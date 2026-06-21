// catalog-id: mi-thumb-flip-like
import SwiftUI

// MARK: - Thumb-Flip Like
// A thumbs-up that does a quick 3D flip on tap (or auto in demo), rotating
// from outline to filled with a knuckle-crack overshoot and a faint upward float.
//
// Implementation notes:
// - The flip is two-staged (rest -> edge-on, swap symbol + jump, edge-on -> rest)
//   so the rendered thumb is NEVER horizontally mirrored at rest. A naive 0<->180
//   rotation3DEffect(axis:.y) mirrors a non-symmetric glyph and would leave the
//   liked state showing a backwards thumb.
// - The outline->filled symbol swap happens at the ~90 degree edge-on midpoint,
//   so the morph is hidden behind the card edge rather than shown on the front face.
// - A persistent card background sits behind the symbol, so even at the edge-on
//   frame the tile is never blank.
public struct ThumbFlipLikeView: View {
    var demo: Bool = false

    // Interactive state.
    @State private var liked: Bool = false
    @State private var flipAngle: Double = 0      // accumulated Y rotation in degrees
    @State private var floatOffset: CGFloat = 0    // brief upward float on flip
    @State private var pop: CGFloat = 1            // knuckle-crack scale overshoot
    @State private var showFilled: Bool = false    // which symbol is rendered
    @State private var burst: Double = 0           // 0...1 radial spark progress
    @State private var tapTrigger: Int = 0

    public var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                if demo {
                    demoContent(side: side)
                } else {
                    interactiveContent(side: side)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Demo (self-driving)

    private func demoContent(side: CGFloat) -> some View {
        // PhaseAnimator auto-cycles the full like/unlike flip on a ~3.2s loop.
        // The trigger-less initializer is the one that loops continuously; the
        // trigger variant only advances once per trigger change.
        PhaseAnimator(ThumbFlipLikeView_DemoPhase.allCases) { phase in
            thumbCard(side: side, state: demoState(for: phase))
        } animation: { phase in
            phase.animation
        }
    }

    // The visual state derived for each demo phase. Kept tiny for the type-checker.
    private func demoState(for phase: ThumbFlipLikeView_DemoPhase) -> ThumbFlipLikeView_ThumbVisualState {
        switch phase {
        case .restOutline:
            return ThumbFlipLikeView_ThumbVisualState(angle: 0, filled: false, float: 0, pop: 1, burst: 0)
        case .edgeToFilled:
            return ThumbFlipLikeView_ThumbVisualState(angle: 90, filled: false, float: -side90Float, pop: 1.04, burst: 0)
        case .landFilled:
            return ThumbFlipLikeView_ThumbVisualState(angle: 180, filled: true, float: 0, pop: 1, burst: 1)
        case .holdFilled:
            return ThumbFlipLikeView_ThumbVisualState(angle: 180, filled: true, float: 0, pop: 1, burst: 0)
        case .edgeToOutline:
            return ThumbFlipLikeView_ThumbVisualState(angle: 270, filled: true, float: -side90Float, pop: 1.02, burst: 0)
        case .landOutline:
            return ThumbFlipLikeView_ThumbVisualState(angle: 360, filled: false, float: 0, pop: 1, burst: 0)
        }
    }

    private var side90Float: CGFloat { 10 }

    // MARK: Interactive

    private func interactiveContent(side: CGFloat) -> some View {
        thumbCard(
            side: side,
            state: ThumbFlipLikeView_ThumbVisualState(
                angle: flipAngle,
                filled: showFilled,
                float: floatOffset,
                pop: pop,
                burst: burst
            )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            performFlip()
        }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.8), trigger: tapTrigger)
        .sensoryFeedback(.success, trigger: liked) { _, now in now }
    }

    // Two-stage flip with a knuckle-crack overshoot spring and an upward float.
    private func performFlip() {
        let goingToLiked = !liked
        tapTrigger &+= 1

        // Stage 1: rotate to the edge-on midpoint + lift slightly.
        withAnimation(.easeIn(duration: 0.14)) {
            flipAngle += 90
            floatOffset = -10
            pop = 1.05
        }

        // At the edge-on midpoint, swap the symbol while it is hidden.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            showFilled = goingToLiked

            // Stage 2: continue past edge-on and land with a knuckle-crack overshoot.
            withAnimation(.spring(response: 0.34, dampingFraction: 0.42)) {
                flipAngle += 90
                pop = 1
            }
            // Float settles back down a touch slower than the snap.
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                floatOffset = 0
            }

            liked = goingToLiked

            if goingToLiked {
                triggerBurst()
            }

            // Keep the accumulated angle bounded so it never drifts huge.
            if flipAngle >= 360 {
                // Normalize after the spring has visually settled.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    if !isFlipMidAir {
                        flipAngle = flipAngle.truncatingRemainder(dividingBy: 360)
                    }
                }
            }
        }
    }

    private var isFlipMidAir: Bool {
        let r = flipAngle.truncatingRemainder(dividingBy: 180)
        return abs(r) > 4 && abs(r) < 176
    }

    private func triggerBurst() {
        burst = 0
        withAnimation(.easeOut(duration: 0.5)) {
            burst = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
            burst = 0
        }
    }

    // MARK: Shared card

    private func thumbCard(side: CGFloat, state: ThumbFlipLikeView_ThumbVisualState) -> some View {
        let cardSize = side * 0.62
        let symbolSize = cardSize * 0.5
        // Counter-mirror when the back face is showing so the glyph is never
        // rendered backwards. The symbol is swapped at the edge-on midpoint, so
        // the user only ever sees an upright thumb on a face.
        let normalized = ((state.angle.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360)
        let showingBack = normalized > 90 && normalized < 270

        return ZStack {
            backdropGlow(size: side, active: state.filled)
            sparkRing(size: cardSize, progress: state.burst)

            cardFace(cardSize: cardSize, filled: state.filled)
                .overlay {
                    thumbSymbol(filled: state.filled, size: symbolSize)
                        .scaleEffect(x: showingBack ? -1 : 1, y: 1)
                }
                .scaleEffect(state.pop)
                .rotation3DEffect(
                    .degrees(state.angle),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.55
                )
                .offset(y: state.float)
        }
        .frame(width: side, height: side)
    }

    private func cardFace(cardSize: CGFloat, filled: Bool) -> some View {
        RoundedRectangle(cornerRadius: cardSize * 0.28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: filled ? likedFaceColors : idleFaceColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: cardSize * 0.28, style: .continuous)
                    .stroke(
                        Color(red: 1, green: 1, blue: 1).opacity(filled ? 0.28 : 0.16),
                        lineWidth: 1
                    )
            }
            .frame(width: cardSize, height: cardSize)
            .shadow(
                color: (filled ? accentColor : Color(red: 0, green: 0, blue: 0)).opacity(filled ? 0.45 : 0.3),
                radius: filled ? 16 : 8,
                x: 0,
                y: 6
            )
    }

    private func thumbSymbol(filled: Bool, size: CGFloat) -> some View {
        Image(systemName: filled ? "hand.thumbsup.fill" : "hand.thumbsup")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(
                filled
                ? AnyShapeStyle(LinearGradient(
                    colors: [Color(red: 1, green: 1, blue: 1), Color(red: 0.92, green: 0.96, blue: 1)],
                    startPoint: .top, endPoint: .bottom))
                : AnyShapeStyle(accentColor)
            )
            .contentTransition(.symbolEffect(.replace))
            .shadow(color: accentColor.opacity(filled ? 0.6 : 0), radius: 6)
    }

    private func backdropGlow(size: CGFloat, active: Bool) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [accentColor.opacity(active ? 0.4 : 0.12), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.55
                )
            )
            .frame(width: size, height: size)
            .blur(radius: 6)
            .opacity(active ? 1 : 0.65)
    }

    // One crisp radial spark ring on the like landing.
    private func sparkRing(size: CGFloat, progress: Double) -> some View {
        let p = CGFloat(progress)
        return ForEach(0..<8, id: \.self) { i in
            let angle = Double(i) / 8.0 * 2 * .pi
            let dist = size * 0.5 * (0.4 + p * 0.6)
            Capsule()
                .fill(accentColor.opacity(Double(1 - p)))
                .frame(width: 3, height: 9 + (1 - p) * 6)
                .offset(y: -dist)
                .rotationEffect(.radians(angle))
                .scaleEffect(0.6 + (1 - p) * 0.6)
        }
        .opacity(progress > 0.001 && progress < 0.999 ? 1 : 0)
    }

    // MARK: Palette

    private var accentColor: Color { Color(red: 0.30, green: 0.62, blue: 1.0) }

    private var idleFaceColors: [Color] {
        [Color(red: 0.16, green: 0.17, blue: 0.22),
         Color(red: 0.10, green: 0.11, blue: 0.15)]
    }

    private var likedFaceColors: [Color] {
        [Color(red: 0.24, green: 0.52, blue: 0.98),
         Color(red: 0.16, green: 0.36, blue: 0.86)]
    }
}

// MARK: - Supporting types

private struct ThumbFlipLikeView_ThumbVisualState {
    var angle: Double
    var filled: Bool
    var float: CGFloat
    var pop: CGFloat
    var burst: Double
}

private enum ThumbFlipLikeView_DemoPhase: CaseIterable {
    case restOutline
    case edgeToFilled
    case landFilled
    case holdFilled
    case edgeToOutline
    case landOutline

    var animation: Animation {
        switch self {
        case .restOutline:
            return .linear(duration: 0.01)
        case .edgeToFilled:
            return .easeIn(duration: 0.16)
        case .landFilled:
            return .spring(response: 0.34, dampingFraction: 0.42)
        case .holdFilled:
            return .easeInOut(duration: 1.0)
        case .edgeToOutline:
            return .easeIn(duration: 0.16)
        case .landOutline:
            return .spring(response: 0.4, dampingFraction: 0.55)
        }
    }
}
