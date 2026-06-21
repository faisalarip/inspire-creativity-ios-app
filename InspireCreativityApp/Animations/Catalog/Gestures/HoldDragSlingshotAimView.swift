// catalog-id: ges-hold-drag-slingshot-aim
import SwiftUI

// MARK: - HoldDragSlingshotAimView
// "Hold-Aim Trajectory Cannon"
// Press and drag back from a cannon to set power + angle; a dotted predicted
// arc updates live. Release fires a ball that follows that EXACT parametric
// arc and bounces on landing.
//
// Core idea: a single closed-form projectile function f(t) drives BOTH the
// dotted preview AND the live flight, so the shot lands precisely on the
// previewed path. Everything is normalized to the GeometryReader size so it
// reads identically in a 120pt tile and a large detail area.

public struct HoldDragSlingshotAimView: View {
    var demo: Bool = false

    public init(demo: Bool = false) {
        self.demo = demo
    }

    // Interactive aim state (normalized 0...1 of the smaller dimension).
    @State private var pull: CGSize = .zero          // current pull-back vector
    @State private var isAiming: Bool = false
    @State private var isFlying: Bool = false
    @State private var firePull: CGSize = .zero       // pull captured at release
    @State private var fireStart: Date = .distantPast

    public var body: some View {
        GeometryReader { geo in
            let size = geo.size
            content(in: size)
                .frame(width: size.width, height: size.height)
                .contentShape(Rectangle())
                .gesture(demo ? nil : aimGesture(in: size))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Self.backdrop)
    }

    // MARK: Layout content

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        let unit = min(size.width, size.height)
        let origin = launchOrigin(in: size)
        let g = Physics.gravity * unit

        TimelineView(.animation) { timeline in
            let now = timeline.date
            let state = resolvedState(now: now, size: size, unit: unit)

            ZStack {
                GroundView(y: Physics.groundY * size.height, width: size.width)

                // Dotted predicted arc (first arc to landing).
                TrajectoryDots(
                    points: previewPoints(
                        v0: state.v0, origin: origin, g: g, size: size, unit: unit
                    ),
                    unit: unit,
                    active: state.aimStrength > 0.001
                )

                // Aim guide line from origin showing the pull-back.
                AimGuide(
                    origin: origin,
                    pull: state.pull,
                    strength: state.aimStrength,
                    unit: unit
                )

                // The flying ball follows the SAME f(t) used for the dots.
                if let ballPos = state.ballPosition {
                    Ball(unit: unit)
                        .position(ballPos)
                        .shadow(color: Self.glow.opacity(0.55), radius: unit * 0.04)
                }

                // Cannon barrel, anchored at origin, aimed along launch vector.
                CannonView(
                    origin: origin,
                    aimAngle: state.barrelAngle,
                    charge: state.aimStrength,
                    unit: unit
                )
            }
            .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.9),
                             trigger: state.bounceTrigger)
        }
    }

    // MARK: Resolved per-frame state

    private struct FrameState {
        var pull: CGSize          // visual pull (for guide + barrel)
        var v0: CGVector          // launch velocity (px/sec)
        var aimStrength: CGFloat  // 0...1 for tint / charge
        var barrelAngle: CGFloat  // radians, barrel direction
        var ballPosition: CGPoint?
        var bounceTrigger: Int
    }

    private func resolvedState(now: Date, size: CGSize, unit: CGFloat) -> FrameState {
        let origin = launchOrigin(in: size)
        let g = Physics.gravity * unit

        if demo {
            return demoState(now: now, origin: origin, g: g, size: size, unit: unit)
        } else {
            return interactiveState(now: now, origin: origin, g: g, size: size, unit: unit)
        }
    }

    // MARK: Interactive state

    private func interactiveState(now: Date, origin: CGPoint, g: CGFloat,
                                  size: CGSize, unit: CGFloat) -> FrameState {
        let activePull = isFlying ? firePull : pull
        let v0 = launchVelocity(fromPull: activePull, unit: unit)
        let strength = aimStrength(fromPull: activePull, unit: unit)
        let angle = barrelAngle(fromPull: activePull)

        var ballPos: CGPoint? = nil
        var trigger = 0

        if isFlying {
            let t = max(0, now.timeIntervalSince(fireStart))
            let flight = flightPoint(t: t, v0: v0, origin: origin, g: g, size: size)
            ballPos = flight.point
            trigger = flight.bounceIndex
        } else if isAiming {
            // While aiming, rest the ball at the muzzle so it never disappears.
            ballPos = muzzlePoint(origin: origin, angle: angle, unit: unit)
        } else {
            ballPos = loadedPoint(origin: origin, unit: unit)
        }

        return FrameState(
            pull: activePull, v0: v0, aimStrength: strength,
            barrelAngle: angle, ballPosition: ballPos, bounceTrigger: trigger
        )
    }

    // MARK: Demo state (self-driving loop)

    private func demoState(now: Date, origin: CGPoint, g: CGFloat,
                           size: CGSize, unit: CGFloat) -> FrameState {
        let period: Double = 3.4
        let phase = now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period)

        // Timeline split: pull-back (0..0.9), hold (0.9..1.2), flight (1.2..end).
        let drawDur: Double = 0.9
        let holdDur: Double = 0.35
        let flightStart = drawDur + holdDur

        // Aim sweeps slowly across cycles so the arc visibly redraws.
        let cycleSeed = floor(now.timeIntervalSinceReferenceDate / period)
        let aimT = (sin(cycleSeed * 1.3) + 1) * 0.5            // 0...1
        let angleDeg = 30 + aimT * 30                          // 30°...60° up-right
        let angleRad = angleDeg * .pi / 180
        let maxPullMag = unit * 0.30

        // Pull magnitude eases in during the draw window.
        let drawProgress = min(1, phase / drawDur)
        let eased = easeOut(drawProgress)
        let pullMag: CGFloat = (phase < flightStart) ? maxPullMag * eased : maxPullMag

        // Pull vector points DOWN-LEFT (opposite of fire direction).
        let pullVec = CGSize(width: -cos(angleRad) * pullMag,
                             height: sin(angleRad) * pullMag)

        let v0 = launchVelocity(fromPull: pullVec, unit: unit)
        let strength = aimStrength(fromPull: pullVec, unit: unit)
        let barrel = barrelAngle(fromPull: pullVec)

        var ballPos: CGPoint?
        var trigger = 0

        if phase < flightStart {
            // Aiming: ball sits at the muzzle, arc is fully drawn.
            ballPos = muzzlePoint(origin: origin, angle: barrel, unit: unit)
        } else {
            let t = phase - flightStart
            let flight = flightPoint(t: t, v0: v0, origin: origin, g: g, size: size)
            ballPos = flight.point
            trigger = 0   // no haptics in demo (avoid buzzing idle tiles)
        }

        return FrameState(
            pull: pullVec, v0: v0, aimStrength: strength,
            barrelAngle: barrel, ballPosition: ballPos, bounceTrigger: trigger
        )
    }

    // MARK: Physics — single source of truth f(t)

    private enum Physics {
        static let gravity: CGFloat = 2.4      // * unit -> px/s^2
        static let groundY: CGFloat = 0.86     // fraction of height
        static let restitution: CGFloat = 0.55
        static let maxBounces = 2
        static let powerScale: CGFloat = 3.1   // pull -> launch speed multiplier
    }

    /// Launch velocity (px/sec) derived from the pull-back vector.
    /// Pull back+down -> fire up+forward, so v0 = -pull * scale (per frame -> per sec).
    private func launchVelocity(fromPull pull: CGSize, unit: CGFloat) -> CGVector {
        let mag = hypot(pull.width, pull.height)
        let capped = min(mag, unit * 0.34)
        guard mag > 0.0001 else { return .zero }
        let dirX = -pull.width / mag
        let dirY = -pull.height / mag
        let speed = capped * Physics.powerScale * 3.2   // tuned px/sec
        return CGVector(dx: dirX * speed, dy: dirY * speed)
    }

    private func aimStrength(fromPull pull: CGSize, unit: CGFloat) -> CGFloat {
        let mag = hypot(pull.width, pull.height)
        return min(1, mag / (unit * 0.30))
    }

    private func barrelAngle(fromPull pull: CGSize) -> CGFloat {
        let mag = hypot(pull.width, pull.height)
        guard mag > 0.0001 else { return -.pi / 4 }    // default up-right
        // Barrel points opposite the pull (the fire direction).
        return atan2(-pull.height, -pull.width)
    }

    /// Closed-form projectile position with restitution bounces along the ground.
    /// Returns the live point and how many landings have occurred by time t.
    private func flightPoint(t: Double, v0: CGVector, origin: CGPoint,
                             g: CGFloat, size: CGSize) -> (point: CGPoint, bounceIndex: Int) {
        let groundLine = Physics.groundY * size.height
        let ballR = ballRadius(unit: min(size.width, size.height))
        let restLine = groundLine - ballR

        guard hypot(v0.dx, v0.dy) > 0.001 else {
            return (CGPoint(x: origin.x, y: restLine), 0)
        }

        // Simulate piecewise parabolas, advancing through bounces.
        var segVx = v0.dx
        var segVy = v0.dy
        var segX0 = origin.x
        var segY0 = origin.y
        var segT0: Double = 0
        var bounces = 0

        while bounces <= Physics.maxBounces {
            let landT = parabolaLandTime(y0: segY0, vy: segVy, g: g, groundY: restLine)
            // No real future landing this segment (shouldn't happen with gravity > 0).
            guard let absLand = landT, absLand.isFinite else { break }
            let segLandTime = segT0 + absLand

            if t <= segLandTime {
                let lt = t - segT0
                let x = segX0 + segVx * lt
                let y = segY0 + segVy * lt + 0.5 * Double(g) * lt * lt
                let cx = clampX(x, size: size, r: ballR)
                return (CGPoint(x: cx, y: y), bounces)
            }

            // Advance to landing, reflect vertical velocity, damp.
            let lt = absLand
            segX0 = segX0 + segVx * lt
            segY0 = restLine
            let vyAtLand = segVy + Double(g) * lt
            segVy = -vyAtLand * Double(Physics.restitution)
            segVx = segVx * 0.86
            segT0 = segLandTime
            bounces += 1

            // If the bounce is too weak, settle at rest.
            if abs(segVy) < Double(g) * 0.05 || bounces > Physics.maxBounces {
                let cx = clampX(segX0, size: size, r: ballR)
                return (CGPoint(x: cx, y: restLine), bounces)
            }
        }

        let cx = clampX(segX0, size: size, r: ballR)
        return (CGPoint(x: cx, y: restLine), bounces)
    }

    /// Time for a parabola y(t)=y0+vy t+0.5 g t^2 to reach groundY (first future root).
    private func parabolaLandTime(y0: Double, vy: Double, g: CGFloat, groundY: CGFloat) -> Double? {
        let gg = Double(g)
        let target = Double(groundY)
        // 0.5 g t^2 + vy t + (y0 - target) = 0
        let a = 0.5 * gg
        let b = vy
        let c = y0 - target
        guard a != 0 else {
            if b == 0 { return nil }
            let t = -c / b
            return t > 0 ? t : nil
        }
        let disc = b * b - 4 * a * c
        guard disc >= 0 else { return nil }
        let sq = disc.squareRoot()
        let t1 = (-b - sq) / (2 * a)
        let t2 = (-b + sq) / (2 * a)
        let candidates = [t1, t2].filter { $0 > 1e-5 }.sorted()
        return candidates.first
    }

    /// Sample the first arc (origin -> first landing) for the dotted preview.
    private func previewPoints(v0: CGVector, origin: CGPoint, g: CGFloat,
                               size: CGSize, unit: CGFloat) -> [CGPoint] {
        guard hypot(v0.dx, v0.dy) > 0.001 else { return [] }
        let restLine = Physics.groundY * size.height - ballRadius(unit: unit)
        guard let landT = parabolaLandTime(y0: origin.y, vy: v0.dy, g: g, groundY: restLine),
              landT.isFinite, landT > 0 else { return [] }

        let count = 26
        var pts: [CGPoint] = []
        pts.reserveCapacity(count)
        for i in 0...count {
            let t = landT * Double(i) / Double(count)
            let x = origin.x + v0.dx * t
            let y = origin.y + v0.dy * t + 0.5 * Double(g) * t * t
            let cx = clampX(x, size: size, r: ballRadius(unit: unit))
            pts.append(CGPoint(x: cx, y: y))
        }
        return pts
    }

    // MARK: Geometry helpers

    private func launchOrigin(in size: CGSize) -> CGPoint {
        let unit = min(size.width, size.height)
        return CGPoint(x: size.width * 0.16,
                       y: Physics.groundY * size.height - unit * 0.12)
    }

    private func ballRadius(unit: CGFloat) -> CGFloat { unit * 0.052 }

    private func muzzlePoint(origin: CGPoint, angle: CGFloat, unit: CGFloat) -> CGPoint {
        let len = unit * 0.17
        return CGPoint(x: origin.x + cos(angle) * len,
                       y: origin.y + sin(angle) * len)
    }

    private func loadedPoint(origin: CGPoint, unit: CGFloat) -> CGPoint {
        muzzlePoint(origin: origin, angle: -.pi / 4, unit: unit)
    }

    private func clampX(_ x: CGFloat, size: CGSize, r: CGFloat) -> CGFloat {
        min(max(x, r), size.width - r)
    }

    private func easeOut(_ t: Double) -> CGFloat {
        let c = min(max(t, 0), 1)
        return CGFloat(1 - pow(1 - c, 3))
    }

    // MARK: Gesture (long-press, then drag to aim, release to fire)

    private func aimGesture(in size: CGSize) -> some Gesture {
        let unit = min(size.width, size.height)
        let maxPull = unit * 0.34

        let drag = DragGesture(minimumDistance: 0)
            .onChanged { value in
                isFlying = false
                isAiming = true
                // Clamp pull magnitude so power stays bounded.
                var p = value.translation
                let mag = hypot(p.width, p.height)
                if mag > maxPull, mag > 0 {
                    p.width = p.width / mag * maxPull
                    p.height = p.height / mag * maxPull
                }
                pull = p
            }
            .onEnded { value in
                var p = value.translation
                let mag = hypot(p.width, p.height)
                if mag > maxPull, mag > 0 {
                    p.width = p.width / mag * maxPull
                    p.height = p.height / mag * maxPull
                }
                firePull = p
                pull = .zero
                isAiming = false
                if mag > unit * 0.04 {
                    fireStart = Date()
                    isFlying = true
                }
            }

        return LongPressGesture(minimumDuration: 0.08)
            .sequenced(before: drag)
            .onEnded { _ in }
    }

    // MARK: Palette

    static let backdrop = LinearGradient(
        colors: [Color(red: 0.05, green: 0.055, blue: 0.09),
                 Color(red: 0.09, green: 0.10, blue: 0.16)],
        startPoint: .top, endPoint: .bottom
    )
    static let glow = Color(red: 0.45, green: 0.85, blue: 1.0)
    static let warm = Color(red: 1.0, green: 0.62, blue: 0.30)
}

// MARK: - Cannon

private struct CannonView: View {
    let origin: CGPoint
    let aimAngle: CGFloat
    let charge: CGFloat        // 0...1
    let unit: CGFloat

    var body: some View {
        let barrelLen = unit * 0.22
        let barrelW = unit * 0.085
        let tint = HoldDragSlingshotAimView.glow

        ZStack {
            // Barrel
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.30, green: 0.34, blue: 0.42),
                                 Color(red: 0.16, green: 0.18, blue: 0.24)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    Capsule()
                        .stroke(tint.opacity(0.25 + charge * 0.55),
                                lineWidth: max(1, unit * 0.01))
                )
                .frame(width: barrelLen, height: barrelW)
                .offset(x: barrelLen / 2)
                .rotationEffect(.radians(Double(aimAngle)))
                .position(origin)

            // Base / wheel
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.24, green: 0.27, blue: 0.34),
                                 Color(red: 0.12, green: 0.13, blue: 0.18)],
                        center: .center, startRadius: 0, endRadius: unit * 0.13
                    )
                )
                .overlay(
                    Circle().stroke(tint.opacity(0.4), lineWidth: max(1, unit * 0.012))
                )
                .frame(width: unit * 0.20, height: unit * 0.20)
                .position(origin)

            // Charge core glows as power builds.
            Circle()
                .fill(tint)
                .frame(width: unit * 0.07, height: unit * 0.07)
                .opacity(0.35 + Double(charge) * 0.65)
                .blur(radius: unit * 0.01 + Double(charge) * unit * 0.02)
                .position(origin)
        }
    }
}

// MARK: - Trajectory dots

private struct TrajectoryDots: View {
    let points: [CGPoint]
    let unit: CGFloat
    let active: Bool

    var body: some View {
        Canvas { ctx, _ in
            guard points.count > 1 else { return }
            let baseR = unit * 0.013
            let n = points.count
            for (i, p) in points.enumerated() {
                let f = Double(i) / Double(max(1, n - 1))
                // Dots fade & shrink toward the landing for a "lead" look.
                let r = baseR * (1.0 - 0.45 * f)
                let alpha = active ? (0.85 - 0.5 * f) : 0.18
                let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
                let color = HoldDragSlingshotAimView.glow.opacity(max(0.08, alpha))
                ctx.fill(Path(ellipseIn: rect), with: .color(color))
            }
            // Landing marker.
            if active, let last = points.last {
                let r = unit * 0.03
                let ring = Path(ellipseIn: CGRect(x: last.x - r, y: last.y - r,
                                                  width: r * 2, height: r * 2))
                ctx.stroke(ring, with: .color(HoldDragSlingshotAimView.warm.opacity(0.7)),
                           lineWidth: unit * 0.008)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Aim guide

private struct AimGuide: View {
    let origin: CGPoint
    let pull: CGSize
    let strength: CGFloat
    let unit: CGFloat

    var body: some View {
        let endX = origin.x + pull.width
        let endY = origin.y + pull.height
        Path { p in
            p.move(to: origin)
            p.addLine(to: CGPoint(x: endX, y: endY))
        }
        .stroke(
            HoldDragSlingshotAimView.warm.opacity(0.25 + Double(strength) * 0.5),
            style: StrokeStyle(lineWidth: max(1, unit * 0.012),
                               lineCap: .round, dash: [unit * 0.03, unit * 0.025])
        )
        .opacity(strength > 0.01 ? 1 : 0)
        .allowsHitTesting(false)
    }
}

// MARK: - Ball

private struct Ball: View {
    let unit: CGFloat

    var body: some View {
        let d = unit * 0.104
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color(red: 1.0, green: 0.95, blue: 0.82),
                             HoldDragSlingshotAimView.warm,
                             Color(red: 0.85, green: 0.40, blue: 0.16)],
                    center: UnitPoint(x: 0.35, y: 0.3),
                    startRadius: 0, endRadius: d * 0.7
                )
            )
            .overlay(
                Circle().stroke(Color.white.opacity(0.35), lineWidth: max(0.5, unit * 0.004))
            )
            .frame(width: d, height: d)
    }
}

// MARK: - Ground

private struct GroundView: View {
    let y: CGFloat
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            Path { p in
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: width, y: y))
            }
            .stroke(
                LinearGradient(
                    colors: [HoldDragSlingshotAimView.glow.opacity(0.0),
                             HoldDragSlingshotAimView.glow.opacity(0.55),
                             HoldDragSlingshotAimView.glow.opacity(0.0)],
                    startPoint: .leading, endPoint: .trailing
                ),
                lineWidth: 1.5
            )

            // Soft fade beneath the line for depth.
            LinearGradient(
                colors: [HoldDragSlingshotAimView.glow.opacity(0.10),
                         Color.clear],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 24)
            .offset(y: y)
        }
        .allowsHitTesting(false)
    }
}
