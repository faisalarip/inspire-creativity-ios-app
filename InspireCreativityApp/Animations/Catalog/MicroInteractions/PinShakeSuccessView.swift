// catalog-id: mi-pin-shake-success
import SwiftUI

// PIN Shake-to-Success
// PIN dots fill as you type; on success they merge into a single dot that
// expands into a checkmark, on failure they scatter and shake.
//
// demo == true  -> self-driving TimelineView loop that auto-fills the dots
//                  then alternates success (merge -> check) and failure
//                  (scatter + shake) on a ~3.5s loop. No haptics.
// demo == false -> a real keypad. Taps fill the dots; a correct PIN merges
//                  into the check, a wrong PIN shakes and resets. Haptics on.

struct PinShakeSuccessView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            Group {
                if demo {
                    PinShakeSuccessView_PinDemoStage(side: side)
                } else {
                    PinShakeSuccessView_PinInteractiveStage(side: side, fullSize: geo.size)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Shared model

private enum PinShakeSuccessView_PinOutcome {
    case success
    case failure
}

/// A normalized description of the whole effect at a single instant.
/// Everything (dots, merge, check, shake) is derived from this so the demo
/// and interactive paths render through the exact same visual code.
private struct PinShakeSuccessView_PinVisualState {
    /// 0..1 fraction of dots that read as "filled".
    var fillFraction: CGFloat
    /// 0..1 progress of dots converging to center (success only).
    var mergeProgress: CGFloat
    /// 0..1 progress of the central dot growing + check trimming on.
    var checkProgress: CGFloat
    /// 0..1 progress of the scatter (failure only).
    var scatterProgress: CGFloat
    /// Live horizontal shake offset in points (failure only).
    var shakeOffset: CGFloat
    /// Outcome currently being expressed.
    var outcome: PinShakeSuccessView_PinOutcome

    static let idle = PinShakeSuccessView_PinVisualState(
        fillFraction: 0, mergeProgress: 0, checkProgress: 0,
        scatterProgress: 0, shakeOffset: 0, outcome: .success
    )
}

private enum PinShakeSuccessView_PinPalette {
    static let bg = Color(red: 0.078, green: 0.063, blue: 0.098)
    static let ring = Color(red: 0.42, green: 0.40, blue: 0.52)
    static let fill = Color(red: 0.66, green: 0.62, blue: 0.95)
    static let success = Color(red: 0.36, green: 0.84, blue: 0.62)
    static let failure = Color(red: 0.95, green: 0.42, blue: 0.46)
    static let ink = Color(red: 0.95, green: 0.95, blue: 0.98)
}

private let pinCount: Int = 4

// MARK: - Checkmark shape

private struct PinShakeSuccessView_CheckShape: Shape {
    var trimEnd: CGFloat

    var animatableData: CGFloat {
        get { trimEnd }
        set { trimEnd = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        // A clean check tucked inside the rect.
        let p0 = CGPoint(x: rect.minX + w * 0.20, y: rect.minY + h * 0.54)
        let p1 = CGPoint(x: rect.minX + w * 0.42, y: rect.minY + h * 0.74)
        let p2 = CGPoint(x: rect.minX + w * 0.80, y: rect.minY + h * 0.28)
        p.move(to: p0)
        p.addLine(to: p1)
        p.addLine(to: p2)
        return p.trimmedPath(from: 0, to: max(0, min(1, trimEnd)))
    }
}

// MARK: - Core visual (shared by both paths)

private struct PinShakeSuccessView_PinEffectView: View {
    let state: PinShakeSuccessView_PinVisualState
    let side: CGFloat

    private var dotRadius: CGFloat { side * 0.052 }
    private var spacing: CGFloat { side * 0.072 }

    private var rowWidth: CGFloat {
        let n = CGFloat(pinCount)
        return n * (dotRadius * 2) + (n - 1) * spacing
    }

    var body: some View {
        ZStack {
            dotsLayer
            mergedCore
        }
        .frame(width: rowWidth, height: dotRadius * 2)
        .offset(x: state.shakeOffset)
    }

    // Persistent ring outlines + fills. The rings NEVER disappear, so no
    // frame is ever blank.
    private var dotsLayer: some View {
        HStack(spacing: spacing) {
            ForEach(0..<pinCount, id: \.self) { index in
                singleDot(index: index)
            }
        }
        // Dots fade as they merge into the central core.
        .opacity(Double(1 - state.mergeProgress * 0.92))
    }

    private func singleDot(index: Int) -> some View {
        let filled = isFilled(index)
        let toCenter = centerOffset(forIndex: index)
        let scatter = scatterVector(forIndex: index)
        return ZStack {
            Circle()
                .stroke(PinShakeSuccessView_PinPalette.ring, lineWidth: max(1.4, side * 0.012))
            Circle()
                .fill(fillColor)
                .scaleEffect(filled ? 1 : 0.0001)
                .opacity(filled ? 1 : 0)
        }
        .frame(width: dotRadius * 2, height: dotRadius * 2)
        // Success: slide toward the row center. Failure: fling outward.
        .offset(
            x: toCenter.x * state.mergeProgress + scatter.x * state.scatterProgress,
            y: toCenter.y * state.mergeProgress + scatter.y * state.scatterProgress
        )
        .scaleEffect(1 - state.scatterProgress * 0.35)
        .animation(.spring(response: 0.32, dampingFraction: 0.7), value: filled)
    }

    // The single dot that the four converge into, which then grows and hosts
    // the checkmark.
    private var mergedCore: some View {
        let grow = 1 + state.checkProgress * 2.6
        let coreVisible = state.mergeProgress > 0.02
        return ZStack {
            Circle()
                .fill(PinShakeSuccessView_PinPalette.success)
                .frame(width: dotRadius * 2, height: dotRadius * 2)
                .scaleEffect(grow)
                .opacity(coreVisible ? Double(min(1, state.mergeProgress * 1.4)) : 0)
            PinShakeSuccessView_CheckShape(trimEnd: state.checkProgress)
                .stroke(
                    PinShakeSuccessView_PinPalette.ink,
                    style: StrokeStyle(lineWidth: max(2, side * 0.022),
                                       lineCap: .round, lineJoin: .round)
                )
                .frame(width: dotRadius * 3.0, height: dotRadius * 3.0)
                .opacity(state.checkProgress > 0.01 ? 1 : 0)
        }
    }

    private var fillColor: Color {
        switch state.outcome {
        case .success: return PinShakeSuccessView_PinPalette.fill
        case .failure:
            // Tint warm red as the failure resolves.
            return state.scatterProgress > 0.01 ? PinShakeSuccessView_PinPalette.failure : PinShakeSuccessView_PinPalette.fill
        }
    }

    private func isFilled(_ index: Int) -> Bool {
        let threshold = state.fillFraction * CGFloat(pinCount)
        return CGFloat(index) + 0.999 <= threshold
    }

    // Vector from a dot's slot to the row center.
    private func centerOffset(forIndex index: Int) -> CGPoint {
        let step = dotRadius * 2 + spacing
        let centerIndex = CGFloat(pinCount - 1) / 2
        let dx = (centerIndex - CGFloat(index)) * step
        return CGPoint(x: dx, y: 0)
    }

    // Deterministic scatter direction so the shudder reads as an explosion.
    private func scatterVector(forIndex index: Int) -> CGPoint {
        let dirs: [CGPoint] = [
            CGPoint(x: -1.0, y: -0.7),
            CGPoint(x: -0.5, y: 0.9),
            CGPoint(x: 0.6, y: -0.85),
            CGPoint(x: 1.1, y: 0.6)
        ]
        let d = dirs[index % dirs.count]
        let mag = side * 0.10
        return CGPoint(x: d.x * mag, y: d.y * mag)
    }
}

// MARK: - Demo path (self-driving tile)

private struct PinShakeSuccessView_PinDemoStage: View {
    let side: CGFloat

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            PinShakeSuccessView_PinEffectView(state: state(at: t), side: side)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private let cycle: Double = 3.6

    private func state(at time: TimeInterval) -> PinShakeSuccessView_PinVisualState {
        let cycleIndex = Int(floor(time / cycle))
        let local = (time.truncatingRemainder(dividingBy: cycle)) / cycle // 0..1
        let outcome: PinShakeSuccessView_PinOutcome = (cycleIndex % 2 == 0) ? .success : .failure

        // Phase split inside one cycle:
        //   0.00 - 0.42  fill dots
        //   0.42 - 0.78  express outcome
        //   0.78 - 1.00  hold + reset
        var s = PinShakeSuccessView_PinVisualState.idle
        s.outcome = outcome

        if local < 0.42 {
            let f = local / 0.42
            s.fillFraction = eased(f)
        } else if local < 0.78 {
            s.fillFraction = 1
            let f = (local - 0.42) / 0.36 // 0..1 across the outcome phase
            apply(outcome: outcome, f: f, into: &s)
        } else {
            // Brief hold of the resolved state, then fade back to filled idle.
            s.fillFraction = 1
            apply(outcome: outcome, f: 1, into: &s)
            let r = (local - 0.78) / 0.22
            // Ease the resolved state back out so the next cycle starts clean.
            let fade = eased(min(1, r))
            s.mergeProgress *= Double(1 - fade)
            s.checkProgress *= Double(1 - fade)
            s.scatterProgress *= Double(1 - fade)
            s.shakeOffset *= CGFloat(1 - fade)
            s.fillFraction = 1 - eased(min(1, max(0, (r - 0.5) * 2)))
        }
        return s
    }

    private func apply(outcome: PinShakeSuccessView_PinOutcome, f: Double, into s: inout PinShakeSuccessView_PinVisualState) {
        switch outcome {
        case .success:
            // First merge to center, then grow + draw the check.
            s.mergeProgress = eased(min(1, f * 1.8))
            let cf = max(0, (f - 0.45) / 0.55)
            s.checkProgress = eased(min(1, cf))
        case .failure:
            // Scatter outward, with a damped-sine shudder riding on top.
            s.scatterProgress = eased(min(1, f * 1.6))
            let k: Double = 6.5   // decay
            let freq: Double = 26 // shake speed
            let amp = side * 0.05
            s.shakeOffset = CGFloat(sin(f * freq) * exp(-f * k)) * amp
        }
    }

    private func eased(_ x: Double) -> Double {
        // smoothstep
        let c = min(1, max(0, x))
        return c * c * (3 - 2 * c)
    }
}

// MARK: - Interactive path (keypad)

private enum PinShakeSuccessView_PinStatus {
    case typing
    case success
    case failure
}

private struct PinShakeSuccessView_PinInteractiveStage: View {
    let side: CGFloat
    let fullSize: CGSize

    private let secret = "1234"

    @State private var entered: String = ""
    @State private var status: PinShakeSuccessView_PinStatus = .typing
    @State private var mergeProgress: CGFloat = 0
    @State private var checkProgress: CGFloat = 0
    @State private var scatterProgress: CGFloat = 0
    @State private var shakeOffset: CGFloat = 0
    @State private var successTick: Int = 0
    @State private var failureTick: Int = 0

    var body: some View {
        VStack(spacing: fullSize.height * 0.06) {
            PinShakeSuccessView_PinEffectView(state: currentState, side: side)
                .frame(maxWidth: .infinity)
                .frame(height: side * 0.16)

            if showKeypad {
                keypad
                    .frame(maxWidth: fullSize.width * 0.92)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .sensoryFeedback(.success, trigger: successTick)
        .sensoryFeedback(.error, trigger: failureTick)
    }

    // Hide the keypad in very small renders (e.g. grid tile) so the dots
    // stay legible; show it once there is room.
    private var showKeypad: Bool {
        fullSize.height > 220 && fullSize.width > 180
    }

    private var currentState: PinShakeSuccessView_PinVisualState {
        var s = PinShakeSuccessView_PinVisualState.idle
        s.fillFraction = CGFloat(entered.count) / CGFloat(pinCount)
        s.mergeProgress = mergeProgress
        s.checkProgress = checkProgress
        s.scatterProgress = scatterProgress
        s.shakeOffset = shakeOffset
        s.outcome = (status == .failure) ? .failure : .success
        return s
    }

    // MARK: keypad

    private var keypad: some View {
        let rows: [[String]] = [
            ["1", "2", "3"],
            ["4", "5", "6"],
            ["7", "8", "9"],
            ["", "0", "<"]
        ]
        return VStack(spacing: fullSize.height * 0.018) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: fullSize.width * 0.05) {
                    ForEach(rows[r].indices, id: \.self) { c in
                        keyButton(rows[r][c])
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keyButton(_ label: String) -> some View {
        if label.isEmpty {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: side * 0.16)
        } else {
            Button {
                handleKey(label)
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .overlay(Circle().stroke(PinShakeSuccessView_PinPalette.ring.opacity(0.5),
                                                 lineWidth: 1))
                    if label == "<" {
                        Image(systemName: "delete.left")
                            .font(.system(size: side * 0.05, weight: .medium))
                            .foregroundStyle(PinShakeSuccessView_PinPalette.ink)
                    } else {
                        Text(label)
                            .font(.system(size: side * 0.06, weight: .semibold,
                                          design: .rounded))
                            .foregroundStyle(PinShakeSuccessView_PinPalette.ink)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: side * 0.16)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: input handling

    private func handleKey(_ label: String) {
        guard status == .typing else {
            // Tapping after a resolved attempt restarts entry.
            resetEntry()
            if label != "<" { append(label) }
            return
        }
        if label == "<" {
            if !entered.isEmpty { entered.removeLast() }
            return
        }
        append(label)
    }

    private func append(_ digit: String) {
        guard entered.count < pinCount else { return }
        entered.append(digit)
        if entered.count == pinCount {
            evaluate()
        }
    }

    private func evaluate() {
        if entered == secret {
            status = .success
            successTick &+= 1
            withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
                mergeProgress = 1
            }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)
                .delay(0.18)) {
                checkProgress = 1
            }
        } else {
            status = .failure
            failureTick &+= 1
            withAnimation(.spring(response: 0.30, dampingFraction: 0.6)) {
                scatterProgress = 1
            }
            playShake()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                resetEntry()
            }
        }
    }

    private func playShake() {
        let amp = side * 0.05
        let steps: [CGFloat] = [-1, 0.85, -0.6, 0.4, -0.22, 0.1, 0]
        var delay: Double = 0
        for v in steps {
            withAnimation(.easeInOut(duration: 0.06).delay(delay)) {
                shakeOffset = v * amp
            }
            delay += 0.06
        }
    }

    private func resetEntry() {
        withAnimation(.easeOut(duration: 0.25)) {
            entered = ""
            status = .typing
            mergeProgress = 0
            checkProgress = 0
            scatterProgress = 0
            shakeOffset = 0
        }
    }
}
