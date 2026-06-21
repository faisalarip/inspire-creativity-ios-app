// catalog-id: ges-throw-and-catch-orbit
import SwiftUI

// MARK: - Boomerang Toss
/// Fling the puck and it arcs out, decelerates, curves back along a banking
/// return path, and lands home in the launch slot with a catch bounce.
struct ThrowAndCatchOrbitView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                ThrowAndCatchOrbitView_BackgroundField()
                if demo {
                    ThrowAndCatchOrbitView_DemoFlight(size: size)
                } else {
                    ThrowAndCatchOrbitView_InteractiveFlight(size: size)
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Shared geometry & math

private enum ThrowAndCatchOrbitView_Orbit {
    /// Where the slot sits within the view (slightly below-center, low-left
    /// launch feel). Returned as a concrete point for a given size.
    static func slot(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * 0.34, y: size.height * 0.66)
    }

    /// Flight reach as a fraction of the view's short edge.
    static func reach(in size: CGSize) -> CGFloat {
        min(size.width, size.height) * 0.62
    }

    /// Pure position function shared by demo and interactive modes.
    /// `progress` 0 -> 1. Both p=0 and p=1 land exactly on the slot because
    /// sin(pi*p) is zero at the endpoints; the rotating `angle` makes the
    /// return leg curve home instead of retracing the outbound leg.
    static func position(progress p: CGFloat,
                         launchAngle: CGFloat,
                         curl: CGFloat,
                         in size: CGSize) -> CGPoint {
        let s = slot(in: size)
        let r = reach(in: size)
        let angle = launchAngle + curl * (p - 0.5)
        let radius = r * sin(.pi * p)
        let dx = radius * cos(angle)
        let dy = radius * sin(angle)
        return CGPoint(x: s.x + dx, y: s.y + dy)
    }

    /// Banking rotation = tangent direction via finite difference, eased to
    /// rest near the endpoints where speed -> 0 and the tangent gets noisy.
    static func banking(progress p: CGFloat,
                        launchAngle: CGFloat,
                        curl: CGFloat,
                        in size: CGSize) -> Angle {
        let edge: CGFloat = 0.06
        let calmP = min(max(p, edge), 1 - edge)
        let h: CGFloat = 0.012
        let a = position(progress: calmP - h, launchAngle: launchAngle, curl: curl, in: size)
        let b = position(progress: calmP + h, launchAngle: launchAngle, curl: curl, in: size)
        let dirAngle = atan2(b.y - a.y, b.x - a.x)
        // Fade the bank toward zero at the very ends so the catch doesn't twitch.
        let endFade = sin(.pi * p)
        return Angle(radians: Double(dirAngle * endFade))
    }

    /// Ease-out: decelerate on the way out, like a real toss.
    static func easeOut(_ raw: CGFloat) -> CGFloat {
        let clamped = min(max(raw, 0), 1)
        return 1 - pow(1 - clamped, 2.0)
    }
}

// MARK: - Background field & slot

private struct ThrowAndCatchOrbitView_BackgroundField: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let s = ThrowAndCatchOrbitView_Orbit.slot(in: size)
            let r = ThrowAndCatchOrbitView_Orbit.reach(in: size)
            ZStack {
                RadialGradient(
                    colors: [
                        Color(red: 0.10, green: 0.11, blue: 0.18),
                        Color(red: 0.05, green: 0.05, blue: 0.09)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * 0.75
                )
                // Faint hint of the boomerang's return loop.
                ThrowAndCatchOrbitView_ReturnPathHint(launchAngle: -1.05, curl: 1.5)
                    .stroke(
                        Color(red: 0.42, green: 0.50, blue: 0.95).opacity(0.12),
                        style: StrokeStyle(lineWidth: max(1.2, r * 0.012),
                                           lineCap: .round, dash: [2, 7])
                    )
                ThrowAndCatchOrbitView_LaunchSlot(slot: s, radius: max(10, r * 0.16))
            }
        }
    }
}

private struct ThrowAndCatchOrbitView_ReturnPathHint: Shape {
    var launchAngle: CGFloat
    var curl: CGFloat
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let size = rect.size
        let steps = 48
        for i in 0...steps {
            let p = CGFloat(i) / CGFloat(steps)
            let pt = ThrowAndCatchOrbitView_Orbit.position(progress: p, launchAngle: launchAngle, curl: curl, in: size)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        return path
    }
}

private struct ThrowAndCatchOrbitView_LaunchSlot: View {
    var slot: CGPoint
    var radius: CGFloat
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.10, green: 0.12, blue: 0.22),
                            Color(red: 0.06, green: 0.07, blue: 0.12)
                        ],
                        center: .center, startRadius: 0, endRadius: radius
                    )
                )
                .frame(width: radius * 2, height: radius * 2)
            Circle()
                .strokeBorder(
                    Color(red: 0.40, green: 0.48, blue: 0.92).opacity(0.55),
                    lineWidth: max(1.5, radius * 0.10)
                )
                .frame(width: radius * 2, height: radius * 2)
            Circle()
                .strokeBorder(
                    Color(red: 0.55, green: 0.62, blue: 1.0).opacity(0.18),
                    lineWidth: max(1, radius * 0.04)
                )
                .frame(width: radius * 2.5, height: radius * 2.5)
        }
        .position(slot)
    }
}

// MARK: - The flung object (a boomerang puck)

private struct ThrowAndCatchOrbitView_Puck: View {
    var diameter: CGFloat
    var squash: CGFloat        // 1 = round, <1 vertical squash, >1 stretch
    var glow: CGFloat          // 0...1 trail glow intensity

    var body: some View {
        ZStack {
            // Soft motion glow behind the body.
            Circle()
                .fill(Color(red: 0.45, green: 0.55, blue: 1.0))
                .frame(width: diameter * 1.55, height: diameter * 1.55)
                .blur(radius: diameter * 0.45)
                .opacity(0.22 + 0.35 * glow)

            // Boomerang body: an elbow drawn from two fat capsules.
            ThrowAndCatchOrbitView_BoomerangShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.78, blue: 0.42),
                            Color(red: 0.93, green: 0.45, blue: 0.55)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    ThrowAndCatchOrbitView_BoomerangShape()
                        .stroke(Color.white.opacity(0.45), lineWidth: max(0.8, diameter * 0.03))
                )
                .frame(width: diameter, height: diameter)
                .shadow(color: Color.black.opacity(0.45),
                        radius: diameter * 0.12, x: 0, y: diameter * 0.10)

            // Center hub highlight.
            Circle()
                .fill(Color.white.opacity(0.75))
                .frame(width: diameter * 0.16, height: diameter * 0.16)
        }
        .scaleEffect(x: 2 - squash, y: squash, anchor: .center)
    }
}

private struct ThrowAndCatchOrbitView_BoomerangShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let t = w * 0.30          // arm thickness
        var path = Path()
        // A rounded "V" / elbow.
        path.move(to: CGPoint(x: w * 0.12, y: h * 0.12))
        path.addLine(to: CGPoint(x: w * 0.12 + t, y: h * 0.12))
        path.addLine(to: CGPoint(x: w * 0.55, y: h * 0.55 - t * 0.2))
        path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.88 - t))
        path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.88))
        path.addLine(to: CGPoint(x: w * 0.88 - t, y: h * 0.88))
        path.addLine(to: CGPoint(x: w * 0.45, y: h * 0.45 + t * 0.2))
        path.addLine(to: CGPoint(x: w * 0.12, y: h * 0.12 + t))
        path.closeSubpath()
        return path.applying(
            CGAffineTransform(translationX: -w / 2, y: -h / 2)
                .concatenating(CGAffineTransform(rotationAngle: -.pi / 4))
                .concatenating(CGAffineTransform(translationX: w / 2, y: h / 2))
        )
    }
}

// MARK: - Demo (self-driving, pure time -> position; no state writes)

private struct ThrowAndCatchOrbitView_DemoFlight: View {
    var size: CGSize
    private let loop: Double = 3.4        // total cycle
    private let flightFraction: Double = 0.72   // rest in the slot the remainder
    private let launchAngle: CGFloat = -1.05
    private let curl: CGFloat = 1.5

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = (t.truncatingRemainder(dividingBy: loop)) / loop   // 0...1
            content(for: phase)
        }
    }

    @ViewBuilder
    private func content(for phase: Double) -> some View {
        let d = puckDiameter
        let prog = flightProgress(phase)
        let pos = ThrowAndCatchOrbitView_Orbit.position(progress: prog, launchAngle: launchAngle, curl: curl, in: size)
        let bank = ThrowAndCatchOrbitView_Orbit.banking(progress: prog, launchAngle: launchAngle, curl: curl, in: size)
        let spin = Double(prog) * 720.0     // boomerang spins as it flies
        let glow = sin(.pi * prog)          // brightest mid-flight
        let squash = catchSquash(phase)
        ThrowAndCatchOrbitView_Puck(diameter: d, squash: squash, glow: glow)
            .rotationEffect(bank)
            .rotationEffect(.degrees(spin))
            .position(pos)
    }

    private var puckDiameter: CGFloat { min(size.width, size.height) * 0.20 }

    /// Maps the loop phase to flight progress 0->1, then holds at 0 (resting in
    /// the slot) for the remainder so the object is always visible.
    private func flightProgress(_ phase: Double) -> CGFloat {
        guard phase < flightFraction else { return 0 }
        let raw = CGFloat(phase / flightFraction)
        // Ease-out so it decelerates on the way out, like a real toss.
        return ThrowAndCatchOrbitView_Orbit.easeOut(raw)
    }

    /// A brief squash right at the catch (flight end) and on the rest segment.
    private func catchSquash(_ phase: Double) -> CGFloat {
        let restStart = flightFraction
        guard phase >= restStart else { return 1.0 }
        // Decaying bounce just after landing.
        let local = (phase - restStart) / (1 - restStart)   // 0...1 in rest
        let damp = exp(-local * 6.0)
        let wobble = cos(local * .pi * 4.0)
        return 1.0 + CGFloat(0.22 * damp * wobble)
    }
}

// MARK: - Interactive (drag to wind up, fling to launch, catch on completion)

private enum ThrowAndCatchOrbitView_FlightPhase { case idle, aiming, flying }

private struct ThrowAndCatchOrbitView_InteractiveFlight: View {
    var size: CGSize

    @State private var phase: ThrowAndCatchOrbitView_FlightPhase = .idle
    @State private var aimOffset: CGSize = .zero       // wind-up pull from slot
    @State private var launchAngle: CGFloat = -1.05
    @State private var curl: CGFloat = 1.5
    @State private var spinBase: Double = 0            // accumulated rest spin
    @State private var spinRevs: Double = 1.5          // revolutions this flight
    @State private var catchScale: CGFloat = 1.0       // spring-driven squash
    @State private var catchTrigger: Int = 0

    // Time-driven flight: TimelineView re-samples the path each frame so the
    // puck actually traces the curved return arc (unlike a withAnimation tween
    // of .position, which would interpolate slot->slot and never travel).
    @State private var flightStart: Date = .distantPast
    private let flightDuration: Double = 0.95

    private var puckDiameter: CGFloat { min(size.width, size.height) * 0.20 }

    var body: some View {
        let slot = ThrowAndCatchOrbitView_Orbit.slot(in: size)
        // Pause the timeline whenever we're not flying so idle/aiming render
        // purely from state changes without burning the frame clock.
        TimelineView(.animation(paused: phase != .flying)) { context in
            let prog = currentProgress(now: context.date)
            content(slot: slot, progress: prog)
        }
    }

    @ViewBuilder
    private func content(slot: CGPoint, progress prog: CGFloat) -> some View {
        let pos = currentPosition(slot: slot, progress: prog)
        let bank = currentBanking(progress: prog)
        let glow: Double = phase == .flying ? Double(sin(.pi * prog)) : 0.0
        let spin = spinBase + (phase == .flying ? Double(prog) * 360.0 * spinRevs : 0)
        let grab = puckDiameter * 2.2

        ThrowAndCatchOrbitView_Puck(diameter: puckDiameter, squash: catchScale, glow: glow)
            .rotationEffect(bank)
            .rotationEffect(.degrees(spin))
            .position(pos)
            .contentShape(
                Circle().path(in: CGRect(x: pos.x - grab / 2, y: pos.y - grab / 2,
                                         width: grab, height: grab))
            )
            .gesture(dragGesture(slot: slot))
            .sensoryFeedback(.impact(flexibility: .soft), trigger: catchTrigger)
    }

    // MARK: progress / position

    private func currentProgress(now: Date) -> CGFloat {
        guard phase == .flying else { return 0 }
        let elapsed = now.timeIntervalSince(flightStart)
        let raw = CGFloat(elapsed / flightDuration)
        return ThrowAndCatchOrbitView_Orbit.easeOut(raw)
    }

    private func currentPosition(slot: CGPoint, progress prog: CGFloat) -> CGPoint {
        switch phase {
        case .idle:
            return slot
        case .aiming:
            return CGPoint(x: slot.x + aimOffset.width, y: slot.y + aimOffset.height)
        case .flying:
            return ThrowAndCatchOrbitView_Orbit.position(progress: prog,
                                  launchAngle: launchAngle, curl: curl, in: size)
        }
    }

    private func currentBanking(progress prog: CGFloat) -> Angle {
        guard phase == .flying else { return .zero }
        return ThrowAndCatchOrbitView_Orbit.banking(progress: prog,
                             launchAngle: launchAngle, curl: curl, in: size)
    }

    // MARK: gesture

    private func dragGesture(slot: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard phase != .flying else { return }
                phase = .aiming
                // Pull the puck back from the slot to aim (resisted wind-up).
                aimOffset = CGSize(width: value.translation.width * 0.6,
                                   height: value.translation.height * 0.6)
            }
            .onEnded { value in
                guard phase != .flying else { return }
                launch(with: value)
            }
    }

    private func launch(with value: DragGesture.Value) {
        // Outbound vector = opposite the wind-up pull, biased by fling velocity.
        let pe = value.predictedEndTranslation
        let vx = -value.translation.width - pe.width * 0.18
        let vy = -value.translation.height - pe.height * 0.18
        let magnitude = max(sqrt(vx * vx + vy * vy), 1)

        launchAngle = atan2(vy, vx)
        // Curl direction follows the sideways throw component; clamp the span.
        let lateral = vx                     // sign gives curl handedness
        let curlMag = min(2.0, 0.9 + Double(magnitude) / 400.0)
        curl = CGFloat(lateral >= 0 ? curlMag : -curlMag)

        // Spin scales with throw strength for tactility.
        spinRevs = 1.5 + Double(min(magnitude, 600)) / 300.0
        aimOffset = .zero
        catchScale = 1.0

        // Start the time-driven flight; TimelineView samples the arc each frame.
        flightStart = Date()
        phase = .flying

        // Finite-duration, non-spring animation gives an exact completion time
        // at the slot. The catch reaction lives in the completion closure; the
        // empty body keeps it a pure timer with no competing visual tween.
        withAnimation(.linear(duration: flightDuration)) {
            // no-op visual; used only to hang completion off the same timing
        } completion: {
            self.catchHome()
        }
    }

    private func catchHome() {
        // Land in the slot, fire haptic, run the squash, settle to idle.
        // Bank the flight's spin into the resting orientation so the rotation
        // doesn't visually snap when we leave the flying phase.
        spinBase += Double(1.0) * 360.0 * spinRevs
        phase = .idle
        catchTrigger += 1
        catchScale = 0.72
        withAnimation(.spring(response: 0.42, dampingFraction: 0.42)) {
            catchScale = 1.0
        }
    }
}
