// catalog-id: btn-breath-idle
import SwiftUI

// MARK: - BreathIdleView_Breath Idle Button
//
// While idle the button gently inhales and exhales with a soft scale + glow
// rhythm. On tap it "holds its breath" (the breath freezes), then springs
// into a success state before resuming the calm idle breathing.
//
// demo == true  -> a self-driving TimelineView(.animation) loop that breathes
//                  continuously AND, once per ~3.6s beat, auto-plays the full
//                  tap choreography (hold -> exhale -> success -> resume) so the
//                  tile shows the whole behavior with no touch. Never blank.
// demo == false -> the real interactive control: it breathes idle and a tap
//                  interrupts the breath, springs to the success state, then
//                  resumes breathing.
//
// iOS 17 compatible. No app dependencies. Pure SwiftUI.

struct BreathIdleView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            Group {
                if demo {
                    BreathIdleView_DemoBreath(side: side)
                } else {
                    BreathIdleView_InteractiveBreath(side: side)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Shared palette (tint #16120e, a warm near-black)

private enum BreathIdleView_Palette {
    static let backdropTop = Color(red: 0.13, green: 0.10, blue: 0.07)
    static let backdropBottom = Color(red: 0.08, green: 0.06, blue: 0.04)

    static let pillTop = Color(red: 0.99, green: 0.78, blue: 0.42)
    static let pillBottom = Color(red: 0.93, green: 0.55, blue: 0.22)

    static let successTop = Color(red: 0.42, green: 0.86, blue: 0.58)
    static let successBottom = Color(red: 0.20, green: 0.68, blue: 0.45)

    static let glowIdle = Color(red: 1.0, green: 0.66, blue: 0.30)
    static let glowSuccess = Color(red: 0.40, green: 0.92, blue: 0.62)

    static let label = Color(red: 0.16, green: 0.10, blue: 0.04)
    static let labelSuccess = Color(red: 0.04, green: 0.20, blue: 0.10)
}

// MARK: - BreathIdleView_Breath math
//
// A single breath engine. `phase` (0...1) is the breath position;
// 0 = full exhale (smallest), 1 = full inhale (largest). We use an
// eased cosine so the turnaround at the top and bottom feels soft, like
// real breathing rather than a metronome.

private enum BreathIdleView_Breath {
    /// Smooth eased breath value in 0...1 from raw time, ~4.4s per full cycle.
    static func value(at t: Double) -> Double {
        let period: Double = 4.4
        let raw = (1.0 - cos(t / period * 2.0 * .pi)) / 2.0 // 0..1, sinusoidal
        // ease the extremes slightly so the hold at top/bottom feels organic
        return raw * raw * (3.0 - 2.0 * raw)
    }

    static func scale(for phase: Double) -> CGFloat {
        // 0.97 (exhale) -> 1.03 (inhale)
        CGFloat(0.97 + 0.06 * phase)
    }

    static func glow(for phase: Double, side: CGFloat) -> CGFloat {
        // glow radius scales with the breath and the tile size
        let base = side * 0.045
        let swing = side * 0.085
        return base + swing * CGFloat(phase)
    }

    static func glowOpacity(for phase: Double) -> Double {
        0.30 + 0.45 * phase
    }
}

// MARK: - Demo (self-driving)

private struct BreathIdleView_DemoBreath: View {
    let side: CGFloat

    // Full looping beat. The first stretch is calm breathing; the tail plays
    // the tap choreography so the demo showcases the success state too.
    private let loop: Double = 3.6

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let cycle = t.truncatingRemainder(dividingBy: loop)
            let stage = stage(for: cycle)

            BreathIdleView_BreathFace(
                side: side,
                phase: stage.breathPhase(at: t),
                isSuccess: stage.isSuccess,
                pressDepth: stage.pressDepth
            )
        }
    }

    /// Decide what part of the choreography we are in for this loop position.
    private func stage(for cycle: Double) -> BreathIdleView_DemoStage {
        // Timeline within one loop (seconds):
        // 0.00 - 2.10  idle breathing
        // 2.10 - 2.45  "hold" (breath freezes) + slight press-in
        // 2.45 - 3.20  exhale into success (held success state shown)
        // 3.20 - 3.60  release back toward idle
        if cycle < 2.10 {
            return .idle
        } else if cycle < 2.45 {
            let p = (cycle - 2.10) / 0.35
            return .hold(press: easeOut(p))
        } else if cycle < 3.20 {
            return .success
        } else {
            let p = (cycle - 3.20) / 0.40
            return .resume(release: 1.0 - easeOut(p))
        }
    }

    private func easeOut(_ x: Double) -> Double {
        1.0 - (1.0 - x) * (1.0 - x)
    }
}

private enum BreathIdleView_DemoStage {
    case idle
    case hold(press: Double)
    case success
    case resume(release: Double)

    var isSuccess: Bool {
        switch self {
        case .success, .resume: return true
        default: return false
        }
    }

    var pressDepth: Double {
        switch self {
        case .hold(let p): return p
        case .success: return 0.6
        case .resume(let r): return 0.6 * r
        default: return 0.0
        }
    }

    /// During idle/resume the face breathes; during hold/success the breath is
    /// frozen near a gentle exhale so it reads as "holding its breath".
    func breathPhase(at t: Double) -> Double {
        switch self {
        case .idle:
            return BreathIdleView_Breath.value(at: t)
        case .hold:
            return 0.35
        case .success:
            return 0.5
        case .resume(let release):
            // ease from the held value back into the live breath
            let live = BreathIdleView_Breath.value(at: t)
            return 0.5 * release + live * (1.0 - release)
        }
    }
}

// MARK: - Interactive

private struct BreathIdleView_InteractiveBreath: View {
    let side: CGFloat

    @State private var isSuccess = false
    @State private var pressing = false
    // When the user taps, we freeze the breath at the value it had at tap time.
    @State private var frozenPhase: Double? = nil
    @State private var feedbackTick = 0

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let livePhase = BreathIdleView_Breath.value(at: t)
            let phase = frozenPhase ?? livePhase

            BreathIdleView_BreathFace(
                side: side,
                phase: phase,
                isSuccess: isSuccess,
                pressDepth: pressing ? 1.0 : 0.0
            )
        }
        .contentShape(Rectangle())
        .onTapGesture { handleTap() }
        .sensoryFeedback(.success, trigger: feedbackTick)
    }

    private func handleTap() {
        // 1. Hold the breath: freeze at a calm value + press in.
        frozenPhase = 0.4
        withAnimation(.easeOut(duration: 0.16)) {
            pressing = true
        }

        // 2. Spring exhale into the success state.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) {
                isSuccess = true
                pressing = false
            }
            feedbackTick &+= 1
        }

        // 3. Resume calm breathing after a beat.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeInOut(duration: 0.5)) {
                isSuccess = false
            }
            frozenPhase = nil
        }
    }
}

// MARK: - The button face (shared by both modes)

private struct BreathIdleView_BreathFace: View {
    let side: CGFloat
    let phase: Double        // 0 exhale ... 1 inhale
    let isSuccess: Bool
    let pressDepth: Double   // 0 rest ... 1 fully pressed in

    private var pillWidth: CGFloat { side * 0.78 }
    private var pillHeight: CGFloat { side * 0.34 }
    private var corner: CGFloat { pillHeight * 0.5 }

    private var scale: CGFloat {
        let breath = BreathIdleView_Breath.scale(for: phase)
        let press = 1.0 - CGFloat(pressDepth) * 0.06
        return breath * press
    }

    var body: some View {
        ZStack {
            backdrop
            pill
                .frame(width: pillWidth, height: pillHeight)
                .scaleEffect(scale)
                .shadow(color: glowColor.opacity(glowOpacity),
                        radius: BreathIdleView_Breath.glow(for: phase, side: side),
                        x: 0, y: 0)
        }
    }

    // MARK: subviews

    private var backdrop: some View {
        LinearGradient(
            colors: [BreathIdleView_Palette.backdropTop, BreathIdleView_Palette.backdropBottom],
            startPoint: .top, endPoint: .bottom
        )
    }

    private var pill: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(fillGradient)
                .overlay(rim)
                .overlay(sheen)

            content
        }
    }

    private var rim: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .stroke(Color.white.opacity(0.18), lineWidth: max(0.6, side * 0.006))
    }

    // A soft top sheen that brightens slightly on the inhale, selling "alive".
    private var sheen: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.28 + 0.14 * phase),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .top, endPoint: .center
                )
            )
            .padding(max(1, side * 0.012))
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var content: some View {
        if isSuccess {
            BreathIdleView_SuccessContent(side: side)
                .transition(.scale(scale: 0.7).combined(with: .opacity))
        } else {
            BreathIdleView_IdleContent(side: side, phase: phase)
                .transition(.opacity)
        }
    }

    // MARK: derived styling

    private var fillGradient: LinearGradient {
        let top = isSuccess ? BreathIdleView_Palette.successTop : BreathIdleView_Palette.pillTop
        let bottom = isSuccess ? BreathIdleView_Palette.successBottom : BreathIdleView_Palette.pillBottom
        return LinearGradient(colors: [top, bottom],
                              startPoint: .top, endPoint: .bottom)
    }

    private var glowColor: Color {
        isSuccess ? BreathIdleView_Palette.glowSuccess : BreathIdleView_Palette.glowIdle
    }

    private var glowOpacity: Double {
        // keep an opacity floor so nothing reads as blank on any frame
        let base = BreathIdleView_Breath.glowOpacity(for: phase)
        return isSuccess ? max(0.45, base) : max(0.30, base)
    }
}

// MARK: - Idle content (a calm breathing dot + label)

private struct BreathIdleView_IdleContent: View {
    let side: CGFloat
    let phase: Double

    var body: some View {
        HStack(spacing: side * 0.04) {
            Circle()
                .fill(BreathIdleView_Palette.label.opacity(0.85))
                .frame(width: side * 0.06, height: side * 0.06)
                .scaleEffect(CGFloat(0.85 + 0.35 * phase))
            Text("Breathe")
                .font(.system(size: side * 0.085, weight: .semibold, design: .rounded))
                .foregroundColor(BreathIdleView_Palette.label)
                .opacity(0.9)
        }
    }
}

// MARK: - Success content (checkmark + label)

private struct BreathIdleView_SuccessContent: View {
    let side: CGFloat

    var body: some View {
        HStack(spacing: side * 0.045) {
            Image(systemName: "checkmark")
                .font(.system(size: side * 0.085, weight: .bold))
                .foregroundColor(BreathIdleView_Palette.labelSuccess)
            Text("Awake")
                .font(.system(size: side * 0.085, weight: .bold, design: .rounded))
                .foregroundColor(BreathIdleView_Palette.labelSuccess)
        }
    }
}
