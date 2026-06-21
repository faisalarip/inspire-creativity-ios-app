// catalog-id: nav-rolling-bead-tabs
import SwiftUI

// MARK: - Rolling Bead Tabs
//
// The active-tab indicator is a solid marble that physically rolls along the
// tab bar to the selected tab. Its rolling spin is coupled to the SAME animated
// position value as its horizontal offset, so the spring's overshoot lives in
// one place and the spin overshoots in lockstep with the x-bounce (rolling
// without slipping: angle = distance / radius). A KeyframeAnimator layers a
// brake-phase squash (x-stretch during travel, then a damped settle wobble) on
// top, as an independent transform.
//
// demo == true  -> a PhaseAnimator auto-rolls the bead across the tabs forever.
// demo == false -> tap a tab to roll the bead there (the faithful tap-driven
//                  interaction from the spec).

struct RollingBeadTabsView: View {
    var demo: Bool = false

    @State private var selectedIndex: Int = 0

    private let tabCount = 4
    private let symbols = ["house.fill", "magnifyingglass", "bell.fill", "person.fill"]

    var body: some View {
        GeometryReader { proxy in
            let metrics = RollingBeadTabsView_Metrics(size: proxy.size, tabCount: tabCount)
            content(metrics: metrics)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundFill)
    }

    // MARK: Mode switch

    @ViewBuilder
    private func content(metrics: RollingBeadTabsView_Metrics) -> some View {
        if demo {
            demoContent(metrics: metrics)
        } else {
            interactiveContent(metrics: metrics)
        }
    }

    // demo: a trigger-less PhaseAnimator continuously cycles the tab indices,
    // .spring(bounce:0.4) rolls the bead between them forever.
    @ViewBuilder
    private func demoContent(metrics: RollingBeadTabsView_Metrics) -> some View {
        PhaseAnimator(phaseSequence) { index in
            barBody(metrics: metrics, activeIndex: index)
        } animation: { _ in
            .spring(duration: 0.85, bounce: 0.4)
        }
    }

    // real: tap a tab -> selectedIndex; the same spring rolls the bead.
    @ViewBuilder
    private func interactiveContent(metrics: RollingBeadTabsView_Metrics) -> some View {
        barBody(metrics: metrics, activeIndex: selectedIndex)
            .animation(.spring(duration: 0.85, bounce: 0.4), value: selectedIndex)
            .overlay(tapTargets(metrics: metrics))
    }

    // A long, looping walk across the tabs so we exercise both short hops and
    // long jumps (where the overshoot is most visible).
    private var phaseSequence: [Int] {
        [0, 1, 2, 3, 2, 0, 3, 1]
    }

    // MARK: Shared bar

    @ViewBuilder
    private func barBody(metrics: RollingBeadTabsView_Metrics, activeIndex: Int) -> some View {
        ZStack {
            trackView(metrics: metrics)
            RollingBeadTabsView_BeadView(metrics: metrics, activeIndex: activeIndex)
            iconRow(metrics: metrics, activeIndex: activeIndex)
        }
    }

    // MARK: Track

    @ViewBuilder
    private func trackView(metrics: RollingBeadTabsView_Metrics) -> some View {
        let h = metrics.trackHeight
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.12, blue: 0.16),
                        Color(red: 0.06, green: 0.07, blue: 0.10)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay(
                Capsule().strokeBorder(
                    Color(red: 1, green: 1, blue: 1).opacity(0.06),
                    lineWidth: 1
                )
            )
            .frame(width: metrics.trackWidth, height: h)
            .position(x: metrics.size.width / 2, y: metrics.midY)
            .shadow(color: Color(red: 0, green: 0, blue: 0).opacity(0.35),
                    radius: h * 0.18, y: h * 0.10)
    }

    // MARK: Icons

    @ViewBuilder
    private func iconRow(metrics: RollingBeadTabsView_Metrics, activeIndex: Int) -> some View {
        ForEach(0..<tabCount, id: \.self) { i in
            let active = (i == activeIndex)
            Image(systemName: symbols[i])
                .font(.system(size: metrics.iconSize, weight: .semibold))
                .foregroundStyle(
                    active
                    ? Color(red: 0.07, green: 0.08, blue: 0.11)
                    : Color(red: 0.62, green: 0.66, blue: 0.74)
                )
                .scaleEffect(active ? 1.04 : 1.0)
                .position(x: metrics.centerX(for: i), y: metrics.midY)
                .animation(.easeOut(duration: 0.3), value: activeIndex)
        }
    }

    // MARK: Tap layer (interactive only)

    @ViewBuilder
    private func tapTargets(metrics: RollingBeadTabsView_Metrics) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<tabCount, id: \.self) { i in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedIndex = i }
            }
        }
        .frame(width: metrics.trackWidth, height: metrics.trackHeight * 1.6)
        .position(x: metrics.size.width / 2, y: metrics.midY)
    }

    private var backgroundFill: some View {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.05, blue: 0.07),
                Color(red: 0.02, green: 0.03, blue: 0.04)
            ],
            startPoint: .top, endPoint: .bottom
        )
    }
}

// MARK: - Bead

private struct RollingBeadTabsView_BeadView: View {
    let metrics: RollingBeadTabsView_Metrics
    let activeIndex: Int

    var body: some View {
        let targetX = metrics.centerX(for: activeIndex)
        beadSurface
            .frame(width: metrics.beadSize, height: metrics.beadSize)
            // Single carrier: offset + spin both interpolate from `centerX`,
            // so the spring overshoot is shared between travel and spin.
            .modifier(RollingBeadTabsView_RollingModifier(centerX: targetX,
                                      restingX: metrics.size.width / 2,
                                      radius: metrics.beadSize / 2))
            // Brake-phase squash, re-keyed by the index change.
            .modifier(RollingBeadTabsView_SquashModifier(trigger: activeIndex))
            .position(x: metrics.size.width / 2, y: metrics.midY)
            .shadow(color: Color(red: 0.30, green: 0.55, blue: 1.0).opacity(0.45),
                    radius: metrics.beadSize * 0.22, y: metrics.beadSize * 0.10)
    }

    // The bead carries off-center surface detail so its rotation is visible —
    // a uniform disc spinning looks identical to one at rest.
    private var beadSurface: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.55, green: 0.78, blue: 1.0),
                            Color(red: 0.22, green: 0.46, blue: 0.95),
                            Color(red: 0.12, green: 0.28, blue: 0.72)
                        ],
                        center: UnitPoint(x: 0.34, y: 0.30),
                        startRadius: 0,
                        endRadius: metrics.beadSize * 0.72
                    )
                )

            // Rotating surface marks (these reveal the spin).
            ForEach(0..<3, id: \.self) { k in
                Circle()
                    .fill(Color(red: 0.85, green: 0.93, blue: 1.0).opacity(0.55))
                    .frame(width: metrics.beadSize * 0.12,
                           height: metrics.beadSize * 0.12)
                    .offset(y: -metrics.beadSize * 0.27)
                    .rotationEffect(.degrees(Double(k) * 120))
            }

            // A meridian band so a full revolution is unmistakable.
            Capsule()
                .fill(Color(red: 0.10, green: 0.20, blue: 0.50).opacity(0.45))
                .frame(width: metrics.beadSize * 0.10,
                       height: metrics.beadSize * 0.86)

            Circle()
                .strokeBorder(Color(red: 1, green: 1, blue: 1).opacity(0.18),
                              lineWidth: max(1, metrics.beadSize * 0.03))
        }
        .overlay(
            // Fixed specular highlight (does NOT rotate — sells a glossy marble).
            Circle()
                .fill(Color(red: 1, green: 1, blue: 1).opacity(0.55))
                .frame(width: metrics.beadSize * 0.18,
                       height: metrics.beadSize * 0.18)
                .blur(radius: metrics.beadSize * 0.04)
                .offset(x: -metrics.beadSize * 0.18,
                        y: -metrics.beadSize * 0.20)
        )
        .clipShape(Circle())
    }
}

// MARK: - Rolling modifier (offset + spin from one Animatable value)

private struct RollingBeadTabsView_RollingModifier: ViewModifier, Animatable {
    var centerX: CGFloat
    let restingX: CGFloat
    let radius: CGFloat

    // Animating this drives the spring; offset & rotation read the same value,
    // so overshoot is shared and the marble rolls without slipping.
    var animatableData: CGFloat {
        get { centerX }
        set { centerX = newValue }
    }

    func body(content: Content) -> some View {
        let travel = centerX - restingX
        let angle = radius > 0 ? Double(travel / radius) : 0
        content
            .rotationEffect(.radians(angle))
            .offset(x: travel)
    }
}

// MARK: - Squash modifier (brake-phase, KeyframeAnimator)

private struct RollingBeadTabsView_SquashModifier: ViewModifier {
    let trigger: Int

    func body(content: Content) -> some View {
        KeyframeAnimator(initialValue: Squash(),
                         trigger: trigger) { s in
            content.scaleEffect(x: s.scaleX, y: s.scaleY, anchor: .center)
        } keyframes: { _ in
            // x-stretch as it launches & rolls, then a damped wobble settle.
            KeyframeTrack(\.scaleX) {
                SpringKeyframe(1.22, duration: 0.30, spring: .snappy)
                SpringKeyframe(0.92, duration: 0.28, spring: .bouncy)
                SpringKeyframe(1.05, duration: 0.18, spring: .bouncy)
                SpringKeyframe(1.0, duration: 0.20, spring: .smooth)
            }
            KeyframeTrack(\.scaleY) {
                SpringKeyframe(0.84, duration: 0.30, spring: .snappy)
                SpringKeyframe(1.08, duration: 0.28, spring: .bouncy)
                SpringKeyframe(0.96, duration: 0.18, spring: .bouncy)
                SpringKeyframe(1.0, duration: 0.20, spring: .smooth)
            }
        }
    }

    struct Squash {
        var scaleX: CGFloat = 1.0
        var scaleY: CGFloat = 1.0
    }
}

// MARK: - Layout metrics

private struct RollingBeadTabsView_Metrics {
    let size: CGSize
    let tabCount: Int

    var midY: CGFloat { size.height / 2 }

    // The track spans most of the width with side insets.
    var sideInset: CGFloat { max(10, size.width * 0.08) }
    var trackWidth: CGFloat { max(1, size.width - sideInset * 2) }

    var trackHeight: CGFloat {
        min(size.height * 0.46, size.width * 0.16).clampedLow(12)
    }

    var beadSize: CGFloat {
        (trackHeight * 0.82).clampedLow(10)
    }

    var iconSize: CGFloat {
        (trackHeight * 0.40).clampedLow(8)
    }

    var slotWidth: CGFloat {
        tabCount > 0 ? trackWidth / CGFloat(tabCount) : trackWidth
    }

    func centerX(for index: Int) -> CGFloat {
        let start = size.width / 2 - trackWidth / 2
        return start + slotWidth * (CGFloat(index) + 0.5)
    }
}

private extension CGFloat {
    func clampedLow(_ low: CGFloat) -> CGFloat { Swift.max(self, low) }
}
