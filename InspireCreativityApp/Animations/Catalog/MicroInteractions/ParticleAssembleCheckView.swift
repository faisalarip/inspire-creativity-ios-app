// catalog-id: mi-particle-assemble-check
import SwiftUI

/// Particle Assemble Check
/// Dozens of scattered dots fly inward via Canvas and lock into the silhouette
/// of a checkmark, the last few settling with a springy jitter, then scatter
/// back out — a self-looping particle assembly.
///
/// - `demo == true`  : a free-running loop driven entirely off the TimelineView
///                     clock (no state) so the tile always looks alive.
/// - `demo == false` : the same self-driving assembly, plus a tap re-triggers a
///                     fresh converge → hold cycle from the moment of touch
///                     (interaction spec is "auto").
struct ParticleAssembleCheckView: View {
    var demo: Bool = false

    // Fixed particle budget (spec: ~40–60, reuse one Canvas).
    private static let particleCount = 52

    // Precomputed ONCE with a seeded RNG — never randomized per frame.
    private let particles: [Particle] = ParticleAssembleCheckView.makeParticles(
        count: ParticleAssembleCheckView.particleCount
    )

    // Loop timing.
    private let period: Double = 3.4

    // Interactive (demo == false): records the moment of the last tap so we can
    // measure elapsed time off the same TimelineView clock.
    @State private var restartDate: Date = .distantPast

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            TimelineView(.animation) { timeline in
                let now = timeline.date
                let progress = phaseProgress(at: now)
                Canvas { context, size in
                    draw(context: context, size: size, side: side, progress: progress)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .modifier(ParticleAssembleCheckView_TapRestart(enabled: !demo, restartDate: $restartDate))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Progress driver

    /// Returns a normalized 0…1 *assembly* progress where:
    ///   0.00–0.45 converge, 0.45–0.65 hold assembled,
    ///   0.65–0.95 scatter, 0.95–1.0 hold scattered.
    private func phaseProgress(at now: Date) -> CGFloat {
        let raw: Double
        if demo {
            // Free-running loop with no @State — stable across redraws.
            let t = now.timeIntervalSinceReferenceDate
            raw = t.truncatingRemainder(dividingBy: period) / period
        } else {
            // Interactive: run one cycle from the last tap. Before any tap we
            // still show a slow ambient loop so the component is never blank.
            if restartDate == .distantPast {
                let t = now.timeIntervalSinceReferenceDate
                raw = t.truncatingRemainder(dividingBy: period) / period
            } else {
                let elapsed = now.timeIntervalSince(restartDate)
                // After one full cycle, settle on the assembled-hold frame.
                raw = elapsed >= period ? 0.55 : (elapsed / period)
            }
        }
        return CGFloat(raw)
    }

    // MARK: - Drawing

    private func draw(context: GraphicsContext, size: CGSize, side: CGFloat, progress: CGFloat) {
        // Map the normalized checkmark box into the available area, centered.
        let inset = side * 0.16
        let boxSide = side - inset * 2.0
        let originX = (size.width - boxSide) / 2.0
        let originY = (size.height - boxSide) / 2.0

        // assembleAmount: 0 = scattered, 1 = locked into the check.
        let assemble = assembleAmount(for: progress)

        let dotRadius = max(1.5, side * 0.022)

        // Soft glow halo behind the check when assembled — adds the "lock" beat.
        if assemble > 0.35 {
            drawHalo(context: context, size: size, side: side, amount: assemble)
        }

        for p in particles {
            // Local arrival timing: late particles start later and overshoot.
            let local = localProgress(global: assemble, delay: p.delay)
            let eased = p.isLate ? overshoot(local) : easeOutCubic(local)

            // Scattered start and assembled target, both in absolute coordinates.
            let start = CGPoint(
                x: originX + p.scatter.x * boxSide,
                y: originY + p.scatter.y * boxSide
            )
            let target = checkTarget(for: p, originX: originX, originY: originY, boxSide: boxSide)

            var pos = lerpPoint(start, target, eased)

            // Residual springy wobble for the last arrivals as they settle.
            if p.isLate {
                let settle = max(0.0, eased - 0.7) / 0.3
                let wobbleAmp = (1.0 - settle) * side * 0.012
                let wx = CGFloat(sin(Double(local) * 18.0 + Double(p.phase)))
                let wy = CGFloat(cos(Double(local) * 16.0 + Double(p.phase)))
                pos.x += wx * wobbleAmp
                pos.y += wy * wobbleAmp
            }

            // Opacity floor so scattered dots stay legible (never blank).
            let opacity = 0.35 + 0.65 * eased
            let color = blend(Self.scatteredRGB, Self.assembledRGB, eased).opacity(opacity)

            // Dots grow slightly as they lock in.
            let r = dotRadius * (0.7 + 0.3 * eased)
            let rect = CGRect(x: pos.x - r, y: pos.y - r, width: r * 2.0, height: r * 2.0)
            context.fill(Path(ellipseIn: rect), with: .color(color))
        }
    }

    private func drawHalo(context: GraphicsContext, size: CGSize, side: CGFloat, amount: CGFloat) {
        let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        let radius = side * 0.42
        let rect = CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2.0, height: radius * 2.0
        )
        let glow = Color(red: 0.36, green: 0.91, blue: 0.62)
        let shading = GraphicsContext.Shading.radialGradient(
            Gradient(colors: [glow.opacity(0.22 * amount), glow.opacity(0.0)]),
            center: center,
            startRadius: 0,
            endRadius: radius
        )
        context.fill(Path(ellipseIn: rect), with: shading)
    }

    // MARK: - Geometry

    /// Two-segment checkmark in a normalized [0,1] box.
    /// A → vertex B → C, BC ≈ 2.5× longer than AB.
    private static let pointA = CGPoint(x: 0.20, y: 0.55)
    private static let pointB = CGPoint(x: 0.42, y: 0.74)
    private static let pointC = CGPoint(x: 0.80, y: 0.28)

    private func checkTarget(for p: Particle, originX: CGFloat, originY: CGFloat, boxSide: CGFloat) -> CGPoint {
        let n: CGPoint
        if p.onFirstSegment {
            n = lerpPoint(Self.pointA, Self.pointB, p.segmentT)
        } else {
            n = lerpPoint(Self.pointB, Self.pointC, p.segmentT)
        }
        return CGPoint(x: originX + n.x * boxSide, y: originY + n.y * boxSide)
    }

    // MARK: - Easing helpers

    /// Convert the phased assembly progress into a 0…1 "assembled" amount with a
    /// hold at the top and a hold at the bottom (never blank).
    private func assembleAmount(for progress: CGFloat) -> CGFloat {
        switch progress {
        case ..<0.45:
            return easeInOut(progress / 0.45)        // converge
        case ..<0.65:
            return 1.0                                // hold assembled
        case ..<0.95:
            return 1.0 - easeInOut((progress - 0.65) / 0.30) // scatter
        default:
            return 0.0                                // hold scattered
        }
    }

    /// Per-particle staggered local progress given a 0…1 delay offset.
    private func localProgress(global: CGFloat, delay: CGFloat) -> CGFloat {
        let span: CGFloat = 0.65 // fraction of the move consumed before all started
        let scaled = (global - delay * span) / (1.0 - span)
        return min(1.0, max(0.0, scaled))
    }

    private func easeInOut(_ t: CGFloat) -> CGFloat {
        let x = min(1.0, max(0.0, t))
        return x * x * (3.0 - 2.0 * x)
    }

    private func easeOutCubic(_ t: CGFloat) -> CGFloat {
        let x = min(1.0, max(0.0, t))
        let inv = 1.0 - x
        return 1.0 - inv * inv * inv
    }

    /// Damped overshoot (back-ease-out style) for the springy late arrivals.
    private func overshoot(_ t: CGFloat) -> CGFloat {
        let x = min(1.0, max(0.0, t))
        let c1: CGFloat = 1.70158
        let c3: CGFloat = c1 + 1.0
        let inv = x - 1.0
        return 1.0 + c3 * inv * inv * inv + c1 * inv * inv
    }

    private func lerpPoint(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    // MARK: - Color

    // Palettes stored as plain RGB tuples so blending never depends on
    // SwiftUI's fragile Color equality.
    private static let scatteredRGB: (Double, Double, Double) = (0.42, 0.78, 0.96) // cool blue
    private static let assembledRGB: (Double, Double, Double) = (0.36, 0.91, 0.62) // success green

    private func blend(_ a: (Double, Double, Double), _ b: (Double, Double, Double), _ t: CGFloat) -> Color {
        let x = Double(min(1.0, max(0.0, t)))
        return Color(
            red: a.0 + (b.0 - a.0) * x,
            green: a.1 + (b.1 - a.1) * x,
            blue: a.2 + (b.2 - a.2) * x
        )
    }

    // MARK: - Particle model & seeded generation

    struct Particle {
        var scatter: CGPoint     // normalized [0,1] start within the box
        var segmentT: CGFloat    // 0…1 along its assigned segment
        var onFirstSegment: Bool // AB vs BC
        var delay: CGFloat       // 0…1 arrival stagger
        var phase: CGFloat       // wobble phase
        var isLate: Bool         // late arrivals overshoot + jitter
    }

    /// Deterministic per-particle randomness, computed once.
    private static func makeParticles(count: Int) -> [Particle] {
        var rng = ParticleAssembleCheckView_SeededGenerator(seed: 0xC0FFEE)

        // Distribute proportional to segment length (BC ≈ 2.5× AB).
        let abLen = distance(pointA, pointB)
        let bcLen = distance(pointB, pointC)
        let firstCount = Int((Double(count) * (abLen / (abLen + bcLen))).rounded())

        var result: [Particle] = []
        result.reserveCapacity(count)

        for i in 0..<count {
            let onFirst = i < firstCount
            let denom = onFirst ? max(1, firstCount) : max(1, count - firstCount)
            let idx = onFirst ? i : (i - firstCount)
            // Even spacing along the segment, nudged slightly for organic feel.
            let baseT = (CGFloat(idx) + 0.5) / CGFloat(denom)
            let jitterT = (CGFloat(rng.nextUnit()) - 0.5) * 0.06
            let segT = min(1.0, max(0.0, baseT + jitterT))

            let scatter = CGPoint(
                x: CGFloat(rng.nextUnit()),
                y: CGFloat(rng.nextUnit())
            )
            let delay = CGFloat(rng.nextUnit())
            let phase = CGFloat(rng.nextUnit()) * .pi * 2.0
            // ~30% of particles are "late" settlers.
            let isLate = rng.nextUnit() > 0.7

            result.append(
                Particle(
                    scatter: scatter,
                    segmentT: segT,
                    onFirstSegment: onFirst,
                    delay: delay,
                    phase: phase,
                    isLate: isLate
                )
            )
        }
        return result
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }
}

// MARK: - Deterministic RNG (SplitMix64)

private struct ParticleAssembleCheckView_SeededGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Returns a Double in [0, 1).
    mutating func nextUnit() -> Double {
        Double(next() >> 11) * (1.0 / 9007199254740992.0)
    }
}

// MARK: - Tap-to-restart modifier (interactive mode only)

private struct ParticleAssembleCheckView_TapRestart: ViewModifier {
    let enabled: Bool
    @Binding var restartDate: Date

    func body(content: Content) -> some View {
        if enabled {
            content.onTapGesture {
                restartDate = Date()
            }
        } else {
            content
        }
    }
}
