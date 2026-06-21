// catalog-id: nav-comet-trail-crumbs
import SwiftUI

// MARK: - Comet Trail Crumbs
// A breadcrumb trail where advancing fires a glowing comet head from the
// current crumb to the next, dragging a tapering, dissolving particle tail.
// The new child crumb lights up on arrival.
//
// demo == true  -> self-driving: the comet perpetually hops crumb -> crumb on
//                  a ~2.6s loop, derived purely from the TimelineView date.
// demo == false -> tap a crumb (or the advance affordance) to fire the comet
//                  toward it; the child crumb reveals when the comet arrives.

struct CometTrailCrumbsView: View {
    var demo: Bool = false

    // Interactive state (demo == false only).
    @State private var fromIndex: Int = 0
    @State private var toIndex: Int = 1
    @State private var revealedCount: Int = 2
    @State private var hopStart: Date = .distantPast
    @State private var arrivalTask: Task<Void, Never>? = nil

    // Tunables.
    private let crumbCount: Int = 4
    private let hopDuration: Double = 1.05
    private let trailParticles: Int = 64

    // Palette (literal colors, no design-system deps).
    private let bg0 = Color(red: 0.043, green: 0.063, blue: 0.086)
    private let bg1 = Color(red: 0.070, green: 0.094, blue: 0.137)
    private let cometCore = Color(red: 0.78, green: 0.92, blue: 1.0)
    private let cometGlow = Color(red: 0.36, green: 0.66, blue: 1.0)
    private let trailWarm = Color(red: 0.56, green: 0.80, blue: 1.0)
    private let crumbLive = Color(red: 0.62, green: 0.86, blue: 1.0)
    private let crumbDim = Color(red: 0.30, green: 0.40, blue: 0.52)

    var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDisappear { arrivalTask?.cancel() }
    }

    // MARK: Layout

    /// Crumb positions along a gentle horizontal arc, derived from size so it
    /// reads at both a 120pt tile and a large detail area.
    private func crumbPositions(in size: CGSize) -> [CGPoint] {
        let n = crumbCount
        guard n > 1 else {
            return [CGPoint(x: size.width / 2, y: size.height / 2)]
        }
        let marginX: CGFloat = max(18, min(size.width, size.height) * 0.16)
        let usableW = max(1, size.width - marginX * 2)
        let midY = size.height * 0.5
        let arc = min(size.height * 0.22, 34)
        var pts: [CGPoint] = []
        pts.reserveCapacity(n)
        for i in 0..<n {
            let f = CGFloat(i) / CGFloat(n - 1)
            let x = marginX + usableW * f
            // Gentle smile arc: lift the ends, dip the middle.
            let y = midY - sin(f * .pi) * arc
            pts.append(CGPoint(x: x, y: y))
        }
        return pts
    }

    private func crumbRadius(in size: CGSize) -> CGFloat {
        max(4.5, min(size.width, size.height) * 0.045)
    }

    // MARK: Content

    private func content(in size: CGSize) -> some View {
        let positions = crumbPositions(in: size)
        return ZStack {
            backdrop
            TimelineView(.animation) { tl in
                let phase = phaseInfo(at: tl.date)
                Canvas { ctx, sz in
                    drawScene(into: &ctx,
                              size: sz,
                              positions: positions,
                              phase: phase)
                }
                .drawingGroup()
            }
            if !demo {
                tapTargets(positions: positions, size: size)
            }
        }
    }

    private var backdrop: some View {
        RadialGradient(
            colors: [bg1, bg0],
            center: .center,
            startRadius: 2,
            endRadius: 220
        )
    }

    /// Invisible tap targets over each crumb for interactive mode.
    private func tapTargets(positions: [CGPoint], size: CGSize) -> some View {
        let r = crumbRadius(in: size)
        let hit = max(r * 2.4, 30)
        return ForEach(positions.indices, id: \.self) { i in
            Circle()
                .fill(Color.white.opacity(0.001))
                .frame(width: hit, height: hit)
                .position(positions[i])
                .contentShape(Circle())
                .onTapGesture { fire(to: i) }
        }
    }

    // MARK: Interaction

    private func fire(to index: Int) {
        guard index != toIndex, index >= 0, index < crumbCount else { return }
        arrivalTask?.cancel()
        fromIndex = toIndex
        toIndex = index
        hopStart = Date()
        let target = index
        let reveal = max(revealedCount, index + 1)
        arrivalTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(hopDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            if toIndex == target {
                revealedCount = reveal
            }
        }
    }

    // MARK: Phase derivation (deterministic from the timeline date)

    struct PhaseInfo {
        var from: Int
        var to: Int
        var progress: Double      // 0...1 eased hop progress
        var raw: Double           // 0...1 linear hop progress
        var revealed: Int         // crumbs currently lit
        var headVisible: Bool     // comet head currently in flight / glowing
    }

    private func phaseInfo(at date: Date) -> PhaseInfo {
        if demo {
            return demoPhase(at: date)
        } else {
            return interactivePhase(at: date)
        }
    }

    /// Self-driving loop: comet walks 0->1->2->3 then resets, on ~2.6s beats
    /// with a brief hold so each crumb reads before the next hop.
    private func demoPhase(at date: Date) -> PhaseInfo {
        let beat: Double = 0.95          // seconds per crumb segment
        let segments = crumbCount - 1
        let loop = beat * Double(segments) + 0.7   // + tail hold
        let t = date.timeIntervalSinceReferenceDate
        let local = t.truncatingRemainder(dividingBy: loop)

        // During the active span the comet hops segment by segment.
        let active = beat * Double(segments)
        if local >= active {
            // Hold on the final crumb, all revealed.
            return PhaseInfo(from: max(0, segments - 1),
                             to: segments,
                             progress: 1,
                             raw: 1,
                             revealed: crumbCount,
                             headVisible: false)
        }
        let segIndex = min(segments - 1, Int(local / beat))
        let within = (local - Double(segIndex) * beat) / beat
        let eased = easeInOut(within)
        return PhaseInfo(from: segIndex,
                         to: segIndex + 1,
                         progress: eased,
                         raw: within,
                         revealed: segIndex + 1 + (within > 0.92 ? 1 : 0),
                         headVisible: true)
    }

    private func interactivePhase(at date: Date) -> PhaseInfo {
        let elapsed = date.timeIntervalSince(hopStart)
        let raw = min(1, max(0, elapsed / hopDuration))
        let inFlight = elapsed >= 0 && elapsed <= hopDuration + 0.25
        return PhaseInfo(from: fromIndex,
                         to: toIndex,
                         progress: easeInOut(raw),
                         raw: raw,
                         revealed: revealedCount,
                         headVisible: inFlight && raw < 1.0)
    }

    private func easeInOut(_ x: Double) -> Double {
        let c = min(1, max(0, x))
        return c * c * (3 - 2 * c)
    }

    // MARK: Drawing

    private func drawScene(into ctx: inout GraphicsContext,
                           size: CGSize,
                           positions: [CGPoint],
                           phase: PhaseInfo) {
        guard positions.count >= 2 else { return }

        drawConnectors(into: &ctx, positions: positions, phase: phase)
        drawCrumbs(into: &ctx, size: size, positions: positions, phase: phase)

        let from = clampIndex(phase.from, positions.count)
        let to = clampIndex(phase.to, positions.count)
        let headPos = lerpPoint(positions[from], positions[to], CGFloat(phase.progress))

        if phase.headVisible {
            drawTrail(into: &ctx,
                      from: positions[from],
                      to: positions[to],
                      progress: phase.progress,
                      headPos: headPos)
            drawCometHead(into: &ctx, at: headPos, size: size, progress: phase.progress)
        }
    }

    private func clampIndex(_ i: Int, _ count: Int) -> Int {
        min(max(0, i), count - 1)
    }

    /// Faint static guide line between consecutive crumbs that have been reached.
    private func drawConnectors(into ctx: inout GraphicsContext,
                                positions: [CGPoint],
                                phase: PhaseInfo) {
        for i in 0..<(positions.count - 1) {
            let reached = (i + 1) < phase.revealed
            let opacity: Double = reached ? 0.18 : 0.06
            var path = Path()
            path.move(to: positions[i])
            path.addLine(to: positions[i + 1])
            ctx.stroke(
                path,
                with: .color(crumbDim.opacity(opacity)),
                style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [2, 5])
            )
        }
    }

    private func drawCrumbs(into ctx: inout GraphicsContext,
                            size: CGSize,
                            positions: [CGPoint],
                            phase: PhaseInfo) {
        let r = crumbRadius(in: size)
        for i in positions.indices {
            let lit = i < phase.revealed
            let isHead = (i == clampIndex(phase.to, positions.count)) && lit
            // Pulse the just-arrived crumb.
            let pulse: CGFloat = (isHead && phase.headVisible == false && phase.progress >= 1)
                ? 1.0 + 0.25 * CGFloat(arrivalPulse(phase))
                : 1.0
            drawCrumbDot(into: &ctx,
                         center: positions[i],
                         radius: r * pulse,
                         lit: lit)
        }
    }

    private func arrivalPulse(_ phase: PhaseInfo) -> Double {
        // Small decaying flash right after arrival (raw near/at 1).
        let x = max(0, min(1, (phase.raw - 0.85) / 0.15))
        return sin(x * .pi)
    }

    private func drawCrumbDot(into ctx: inout GraphicsContext,
                              center: CGPoint,
                              radius r: CGFloat,
                              lit: Bool) {
        let outer = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)

        if lit {
            // Soft halo (additive) for a lit crumb.
            var glow = ctx
            glow.blendMode = .plusLighter
            let haloR = r * 2.4
            let halo = CGRect(x: center.x - haloR, y: center.y - haloR,
                              width: haloR * 2, height: haloR * 2)
            glow.fill(
                Circle().path(in: halo),
                with: .radialGradient(
                    Gradient(colors: [cometGlow.opacity(0.28), .clear]),
                    center: center, startRadius: 0, endRadius: haloR
                )
            )
        }

        // Ring.
        ctx.stroke(
            Circle().path(in: outer.insetBy(dx: -1, dy: -1)),
            with: .color((lit ? crumbLive : crumbDim).opacity(lit ? 0.9 : 0.5)),
            lineWidth: 1.4
        )
        // Core fill.
        ctx.fill(
            Circle().path(in: outer.insetBy(dx: r * 0.34, dy: r * 0.34)),
            with: .color(lit ? crumbLive : crumbDim.opacity(0.55))
        )
    }

    /// Tapering particle tail behind the head. Each particle k sits at the head
    /// position sampled a little earlier in the hop, with a deterministic
    /// perpendicular jitter so it scatters rather than reads as a smooth ribbon.
    private func drawTrail(into ctx: inout GraphicsContext,
                           from: CGPoint,
                           to: CGPoint,
                           progress: Double,
                           headPos: CGPoint) {
        var trail = ctx
        trail.blendMode = .plusLighter

        let dx = to.x - from.x
        let dy = to.y - from.y
        let len = max(0.0001, hypot(dx, dy))
        let nx = -dy / len   // unit perpendicular
        let ny = dx / len

        let n = trailParticles
        let span: Double = 0.42   // how far back (in progress units) the tail reaches
        for k in 0..<n {
            let f = Double(k) / Double(n - 1)         // 0 = head, 1 = tail end
            let sampleP = progress - f * span
            guard sampleP >= 0 else { continue }
            let px = from.x + CGFloat(sampleP) * dx
            let py = from.y + CGFloat(sampleP) * dy

            let jitterAmp = CGFloat(2.6 + 6.0 * f)    // spreads out toward the tail
            let j = (hash01(k) - 0.5) * 2.0 * jitterAmp
            let wobble = sin(Double(k) * 1.7 + progress * 6.0) * Double(2.0 * f)
            let off = j + CGFloat(wobble)
            let cx = px + nx * off
            let cy = py + ny * off

            let taper = (1.0 - f)
            let radius = CGFloat(0.8 + 2.6 * taper * taper)
            let alpha = (0.30 * taper * taper) * (0.6 + 0.4 * Double(hash01(k * 7 + 3)))

            let rect = CGRect(x: cx - radius, y: cy - radius,
                              width: radius * 2, height: radius * 2)
            let mix = trailWarm.opacity(alpha)
            trail.fill(Circle().path(in: rect), with: .color(mix))
        }
    }

    private func drawCometHead(into ctx: inout GraphicsContext,
                               at p: CGPoint,
                               size: CGSize,
                               progress: Double) {
        var glow = ctx
        glow.blendMode = .plusLighter

        let base = max(6, min(size.width, size.height) * 0.05)
        // Slight breathing so the head never reads as a flat dot.
        let pulse = 1.0 + 0.12 * sin(progress * .pi * 4)
        let glowR = base * 2.6 * CGFloat(pulse)
        let glowRect = CGRect(x: p.x - glowR, y: p.y - glowR,
                              width: glowR * 2, height: glowR * 2)
        glow.fill(
            Circle().path(in: glowRect),
            with: .radialGradient(
                Gradient(colors: [
                    cometGlow.opacity(0.55),
                    cometGlow.opacity(0.18),
                    .clear
                ]),
                center: p, startRadius: 0, endRadius: glowR
            )
        )

        // Bright hot core.
        let coreR = base * 0.55
        let coreRect = CGRect(x: p.x - coreR, y: p.y - coreR,
                              width: coreR * 2, height: coreR * 2)
        glow.fill(
            Circle().path(in: coreRect),
            with: .radialGradient(
                Gradient(colors: [Color.white, cometCore.opacity(0.9), .clear]),
                center: p, startRadius: 0, endRadius: coreR
            )
        )
    }

    // MARK: Helpers

    private func lerpPoint(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    /// Deterministic 0...1 hash for stable per-particle jitter.
    private func hash01(_ i: Int) -> CGFloat {
        let x = sin(Double(i) * 127.1 + 311.7) * 43758.5453
        return CGFloat(x - floor(x))
    }
}
