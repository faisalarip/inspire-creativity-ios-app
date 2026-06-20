// catalog-id: ges-drag-elastic-grid-warp
import SwiftUI

// MARK: - Elastic Grid Warp
//
// Drag a point on a uniform dot grid and nearby nodes pull toward it with a
// Gaussian distance falloff, the lattice warping like a stretched fishnet and
// rippling back to flat on release.
//
// Architecture note: a `Canvas` reading a plain `@State` scalar does NOT
// re-evaluate its closure per animation frame, so a release "spring" applied
// via `withAnimation` on a scalar would look dead. Instead a single always-on
// `TimelineView(.animation)` drives BOTH modes, and the release ripple is a
// hand-rolled time-decayed damped oscillation evaluated per frame inside the
// Canvas — the negative lobes make nodes overshoot past flat and settle, which
// is the "rippling bouncy spring" the spec calls for.

public struct DragElasticGridWarpView: View {
    public var demo: Bool = false

    public init(demo: Bool = false) {
        self.demo = demo
    }

    // Drag state (interactive mode only)
    @State private var dragCenter: CGPoint? = nil
    @State private var dragStrength: CGFloat = 0
    @State private var releaseDate: Date? = nil
    @State private var releaseCenter: CGPoint = .zero
    @State private var releaseStrength: CGFloat = 0

    public var body: some View {
        GeometryReader { geo in
            let size = geo.size
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let warp = resolveWarp(size: size, time: t)
                Canvas { context, canvasSize in
                    drawLattice(
                        context: &context,
                        size: canvasSize,
                        center: warp.center,
                        strength: warp.strength
                    )
                }
                .contentShape(Rectangle())
                .gesture(dragGesture(size: size))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Warp resolution

    private struct Warp {
        var center: CGPoint
        var strength: CGFloat
    }

    /// Resolves the active warp center + strength for the current frame,
    /// branching on demo vs interactive and folding in the release ripple.
    private func resolveWarp(size: CGSize, time: TimeInterval) -> Warp {
        if demo {
            return demoWarp(size: size, time: time)
        }
        return interactiveWarp(size: size, time: time)
    }

    /// Self-driving Lissajous warp center with a gently pulsing strength.
    private func demoWarp(size: CGSize, time: TimeInterval) -> Warp {
        let period: Double = 3.4
        let phase = (time.truncatingRemainder(dividingBy: period)) / period
        let angle = phase * 2 * Double.pi

        // Travel a soft Lissajous path inside the central region of the tile.
        let cx = 0.5 + 0.30 * cos(angle)
        let cy = 0.5 + 0.22 * sin(angle * 2)
        let center = CGPoint(x: CGFloat(cx) * size.width,
                             y: CGFloat(cy) * size.height)

        // Strength always stays clearly visible (never zero / blank).
        let pulse = 0.5 + 0.5 * sin(angle * 1.5)
        let strength = CGFloat(0.55 + 0.45 * pulse)
        return Warp(center: center, strength: strength)
    }

    /// Interactive warp: active drag wins; otherwise decay the release ripple.
    private func interactiveWarp(size: CGSize, time: TimeInterval) -> Warp {
        if let c = dragCenter {
            return Warp(center: c, strength: dragStrength)
        }
        guard let release = releaseDate, releaseStrength > 0.0001 else {
            return Warp(center: CGPoint(x: size.width / 2, y: size.height / 2),
                        strength: 0)
        }
        let elapsed = time - release.timeIntervalSinceReferenceDate
        let strength = rippleStrength(elapsed: elapsed, base: releaseStrength)
        return Warp(center: releaseCenter, strength: strength)
    }

    /// Time-decayed damped oscillation: overshoots past flat then settles.
    private func rippleStrength(elapsed: TimeInterval, base: CGFloat) -> CGFloat {
        guard elapsed >= 0 else { return base }
        let decay: Double = 6.5          // envelope falloff rate
        let omega: Double = 13.0         // bounce frequency (~2 lobes)
        let envelope = exp(-decay * elapsed)
        let osc = cos(omega * elapsed)
        return base * CGFloat(envelope * osc)
    }

    // MARK: - Drag gesture

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                dragCenter = clampPoint(value.location, in: size)
                // Pull magnitude grows with how far the finger has travelled,
                // so a small touch warps gently and a big drag pinches hard.
                let dx = value.translation.width
                let dy = value.translation.height
                let travel = sqrt(dx * dx + dy * dy)
                let norm = travel / max(min(size.width, size.height), 1)
                dragStrength = min(1.0, 0.30 + norm * 1.6)
            }
            .onEnded { value in
                releaseCenter = clampPoint(value.location, in: size)
                releaseStrength = max(dragStrength, 0.2)
                releaseDate = Date()
                dragCenter = nil
                dragStrength = 0
            }
    }

    private func clampPoint(_ p: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: min(max(p.x, 0), size.width),
                y: min(max(p.y, 0), size.height))
    }

    // MARK: - Lattice rendering

    /// Draws the fishnet: row polylines + column polylines through displaced
    /// nodes, with a glossy dot at each node. Called from both modes.
    private func drawLattice(context: inout GraphicsContext,
                             size: CGSize,
                             center: CGPoint,
                             strength: CGFloat) {
        let cols = 13
        let rows = 13
        guard size.width > 1, size.height > 1 else { return }

        let inset: CGFloat = max(min(size.width, size.height) * 0.06, 4)
        let usable = CGSize(width: size.width - inset * 2,
                            height: size.height - inset * 2)
        let stepX = usable.width / CGFloat(cols - 1)
        let stepY = usable.height / CGFloat(rows - 1)

        // Sigma controls the falloff radius; max pull keyed to lattice scale.
        let sigma = min(usable.width, usable.height) * 0.34
        let maxPull = min(usable.width, usable.height) * 0.40 * strength

        var nodes = [[CGPoint]](repeating: [CGPoint](repeating: .zero, count: cols),
                                count: rows)
        for r in 0..<rows {
            for c in 0..<cols {
                let rest = CGPoint(x: inset + CGFloat(c) * stepX,
                                   y: inset + CGFloat(r) * stepY)
                nodes[r][c] = displace(rest: rest,
                                       center: center,
                                       sigma: sigma,
                                       maxPull: maxPull)
            }
        }

        drawConnections(context: &context, nodes: nodes, rows: rows, cols: cols,
                        center: center, sigma: sigma)
        drawNodes(context: &context, nodes: nodes, rows: rows, cols: cols,
                  size: size, center: center, sigma: sigma)
    }

    /// Gaussian falloff displacement toward the warp center (pinched well).
    private func displace(rest: CGPoint,
                          center: CGPoint,
                          sigma: CGFloat,
                          maxPull: CGFloat) -> CGPoint {
        guard maxPull != 0, sigma > 0 else { return rest }
        let dx = center.x - rest.x
        let dy = center.y - rest.y
        let dist = sqrt(dx * dx + dy * dy)
        guard dist > 0.0001 else { return rest }
        let ratio = dist / sigma
        let falloff = exp(-(ratio * ratio))
        // Pull cannot exceed the distance to the center (no overshoot collapse).
        let pull = min(maxPull * falloff, dist * 0.92)
        let ux = dx / dist
        let uy = dy / dist
        return CGPoint(x: rest.x + ux * pull, y: rest.y + uy * pull)
    }

    /// Strength of warp influence at a node, for color/width modulation.
    private func influence(at point: CGPoint, center: CGPoint, sigma: CGFloat) -> CGFloat {
        guard sigma > 0 else { return 0 }
        let dx = center.x - point.x
        let dy = center.y - point.y
        let dist = sqrt(dx * dx + dy * dy)
        let ratio = dist / sigma
        return exp(-(ratio * ratio))
    }

    private func drawConnections(context: inout GraphicsContext,
                                 nodes: [[CGPoint]],
                                 rows: Int,
                                 cols: Int,
                                 center: CGPoint,
                                 sigma: CGFloat) {
        // Horizontal strands
        for r in 0..<rows {
            var path = Path()
            path.move(to: nodes[r][0])
            for c in 1..<cols {
                path.addLine(to: nodes[r][c])
            }
            strokeStrand(context: &context, path: path)
        }
        // Vertical strands
        for c in 0..<cols {
            var path = Path()
            path.move(to: nodes[0][c])
            for r in 1..<rows {
                path.addLine(to: nodes[r][c])
            }
            strokeStrand(context: &context, path: path)
        }
    }

    private func strokeStrand(context: inout GraphicsContext, path: Path) {
        let gradient = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [
                Color(hexCode: 0x3A4D8F).opacity(0.55),
                Color(hexCode: 0x6FA8FF).opacity(0.85)
            ]),
            startPoint: .zero,
            endPoint: CGPoint(x: 200, y: 200)
        )
        context.stroke(path, with: gradient,
                       style: StrokeStyle(lineWidth: 1.0, lineCap: .round, lineJoin: .round))
    }

    private func drawNodes(context: inout GraphicsContext,
                           nodes: [[CGPoint]],
                           rows: Int,
                           cols: Int,
                           size: CGSize,
                           center: CGPoint,
                           sigma: CGFloat) {
        let baseRadius = max(min(size.width, size.height) * 0.012, 1.2)
        for r in 0..<rows {
            for c in 0..<nodes[r].count {
                let p = nodes[r][c]
                let inf = influence(at: p, center: center, sigma: sigma)
                // Warped nodes brighten and swell — reads as the pinch well core.
                let radius = baseRadius * (1 + inf * 1.4)
                let dot = Path(ellipseIn: CGRect(x: p.x - radius, y: p.y - radius,
                                                 width: radius * 2, height: radius * 2))
                let color = Color(hexCode: 0x9CC4FF).opacity(0.45 + 0.55 * Double(inf))
                context.fill(dot, with: .color(color))

                // A bright glint on the most-warped nodes for the gravity-lens feel.
                if inf > 0.45 {
                    let glintR = radius * 0.5
                    let glint = Path(ellipseIn: CGRect(
                        x: p.x - glintR - radius * 0.25,
                        y: p.y - glintR - radius * 0.25,
                        width: glintR * 2, height: glintR * 2))
                    context.fill(glint, with: .color(.white.opacity(Double(inf) * 0.7)))
                }
            }
        }
    }
}

// MARK: - Color hex helper

private extension Color {
    init(hexCode hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

// MARK: - Preview
