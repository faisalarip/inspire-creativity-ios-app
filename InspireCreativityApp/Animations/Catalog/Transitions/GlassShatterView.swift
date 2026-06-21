// catalog-id: tr-glass-shatter
import SwiftUI

// MARK: - Glass Shatter
//
// The outgoing glass pane fractures into precomputed triangular/polygonal shards
// that tumble, spin, and fall away under gravity, uncovering the view behind.
// Each shard catches a raking specular highlight that sweeps as it rotates,
// so the break sparkles like real broken glass.
//
// demo == true  -> a self-driving TimelineView loop shatters and reassembles
//                  on a smoothed triangle wave so the tile is always alive.
// demo == false -> tap to shatter; tap again to reassemble.

struct GlassShatterView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { proxy in
            content(size: proxy.size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(size: CGSize) -> some View {
        if demo {
            GlassShatterView_DemoStage(size: size)
        } else {
            GlassShatterView_InteractiveStage(size: size)
        }
    }
}

// MARK: - Demo (self-driving loop)

private struct GlassShatterView_DemoStage: View {
    let size: CGSize
    private let period: Double = 3.4

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = (t.truncatingRemainder(dividingBy: period)) / period
            GlassShatterView_ShatterStage(size: size, progress: GlassShatterView_ShatterMath.loopProgress(phase))
        }
    }
}

// MARK: - Interactive (tap to shatter / reassemble)

private struct GlassShatterView_InteractiveStage: View {
    let size: CGSize

    @State private var anchor: Date? = nil    // moment the current transition began
    @State private var fromValue: Double = 0  // progress at the start of the transition
    @State private var toValue: Double = 0     // progress target of the transition
    @State private var resting: Double = 0     // value to hold when no transition runs

    private let duration: Double = 1.15

    var body: some View {
        TimelineView(.animation) { timeline in
            let p = currentProgress(now: timeline.date)
            GlassShatterView_ShatterStage(size: size, progress: p)
                .contentShape(Rectangle())
                .onTapGesture { handleTap(now: timeline.date, current: p) }
        }
    }

    private func currentProgress(now: Date) -> Double {
        guard let anchor else { return resting }
        let elapsed = now.timeIntervalSince(anchor)
        let f = min(max(elapsed / duration, 0), 1)
        let eased = GlassShatterView_ShatterMath.smoothstep(f)
        return fromValue + (toValue - fromValue) * eased
    }

    private func handleTap(now: Date, current: Double) {
        // Resume from wherever we are so mid-flight taps don't jump.
        fromValue = current
        toValue = current < 0.5 ? 1 : 0
        resting = toValue
        anchor = now
    }
}

// MARK: - Stage: revealed background + glass overlay

private struct GlassShatterView_ShatterStage: View {
    let size: CGSize
    let progress: Double   // 0 = intact glass, 1 = fully dispersed (revealed)

    var body: some View {
        ZStack {
            GlassShatterView_RevealedBackground()           // opaque floor -- never blank
            GlassShatterView_GlassOverlay(progress: progress)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}

// The always-legible destination view behind the glass.
private struct GlassShatterView_RevealedBackground: View {
    var body: some View {
        GeometryReader { proxy in
            let s = min(proxy.size.width, proxy.size.height)
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.10, blue: 0.20),
                        Color(red: 0.16, green: 0.09, blue: 0.26)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [
                        Color(red: 0.42, green: 0.55, blue: 0.95).opacity(0.55),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: s * 0.65
                )
                Image(systemName: "sparkles")
                    .font(.system(size: s * 0.30, weight: .regular))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.98, green: 0.99, blue: 1.0),
                                Color(red: 0.74, green: 0.82, blue: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color(red: 0.30, green: 0.45, blue: 0.95).opacity(0.6),
                            radius: s * 0.05)
            }
        }
    }
}

// MARK: - Glass overlay (Canvas-rendered shards)

private struct GlassShatterView_GlassOverlay: View {
    let progress: Double

    var body: some View {
        Canvas { context, size in
            let p = max(0, min(1, progress))
            for shard in GlassShatterView_ShatterMath.shards {
                draw(shard, into: context, size: size, p: p)
            }
            // Hairline impact-point spark while still mostly intact.
            if p < 0.18 {
                drawImpactSpark(in: context, size: size, p: p)
            }
        }
        .allowsHitTesting(false)
    }

    private func draw(_ shard: GlassShatterView_Shard, into context: GraphicsContext, size: CGSize, p: Double) {
        let st = GlassShatterView_ShatterMath.state(for: shard, p: p, size: size)
        guard st.opacity > 0.001 else { return }

        var layer = context
        layer.opacity = st.opacity
        layer.translateBy(x: st.position.x, y: st.position.y)
        layer.rotate(by: .radians(st.angle))

        // GlassShatterView_Shard path is built around its own centroid -> rotation pivots on center.
        let path = shard.localPath(size: size)

        // Base glass body.
        layer.fill(path, with: .color(glassTint(shard)))

        // Raking specular band, defined in shard-LOCAL coordinates so the
        // highlight sweeps across the shard as the layer rotates.
        let bounds = shard.localBounds(size: size)
        layer.drawLayer { inner in
            inner.clip(to: path)
            inner.fill(
                Path(bounds),
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: Color.white.opacity(0.0), location: 0.30),
                        .init(color: Color.white.opacity(0.85), location: 0.50),
                        .init(color: Color.white.opacity(0.0), location: 0.70)
                    ]),
                    startPoint: CGPoint(x: bounds.minX, y: bounds.minY),
                    endPoint: CGPoint(x: bounds.maxX, y: bounds.maxY)
                )
            )
        }

        // Crisp edge so the crack gaps read.
        layer.stroke(
            path,
            with: .color(Color(red: 0.80, green: 0.90, blue: 1.0).opacity(0.55)),
            lineWidth: max(0.5, size.width * 0.0035)
        )
    }

    private func glassTint(_ shard: GlassShatterView_Shard) -> Color {
        // Subtle per-shard tint variation, derived deterministically.
        let v = shard.tintBias
        return Color(
            red: 0.62 + 0.10 * v,
            green: 0.74 + 0.08 * v,
            blue: 0.92 + 0.06 * v
        ).opacity(0.34)
    }

    private func drawImpactSpark(in context: GraphicsContext, size: CGSize, p: Double) {
        let center = CGPoint(x: GlassShatterView_ShatterMath.impact.x * size.width,
                             y: GlassShatterView_ShatterMath.impact.y * size.height)
        let r = size.width * 0.05 * (1 - p / 0.18)
        guard r > 0 else { return }
        let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(colors: [Color.white.opacity(0.9), Color.white.opacity(0.0)]),
                center: center, startRadius: 0, endRadius: r
            )
        )
    }
}

// MARK: - GlassShatterView_Shard model

private struct GlassShatterView_Shard {
    /// Centroid in normalized [0,1] space.
    let centroid: CGPoint
    /// Polygon vertices in normalized [0,1] space.
    let vertices: [CGPoint]
    /// Outward + jittered launch velocity, normalized units per unit progress-time.
    let velocity: CGVector
    /// Angular velocity (radians per unit progress-time).
    let spin: Double
    /// Per-shard tint bias in [-1, 1].
    let tintBias: Double

    /// Path built around the shard's own centroid (local space), scaled to `size`.
    func localPath(size: CGSize) -> Path {
        var path = Path()
        guard let first = vertices.first else { return path }
        let cx = centroid.x
        let cy = centroid.y
        func map(_ pt: CGPoint) -> CGPoint {
            CGPoint(x: (pt.x - cx) * size.width, y: (pt.y - cy) * size.height)
        }
        path.move(to: map(first))
        for v in vertices.dropFirst() {
            path.addLine(to: map(v))
        }
        path.closeSubpath()
        return path
    }

    func localBounds(size: CGSize) -> CGRect {
        localPath(size: size).boundingRect
    }
}

private struct GlassShatterView_ShardState {
    let position: CGPoint  // centroid position in screen space
    let angle: Double      // radians
    let opacity: Double
}

// MARK: - Math / mesh (deterministic, computed once)

private enum GlassShatterView_ShatterMath {

    /// Impact point in normalized space.
    static let impact = CGPoint(x: 0.5, y: 0.46)

    /// Precomputed spider-web fracture -- radial spokes x concentric rings.
    /// Built once with a seeded generator so the mesh NEVER re-randomizes.
    static let shards: [GlassShatterView_Shard] = buildShards()

    /// Smoothstep easing.
    static func smoothstep(_ x: Double) -> Double {
        let t = max(0, min(1, x))
        return t * t * (3 - 2 * t)
    }

    /// Maps a 0->1 loop phase to a smoothed 0->1->0 triangle (shatter then reassemble).
    static func loopProgress(_ phase: Double) -> Double {
        let tri: Double
        if phase < 0.5 {
            tri = phase / 0.5             // 0 -> 1
        } else {
            tri = (1 - phase) / 0.5       // 1 -> 0
        }
        return smoothstep(tri)
    }

    /// Physics for one shard at normalized progress p in [0,1].
    /// Identical mapping is used by both demo and interactive modes.
    static func state(for shard: GlassShatterView_Shard, p: Double, size: CGSize) -> GlassShatterView_ShardState {
        // Base (intact) centroid in screen space.
        let baseX = shard.centroid.x * size.width
        let baseY = shard.centroid.y * size.height

        // Ease-in launch so shards stay put at p~0 then accelerate.
        let launch = p * p   // quadratic ramp

        let dx = shard.velocity.dx * launch * size.width
        // Gravity grows with progress^2; positive y is downward.
        let gravity = 0.9 * (p * p) * size.height
        let dy = shard.velocity.dy * launch * size.height + gravity

        let position = CGPoint(x: baseX + dx, y: baseY + dy)
        let angle = shard.spin * p

        // Stay fully opaque until late, then fade so they don't pop at the edge.
        let opacity: Double
        if p < 0.72 {
            opacity = 1.0
        } else {
            opacity = max(0, 1 - (p - 0.72) / 0.28)
        }
        return GlassShatterView_ShardState(position: position, angle: angle, opacity: opacity)
    }

    // MARK: Mesh construction

    private static func buildShards() -> [GlassShatterView_Shard] {
        var rng = GlassShatterView_SeededRNG(seed: 0x9E3779B97F4A7C15)
        var result: [GlassShatterView_Shard] = []

        let cx = impact.x
        let cy = impact.y
        let spokes = 9
        // Last ring overflows the frame so the intact pane fully covers the
        // rectangle (the overflow is caught by .clipped() on GlassShatterView_ShatterStage),
        // leaving no bare corners or floating boundary seam.
        let rings: [Double] = [0.0, 0.16, 0.34, 0.58, 1.25]

        // Per-spoke angle with slight jitter, sorted around the circle.
        var angles: [Double] = []
        for i in 0..<spokes {
            let base = (Double(i) / Double(spokes)) * 2 * .pi
            let jitter = (rng.nextUnit() - 0.5) * (2 * .pi / Double(spokes)) * 0.5
            angles.append(base + jitter)
        }
        angles.sort()

        func ringPoint(angle: Double, radius: Double) -> CGPoint {
            // Per-vertex radial jitter for an irregular, glass-like break.
            let jr = radius * (1 + (rng.nextUnit() - 0.5) * 0.18)
            let x = cx + cos(angle) * jr
            let y = cy + sin(angle) * jr
            return CGPoint(x: x, y: y)
        }

        // Precompute the lattice of ring points per spoke.
        var lattice: [[CGPoint]] = []
        for a in angles {
            var col: [CGPoint] = []
            for r in rings {
                col.append(r == 0 ? CGPoint(x: cx, y: cy) : ringPoint(angle: a, radius: r))
            }
            lattice.append(col)
        }

        // Build triangle/quad cells between adjacent spokes and rings.
        for s in 0..<spokes {
            let s2 = (s + 1) % spokes
            for ri in 0..<(rings.count - 1) {
                let inner = rings[ri]
                let verts: [CGPoint]
                if inner == 0 {
                    // Innermost cells are triangles fanning from the impact point.
                    verts = [
                        CGPoint(x: cx, y: cy),
                        lattice[s][ri + 1],
                        lattice[s2][ri + 1]
                    ]
                } else {
                    // Outer cells are quads (two spokes x two rings).
                    verts = [
                        lattice[s][ri],
                        lattice[s][ri + 1],
                        lattice[s2][ri + 1],
                        lattice[s2][ri]
                    ]
                }
                result.append(makeShard(vertices: verts, rng: &rng))
            }
        }
        return result
    }

    private static func makeShard(vertices: [CGPoint], rng: inout GlassShatterView_SeededRNG) -> GlassShatterView_Shard {
        // Centroid = average of vertices.
        var sx: Double = 0
        var sy: Double = 0
        for v in vertices {
            sx += v.x
            sy += v.y
        }
        let n = Double(vertices.count)
        let centroid = CGPoint(x: sx / n, y: sy / n)

        // Outward direction from the impact point.
        var ux = centroid.x - impact.x
        var uy = centroid.y - impact.y
        let len = max(0.0001, (ux * ux + uy * uy).squareRoot())
        ux /= len
        uy /= len

        // Speed scales with distance (outer shards fly farther) + jitter.
        let speed = 0.55 + len * 1.4 + (rng.nextUnit() - 0.5) * 0.25
        let tangentialJitter = (rng.nextUnit() - 0.5) * 0.30
        // A little tangential spread for a natural scatter.
        let vx = ux * speed - uy * tangentialJitter
        let vy = uy * speed + ux * tangentialJitter

        let spin = (rng.nextUnit() - 0.5) * 7.0       // radians over full progress
        let tintBias = (rng.nextUnit() - 0.5) * 2.0   // [-1, 1]

        return GlassShatterView_Shard(
            centroid: centroid,
            vertices: vertices,
            velocity: CGVector(dx: vx, dy: vy),
            spin: spin,
            tintBias: tintBias
        )
    }
}

// MARK: - Seeded RNG (SplitMix64) -- deterministic, so the mesh is stable

private struct GlassShatterView_SeededRNG {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Uniform Double in [0, 1).
    mutating func nextUnit() -> Double {
        Double(next() >> 11) * (1.0 / 9007199254740992.0)
    }
}
