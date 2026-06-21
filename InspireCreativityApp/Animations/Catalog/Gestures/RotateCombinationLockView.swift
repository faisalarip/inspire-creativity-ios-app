// catalog-id: ges-rotate-combination-lock
import SwiftUI

// MARK: - Public View

/// Combination Safe Dial — rotate a numbered dial; correct numbers in sequence
/// light up, then the bolt retracts and the door eases open.
///
/// - `demo == true`: a self-driving PhaseAnimator scripts the full solve loop
///   (dial turns to each number, pips light, bolt retracts, door swings open,
///   then re-closes) so the tile stays alive with no touch.
/// - `demo == false`: a real one-finger circular drag (atan2) turns the dial,
///   snapping to integers; reversing direction commits a number; matching the
///   secret combo unlocks the safe.
struct RotateCombinationLockView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                backdrop(side: side)
                if demo {
                    DemoSafe(side: side)
                } else {
                    InteractiveSafe(side: side)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func backdrop(side: CGFloat) -> some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.06, blue: 0.10),
                Color(red: 0.02, green: 0.02, blue: 0.05)
            ],
            startPoint: .top, endPoint: .bottom
        )
    }
}

// MARK: - Shared lock state model

/// Snapshot of everything the renderer needs to draw a frame.
private struct LockState {
    var dialAngle: Double = 0      // radians, dial rotation
    var litCount: Int = 0          // how many combo stages are satisfied (0...3)
    var boltRetract: CGFloat = 0   // 0 = locked/extended, 1 = fully retracted
    var doorOpen: CGFloat = 0      // 0 = shut, 1 = fully swung open
    var solved: Bool = false       // glow accent when fully solved
}

private let comboCount = 3
private let dialNumbers = 40            // classic safe dial 0...39
private let unlockDoorAngle: Double = 78 // cap < 90 so we never see the back face

// MARK: - Demo (self-driving)

private struct DemoSafe: View {
    let side: CGFloat

    private enum Phase: CaseIterable {
        case closed, dialOne, dialTwo, dialThree, retract, open, hold, reclose
    }

    var body: some View {
        // No trigger → PhaseAnimator loops the phase sequence forever, so the
        // tile self-plays the full solve cycle with no touch.
        PhaseAnimator(Phase.allCases) { phase in
            SafeBody(state: state(for: phase), side: side, accent: accent(for: phase))
        } animation: { phase in
            animation(for: phase)
        }
    }

    private func state(for phase: Phase) -> LockState {
        var s = LockState()
        switch phase {
        case .closed:
            s.dialAngle = 0
        case .dialOne:
            s.dialAngle = turns(1.6)         // spin clockwise to first number
            s.litCount = 1
        case .dialTwo:
            s.dialAngle = turns(0.7)         // reverse to second
            s.litCount = 2
        case .dialThree:
            s.dialAngle = turns(1.25)        // reverse again to third
            s.litCount = 3
        case .retract:
            s.dialAngle = turns(1.25)
            s.litCount = 3
            s.solved = true
            s.boltRetract = 1
        case .open:
            s.dialAngle = turns(1.25)
            s.litCount = 3
            s.solved = true
            s.boltRetract = 1
            s.doorOpen = 1
        case .hold:
            s.dialAngle = turns(1.25)
            s.litCount = 3
            s.solved = true
            s.boltRetract = 1
            s.doorOpen = 1
        case .reclose:
            s.dialAngle = turns(1.25)
            s.litCount = 0
            s.boltRetract = 0
            s.doorOpen = 0
        }
        return s
    }

    private func accent(for phase: Phase) -> Bool {
        switch phase {
        case .retract, .open, .hold: return true
        default: return false
        }
    }

    private func animation(for phase: Phase) -> Animation? {
        switch phase {
        case .closed:    return .easeInOut(duration: 0.25)
        case .dialOne:   return .easeInOut(duration: 0.75)
        case .dialTwo:   return .easeInOut(duration: 0.65)
        case .dialThree: return .easeInOut(duration: 0.6)
        case .retract:   return .spring(response: 0.35, dampingFraction: 0.55)
        case .open:      return .spring(response: 0.7, dampingFraction: 0.78)
        case .hold:      return .easeInOut(duration: 0.6)
        case .reclose:   return .easeInOut(duration: 0.55)
        }
    }

    private func turns(_ t: Double) -> Double { t * 2 * .pi }
}

// MARK: - Interactive

private struct InteractiveSafe: View {
    let side: CGFloat

    // Secret combination (indices into 0...39).
    private let combo = [12, 30, 4]

    @State private var angle: Double = 0          // committed dial rotation (radians)
    @State private var lastFinger: Double = 0      // last finger angle (radians)
    @State private var dragActive: Bool = false    // true once a drag is in flight
    @State private var lastSign: Int = 0           // sign of last applied delta
    @State private var stage: Int = 0              // matched count
    @State private var solved: Bool = false
    @State private var boltRetract: CGFloat = 0
    @State private var doorOpen: CGFloat = 0
    @State private var snappedNumber: Int = 0      // number under the indicator

    var body: some View {
        let state = LockState(
            dialAngle: angle,
            litCount: stage,
            boltRetract: boltRetract,
            doorOpen: doorOpen,
            solved: solved
        )
        SafeBody(state: state, side: side, accent: solved)
            .contentShape(Rectangle())
            .gesture(dialDrag(side: side))
            .sensoryFeedback(.selection, trigger: snappedNumber)
            .sensoryFeedback(.impact(weight: .medium), trigger: stage)
            .sensoryFeedback(.success, trigger: solved) { _, now in now }
    }

    private func dialDrag(side: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let center = CGPoint(x: side / 2, y: side / 2)
                let f = atan2(value.location.y - center.y,
                              value.location.x - center.x)
                // First sample of a fresh drag has zero translation: seed the
                // reference finger angle and wait for the next sample.
                if isGestureStart(value) || !dragActive {
                    dragActive = true
                    lastFinger = f
                    return
                }
                var delta = f - lastFinger
                if delta > .pi { delta -= 2 * .pi }
                if delta < -.pi { delta += 2 * .pi }
                lastFinger = f
                applyDelta(delta)
            }
            .onEnded { _ in
                snapAndCommit()
                lastFinger = 0
                lastSign = 0
                dragActive = false
            }
    }

    private func isGestureStart(_ value: DragGesture.Value) -> Bool {
        value.translation == .zero
    }

    private func applyDelta(_ delta: Double) {
        guard !solved else { return }
        angle += delta

        // Track direction; a reversal commits the current number as a candidate.
        let sign = delta > 0 ? 1 : (delta < 0 ? -1 : 0)
        if sign != 0 {
            if lastSign != 0 && sign != lastSign {
                commitCandidate()
            }
            lastSign = sign
        }

        // Haptic + visual snap as we cross each integer number.
        let n = currentNumber()
        if n != snappedNumber {
            snappedNumber = n
        }
    }

    /// The dial number currently under the indicator (0...39).
    private func currentNumber() -> Int {
        let perNum = 2 * .pi / Double(dialNumbers)
        // Negative rotation moves higher numbers up (clockwise dial convention).
        let raw = (-angle / perNum)
        var n = Int(raw.rounded()) % dialNumbers
        if n < 0 { n += dialNumbers }
        return n
    }

    private func commitCandidate() {
        guard stage < comboCount else { return }
        let candidate = currentNumber()
        if candidate == combo[stage] {
            stage += 1
            if stage == comboCount {
                unlock()
            }
        } else if candidate == combo[0] {
            stage = 1
        } else {
            stage = 0
        }
    }

    private func snapAndCommit() {
        guard !solved else { return }
        // Snap committed angle to the nearest integer number with a small spring.
        let perNum = 2 * .pi / Double(dialNumbers)
        let snapped = (angle / perNum).rounded() * perNum
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            angle = snapped
        }
        // A pause-and-release also reads as a reversal for the final number.
        commitCandidate()
        lastSign = 0
    }

    private func unlock() {
        solved = true
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
            boltRetract = 1
        }
        withAnimation(.spring(response: 0.7, dampingFraction: 0.78).delay(0.2)) {
            doorOpen = 1
        }
        // Auto re-lock after a beat so the demo-able interactive state recovers.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            withAnimation(.easeInOut(duration: 0.55)) {
                doorOpen = 0
                boltRetract = 0
            }
            stage = 0
            solved = false
            lastSign = 0
        }
    }
}

// MARK: - Safe body (shared renderer)

private struct SafeBody: View {
    let state: LockState
    let side: CGFloat
    let accent: Bool

    var body: some View {
        let s = side
        ZStack {
            // Interior cavity revealed when the door swings — keeps an open
            // frame legible (never blank).
            InteriorCavity(side: s)

            // The swinging door carries the dial, hinged on the left edge.
            DoorFace(state: state, side: s, accent: accent)
                .rotation3DEffect(
                    .degrees(Double(state.doorOpen) * unlockDoorAngle),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .leading,
                    perspective: 0.55
                )
        }
        .frame(width: s, height: s)
    }
}

private struct InteriorCavity: View {
    let side: CGFloat

    var body: some View {
        let inset = side * 0.10
        RoundedRectangle(cornerRadius: side * 0.06, style: .continuous)
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 0.10, green: 0.10, blue: 0.13),
                        Color(red: 0.02, green: 0.02, blue: 0.03)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: side * 0.5
                )
            )
            .overlay(
                // Suggestion of a shelf so the open interior reads as a safe.
                RoundedRectangle(cornerRadius: side * 0.01)
                    .fill(Color(red: 0.16, green: 0.16, blue: 0.19))
                    .frame(width: side * 0.55, height: side * 0.03)
                    .offset(y: side * 0.05)
            )
            .padding(inset)
    }
}

// MARK: - Door face (bolt + dial)

private struct DoorFace: View {
    let state: LockState
    let side: CGFloat
    let accent: Bool

    var body: some View {
        let s = side
        ZStack {
            doorPlate(s: s)
            Bolt(retract: state.boltRetract, side: s)
            VStack(spacing: s * 0.04) {
                ProgressPips(litCount: state.litCount, side: s)
                Dial(angle: state.dialAngle, accent: accent, side: s)
            }
        }
        .frame(width: s, height: s)
        // Subtle parallax shadow as the door lifts off the body.
        .shadow(color: .black.opacity(0.35 * Double(state.doorOpen)),
                radius: s * 0.04 * state.doorOpen,
                x: s * 0.05 * state.doorOpen, y: 0)
    }

    private func doorPlate(s: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: s * 0.06, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.28, green: 0.30, blue: 0.36),
                        Color(red: 0.16, green: 0.17, blue: 0.22)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: s * 0.06, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.black.opacity(0.25)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: max(1, s * 0.008)
                    )
            )
            .padding(s * 0.10)
    }
}

// MARK: - Bolt

private struct Bolt: View {
    let retract: CGFloat
    let side: CGFloat

    var body: some View {
        let s = side
        let travel = s * 0.16
        // Bolt sits on the right edge of the door, slides left to retract.
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.78, green: 0.80, blue: 0.86),
                        Color(red: 0.50, green: 0.52, blue: 0.58)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .frame(width: s * 0.20, height: s * 0.055)
            .overlay(
                Capsule().stroke(Color.black.opacity(0.25), lineWidth: max(0.5, s * 0.004))
            )
            .offset(x: s * 0.33 - travel * retract, y: -s * 0.30)
    }
}

// MARK: - Progress pips

private struct ProgressPips: View {
    let litCount: Int
    let side: CGFloat

    var body: some View {
        let s = side
        HStack(spacing: s * 0.025) {
            ForEach(0..<comboCount, id: \.self) { i in
                Circle()
                    .fill(i < litCount ? litColor : Color(red: 0.20, green: 0.21, blue: 0.26))
                    .frame(width: s * 0.035, height: s * 0.035)
                    .overlay(
                        Circle()
                            .fill(Color.white)
                            .frame(width: s * 0.012, height: s * 0.012)
                            .opacity(i < litCount ? 0.9 : 0)
                    )
                    .shadow(color: i < litCount ? litColor.opacity(0.8) : .clear,
                            radius: s * 0.02)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: litCount)
            }
        }
        .padding(.top, s * 0.02)
    }

    private var litColor: Color {
        litCount >= comboCount
            ? Color(red: 0.45, green: 0.95, blue: 0.55)
            : Color(red: 1.0, green: 0.78, blue: 0.30)
    }
}

// MARK: - Dial

private struct Dial: View {
    let angle: Double
    let accent: Bool
    let side: CGFloat

    var body: some View {
        let s = side
        let d = s * 0.50
        ZStack {
            indicator(s: s, d: d)
            ringFace(d: d)
            ticksAndNumerals(d: d)
                .rotationEffect(.radians(angle))
            knob(d: d)
                .rotationEffect(.radians(angle))
        }
        .frame(width: d, height: d)
    }

    // Fixed pointer above the dial showing the reading position.
    private func indicator(s: CGFloat, d: CGFloat) -> some View {
        Triangle()
            .fill(accent
                  ? Color(red: 0.45, green: 0.95, blue: 0.55)
                  : Color(red: 0.95, green: 0.85, blue: 0.55))
            .frame(width: d * 0.10, height: d * 0.09)
            .offset(y: -d * 0.56)
            .shadow(color: .black.opacity(0.4), radius: d * 0.01, y: d * 0.01)
    }

    private func ringFace(d: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 0.20, green: 0.21, blue: 0.26),
                        Color(red: 0.10, green: 0.10, blue: 0.13)
                    ],
                    center: .center, startRadius: 0, endRadius: d * 0.55
                )
            )
            .overlay(
                Circle().strokeBorder(
                    accent
                        ? Color(red: 0.45, green: 0.95, blue: 0.55).opacity(0.85)
                        : Color.white.opacity(0.10),
                    lineWidth: max(1, d * 0.02)
                )
            )
            .shadow(color: accent
                    ? Color(red: 0.45, green: 0.95, blue: 0.55).opacity(0.6)
                    : .clear,
                    radius: d * 0.06)
    }

    private func ticksAndNumerals(d: CGFloat) -> some View {
        // Show every tick; numerals only on the majors (every 5) and only when
        // the dial is large enough to read them — keeps a 120pt tile uncluttered.
        let showNumerals = side > 220
        return ZStack {
            ForEach(0..<dialNumbers, id: \.self) { i in
                tick(i: i, d: d)
            }
            if showNumerals {
                ForEach(0..<8, id: \.self) { j in
                    numeral(major: j * 5, d: d)
                }
            }
        }
    }

    private func tick(i: Int, d: CGFloat) -> some View {
        let isMajor = i % 5 == 0
        let len = isMajor ? d * 0.10 : d * 0.05
        return Rectangle()
            .fill(Color.white.opacity(isMajor ? 0.75 : 0.35))
            .frame(width: max(0.6, d * (isMajor ? 0.014 : 0.008)), height: len)
            .offset(y: -d * 0.43)
            .rotationEffect(.degrees(Double(i) / Double(dialNumbers) * 360))
    }

    private func numeral(major: Int, d: CGFloat) -> some View {
        Text("\(major)")
            .font(.system(size: d * 0.085, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.85))
            .offset(y: -d * 0.30)
            .rotationEffect(.degrees(Double(major) / Double(dialNumbers) * 360))
    }

    // Center knurled grip that turns with the dial.
    private func knob(d: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.62, green: 0.64, blue: 0.70),
                            Color(red: 0.34, green: 0.36, blue: 0.42)
                        ],
                        center: .topLeading, startRadius: 0, endRadius: d * 0.30
                    )
                )
                .frame(width: d * 0.46, height: d * 0.46)
            // Knurl ridges.
            ForEach(0..<24, id: \.self) { k in
                Capsule()
                    .fill(Color.black.opacity(0.18))
                    .frame(width: max(0.5, d * 0.006), height: d * 0.07)
                    .offset(y: -d * 0.19)
                    .rotationEffect(.degrees(Double(k) / 24 * 360))
            }
            // Grip groove marking the dial's zero so rotation is visible.
            Capsule()
                .fill(Color(red: 0.95, green: 0.85, blue: 0.55))
                .frame(width: d * 0.03, height: d * 0.20)
                .offset(y: -d * 0.10)
        }
    }
}

// MARK: - Triangle helper

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}
