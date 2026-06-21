// catalog-id: mtl-caustic-lens
// catalog-metal: CausticLensView.metal
import SwiftUI

/// Caustic Glass Lens — a draggable circular glass blob that magnifies and
/// refracts the content beneath it, with animated underwater caustic light
/// bands rippling across the lens interior.
///
/// - `demo == true`  : self-driving figure-eight drift, caustics always live.
/// - `demo == false` : drag the lens with your finger; on release it springs
///                     back into the idle figure-eight drift.
///
/// Single public view. SwiftUI-only, iOS 17. The refraction/caustics/rim are
/// all composited in one `.layerEffect` pass (see `CausticLens.metal`).
struct CausticLensView: View {
    var demo: Bool = false

    // Live finger position while dragging (view-local points). nil == not dragging.
    @State private var dragLocation: CGPoint? = nil
    // Where the finger let go, plus the timeline timestamp of release — used to
    // interpolate a deterministic spring-back to the idle path.
    @State private var releaseFrom: CGPoint = .zero
    @State private var releaseAt: Double = -1_000

    // Seconds for one full figure-eight loop, and the spring-back duration.
    private let loopDuration: Double = 3.4
    private let returnDuration: Double = 0.9

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let radius = lensRadius(for: size)

            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let center = currentCenter(time: t, size: size)

                CausticLensView_Backdrop()
                    .modifier(
                        CausticLensView_CausticLensEffect(
                            center: center,
                            radius: radius,
                            time: t,
                            size: size
                        )
                    )
                    .contentShape(Rectangle())
                    .gesture(
                        dragGesture(time: t, size: size),
                        including: demo ? .subviews : .all
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.06, green: 0.04, blue: 0.03))
        .clipped()
    }

    // MARK: - Center driver (a pure function of the timeline clock)

    /// The lens center for a given frame. Fully derived from the clock so the
    /// motion is deterministic and never jumps (no withAnimation on read state).
    private func currentCenter(time t: Double, size: CGSize) -> CGPoint {
        let idle = figureEight(time: t, size: size)

        // Dragging: track the finger directly.
        if let live = dragLocation {
            return clamp(live, in: size)
        }

        // Just released: ease from the release point back onto the idle path.
        let since = t - releaseAt
        if since < returnDuration {
            let raw = since / returnDuration
            let e = springEase(raw)
            let x = releaseFrom.x + (idle.x - releaseFrom.x) * e
            let y = releaseFrom.y + (idle.y - releaseFrom.y) * e
            return CGPoint(x: x, y: y)
        }

        // Idle: slow figure-eight drift.
        return idle
    }

    /// Parametric figure-eight: (sin ωt, sin 2ωt) mapped into the view bounds.
    private func figureEight(time t: Double, size: CGSize) -> CGPoint {
        let omega = 2.0 * Double.pi / loopDuration
        let cx = Double(size.width) * 0.5
        let cy = Double(size.height) * 0.5
        // Keep the path comfortably inside so the lens never rides the edge.
        let ax = Double(size.width) * 0.30
        let ay = Double(size.height) * 0.26
        let x = cx + ax * sin(omega * t)
        let y = cy + ay * sin(2.0 * omega * t)
        return CGPoint(x: x, y: y)
    }

    /// Damped-sine ease-out (0→1) that overshoots slightly for a springy snap.
    private func springEase(_ x: Double) -> Double {
        let c = x < 0 ? 0 : (x > 1 ? 1 : x)
        let decay = exp(-5.5 * c)
        let osc = cos(c * Double.pi * 2.2)
        return 1.0 - decay * osc
    }

    // MARK: - Geometry helpers

    private func lensRadius(for size: CGSize) -> CGFloat {
        let minSide = min(size.width, size.height)
        return max(minSide * 0.30, 28.0)
    }

    private func clamp(_ p: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(p.x, 0), size.width),
            y: min(max(p.y, 0), size.height)
        )
    }

    // MARK: - Interaction

    private func dragGesture(time t: Double, size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                dragLocation = value.location
            }
            .onEnded { value in
                releaseFrom = clamp(value.location, in: size)
                releaseAt = t
                dragLocation = nil
            }
    }
}

// MARK: - Lens effect modifier

/// Wraps the stitchable `causticLens` shader as a `.layerEffect`. Sampling is
/// inward (magnifying), so the displaced coordinate stays within `radius` of
/// `position` — that makes `maxSampleOffset == radius` genuinely sufficient.
private struct CausticLensView_CausticLensEffect: ViewModifier {
    let center: CGPoint
    let radius: CGFloat
    let time: Double
    let size: CGSize

    func body(content: Content) -> some View {
        content.layerEffect(
            ShaderLibrary.causticLens(
                .float2(Float(center.x), Float(center.y)),
                .float(Float(radius)),
                .float(Float(time)),
                .float2(Float(size.width), Float(size.height))
            ),
            maxSampleOffset: CGSize(width: radius, height: radius)
        )
    }
}

// MARK: - CausticLensView_Backdrop (vivid, opaque content for the lens to magnify)

/// A rich, fully opaque scene. The lens needs real detail beneath it to read as
/// magnification/refraction — without this the effect would be invisible.
private struct CausticLensView_Backdrop: View {
    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                // Deep teal→indigo base wash.
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.20, blue: 0.30),
                        Color(red: 0.06, green: 0.10, blue: 0.26),
                        Color(red: 0.10, green: 0.05, blue: 0.20)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Warm pooled glow so refracted light has somewhere to gather.
                RadialGradient(
                    colors: [
                        Color(red: 0.95, green: 0.62, blue: 0.30).opacity(0.55),
                        Color(red: 0.20, green: 0.40, blue: 0.55).opacity(0.0)
                    ],
                    center: .init(x: 0.32, y: 0.30),
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * 0.7
                )
                .blendMode(.screen)

                // Crisp lattice — high-frequency detail makes the magnification
                // obvious and gives the caustics something to bend.
                CausticLensView_LensGrid(size: size)
                    .stroke(Color(red: 0.70, green: 0.90, blue: 1.0).opacity(0.22),
                            lineWidth: 1)

                // A couple of bold marks for scale reference under the lens.
                Circle()
                    .fill(Color(red: 1.0, green: 0.78, blue: 0.32).opacity(0.85))
                    .frame(width: max(size.width, size.height) * 0.12)
                    .position(x: size.width * 0.68, y: size.height * 0.40)

                Capsule()
                    .fill(Color(red: 0.40, green: 0.85, blue: 0.80).opacity(0.75))
                    .frame(width: max(size.width, size.height) * 0.22,
                           height: max(size.width, size.height) * 0.05)
                    .rotationEffect(.degrees(-22))
                    .position(x: size.width * 0.36, y: size.height * 0.70)

                Text("✦")
                    .font(.system(size: max(size.width, size.height) * 0.16,
                                  weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 1.0, green: 0.95, blue: 0.86).opacity(0.9))
                    .position(x: size.width * 0.78, y: size.height * 0.74)
            }
            .frame(width: size.width, height: size.height)
        }
        .drawingGroup() // flatten into a single layer for the effect to sample
    }
}

/// A thin orthogonal lattice; high-frequency reference texture.
private struct CausticLensView_LensGrid: Shape {
    let size: CGSize

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let step = max(min(rect.width, rect.height) / 9.0, 14.0)

        var x = rect.minX
        while x <= rect.maxX {
            p.move(to: CGPoint(x: x, y: rect.minY))
            p.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += step
        }
        var y = rect.minY
        while y <= rect.maxY {
            p.move(to: CGPoint(x: rect.minX, y: y))
            p.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += step
        }
        return p
    }
}
