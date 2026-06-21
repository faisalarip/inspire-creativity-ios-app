// catalog-id: tx-magnetic-poetry
import SwiftUI

// MARK: - Magnetic Poetry
//
// Word tiles laid out like fridge magnets on a metal door. A drag flings any
// tile while its neighbors physically nudge aside on a distance-falloff shove,
// then everything springs back to its baseline slot. In demo mode a virtual
// "finger" auto-flings one tile after another on a continuous loop so the tile
// looks alive with no touch.
//
// Both modes feed the SAME pure layout function (`tileOffset`) so the neighbor
// coupling is identical whether driven by a real drag or the demo timeline.

public struct MagneticPoetryView: View {
    var demo: Bool = false

    // The little poem. Capped well under the ~12-tile budget.
    private let words: [String] = [
        "magnet", "words", "drift", "on",
        "cold", "steel", "quiet", "hum", "shove"
    ]

    // Interactive drag state.
    @State private var draggedIndex: Int? = nil
    @State private var dragTranslation: CGSize = .zero
    @State private var releasing: Bool = false
    @State private var settleTick: Int = 0

    public init(demo: Bool = false) {
        self.demo = demo
    }

    public var body: some View {
        GeometryReader { geo in
            let layout = makeLayout(in: geo.size)
            ZStack {
                background
                if demo {
                    demoBoard(layout: layout, size: geo.size)
                } else {
                    interactiveBoard(layout: layout, size: geo.size)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    // MARK: Background — brushed metal door.

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.11, blue: 0.13),
                    Color(red: 0.06, green: 0.07, blue: 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            LinearGradient(
                colors: [
                    Color.white.opacity(0.05),
                    Color.clear,
                    Color.white.opacity(0.03)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    // MARK: Demo board — virtual finger auto-flings tiles on a loop.

    private func demoBoard(layout: TileLayout, size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let drive = demoDrive(time: t, count: words.count)
            board(
                layout: layout,
                size: size,
                activeIndex: drive.activeIndex,
                source: drive.translation,
                liftAmount: drive.lift
            )
        }
    }

    // MARK: Interactive board — real drag with neighbor shove.

    private func interactiveBoard(layout: TileLayout, size: CGSize) -> some View {
        board(
            layout: layout,
            size: size,
            activeIndex: draggedIndex,
            source: dragTranslation,
            liftAmount: draggedIndex == nil ? 0 : (releasing ? 0 : 1)
        )
    }

    // MARK: Shared board renderer.

    private func board(
        layout: TileLayout,
        size: CGSize,
        activeIndex: Int?,
        source: CGSize,
        liftAmount: CGFloat
    ) -> some View {
        ZStack {
            ForEach(words.indices, id: \.self) { index in
                tileView(
                    index: index,
                    layout: layout,
                    activeIndex: activeIndex,
                    source: source,
                    liftAmount: liftAmount
                )
            }
        }
        .sensoryFeedbackCompat(trigger: settleTick)
    }

    // MARK: One positioned tile (factored to keep type-checking cheap).

    @ViewBuilder
    private func tileView(
        index: Int,
        layout: TileLayout,
        activeIndex: Int?,
        source: CGSize,
        liftAmount: CGFloat
    ) -> some View {
        let slot = layout.slots[index]
        let shove = tileOffset(
            index: index,
            activeIndex: activeIndex,
            source: source,
            layout: layout
        )
        let isActive = (index == activeIndex)
        tile(
            word: words[index],
            fontSize: layout.fontSize,
            isActive: isActive,
            lift: isActive ? liftAmount : 0
        )
        .position(x: slot.x, y: slot.y)
        .offset(shove)
        .zIndex(isActive ? 100 : Double(index))
        .gesture(dragGesture(for: index), including: demo ? .none : .all)
    }

    // MARK: A single magnet tile.

    private func tile(word: String, fontSize: CGFloat, isActive: Bool, lift: CGFloat) -> some View {
        let safeLift = max(0, lift)
        return Text(word)
            .font(.system(size: fontSize, weight: .heavy, design: .serif))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.16, green: 0.17, blue: 0.20),
                        Color(red: 0.05, green: 0.05, blue: 0.07)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .padding(.horizontal, fontSize * 0.5)
            .padding(.vertical, fontSize * 0.32)
            .background(tileBackground(fontSize: fontSize))
            .scaleEffect(1 + safeLift * 0.06)
            .shadow(
                color: Color.black.opacity(0.35 + safeLift * 0.25),
                radius: 3 + safeLift * 7,
                x: 0,
                y: 2 + safeLift * 5
            )
    }

    private func tileBackground(fontSize: CGFloat) -> some View {
        let radius = fontSize * 0.28
        return ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.96, green: 0.95, blue: 0.92),
                            Color(red: 0.86, green: 0.85, blue: 0.82)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.7), lineWidth: 0.75)
        }
    }

    // MARK: - Pure physics: one function, two drivers.

    /// Returns the live offset for a tile given which tile is "active" (grabbed
    /// or virtually flung) and that active tile's current translation. The
    /// active tile follows `source`; every other tile is shoved away from the
    /// active tile's *displaced* position with a smooth distance falloff.
    private func tileOffset(
        index: Int,
        activeIndex: Int?,
        source: CGSize,
        layout: TileLayout
    ) -> CGSize {
        guard let active = activeIndex else { return .zero }
        if index == active { return source }

        let slot = layout.slots[index]
        let activeSlot = layout.slots[active]
        // Active tile's live centre.
        let activeNow = CGPoint(x: activeSlot.x + source.width,
                                y: activeSlot.y + source.height)

        let dx = slot.x - activeNow.x
        let dy = slot.y - activeNow.y
        let dist = max(sqrt(dx * dx + dy * dy), 0.0001)

        // Smooth falloff: full strength when overlapping, zero past `reach`.
        let reach = layout.reach
        let falloff = max(0, 1 - dist / reach)
        let strength = falloff * falloff  // ease so distant tiles barely move
        let push = layout.maxShove * strength

        let nx = dx / dist
        let ny = dy / dist
        return CGSize(width: nx * push, height: ny * push)
    }

    // MARK: - Demo drive: virtual finger.

    struct DemoDrive {
        var activeIndex: Int
        var translation: CGSize
        var lift: CGFloat
    }

    /// Cycles one tile at a time: fling out, then a damped spring back to rest,
    /// then the next tile. One fling-and-settle cycle lasts ~3.2s.
    private func demoDrive(time: Double, count: Int) -> DemoDrive {
        let safeCount = max(count, 1)
        let cycle: Double = 3.2
        let phase = time.truncatingRemainder(dividingBy: cycle) / cycle  // 0..1
        let cycleNumber = Int(floor(time / cycle))
        let active = ((cycleNumber % safeCount) + safeCount) % safeCount

        // A wandering fling direction so each cycle differs.
        let dirAngle = Double(cycleNumber) * 2.39996  // golden-ish angle
        let dirX = CGFloat(cos(dirAngle))
        let dirY = CGFloat(sin(dirAngle))

        // Magnitude: rises quickly (fling out) then a damped spring recoil to 0.
        let magnitude = flingMagnitude(phase: phase)
        let amp = demoReach()
        let translation = CGSize(width: dirX * amp * magnitude,
                                 height: dirY * amp * magnitude)
        let lift = CGFloat(min(1, max(0, magnitude) * 1.4))
        return DemoDrive(activeIndex: active, translation: translation, lift: lift)
    }

    /// Normalised fling profile over the cycle phase 0...1.
    /// Fast rise to a peak, then a decaying oscillation back to rest.
    private func flingMagnitude(phase p: Double) -> CGFloat {
        if p < 0.18 {
            // Snappy pull-out.
            let x = p / 0.18
            return CGFloat(sin(x * Double.pi / 2))
        } else {
            // Damped recoil: e^-kt * cos back to rest.
            let x = (p - 0.18) / 0.82            // 0..1
            let decay = exp(-3.4 * x)
            let wobble = cos(x * Double.pi * 3.0)
            let value = decay * wobble
            return CGFloat(value)
        }
    }

    private func demoReach() -> CGFloat { 1.0 }  // scaled inside demoDrive via amp

    // MARK: - Drag gesture (interactive only).

    private func dragGesture(for index: Int) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                releasing = false
                if draggedIndex != index {
                    draggedIndex = index
                }
                dragTranslation = value.translation
            }
            .onEnded { _ in
                // Keep `draggedIndex` set through the spring so the active tile
                // AND its shoved neighbours spring back together; only release
                // control once the recoil completes. Without this the offset
                // would snap to .zero the instant activeIndex went nil.
                settleTick &+= 1
                withAnimation(.spring(response: 0.5, dampingFraction: 0.45)) {
                    releasing = true
                    dragTranslation = .zero
                } completion: {
                    // Only clear if no new tile was grabbed mid-recoil; a fresh
                    // `onChanged` sets `releasing = false`, so this guard avoids
                    // clobbering an in-progress second drag.
                    if releasing {
                        draggedIndex = nil
                        releasing = false
                    }
                }
            }
    }

    // MARK: - Layout: slot positions + physics scale, all from geometry.

    struct TileLayout {
        var slots: [CGPoint]
        var fontSize: CGFloat
        var maxShove: CGFloat
        var reach: CGFloat
    }

    /// A simple flowing wrap: tiles fill left-to-right, wrapping to new rows,
    /// centred vertically. Everything scales off `size` so it reads in a 120pt
    /// tile and a large detail area alike.
    private func makeLayout(in size: CGSize) -> TileLayout {
        let count = words.count
        let safeWidth = max(size.width, 1)
        let safeHeight = max(size.height, 1)
        let minSide = min(safeWidth, safeHeight)

        // Pick a row count that keeps tiles legible across sizes.
        let rows = max(rowCount(for: count, size: size), 1)
        let perRow = max(Int(ceil(Double(count) / Double(rows))), 1)

        let fontSize = max(8, min(safeHeight / CGFloat(rows) * 0.34,
                                  safeWidth / CGFloat(perRow) * 0.30))

        let rowHeight = safeHeight / CGFloat(rows + 1)
        var slots: [CGPoint] = []
        slots.reserveCapacity(count)

        for r in 0..<rows {
            let start = r * perRow
            let end = min(start + perRow, count)
            if start >= end { continue }
            let n = end - start
            let colWidth = safeWidth / CGFloat(n + 1)
            let y = rowHeight * CGFloat(r + 1)
                + (safeHeight - rowHeight * CGFloat(rows + 1)) / 2
                + rowHeight / 2
            for c in 0..<n {
                let x = colWidth * CGFloat(c + 1)
                slots.append(CGPoint(x: x, y: y))
            }
        }
        // Safety: ensure we always have a slot per word.
        while slots.count < count {
            slots.append(CGPoint(x: safeWidth / 2, y: safeHeight / 2))
        }

        let maxShove = minSide * 0.16
        let reach = max(minSide * 0.55, 1)
        return TileLayout(slots: slots, fontSize: fontSize, maxShove: maxShove, reach: reach)
    }

    private func rowCount(for count: Int, size: CGSize) -> Int {
        let aspect = size.width / max(size.height, 1)
        if aspect > 1.6 { return 2 }        // wide detail area
        if size.height < 200 { return 3 }   // small grid tile
        return 4
    }
}

// MARK: - sensoryFeedback compatibility shim.

private extension View {
    @ViewBuilder
    func sensoryFeedbackCompat(trigger: Int) -> some View {
        if #available(iOS 17.0, *) {
            self.sensoryFeedback(.impact(flexibility: .soft), trigger: trigger)
        } else {
            self
        }
    }
}
