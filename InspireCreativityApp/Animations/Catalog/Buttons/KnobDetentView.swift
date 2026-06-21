// catalog-id: btn-knob-detent
import SwiftUI

/// A circular hardware-style dial. Rotate it like an audio gear knob: it clicks
/// through notched detents with a tactile micro-rotation kickback at each step
/// until it locks on a value.
///
/// - `demo == true`  → a self-driving PhaseAnimator steps the knob across detents
///   (0 → max → 0) so the tile clicks alive with a kickback at each notch.
/// - `demo == false` → a real DragGesture rotary control (atan2 + delta
///   accumulation) that snaps to the nearest detent with an overshoot spring
///   and fires selection haptics on each detent crossing.
struct KnobDetentView: View {

    var demo: Bool = false

    // MARK: Tunables

    private let detentCount: Int = 8
    private let sweepDegrees: Double = 280          // total travel; clamps so it "locks on a value"
    private var startDegrees: Double { -sweepDegrees / 2 }
    private var endDegrees: Double { sweepDegrees / 2 }
    private var detentStep: Double { sweepDegrees / Double(detentCount - 1) }

    // MARK: Interactive state

    @State private var angle: Double = 0            // current rotation in degrees, clamped to sweep
    @State private var lastRawAngle: Double? = nil  // previous frame's raw atan2 angle (for delta accumulation)
    @State private var detentIndex: Int = 0         // changes on each detent crossing → haptic trigger

    // MARK: Demo phase sequence

    /// Bounce out to the far detent then back — discrete stops are the detents,
    /// the spring overshoot between them is the kickback. ~9 phases keeps the
    /// loop in the 2.5–4s window.
    private let demoPhases: [Int] = [0, 2, 4, 6, 7, 5, 3, 1, 0]

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let diameter = side * 0.74

            ZStack {
                if demo {
                    demoKnob(diameter: diameter)
                } else {
                    interactiveKnob(diameter: diameter)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.selection, trigger: detentIndex)
    }

    // MARK: - Demo (self-driving)

    private func demoKnob(diameter: CGFloat) -> some View {
        PhaseAnimator(demoPhases) { phase in
            knobBody(diameter: diameter, angle: angleFor(detent: phase))
        } animation: { _ in
            // Low damping → the per-step overshoot reads as the detent kickback.
            .spring(response: 0.30, dampingFraction: 0.52)
        }
    }

    // MARK: - Interactive

    private func interactiveKnob(diameter: CGFloat) -> some View {
        // The gesture is attached to this diameter×diameter box, and DragGesture
        // reports `location` in that local space — so the pivot is its own center.
        let center = CGPoint(x: diameter / 2, y: diameter / 2)
        return knobBody(diameter: diameter, angle: angle)
            .contentShape(Circle())
            .gesture(rotationDrag(center: center))
    }

    private func rotationDrag(center: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let raw = rawAngle(at: value.location, center: center)
                guard let previous = lastRawAngle else {
                    lastRawAngle = raw
                    return
                }
                // Delta accumulation avoids the ±180° atan2 wraparound flip.
                var delta = raw - previous
                if delta > 180 { delta -= 360 }
                if delta < -180 { delta += 360 }
                lastRawAngle = raw

                let proposed = (angle + delta).clamped(to: startDegrees...endDegrees)
                let crossedBefore = nearestDetent(for: angle)
                angle = proposed
                let crossedAfter = nearestDetent(for: angle)
                if crossedAfter != crossedBefore {
                    detentIndex = crossedAfter   // fires selection haptic
                }
            }
            .onEnded { _ in
                lastRawAngle = nil
                let snapped = angleFor(detent: nearestDetent(for: angle))
                withAnimation(.spring(response: 0.26, dampingFraction: 0.5)) {
                    angle = snapped
                }
            }
    }

    /// Raw pointer angle in degrees relative to the knob center (0° = up).
    private func rawAngle(at point: CGPoint, center: CGPoint) -> Double {
        let dx = Double(point.x - center.x)
        let dy = Double(point.y - center.y)
        return atan2(dx, -dy) * 180 / .pi
    }

    private func nearestDetent(for deg: Double) -> Int {
        let idx = Int((deg - startDegrees) / detentStep + 0.5)
        return min(max(idx, 0), detentCount - 1)
    }

    private func angleFor(detent index: Int) -> Double {
        startDegrees + Double(index) * detentStep
    }

    // MARK: - Knob visuals (shared by demo + interactive)

    private func knobBody(diameter: CGFloat, angle: Double) -> some View {
        ZStack {
            detentRing(diameter: diameter)
            tickMarks(diameter: diameter, angle: angle)
            dialFace(diameter: diameter)
                .rotationEffect(.degrees(angle))
            valueReadout(diameter: diameter, angle: angle)
        }
        .frame(width: diameter, height: diameter)
    }

    /// The fixed outer collar with the notch ticks drawn around it.
    private func detentRing(diameter: CGFloat) -> some View {
        Circle()
            .stroke(
                AngularGradient(
                    colors: [
                        Color(red: 0.16, green: 0.14, blue: 0.11),
                        Color(red: 0.34, green: 0.30, blue: 0.24),
                        Color(red: 0.16, green: 0.14, blue: 0.11)
                    ],
                    center: .center
                ),
                lineWidth: diameter * 0.05
            )
            .frame(width: diameter * 1.04, height: diameter * 1.04)
    }

    private func tickMarks(diameter: CGFloat, angle: Double) -> some View {
        let activeDetent = nearestDetent(for: angle)
        return ZStack {
            ForEach(0..<detentCount, id: \.self) { i in
                Capsule()
                    .fill(tickColor(active: activeDetent == i))
                    .frame(width: diameter * 0.018, height: diameter * 0.07)
                    .offset(y: -diameter * 0.56)
                    .rotationEffect(.degrees(angleFor(detent: i)))
            }
        }
        .frame(width: diameter, height: diameter)
    }

    /// Highlight the detent the pointer is closest to.
    private func tickColor(active: Bool) -> Color {
        active
            ? Color(red: 1.0, green: 0.78, blue: 0.35)
            : Color(red: 0.42, green: 0.38, blue: 0.32)
    }

    /// The rotating dial: a metallic disc with a brushed sheen and a pointer.
    private func dialFace(diameter: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.30, green: 0.27, blue: 0.23),
                            Color(red: 0.13, green: 0.11, blue: 0.09)
                        ],
                        center: .init(x: 0.35, y: 0.30),
                        startRadius: 0,
                        endRadius: diameter * 0.55
                    )
                )

            // Brushed-metal sheen sweeping across the face.
            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.16),
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.10),
                            Color.white.opacity(0.0)
                        ],
                        center: .center
                    )
                )
                .blendMode(.screen)

            // Knurled rim indentation.
            Circle()
                .strokeBorder(Color.black.opacity(0.45), lineWidth: diameter * 0.03)

            pointer(diameter: diameter)
        }
        .frame(width: diameter * 0.86, height: diameter * 0.86)
        .shadow(color: .black.opacity(0.5), radius: diameter * 0.04, x: 0, y: diameter * 0.02)
    }

    private func pointer(diameter: CGFloat) -> some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.82, blue: 0.40),
                        Color(red: 0.92, green: 0.55, blue: 0.18)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: diameter * 0.04, height: diameter * 0.30)
            .offset(y: -diameter * 0.22)
            .shadow(color: Color(red: 1.0, green: 0.7, blue: 0.3).opacity(0.6),
                    radius: diameter * 0.02)
    }

    /// Center hub showing the locked detent index.
    private func valueReadout(diameter: CGFloat, angle: Double) -> some View {
        let value = nearestDetent(for: angle)
        return Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 0.10, green: 0.09, blue: 0.07),
                        Color(red: 0.04, green: 0.03, blue: 0.02)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter * 0.18
                )
            )
            .frame(width: diameter * 0.34, height: diameter * 0.34)
            .overlay(
                Text("\(value)")
                    .font(.system(size: diameter * 0.16, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 1.0, green: 0.80, blue: 0.40))
                    .monospacedDigit()
            )
            .overlay(
                Circle().strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            )
    }
}

// MARK: - Helpers

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
