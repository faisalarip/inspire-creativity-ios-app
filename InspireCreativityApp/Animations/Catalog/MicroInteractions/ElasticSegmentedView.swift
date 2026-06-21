// catalog-id: mi-elastic-segmented
import SwiftUI

// MARK: - Elastic Segmented Control
// A selection pill that rubber-bands between segments: the edge moving in the
// direction of travel leads (fast spring, overshoots), the trailing edge lags
// (slow spring), so the capsule momentarily spans the gap before collapsing to
// a single segment width on arrival. The active label crossfades to a bolder
// weight. demo == true self-drives the selection on a ~3s loop.

struct ElasticSegmentedView: View {
    var demo: Bool = false

    private let labels: [String] = ["Day", "Week", "Month"]

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            content(in: size)
                .frame(width: size.width, height: size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if demo {
            ElasticSegmentedView_ElasticSegDemoDriver(labels: labels, canvas: size)
        } else {
            ElasticSegmentedView_ElasticSegInteractive(labels: labels, canvas: size)
        }
    }
}

// MARK: - Shared layout math

private struct ElasticSegmentedView_ElasticSegMetrics {
    let canvas: CGSize
    let count: Int

    // The control occupies a centered, inset band of the canvas so it reads
    // well both in a tiny tile and a large detail area.
    var trackInset: CGFloat { max(6, min(canvas.width, canvas.height) * 0.10) }

    var trackWidth: CGFloat { max(0, canvas.width - trackInset * 2) }

    var trackHeight: CGFloat {
        let h = canvas.height - trackInset * 2
        // Keep the track a sane height regardless of aspect ratio.
        return max(0, min(h, max(28, canvas.height * 0.42)))
    }

    var trackOriginX: CGFloat { trackInset }
    var trackOriginY: CGFloat { (canvas.height - trackHeight) / 2 }

    var segmentWidth: CGFloat {
        guard count > 0 else { return 0 }
        return trackWidth / CGFloat(count)
    }

    var innerPadding: CGFloat { max(3, trackHeight * 0.10) }

    var fontSize: CGFloat { max(9, min(20, trackHeight * 0.34)) }

    var hasRoom: Bool { trackWidth > 1 && trackHeight > 1 }

    // Given the fractional leading/trailing edge indices, return the pill rect
    // in track-local coordinates. The pill is never narrower than one segment.
    func pillRect(leftFrac: Double, rightFrac: Double) -> CGRect {
        let lo = CGFloat(min(leftFrac, rightFrac))
        let hi = CGFloat(max(leftFrac, rightFrac))
        let segW = segmentWidth
        let x = lo * segW + innerPadding
        let span = (hi - lo) * segW
        let w = segW + span - innerPadding * 2
        let y = innerPadding
        let h = trackHeight - innerPadding * 2
        return CGRect(x: x, y: y, width: max(0, w), height: max(0, h))
    }

    func segmentCenterX(_ index: Int) -> CGFloat {
        (CGFloat(index) + 0.5) * segmentWidth
    }
}

// MARK: - Palette (literal colors only; no design-system dependency)

private enum ElasticSegmentedView_ElasticSegPalette {
    static let trackTop = Color(red: 0.12, green: 0.10, blue: 0.18)
    static let trackBottom = Color(red: 0.08, green: 0.07, blue: 0.13)
    static let trackStroke = Color(red: 1.0, green: 1.0, blue: 1.0).opacity(0.06)

    static let pillTop = Color(red: 0.55, green: 0.42, blue: 0.98)
    static let pillBottom = Color(red: 0.38, green: 0.30, blue: 0.92)
    static let pillGlow = Color(red: 0.60, green: 0.48, blue: 1.0)

    static let labelIdle = Color(red: 1.0, green: 1.0, blue: 1.0).opacity(0.45)
    static let labelActive = Color(red: 1.0, green: 1.0, blue: 1.0)
}

// MARK: - The pill renderer (used by both modes)

private struct ElasticSegmentedView_ElasticSegPill: View {
    let rect: CGRect
    let height: CGFloat

    var body: some View {
        let radius = max(4, min(rect.width, height) / 2)
        Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: [ElasticSegmentedView_ElasticSegPalette.pillTop, ElasticSegmentedView_ElasticSegPalette.pillBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
            )
            .frame(width: rect.width, height: rect.height)
            .shadow(color: ElasticSegmentedView_ElasticSegPalette.pillGlow.opacity(0.45), radius: radius * 0.55, y: 1)
            .position(x: rect.midX, y: rect.midY)
    }
}

// MARK: - Track background + label row (shared)

private struct ElasticSegmentedView_ElasticSegTrack: View {
    let metrics: ElasticSegmentedView_ElasticSegMetrics
    let labels: [String]
    let activeIndex: Int
    let activeStrength: Double // 0...1 how "settled" the active label is

    var body: some View {
        ZStack(alignment: .topLeading) {
            background
            labelRow
        }
        .frame(width: metrics.trackWidth, height: metrics.trackHeight)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: metrics.trackHeight / 2, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [ElasticSegmentedView_ElasticSegPalette.trackTop, ElasticSegmentedView_ElasticSegPalette.trackBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: metrics.trackHeight / 2, style: .continuous)
                    .stroke(ElasticSegmentedView_ElasticSegPalette.trackStroke, lineWidth: 1)
            )
    }

    private var labelRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, text in
                segmentLabel(index: index, text: text)
                    .frame(width: metrics.segmentWidth, height: metrics.trackHeight)
            }
        }
    }

    // Two stacked weight variants crossfaded by proximity to the pill keep the
    // label legible on every frame and give the "weight crossfade" effect
    // without relying on contentTransition(.interpolate) on fontWeight.
    private func segmentLabel(index: Int, text: String) -> some View {
        let isActive = index == activeIndex
        let activeAmt = isActive ? activeStrength : 0
        return ZStack {
            Text(text)
                .font(.system(size: metrics.fontSize, weight: .medium))
                .foregroundStyle(ElasticSegmentedView_ElasticSegPalette.labelIdle)
                .opacity(1 - activeAmt)
            Text(text)
                .font(.system(size: metrics.fontSize, weight: .bold))
                .foregroundStyle(ElasticSegmentedView_ElasticSegPalette.labelActive)
                .opacity(activeAmt)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.55)
        .padding(.horizontal, 2)
    }
}

// MARK: - Demo mode (self-driving, pure function of time)

private struct ElasticSegmentedView_ElasticSegDemoDriver: View {
    let labels: [String]
    let canvas: CGSize

    var body: some View {
        let metrics = ElasticSegmentedView_ElasticSegMetrics(canvas: canvas, count: labels.count)
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let state = ElasticSegmentedView_ElasticSegDemoDriver.driveState(time: t, count: labels.count)
            ZStack(alignment: .topLeading) {
                ElasticSegmentedView_ElasticSegTrack(
                    metrics: metrics,
                    labels: labels,
                    activeIndex: state.activeIndex,
                    activeStrength: state.activeStrength
                )
                if metrics.hasRoom {
                    let r = metrics.pillRect(leftFrac: state.leftFrac, rightFrac: state.rightFrac)
                    ElasticSegmentedView_ElasticSegPill(rect: r, height: metrics.trackHeight)
                }
            }
            .frame(width: metrics.trackWidth, height: metrics.trackHeight)
            .position(
                x: metrics.trackOriginX + metrics.trackWidth / 2,
                y: metrics.trackOriginY + metrics.trackHeight / 2
            )
        }
    }

    struct State {
        var leftFrac: Double
        var rightFrac: Double
        var activeIndex: Int
        var activeStrength: Double
    }

    // Pure function of time: cycles through segments, baking the lead/lag
    // asymmetry into the eased ramps so the pill spans the gap mid-travel and
    // collapses to one segment on arrival. Never narrower than one segment.
    private static func driveState(time: Double, count: Int) -> State {
        let dwell: Double = 0.55      // fraction of a step spent settled
        let stepDuration: Double = 1.2
        let cycle = stepDuration * Double(count)
        let phase = time.truncatingRemainder(dividingBy: cycle)
        let stepIndex = Int(phase / stepDuration) % count
        let nextIndex = (stepIndex + 1) % count
        let local = (phase / stepDuration) - Double(Int(phase / stepDuration)) // 0...1 in step

        // The first `dwell` of each step is settled on `stepIndex`; the rest is
        // the transition toward `nextIndex`.
        if local < dwell {
            let from = Double(stepIndex)
            return State(leftFrac: from, rightFrac: from,
                         activeIndex: stepIndex, activeStrength: 1)
        }

        let p = (local - dwell) / (1 - dwell) // 0...1 transition progress
        let from = Double(stepIndex)
        let to = Double(nextIndex)

        // Wrap-around (e.g. 2 -> 0) moves left visually; otherwise right.
        let movingRight = nextIndex > stepIndex

        // Lead edge: fast with overshoot. Trail edge: slow, no overshoot.
        let leadEase = overshoot(p)            // arrives early, overshoots
        let trailEase = easeInOutSlow(p)       // lags behind

        let leadPos = from + (to - from) * leadEase
        let trailPos = from + (to - from) * trailEase

        let left: Double
        let right: Double
        if movingRight {
            // Right edge is the lead; left edge is the trail.
            right = leadPos
            left = trailPos
        } else {
            // Moving left: left edge is the lead; right edge trails.
            left = leadPos
            right = trailPos
        }

        // Active label: hand over weight near the midpoint of travel.
        let handover = smoothstep(p, edge0: 0.35, edge1: 0.75)
        let activeIndex = handover < 0.5 ? stepIndex : nextIndex
        let strength = handover < 0.5 ? (1 - handover * 2) : ((handover - 0.5) * 2)

        return State(leftFrac: left, rightFrac: right,
                     activeIndex: activeIndex, activeStrength: max(0.15, strength))
    }

    // Fast ramp that overshoots past 1 then settles — drives the lead edge.
    private static func overshoot(_ p: Double) -> Double {
        let c = clamp01(p)
        // Slightly compressed time so the lead arrives early.
        let q = clamp01(c * 1.18)
        let s = 1.70158
        let x = q - 1
        return 1 + (s + 1) * x * x * x + s * x * x
    }

    // Slow ease for the trailing edge so it lags behind the lead.
    private static func easeInOutSlow(_ p: Double) -> Double {
        let c = clamp01(p)
        // Delay the start so the trail visibly lags, then ease in-out.
        let q = clamp01((c - 0.12) / 0.88)
        return q < 0.5 ? 4 * q * q * q : 1 - pow(-2 * q + 2, 3) / 2
    }

    private static func smoothstep(_ x: Double, edge0: Double, edge1: Double) -> Double {
        let t = clamp01((x - edge0) / (edge1 - edge0))
        return t * t * (3 - 2 * t)
    }

    private static func clamp01(_ v: Double) -> Double { min(1, max(0, v)) }
}

// MARK: - Interactive mode

private struct ElasticSegmentedView_ElasticSegInteractive: View {
    let labels: [String]
    let canvas: CGSize

    @State private var selectedIndex: Int = 0
    @State private var leadFrac: Double = 0
    @State private var trailFrac: Double = 0
    @State private var activeStrength: Double = 1

    var body: some View {
        let metrics = ElasticSegmentedView_ElasticSegMetrics(canvas: canvas, count: labels.count)
        ZStack(alignment: .topLeading) {
            ElasticSegmentedView_ElasticSegTrack(
                metrics: metrics,
                labels: labels,
                activeIndex: selectedIndex,
                activeStrength: activeStrength
            )
            if metrics.hasRoom {
                let r = metrics.pillRect(leftFrac: leadFrac, rightFrac: trailFrac)
                ElasticSegmentedView_ElasticSegPill(rect: r, height: metrics.trackHeight)
            }
            tapRow(metrics: metrics)
        }
        .frame(width: metrics.trackWidth, height: metrics.trackHeight)
        .position(
            x: metrics.trackOriginX + metrics.trackWidth / 2,
            y: metrics.trackOriginY + metrics.trackHeight / 2
        )
        .sensoryFeedback(.selection, trigger: selectedIndex)
    }

    private func tapRow(metrics: ElasticSegmentedView_ElasticSegMetrics) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, _ in
                Color.clear
                    .frame(width: metrics.segmentWidth, height: metrics.trackHeight)
                    .contentShape(Rectangle())
                    .onTapGesture { select(index) }
            }
        }
    }

    // Direction-dependent springs: the edge moving in the travel direction is
    // the lead (fast, bouncy → overshoot/squash); the opposite edge is the
    // trail (slow, no bounce → lags and spans the gap mid-travel).
    private func select(_ index: Int) {
        guard index != selectedIndex else { return }
        let movingRight = index > selectedIndex
        let target = Double(index)

        let fastSpring = Animation.spring(response: 0.26, dampingFraction: 0.55)
        let slowSpring = Animation.spring(response: 0.46, dampingFraction: 0.85)

        selectedIndex = index

        // leadFrac / trailFrac map to the geometric left/right edges via
        // min/max inside pillRect, so we just animate them with the right
        // springs depending on which edge leads.
        if movingRight {
            // lead = right edge → animate the larger-bound edge fast.
            withAnimation(fastSpring) { leadFrac = target }
            withAnimation(slowSpring) { trailFrac = target }
        } else {
            // moving left: lead = left edge.
            withAnimation(fastSpring) { trailFrac = target }
            withAnimation(slowSpring) { leadFrac = target }
        }

        withAnimation(.easeInOut(duration: 0.28)) { activeStrength = 0.2 }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.12)) {
            activeStrength = 1
        }
    }
}
