// catalog-id: nav-typewriter-return-tabs
import SwiftUI

/// Ratchet Slide Tabs — the active-tab indicator advances like a ratcheting
/// mechanism: on switch it steps along a toothed rail one notch at a time with
/// a clicking detent at each tooth, accelerating across longer jumps and
/// braking into a hard stop with a tiny recoil at the destination.
///
/// Mechanism: a `KeyframeAnimator` drives the indicator's x through one
/// `LinearKeyframe` per intervening tooth (stepped, accelerating spacing), then
/// a `SpringKeyframe` brake + recoil at the destination. `sensoryFeedback`
/// fires on each switch. iOS 17.
struct TypewriterReturnTabsView: View {
    var demo: Bool = false

    private let tabs: [String] = ["Home", "Search", "Saved", "Profile"]

    // KeyframeAnimator needs a *committed* source and target so it knows how
    // far to travel. We mutate `source = target` first, then `target = i`, so
    // both land before the re-render and the ratchet always starts from the
    // tab we actually left (not always from index 0).
    @State private var source: Int = 0
    @State private var target: Int = 0

    // Demo auto-stepping clock phase.
    @State private var demoPhase: Int = 0

    var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundFill)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: target)
    }

    // MARK: - Layout

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        let count = tabs.count
        // The bar occupies a comfortable band; size everything off it so the
        // piece reads in a 120pt tile and a full detail area alike.
        let barHeight: CGFloat = min(max(size.height * 0.42, 40), 92)
        let barWidth: CGFloat = max(size.width - barHeight * 0.5, 1)
        let slotWidth: CGFloat = barWidth / CGFloat(count)
        let pillInset: CGFloat = slotWidth * 0.12
        let pillWidth: CGFloat = slotWidth - pillInset * 2
        let pillHeight: CGFloat = barHeight - barHeight * 0.22

        VStack(spacing: 0) {
            Spacer(minLength: 0)
            tabBar(
                barWidth: barWidth,
                barHeight: barHeight,
                slotWidth: slotWidth,
                pillInset: pillInset,
                pillWidth: pillWidth,
                pillHeight: pillHeight
            )
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(TypewriterReturnTabsView_DemoDriver(enabled: demo, phase: $demoPhase, count: count) { next in
            select(to: next)
        })
    }

    @ViewBuilder
    private func tabBar(
        barWidth: CGFloat,
        barHeight: CGFloat,
        slotWidth: CGFloat,
        pillInset: CGFloat,
        pillWidth: CGFloat,
        pillHeight: CGFloat
    ) -> some View {
        let corner: CGFloat = barHeight * 0.34

        ZStack(alignment: .leading) {
            // Rail trough.
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(railFill)
                .overlay(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .strokeBorder(railStroke, lineWidth: 1)
                )

            // Toothed rail — the tick marks that make the stepping legible.
            toothRail(barWidth: barWidth, barHeight: barHeight)

            // The ratcheting indicator pill.
            indicatorPill(
                slotWidth: slotWidth,
                pillInset: pillInset,
                pillWidth: pillWidth,
                pillHeight: pillHeight,
                barHeight: barHeight
            )

            // Tab labels on top, hit targets for the interactive build.
            labelRow(slotWidth: slotWidth, barHeight: barHeight)
        }
        .frame(width: barWidth, height: barHeight)
        .padding(.horizontal, (barHeight * 0.5) / 2)
    }

    // MARK: - Tooth rail

    @ViewBuilder
    private func toothRail(barWidth: CGFloat, barHeight: CGFloat) -> some View {
        let pitch = toothPitch(barWidth: barWidth)
        let count = max(Int((barWidth / pitch).rounded()) - 1, 1)
        let toothHeight: CGFloat = barHeight * 0.16
        Canvas { ctx, sz in
            var x = pitch
            let midY = sz.height / 2
            while x < sz.width - pitch * 0.5 {
                let rect = CGRect(
                    x: x - 0.6,
                    y: midY - toothHeight / 2,
                    width: 1.2,
                    height: toothHeight
                )
                ctx.fill(
                    Path(roundedRect: rect, cornerRadius: 0.6),
                    with: .color(toothColor)
                )
                x += pitch
            }
            _ = count
        }
        .allowsHitTesting(false)
    }

    // MARK: - Indicator

    @ViewBuilder
    private func indicatorPill(
        slotWidth: CGFloat,
        pillInset: CGFloat,
        pillWidth: CGFloat,
        pillHeight: CGFloat,
        barHeight: CGFloat
    ) -> some View {
        let corner: CGFloat = pillHeight * 0.42
        let startX = xFor(source, slotWidth: slotWidth, pillInset: pillInset)
        let endX = xFor(target, slotWidth: slotWidth, pillInset: pillInset)
        let barWidth = slotWidth * CGFloat(tabs.count)
        let pitch = toothPitch(barWidth: barWidth)

        KeyframeAnimator(initialValue: startX, trigger: target) { x in
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(pillFill)
                .overlay(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .strokeBorder(pillStroke, lineWidth: 1)
                )
                .frame(width: pillWidth, height: pillHeight)
                .shadow(color: pillGlow, radius: 8, x: 0, y: 0)
                .offset(x: x, y: 0)
        } keyframes: { _ in
            ratchetKeyframes(from: startX, to: endX, pitch: pitch)
        }
        .allowsHitTesting(false)
    }

    /// Builds the stepped, accelerating ratchet track from `start` to `end`.
    @KeyframesBuilder<CGFloat>
    private func ratchetKeyframes(
        from start: CGFloat,
        to end: CGFloat,
        pitch: CGFloat
    ) -> some Keyframes<CGFloat> {
        let distance = end - start
        let direction: CGFloat = distance >= 0 ? 1 : -1
        let span = abs(distance)
        // Number of detent steps; at least 1 so even an adjacent hop clicks.
        let teeth = max(Int((span / pitch).rounded()), 1)
        // No travel (e.g. first appear): a tiny hold avoids a spurious recoil.
        let overshoot: CGFloat = span > 0.5 ? direction * min(pitch * 0.5, 10) : 0

        // Force the true starting point with a near-instant keyframe so the
        // animator does not visually snap from a stale initialValue.
        LinearKeyframe(start, duration: 0.0001)

        // One LinearKeyframe per intervening tooth, durations shrinking so the
        // slide accelerates across the rail (cranking up to speed).
        for step in 1...teeth {
            let progress = CGFloat(step) / CGFloat(teeth)
            let notchX = start + distance * progress
            LinearKeyframe(notchX, duration: notchDuration(step: step, total: teeth))
        }

        // Brake: drive slightly past the target (the wall impact)...
        LinearKeyframe(end + overshoot, duration: 0.05)
        // ...then a spring settles back for the tiny recoil + hard stop.
        SpringKeyframe(end, duration: 0.28, spring: Spring(response: 0.22, dampingRatio: 0.55))
    }

    /// Per-notch duration: starts slow, accelerates to a fast crank.
    private func notchDuration(step: Int, total: Int) -> Double {
        guard total > 1 else { return 0.10 }
        let t = Double(step) / Double(total) // 0...1 across the rail
        // Ease-in on speed: longer at the start, shorter near the end.
        let fast: Double = 0.028
        let slow: Double = 0.085
        let eased = (1.0 - t) * (1.0 - t) // quadratic deceleration of *duration*
        return fast + (slow - fast) * eased
    }

    // MARK: - Labels / hit targets

    @ViewBuilder
    private func labelRow(slotWidth: CGFloat, barHeight: CGFloat) -> some View {
        let fontSize: CGFloat = min(max(barHeight * 0.26, 9), 16)
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, title in
                tabLabel(
                    title: title,
                    index: index,
                    fontSize: fontSize,
                    barHeight: barHeight
                )
                .frame(width: slotWidth, height: barHeight)
            }
        }
    }

    @ViewBuilder
    private func tabLabel(
        title: String,
        index: Int,
        fontSize: CGFloat,
        barHeight: CGFloat
    ) -> some View {
        let isActive = index == target
        Text(title)
            .font(.system(size: fontSize, weight: isActive ? .semibold : .medium, design: .rounded))
            .foregroundStyle(isActive ? activeLabel : idleLabel)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .allowsHitTesting(!demo)
            .onTapGesture { select(to: index) }
            .animation(.easeOut(duration: 0.25), value: target)
    }

    // MARK: - Selection engine (shared by tap + demo)

    /// Commit `source` before `target` so the KeyframeAnimator's initialValue
    /// and trigger stay consistent and the ratchet starts from the real tab.
    private func select(to index: Int) {
        guard index != target else { return }
        source = target
        target = index
    }

    // MARK: - Geometry helpers

    private func xFor(_ index: Int, slotWidth: CGFloat, pillInset: CGFloat) -> CGFloat {
        CGFloat(index) * slotWidth + pillInset
    }

    /// Fixed-ish tooth pitch so a wide bar yields more detents (more clicks)
    /// and a narrow tile still ratchets visibly.
    private func toothPitch(barWidth: CGFloat) -> CGFloat {
        let slot = barWidth / CGFloat(tabs.count)
        // ~4 sub-notches per slot, clamped to a tactile range.
        return min(max(slot / 4, 14), 34)
    }

    // MARK: - Palette (tint #101418)

    private var backgroundFill: some ShapeStyle {
        LinearGradient(
            colors: [
                Color(red: 0.063, green: 0.078, blue: 0.094),
                Color(red: 0.043, green: 0.055, blue: 0.070)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var railFill: some ShapeStyle {
        LinearGradient(
            colors: [
                Color(red: 0.094, green: 0.110, blue: 0.133),
                Color(red: 0.063, green: 0.075, blue: 0.094)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var railStroke: Color { Color(red: 0.20, green: 0.23, blue: 0.27).opacity(0.6) }
    private var toothColor: Color { Color(red: 0.42, green: 0.47, blue: 0.55).opacity(0.55) }

    private var pillFill: some ShapeStyle {
        LinearGradient(
            colors: [
                Color(red: 0.36, green: 0.62, blue: 0.95),
                Color(red: 0.24, green: 0.46, blue: 0.86)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var pillStroke: Color { Color(red: 0.62, green: 0.80, blue: 1.0).opacity(0.55) }
    private var pillGlow: Color { Color(red: 0.30, green: 0.55, blue: 0.95).opacity(0.45) }
    private var activeLabel: Color { Color(red: 1.0, green: 1.0, blue: 1.0) }
    private var idleLabel: Color { Color(red: 0.62, green: 0.67, blue: 0.74) }
}

// MARK: - Demo driver

/// Drives the demo auto-loop. A cancellable async timer acts as a ~3s clock;
/// on each tick it steps the selection, reusing the exact same ratchet engine
/// the tap path uses. Inert when `enabled` is false; cancels cleanly when the
/// flag toggles.
private struct TypewriterReturnTabsView_DemoDriver: ViewModifier {
    let enabled: Bool
    @Binding var phase: Int
    let count: Int
    let onStep: (Int) -> Void

    func body(content: Content) -> some View {
        content
            .task(id: enabled) {
                guard enabled, count > 0 else { return }
                var i = phase
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    if Task.isCancelled { break }
                    i = (i + 1) % count
                    phase = i
                    onStep(i)
                }
            }
    }
}
