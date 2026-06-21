// catalog-id: mtl-foil-tilt
// catalog-metal: FoilTiltView.metal
import SwiftUI

// MARK: - Foil Tilt
// Holographic foil-stamp diffraction. A draggable tilt sweeps an iridescent
// rainbow sheen across an embossed sticker with a sharp specular glint.
// demo == true  -> TimelineView(.animation) auto-rocks the tilt forever.
// demo == false -> DragGesture deflects the tilt; release springs back to idle.
public struct FoilTiltView: View {
    public var demo: Bool = false

    // Drag-driven deflection added on top of the always-running idle rock.
    @State private var dragDeflection: CGSize = .zero

    public init(demo: Bool = false) {
        self.demo = demo
    }

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let minSide = max(min(size.width, size.height), 1)

            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let tilt = resolvedTilt(time: t)

                FoilTiltView_FoilBadge(unit: minSide)
                    .frame(width: size.width, height: size.height)
                    .modifier(
                        FoilTiltView_FoilShaderModifier(
                            pixelSize: size,
                            tilt: tilt,
                            time: t
                        )
                    )
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            // `.subviews` disables this view's own drag in demo mode while the
            // idle rock keeps driving the shader; `.all` enables it otherwise.
            .gesture(
                dragGesture(minSide: minSide),
                including: demo ? .subviews : .all
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Tilt resolution (idle rock + drag deflection, always additive)

    private func resolvedTilt(time t: TimeInterval) -> CGPoint {
        let idle = idleRock(time: t)
        let dx: Double = idle.x + Double(dragDeflection.width)
        let dy: Double = idle.y + Double(dragDeflection.height)
        // Clamp so the rainbow stays in a tactile, believable range.
        return CGPoint(
            x: clamp(dx, -1.6, 1.6),
            y: clamp(dy, -1.6, 1.6)
        )
    }

    private func idleRock(time t: TimeInterval) -> (x: Double, y: Double) {
        // Slow, lazily-drifting sine on x and y so the sheen sweeps back and
        // forth on its own. Two slightly detuned frequencies keep it organic.
        let x = sin(t * 0.55) * 0.85 + sin(t * 0.21) * 0.30
        let y = cos(t * 0.40) * 0.70 + sin(t * 0.17 + 1.3) * 0.25
        return (x, y)
    }

    private func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        min(max(v, lo), hi)
    }

    // MARK: Interaction

    private func dragGesture(minSide: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Map finger translation to a tilt vector. Normalize by the
                // tile size so the feel is consistent in a tiny grid cell and
                // a large detail area alike.
                let nx = value.translation.width / minSide
                let ny = value.translation.height / minSide
                dragDeflection = CGSize(width: nx * 2.4, height: ny * 2.4)
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) {
                    dragDeflection = .zero
                }
            }
    }
}

// MARK: - Shader modifier (iOS 17 .colorEffect)

private struct FoilTiltView_FoilShaderModifier: ViewModifier {
    let pixelSize: CGSize
    let tilt: CGPoint
    let time: TimeInterval

    func body(content: Content) -> some View {
        content.colorEffect(
            ShaderLibrary.foilTilt(
                .float2(Float(pixelSize.width), Float(pixelSize.height)),
                .float2(Float(tilt.x), Float(tilt.y)),
                .float(Float(time))
            )
        )
    }
}

// MARK: - Base content: an embossed foil sticker

// The shader colors whatever alpha/luminance is here. It must read as a real,
// legible sticker even with no shader (the "never blank" guarantee), so it is
// a die-cut badge with an embossed grayscale relief pattern inside.
private struct FoilTiltView_FoilBadge: View {
    let unit: CGFloat

    var body: some View {
        ZStack {
            // Die-cut shape gives the foil its silhouette (via input alpha).
            FoilTiltView_FoilStarBadge()
                .fill(Color(red: 0.62, green: 0.62, blue: 0.64))
            FoilTiltView_EmbossPattern(unit: unit)
                .clipShape(FoilTiltView_FoilStarBadge())
            // A faint rim brightens the edge so the glint has something to bite.
            FoilTiltView_FoilStarBadge()
                .stroke(Color(red: 0.95, green: 0.95, blue: 0.97), lineWidth: max(unit * 0.012, 1))
                .opacity(0.65)
        }
        .padding(unit * 0.10)
    }
}

// Embossed relief: concentric rings + radial spokes + a center monogram disc,
// all in grayscale. Luminance variation here becomes the diffraction texture.
private struct FoilTiltView_EmbossPattern: View {
    let unit: CGFloat

    var body: some View {
        ZStack {
            FoilTiltView_ConcentricRings()
                .stroke(
                    Color(red: 0.30, green: 0.30, blue: 0.32),
                    style: StrokeStyle(lineWidth: max(unit * 0.018, 0.8))
                )
                .opacity(0.9)
            FoilTiltView_RadialSpokes(count: 24)
                .stroke(
                    Color(red: 0.80, green: 0.80, blue: 0.82),
                    style: StrokeStyle(lineWidth: max(unit * 0.010, 0.5))
                )
                .opacity(0.55)
            Circle()
                .fill(Color(red: 0.50, green: 0.50, blue: 0.52))
                .frame(width: unit * 0.30, height: unit * 0.30)
            FoilTiltView_SparkleMark()
                .fill(Color(red: 0.97, green: 0.97, blue: 0.99))
                .frame(width: unit * 0.22, height: unit * 0.22)
                .opacity(0.9)
        }
    }
}

// MARK: - Shapes

// A soft 6-point star / seal used as the foil die-cut.
private struct FoilTiltView_FoilStarBadge: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let points = 12
        let outer = r
        let inner = r * 0.82 // shallow scallops -> reads as a wax/foil seal
        var p = Path()
        for i in 0..<(points * 2) {
            let radius: CGFloat = (i % 2 == 0) ? outer : inner
            let angle = (Double(i) / Double(points * 2)) * 2 * .pi - .pi / 2
            let pt = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

private struct FoilTiltView_ConcentricRings: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxR = min(rect.width, rect.height) / 2
        var p = Path()
        let count = 7
        for i in 1...count {
            let radius = maxR * (CGFloat(i) / CGFloat(count + 1))
            p.addEllipse(
                in: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
            )
        }
        return p
    }
}

private struct FoilTiltView_RadialSpokes: Shape {
    let count: Int
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        var p = Path()
        for i in 0..<count {
            let angle = (Double(i) / Double(count)) * 2 * .pi
            let outer = CGPoint(
                x: center.x + CGFloat(cos(angle)) * r,
                y: center.y + CGFloat(sin(angle)) * r
            )
            let inner = CGPoint(
                x: center.x + CGFloat(cos(angle)) * r * 0.34,
                y: center.y + CGFloat(sin(angle)) * r * 0.34
            )
            p.move(to: inner)
            p.addLine(to: outer)
        }
        return p
    }
}

// A 4-point sparkle for the center monogram.
private struct FoilTiltView_SparkleMark: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let waist = r * 0.18
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - r))
        p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + waist, y: c.y - waist))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + waist, y: c.y + waist))
        p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - waist, y: c.y + waist))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - waist, y: c.y - waist))
        p.closeSubpath()
        return p
    }
}
