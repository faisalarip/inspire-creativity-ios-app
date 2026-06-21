// catalog-id: btn-ferrofluid-spike
import SwiftUI

/// Ferrofluid Spike — a long-press erupts the button surface into clustered
/// black spikes pulled toward the touch point, then collapses back into a
/// smooth puddle on release.
///
/// Technique: a `Canvas` draws a base blob plus per-node spike chains (stacks
/// of overlapping circles). A `.blur` + `.alphaThreshold` filter pair fuses the
/// overlapping circles into one continuous gooey surface (the classic metaball
/// trick). All motion is computed analytically from a `TimelineView(.animation)`
/// date so the spring rise/collapse interpolates correctly inside the Canvas
/// closure (state read inside Canvas does NOT interpolate via withAnimation).
struct FerrofluidSpikeView: View {
    /// `true` → self-driving demo loop (orbiting phantom magnet, no touch).
    /// `false` → real long-press + drag interactive component.
    var demo: Bool = false

    // Event facts only — never animated state read inside Canvas.
    @State private var isPressed = false
    @State private var pressDate: Date?
    @State private var releaseDate: Date?
    @State private var releaseAmp: CGFloat = 0
    @State private var touchLocation: CGPoint?
    @State private var impactTrigger = 0

    var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: impactTrigger)
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        let dim = min(size.width, size.height)
        ZStack {
            // Soft glow halo so the matte-black ferrofluid reads on a dark tint.
            haloLayer(dim: dim)

            TimelineView(.animation) { timeline in
                let now = timeline.date
                let amp = amplitude(now: now)
                let magnet = magnetPoint(now: now, size: size, dim: dim)
                metaballCanvas(size: size, dim: dim, amplitude: amp, magnet: magnet)
            }
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .gesture(demo ? nil : pressGesture(in: size))
    }

    // MARK: - Layers

    private func haloLayer(dim: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 0.42, green: 0.45, blue: 0.55).opacity(0.55),
                        Color(red: 0.10, green: 0.11, blue: 0.16).opacity(0.0)
                    ],
                    center: .center,
                    startRadius: dim * 0.05,
                    endRadius: dim * 0.62
                )
            )
            .frame(width: dim * 1.05, height: dim * 1.05)
            .blur(radius: dim * 0.04)
    }

    private func metaballCanvas(size: CGSize, dim: CGFloat, amplitude amp: CGFloat, magnet: CGPoint) -> some View {
        // Tie all radii to `dim` so ratios stay scale-invariant from 120pt → detail.
        let baseR = dim * 0.085
        let blurR = dim * 0.075
        let circles = surfaceCircles(size: size, dim: dim, amplitude: amp, magnet: magnet, baseR: baseR)

        return Canvas { ctx, _ in
            // Fuse the circles into one gooey surface inside an isolated layer so
            // the metaball filters never touch the sheen drawn afterward.
            // Filter order: alphaThreshold added FIRST (outermost), blur added
            // SECOND (inner) so blur hits the raw circles and the threshold cuts
            // the blurred result → a fused continuous surface, not soft discs.
            ctx.drawLayer { metaball in
                metaball.addFilter(.alphaThreshold(min: 0.45, color: .black))
                metaball.addFilter(.blur(radius: blurR))
                metaball.drawLayer { layer in
                    for c in circles {
                        let rect = CGRect(
                            x: c.center.x - c.radius,
                            y: c.center.y - c.radius,
                            width: c.radius * 2,
                            height: c.radius * 2
                        )
                        layer.fill(Path(ellipseIn: rect), with: .color(.white))
                    }
                }
            }

            // Specular sheen on the fused silhouette (drawn on top, unfiltered)
            // so the matte black reads as wet liquid metal.
            drawSheen(in: &ctx, circles: circles, dim: dim)
        }
        .frame(width: size.width, height: size.height)
    }

    private func drawSheen(in ctx: inout GraphicsContext, circles: [SurfaceCircle], dim: CGFloat) {
        for c in circles where c.isHighlight {
            let r = c.radius * 0.55
            let rect = CGRect(
                x: c.center.x - r,
                y: c.center.y - r * 1.3,
                width: r * 2,
                height: r * 1.4
            )
            let shade = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [
                    Color(red: 0.62, green: 0.66, blue: 0.78).opacity(0.9),
                    Color(red: 0.18, green: 0.19, blue: 0.24).opacity(0.0)
                ]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY),
                endPoint: CGPoint(x: rect.midX, y: rect.maxY)
            )
            ctx.fill(Path(ellipseIn: rect), with: shade)
        }
    }

    // MARK: - Geometry (factored small so the Canvas closure stays type-checkable)

    struct SurfaceCircle {
        var center: CGPoint
        var radius: CGFloat
        var isHighlight: Bool
    }

    /// Builds the full circle field: a central puddle plus rim nodes that each
    /// erupt a leaning spike chain toward the magnet.
    private func surfaceCircles(size: CGSize, dim: CGFloat, amplitude amp: CGFloat, magnet: CGPoint, baseR: CGFloat) -> [SurfaceCircle] {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let puddleR = dim * 0.30
        var out: [SurfaceCircle] = []

        // Flat resting puddle — always present so the tile is never blank.
        out.append(SurfaceCircle(center: center, radius: puddleR * 0.62, isHighlight: false))
        out.append(SurfaceCircle(
            center: CGPoint(x: center.x - puddleR * 0.18, y: center.y - puddleR * 0.22),
            radius: puddleR * 0.30, isHighlight: true))

        let nodeCount = 12
        let ringR = puddleR * 0.78
        for i in 0..<nodeCount {
            let theta = (CGFloat(i) / CGFloat(nodeCount)) * .pi * 2
            let node = CGPoint(x: center.x + cos(theta) * ringR,
                               y: center.y + sin(theta) * ringR)
            appendSpike(into: &out, node: node, magnet: magnet,
                        amplitude: amp, dim: dim, baseR: baseR)
        }
        return out
    }

    /// One rim node → a chain of shrinking circles climbing toward the magnet.
    private func appendSpike(into out: inout [SurfaceCircle], node: CGPoint, magnet: CGPoint, amplitude amp: CGFloat, dim: CGFloat, baseR: CGFloat) {
        let dx = magnet.x - node.x
        let dy = magnet.y - node.y
        let dist = max(sqrt(dx * dx + dy * dy), 0.0001)
        // Proximity weight: nodes nearer the magnet rise taller and lean harder.
        let proximity = max(0, 1 - dist / (dim * 0.95))
        let weight = proximity * proximity
        let height = amp * weight * dim * 0.34

        // Anchor blob (keeps the spike welded to the puddle even at rest).
        out.append(SurfaceCircle(center: node, radius: baseR * 0.95, isHighlight: false))
        guard height > dim * 0.012 else { return }

        // Direction = node → magnet (the "chasing the finger" lean).
        let ux = dx / dist
        let uy = dy / dist
        let links = 4
        for j in 1...links {
            let t = CGFloat(j) / CGFloat(links)
            let along = height * t
            let cx = node.x + ux * along
            let cy = node.y + uy * along
            let r = baseR * (0.92 - 0.16 * t)
            out.append(SurfaceCircle(center: CGPoint(x: cx, y: cy),
                                     radius: r,
                                     isHighlight: j == links))
        }
    }

    /// The magnet/touch point that spikes lean toward.
    private func magnetPoint(now: Date, size: CGSize, dim: CGFloat) -> CGPoint {
        if !demo, let loc = touchLocation, (isPressed || (releaseDate.map { now.timeIntervalSince($0) < 0.45 } ?? false)) {
            return loc
        }
        // Demo (and idle) loop: a phantom magnet orbits the button on a ~3.2s loop.
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let period = 3.2
        let phase = (now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period)) / period
        let angle = CGFloat(phase) * .pi * 2
        // Breathe the orbit radius so the magnet drifts in and out.
        let wobble = 0.72 + 0.22 * sin(angle * 2)
        let orbitR = dim * 0.46 * wobble
        return CGPoint(x: center.x + cos(angle) * orbitR,
                       y: center.y + sin(angle) * orbitR)
    }

    /// Analytic amplitude — swell on press, critically-damped collapse on release.
    private func amplitude(now: Date) -> CGFloat {
        if demo {
            // Steady-high with a gentle pulse → always alive, never blank.
            let t = now.timeIntervalSinceReferenceDate
            return 0.82 + 0.10 * CGFloat(sin(t * 1.8))
        }
        if isPressed, let p = pressDate {
            let t = now.timeIntervalSince(p)
            return 1 - exp(-CGFloat(t) / 0.12) // smooth swell toward 1
        }
        if let r = releaseDate {
            let t = CGFloat(now.timeIntervalSince(r))
            let w: CGFloat = 14
            return releaseAmp * (1 + w * t) * exp(-w * t) // damped collapse to 0
        }
        return 0
    }

    private func pressedAmplitude(at date: Date) -> CGFloat {
        guard let p = pressDate else { return 0 }
        let t = date.timeIntervalSince(p)
        return 1 - exp(-CGFloat(t) / 0.12)
    }

    // MARK: - Gesture

    private func pressGesture(in size: CGSize) -> some Gesture {
        LongPressGesture(minimumDuration: 0.05, maximumDistance: .infinity)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                switch value {
                case .first:
                    beginPress(at: CGPoint(x: size.width / 2, y: size.height / 2))
                case .second(_, let drag):
                    if !isPressed { beginPress(at: drag?.location ?? CGPoint(x: size.width / 2, y: size.height / 2)) }
                    if let loc = drag?.location { touchLocation = loc }
                }
            }
            .onEnded { _ in endPress() }
    }

    private func beginPress(at location: CGPoint) {
        guard !isPressed else { return }
        touchLocation = location
        pressDate = Date()
        releaseDate = nil
        isPressed = true
        impactTrigger += 1
    }

    private func endPress() {
        // Capture height BEFORE mutating state so the collapse starts correctly.
        releaseAmp = pressedAmplitude(at: Date())
        releaseDate = Date()
        isPressed = false
        impactTrigger += 1
    }
}
