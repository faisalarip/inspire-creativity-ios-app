// catalog-id: ges-fling-spinner-coast
import SwiftUI

/// Fortune Wheel Flick — flick a segmented wheel and it spins with angular
/// momentum, a ticking flap clacking past each segment and slowing with
/// friction until the pointer eases into a final wedge.
///
/// - `demo == true`  : self-driving loop re-flicks the wheel every cycle.
/// - `demo == false` : real `DragGesture` flick with friction-decay coast,
///                     analytic snap-to-wedge, deflecting clicker flap and
///                     per-tick haptics.
struct FlingSpinnerCoastView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            if demo {
                DemoSpinner(side: side, center: center)
            } else {
                InteractiveSpinner(side: side, center: center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.051, green: 0.055, blue: 0.086))
    }
}

// MARK: - Shared geometry / palette

private enum Wheel {
    static let segments: Int = 8
    static var seg: Double { (2 * .pi) / Double(segments) }

    /// The fixed pointer sits at 12 o'clock. In screen space that direction is
    /// `-.pi/2` (straight up). A wedge "center" is what we want resting under
    /// the pointer, so the snap target solves for the wedge center aligning
    /// with the pointer angle.
    static let pointerAngle: Double = -.pi / 2

    /// Decay constant (1/seconds). k·cycleDuration must stay ≥ ~5 so the
    /// residual position gap at a demo cycle boundary is invisible.
    static let friction: Double = 1.9

    static let wedgeColors: [Color] = [
        Color(red: 0.93, green: 0.36, blue: 0.42),
        Color(red: 0.98, green: 0.70, blue: 0.32),
        Color(red: 0.40, green: 0.80, blue: 0.58),
        Color(red: 0.36, green: 0.62, blue: 0.93),
        Color(red: 0.74, green: 0.50, blue: 0.93),
        Color(red: 0.98, green: 0.52, blue: 0.66),
        Color(red: 0.46, green: 0.84, blue: 0.86),
        Color(red: 0.96, green: 0.84, blue: 0.40)
    ]

    /// Rotation that lands the nearest wedge center under the fixed pointer.
    ///
    /// Wedge `i` spans `[i·seg, (i+1)·seg]` with center `i·seg + seg/2`. After a
    /// wheel rotation `θ` that center sits at screen angle `i·seg + seg/2 + θ`.
    /// Requiring it to equal `pointerAngle` gives valid rotations
    /// `θ = (pointerAngle - seg/2) + n·seg`. We snap to the one nearest `rest`.
    static func snappedRest(_ rest: Double) -> Double {
        let offset = pointerAngle - seg / 2
        let n = (rest - offset) / seg
        return n.rounded() * seg + offset
    }
}

// MARK: - Spin model (pure, analytic)

private struct SpinModel {
    /// angle(t) = S − (S − start)·exp(−k·t)
    /// At t=0 → start, at t→∞ → S (a snapped wedge center under the pointer).
    static func angle(start: Double, target: Double, elapsed: Double) -> Double {
        let k = Wheel.friction
        return target - (target - start) * exp(-k * elapsed)
    }

    /// Instantaneous angular speed magnitude — drives flap deflection so the
    /// clicker only flicks while the wheel is actually moving.
    static func angularSpeed(start: Double, target: Double, elapsed: Double) -> Double {
        let k = Wheel.friction
        return abs((target - start) * k * exp(-k * elapsed))
    }

    /// Signed direction of rotation (for flap lean side).
    static func direction(start: Double, target: Double) -> Double {
        (target - start) >= 0 ? 1 : -1
    }
}

// MARK: - Demo (self-driving)

private struct DemoSpinner: View {
    let side: CGFloat
    let center: CGPoint

    private let cycle: Double = 3.4

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let cycleIndex = floor(t / cycle)
            let tau = t - cycleIndex * cycle

            // Each cycle advances an integer number of wedges so every target
            // is a true wedge center; accumulating the base gives a continuous
            // re-flick with no backwards jump.
            let wedgesPerCycle: Double = 5
            let baseStart = Wheel.snappedRest(0)
            let start = baseStart + cycleIndex * wedgesPerCycle * Wheel.seg
            let target = start + wedgesPerCycle * Wheel.seg

            let angle = SpinModel.angle(start: start, target: target, elapsed: tau)
            let speed = SpinModel.angularSpeed(start: start, target: target, elapsed: tau)
            let dir = SpinModel.direction(start: start, target: target)

            SpinnerStage(
                side: side,
                center: center,
                rotation: angle,
                flapDeflection: flapDeflection(angle: angle, speed: speed, dir: dir),
                tickIndex: 0,
                hapticsEnabled: false
            )
        }
    }
}

// MARK: - Interactive

private struct InteractiveSpinner: View {
    let side: CGFloat
    let center: CGPoint

    // Coasting state
    @State private var startAngle: Double = Wheel.snappedRest(0)
    @State private var targetAngle: Double = Wheel.snappedRest(0)
    @State private var flingDate: Date = .distantPast

    // Dragging state
    @State private var isDragging: Bool = false
    @State private var dragBaseAngle: Double = Wheel.snappedRest(0)
    @State private var accumulatedFinger: Double = 0
    @State private var lastFingerAngle: Double = 0

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSince(flingDate)
            let render = renderState(elapsed: elapsed)

            SpinnerStage(
                side: side,
                center: center,
                rotation: render.angle,
                flapDeflection: flapDeflection(angle: render.angle, speed: render.speed, dir: render.dir),
                tickIndex: render.tickIndex,
                hapticsEnabled: true
            )
        }
        .contentShape(Rectangle())
        .gesture(spinGesture)
    }

    private struct RenderState {
        var angle: Double
        var speed: Double
        var dir: Double
        var tickIndex: Int
    }

    private func renderState(elapsed: Double) -> RenderState {
        let angle: Double
        let speed: Double
        let dir: Double
        if isDragging {
            angle = dragBaseAngle + accumulatedFinger
            speed = 0
            dir = accumulatedFinger >= 0 ? 1 : -1
        } else {
            angle = SpinModel.angle(start: startAngle, target: targetAngle, elapsed: max(0, elapsed))
            speed = SpinModel.angularSpeed(start: startAngle, target: targetAngle, elapsed: max(0, elapsed))
            dir = SpinModel.direction(start: startAngle, target: targetAngle)
        }
        let tickIndex = Int(floor(angle / Wheel.seg))
        return RenderState(angle: angle, speed: speed, dir: dir, tickIndex: tickIndex)
    }

    private var spinGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let fingerAngle = atan2(
                    value.location.y - center.y,
                    value.location.x - center.x
                )
                if !isDragging {
                    isDragging = true
                    // Resume from wherever the coast currently sits.
                    let elapsed = Date().timeIntervalSince(flingDate)
                    dragBaseAngle = SpinModel.angle(
                        start: startAngle, target: targetAngle, elapsed: max(0, elapsed)
                    )
                    accumulatedFinger = 0
                    lastFingerAngle = fingerAngle
                }
                // Normalize wrap-around to [-pi, pi] so crossing the atan2 seam
                // doesn't produce a giant jump.
                var delta = fingerAngle - lastFingerAngle
                if delta > .pi { delta -= 2 * .pi }
                if delta < -.pi { delta += 2 * .pi }
                accumulatedFinger += delta
                lastFingerAngle = fingerAngle
            }
            .onEnded { value in
                let current = dragBaseAngle + accumulatedFinger
                let omega = angularVelocity(value: value)

                // Natural exponential rest, then snap that rest to a wedge center.
                let rest = current + omega / Wheel.friction
                let snapped = Wheel.snappedRest(rest)

                startAngle = current
                targetAngle = snapped
                flingDate = Date()

                isDragging = false
                accumulatedFinger = 0
            }
    }

    /// Angular launch velocity from the drag's predicted end (iOS 17-safe).
    private func angularVelocity(value: DragGesture.Value) -> Double {
        let rx = value.location.x - center.x
        let ry = value.location.y - center.y
        let r2 = rx * rx + ry * ry
        guard r2 > 1 else { return 0 }

        // Predicted "remaining" motion is proportional to release velocity.
        let px = value.predictedEndTranslation.width - value.translation.width
        let py = value.predictedEndTranslation.height - value.translation.height

        let gain: Double = 7.5
        let cross = rx * py - ry * px
        return gain * cross / r2
    }
}

// MARK: - Flap deflection (shared, analytic)

/// The clicker flap deflects sharply as a peg passes 12 o'clock, scaled by the
/// current angular speed so it sits flat at rest. `pow(.., 8)` produces a tight
/// clack right at each boundary that springs back across the wedge.
private func flapDeflection(angle: Double, speed: Double, dir: Double) -> Double {
    let phase = angle / Wheel.seg
    let frac = phase - floor(phase)            // 0..1 across one wedge
    // Distance to the nearest boundary (0 or 1), folded to 0..0.5.
    let toBoundary = min(frac, 1 - frac)
    let edge = pow(1 - toBoundary * 2, 8)      // 1 at a boundary, ~0 mid-wedge
    let speedFactor = min(1.0, speed / 6.0)
    let maxDefl: Double = 0.42
    return maxDefl * speedFactor * edge * (dir >= 0 ? 1 : -1)
}

// MARK: - Visual stage

private struct SpinnerStage: View {
    let side: CGFloat
    let center: CGPoint
    let rotation: Double
    let flapDeflection: Double
    let tickIndex: Int
    let hapticsEnabled: Bool

    var body: some View {
        let r = side * 0.40

        ZStack {
            WheelFace(radius: r)
                .rotationEffect(.radians(rotation))
                .position(center)

            HubCap(radius: r * 0.18)
                .position(center)

            ClickerFlap(radius: r, deflection: flapDeflection)
                .position(x: center.x, y: center.y - r)
        }
        .modifier(TickHaptics(enabled: hapticsEnabled, tickIndex: tickIndex))
    }
}

// MARK: - Wheel face

private struct WheelFace: View {
    let radius: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = radius
            let seg = Wheel.seg

            // Outer rim
            let rimRect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
            ctx.fill(
                Circle().path(in: rimRect.insetBy(dx: -r * 0.06, dy: -r * 0.06)),
                with: .color(Color(red: 0.16, green: 0.17, blue: 0.22))
            )

            // Wedges
            for i in 0..<Wheel.segments {
                let a0 = Double(i) * seg
                let a1 = Double(i + 1) * seg
                var path = Path()
                path.move(to: c)
                path.addArc(
                    center: c,
                    radius: r,
                    startAngle: .radians(a0),
                    endAngle: .radians(a1),
                    clockwise: false
                )
                path.closeSubpath()

                let base = Wheel.wedgeColors[i % Wheel.wedgeColors.count]
                ctx.fill(path, with: .color(base))

                // Subtle radial shade for depth, clipped to the wedge.
                ctx.fill(
                    path,
                    with: .radialGradient(
                        Gradient(colors: [
                            Color.white.opacity(0.12),
                            Color.clear,
                            Color.black.opacity(0.18)
                        ]),
                        center: c,
                        startRadius: 0,
                        endRadius: r
                    )
                )
            }

            // Pegs at each boundary (what the flap clacks against).
            for i in 0..<Wheel.segments {
                let a = Double(i) * seg
                let p = CGPoint(
                    x: c.x + cos(a) * r * 0.97,
                    y: c.y + sin(a) * r * 0.97
                )
                let pegR = r * 0.045
                let pegRect = CGRect(
                    x: p.x - pegR, y: p.y - pegR,
                    width: pegR * 2, height: pegR * 2
                )
                ctx.fill(Circle().path(in: pegRect), with: .color(.white.opacity(0.9)))
                ctx.fill(
                    Circle().path(in: pegRect.insetBy(dx: pegR * 0.4, dy: pegR * 0.4)),
                    with: .color(Color(red: 0.22, green: 0.23, blue: 0.30))
                )
            }
        }
        .frame(width: radius * 2.2, height: radius * 2.2)
    }
}

// MARK: - Hub

private struct HubCap: View {
    let radius: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.93, green: 0.94, blue: 0.98),
                            Color(red: 0.62, green: 0.64, blue: 0.72)
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: radius * 2
                    )
                )
            Circle()
                .stroke(Color.black.opacity(0.25), lineWidth: max(1, radius * 0.12))
        }
        .frame(width: radius * 2, height: radius * 2)
        .shadow(color: .black.opacity(0.4), radius: radius * 0.3, y: radius * 0.2)
    }
}

// MARK: - Clicker flap (fixed at 12 o'clock)

private struct ClickerFlap: View {
    let radius: CGFloat
    let deflection: Double

    var body: some View {
        let w = radius * 0.16
        let h = radius * 0.34

        FlapShape()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.97, green: 0.97, blue: 1.0),
                        Color(red: 0.78, green: 0.80, blue: 0.88)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                FlapShape().stroke(Color.black.opacity(0.25), lineWidth: 1)
            )
            .frame(width: w, height: h)
            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            // Pivot at the top so the flap swings like a hinged clicker.
            .rotationEffect(.radians(deflection), anchor: .top)
            .offset(y: -h * 0.15)
    }
}

private struct FlapShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let topInset = rect.width * 0.12
        p.move(to: CGPoint(x: rect.minX + topInset, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - topInset, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - topInset, y: rect.maxY * 0.55))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))           // point
        p.addLine(to: CGPoint(x: rect.minX + topInset, y: rect.maxY * 0.55))
        p.closeSubpath()
        return p
    }
}

// MARK: - Haptics modifier

private struct TickHaptics: ViewModifier {
    let enabled: Bool
    let tickIndex: Int

    func body(content: Content) -> some View {
        if enabled {
            content.sensoryFeedback(.impact(weight: .light), trigger: tickIndex)
        } else {
            content
        }
    }
}
