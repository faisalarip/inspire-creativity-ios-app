// catalog-id: mi-knurled-stepper
import SwiftUI

/// A plus/minus stepper whose number rides a knurled metal thumbwheel.
/// Each step rotates the wheel exactly one notch with a detent bounce and a
/// brief motion-blur smear; the value stays crisp on a fixed center plate.
///
/// - `demo == true`  : a self-driving loop ramps the value up and down so the
///                     wheel keeps clicking through detents with no touch.
/// - `demo == false` : the real component — `+` / `−` buttons plus a vertical
///                     drag that scrubs the wheel and snaps to the nearest notch.
struct KnurledStepperView: View {
    var demo: Bool = false

    // MARK: Tuning

    /// Angle between two adjacent notches. This single value drives the spin,
    /// the drag snap, and the haptic trigger.
    private let detent: Double = .pi / 6          // 30° per notch
    private let minValue: Int = 0
    private let maxValue: Int = 99

    // MARK: Interactive state

    @State private var value: Int = 12
    /// Wheel phase in radians. `phase / detent` is the (fractional) notch index.
    @State private var phase: Double = 0
    /// Transient angular speed used to drive the motion-blur smear.
    @State private var smear: Double = 0
    @State private var dragStartPhase: Double = 0

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let unit = side / 120.0                // scale everything off the tile

            Group {
                if demo {
                    demoBody(unit: unit)
                } else {
                    interactiveBody(unit: unit)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Demo (self-driving)

    private func demoBody(unit: CGFloat) -> some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let model = demoModel(at: t)
            stepperLayout(unit: unit,
                          value: model.value,
                          phase: model.phase,
                          smear: model.smear,
                          plusActive: model.plusActive,
                          minusActive: model.minusActive)
        }
    }

    /// Drives a triangle wave of values (ramp up then down) on a ~3.4s loop.
    private func demoModel(at time: Double) -> (value: Int, phase: Double, smear: Double, plusActive: Bool, minusActive: Bool) {
        let stepDuration: Double = 0.42
        let stepsUp = 4
        let total = stepsUp * 2
        let cycle = Double(total) * stepDuration
        let local = time.truncatingRemainder(dividingBy: cycle)
        let rawIndex = local / stepDuration
        let stepIndex = Int(rawIndex)
        let frac = rawIndex - Double(stepIndex)

        // Triangle: 0,1,2,3,4,3,2,1 ...
        let goingUp = stepIndex < stepsUp
        let baseFrom: Int
        let baseTo: Int
        if goingUp {
            baseFrom = stepIndex
            baseTo = stepIndex + 1
        } else {
            let down = stepIndex - stepsUp
            baseFrom = stepsUp - down
            baseTo = stepsUp - down - 1
        }

        // Eased settle within each step gives the detent bounce feel.
        let eased = detentEase(frac)
        let phaseFrom = Double(baseFrom) * detent
        let phaseTo = Double(baseTo) * detent
        let phase = phaseFrom + (phaseTo - phaseFrom) * eased

        // Number swaps at the midpoint of the rotation so it reads with the click.
        let value = 12 + (frac > 0.5 ? baseTo : baseFrom)

        // Smear peaks early in the step and decays to crisp.
        let smear = pow(max(0, 1 - frac * 2.2), 2) * 6

        let plusActive = goingUp && frac < 0.30
        let minusActive = !goingUp && frac < 0.30
        return (value, phase, smear, plusActive, minusActive)
    }

    /// Overshooting ease so each demo step lands with a small detent bounce.
    private func detentEase(_ x: Double) -> Double {
        let c: Double = 1.70158 * 1.2
        let p = x - 1
        return 1 + (c + 1) * p * p * p + c * p * p
    }

    // MARK: - Interactive

    private func interactiveBody(unit: CGFloat) -> some View {
        stepperLayout(unit: unit,
                      value: value,
                      phase: phase,
                      smear: smear,
                      plusActive: false,
                      minusActive: false)
        .contentShape(Rectangle())
        .gesture(wheelDrag(unit: unit))
        .sensoryFeedback(.selection, trigger: value)
    }

    private func wheelDrag(unit: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { g in
                if g.translation == .zero {
                    dragStartPhase = phase
                }
                // Drag up to increase. ~22pt per notch feels machined.
                let perNotch = 22.0 * unit
                let delta = Double(-g.translation.height) / perNotch * detent
                let newPhase = dragStartPhase + delta
                smear = min(8, abs(delta) * 14)
                phase = newPhase
                value = clampValue(baseValueForPhase(newPhase))
            }
            .onEnded { g in
                let perNotch = 22.0 * unit
                let predicted = Double(-g.predictedEndTranslation.height) / perNotch * detent
                let target = dragStartPhase + predicted
                let snapped = (target / detent).rounded() * detent
                withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) {
                    phase = snapped
                }
                value = clampValue(baseValueForPhase(snapped))
                withAnimation(.easeOut(duration: 0.35)) { smear = 0 }
            }
    }

    /// Maps an absolute phase to the displayed value, anchored at the start
    /// value of the drag so scrubbing reads as continuous counting.
    private func baseValueForPhase(_ p: Double) -> Int {
        let notch = Int((p / detent).rounded())
        return 12 + notch
    }

    private func step(_ direction: Int) {
        let next = clampValue(value + direction)
        guard next != value else {
            // At the limit: a small recoil instead of a real step.
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                phase += Double(direction) * detent * 0.18
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.05)) {
                phase -= Double(direction) * detent * 0.18
            }
            return
        }
        smear = 6
        withAnimation(.spring(response: 0.42, dampingFraction: 0.55)) {
            value = next
            phase += Double(direction) * detent
        }
        withAnimation(.easeOut(duration: 0.32)) { smear = 0 }
    }

    private func clampValue(_ v: Int) -> Int { min(maxValue, max(minValue, v)) }

    // MARK: - Shared layout

    @ViewBuilder
    private func stepperLayout(unit: CGFloat,
                               value: Int,
                               phase: Double,
                               smear: Double,
                               plusActive: Bool,
                               minusActive: Bool) -> some View {
        let wheelHeight = 78.0 * unit
        let wheelWidth = 56.0 * unit
        let buttonSize = 30.0 * unit

        HStack(spacing: 10.0 * unit) {
            stepButton(symbol: "minus",
                       unit: unit,
                       size: buttonSize,
                       active: minusActive,
                       direction: -1)

            wheel(unit: unit,
                  width: wheelWidth,
                  height: wheelHeight,
                  value: value,
                  phase: phase,
                  smear: smear)

            stepButton(symbol: "plus",
                       unit: unit,
                       size: buttonSize,
                       active: plusActive,
                       direction: 1)
        }
        .padding(8.0 * unit)
    }

    // MARK: Buttons

    @ViewBuilder
    private func stepButton(symbol: String,
                            unit: CGFloat,
                            size: CGFloat,
                            active: Bool,
                            direction: Int) -> some View {
        let pressed = active
        Button {
            step(direction)
        } label: {
            ZStack {
                Circle()
                    .fill(buttonGradient)
                    .overlay(
                        Circle().strokeBorder(
                            Color(red: 1, green: 1, blue: 1).opacity(0.12),
                            lineWidth: 1)
                    )
                Image(systemName: symbol)
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(Color(red: 0.86, green: 0.88, blue: 0.95))
            }
            .frame(width: size, height: size)
            .scaleEffect(pressed ? 0.86 : 1.0)
            .shadow(color: Color(red: 0, green: 0, blue: 0).opacity(0.45),
                    radius: pressed ? 1 : 3,
                    x: 0, y: pressed ? 1 : 2)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: pressed)
        }
        .buttonStyle(.plain)
        .disabled(demo)
    }

    private var buttonGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.27, green: 0.29, blue: 0.36),
                Color(red: 0.15, green: 0.16, blue: 0.21)
            ],
            startPoint: .top, endPoint: .bottom)
    }

    // MARK: Wheel

    @ViewBuilder
    private func wheel(unit: CGFloat,
                       width: CGFloat,
                       height: CGFloat,
                       value: Int,
                       phase: Double,
                       smear: Double) -> some View {
        let radius = Double(height) / 2.0
        ZStack {
            // Cylinder body
            RoundedRectangle(cornerRadius: 9.0 * unit, style: .continuous)
                .fill(cylinderGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 9.0 * unit, style: .continuous)
                        .strokeBorder(Color(red: 0, green: 0, blue: 0).opacity(0.5),
                                      lineWidth: 1)
                )

            // Knurled ridges scrolling vertically (faked cylinder).
            KnurledStepperView_KnurlRidges(phase: phase, detent: detent, radius: radius)
                .frame(width: width, height: height)
                .blur(radius: min(6, smear) * 0.5 + smear * 0.1)
                .clipShape(RoundedRectangle(cornerRadius: 9.0 * unit, style: .continuous))

            // Top / bottom shading to sell the curvature of the cylinder.
            rimShade
                .clipShape(RoundedRectangle(cornerRadius: 9.0 * unit, style: .continuous))
                .allowsHitTesting(false)

            // Fixed center plate carrying the crisp, swappable number.
            numberPlate(unit: unit, width: width, value: value, smear: smear)

            // Specular sheen sweeping the metal.
            LinearGradient(
                colors: [
                    Color(red: 1, green: 1, blue: 1).opacity(0.0),
                    Color(red: 1, green: 1, blue: 1).opacity(0.18),
                    Color(red: 1, green: 1, blue: 1).opacity(0.0)
                ],
                startPoint: .leading, endPoint: .trailing)
            .clipShape(RoundedRectangle(cornerRadius: 9.0 * unit, style: .continuous))
            .allowsHitTesting(false)
        }
        .frame(width: width, height: height)
    }

    private var cylinderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.11, blue: 0.15),
                Color(red: 0.22, green: 0.24, blue: 0.30),
                Color(red: 0.10, green: 0.11, blue: 0.15)
            ],
            startPoint: .top, endPoint: .bottom)
    }

    private var rimShade: some View {
        LinearGradient(
            colors: [
                Color(red: 0, green: 0, blue: 0).opacity(0.85),
                Color(red: 0, green: 0, blue: 0).opacity(0.0),
                Color(red: 0, green: 0, blue: 0).opacity(0.0),
                Color(red: 0, green: 0, blue: 0).opacity(0.85)
            ],
            startPoint: .top, endPoint: .bottom)
    }

    @ViewBuilder
    private func numberPlate(unit: CGFloat,
                             width: CGFloat,
                             value: Int,
                             smear: Double) -> some View {
        let plateHeight = 30.0 * unit
        ZStack {
            RoundedRectangle(cornerRadius: 6.0 * unit, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.32, green: 0.34, blue: 0.42).opacity(0.55),
                            Color(red: 0.10, green: 0.11, blue: 0.15).opacity(0.55)
                        ],
                        startPoint: .top, endPoint: .bottom)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6.0 * unit, style: .continuous)
                        .stroke(Color(red: 1, green: 1, blue: 1).opacity(0.10),
                                lineWidth: 1)
                )
                .frame(width: width - 8.0 * unit, height: plateHeight)
                .shadow(color: Color(red: 0, green: 0, blue: 0).opacity(0.5),
                        radius: 2, x: 0, y: 1)

            Text("\(value)")
                .font(.system(size: 22.0 * unit, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(value)))
                .foregroundStyle(Color(red: 0.95, green: 0.97, blue: 1.0))
                .shadow(color: Color(red: 0.4, green: 0.7, blue: 1.0).opacity(0.35),
                        radius: 3)
                .blur(radius: min(3.5, smear * 0.45))
        }
    }
}

// MARK: - Knurled ridges (analytic cylinder)

/// Draws horizontal knurl ridges positioned by `y = R·sin(θ)`, lit by the
/// front hemisphere `max(0, cos(θ))`, so they scroll and compress at the rim
/// like a real machined thumbwheel.
private struct KnurledStepperView_KnurlRidges: View {
    var phase: Double
    var detent: Double
    var radius: Double

    var body: some View {
        Canvas { context, size in
            let cy = size.height / 2
            let r = radius
            // Place one ridge per half-detent for a fine knurl.
            let step = detent / 2.0
            let count = Int((Double.pi / step)) + 1

            for i in -count...count {
                let theta = phase.truncatingRemainder(dividingBy: .pi * 2) + Double(i) * step
                let c = cos(theta)
                guard c > 0.02 else { continue }      // front face only
                let y = cy - CGFloat(r * sin(theta))
                guard y >= -4 && y <= size.height + 4 else { continue }

                // Brightness and thickness follow the curvature.
                let bright = pow(c, 0.8)
                let lineHeight = CGFloat(1.4 + 2.6 * c)
                let inset: CGFloat = 4

                let rect = CGRect(x: inset,
                                  y: y - lineHeight / 2,
                                  width: size.width - inset * 2,
                                  height: lineHeight)
                let highlight = 0.18 + 0.62 * bright
                context.fill(
                    Path(roundedRect: rect, cornerRadius: lineHeight / 2),
                    with: .color(Color(red: 0.78, green: 0.82, blue: 0.92)
                        .opacity(highlight)))

                // Thin dark groove just beneath each ridge for depth.
                let grooveRect = CGRect(x: inset,
                                        y: y + lineHeight / 2,
                                        width: size.width - inset * 2,
                                        height: 1)
                context.fill(
                    Path(grooveRect),
                    with: .color(Color(red: 0, green: 0, blue: 0)
                        .opacity(0.32 * bright)))
            }
        }
    }
}
