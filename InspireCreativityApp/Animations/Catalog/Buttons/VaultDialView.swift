// catalog-id: btn-vault-dial
import SwiftUI

// MARK: - Vault Dial
// Rotate the dial like a safe combination. Correct stops illuminate one by one;
// the final turn swings the whole face open like a vault door, revealing the
// unlocked content behind it.
//
// Shared render state (dialAngle / litStops / doorProgress) is written by either
// of two drivers:
//   • demo == true  -> a self-looping PhaseAnimator scripts the sequence.
//   • demo == false -> a DragGesture + atan2 delta-accumulation matcher.
public struct VaultDialView: View {
    var demo: Bool = false

    public init(demo: Bool = false) {
        self.demo = demo
    }

    public var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                VaultDialView_VaultBackdrop(side: side)

                if demo {
                    VaultDialView_DemoDriver(side: side)
                } else {
                    VaultDialView_InteractiveDriver(side: side)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Palette

private enum VaultDialView_VaultPalette {
    static let plate0 = Color(red: 0.10, green: 0.11, blue: 0.14)
    static let plate1 = Color(red: 0.16, green: 0.17, blue: 0.21)
    static let steelHi = Color(red: 0.62, green: 0.65, blue: 0.72)
    static let steelLo = Color(red: 0.20, green: 0.22, blue: 0.27)
    static let brass    = Color(red: 0.78, green: 0.62, blue: 0.32)
    static let brassDk  = Color(red: 0.42, green: 0.33, blue: 0.16)
    static let litOn    = Color(red: 0.42, green: 0.92, blue: 0.55)
    static let litOff   = Color(red: 0.22, green: 0.24, blue: 0.28)
    static let vaultBg  = Color(red: 0.07, green: 0.08, blue: 0.10)
    static let reveal0  = Color(red: 0.13, green: 0.30, blue: 0.22)
    static let reveal1  = Color(red: 0.07, green: 0.16, blue: 0.13)
}

// MARK: - Backdrop (vault interior, always opaque so an edge-on door is never blank)

private struct VaultDialView_VaultBackdrop: View {
    let side: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: side * 0.12, style: .continuous)
            .fill(VaultDialView_VaultPalette.vaultBg)
            .overlay(
                RoundedRectangle(cornerRadius: side * 0.12, style: .continuous)
                    .strokeBorder(VaultDialView_VaultPalette.steelLo, lineWidth: max(1, side * 0.012))
            )
            .frame(width: side * 0.96, height: side * 0.96)
    }
}

// MARK: - Demo driver (auto-loop, no haptics)

private struct VaultDialView_DemoDriver: View {
    let side: CGFloat

    // Phases scripted CW -> CCW -> CW -> open -> reset.
    enum Phase: CaseIterable {
        case rest, spinCW1, spinCCW, spinCW2, unlockedClosed, doorOpen
    }

    var body: some View {
        PhaseAnimator(Phase.allCases) { phase in
            VaultDialView_DialAssembly(
                side: side,
                dialAngle: angle(for: phase),
                litStops: litStops(for: phase),
                doorProgress: doorProgress(for: phase),
                glow: glow(for: phase)
            )
        } animation: { phase in
            switch phase {
            case .rest:           return .easeInOut(duration: 0.45)
            case .spinCW1:        return .easeInOut(duration: 0.85)
            case .spinCCW:        return .easeInOut(duration: 0.95)
            case .spinCW2:        return .easeInOut(duration: 0.80)
            case .unlockedClosed: return .spring(response: 0.35, dampingFraction: 0.6)
            case .doorOpen:       return .spring(response: 0.7, dampingFraction: 0.78)
            }
        }
    }

    private func angle(for phase: Phase) -> Double {
        switch phase {
        case .rest:           return 0
        case .spinCW1:        return .pi * 1.9
        case .spinCCW:        return .pi * 0.5
        case .spinCW2:        return .pi * 2.6
        case .unlockedClosed: return .pi * 2.6
        case .doorOpen:       return .pi * 2.6
        }
    }

    private func litStops(for phase: Phase) -> Int {
        switch phase {
        case .rest:           return 0
        case .spinCW1:        return 1
        case .spinCCW:        return 2
        case .spinCW2:        return 3
        case .unlockedClosed: return 3
        case .doorOpen:       return 3
        }
    }

    private func doorProgress(for phase: Phase) -> Double {
        phase == .doorOpen ? 1 : 0
    }

    private func glow(for phase: Phase) -> Double {
        switch phase {
        case .unlockedClosed, .doorOpen: return 1
        default: return 0
        }
    }
}

// MARK: - Interactive driver (real safe-cracking)

private struct VaultDialView_InteractiveDriver: View {
    let side: CGFloat

    @State private var dialAngle: Double = 0          // accumulated radians
    @State private var litStops: Int = 0
    @State private var doorProgress: Double = 0
    @State private var unlocked: Bool = false

    // Drag tracking
    @State private var lastTouchAngle: Double? = nil   // raw atan2 of previous frame
    @State private var dirSign: Int = 0                // current travel direction (+1 CW / -1 CCW)
    @State private var directionChanges: Int = 0       // how many reversals matched so far

    // Haptic triggers
    @State private var tickTrigger: Int = 0
    @State private var unlockTrigger: Int = 0

    // The combination is "three reversals": CW, then CCW, then CW.
    private let requiredReversals = 3

    var body: some View {
        VaultDialView_DialAssembly(
            side: side,
            dialAngle: dialAngle,
            litStops: litStops,
            doorProgress: doorProgress,
            glow: unlocked ? 1 : 0
        )
        .contentShape(Circle())
        .gesture(dialGesture)
        .sensoryFeedback(.selection, trigger: tickTrigger)
        .sensoryFeedback(.success, trigger: unlockTrigger)
    }

    private var dialGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in handleChange(value) }
            .onEnded { _ in lastTouchAngle = nil }
    }

    private func handleChange(_ value: DragGesture.Value) {
        guard !unlocked else { return }

        // atan2 of the touch relative to the dial center (center of the assembly).
        let center = CGPoint(x: side * 0.5, y: side * 0.5)
        let raw = atan2(value.location.y - center.y, value.location.x - center.x)

        guard let prev = lastTouchAngle else {
            lastTouchAngle = raw
            return
        }

        // Normalize the delta into [-pi, pi] so the +/-pi wrap never spuriously
        // reads as a huge jump / fake reversal.
        var delta = raw - prev
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }
        lastTouchAngle = raw

        dialAngle += delta

        // Direction-reversal matcher: only count meaningful, sustained motion.
        let threshold: Double = 0.02
        guard abs(delta) > threshold else { return }
        let sign = delta > 0 ? 1 : -1

        // Required pattern of travel directions: CW(+1), CCW(-1), CW(+1)
        let pattern = [1, -1, 1]

        if dirSign == 0 {
            // First sustained motion sets the initial direction.
            dirSign = sign
            if sign == pattern[0] {
                registerStop(index: 0)
            }
        } else if sign != dirSign {
            // A reversal happened.
            dirSign = sign
            let expectedIndex = directionChanges // next slot in pattern
            if expectedIndex < pattern.count, sign == pattern[expectedIndex] {
                registerStop(index: expectedIndex)
            } else {
                resetCombination()
            }
        }
    }

    private func registerStop(index: Int) {
        guard index == directionChanges else { return }
        directionChanges = index + 1
        litStops = directionChanges
        tickTrigger += 1
        if directionChanges >= requiredReversals {
            triggerUnlock()
        }
    }

    private func resetCombination() {
        directionChanges = 0
        dirSign = 0
        withAnimation(.easeInOut(duration: 0.25)) {
            litStops = 0
        }
    }

    private func triggerUnlock() {
        unlocked = true
        lastTouchAngle = nil
        unlockTrigger += 1
        withAnimation(.spring(response: 0.7, dampingFraction: 0.78)) {
            doorProgress = 1
        }
    }
}

// MARK: - Dial Assembly (the door + dial face + lights, swung open by doorProgress)

private struct VaultDialView_DialAssembly: View {
    let side: CGFloat
    let dialAngle: Double      // radians
    let litStops: Int
    let doorProgress: Double   // 0...1
    let glow: Double           // 0...1 unlocked illumination

    private var doorAngle: Double { doorProgress * 92 }

    var body: some View {
        ZStack {
            VaultDialView_RevealedContent(side: side)
                .opacity(min(1, doorProgress * 1.6))

            VaultDialView_VaultDoor(
                side: side,
                dialAngle: dialAngle,
                litStops: litStops,
                glow: glow
            )
            // Hinge at the leading edge -> reads as a real vault door, not a flip.
            .rotation3DEffect(
                .degrees(doorAngle),
                axis: (x: 0, y: 1, z: 0),
                anchor: .leading,
                perspective: 0.55
            )
            // Subtle dim as the door turns edge-on.
            .brightness(-0.18 * doorProgress)
        }
    }
}

// MARK: - Revealed content behind the door

private struct VaultDialView_RevealedContent: View {
    let side: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: side * 0.10, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [VaultDialView_VaultPalette.reveal0, VaultDialView_VaultPalette.reveal1],
                        center: .center,
                        startRadius: side * 0.04,
                        endRadius: side * 0.55
                    )
                )
            VStack(spacing: side * 0.05) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: side * 0.20, weight: .semibold))
                Text("UNLOCKED")
                    .font(.system(size: side * 0.085, weight: .heavy, design: .rounded))
                    .tracking(side * 0.012)
            }
            .foregroundStyle(VaultDialView_VaultPalette.litOn)
        }
        .frame(width: side * 0.78, height: side * 0.78)
        .shadow(color: VaultDialView_VaultPalette.litOn.opacity(0.4), radius: side * 0.05)
    }
}

// MARK: - The vault door face: steel plate + indicator lights + spinning dial

private struct VaultDialView_VaultDoor: View {
    let side: CGFloat
    let dialAngle: Double
    let litStops: Int
    let glow: Double

    var body: some View {
        ZStack {
            // Steel door plate
            RoundedRectangle(cornerRadius: side * 0.10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [VaultDialView_VaultPalette.plate1, VaultDialView_VaultPalette.plate0],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: side * 0.10, style: .continuous)
                        .strokeBorder(VaultDialView_VaultPalette.steelLo, lineWidth: max(1, side * 0.014))
                )
                .overlay(rivets)
                .frame(width: side * 0.78, height: side * 0.78)

            VaultDialView_StopLights(side: side, litStops: litStops, glow: glow)

            VaultDialView_DialFace(side: side, angle: dialAngle, glow: glow)
        }
    }

    private var rivets: some View {
        GeometryReader { g in
            let inset = g.size.width * 0.10
            let r = g.size.width * 0.020
            ZStack {
                rivet(at: CGPoint(x: inset, y: inset), r: r)
                rivet(at: CGPoint(x: g.size.width - inset, y: inset), r: r)
                rivet(at: CGPoint(x: inset, y: g.size.height - inset), r: r)
                rivet(at: CGPoint(x: g.size.width - inset, y: g.size.height - inset), r: r)
            }
        }
    }

    private func rivet(at p: CGPoint, r: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [VaultDialView_VaultPalette.steelHi, VaultDialView_VaultPalette.steelLo],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: r * 2
                )
            )
            .frame(width: r * 2, height: r * 2)
            .position(p)
    }
}

// MARK: - Stop indicator lights (a small ring of pips above the dial)

private struct VaultDialView_StopLights: View {
    let side: CGFloat
    let litStops: Int
    let glow: Double

    private let total = 3

    var body: some View {
        let pip = side * 0.045
        HStack(spacing: side * 0.045) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(i < litStops ? VaultDialView_VaultPalette.litOn : VaultDialView_VaultPalette.litOff)
                    .frame(width: pip, height: pip)
                    .overlay(
                        Circle().strokeBorder(VaultDialView_VaultPalette.steelLo, lineWidth: max(0.5, side * 0.004))
                    )
                    .shadow(
                        color: VaultDialView_VaultPalette.litOn.opacity(i < litStops ? 0.8 : 0),
                        radius: pip * 0.6
                    )
            }
        }
        .offset(y: -side * 0.27)
        .opacity(0.55 + 0.45 * (litStops > 0 ? 1 : 0))
    }
}

// MARK: - The rotating dial face

private struct VaultDialView_DialFace: View {
    let side: CGFloat
    let angle: Double   // radians
    let glow: Double

    private var dialSize: CGFloat { side * 0.50 }

    var body: some View {
        ZStack {
            // Outer brass collar
            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            VaultDialView_VaultPalette.brassDk, VaultDialView_VaultPalette.brass,
                            VaultDialView_VaultPalette.brassDk, VaultDialView_VaultPalette.brass,
                            VaultDialView_VaultPalette.brassDk
                        ],
                        center: .center
                    )
                )
                .frame(width: dialSize * 1.20, height: dialSize * 1.20)
                .overlay(
                    Circle()
                        .strokeBorder(VaultDialView_VaultPalette.brassDk, lineWidth: max(1, side * 0.01))
                )
                .shadow(color: VaultDialView_VaultPalette.litOn.opacity(0.7 * glow), radius: side * 0.06 * glow)

            // Knurled dial body with tick marks, this rotates.
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [VaultDialView_VaultPalette.steelHi, VaultDialView_VaultPalette.steelLo],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: dialSize * 0.8
                        )
                    )
                VaultDialView_DialTicks(diameter: dialSize, lineWidth: max(0.5, side * 0.006))
                // Grip notch indicating the dial's current heading.
                Capsule()
                    .fill(VaultDialView_VaultPalette.plate0)
                    .frame(width: dialSize * 0.06, height: dialSize * 0.30)
                    .offset(y: -dialSize * 0.30)
            }
            .frame(width: dialSize, height: dialSize)
            .rotationEffect(.radians(angle))

            // Center hub
            Circle()
                .fill(
                    RadialGradient(
                        colors: [VaultDialView_VaultPalette.steelHi, VaultDialView_VaultPalette.plate0],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: dialSize * 0.18
                    )
                )
                .frame(width: dialSize * 0.30, height: dialSize * 0.30)
                .overlay(
                    Circle().strokeBorder(VaultDialView_VaultPalette.steelLo, lineWidth: max(0.5, side * 0.006))
                )
        }
    }
}

// MARK: - Tick marks around the dial rim

private struct VaultDialView_DialTicks: View {
    let diameter: CGFloat
    let lineWidth: CGFloat

    private let count = 24

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                let major = i % 3 == 0
                Capsule()
                    .fill(VaultDialView_VaultPalette.plate0.opacity(major ? 0.9 : 0.5))
                    .frame(
                        width: lineWidth * (major ? 1.6 : 1.0),
                        height: diameter * (major ? 0.10 : 0.06)
                    )
                    .offset(y: -diameter * 0.40)
                    .rotationEffect(.degrees(Double(i) / Double(count) * 360))
            }
        }
        .frame(width: diameter, height: diameter)
    }
}
