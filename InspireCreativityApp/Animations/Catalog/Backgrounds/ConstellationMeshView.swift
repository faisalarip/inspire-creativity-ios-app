// catalog-id: bg-constellation-mesh
import SwiftUI

// MARK: - Constellation Mesh
// Free-floating points drift in a Canvas and draw links between any two
// within a proximity radius (opacity falls off by distance), forming a
// constantly reforming network graph. A tap drops a bright node the web
// latches onto. demo == true self-drives by injecting a synthetic node.

struct ConstellationMeshView: View {
    var demo: Bool = false

    // A single node in the lattice. Positions are derived as a pure function
    // of elapsed time from these immutable seed values, so no per-frame state
    // mutation is needed (avoids the "modify state during update" trap and is
    // frame-rate independent).
    struct Node: Identifiable {
        let id: UUID
        var origin: CGPoint      // unit space 0...1
        var velocity: CGVector   // unit / second
        var radius: CGFloat      // unit (fraction of min dimension)
        var brightness: CGFloat  // 0...1 base glow weight
        var birth: Date          // for glow fade-in/out on seeded/user nodes
        var isAccent: Bool       // brighter, latch-on node
    }

    @State private var start: Date = .init()
    @State private var baseNodes: [Node] = ConstellationMeshView.makeBaseNodes()
    @State private var userNodes: [Node] = []

    // Tuning
    private let proximityUnit: CGFloat = 0.30   // link radius in unit space
    private let userNodeCap: Int = 12
    private let demoCycle: Double = 2.2         // seconds per synthetic node

    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geo in
                canvas(date: timeline.date, size: geo.size)
                    .contentShape(Rectangle())
                    .gesture(tapGesture(in: geo.size))
            }
        }
        .background(Self.backdrop)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    // MARK: Background

    private static let backdrop = Color(red: 0.039, green: 0.039, blue: 0.047)

    // MARK: Canvas

    private func canvas(date: Date, size: CGSize) -> some View {
        let t = date.timeIntervalSince(start)
        let dim = min(size.width, size.height)
        let proximity = proximityUnit * dim

        // Resolve every node's absolute position + live alpha for this frame.
        let live = resolvedNodes(date: date, t: t, size: size)

        return Canvas { context, _ in
            drawLinks(in: &context, nodes: live, proximity: proximity)
            drawNodes(in: &context, nodes: live, dim: dim)
        }
    }

    // A node resolved to screen space for one frame.
    struct ResolvedNode {
        var point: CGPoint
        var radius: CGFloat
        var alpha: CGFloat
        var isAccent: Bool
    }

    private func resolvedNodes(date: Date, t: TimeInterval, size: CGSize) -> [ResolvedNode] {
        let dim = min(size.width, size.height)
        var out: [ResolvedNode] = []
        out.reserveCapacity(baseNodes.count + userNodes.count + 1)

        for node in baseNodes {
            out.append(resolve(node, date: date, t: t, size: size, dim: dim, fade: false))
        }
        for node in userNodes {
            out.append(resolve(node, date: date, t: t, size: size, dim: dim, fade: true))
        }
        if demo, let synthetic = syntheticNode(t: t) {
            out.append(resolve(synthetic, date: date, t: t, size: size, dim: dim, fade: true))
        }
        return out
    }

    private func resolve(_ node: Node, date: Date, t: TimeInterval, size: CGSize, dim: CGFloat, fade: Bool) -> ResolvedNode {
        // Base nodes drift on absolute time; user/synthetic nodes drift from
        // their own birth so a tapped node renders AT the tap point (elapsed≈0)
        // and the web latches on there, rather than being displaced by global t.
        let elapsed = fade ? date.timeIntervalSince(node.birth) : t
        let ux = Self.fold(node.origin.x + node.velocity.dx * CGFloat(elapsed))
        let uy = Self.fold(node.origin.y + node.velocity.dy * CGFloat(elapsed))
        let point = CGPoint(x: ux * size.width, y: uy * size.height)

        var alpha = node.brightness
        if fade {
            // Glow fades in fast, then eases down over ~5s but never vanishes
            // entirely for base/user nodes — keeps the tile legible.
            let age = date.timeIntervalSince(node.birth)
            let pulse = max(0.0, 1.0 - age / 5.0)
            alpha = node.brightness * (0.45 + 0.55 * CGFloat(pulse))
        }
        return ResolvedNode(point: point,
                            radius: node.radius * dim,
                            alpha: min(1.0, max(0.18, alpha)),
                            isAccent: node.isAccent)
    }

    // MARK: Drawing

    private func drawLinks(in context: inout GraphicsContext, nodes: [ResolvedNode], proximity: CGFloat) {
        guard nodes.count > 1 else { return }
        let prox2 = proximity * proximity
        for i in 0..<(nodes.count - 1) {
            let a = nodes[i]
            for j in (i + 1)..<nodes.count {
                let b = nodes[j]
                let dx = a.point.x - b.point.x
                let dy = a.point.y - b.point.y
                let d2 = dx * dx + dy * dy
                guard d2 < prox2, d2 > 0 else { continue }
                let dist = sqrt(d2)
                let falloff = 1.0 - dist / proximity            // 0...1
                let accent = a.isAccent || b.isAccent
                let alpha = falloff * (accent ? 0.9 : 0.5)
                strokeLink(in: &context, from: a.point, to: b.point, alpha: alpha, accent: accent)
            }
        }
    }

    private func strokeLink(in context: inout GraphicsContext, from: CGPoint, to: CGPoint, alpha: CGFloat, accent: Bool) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        let color = accent ? Self.accentColor : Self.lineColor
        context.stroke(path, with: .color(color.opacity(Double(alpha))), lineWidth: accent ? 1.3 : 0.8)
    }

    private func drawNodes(in context: inout GraphicsContext, nodes: [ResolvedNode], dim: CGFloat) {
        for node in nodes {
            let r = node.radius
            let rect = CGRect(x: node.point.x - r, y: node.point.y - r, width: r * 2, height: r * 2)
            let core = node.isAccent ? Self.accentColor : Self.nodeColor

            // Soft halo
            let haloR = r * (node.isAccent ? 3.4 : 2.2)
            let haloRect = CGRect(x: node.point.x - haloR, y: node.point.y - haloR, width: haloR * 2, height: haloR * 2)
            context.fill(Path(ellipseIn: haloRect),
                         with: .radialGradient(
                            Gradient(colors: [core.opacity(Double(node.alpha) * 0.35), core.opacity(0.0)]),
                            center: node.point, startRadius: 0, endRadius: haloR))

            // Core dot
            context.fill(Path(ellipseIn: rect), with: .color(core.opacity(Double(node.alpha))))
        }
    }

    // MARK: Palette

    private static let lineColor = Color(red: 0.46, green: 0.62, blue: 0.95)
    private static let nodeColor = Color(red: 0.78, green: 0.86, blue: 1.0)
    private static let accentColor = Color(red: 0.55, green: 0.95, blue: 0.85)

    // MARK: Interaction

    private func tapGesture(in size: CGSize) -> some Gesture {
        SpatialTapGesture(coordinateSpace: .local)
            .onEnded { value in
                addNode(at: value.location, in: size)
            }
    }

    private func addNode(at location: CGPoint, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let unit = CGPoint(x: location.x / size.width, y: location.y / size.height)
        let node = Node(id: UUID(),
                        origin: CGPoint(x: Self.clampUnit(unit.x), y: Self.clampUnit(unit.y)),
                        velocity: CGVector(dx: CGFloat.random(in: -0.035...0.035),
                                           dy: CGFloat.random(in: -0.035...0.035)),
                        radius: 0.018,
                        brightness: 1.0,
                        birth: Date(),
                        isAccent: true)
        userNodes.append(node)
        if userNodes.count > userNodeCap {
            userNodes.removeFirst(userNodes.count - userNodeCap)
        }
    }

    // MARK: Demo synthetic node (pure function of time)

    private func syntheticNode(t: TimeInterval) -> Node? {
        let cycle = demoCycle
        let index = floor(t / cycle)
        let phase = t / cycle - index            // 0...1 within current cycle
        // A fresh location each cycle, walked deterministically around the tile.
        let seed = index * 1.6180339887
        let ux = 0.5 + 0.34 * cos(seed)
        let uy = 0.5 + 0.34 * sin(seed * 1.7)
        // Birth offset so glow fade is driven by phase within the cycle.
        let birth = start.addingTimeInterval(index * cycle)
        _ = phase
        return Node(id: UUID(),
                    origin: CGPoint(x: Self.clampUnit(CGFloat(ux)), y: Self.clampUnit(CGFloat(uy))),
                    velocity: CGVector(dx: 0.02 * cos(seed * 2.3), dy: 0.02 * sin(seed * 1.1)),
                    radius: 0.02,
                    brightness: 1.0,
                    birth: birth,
                    isAccent: true)
    }

    // MARK: Math helpers

    // Fold a value into 0...1 with a triangle wave so motion bounces off the
    // bounds — gives "reflect off edges" for free, deterministically.
    private static func fold(_ v: CGFloat) -> CGFloat {
        let m = (v.truncatingRemainder(dividingBy: 2) + 2).truncatingRemainder(dividingBy: 2)
        return m < 1 ? m : 2 - m
    }

    private static func clampUnit(_ v: CGFloat) -> CGFloat {
        min(1.0, max(0.0, v))
    }

    // MARK: Seeded base lattice

    private static func makeBaseNodes() -> [Node] {
        var rng = SeededGenerator(seed: 0xC0FFEE)
        let count = 44
        var nodes: [Node] = []
        nodes.reserveCapacity(count)
        for _ in 0..<count {
            let ox = CGFloat.random(in: 0.02...0.98, using: &rng)
            let oy = CGFloat.random(in: 0.02...0.98, using: &rng)
            let vx = CGFloat.random(in: -0.03...0.03, using: &rng)
            let vy = CGFloat.random(in: -0.03...0.03, using: &rng)
            let r = CGFloat.random(in: 0.006...0.013, using: &rng)
            let b = CGFloat.random(in: 0.55...0.95, using: &rng)
            nodes.append(Node(id: UUID(),
                              origin: CGPoint(x: ox, y: oy),
                              velocity: CGVector(dx: vx, dy: vy),
                              radius: r,
                              brightness: b,
                              birth: Date(timeIntervalSince1970: 0), // no fade
                              isAccent: false))
        }
        return nodes
    }

    // Small deterministic RNG so the seed lattice is stable across launches.
    struct SeededGenerator: RandomNumberGenerator {
        private var state: UInt64
        init(seed: UInt64) { state = seed != 0 ? seed : 0x9E3779B97F4A7C15 }
        mutating func next() -> UInt64 {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return state
        }
    }
}
