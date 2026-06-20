// catalog-id: ges-drag-reorder-spring
import SwiftUI

/// Spring Reorder List
///
/// Long-press lifts a row that tilts and casts a shadow; as you drag, the other
/// rows shove aside with damped springs and trail slightly behind the gap,
/// settling with a soft jiggle.
///
/// - `demo == true`  → a self-driving TimelineView loop scripts a fake
///   pick-up → move → drop on a ~3.4s cycle so the tile looks alive untouched.
/// - `demo == false` → the real interactive component: a per-row
///   `LongPressGesture(0.3).sequenced(before: DragGesture(minimumDistance: 0))`
///   lifts a row and reorders the list with overshooting springs.
struct DragReorderSpringView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if demo {
            DemoReorderList(size: size)
        } else {
            InteractiveReorderList(size: size)
        }
    }
}

// MARK: - Shared model

private struct ReorderItem: Identifiable, Equatable {
    let id: Int
    let hue: Double
    let glyph: String
}

private enum ReorderPalette {
    static let items: [ReorderItem] = [
        ReorderItem(id: 0, hue: 0.58, glyph: "square.stack.3d.up.fill"),
        ReorderItem(id: 1, hue: 0.74, glyph: "wand.and.stars"),
        ReorderItem(id: 2, hue: 0.90, glyph: "paintbrush.pointed.fill"),
        ReorderItem(id: 3, hue: 0.07, glyph: "bolt.fill"),
        ReorderItem(id: 4, hue: 0.42, glyph: "leaf.fill")
    ]
}

// MARK: - Geometry helpers

private enum ReorderMetrics {
    /// Vertical breathing room around the stack so a lifted/tilted row never clips.
    static func layout(for size: CGSize, count: Int) -> (rowHeight: CGFloat, gap: CGFloat, top: CGFloat, inset: CGFloat) {
        let inset: CGFloat = max(8, min(size.width, size.height) * 0.06)
        let usableWidth = max(40, size.width - inset * 2)
        // Keep rows from getting absurdly tall in a big detail view.
        let gap: CGFloat = max(4, usableWidth * 0.03)
        let usableHeight = max(40, size.height - inset * 2)
        let totalGap = gap * CGFloat(count - 1)
        let rowHeight = max(18, (usableHeight - totalGap) / CGFloat(count))
        let stackHeight = rowHeight * CGFloat(count) + totalGap
        let top = (size.height - stackHeight) / 2 + rowHeight / 2
        return (rowHeight, gap, top, inset)
    }

    static func slotCenterY(slot: Int, rowHeight: CGFloat, gap: CGFloat, top: CGFloat) -> CGFloat {
        top + CGFloat(slot) * (rowHeight + gap)
    }
}

// MARK: - Lift state passed to the row renderer

private struct LiftState {
    var lift: CGFloat = 0          // 0…1 how "picked up" the row is
    var dragOffset: CGFloat = 0    // extra Y the finger/clock adds on top of the slot
    var isActive: Bool = false     // is this the row being moved
}

// MARK: - Row renderer (shared by both modes)

private struct ReorderRowView: View {
    let item: ReorderItem
    let width: CGFloat
    let height: CGFloat
    let lift: LiftState

    private var corner: CGFloat { min(height * 0.32, 22) }

    private var baseColor: Color {
        Color(hue: item.hue, saturation: 0.55, brightness: 0.92)
    }

    private var fillGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hue: item.hue, saturation: 0.42, brightness: 0.99),
                Color(hue: item.hue, saturation: 0.62, brightness: 0.80)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        let scale = 1 + lift.lift * 0.06
        let tilt = Double(lift.lift) * 5.0
        let shadowRadius = 3 + lift.lift * 14
        let shadowY = 2 + lift.lift * 9

        rowBody
            .frame(width: width, height: height)
            .scaleEffect(scale)
            .rotation3DEffect(
                .degrees(tilt),
                axis: (x: 1, y: 0, z: 0),
                anchor: .center,
                perspective: 0.4
            )
            .shadow(
                color: baseColor.opacity(0.30 + lift.lift * 0.28),
                radius: shadowRadius,
                x: 0,
                y: shadowY
            )
            .zIndex(lift.isActive ? 10 : 0)
    }

    private var rowBody: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(fillGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .stroke(Color.white.opacity(0.35 + lift.lift * 0.25), lineWidth: 1)
                )
                .overlay(glossHighlight)

            HStack(spacing: height * 0.28) {
                handleDots
                Image(systemName: item.glyph)
                    .font(.system(size: height * 0.34, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                Capsule()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: width * 0.30, height: max(3, height * 0.10))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, height * 0.34)
        }
    }

    private var glossHighlight: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.30), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
            )
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }

    private var handleDots: some View {
        VStack(spacing: max(2, height * 0.10)) {
            ForEach(0..<2, id: \.self) { _ in
                HStack(spacing: max(2, height * 0.10)) {
                    Circle().frame(width: max(2, height * 0.07))
                    Circle().frame(width: max(2, height * 0.07))
                }
            }
        }
        .foregroundStyle(Color.white.opacity(0.8))
    }
}

// MARK: - Background

private struct ReorderBackground: View {
    var body: some View {
        Color(hexCode: 0x0D0E16)
            .overlay(
                RadialGradient(
                    colors: [Color.white.opacity(0.06), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 260
                )
            )
    }
}

// MARK: - Interactive mode

private struct InteractiveReorderList: View {
    let size: CGSize

    @State private var order: [ReorderItem] = ReorderPalette.items
    @State private var draggingID: Int? = nil
    @State private var dragTranslation: CGFloat = 0
    @State private var liftAmount: CGFloat = 0
    @State private var dragStartSlot: Int = 0
    @State private var pickupTick: Int = 0
    @State private var dropTick: Int = 0

    private let space = "reorder.interactive"

    var body: some View {
        let m = ReorderMetrics.layout(for: size, count: order.count)
        ZStack {
            ReorderBackground()
            ForEach(order) { item in
                let slot = currentSlot(of: item)
                row(item: item, slot: slot, metrics: m)
            }
        }
        .coordinateSpace(name: space)
        .sensoryFeedback(.impact(weight: .medium), trigger: pickupTick)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: dropTick)
    }

    // MARK: row + gesture

    @ViewBuilder
    private func row(item: ReorderItem, slot: Int, metrics m: (rowHeight: CGFloat, gap: CGFloat, top: CGFloat, inset: CGFloat)) -> some View {
        let isDragging = draggingID == item.id
        let baseY = ReorderMetrics.slotCenterY(slot: slot, rowHeight: m.rowHeight, gap: m.gap, top: m.top)
        let extra = isDragging ? dragTranslation : 0
        let width = size.width - m.inset * 2

        ReorderRowView(
            item: item,
            width: width,
            height: m.rowHeight,
            lift: LiftState(
                lift: isDragging ? liftAmount : 0,
                dragOffset: extra,
                isActive: isDragging
            )
        )
        .position(x: size.width / 2, y: baseY + extra)
        .animation(isDragging ? nil : .interpolatingSpring(duration: 0.42, bounce: 0.35), value: slot)
        .gesture(rowGesture(for: item, metrics: m))
    }

    private func rowGesture(for item: ReorderItem, metrics m: (rowHeight: CGFloat, gap: CGFloat, top: CGFloat, inset: CGFloat)) -> some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(space)))
            .onChanged { value in
                switch value {
                case .first(true):
                    beginLift(item)
                case .second(true, let drag):
                    if draggingID != item.id { beginLift(item) }
                    if let drag { handleDrag(item: item, translation: drag.translation.height, metrics: m) }
                default:
                    break
                }
            }
            .onEnded { _ in
                endDrag()
            }
    }

    // MARK: state transitions

    private func beginLift(_ item: ReorderItem) {
        guard draggingID != item.id else { return }
        draggingID = item.id
        dragTranslation = 0
        dragStartSlot = order.firstIndex(of: item) ?? 0
        pickupTick &+= 1
        withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) {
            liftAmount = 1
        }
    }

    private func handleDrag(item: ReorderItem, translation: CGFloat, metrics m: (rowHeight: CGFloat, gap: CGFloat, top: CGFloat, inset: CGFloat)) {
        guard let from = order.firstIndex(of: item) else { return }
        let step = m.rowHeight + m.gap
        // Anchor the target to the slot where the press began, not the live
        // index — DragGesture translation is cumulative from gesture start, so
        // mixing it with the already-advanced index double-counts the move.
        let liveSlot = CGFloat(dragStartSlot) + translation / step
        let target = min(max(Int(liveSlot.rounded()), 0), order.count - 1)
        if target != from {
            withAnimation(.interpolatingSpring(duration: 0.45, bounce: 0.35)) {
                let moved = order.remove(at: from)
                order.insert(moved, at: target)
            }
        }
        // Keep the lifted row glued to the finger: its visible Y is
        // slot(currentSlot) + dragTranslation, and we want that to equal
        // slot(dragStartSlot) + translation.
        let currentSlot = order.firstIndex(of: item) ?? from
        dragTranslation = (CGFloat(dragStartSlot) - CGFloat(currentSlot)) * step + translation
    }

    private func endDrag() {
        dropTick &+= 1
        let settlingID = draggingID
        // Keep the row "active" through the settle so the spring on
        // dragTranslation/liftAmount actually renders (a soft jiggle) instead
        // of snapping the instant draggingID clears.
        withAnimation(.interpolatingSpring(duration: 0.5, bounce: 0.32)) {
            dragTranslation = 0
            liftAmount = 0
        } completion: {
            if draggingID == settlingID { draggingID = nil }
        }
    }

    private func currentSlot(of item: ReorderItem) -> Int {
        order.firstIndex(of: item) ?? 0
    }
}

// MARK: - Demo (self-driving) mode

private struct DemoReorderList: View {
    let size: CGSize

    private let items = ReorderPalette.items
    private let cycle: Double = 3.4

    var body: some View {
        let m = ReorderMetrics.layout(for: size, count: items.count)
        TimelineView(.animation) { timeline in
            let t = phase(timeline.date)
            let script = DemoScript(t: t, count: items.count)
            ZStack {
                ReorderBackground()
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    demoRow(item: item, index: index, script: script, metrics: m)
                }
            }
        }
    }

    private func phase(_ date: Date) -> Double {
        let secs = date.timeIntervalSinceReferenceDate
        return (secs.truncatingRemainder(dividingBy: cycle)) / cycle
    }

    @ViewBuilder
    private func demoRow(item: ReorderItem, index: Int, script: DemoScript, metrics m: (rowHeight: CGFloat, gap: CGFloat, top: CGFloat, inset: CGFloat)) -> some View {
        let isActive = index == script.activeIndex
        let step = m.rowHeight + m.gap
        // Continuous slot position (Double) for every row so neighbors glide
        // into the gap with the same overshoot the active row uses, rather than
        // teleporting a whole slot when an integer threshold flips.
        let continuousSlot = script.continuousSlot(for: index)
        let baseY = m.top + CGFloat(continuousSlot) * step
        let width = size.width - m.inset * 2

        ReorderRowView(
            item: item,
            width: width,
            height: m.rowHeight,
            lift: LiftState(
                lift: isActive ? script.lift : 0,
                dragOffset: 0,
                isActive: isActive
            )
        )
        .position(x: size.width / 2, y: baseY)
    }
}

/// Pure-function description of the scripted pick-up → move → drop loop.
///
/// The active row (index 1) lifts, slides down two slots while the rows it
/// passes shove up to fill the gap (with an overshooting smoothstep that reads
/// as a damped jiggle), holds, then rises back and drops home — a fully
/// symmetric cycle so the TimelineView loops with no teleport on wrap.
private struct DemoScript {
    let t: Double
    let count: Int

    let activeIndex = 1
    private let travel: Int = 2   // how many slots the active row migrates

    // Phase boundaries within the normalized [0,1) cycle.
    private let pPick = 0.12      // finish lifting
    private let pDownEnd = 0.42   // finished moving down
    private let pHoldEnd = 0.58   // dwell at the bottom slot
    private let pUpEnd = 0.86     // returned to original slot
    // remainder: drop + settle back to rest

    var lift: CGFloat {
        if t < pPick {
            return CGFloat(smoothstep(0, pPick, t))
        } else if t < pUpEnd {
            return 1
        } else {
            return CGFloat(1 - smoothstep(pUpEnd, 1.0, t))
        }
    }

    /// Continuous migration of the active row (in slot units): 0 = its original
    /// slot, `travel` = the destination slot. Overshoots on each leg for the
    /// springy jiggle.
    private var activeProgress: Double {
        if t < pPick { return 0 }
        if t < pDownEnd { return overshoot(smoothstep(pPick, pDownEnd, t)) * Double(travel) }
        if t < pHoldEnd { return Double(travel) }
        if t < pUpEnd { return (1 - overshoot(smoothstep(pHoldEnd, pUpEnd, t))) * Double(travel) }
        return 0
    }

    /// Continuous slot position for any row. The active row follows
    /// `activeProgress` directly; every other row is smoothly pushed out of the
    /// way in proportion to how far the active row has swept past it — so the
    /// neighbors glide and jiggle into the gap instead of snapping a whole slot.
    func continuousSlot(for index: Int) -> Double {
        let p = activeProgress                       // active row's signed travel
        if index == activeIndex {
            return Double(activeIndex) + p
        }
        // How far the active row currently is, as an absolute slot position.
        let activeNow = Double(activeIndex) + p
        let origin = Double(activeIndex)
        let other = Double(index)
        // Down-sweep: rows below origin, above the active row's live position,
        // slide up by the fraction of the way the active row has passed them.
        if p >= 0 {
            guard other > origin else { return other }
            // Fraction in [0,1] of this neighbor being "passed" by the active row.
            let f = clamp(activeNow - (other - 1), low: 0, high: 1)
            return other - f
        } else {
            // (Unused in the current script, but symmetric for completeness.)
            guard other < origin else { return other }
            let f = clamp((other + 1) - activeNow, low: 0, high: 1)
            return other + f
        }
    }

    // MARK: math

    private func clamp(_ x: Double, low: Double, high: Double) -> Double {
        min(max(x, low), high)
    }

    private func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        guard b > a else { return x < a ? 0 : 1 }
        let u = min(max((x - a) / (b - a), 0), 1)
        return u * u * (3 - 2 * u)
    }

    /// A unit ease that overshoots past 1 then settles, for the springy jiggle.
    private func overshoot(_ u: Double) -> Double {
        let c: Double = 1.70158
        let x = u - 1
        return 1 + (c + 1) * x * x * x + c * x * x
    }
}

// MARK: - Color hex helper

private extension Color {
    init(hexCode hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
