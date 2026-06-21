// catalog-id: mi-jelly-count-badge
import SwiftUI

// MARK: - Jelly Count Badge
// A notification badge whose number drops in from above, squashing the badge
// into a wobbly gelatin blob that springs back to a clean circle.
// interaction == "auto": both demo states are self-driving on a ~2.8s loop.
// demo == false additionally lets a tap bump the count for tactility.
struct JellyCountBadgeView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            JellyCountBadgeView_JellyBadgeStage(side: min(geo.size.width, geo.size.height),
                            interactive: !demo)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Stage (host icon + badge), drives the auto loop

private struct JellyCountBadgeView_JellyBadgeStage: View {
    let side: CGFloat
    let interactive: Bool

    // Cycle over a small, legible range so the loop stays clean.
    private let sequence: [Int] = [1, 2, 3, 5, 8, 12, 1]

    @State private var index: Int = 0
    @State private var count: Int = 1
    @State private var didAppear: Bool = false

    private let loopInterval: TimeInterval = 2.8

    var body: some View {
        let host = side * 0.62
        let corner = host * 0.26

        ZStack {
            hostIcon(side: host, corner: corner)

            JellyCountBadgeView_JellyBadge(count: count, diameter: badgeDiameter(host: host))
                .offset(x: host * 0.40, y: -host * 0.40)
                .contentShape(Circle())
                .onTapGesture {
                    guard interactive else { return }
                    bump()
                }
        }
        .frame(width: side, height: side)
        // Bare increments won't move; the transition needs an animation
        // transaction keyed to the displayed count.
        .animation(.spring(response: 0.42, dampingFraction: 0.62), value: count)
        .onAppear { startLoop() }
    }

    private func badgeDiameter(host: CGFloat) -> CGFloat {
        let base = host * 0.46
        // Widen slightly for two-digit values so digits stay legible.
        return count >= 10 ? base * 1.18 : base
    }

    // MARK: Host app-icon look

    @ViewBuilder
    private func hostIcon(side: CGFloat, corner: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.30, green: 0.32, blue: 0.46),
                        Color(red: 0.16, green: 0.17, blue: 0.27)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            )
            .overlay(envelopeGlyph(side: side))
            .frame(width: side, height: side)
            .shadow(color: Color.black.opacity(0.35),
                    radius: side * 0.10, x: 0, y: side * 0.06)
    }

    @ViewBuilder
    private func envelopeGlyph(side: CGFloat) -> some View {
        Image(systemName: "bell.fill")
            .font(.system(size: side * 0.40, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.92))
    }

    // MARK: Loop + interaction

    private func startLoop() {
        guard !didAppear else { return }
        didAppear = true
        advance() // first hop is part of the loop, not instant
    }

    private func advance() {
        DispatchQueue.main.asyncAfter(deadline: .now() + loopInterval) {
            index = (index + 1) % sequence.count
            count = sequence[index]
            advance()
        }
    }

    private func bump() {
        if count >= 99 {
            count = 1
        } else {
            count += 1
        }
    }
}

// MARK: - The jelly badge itself

private struct JellyCountBadgeView_JellyBadge: View {
    let count: Int
    let diameter: CGFloat

    var body: some View {
        // PhaseAnimator(trigger:) runs the full squash->overshoot->settle
        // sequence exactly once per count change — the spec's behavior.
        PhaseAnimator(JellyCountBadgeView_JellyPhase.allCases, trigger: count) { phase in
            badgeBody
                .scaleEffect(x: phase.scaleX, y: phase.scaleY, anchor: .bottom)
        } animation: { phase in
            phase.animation
        }
    }

    private var badgeBody: some View {
        ZStack {
            // Soft contact shadow grounds the blob.
            Circle()
                .fill(Color.black.opacity(0.30))
                .frame(width: diameter, height: diameter)
                .blur(radius: diameter * 0.10)
                .offset(y: diameter * 0.06)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.00, green: 0.38, blue: 0.42),
                            Color(red: 0.93, green: 0.16, blue: 0.27)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(glossHighlight)
                .overlay(
                    Circle().strokeBorder(Color.white.opacity(0.22),
                                          lineWidth: max(1, diameter * 0.03))
                )
                .frame(width: diameter, height: diameter)

            countLabel
        }
        .compositingGroup()
    }

    private var glossHighlight: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color.white.opacity(0.55), Color.clear],
                    center: UnitPoint(x: 0.32, y: 0.26),
                    startRadius: 0,
                    endRadius: diameter * 0.55
                )
            )
            .padding(diameter * 0.06)
    }

    private var countLabel: some View {
        // The number drops in from above on each new value. The .id forces a
        // fresh view so the move/opacity transition fires; this is the hero
        // motion, so we do NOT also layer contentTransition(.numericText).
        Text("\(count)")
            .font(.system(size: diameter * 0.52, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .shadow(color: Color.black.opacity(0.25), radius: 1, y: 1)
            .id(count)
            .transition(
                .asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                )
            )
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())
    }
}

// MARK: - Jelly squash phases

private enum JellyCountBadgeView_JellyPhase: CaseIterable {
    case rest        // resting circle
    case squash      // number lands: wide + short
    case rebound     // overshoot tall + thin
    case settle      // springs back to a circle

    var scaleX: CGFloat {
        switch self {
        case .rest:    return 1.00
        case .squash:  return 1.26
        case .rebound: return 0.90
        case .settle:  return 1.00
        }
    }

    var scaleY: CGFloat {
        switch self {
        case .rest:    return 1.00
        case .squash:  return 0.76
        case .rebound: return 1.12
        case .settle:  return 1.00
        }
    }

    var animation: Animation {
        switch self {
        case .rest:    return .easeOut(duration: 0.10)
        case .squash:  return .spring(response: 0.18, dampingFraction: 0.55)
        case .rebound: return .spring(response: 0.26, dampingFraction: 0.50)
        case .settle:  return .spring(response: 0.55, dampingFraction: 0.42) // bouncy jelly settle
        }
    }
}
