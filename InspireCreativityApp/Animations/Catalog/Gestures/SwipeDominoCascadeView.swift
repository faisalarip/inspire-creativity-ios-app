// catalog-id: ges-swipe-domino-cascade
import SwiftUI

// MARK: - Domino Swipe Cascade
// Swipe across a row of standing tiles and they topple in sequence, each
// knocking the next with a slight delay and angular fall; the last one fires
// the action. A single `progress` value (the topple-front position) drives
// both the self-running demo loop and the live drag interaction.

struct SwipeDominoCascadeView: View {
    var demo: Bool = false

    // Live interactive state
    @State private var dragProgress: Double = 0
    @State private var isDragging: Bool = false
    @State private var fallenCount: Int = 0
    @State private var didComplete: Bool = false

    private let tileCount: Int = 6

    var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // Haptics only in the live (non-demo) component.
        .modifier(
            SwipeDominoCascadeView_DominoHaptics(
                enabled: !demo,
                fallenCount: fallenCount,
                didComplete: didComplete
            )
        )
    }

    // MARK: Content

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if demo {
            TimelineView(.animation) { timeline in
                let p = demoProgress(at: timeline.date)
                row(progress: p, in: size, completed: p > 0.96)
            }
        } else {
            row(progress: dragProgress, in: size, completed: didComplete)
                .contentShape(Rectangle())
                .gesture(dragGesture(in: size))
        }
    }

    // MARK: Row of tiles

    private func row(progress: Double, in size: CGSize, completed: Bool) -> some View {
        let layout = SwipeDominoCascadeView_DominoLayout(size: size, count: tileCount)
        return ZStack {
            backdrop(in: size)
            floor(in: size, layout: layout)

            ForEach(0..<tileCount, id: \.self) { index in
                let a = angle(index: index, progress: progress)
                SwipeDominoCascadeView_DominoTile(
                    isLast: index == tileCount - 1,
                    triggered: completed && index == tileCount - 1,
                    width: layout.tileWidth,
                    height: layout.tileHeight
                )
                .rotation3DEffect(
                    .degrees(a),
                    axis: (x: 1, y: 0, z: 0),
                    anchor: .bottom,
                    perspective: 0.42
                )
                .frame(width: layout.tileWidth, height: layout.tileHeight, alignment: .bottom)
                .position(
                    x: layout.x(for: index),
                    y: layout.baselineY - layout.tileHeight / 2
                )
            }

            rewardBurst(in: size, layout: layout, show: completed)
        }
        .compositingGroup()
    }

    // MARK: Backdrop

    private func backdrop(in size: CGSize) -> some View {
        let dim = min(size.width, size.height)
        return RoundedRectangle(cornerRadius: dim * 0.10, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.08, blue: 0.13),
                        Color(red: 0.04, green: 0.05, blue: 0.09)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    // MARK: Floor / baseline (always visible so a frame is never blank)

    private func floor(in size: CGSize, layout: SwipeDominoCascadeView_DominoLayout) -> some View {
        let y = layout.baselineY + layout.tileHeight * 0.02
        return Path { path in
            path.move(to: CGPoint(x: layout.leftInset, y: y))
            path.addLine(to: CGPoint(x: size.width - layout.leftInset, y: y))
        }
        .stroke(
            LinearGradient(
                colors: [
                    Color(red: 0.20, green: 0.22, blue: 0.30).opacity(0.0),
                    Color(red: 0.36, green: 0.40, blue: 0.52).opacity(0.9),
                    Color(red: 0.20, green: 0.22, blue: 0.30).opacity(0.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            ),
            style: StrokeStyle(lineWidth: max(1.0, layout.tileWidth * 0.06), lineCap: .round)
        )
    }

    // MARK: Reward burst on the last tile

    @ViewBuilder
    private func rewardBurst(in size: CGSize, layout: SwipeDominoCascadeView_DominoLayout, show: Bool) -> some View {
        let cx = layout.x(for: tileCount - 1)
        let cy = layout.baselineY - layout.tileHeight * 0.18
        let r = layout.tileWidth * 1.9

        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.35, green: 0.95, blue: 0.62).opacity(0.55),
                            Color(red: 0.35, green: 0.95, blue: 0.62).opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: r
                    )
                )
                .frame(width: r * 2, height: r * 2)
                .scaleEffect(show ? 1.0 : 0.2)
                .opacity(show ? 1.0 : 0.0)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: layout.tileWidth * 1.05, weight: .bold))
                .foregroundStyle(Color(red: 0.40, green: 0.98, blue: 0.66))
                .shadow(color: Color(red: 0.20, green: 0.80, blue: 0.50).opacity(0.8), radius: 6)
                .scaleEffect(show ? 1.0 : 0.4)
                .opacity(show ? 1.0 : 0.0)
        }
        .position(x: cx, y: cy)
        .animation(.spring(duration: 0.45, bounce: 0.55), value: show)
        .allowsHitTesting(false)
    }

    // MARK: Cascade angle — continuous function of (index, progress)

    /// Each tile begins to fall as the topple-front passes its position, with a
    /// spatial stagger that *is* the per-index delay and the propagating wave.
    private func angle(index: Int, progress: Double) -> Double {
        let maxAngle: Double = 80.0           // capped < 90 to avoid the invisible sliver
        let window: Double = 0.26             // how long a single tile takes to fall
        let span: Double = 0.74               // fraction of progress the front travels over tiles
        let start = (Double(index) / Double(max(1, tileCount - 1))) * span
        let local = (progress - start) / window
        return maxAngle * smoothstep(local)
    }

    private func smoothstep(_ x: Double) -> Double {
        let t = min(1.0, max(0.0, x))
        return t * t * (3.0 - 2.0 * t)
    }

    // MARK: Demo loop — triangle wave 0 -> 1 -> 0 (cascade falls then stands)

    private func demoProgress(at date: Date) -> Double {
        let period: Double = 3.4
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
        // Hold a beat at the top so the completed reward is readable.
        let up = 0.46, hold = 0.16
        if t < up {
            return easeInOut(t / up)
        } else if t < up + hold {
            return 1.0
        } else {
            let d = (t - up - hold) / (1.0 - up - hold)
            return 1.0 - easeInOut(d)
        }
    }

    private func easeInOut(_ x: Double) -> Double {
        let t = min(1.0, max(0.0, x))
        return t * t * (3.0 - 2.0 * t)
    }

    // MARK: Live drag — location.x is the topple-front

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDragging = true
                let layout = SwipeDominoCascadeView_DominoLayout(size: size, count: tileCount)
                let raw = (value.location.x - layout.leftInset)
                    / max(1.0, layout.usableWidth)
                let p = min(1.0, max(0.0, raw))
                dragProgress = p
                updateDerivedState(progress: p)
            }
            .onEnded { _ in
                isDragging = false
                if dragProgress > 0.9 {
                    // Settle fully toppled, show reward, then reset to standing.
                    withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                        dragProgress = 1.0
                        didComplete = true
                        fallenCount = tileCount
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                        guard !isDragging else { return }
                        withAnimation(.spring(duration: 0.6, bounce: 0.3)) {
                            dragProgress = 0
                        }
                        didComplete = false
                        fallenCount = 0
                    }
                } else {
                    withAnimation(.spring(duration: 0.55, bounce: 0.35)) {
                        dragProgress = 0
                    }
                    didComplete = false
                    fallenCount = 0
                }
            }
    }

    /// Count how many tiles have visibly fallen, to drive per-topple haptics.
    private func updateDerivedState(progress: Double) {
        var count = 0
        for i in 0..<tileCount where angle(index: i, progress: progress) > 60.0 {
            count += 1
        }
        if count != fallenCount {
            fallenCount = count
        }
        let complete = progress > 0.96
        if complete != didComplete {
            didComplete = complete
        }
    }
}

// MARK: - Layout helper

private struct SwipeDominoCascadeView_DominoLayout {
    let size: CGSize
    let count: Int

    var minDim: CGFloat { min(size.width, size.height) }
    var leftInset: CGFloat { size.width * 0.10 }
    var usableWidth: CGFloat { size.width - leftInset * 2 }
    var tileWidth: CGFloat { max(6.0, usableWidth / (CGFloat(count) * 1.7)) }
    var tileHeight: CGFloat { tileWidth * 2.6 }
    var baselineY: CGFloat { size.height * 0.66 }

    func x(for index: Int) -> CGFloat {
        let denom = CGFloat(max(1, count - 1))
        return leftInset + usableWidth * (CGFloat(index) / denom)
    }
}

// MARK: - A single domino tile

private struct SwipeDominoCascadeView_DominoTile: View {
    let isLast: Bool
    let triggered: Bool
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.18, style: .continuous)
                .fill(faceGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: width * 0.18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.35),
                                    Color.black.opacity(0.25)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: max(0.75, width * 0.04)
                        )
                )
                .shadow(color: Color.black.opacity(0.45), radius: width * 0.18, x: 0, y: width * 0.12)

            pips
        }
        .frame(width: width, height: height)
    }

    private var faceGradient: LinearGradient {
        if isLast {
            return LinearGradient(
                colors: triggered
                    ? [Color(red: 0.35, green: 0.95, blue: 0.62),
                       Color(red: 0.20, green: 0.72, blue: 0.46)]
                    : [Color(red: 0.98, green: 0.78, blue: 0.36),
                       Color(red: 0.86, green: 0.55, blue: 0.20)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: [
                Color(red: 0.93, green: 0.94, blue: 0.98),
                Color(red: 0.72, green: 0.76, blue: 0.86)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // A center divider line plus a couple of pips so each tile reads as a domino.
    private var pips: some View {
        VStack(spacing: height * 0.10) {
            pip
            Rectangle()
                .fill(Color.black.opacity(0.18))
                .frame(width: width * 0.6, height: max(1.0, height * 0.02))
            pip
        }
    }

    private var pip: some View {
        Circle()
            .fill(
                isLast
                    ? Color.black.opacity(0.28)
                    : Color(red: 0.30, green: 0.34, blue: 0.46).opacity(0.85)
            )
            .frame(width: width * 0.22, height: width * 0.22)
    }
}

// MARK: - Haptics modifier (live mode only)

private struct SwipeDominoCascadeView_DominoHaptics: ViewModifier {
    let enabled: Bool
    let fallenCount: Int
    let didComplete: Bool

    func body(content: Content) -> some View {
        if enabled {
            content
                .sensoryFeedback(.impact(weight: .light), trigger: fallenCount)
                .sensoryFeedback(.success, trigger: didComplete) { _, now in now }
        } else {
            content
        }
    }
}
