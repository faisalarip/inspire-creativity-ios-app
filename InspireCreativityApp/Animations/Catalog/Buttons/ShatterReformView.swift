// catalog-id: btn-shatter-reform
import SwiftUI

// MARK: - ShatterReformView
// An error-state button that shatters into angular glass shards which scatter
// outward, then magnetically reassemble into the intact button.
//
// demo == true  -> self-driving PhaseAnimator loop (no haptics, never blank).
// demo == false -> tap to trigger the shatter -> reform sequence (with haptics).
struct ShatterReformView: View {
    var demo: Bool = false

    // Tap trigger for the interactive PhaseAnimator.
    @State private var tapCount: Int = 0

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let side = min(size.width, size.height)
            // Inset the button so scatter displacement stays inside the frame.
            let buttonSide = side * 0.58
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            ZStack {
                if demo {
                    demoBody(buttonSide: buttonSide, center: center)
                } else {
                    interactiveBody(buttonSide: buttonSide, center: center)
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Demo (auto-looping)

    @ViewBuilder
    private func demoBody(buttonSide: CGFloat, center: CGPoint) -> some View {
        PhaseAnimator(ShatterReformView_ShatterPhase.allCases) { phase in
            ShatterReformView_ShardCanvas(
                shards: Self.shards,
                progress: phase.progress,
                buttonSide: buttonSide,
                center: center
            )
        } animation: { phase in
            phase.animation
        }
    }

    // MARK: Interactive (tap-driven)

    @ViewBuilder
    private func interactiveBody(buttonSide: CGFloat, center: CGPoint) -> some View {
        PhaseAnimator(ShatterReformView_ShatterPhase.allCases, trigger: tapCount) { phase in
            ShatterReformView_ShardCanvas(
                shards: Self.shards,
                progress: phase.progress,
                buttonSide: buttonSide,
                center: center
            )
            .contentShape(Rectangle())
            .sensoryFeedback(.error, trigger: phase) { _, newValue in
                newValue == .scattered
            }
            .sensoryFeedback(.success, trigger: phase) { _, newValue in
                newValue == .reformed
            }
        } animation: { phase in
            phase.animation
        }
        .contentShape(Rectangle())
        .onTapGesture {
            tapCount += 1
        }
    }

    // MARK: Precomputed shard geometry (deterministic, computed once)

    static let shards: [ShatterReformView_ShatterShard] = ShatterReformView_ShatterShard.makeShards()
}

// MARK: - Phases

private enum ShatterReformView_ShatterPhase: CaseIterable, Equatable {
    case intact      // fully assembled, resting beat
    case scattered   // glass exploded outward (capped within frame)
    case reformed    // magnetically snapped back together

    // Maps each phase to a single 0...1 scatter progress.
    var progress: CGFloat {
        switch self {
        case .intact:    return 0
        case .scattered: return 1
        case .reformed:  return 0
        }
    }

    // Per-phase animation curve: explosive into scatter, springy magnetic reform,
    // gentle hold before re-shattering.
    var animation: Animation {
        switch self {
        case .scattered:
            // Sharp outward burst.
            return .easeOut(duration: 0.45)
        case .reformed:
            // Magnetic snap-back: overshoot + settle.
            return .interpolatingSpring(stiffness: 180, damping: 12)
                .delay(0.12)
        case .intact:
            // Rest beat so the intact button is legible before the next break.
            return .easeInOut(duration: 0.35).delay(1.1)
        }
    }
}

// MARK: - Shard model

struct ShatterReformView_ShatterShard: Identifiable {
    let id: Int
    // Polygon vertices in unit space (0...1) relative to the button rect.
    let unitPoints: [CGPoint]
    // Centroid in unit space.
    let unitCentroid: CGPoint
    // Direction the shard flies when scattered (scaled at draw time).
    let scatterDir: CGVector
    // Peak rotation in degrees at full scatter.
    let scatterRotation: Double
    // Slight color variance to read as faceted glass.
    let tintBias: CGFloat

    // Builds ~18 angular shards via a deterministic radial Voronoi-ish partition.
    static func makeShards() -> [ShatterReformView_ShatterShard] {
        var rng = ShatterReformView_ShatterRNG(seed: 0xC0FFEE)
        let center = CGPoint(x: 0.5, y: 0.5)

        // Fracture origin slightly off-center for a more believable impact point.
        let impact = CGPoint(x: 0.42, y: 0.38)

        // Generate ring vertices around the impact, then fan facets between
        // consecutive rays. An inner ring + the square boundary gives glass facets.
        let rayCount = 9
        var rays: [[CGPoint]] = []
        for i in 0..<rayCount {
            let baseAngle = (Double(i) / Double(rayCount)) * 2.0 * Double.pi
            let span = (2.0 * Double.pi / Double(rayCount)) * 0.55
            let jitter = (rng.nextUnit() - 0.5) * span
            let angle: Double = baseAngle + jitter
            let innerR: CGFloat = 0.18 + CGFloat(rng.nextUnit()) * 0.10
            let inner = CGPoint(
                x: impact.x + cgCos(angle) * innerR,
                y: impact.y + cgSin(angle) * innerR
            )
            let outer = Self.projectToUnitSquare(from: impact, angle: angle)
            rays.append([inner, outer])
        }

        var result: [ShatterReformView_ShatterShard] = []
        var nextID = 0

        // Inner cap triangles fanning from impact to inner ring.
        for i in 0..<rayCount {
            let a = rays[i][0]
            let b = rays[(i + 1) % rayCount][0]
            let poly: [CGPoint] = [impact, a, b]
            result.append(Self.buildShard(id: nextID, unit: poly, center: center, rng: &rng))
            nextID += 1
        }

        // Outer ring quads between inner ring and the square boundary.
        for i in 0..<rayCount {
            let innerA = rays[i][0]
            let outerA = rays[i][1]
            let innerB = rays[(i + 1) % rayCount][0]
            let outerB = rays[(i + 1) % rayCount][1]
            let poly: [CGPoint] = [innerA, outerA, outerB, innerB]
            result.append(Self.buildShard(id: nextID, unit: poly, center: center, rng: &rng))
            nextID += 1
        }

        return result
    }

    private static func buildShard(
        id: Int,
        unit: [CGPoint],
        center: CGPoint,
        rng: inout ShatterReformView_ShatterRNG
    ) -> ShatterReformView_ShatterShard {
        let centroid = Self.centroidOf(unit)
        // Scatter direction: radially away from the button center.
        var dx: CGFloat = centroid.x - center.x
        var dy: CGFloat = centroid.y - center.y
        let len: CGFloat = max(0.001, (dx * dx + dy * dy).squareRoot())
        dx /= len
        dy /= len
        // Add a little tangential swirl so it doesn't read as a pure radial puff.
        let swirl: CGFloat = CGFloat(rng.nextUnit() - 0.5) * 0.5
        let mag: CGFloat = 0.75 + CGFloat(rng.nextUnit()) * 0.35
        let dir = CGVector(
            dx: dx * mag + (-dy) * swirl,
            dy: dy * mag + dx * swirl
        )
        let rotation: Double = (rng.nextUnit() - 0.5) * 90.0
        let tint = CGFloat(rng.nextUnit())
        return ShatterReformView_ShatterShard(
            id: id,
            unitPoints: unit,
            unitCentroid: centroid,
            scatterDir: dir,
            scatterRotation: rotation,
            tintBias: tint
        )
    }

    private static func centroidOf(_ pts: [CGPoint]) -> CGPoint {
        guard !pts.isEmpty else { return CGPoint(x: 0.5, y: 0.5) }
        var sx: CGFloat = 0
        var sy: CGFloat = 0
        for p in pts {
            sx += p.x
            sy += p.y
        }
        return CGPoint(x: sx / CGFloat(pts.count), y: sy / CGFloat(pts.count))
    }

    // Casts a ray from `origin` at `angle` to the boundary of the unit square.
    private static func projectToUnitSquare(from origin: CGPoint, angle: Double) -> CGPoint {
        let dx: CGFloat = cgCos(angle)
        let dy: CGFloat = cgSin(angle)
        var t: CGFloat = CGFloat.greatestFiniteMagnitude
        if dx > 0.0001 { t = min(t, (1 - origin.x) / dx) }
        if dx < -0.0001 { t = min(t, (0 - origin.x) / dx) }
        if dy > 0.0001 { t = min(t, (1 - origin.y) / dy) }
        if dy < -0.0001 { t = min(t, (0 - origin.y) / dy) }
        if t == CGFloat.greatestFiniteMagnitude { t = 0.5 }
        return CGPoint(x: origin.x + dx * t, y: origin.y + dy * t)
    }
}

// Small trig wrappers annotated to keep the type-checker fast.
private func cgCos(_ a: Double) -> CGFloat { CGFloat(cos(a)) }
private func cgSin(_ a: Double) -> CGFloat { CGFloat(sin(a)) }

// MARK: - Deterministic RNG (so shard geometry is identical every init)

struct ShatterReformView_ShatterRNG {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed != 0 ? seed : 0x9E3779B97F4A7C15 }

    mutating func next() -> UInt64 {
        // xorshift64*
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 0x2545F4914F6CDD1D
    }

    // Returns a value in 0...1.
    mutating func nextUnit() -> Double {
        let v = next() >> 11 // top 53 bits
        return Double(v) / Double(UInt64(1) << 53)
    }
}

// MARK: - Shard rendering

private struct ShatterReformView_ShardCanvas: View {
    let shards: [ShatterReformView_ShatterShard]
    let progress: CGFloat // 0 = intact, 1 = fully scattered
    let buttonSide: CGFloat
    let center: CGPoint

    // Scatter is capped so shards stay inside the frame; opacity is floored
    // so no frame is ever blank.
    private let maxScatter: CGFloat = 0.30 // fraction of buttonSide
    private let opacityFloor: Double = 0.46

    var body: some View {
        ZStack {
            ForEach(shards) { shard in
                shardShape(shard)
            }
            label
        }
    }

    @ViewBuilder
    private func shardShape(_ shard: ShatterReformView_ShatterShard) -> some View {
        let displacement = shardDisplacement(shard)
        let rot: Double = shard.scatterRotation * Double(progress)
        let op: Double = shardOpacity()

        ShatterReformView_ShardPath(unitPoints: shard.unitPoints, buttonSide: buttonSide, center: center)
            .fill(shardGradient(shard))
            .overlay(shardEdge(shard))
            .rotationEffect(.degrees(rot), anchor: shardAnchor(shard))
            .offset(x: displacement.dx, y: displacement.dy)
            .opacity(op)
            .compositingGroup()
            .shadow(
                color: Color(red: 0.0, green: 0.0, blue: 0.0).opacity(0.28 * Double(progress)),
                radius: 3.0 * progress,
                x: displacement.dx * 0.08,
                y: 2.0 + displacement.dy * 0.08
            )
    }

    @ViewBuilder
    private func shardEdge(_ shard: ShatterReformView_ShatterShard) -> some View {
        ShatterReformView_ShardPath(unitPoints: shard.unitPoints, buttonSide: buttonSide, center: center)
            .stroke(highlightStroke(), lineWidth: 0.75)
    }

    // The intact/reformed label; fades in as shards close up.
    @ViewBuilder
    private var label: some View {
        let labelOpacity: Double = max(0.0, 1.0 - Double(progress) * 2.2)
        Text("Confirm")
            .font(.system(size: buttonSide * 0.16, weight: .semibold, design: .rounded))
            .foregroundStyle(Color(red: 0.96, green: 0.97, blue: 1.0))
            .shadow(color: Color(red: 0.0, green: 0.1, blue: 0.25).opacity(0.5), radius: 1, y: 1)
            .opacity(labelOpacity)
            .allowsHitTesting(false)
    }

    private func shardDisplacement(_ shard: ShatterReformView_ShatterShard) -> CGVector {
        let reach: CGFloat = buttonSide * maxScatter
        return CGVector(
            dx: shard.scatterDir.dx * reach * progress,
            dy: shard.scatterDir.dy * reach * progress
        )
    }

    // Floor opacity at the scatter peak so the tile is never blank.
    private func shardOpacity() -> Double {
        let p: Double = Double(progress)
        // 1.0 at intact, easing to the floor at full scatter.
        return opacityFloor + (1.0 - opacityFloor) * (1.0 - p)
    }

    private func shardAnchor(_ shard: ShatterReformView_ShatterShard) -> UnitPoint {
        UnitPoint(x: shard.unitCentroid.x, y: shard.unitCentroid.y)
    }

    // Faceted glass gradient with slight per-shard brightness variance.
    private func shardGradient(_ shard: ShatterReformView_ShatterShard) -> LinearGradient {
        let b: Double = Double(shard.tintBias)
        let top = Color(
            red: 0.30 + b * 0.22,
            green: 0.55 + b * 0.18,
            blue: 0.80 + b * 0.18
        )
        let bottom = Color(
            red: 0.10 + b * 0.10,
            green: 0.22 + b * 0.12,
            blue: 0.42 + b * 0.16
        )
        return LinearGradient(
            colors: [top, bottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func highlightStroke() -> Color {
        Color(red: 0.85, green: 0.93, blue: 1.0).opacity(0.55)
    }
}

// MARK: - Shard path (unit -> pixel)

private struct ShatterReformView_ShardPath: Shape {
    let unitPoints: [CGPoint]
    let buttonSide: CGFloat
    let center: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard unitPoints.count >= 3 else { return path }
        let origin = CGPoint(
            x: center.x - buttonSide / 2,
            y: center.y - buttonSide / 2
        )
        let mapped: [CGPoint] = unitPoints.map { p in
            CGPoint(
                x: origin.x + p.x * buttonSide,
                y: origin.y + p.y * buttonSide
            )
        }
        path.move(to: mapped[0])
        for i in 1..<mapped.count {
            path.addLine(to: mapped[i])
        }
        path.closeSubpath()
        return path
    }
}
