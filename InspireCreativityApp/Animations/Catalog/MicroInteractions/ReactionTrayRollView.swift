// catalog-id: mi-reaction-tray-roll
import SwiftUI

/// Reaction Tray Roll
/// A long-press opens a row of emoji that arc up and scale into place in a
/// staggered spring sequence; sliding across magnifies the hovered one like a
/// fisheye macOS Dock / iMessage reaction tray.
///
/// - `demo == true`  : self-driving. The tray arcs open, holds, and a virtual
///                     cursor sweeps the row back and forth so the fisheye rides
///                     on its own. The loop is continuous at the wrap — never blank.
/// - `demo == false` : the real interactive component. LongPress opens the tray,
///                     a sequenced drag feeds the fisheye, release commits the
///                     hovered emoji.
struct ReactionTrayRollView: View {
    var demo: Bool = false

    // Interactive state (ignored in demo mode).
    @State private var isOpen: Bool = false
    @State private var cursorX: CGFloat? = nil
    @State private var hoveredIndex: Int? = nil
    @State private var committedIndex: Int? = nil

    private let emojis: [String] = ["👍", "❤️", "😂", "😮", "😢", "🙏"]

    var body: some View {
        GeometryReader { proxy in
            content(in: proxy.size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if demo {
            demoContent(in: size)
        } else {
            interactiveContent(in: size)
        }
    }

    // MARK: - Demo (self-driving)

    private func demoContent(in size: CGSize) -> some View {
        let metrics = ReactionTrayRollView_Metrics(size: size, count: emojis.count)
        return TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let openAmount: Double = openAmountForDemo(t)
            let cursor: CGFloat = demoCursorX(t, metrics: metrics)
            let hovered = nearestIndex(to: cursor, metrics: metrics)

            ZStack {
                backdrop
                ReactionTrayRollView_TrayRow(
                    emojis: emojis,
                    metrics: metrics,
                    openAmount: openAmount,
                    cursorX: cursor,
                    hoveredIndex: hovered,
                    committedIndex: nil
                )
            }
        }
    }

    /// Arc the tray open, hold, then arc back out — continuous at both ends of
    /// the loop so there is no single-frame collapse at the wrap.
    private func openAmountForDemo(_ t: TimeInterval) -> Double {
        let period: Double = 3.4
        let phase = (t.truncatingRemainder(dividingBy: period)) / period // 0..1
        let intro = min(1.0, phase / 0.18)                                // arc in
        let outro: Double = phase < 0.85
            ? 1.0
            : max(0.0, 1.0 - (phase - 0.85) / 0.15)                       // arc out
        return easeOutBack(intro) * outro
    }

    /// Triangle-wave cursor that sweeps a touch beyond each end-emoji center so
    /// the end items reach full boost and the turnaround feels natural. The
    /// position is continuous across the loop wrap.
    private func demoCursorX(_ t: TimeInterval, metrics: ReactionTrayRollView_Metrics) -> CGFloat {
        let period: Double = 3.4
        let phase = (t.truncatingRemainder(dividingBy: period)) / period // 0..1
        let tri = phase < 0.5 ? (phase * 2.0) : (2.0 - phase * 2.0)       // 0->1->0
        let smooth = smoothstep(tri)
        let overshoot = metrics.spacing * 0.55
        let lo = metrics.firstCenterX - overshoot
        let hi = metrics.lastCenterX + overshoot
        return lo + (hi - lo) * CGFloat(smooth)
    }

    // MARK: - Interactive

    private func interactiveContent(in size: CGSize) -> some View {
        let metrics = ReactionTrayRollView_Metrics(size: size, count: emojis.count)
        let openAmount: Double = isOpen ? 1.0 : 0.0

        return ZStack {
            backdrop

            // Idle affordance shown when closed; fades out as the tray opens.
            idleAffordance(metrics: metrics)
                .opacity(1.0 - openAmount)

            ReactionTrayRollView_TrayRow(
                emojis: emojis,
                metrics: metrics,
                openAmount: openAmount,
                cursorX: cursorX,
                hoveredIndex: hoveredIndex,
                committedIndex: committedIndex
            )
            .allowsHitTesting(false)
            // Keep the faint resting emoji from leaking behind the idle pill.
            .opacity(isOpen ? 1.0 : 0.0)
        }
        .contentShape(Rectangle())
        .gesture(trayGesture(metrics: metrics))
        .sensoryFeedback(.selection, trigger: hoveredIndex)
        .sensoryFeedback(.impact(weight: .medium), trigger: committedIndex)
    }

    private func idleAffordance(metrics: ReactionTrayRollView_Metrics) -> some View {
        VStack(spacing: metrics.itemSize * 0.18) {
            Capsule()
                .fill(trayFill)
                .overlay(
                    Capsule().stroke(trayStroke, lineWidth: 1)
                )
                .overlay(
                    Text(committedIndex.map { emojis[$0] } ?? "👍")
                        .font(.system(size: metrics.itemSize * 0.62))
                )
                .frame(width: metrics.itemSize * 1.7, height: metrics.itemSize * 1.05)
            Text("Hold")
                .font(.system(size: max(8, metrics.itemSize * 0.24), weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.62, green: 0.60, blue: 0.70))
        }
        .position(x: metrics.size.width / 2, y: metrics.rowBaselineY)
    }

    // MARK: - Gesture

    private func trayGesture(metrics: ReactionTrayRollView_Metrics) -> some Gesture {
        LongPressGesture(minimumDuration: 0.28)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                switch value {
                case .first(true):
                    open()
                case .second(true, let drag):
                    if !isOpen { open() }
                    if let drag {
                        let x = clampedX(drag.location.x, metrics: metrics)
                        cursorX = x
                        hoveredIndex = nearestIndex(to: x, metrics: metrics)
                    }
                default:
                    break
                }
            }
            .onEnded { _ in
                if let h = hoveredIndex {
                    committedIndex = h
                }
                close()
            }
    }

    private func open() {
        guard !isOpen else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.7)) {
            isOpen = true
        }
    }

    private func close() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
            isOpen = false
            cursorX = nil
            hoveredIndex = nil
        }
    }

    private func clampedX(_ x: CGFloat, metrics: ReactionTrayRollView_Metrics) -> CGFloat {
        min(max(x, 0), metrics.size.width)
    }

    // MARK: - Shared geometry helpers

    private func nearestIndex(to x: CGFloat, metrics: ReactionTrayRollView_Metrics) -> Int {
        var best = 0
        var bestDist = CGFloat.greatestFiniteMagnitude
        for i in 0..<emojis.count {
            let d = abs(metrics.centerX(i) - x)
            if d < bestDist {
                bestDist = d
                best = i
            }
        }
        return best
    }

    // MARK: - Palette

    private var backdrop: some View {
        // Tint #141019 with a soft vignette so the tile reads on its own.
        RadialGradient(
            colors: [
                Color(red: 0.118, green: 0.094, blue: 0.149),
                Color(red: 0.078, green: 0.063, blue: 0.098)
            ],
            center: .center,
            startRadius: 2,
            endRadius: 220
        )
    }

    private var trayFill: Color {
        Color(red: 0.18, green: 0.16, blue: 0.24).opacity(0.92)
    }

    private var trayStroke: Color {
        Color(red: 0.42, green: 0.40, blue: 0.55).opacity(0.55)
    }
}

// MARK: - Layout metrics

private struct ReactionTrayRollView_Metrics {
    let size: CGSize
    let count: Int
    let itemSize: CGFloat
    let spacing: CGFloat
    let rowWidth: CGFloat
    let rowOriginX: CGFloat
    let rowBaselineY: CGFloat

    init(size: CGSize, count: Int) {
        self.size = size
        self.count = count

        let w = max(size.width, 1)
        let h = max(size.height, 1)

        // Derive item size so the whole row (with magnification headroom) fits
        // even a ~120pt tile. Width is the binding constraint with 6 items.
        let byWidth = w / (CGFloat(count) + 1.4)
        let byHeight = h * 0.40
        let item = max(8, min(byWidth, byHeight))
        self.itemSize = item

        let gap = item * 0.30
        self.spacing = item + gap
        self.rowWidth = spacing * CGFloat(count - 1)
        self.rowOriginX = (w - rowWidth) / 2
        // Sit a touch below center; emoji grow upward from this baseline.
        self.rowBaselineY = h * 0.58
    }

    var firstCenterX: CGFloat { centerX(0) }
    var lastCenterX: CGFloat { centerX(count - 1) }

    func centerX(_ index: Int) -> CGFloat {
        rowOriginX + spacing * CGFloat(index)
    }
}

// MARK: - Tray row (single render path for both modes)

private struct ReactionTrayRollView_TrayRow: View {
    let emojis: [String]
    let metrics: ReactionTrayRollView_Metrics
    let openAmount: Double
    let cursorX: CGFloat?
    let hoveredIndex: Int?
    let committedIndex: Int?

    var body: some View {
        // The tray pill bows up behind the emoji.
        ZStack {
            trayPill
            ForEach(emojis.indices, id: \.self) { index in
                emojiItem(index)
            }
        }
    }

    private var trayPill: some View {
        // Sub-expressions hoisted into typed lets so the modifier chain
        // type-checks within the optimizer's solver budget (Release archive).
        let padX: CGFloat = metrics.itemSize * 0.62
        let pillW: CGFloat = metrics.rowWidth + metrics.itemSize + padX
        let pillH: CGFloat = metrics.itemSize * 1.45
        let lift: CGFloat = metrics.itemSize * 0.18
        let shadowOpacity: Double = 0.35 * openAmount
        let scaleX: CGFloat = 0.6 + 0.4 * CGFloat(openAmount)
        let scaleY: CGFloat = 0.5 + 0.5 * CGFloat(openAmount)
        let posX: CGFloat = metrics.size.width / 2
        let posY: CGFloat = metrics.rowBaselineY - metrics.itemSize * 0.30 - lift * CGFloat(openAmount)
        let fill = LinearGradient(
            colors: [
                Color(red: 0.22, green: 0.20, blue: 0.30).opacity(0.96),
                Color(red: 0.15, green: 0.13, blue: 0.21).opacity(0.96)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        let border = Capsule().stroke(
            Color(red: 0.46, green: 0.44, blue: 0.60).opacity(0.45),
            lineWidth: 1
        )
        return Capsule()
            .fill(fill)
            .overlay(border)
            .shadow(color: Color.black.opacity(shadowOpacity), radius: 10, y: 5)
            .frame(width: pillW, height: pillH)
            .scaleEffect(x: scaleX, y: scaleY, anchor: .bottom)
            .opacity(openAmount)
            .position(x: posX, y: posY)
    }

    private func emojiItem(_ index: Int) -> some View {
        let p = itemProgress(index)                     // 0..1 arc-in
        let baseX = metrics.centerX(index)
        let fisheye = fisheyeBoost(forCenterX: baseX)   // 0..1 nearness
        let scale = itemScale(progress: p, fisheye: fisheye)
        let lift = itemLift(progress: p, fisheye: fisheye)
        let isHover = (hoveredIndex == index)
        let isCommitted = (committedIndex == index)

        return Text(emojis[index])
            .font(.system(size: metrics.itemSize * 0.92))
            .scaleEffect(scale, anchor: .bottom)
            .background(
                Circle()
                    .fill(Color.white.opacity(isCommitted ? 0.10 : 0))
                    .frame(width: metrics.itemSize * 1.3, height: metrics.itemSize * 1.3)
            )
            .overlay(alignment: .top) {
                hoverLabel(index)
                    .opacity(isHover ? fisheye : 0)
            }
            .shadow(
                color: Color.black.opacity(0.30 * fisheye),
                radius: 4 * fisheye,
                y: 2
            )
            .position(
                x: baseX,
                y: metrics.rowBaselineY - lift
            )
            .opacity(itemOpacity(progress: p))
    }

    private func hoverLabel(_ index: Int) -> some View {
        Text(emojis[index])
            .font(.system(size: metrics.itemSize * 0.55))
            .padding(.horizontal, metrics.itemSize * 0.22)
            .padding(.vertical, metrics.itemSize * 0.10)
            .background(
                Capsule().fill(Color(red: 0.10, green: 0.09, blue: 0.14).opacity(0.95))
            )
            .offset(y: -metrics.itemSize * 1.5)
            .fixedSize()
    }

    // MARK: progress + fisheye math

    /// Staggered arc-in: derive each item's local progress from the single
    /// openAmount plus an index offset, so demo and interactive behave alike.
    private func itemProgress(_ index: Int) -> Double {
        let count = Double(metrics.count)
        let span: Double = 1.6
        let raw = openAmount * (count + span) - Double(index)
        return min(max(raw / span, 0), 1)
    }

    /// Gaussian nearness 0..1 of an item center to the cursor.
    private func fisheyeBoost(forCenterX x: CGFloat) -> Double {
        guard let cursor = cursorX else { return 0 }
        let sigma = max(metrics.spacing * 1.05, 1)
        let d = Double(abs(x - cursor) / sigma)
        return exp(-d * d)
    }

    private func itemScale(progress p: Double, fisheye: Double) -> CGFloat {
        let arc = 0.55 + 0.45 * easeOutBack(p)   // grows in from 0.55 -> 1.0
        let boost = 1.0 + 0.85 * fisheye          // up to +85% under the cursor
        return CGFloat(arc * boost)
    }

    private func itemLift(progress p: Double, fisheye: Double) -> CGFloat {
        let base = metrics.itemSize * 0.55 * CGFloat(easeOutBack(p))
        let hover = metrics.itemSize * 0.42 * CGFloat(fisheye)
        return base + hover
    }

    private func itemOpacity(progress p: Double) -> CGFloat {
        // Never fully invisible once any open begins; clamp a legible floor.
        CGFloat(min(1.0, 0.15 + p * 1.1))
    }
}

// MARK: - Easing (file-private free functions)

private func easeOutBack(_ x: Double) -> Double {
    let c1: Double = 1.70158
    let c3: Double = c1 + 1.0
    let t = x - 1.0
    return 1.0 + c3 * t * t * t + c1 * t * t
}

private func smoothstep(_ x: Double) -> Double {
    let t = min(max(x, 0), 1)
    return t * t * (3.0 - 2.0 * t)
}
