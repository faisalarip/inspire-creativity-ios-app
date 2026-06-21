// catalog-id: tr-iris-shutter
import SwiftUI

/// Iris Shutter Wipe — a ring of overlapping camera-aperture blades spirals open
/// from the center, the polygonal opening growing to reveal the destination view.
///
/// The reveal is a real SwiftUI `Path` N-gon mask over the destination; the blades
/// are a decorative `Canvas` overlay registered to the SAME center / radius /
/// rotation / blade-count so the polygon reads as the hole the blades define.
///
/// Geometry is rebuilt every frame from a single `progress` value. Because
/// `Canvas` and `Path` are not interpolated by SwiftUI on their own, the content
/// is wrapped in an `Animatable` view (`IrisShutterView_IrisContent`) whose `animatableData` IS
/// the progress — so both the `withAnimation(.spring)` tap and the continuous
/// `TimelineView(.animation)` demo loop produce smooth, frame-by-frame motion.
struct IrisShutterView: View {
    var demo: Bool = false

    // Interactive state: tap toggles the aperture open/closed.
    @State private var isOpen: Bool = false

    private let bladeCount: Int = 7

    var body: some View {
        GeometryReader { geo in
            if demo {
                demoBody(size: geo.size)
            } else {
                interactiveBody(size: geo.size)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Modes

    @ViewBuilder
    private func demoBody(size: CGSize) -> some View {
        // Continuous, self-driving triangle-wave 0 -> 1 -> 0 over a ~3s period.
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let progress: CGFloat = Self.triangleWave(time: t, period: 3.0)
            IrisShutterView_IrisContent(progress: progress, size: size, bladeCount: bladeCount)
        }
    }

    @ViewBuilder
    private func interactiveBody(size: CGSize) -> some View {
        let progress: CGFloat = isOpen ? 1 : 0
        IrisShutterView_IrisContent(progress: progress, size: size, bladeCount: bladeCount)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.72)) {
                    isOpen.toggle()
                }
            }
    }

    /// Smooth 0 -> 1 -> 0 wave. Built from a smoothstep'd triangle so the demo
    /// eases at the extremes instead of bouncing linearly.
    private static func triangleWave(time: TimeInterval, period: TimeInterval) -> CGFloat {
        let phase = (time.truncatingRemainder(dividingBy: period)) / period
        let tri: CGFloat = phase < 0.5 ? CGFloat(phase * 2) : CGFloat((1 - phase) * 2)
        // smoothstep for soft ends
        return tri * tri * (3 - 2 * tri)
    }
}

// MARK: - Animatable content

/// Renders the full iris for a given `progress`. Conforming to `Animatable` with
/// `animatableData == progress` makes SwiftUI interpolate progress every frame,
/// so the Canvas-drawn blades + polygon mask animate smoothly under both
/// `withAnimation` (tap) and a continuous `TimelineView` value (demo).
private struct IrisShutterView_IrisContent: View, Animatable {
    var progress: CGFloat
    let size: CGSize
    let bladeCount: Int

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let p: CGFloat = min(max(progress, 0), 1)
        let metrics = IrisShutterView_IrisMetrics(size: size, progress: p, bladeCount: bladeCount)

        return ZStack {
            // 1. Dark camera housing behind everything.
            housing(metrics: metrics)

            // 2. Destination "scene" revealed through the polygonal opening.
            destinationScene(metrics: metrics)
                .mask(
                    IrisShutterView_OpeningPolygon(metrics: metrics)
                        .fill(style: FillStyle(eoFill: false, antialiased: true))
                )

            // 3. Decorative aperture blades in the annulus between opening and rim.
            bladeCanvas(metrics: metrics)
                .allowsHitTesting(false)

            // 4. Bezel rim ring so it always reads as a lens aperture.
            bezel(metrics: metrics)
                .allowsHitTesting(false)
        }
        .clipShape(Circle().inset(by: metrics.bezelInset))
    }

    // MARK: - Layers

    @ViewBuilder
    private func housing(metrics: IrisShutterView_IrisMetrics) -> some View {
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.09)
            RadialGradient(
                colors: [
                    Color(red: 0.16, green: 0.17, blue: 0.21),
                    Color(red: 0.05, green: 0.05, blue: 0.07)
                ],
                center: .center,
                startRadius: 0,
                endRadius: metrics.outerRadius
            )
        }
    }

    @ViewBuilder
    private func destinationScene(metrics: IrisShutterView_IrisMetrics) -> some View {
        ZStack {
            // A warm, vivid "next screen" so the reveal is satisfying.
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.55, blue: 0.32),
                    Color(red: 0.93, green: 0.27, blue: 0.49),
                    Color(red: 0.40, green: 0.20, blue: 0.74)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // Soft glow disc to give the scene some life through the iris.
            RadialGradient(
                colors: [
                    Color(red: 1.0, green: 0.96, blue: 0.80).opacity(0.85),
                    Color(red: 1.0, green: 0.96, blue: 0.80).opacity(0.0)
                ],
                center: UnitPoint(x: 0.42, y: 0.38),
                startRadius: 0,
                endRadius: metrics.outerRadius * 0.9
            )
            sunburst(metrics: metrics)
        }
    }

    /// Faint radiating rays so the destination has detail, not a flat fill.
    @ViewBuilder
    private func sunburst(metrics: IrisShutterView_IrisMetrics) -> some View {
        Canvas { ctx, _ in
            let center = metrics.center
            let rays = 24
            for i in 0..<rays {
                let a: CGFloat = (CGFloat(i) / CGFloat(rays)) * .pi * 2
                var path = Path()
                path.move(to: center)
                let end = CGPoint(
                    x: center.x + cos(a) * metrics.outerRadius * 1.4,
                    y: center.y + sin(a) * metrics.outerRadius * 1.4
                )
                path.addLine(to: end)
                ctx.stroke(
                    path,
                    with: .color(Color(red: 1.0, green: 1.0, blue: 1.0).opacity(0.06)),
                    lineWidth: 2
                )
            }
        }
    }

    @ViewBuilder
    private func bladeCanvas(metrics: IrisShutterView_IrisMetrics) -> some View {
        Canvas { ctx, _ in
            drawBlades(in: &ctx, metrics: metrics)
        }
    }

    @ViewBuilder
    private func bezel(metrics: IrisShutterView_IrisMetrics) -> some View {
        let lineWidth: CGFloat = max(metrics.minDim * 0.035, 2)
        ZStack {
            Circle()
                .inset(by: metrics.bezelInset)
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            Color(red: 0.55, green: 0.58, blue: 0.66),
                            Color(red: 0.12, green: 0.13, blue: 0.16),
                            Color(red: 0.72, green: 0.75, blue: 0.82),
                            Color(red: 0.10, green: 0.11, blue: 0.14),
                            Color(red: 0.55, green: 0.58, blue: 0.66)
                        ],
                        center: .center
                    ),
                    lineWidth: lineWidth
                )
            Circle()
                .inset(by: metrics.bezelInset + lineWidth)
                .strokeBorder(
                    Color(red: 0.02, green: 0.02, blue: 0.03).opacity(0.7),
                    lineWidth: max(lineWidth * 0.4, 1)
                )
        }
    }

    // MARK: - Blade drawing

    private func drawBlades(in ctx: inout GraphicsContext, metrics: IrisShutterView_IrisMetrics) {
        let n = metrics.bladeCount
        for i in 0..<n {
            let blade = bladePath(index: i, metrics: metrics)

            // Base blade fill — brushed metal gradient across the blade.
            let g = Gradient(colors: [
                Color(red: 0.30, green: 0.32, blue: 0.38),
                Color(red: 0.16, green: 0.17, blue: 0.21),
                Color(red: 0.09, green: 0.10, blue: 0.13)
            ])
            let baseAngle: CGFloat = metrics.bladeBaseAngle(index: i)
            let shading = GraphicsContext.Shading.linearGradient(
                g,
                startPoint: CGPoint(
                    x: metrics.center.x + cos(baseAngle) * metrics.outerRadius,
                    y: metrics.center.y + sin(baseAngle) * metrics.outerRadius
                ),
                endPoint: metrics.center
            )
            ctx.fill(blade, with: shading)

            // Seam line where this blade overlaps its neighbour — adds depth.
            ctx.stroke(
                blade,
                with: .color(Color(red: 0.0, green: 0.0, blue: 0.0).opacity(0.45)),
                lineWidth: 0.8
            )

            // Specular highlight along the inner (aperture-facing) edge.
            let edge = bladeInnerEdge(index: i, metrics: metrics)
            ctx.stroke(
                edge,
                with: .color(Color(red: 0.85, green: 0.88, blue: 0.95).opacity(0.55)),
                lineWidth: max(metrics.minDim * 0.006, 0.8)
            )
        }
    }

    /// One curved blade: a quad spanning from the rim inward, with its inner edge
    /// hugging two adjacent vertices of the opening polygon (so blades register
    /// exactly with the mask).
    private func bladePath(index: Int, metrics: IrisShutterView_IrisMetrics) -> Path {
        let inner = metrics.openingVertices
        let n = inner.count
        let a = inner[index % n]
        let b = inner[(index + 1) % n]

        // Outer arc points pushed out to (beyond) the rim along each vertex angle.
        let outerR: CGFloat = metrics.outerRadius * 1.25
        let aAng: CGFloat = metrics.vertexAngle(index)
        let bAng: CGFloat = metrics.vertexAngle(index + 1)
        let outerA = metrics.point(angle: aAng, radius: outerR)
        let outerB = metrics.point(angle: bAng, radius: outerR)

        var path = Path()
        path.move(to: a)
        // Inner edge bows slightly outward for the curved-iris look.
        path.addQuadCurve(to: b, control: metrics.innerEdgeControl(index))
        path.addLine(to: outerB)
        path.addLine(to: outerA)
        path.closeSubpath()
        return path
    }

    private func bladeInnerEdge(index: Int, metrics: IrisShutterView_IrisMetrics) -> Path {
        let inner = metrics.openingVertices
        let n = inner.count
        let a = inner[index % n]
        let b = inner[(index + 1) % n]
        var path = Path()
        path.move(to: a)
        path.addQuadCurve(to: b, control: metrics.innerEdgeControl(index))
        return path
    }
}

// MARK: - Iris geometry

/// All shared geometry for a given size + progress. Both the mask polygon and the
/// decorative blades derive from this single source so they stay registered.
private struct IrisShutterView_IrisMetrics {
    let size: CGSize
    let progress: CGFloat
    let bladeCount: Int

    let center: CGPoint
    let minDim: CGFloat
    let outerRadius: CGFloat
    let bezelInset: CGFloat
    let openingRadius: CGFloat
    let rotation: CGFloat
    let openingVertices: [CGPoint]

    init(size: CGSize, progress: CGFloat, bladeCount: Int) {
        self.size = size
        self.progress = progress
        self.bladeCount = bladeCount

        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        self.center = c
        let m: CGFloat = min(size.width, size.height)
        self.minDim = m

        let inset: CGFloat = m * 0.02
        self.bezelInset = inset
        // Outer radius reaches the bezel ring.
        self.outerRadius = m / 2 - inset

        // Opening grows linearly with progress from a tiny pinhole to slightly
        // past the rim so it fully clears the frame when open. (Easing is applied
        // by the caller's spring / demo wave, so we keep this linear to avoid
        // double-easing.)
        let minR: CGFloat = m * 0.02
        let maxR: CGFloat = (m / 2) * 1.18
        self.openingRadius = minR + (maxR - minR) * progress

        // Blades spiral: rotate ~52 degrees as the aperture opens.
        self.rotation = (52 * .pi / 180) * progress

        // Precompute polygon vertices.
        var verts: [CGPoint] = []
        let n = bladeCount
        for i in 0..<n {
            let ang: CGFloat = IrisShutterView_IrisMetrics.angle(index: i, count: n, rotation: rotation)
            verts.append(CGPoint(
                x: c.x + cos(ang) * openingRadius,
                y: c.y + sin(ang) * openingRadius
            ))
        }
        self.openingVertices = verts
    }

    func vertexAngle(_ index: Int) -> CGFloat {
        IrisShutterView_IrisMetrics.angle(index: index, count: bladeCount, rotation: rotation)
    }

    func point(angle: CGFloat, radius: CGFloat) -> CGPoint {
        CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }

    /// Control point that bows the inner edge of a blade outward from center,
    /// giving the curved-iris polygon its convex sides.
    func innerEdgeControl(_ index: Int) -> CGPoint {
        let a0: CGFloat = vertexAngle(index)
        let a1: CGFloat = vertexAngle(index + 1)
        let mid: CGFloat = (a0 + a1) / 2
        let bow: CGFloat = openingRadius * 1.12
        return point(angle: mid, radius: bow)
    }

    func bladeBaseAngle(index: Int) -> CGFloat {
        let a0: CGFloat = vertexAngle(index)
        let a1: CGFloat = vertexAngle(index + 1)
        return (a0 + a1) / 2
    }

    static func angle(index: Int, count: Int, rotation: CGFloat) -> CGFloat {
        let step: CGFloat = (.pi * 2) / CGFloat(count)
        return CGFloat(index) * step + rotation - .pi / 2
    }
}

// MARK: - Opening polygon shape (the actual reveal mask)

private struct IrisShutterView_OpeningPolygon: Shape {
    let metrics: IrisShutterView_IrisMetrics

    func path(in rect: CGRect) -> Path {
        let verts = metrics.openingVertices
        guard verts.count >= 3 else { return Path() }
        var path = Path()
        path.move(to: verts[0])
        for i in 0..<verts.count {
            let next = verts[(i + 1) % verts.count]
            // Bowed sides match the blade inner edges exactly.
            path.addQuadCurve(to: next, control: metrics.innerEdgeControl(i))
        }
        path.closeSubpath()
        return path
    }
}
