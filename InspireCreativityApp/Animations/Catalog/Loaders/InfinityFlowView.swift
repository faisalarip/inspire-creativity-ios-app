// catalog-id: ld-infinity-flow
import SwiftUI

/// Infinity Flow — a glowing bead races along a lemniscate (figure-eight) while a
/// gradient comet trail streaks behind it. The bead naturally accelerates through
/// the central crossover pinch and eases on the outer loops (a property of the
/// Gerono parametrization), so it reads as a real bead with momentum on a track.
///
/// Both `demo` states are self-driving via `TimelineView(.animation)` (the spec's
/// interaction is "auto"). `demo == true` is the calm grid-tile loop; `demo == false`
/// is a slightly richer detail variant with a wider, brighter ribbon. Neither uses
/// touch. Bead and trail are sampled from the SAME time-warped parameter inside a
/// single Canvas, so the bead's leading edge always sits exactly on the trail head —
/// no parametric-vs-arclength desync (which is why we avoid `.trim`).
struct InfinityFlowView: View {
    var demo: Bool = false

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                draw(into: &context, size: size, time: timeline.date.timeIntervalSinceReferenceDate)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Self.backdrop)
        .drawingGroup()
    }

    // MARK: - Tunables

    /// Full laps of the figure-eight per second (one lap = the bead visits both lobes once).
    private var lapsPerSecond: Double { demo ? 0.34 : 0.40 }

    /// How far behind the bead, in parametric seconds, the trail extends.
    private var trailSpan: Double { demo ? 0.42 : 0.52 }

    /// Number of trail segments. More = smoother ribbon; this stays cheap in one Canvas.
    private var trailSamples: Int { demo ? 44 : 56 }

    private var trackLineWidth: CGFloat { demo ? 2.2 : 3.0 }
    private var ribbonWidth: CGFloat { demo ? 4.6 : 6.4 }
    private var beadCoreRadius: CGFloat { demo ? 4.2 : 5.6 }

    // MARK: - Palette (literal Color(red:green:blue:) — no app dependencies)

    private static let backdrop = Color(red: 0.039, green: 0.063, blue: 0.078)
    private let trackColor = Color(red: 0.16, green: 0.22, blue: 0.30)
    private let beadGlow  = Color(red: 0.62, green: 0.96, blue: 1.00)

    /// Ribbon endpoints kept as raw RGB tuples so blending never relies on `Color`
    /// equality (which is unreliable across SwiftUI versions and could silently make
    /// the whole trail render white).
    private let trailHeadRGB: (r: Double, g: Double, b: Double) = (0.42, 0.92, 1.00) // bright cyan at the head
    private let trailTailRGB: (r: Double, g: Double, b: Double) = (0.58, 0.38, 1.00) // violet fading into the tail

    // MARK: - Geometry

    /// Lemniscate of Gerono in unit space: x ∈ [-1, 1], y ∈ [-0.5, 0.5].
    /// x = cos(t), y = sin(t)·cos(t).  The natural |P'(t)| peaks at the crossover
    /// (t = π/2, 3π/2) and dips on the lobes, which IS the "momentum" the spec wants.
    private func unitPoint(_ t: Double) -> CGPoint {
        let x = cos(t)
        let y = sin(t) * cos(t)
        return CGPoint(x: x, y: y)
    }

    /// Maps a unit-space point into the view, fitting the 2:1 lemniscate with margin
    /// for the bead glow so nothing clips inside a small (~120pt) tile.
    private func transform(_ p: CGPoint, size: CGSize) -> CGPoint {
        let margin: CGFloat = beadCoreRadius * 2.6 + 6
        let usableW = max(size.width - margin * 2, 1)
        let usableH = max(size.height - margin * 2, 1)
        // Lemniscate spans 2 wide, 1 tall in unit space → scale by the tighter fit.
        let scale = min(usableW / 2.0, usableH / 1.0)
        let cx = size.width / 2
        let cy = size.height / 2
        return CGPoint(x: cx + p.x * scale, y: cy + p.y * scale)
    }

    // MARK: - Rendering

    private func draw(into context: inout GraphicsContext, size: CGSize, time: Double) {
        drawTrack(into: &context, size: size)

        // Leading parameter of the bead. A full lap of the Gerono curve is one 2π period.
        let head = time * lapsPerSecond * 2.0 * .pi

        drawTrail(into: &context, size: size, head: head)
        drawBead(into: &context, size: size, head: head)
    }

    /// Faint full lemniscate underneath — guarantees a never-blank, legible state and
    /// sells the "real track" the bead rides on.
    private func drawTrack(into context: inout GraphicsContext, size: CGSize) {
        var path = Path()
        let steps = 140
        for i in 0...steps {
            let t = (Double(i) / Double(steps)) * 2.0 * .pi
            let pt = transform(unitPoint(t), size: size)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        context.stroke(
            path,
            with: .color(trackColor.opacity(0.55)),
            style: StrokeStyle(lineWidth: trackLineWidth, lineCap: .round, lineJoin: .round)
        )
    }

    /// The comet ribbon. Each consecutive pair of samples is its own short stroke with
    /// an age-based opacity + color blend, so the fade tracks distance-behind-the-bead
    /// (NOT screen position) — correct even where the ribbon crosses itself at center.
    /// Sampling over a fixed parametric span stretches the ribbon where the bead is fast
    /// (the crossover) and compresses it on the slow lobes — free momentum.
    private func drawTrail(into context: inout GraphicsContext, size: CGSize, head: Double) {
        let n = trailSamples
        guard n >= 2 else { return }

        // Precompute points from the tail (oldest) to the head (newest).
        var points: [CGPoint] = []
        points.reserveCapacity(n + 1)
        for i in 0...n {
            let frac = Double(i) / Double(n)          // 0 = tail, 1 = head
            let t = head - trailSpan * (1.0 - frac)
            points.append(transform(unitPoint(t), size: size))
        }

        for i in 0..<n {
            let segFrac = Double(i) / Double(n)        // 0 tail → ~1 head
            // Ease the alpha so the tail dissolves smoothly rather than cutting off.
            let alpha = pow(segFrac, 1.7)
            let color = blend(trailTailRGB, trailHeadRGB, t: segFrac)
            let width = ribbonWidth * (0.35 + 0.65 * segFrac)

            var seg = Path()
            seg.move(to: points[i])
            seg.addLine(to: points[i + 1])
            context.stroke(
                seg,
                with: .color(color.opacity(alpha)),
                style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
            )
        }
    }

    /// Bead = a few stacked circles (large/dim glow → small/bright core) placed exactly
    /// at the leading sample, so it always sits on the trail head.
    private func drawBead(into context: inout GraphicsContext, size: CGSize, head: Double) {
        let center = transform(unitPoint(head), size: size)
        let layers: [(scale: CGFloat, opacity: Double)] = [
            (3.4, 0.16),
            (2.2, 0.28),
            (1.45, 0.55),
            (1.0, 1.0)
        ]
        for layer in layers {
            let r = beadCoreRadius * layer.scale
            let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
            let c = layer.scale <= 1.0 ? Color.white : beadGlow
            context.fill(Path(ellipseIn: rect), with: .color(c.opacity(layer.opacity)))
        }
    }

    // MARK: - Helpers

    /// Linear RGB interpolation between two raw color tuples. Takes tuples directly so
    /// it never depends on `Color` equality.
    private func blend(
        _ a: (r: Double, g: Double, b: Double),
        _ b: (r: Double, g: Double, b: Double),
        t: Double
    ) -> Color {
        let k = min(max(t, 0), 1)
        return Color(
            red: a.r + (b.r - a.r) * k,
            green: a.g + (b.g - a.g) * k,
            blue: a.b + (b.b - a.b) * k
        )
    }
}
