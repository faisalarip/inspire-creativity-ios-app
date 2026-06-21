// catalog-id: tx-stamp-ink
import SwiftUI

// MARK: - Rubber Stamp Slam
// The word slams down as an over-rotated ink stamp that overshoots in scale,
// kicks up a faint dust ring, and leaves a textured uneven-ink imprint with
// slightly heavier edges and a tiny settle wobble.
//
// demo == true  -> self-driving PhaseAnimator loop (~3s, rest-dominant)
// demo == false -> tap to replay the KeyframeAnimator slam

struct StampInkView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let side = min(size.width, size.height)

            ZStack {
                StampInkView_StampBackdrop(side: side)

                if demo {
                    StampInkView_DemoStamp(side: side)
                } else {
                    StampInkView_InteractiveStamp(side: side)
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Animatable pose shared by both drivers

private struct StampInkView_StampPose {
    var scale: CGFloat = 1.0
    var rotation: Double = -8.0   // resting over-rotated tilt (degrees)
    var inkOpacity: Double = 1.0  // legibility of the stamped word
    var dust: CGFloat = 0.0       // 0 = no ring, 1 = fully expanded/faded
    var press: CGFloat = 0.0      // 0 = lifted, 1 = pressed flat into page

    static let rest = StampInkView_StampPose(scale: 1.0, rotation: -8.0, inkOpacity: 1.0, dust: 0.0, press: 0.0)
}

// MARK: - Backdrop (paper card)

private struct StampInkView_StampBackdrop: View {
    let side: CGFloat

    var body: some View {
        let inset = side * 0.06
        RoundedRectangle(cornerRadius: side * 0.10, style: .continuous)
            .fill(paperGradient)
            .overlay(
                RoundedRectangle(cornerRadius: side * 0.10, style: .continuous)
                    .strokeBorder(Color(red: 0.86, green: 0.83, blue: 0.77), lineWidth: 1)
            )
            .padding(inset)
            .shadow(color: Color.black.opacity(0.18), radius: side * 0.04, x: 0, y: side * 0.02)
    }

    private var paperGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.98, green: 0.97, blue: 0.93),
                Color(red: 0.94, green: 0.92, blue: 0.86)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - The stamped face (renders from a StampInkView_StampPose)

private struct StampInkView_StampFace: View {
    let pose: StampInkView_StampPose
    let side: CGFloat

    private let word = "APPROVED"
    private let inkColor = Color(red: 0.74, green: 0.13, blue: 0.16)

    var body: some View {
        ZStack {
            dustRing
            stampedWord
        }
        .frame(width: side, height: side)
    }

    // The ink imprint: a textured/uneven word in stamp red.
    private var stampedWord: some View {
        let pressLift = 1.0 - Double(pose.press) * 0.12

        return wordText
            .overlay(StampInkView_GrainOverlay(side: side, ink: inkColor).mask(wordText))
            .overlay(StampInkView_EdgeBleed(side: side, ink: inkColor).mask(wordText))
            .opacity(pose.inkOpacity * pressLift)
            .scaleEffect(pose.scale)
            .rotationEffect(.degrees(pose.rotation))
            // soft impact shadow that tightens as it presses flat
            .shadow(
                color: inkColor.opacity(0.28 * (1.0 - Double(pose.press) * 0.5)),
                radius: side * 0.012 * (1.0 + (1.0 - pose.press) * 2.0),
                x: 0,
                y: 0
            )
    }

    private var wordText: some View {
        Text(word)
            .font(.system(size: side * 0.16, weight: .heavy, design: .rounded))
            .tracking(side * 0.012)
            .foregroundStyle(inkColor)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .padding(.horizontal, side * 0.10)
            .overlay(
                RoundedRectangle(cornerRadius: side * 0.04, style: .continuous)
                    .strokeBorder(inkColor, lineWidth: side * 0.012)
                    .padding(.horizontal, side * 0.045)
                    .padding(.vertical, side * 0.02)
            )
    }

    // Expanding + fading dust ring kicked up by the slam.
    private var dustRing: some View {
        let ringScale = 0.25 + pose.dust * 1.05
        let ringOpacity = Double(max(0.0, 1.0 - pose.dust)) * 0.5

        return Circle()
            .strokeBorder(
                Color(red: 0.55, green: 0.50, blue: 0.42),
                lineWidth: side * 0.02 * (1.0 - pose.dust * 0.7)
            )
            .frame(width: side * 0.46, height: side * 0.46)
            .scaleEffect(ringScale)
            .rotationEffect(.degrees(pose.rotation))
            .opacity(ringOpacity)
            .blur(radius: side * 0.006)
    }
}

// MARK: - Static seeded grain (uneven-ink texture, generated once)

private struct StampInkView_GrainOverlay: View {
    let side: CGFloat
    let ink: Color

    var body: some View {
        Canvas { context, canvasSize in
            var rng = StampInkView_SeededRandom(seed: 0xA17C_E901)
            let count = 90
            for _ in 0..<count {
                let x = rng.nextUnit() * canvasSize.width
                let y = rng.nextUnit() * canvasSize.height
                let r = (0.6 + rng.nextUnit() * 1.8)
                let hole = rng.nextUnit() < 0.55
                let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                // "hole" speckles knock ink OUT (patchy coverage); others add density
                let alpha = hole ? 0.85 : 0.4
                let color = hole ? Color(red: 0.98, green: 0.97, blue: 0.93) : ink
                context.fill(Path(ellipseIn: rect), with: .color(color.opacity(alpha)))
            }
        }
    }
}

// Slightly heavier ink along edges — a subtle darker vignette inside the glyphs.
private struct StampInkView_EdgeBleed: View {
    let side: CGFloat
    let ink: Color

    var body: some View {
        RadialGradient(
            colors: [
                Color.clear,
                ink.opacity(0.0),
                Color(red: 0.50, green: 0.08, blue: 0.10).opacity(0.45)
            ],
            center: .center,
            startRadius: side * 0.05,
            endRadius: side * 0.42
        )
    }
}

// Tiny deterministic LCG so the grain is stable across redraws.
private struct StampInkView_SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9 : seed }

    mutating func nextUnit() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let top = (state >> 33) & 0x7FFF_FFFF
        return CGFloat(top) / CGFloat(0x7FFF_FFFF)
    }
}

// MARK: - Demo driver (self-driving PhaseAnimator, ~3s, rest-dominant)

private struct StampInkView_DemoStamp: View {
    let side: CGFloat

    var body: some View {
        // Phases: a quick wind-up + slam, then a long legible rest.
        PhaseAnimator(StampInkView_StampPhase.allCases) { phase in
            StampInkView_StampFace(pose: phase.pose, side: side)
        } animation: { phase in
            phase.transition
        }
    }
}

private enum StampInkView_StampPhase: CaseIterable {
    case lifted     // raised, slightly transparent but legible
    case impact     // slammed past 1, hardest tilt, dust born
    case settle     // tiny overshoot wobble back
    case rest       // resting, full ink (dominant slice)

    var pose: StampInkView_StampPose {
        switch self {
        case .lifted:
            return StampInkView_StampPose(scale: 1.42, rotation: -16, inkOpacity: 0.82, dust: 0.0, press: 0.0)
        case .impact:
            return StampInkView_StampPose(scale: 0.94, rotation: -3, inkOpacity: 1.0, dust: 1.0, press: 1.0)
        case .settle:
            return StampInkView_StampPose(scale: 1.05, rotation: -10, inkOpacity: 1.0, dust: 1.0, press: 0.6)
        case .rest:
            return StampInkView_StampPose(scale: 1.0, rotation: -8, inkOpacity: 1.0, dust: 1.0, press: 0.0)
        }
    }

    var transition: Animation {
        switch self {
        case .lifted:
            // re-arm: ease back up, hold a beat
            return .easeInOut(duration: 0.55)
        case .impact:
            // the slam — fast and forceful
            return .spring(response: 0.18, dampingFraction: 0.45)
        case .settle:
            // bounce-back wobble
            return .spring(response: 0.30, dampingFraction: 0.55)
        case .rest:
            // long legible dwell so the tile never reads as dead/flickering
            return .easeOut(duration: 1.6)
        }
    }
}

// MARK: - Interactive driver (tap to slam)

private struct StampInkView_InteractiveStamp: View {
    let side: CGFloat
    @State private var tapCount: Int = 0

    var body: some View {
        KeyframeAnimator(initialValue: StampInkView_StampPose.rest, trigger: tapCount) { pose in
            StampInkView_StampFace(pose: pose, side: side)
                .overlay(alignment: .bottom) { hint }
        } keyframes: { _ in
            keyframeTrack
        }
        .contentShape(Rectangle())
        .onTapGesture { tapCount += 1 }
    }

    private var hint: some View {
        Text(tapCount == 0 ? "tap to stamp" : "")
            .font(.system(size: side * 0.055, weight: .semibold, design: .rounded))
            .foregroundStyle(Color(red: 0.45, green: 0.42, blue: 0.36).opacity(0.7))
            .padding(.bottom, side * 0.05)
            .allowsHitTesting(false)
    }

    @KeyframesBuilder<StampInkView_StampPose>
    private var keyframeTrack: some Keyframes<StampInkView_StampPose> {
        // Wind up high, slam past 1, wobble, settle to rest.
        KeyframeTrack(\.scale) {
            CubicKeyframe(1.55, duration: 0.0)
            SpringKeyframe(0.92, duration: 0.18, spring: .init(response: 0.18, dampingRatio: 0.42))
            SpringKeyframe(1.06, duration: 0.16, spring: .init(response: 0.22, dampingRatio: 0.5))
            SpringKeyframe(1.0, duration: 0.32, spring: .init(response: 0.30, dampingRatio: 0.6))
        }
        KeyframeTrack(\.rotation) {
            CubicKeyframe(-18, duration: 0.0)
            SpringKeyframe(-2, duration: 0.18, spring: .init(response: 0.18, dampingRatio: 0.42))
            SpringKeyframe(-11, duration: 0.16, spring: .init(response: 0.22, dampingRatio: 0.5))
            SpringKeyframe(-8, duration: 0.32, spring: .init(response: 0.30, dampingRatio: 0.6))
        }
        KeyframeTrack(\.inkOpacity) {
            CubicKeyframe(0.82, duration: 0.0)
            CubicKeyframe(1.0, duration: 0.18)
            CubicKeyframe(1.0, duration: 0.48)
        }
        KeyframeTrack(\.press) {
            CubicKeyframe(0.0, duration: 0.0)
            CubicKeyframe(1.0, duration: 0.18)
            CubicKeyframe(0.5, duration: 0.16)
            CubicKeyframe(0.0, duration: 0.32)
        }
        KeyframeTrack(\.dust) {
            CubicKeyframe(0.0, duration: 0.0)
            LinearKeyframe(0.05, duration: 0.16)
            CubicKeyframe(1.0, duration: 0.7)
        }
    }
}
