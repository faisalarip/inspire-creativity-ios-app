// catalog-id: ges-swipe-elastic-reveal
import SwiftUI

/// Elastic Action Reveal
///
/// Swiping a list row left stretches a single trailing action button that
/// elongates elastically with diminishing-return resistance. Past a threshold
/// it pops into a wide pill that springs to full width and auto-fires with a
/// haptic confirmation.
///
/// - `demo == true`  → a self-driving PhaseAnimator loop cycles
///   rest → stretch → commit → rest so the tile is always alive (and never blank).
/// - `demo == false` → a real DragGesture(minimumDistance: 0) drives the pill
///   width via a rubber-band curve; past threshold it springs full + fires.
struct SwipeElasticRevealView: View {
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
            SwipeElasticRevealView_DemoReveal(size: size)
        } else {
            SwipeElasticRevealView_InteractiveReveal(size: size)
        }
    }
}

// MARK: - Shared geometry helpers

private enum SwipeElasticRevealView_RevealMath {
    /// Trailing inset so the row never bleeds into the tile edge.
    static func inset(for size: CGSize) -> CGFloat {
        max(8, min(size.width, size.height) * 0.07)
    }

    /// Resting width of the action pill (a tidy circle-ish nub).
    static func restWidth(for size: CGSize) -> CGFloat {
        max(34, min(size.width, size.height) * 0.30)
    }

    /// Width past which a release commits and fires.
    static func threshold(for size: CGSize) -> CGFloat {
        max(restWidth(for: size) + 18, size.width * 0.46)
    }

    /// Fully-committed width — spans the row, leaving the trailing inset.
    static func fullWidth(for size: CGSize) -> CGFloat {
        max(threshold(for: size) + 8, size.width - inset(for: size) * 2)
    }

    /// Diminishing-return resistance: grows quickly early, eases toward a soft
    /// cap so the pill feels stretchy and tactile rather than 1:1 linear.
    static func rubberBand(drag: CGFloat, size: CGSize) -> CGFloat {
        let rest = restWidth(for: size)
        let raw = max(0, drag)                 // leftward only
        let softCap: CGFloat = (fullWidth(for: size) - rest) * 1.15
        let eased = softCap * (1 - 1 / (raw / softCap + 1))
        return rest + eased
    }
}

// MARK: - Palette

private enum SwipeElasticRevealView_RevealPalette {
    static let panel = Color(red: 0.12, green: 0.13, blue: 0.18)
    static let panelEdge = Color(red: 0.22, green: 0.24, blue: 0.32)
    static let bar = Color(red: 0.32, green: 0.35, blue: 0.45)
    static let icon = Color(red: 0.55, green: 0.60, blue: 0.74)

    static let actionTop = Color(red: 0.98, green: 0.32, blue: 0.36)
    static let actionBottom = Color(red: 0.86, green: 0.16, blue: 0.42)

    static let firedTop = Color(red: 0.20, green: 0.78, blue: 0.52)
    static let firedBottom = Color(red: 0.10, green: 0.62, blue: 0.46)
}

// MARK: - Row content (always visible — guarantees "never blank")

private struct SwipeElasticRevealView_RevealRow: View {
    let size: CGSize
    /// How far the row content is pushed left by the growing pill.
    let push: CGFloat

    var body: some View {
        let inset = SwipeElasticRevealView_RevealMath.inset(for: size)
        let scale = min(size.width, size.height) / 120

        HStack(spacing: max(8, 12 * scale)) {
            avatar(scale: scale)
            VStack(alignment: .leading, spacing: max(5, 7 * scale)) {
                bar(widthFraction: 0.62, height: max(6, 9 * scale))
                bar(widthFraction: 0.40, height: max(5, 7 * scale))
                    .opacity(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, inset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .offset(x: -push)
    }

    private func avatar(scale: CGFloat) -> some View {
        let d = max(26, 38 * scale)
        return Circle()
            .fill(
                LinearGradient(
                    colors: [SwipeElasticRevealView_RevealPalette.bar, SwipeElasticRevealView_RevealPalette.panelEdge],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: d, height: d)
            .overlay(
                Image(systemName: "envelope.fill")
                    .font(.system(size: d * 0.42, weight: .semibold))
                    .foregroundStyle(SwipeElasticRevealView_RevealPalette.icon)
            )
    }

    private func bar(widthFraction: CGFloat, height: CGFloat) -> some View {
        Capsule()
            .fill(SwipeElasticRevealView_RevealPalette.bar)
            .frame(height: height)
            .frame(maxWidth: .infinity, alignment: .leading)
            .scaleEffect(x: widthFraction, anchor: .leading)
    }
}

// MARK: - The stretchy trailing action pill

private struct SwipeElasticRevealView_ActionPill: View {
    let size: CGSize
    let width: CGFloat
    let fired: Bool

    var body: some View {
        let inset = SwipeElasticRevealView_RevealMath.inset(for: size)
        let rest = SwipeElasticRevealView_RevealMath.restWidth(for: size)
        let height = pillHeight
        // Label fades in only once the pill is comfortably wider than its nub.
        let labelReveal = clamped((width - rest * 1.4) / (rest * 1.6))

        ZStack {
            Capsule()
                .fill(fillGradient)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
                .shadow(color: shadowColor, radius: 8, x: -2, y: 3)

            HStack(spacing: 6 * scale) {
                Image(systemName: fired ? "checkmark" : "trash.fill")
                    .font(.system(size: height * 0.40, weight: .bold))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))

                if labelReveal > 0.02 {
                    Text(fired ? "Done" : "Delete")
                        .font(.system(size: height * 0.34, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .fixedSize()
                        .opacity(labelReveal)
                        .scaleEffect(0.7 + 0.3 * labelReveal, anchor: .leading)
                }
            }
            .padding(.horizontal, height * 0.30)
        }
        .frame(width: max(rest, width), height: height)
        .padding(.trailing, inset)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var scale: CGFloat { min(size.width, size.height) / 120 }

    private var pillHeight: CGFloat {
        max(30, min(size.height * 0.52, SwipeElasticRevealView_RevealMath.restWidth(for: size)))
    }

    private var fillGradient: LinearGradient {
        let top = fired ? SwipeElasticRevealView_RevealPalette.firedTop : SwipeElasticRevealView_RevealPalette.actionTop
        let bottom = fired ? SwipeElasticRevealView_RevealPalette.firedBottom : SwipeElasticRevealView_RevealPalette.actionBottom
        return LinearGradient(
            colors: [top, bottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var shadowColor: Color {
        (fired ? SwipeElasticRevealView_RevealPalette.firedBottom : SwipeElasticRevealView_RevealPalette.actionBottom).opacity(0.5)
    }

    private func clamped(_ v: CGFloat) -> CGFloat { min(1, max(0, v)) }
}

// MARK: - Card chrome shared by both modes

private struct SwipeElasticRevealView_RevealCard<Pill: View>: View {
    let size: CGSize
    let push: CGFloat
    @ViewBuilder var pill: () -> Pill

    var body: some View {
        let corner = max(12, min(size.width, size.height) * 0.16)
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(SwipeElasticRevealView_RevealPalette.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .stroke(SwipeElasticRevealView_RevealPalette.panelEdge, lineWidth: 1)
                )

            SwipeElasticRevealView_RevealRow(size: size, push: push)
            pill()
        }
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .padding(max(6, min(size.width, size.height) * 0.06))
    }
}

// MARK: - Interactive (demo == false)

private struct SwipeElasticRevealView_InteractiveReveal: View {
    let size: CGSize

    @State private var pillWidth: CGFloat
    @State private var fired = false
    @State private var fireTick = 0

    init(size: CGSize) {
        self.size = size
        _pillWidth = State(initialValue: SwipeElasticRevealView_RevealMath.restWidth(for: size))
    }

    var body: some View {
        let rest = SwipeElasticRevealView_RevealMath.restWidth(for: size)
        let push = max(0, pillWidth - rest)

        SwipeElasticRevealView_RevealCard(size: size, push: push) {
            SwipeElasticRevealView_ActionPill(size: size, width: pillWidth, fired: fired)
        }
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .sensoryFeedback(.success, trigger: fireTick)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !fired else { return }
                let drag = max(0, -value.translation.width)
                pillWidth = SwipeElasticRevealView_RevealMath.rubberBand(drag: drag, size: size)
            }
            .onEnded { _ in
                guard !fired else { return }
                if pillWidth >= SwipeElasticRevealView_RevealMath.threshold(for: size) {
                    commit()
                } else {
                    springBack()
                }
            }
    }

    private func commit() {
        fired = true
        fireTick &+= 1
        withAnimation(.bouncy(duration: 0.45, extraBounce: 0.25)) {
            pillWidth = SwipeElasticRevealView_RevealMath.fullWidth(for: size)
        }
        // Reset so the tile stays reusable after firing.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                pillWidth = SwipeElasticRevealView_RevealMath.restWidth(for: size)
            }
            withAnimation(.easeInOut(duration: 0.3).delay(0.15)) {
                fired = false
            }
        }
    }

    private func springBack() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            pillWidth = SwipeElasticRevealView_RevealMath.restWidth(for: size)
        }
    }
}

// MARK: - Demo (demo == true) — self-driving, never blank

private enum SwipeElasticRevealView_RevealPhase: CaseIterable {
    case rest, stretch, commit
}

private struct SwipeElasticRevealView_DemoReveal: View {
    let size: CGSize

    var body: some View {
        PhaseAnimator(SwipeElasticRevealView_RevealPhase.allCases) { phase in
            frame(for: phase)
        } animation: { phase in
            animation(for: phase)
        }
    }

    @ViewBuilder
    private func frame(for phase: SwipeElasticRevealView_RevealPhase) -> some View {
        let width = pillWidth(for: phase)
        let rest = SwipeElasticRevealView_RevealMath.restWidth(for: size)
        let push = max(0, width - rest)

        SwipeElasticRevealView_RevealCard(size: size, push: push) {
            SwipeElasticRevealView_ActionPill(size: size, width: width, fired: phase == .commit)
        }
    }

    private func pillWidth(for phase: SwipeElasticRevealView_RevealPhase) -> CGFloat {
        switch phase {
        case .rest:    return SwipeElasticRevealView_RevealMath.restWidth(for: size)
        case .stretch: return SwipeElasticRevealView_RevealMath.threshold(for: size) + 6
        case .commit:  return SwipeElasticRevealView_RevealMath.fullWidth(for: size)
        }
    }

    private func animation(for phase: SwipeElasticRevealView_RevealPhase) -> Animation {
        switch phase {
        case .rest:    return .easeInOut(duration: 0.55)          // recoil back
        case .stretch: return .easeOut(duration: 1.25)            // slow elastic pull
        case .commit:  return .bouncy(duration: 0.5, extraBounce: 0.3) // snap wide
        }
    }
}
