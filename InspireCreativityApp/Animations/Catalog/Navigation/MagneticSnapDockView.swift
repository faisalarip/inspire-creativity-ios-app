// catalog-id: nav-magnetic-snap-dock
import SwiftUI

// MARK: - Magnetic Snap Dock
// A reorderable dock: dragging an icon makes the others slide aside and the
// dragged icon snaps into slots with a magnetic click + overshoot wobble, while
// a soft attraction pulls it toward the nearest gap as you hover.
//
// Both the interactive path (LongPress -> Drag) and the self-driving demo feed
// the SAME pure slot math (`slotCenterX` / `visualSlot`), so the demo is a
// faithful replay of the real gesture — no second layout routine.

struct MagneticSnapDockView: View {
    var demo: Bool = false

    // Stable item identities. Kept low (5) so the shuffle is legible at 120pt.
    @State private var items: [MagneticSnapDockView_DockItem] = MagneticSnapDockView_DockItem.defaults

    // Single source of truth for the INTERACTIVE path.
    @State private var draggingIndex: Int? = nil      // logical index in `items`
    @State private var targetSlot: Int = 0            // slot the gap is opening at
    @State private var fingerX: CGFloat = 0           // live finger x in dock space
    @State private var snapTick: Int = 0              // drives the release haptic

    var body: some View {
        GeometryReader { geo in
            let metrics = MagneticSnapDockView_DockMetrics(size: geo.size, count: items.count)
            ZStack {
                background(metrics)
                if demo {
                    demoDock(metrics)
                } else {
                    interactiveDock(metrics)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Background

    private func background(_ m: MagneticSnapDockView_DockMetrics) -> some View {
        let r = m.dockHeight / 2
        return RoundedRectangle(cornerRadius: r, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.13, green: 0.15, blue: 0.20),
                        Color(red: 0.07, green: 0.08, blue: 0.11)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
            .frame(width: m.dockWidth, height: m.dockHeight)
            .shadow(color: .black.opacity(0.45), radius: m.tile * 0.18, y: m.tile * 0.10)
            .position(x: m.size.width / 2, y: m.midY)
    }

    // MARK: - Interactive dock (demo == false)

    private func interactiveDock(_ m: MagneticSnapDockView_DockMetrics) -> some View {
        ZStack {
            ForEach(Array(items.enumerated()), id: \.element.id) { logicalIndex, item in
                iconTile(item, m: m)
                    .scaleEffect(draggingIndex == logicalIndex ? 1.22 : 1.0)
                    .shadow(
                        color: .black.opacity(draggingIndex == logicalIndex ? 0.5 : 0.0),
                        radius: m.tile * 0.22, y: m.tile * 0.12
                    )
                    .position(position(forLogical: logicalIndex, m: m))
                    .zIndex(draggingIndex == logicalIndex ? 10 : 0)
                    .animation(shuffleAnimation, value: targetSlot)
                    .animation(shuffleAnimation, value: draggingIndex)
            }
        }
        .frame(width: m.size.width, height: m.size.height)
        .contentShape(Rectangle())
        .gesture(dragGesture(m))
        .sensoryFeedback(.impact(weight: .medium), trigger: snapTick)
        .sensoryFeedback(.selection, trigger: targetSlot)
    }

    private var shuffleAnimation: Animation {
        .spring(response: 0.34, dampingFraction: 0.72)
    }

    // Position of a logical item. The dragged item floats toward the finger with
    // a magnetic attraction to the nearest slot; everyone else sits at their
    // visual slot (which has shifted to open the gap at `targetSlot`).
    private func position(forLogical logicalIndex: Int, m: MagneticSnapDockView_DockMetrics) -> CGPoint {
        if draggingIndex == logicalIndex {
            return liftedPosition(m: m)
        }
        let slot = visualSlot(ofLogical: logicalIndex)
        return CGPoint(x: m.slotCenterX(slot), y: m.midY)
    }

    // The lifted icon: blend the raw finger position with the nearest slot center
    // so it "resists then clicks" toward the gap — the magnetic pull.
    private func liftedPosition(m: MagneticSnapDockView_DockMetrics) -> CGPoint {
        let nearest = m.slotCenterX(targetSlot)
        let pull: CGFloat = 0.30                      // attraction strength
        let x = fingerX * (1 - pull) + nearest * pull
        let clamped = min(max(x, m.slotCenterX(0)), m.slotCenterX(m.count - 1))
        return CGPoint(x: clamped, y: m.midY - m.tile * 0.16)   // lifted above rail
    }

    // MARK: Gesture — LongPress to lift, then Drag to move, snap on release.

    private func dragGesture(_ m: MagneticSnapDockView_DockMetrics) -> some Gesture {
        LongPressGesture(minimumDuration: 0.16)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                switch value {
                case .first:
                    break
                case .second(let pressed, let drag):
                    guard pressed, let drag else { return }
                    beginIfNeeded(at: drag.startLocation, m: m)
                    update(to: drag.location, m: m)
                }
            }
            .onEnded { _ in
                endDrag()
            }
    }

    private func beginIfNeeded(at start: CGPoint, m: MagneticSnapDockView_DockMetrics) {
        guard draggingIndex == nil else { return }
        let slot = m.slot(forX: start.x)
        // Before any drag, logical order == slot order, so slot == logical item.
        fingerX = start.x
        withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
            draggingIndex = slot
            targetSlot = slot
        }
    }

    private func update(to location: CGPoint, m: MagneticSnapDockView_DockMetrics) {
        guard draggingIndex != nil else { return }
        fingerX = location.x
        let newTarget = m.slot(forX: location.x)
        if newTarget != targetSlot {
            withAnimation(shuffleAnimation) {
                targetSlot = newTarget       // gap opens AHEAD of the drop
            }
        }
    }

    private func endDrag() {
        guard let dragged = draggingIndex else { return }
        reorder(fromSlot: dragged, toSlot: targetSlot)   // logical index == home slot
        // Snap home with a bouncy overshoot wobble.
        withAnimation(.spring(response: 0.42, dampingFraction: 0.52)) {
            draggingIndex = nil
        }
        snapTick &+= 1   // fire the impact haptic on real release only
    }

    // MARK: Reorder bookkeeping (logical index <-> visual slot)
    //
    // `items` is kept in logical order. Between drags, logical order == slot order,
    // so a logical index IS its home slot. A drag always starts fresh
    // (draggingIndex == nil) and commits fully before the next, preserving the
    // invariant. During a drag we recompute the visual slot of each item.

    // The visual slot a non-dragged logical item occupies, given the gap opening
    // at `targetSlot`. Items between the dragged item's home slot and the target
    // shift by one to make room.
    private func visualSlot(ofLogical logicalIndex: Int) -> Int {
        guard let dragged = draggingIndex, dragged != logicalIndex else {
            return logicalIndex
        }
        return Self.shiftedSlot(index: logicalIndex, source: dragged, target: targetSlot)
    }

    // Pure shift rule shared by interactive + demo paths.
    static func shiftedSlot(index i: Int, source: Int, target: Int) -> Int {
        if source < target {
            // gap moves right: items in (source, target] slide LEFT by one
            if i > source && i <= target { return i - 1 }
        } else if source > target {
            // gap moves left: items in [target, source) slide RIGHT by one
            if i >= target && i < source { return i + 1 }
        }
        return i
    }

    private func reorder(fromSlot: Int, toSlot: Int) {
        guard fromSlot != toSlot,
              items.indices.contains(fromSlot),
              items.indices.contains(toSlot) else { return }
        let moved = items.remove(at: fromSlot)
        items.insert(moved, at: toSlot)
    }

    // MARK: - Demo dock (demo == true)
    // Self-driving: a TimelineView scripts a synthetic drag of the middle icon
    // back and forth between the two end slots, feeding the SAME slot math. The
    // dragged item's home slot is CONSTANT (no commit ever happens), and the live
    // target is derived from the floating icon's position — exactly like the real
    // gesture — so the gap always sits under the icon with no overlap. The release
    // overshoot wobble is baked into the travel easing so the snap reads as bouncy.

    private func demoDock(_ m: MagneticSnapDockView_DockMetrics) -> some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let state = MagneticSnapDockView_DemoState(time: t, metrics: m)
            let liveTarget = m.slot(forX: state.draggedX)
            ZStack {
                ForEach(Array(items.enumerated()), id: \.element.id) { logicalIndex, item in
                    demoTile(logicalIndex, item: item, state: state, target: liveTarget, m: m)
                }
            }
            .frame(width: m.size.width, height: m.size.height)
        }
    }

    @ViewBuilder
    private func demoTile(_ logicalIndex: Int, item: MagneticSnapDockView_DockItem,
                          state: MagneticSnapDockView_DemoState, target: Int, m: MagneticSnapDockView_DockMetrics) -> some View {
        let isDragged = (logicalIndex == state.draggedLogical)
        if isDragged {
            iconTile(item, m: m)
                .scaleEffect(1.0 + 0.22 * state.liftAmount)
                .shadow(color: .black.opacity(0.5 * state.liftAmount),
                        radius: m.tile * 0.22, y: m.tile * 0.12)
                .position(x: state.draggedX, y: m.midY - m.tile * 0.16 * state.liftAmount)
                .zIndex(10)
        } else {
            let slot = Self.shiftedSlot(index: logicalIndex,
                                        source: state.draggedLogical, target: target)
            iconTile(item, m: m)
                .position(x: m.slotCenterX(slot), y: m.midY)
                .zIndex(0)
                .animation(shuffleAnimation, value: slot)   // slide aside, don't teleport
        }
    }

    // MARK: - Shared icon tile

    private func iconTile(_ item: MagneticSnapDockView_DockItem, m: MagneticSnapDockView_DockMetrics) -> some View {
        let r = m.tile * 0.26
        return RoundedRectangle(cornerRadius: r, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [item.top, item.bottom],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
            )
            .overlay(
                Image(systemName: item.symbol)
                    .font(.system(size: m.tile * 0.42, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
            )
            .frame(width: m.tile, height: m.tile)
    }
}

// MARK: - Demo state (derived, never written to @State during render)

private struct MagneticSnapDockView_DemoState {
    let draggedLogical: Int    // == home slot; CONSTANT because demo never commits
    let draggedX: CGFloat      // live x of the floating icon
    let liftAmount: CGFloat    // 0 = resting in slot, 1 = fully lifted

    init(time: Double, metrics m: MagneticSnapDockView_DockMetrics) {
        // The MIDDLE icon hops between the two end slots on a ~3.4s loop, so the
        // home slot is honest and the shuffle is symmetric in both directions.
        let dragged = m.count / 2          // 2 for a 5-item dock
        let endLeft = 0
        let endRight = m.count - 1
        self.draggedLogical = dragged

        let loop: Double = 3.4
        let phase = (time.truncatingRemainder(dividingBy: loop)) / loop  // 0..1

        let cHome = m.slotCenterX(dragged)
        let cLeft = m.slotCenterX(endLeft)
        let cRight = m.slotCenterX(endRight)

        // Phase plan:
        //   0.00–0.10  lift up in place
        //   0.10–0.40  travel home -> right end (overshoot wobble)
        //   0.40–0.50  hold lifted at right
        //   0.50–0.80  travel right end -> left end (overshoot wobble)
        //   0.80–0.90  hold lifted at left
        //   0.90–1.00  travel left -> home & drop down
        self.liftAmount = MagneticSnapDockView_DemoState.lift(phase)

        if phase < 0.10 {
            self.draggedX = cHome
        } else if phase < 0.40 {
            let local = (phase - 0.10) / 0.30
            self.draggedX = MagneticSnapDockView_DemoState.overshootLerp(cHome, cRight, local)
        } else if phase < 0.50 {
            self.draggedX = cRight
        } else if phase < 0.80 {
            let local = (phase - 0.50) / 0.30
            self.draggedX = MagneticSnapDockView_DemoState.overshootLerp(cRight, cLeft, local)
        } else if phase < 0.90 {
            self.draggedX = cLeft
        } else {
            let local = (phase - 0.90) / 0.10
            self.draggedX = MagneticSnapDockView_DemoState.overshootLerp(cLeft, cHome, local)
        }
    }

    // Lift envelope: rises fast, stays up through the travels, drops at the end.
    static func lift(_ phase: Double) -> CGFloat {
        let p: Double
        if phase < 0.10 {
            p = phase / 0.10
        } else if phase < 0.90 {
            p = 1.0
        } else {
            p = 1.0 - (phase - 0.90) / 0.10
        }
        let e = p * p * (3 - 2 * p)   // smoothstep
        return CGFloat(min(max(e, 0), 1))
    }

    // Travel with a baked damped-overshoot so the synthetic snap visibly wobbles
    // into the slot (replaces the event-driven spring of the interactive path).
    static func overshootLerp(_ a: CGFloat, _ b: CGFloat, _ tRaw: Double) -> CGFloat {
        let t = min(max(tRaw, 0), 1)
        let zeta = 0.42
        let omega = 9.0
        let decay = exp(-zeta * omega * t)
        let wd = omega * sqrt(max(0.0001, 1 - zeta * zeta))
        let osc = decay * (cos(wd * t) + (zeta * omega / wd) * sin(wd * t))
        let settle = 1.0 - osc           // 0 -> ~1 with overshoot past 1, then rings
        return a + (b - a) * CGFloat(settle)
    }
}

// MARK: - Metrics

private struct MagneticSnapDockView_DockMetrics {
    let size: CGSize
    let count: Int
    let tile: CGFloat
    let gap: CGFloat
    let slotWidth: CGFloat
    let dockWidth: CGFloat
    let dockHeight: CGFloat
    let midY: CGFloat
    let originX: CGFloat   // x of slot 0's center

    init(size: CGSize, count: Int) {
        self.size = size
        self.count = count
        let n = CGFloat(count)
        let shortest = min(size.width, size.height)

        // Slot geometry is derived FROM the final dock width so they can never
        // disagree (no clamped/unclamped mismatch). Layout model:
        //   gap = 0.34 * slotWidth, tile = 0.66 * slotWidth,
        //   dockWidth = count*slotWidth + gap = slotWidth * (count + 0.34)
        let gapFrac: CGFloat = 0.34
        let padFactor = n + gapFrac

        // Cap the dock by width AND by height (so tiles never get huge on wide tiles).
        let maxByWidth = size.width * 0.94
        let maxTileByHeight = shortest * 0.50
        let maxByHeight = (maxTileByHeight / 0.66) * padFactor
        let dw = max(40, min(maxByWidth, maxByHeight))
        self.dockWidth = dw

        let sw = dw / padFactor
        self.slotWidth = sw
        self.gap = sw * gapFrac
        self.tile = sw * 0.66
        self.dockHeight = self.tile + self.gap * 1.3
        self.midY = size.height / 2

        let dockLeft = (size.width - dw) / 2
        self.originX = dockLeft + self.gap + self.tile / 2
    }

    func slotCenterX(_ slot: Int) -> CGFloat {
        originX + slotWidth * CGFloat(slot)
    }

    func slot(forX x: CGFloat) -> Int {
        let raw = (x - originX) / slotWidth
        let rounded = Int(raw.rounded())
        return min(max(rounded, 0), count - 1)
    }
}

// MARK: - Model

private struct MagneticSnapDockView_DockItem: Identifiable, Equatable {
    let id: Int
    let symbol: String
    let top: Color
    let bottom: Color

    static let defaults: [MagneticSnapDockView_DockItem] = [
        MagneticSnapDockView_DockItem(id: 0, symbol: "house.fill",
                 top: Color(red: 0.36, green: 0.62, blue: 0.98),
                 bottom: Color(red: 0.20, green: 0.40, blue: 0.86)),
        MagneticSnapDockView_DockItem(id: 1, symbol: "magnifyingglass",
                 top: Color(red: 0.98, green: 0.55, blue: 0.42),
                 bottom: Color(red: 0.92, green: 0.34, blue: 0.36)),
        MagneticSnapDockView_DockItem(id: 2, symbol: "heart.fill",
                 top: Color(red: 0.96, green: 0.45, blue: 0.66),
                 bottom: Color(red: 0.82, green: 0.26, blue: 0.55)),
        MagneticSnapDockView_DockItem(id: 3, symbol: "bell.fill",
                 top: Color(red: 0.55, green: 0.78, blue: 0.52),
                 bottom: Color(red: 0.30, green: 0.62, blue: 0.42)),
        MagneticSnapDockView_DockItem(id: 4, symbol: "gearshape.fill",
                 top: Color(red: 0.74, green: 0.66, blue: 0.96),
                 bottom: Color(red: 0.52, green: 0.42, blue: 0.88))
    ]
}
