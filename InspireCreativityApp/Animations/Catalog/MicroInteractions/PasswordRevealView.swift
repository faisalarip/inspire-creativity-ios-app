// catalog-id: mi-password-reveal
import SwiftUI

// Password Reveal Flip — Micro-interactions
// Tapping the eye toggles each masked dot flipping in sequence (rotation3DEffect axis:.y,
// per-index delay) to reveal its character at the 90° midpoint, while the SF Symbol eye
// blinks open/shut via contentTransition(.symbolEffect(.replace)).
// demo == true  -> PhaseAnimator self-drives the reveal/hide loop (transaction fires the
//                  symbolEffect blink + per-dot value-keyed staggered springs).
// demo == false -> tapping the eye toggles `revealed`, driving the same staggered flips.
struct PasswordRevealView: View {
    var demo: Bool = false

    @State private var revealed: Bool = false

    // Fixed demo string — six glyphs so the row reads as a short password.
    private let chars: [String] = ["S", "w", "i", "f", "t", "!"]

    var body: some View {
        GeometryReader { geo in
            content(size: geo.size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(size: CGSize) -> some View {
        if demo {
            PhaseAnimator([false, true]) { phase in
                rowAndEye(revealed: phase, size: size)
            } animation: { _ in
                // Timed curve (not a spring) so the loop length is deterministic.
                // ~1.6s per phase -> ~3.2s round-trip, inside the 2.5–4s window.
                // Longer than the last dot's delay (5 * 0.08) + flip (~0.5s) so the
                // staggered springs always finish before the phase flips back.
                .easeInOut(duration: 1.6)
            }
        } else {
            rowAndEye(revealed: revealed, size: size)
        }
    }

    // One render function for both modes guarantees parity: the per-dot springs are
    // keyed on the `revealed` argument, so in demo they fire off the PhaseAnimator's
    // changing `phase` value.
    private func rowAndEye(revealed: Bool, size: CGSize) -> some View {
        let metrics = PasswordRevealView_Metrics(size: size, count: chars.count)
        return VStack(spacing: metrics.vGap) {
            dotRow(revealed: revealed, metrics: metrics)
            eyeButton(revealed: revealed, metrics: metrics)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func dotRow(revealed: Bool, metrics: PasswordRevealView_Metrics) -> some View {
        HStack(spacing: metrics.hGap) {
            ForEach(chars.indices, id: \.self) { i in
                PasswordRevealView_FlipDot(
                    angle: revealed ? 180 : 0,
                    char: chars[i],
                    side: metrics.dot
                )
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.72)
                        .delay(Double(i) * 0.08),
                    value: revealed
                )
            }
        }
    }

    @ViewBuilder
    private func eyeButton(revealed: Bool, metrics: PasswordRevealView_Metrics) -> some View {
        let symbol = revealed ? "eye.fill" : "eye.slash.fill"
        Image(systemName: symbol)
            .font(.system(size: metrics.eye, weight: .semibold))
            .foregroundStyle(Self.accent)
            .contentTransition(.symbolEffect(.replace))
            .symbolEffect(.bounce, value: revealed)
            .frame(width: metrics.eye * 2.0, height: metrics.eye * 2.0)
            .background(
                Circle().fill(Self.eyeWell)
            )
            .overlay(
                Circle().strokeBorder(Self.accent.opacity(0.22), lineWidth: 1)
            )
            .contentShape(Circle())
            .onTapGesture {
                guard !demo else { return }
                // withAnimation so the symbolEffect blink + the per-dot flips both
                // run inside one transaction.
                withAnimation { self.revealed.toggle() }
            }
            .allowsHitTesting(!demo)
            .accessibilityLabel(revealed ? "Hide password" : "Reveal password")
    }

    // MARK: - Palette (literal colors, no design-system dependency)

    private static let accent = Color(red: 0.55, green: 0.80, blue: 1.0)
    private static let eyeWell = Color(red: 0.10, green: 0.10, blue: 0.16)
}

// MARK: - Layout metrics derived from the container size.

private struct PasswordRevealView_Metrics {
    let dot: CGFloat
    let hGap: CGFloat
    let vGap: CGFloat
    let eye: CGFloat

    init(size: CGSize, count: Int) {
        let w = max(size.width, 1)
        let h = max(size.height, 1)
        let n = CGFloat(max(count, 1))
        // Width budget: each dot plus a gap of ~0.35 * dot.
        let byWidth = w / (n * 1.45)
        let byHeight = h * 0.34
        let side = max(8, min(byWidth, byHeight, 64))
        self.dot = side
        self.hGap = max(3, side * 0.28)
        self.vGap = max(8, h * 0.10)
        self.eye = max(10, min(side * 0.62, 26))
    }
}

// MARK: - A single Animatable flipping dot.
// Conforms to Animatable so `body` re-runs every interpolated frame with the live
// `angle`; the mask/char swap therefore happens exactly at 90°, frame-synced to the
// spring with no separate opacity animation to desync.

private struct PasswordRevealView_FlipDot: View, Animatable {
    var angle: Double
    let char: String
    let side: CGFloat

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        // Past 90° the card is edge-on and we show the reverse (character) face.
        let showChar = angle >= 90

        return ZStack {
            maskFace
                .opacity(showChar ? 0 : 1)

            charFace
                .opacity(showChar ? 1 : 0)
                // Un-mirror the back face so revealed text isn't reversed.
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .frame(width: side, height: side * 1.25)
        .rotation3DEffect(
            .degrees(angle),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.4
        )
    }

    // Masked state: a faint card with a filled bullet so even an edge-on dot shows a sliver.
    private var maskFace: some View {
        cardBackground
            .overlay(
                Circle()
                    .fill(Self.dotInk)
                    .frame(width: side * 0.40, height: side * 0.40)
            )
    }

    // Revealed state: the character on the same card.
    private var charFace: some View {
        cardBackground
            .overlay(
                Text(char)
                    .font(.system(size: side * 0.62, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Self.charInk)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: side * 0.24, style: .continuous)
            .fill(Self.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: side * 0.24, style: .continuous)
                    .strokeBorder(Self.cardStroke, lineWidth: 1)
            )
    }

    private static let cardFill = Color(red: 0.13, green: 0.14, blue: 0.21)
    private static let cardStroke = Color(red: 0.30, green: 0.34, blue: 0.46).opacity(0.55)
    private static let dotInk = Color(red: 0.66, green: 0.72, blue: 0.86)
    private static let charInk = Color(red: 0.93, green: 0.96, blue: 1.0)
}
