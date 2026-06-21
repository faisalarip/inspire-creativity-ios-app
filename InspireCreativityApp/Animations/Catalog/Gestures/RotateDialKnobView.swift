// catalog-id: ges-rotate-dial-knob
import SwiftUI

// MARK: - Tactile Detent Dial
// Twist a knurled dial; it clicks through evenly spaced detents with a
// micro-overshoot at each notch and a tick flash as it passes.
// demo == true  -> self-driving PhaseAnimator that auto-clicks notch to notch.
// demo == false -> single-finger DragGesture + atan2 delta accumulation,
//                  spring(bounce:) snap-to-detent and haptic per notch crossing.

public struct RotateDialKnobView: View {
    public var demo: Bool = false

    // Number of evenly spaced detents around the dial.
    private let detentCount: Int = 8

    // Live interactive state.
    @State private var angle: Double = 0          // current dial angle (radians)
    @State private var lastTouchAngle: Double = 0 // previous sample for delta accumulation
    @State private var isDragging: Bool = false
    @State private var currentDetent: Int = 0     // nearest detent index, updates live
    @State private var flashDetent: Int = -1      // which tick is flashing

    public init(demo: Bool = false) {
        self.demo = demo
    }

    public var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let dim = side * 0.86
            ZStack {
                background
                // DragGesture reports location in the dialStack's local space,
                // so the rotation center is the local mid-point (dim/2, dim/2),
                // NOT the GeometryReader's full-size center.
                content(dim: dim, center: CGPoint(x: dim / 2, y: dim / 2))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Background

    private var background: some View {
        RadialGradient(
            colors: [
                Color(red: 0.10, green: 0.11, blue: 0.16),
                Color(red: 0.05, green: 0.05, blue: 0.09)
            ],
            center: .center,
            startRadius: 0,
            endRadius: 220
        )
        .ignoresSafeArea()
    }

    // MARK: Content router

    @ViewBuilder
    private func content(dim: CGFloat, center: CGPoint) -> some View {
        if demo {
            demoContent(dim: dim)
        } else {
            interactiveContent(dim: dim, center: center)
        }
    }

    // MARK: Demo (self-driving)

    @ViewBuilder
    private func demoContent(dim: CGFloat) -> some View {
        // PhaseAnimator steps over detent indices; each transition uses a
        // spring(bounce:) so the needle micro-overshoots into every notch.
        PhaseAnimator(demoSequence, content: { idx in
            dialStack(dim: dim,
                      liveAngle: detentAngle(for: idx),
                      flashedDetent: ((idx % detentCount) + detentCount) % detentCount)
        }, animation: { _ in
            .spring(duration: 0.34, bounce: 0.42)
        })
    }

    // Sweep up through a handful of detents and back so the dial auto-clicks
    // on a lively ~3s loop (kept short of a full revolution on purpose).
    private var demoSequence: [Int] {
        var seq: [Int] = []
        for i in 0...4 { seq.append(i) }
        for i in stride(from: 3, through: 0, by: -1) { seq.append(i) }
        return seq
    }

    // MARK: Interactive (single-finger twist)

    @ViewBuilder
    private func interactiveContent(dim: CGFloat, center: CGPoint) -> some View {
        dialStack(dim: dim, liveAngle: angle, flashedDetent: flashDetent)
            .contentShape(Circle())
            .gesture(twistGesture(center: center))
            .modifier(DetentHaptic(trigger: currentDetent, enabled: !demo))
    }

    private func twistGesture(center: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let touchAngle = atan2(value.location.y - center.y,
                                       value.location.x - center.x)
                if !isDragging {
                    isDragging = true
                    lastTouchAngle = touchAngle
                    return
                }
                // Shortest-arc delta avoids the atan2 ±pi wrap discontinuity.
                var delta = touchAngle - lastTouchAngle
                delta = normalizedAngle(delta)
                lastTouchAngle = touchAngle
                angle += delta
                updateLiveDetent()
            }
            .onEnded { _ in
                isDragging = false
                let target = nearestDetentIndex(for: angle)
                withAnimation(.spring(duration: 0.45, bounce: 0.4)) {
                    angle = detentAngle(for: target)
                }
                fireDetent(index: target)
            }
    }

    // Update nearest-detent index live so haptic + tick flash fire as we pass.
    private func updateLiveDetent() {
        let idx = nearestDetentIndex(for: angle)
        let wrapped = ((idx % detentCount) + detentCount) % detentCount
        if wrapped != currentDetent {
            fireDetent(index: idx)
        }
    }

    private func fireDetent(index: Int) {
        let wrapped = ((index % detentCount) + detentCount) % detentCount
        currentDetent = wrapped
        withAnimation(.easeOut(duration: 0.08)) {
            flashDetent = wrapped
        }
        withAnimation(.easeIn(duration: 0.45).delay(0.10)) {
            flashDetent = -1
        }
    }

    // MARK: Detent math

    private var detentStep: Double { (2 * Double.pi) / Double(detentCount) }

    private func detentAngle(for index: Int) -> Double {
        Double(index) * detentStep
    }

    private func nearestDetentIndex(for a: Double) -> Int {
        Int((a / detentStep).rounded())
    }

    private func normalizedAngle(_ a: Double) -> Double {
        var v = a
        while v > Double.pi { v -= 2 * Double.pi }
        while v < -Double.pi { v += 2 * Double.pi }
        return v
    }

    // MARK: Dial assembly

    private func dialStack(dim: CGFloat, liveAngle: Double, flashedDetent: Int) -> some View {
        ZStack {
            DetentTicks(count: detentCount,
                        diameter: dim,
                        flashedDetent: flashedDetent)
            KnobBody(diameter: dim, angle: liveAngle)
            Needle(diameter: dim, angle: liveAngle)
            CenterCap(diameter: dim)
        }
        .frame(width: dim, height: dim)
    }
}

// MARK: - Detent tick ring (the notches)

private struct DetentTicks: View {
    let count: Int
    let diameter: CGFloat
    let flashedDetent: Int

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                tick(at: i)
            }
        }
        .frame(width: diameter, height: diameter)
    }

    private func tick(at i: Int) -> some View {
        let isFlash = (i == flashedDetent)
        let lit = Color(red: 1.0, green: 0.82, blue: 0.36)
        let dim = Color(red: 0.34, green: 0.36, blue: 0.45)
        let h: CGFloat = diameter * (isFlash ? 0.10 : 0.066)
        let w: CGFloat = diameter * (isFlash ? 0.022 : 0.016)
        return Capsule(style: .continuous)
            .fill(isFlash ? lit : dim)
            .frame(width: w, height: h)
            .shadow(color: isFlash ? lit.opacity(0.9) : .clear,
                    radius: isFlash ? 7 : 0)
            .offset(y: -diameter * 0.5 + h * 0.5 + diameter * 0.012)
            .rotationEffect(.radians(Double(i) * tickStep))
    }

    private var tickStep: Double { (2 * Double.pi) / Double(count) }
}

// MARK: - Knurled knob body

private struct KnobBody: View {
    let diameter: CGFloat
    let angle: Double

    private let ridgeCount: Int = 36

    var body: some View {
        ZStack {
            // Recessed bezel.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.07, green: 0.08, blue: 0.12),
                            Color(red: 0.03, green: 0.03, blue: 0.06)
                        ],
                        center: .center,
                        startRadius: diameter * 0.30,
                        endRadius: diameter * 0.50
                    )
                )
                .frame(width: diameter * 0.92, height: diameter * 0.92)

            // Knob plate with directional sheen.
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.26, green: 0.28, blue: 0.36),
                            Color(red: 0.13, green: 0.14, blue: 0.20),
                            Color(red: 0.08, green: 0.09, blue: 0.13)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: diameter * 0.78, height: diameter * 0.78)
                .overlay(knurling)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                        .frame(width: diameter * 0.78, height: diameter * 0.78)
                )
                .rotationEffect(.radians(angle))
                .shadow(color: .black.opacity(0.55), radius: 10, x: 0, y: 6)
        }
    }

    // Ridged grip texture around the plate rim.
    private var knurling: some View {
        ZStack {
            ForEach(0..<ridgeCount, id: \.self) { i in
                ridge(at: i)
            }
        }
        .frame(width: diameter * 0.78, height: diameter * 0.78)
        .mask(
            Circle()
                .strokeBorder(Color.black, lineWidth: diameter * 0.11)
                .frame(width: diameter * 0.78, height: diameter * 0.78)
        )
    }

    private func ridge(at i: Int) -> some View {
        let shade = (i % 2 == 0)
            ? Color.white.opacity(0.16)
            : Color.black.opacity(0.30)
        return Rectangle()
            .fill(shade)
            .frame(width: ridgeWidth, height: diameter * 0.78)
            .rotationEffect(.radians(Double(i) * ridgeStep))
    }

    private var ridgeWidth: CGFloat { diameter * 0.013 }
    private var ridgeStep: Double { Double.pi / Double(ridgeCount) }
}

// MARK: - Pointer needle

private struct Needle: View {
    let diameter: CGFloat
    let angle: Double

    var body: some View {
        Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.88, blue: 0.52),
                        Color(red: 0.96, green: 0.55, blue: 0.20)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: diameter * 0.030, height: diameter * 0.30)
            .offset(y: -diameter * 0.16)
            .shadow(color: Color(red: 0.96, green: 0.55, blue: 0.20).opacity(0.55),
                    radius: 5)
            .rotationEffect(.radians(angle))
    }
}

// MARK: - Center cap

private struct CenterCap: View {
    let diameter: CGFloat

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 0.30, green: 0.32, blue: 0.40),
                        Color(red: 0.10, green: 0.11, blue: 0.16)
                    ],
                    center: .init(x: 0.4, y: 0.35),
                    startRadius: 0,
                    endRadius: diameter * 0.12
                )
            )
            .frame(width: diameter * 0.20, height: diameter * 0.20)
            .overlay(
                Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}

// MARK: - Haptic helper (gated to interactive mode)

private struct DetentHaptic: ViewModifier {
    let trigger: Int
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.sensoryFeedback(.impact(weight: .light, intensity: 0.8),
                                    trigger: trigger)
        } else {
            content
        }
    }
}
