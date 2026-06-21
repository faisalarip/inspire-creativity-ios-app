// catalog-id: ges-fling-pinball-bumpers
import SwiftUI

// MARK: - FlingPinballBumpersView
// Fling a ball into a field of bumpers. Each hit reflects the ball with a touch
// of extra energy (restitution > 1) and flashes / scale-pops the bumper. The ball
// ricochets, decays with friction, and (interactively) you can fling it with a drag.
// demo == true  -> self-playing: auto re-launches the ball every few seconds.
// demo == false -> drag to fling; physics keeps coasting between flings.
struct FlingPinballBumpersView: View {
    var demo: Bool = false

    // MARK: Simulation state
    @State private var sim = PinballSim()
    @State private var lastTick: Date? = nil
    @State private var lastLaunch: Date? = nil
    @State private var configuredSize: CGSize = .zero
    @State private var hitCount: Int = 0
    @State private var dragStart: CGPoint? = nil

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { context in
                Canvas { ctx, _ in
                    drawField(into: ctx, size: geo.size, now: context.date)
                } symbols: {
                    // no external symbols needed
                }
                .contentShape(Rectangle())
                .gesture(flingGesture(size: geo.size))
                .onChange(of: context.date) { _, now in
                    advance(now: now, size: geo.size)
                }
            }
            .onChange(of: geo.size) { _, newSize in
                configureIfNeeded(size: newSize)
            }
            .onAppear { configureIfNeeded(size: geo.size) }
        }
        .background(boardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: hitCount)
    }

    // MARK: Background
    private var boardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.10),
                        Color(red: 0.10, green: 0.08, blue: 0.18)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    // MARK: Configuration (first valid frame only)
    private func configureIfNeeded(size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        guard size != configuredSize else { return }
        configuredSize = size
        sim.configure(size: size)
        if lastLaunch == nil {
            // Seed an initial launch so demo never starts blank / static.
            launch(in: size, seededByTime: true)
        } else {
            // On resize, keep the ball but re-clamp it into the new bounds.
            sim.clampIntoBounds(size: size)
        }
    }

    // MARK: Per-frame advance
    private func advance(now: Date, size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        guard sim.isConfigured else {
            configureIfNeeded(size: size)
            lastTick = now
            return
        }

        let previous: Date = lastTick ?? now
        lastTick = now
        var dt: Double = now.timeIntervalSince(previous)
        if dt <= 0 { return }
        // Clamp dt so a stalled frame can't teleport the ball through a bumper.
        dt = min(dt, 1.0 / 30.0)

        // Demo: time-based re-launch keeps it alive regardless of where the ball rests.
        if demo {
            let elapsed: Double = now.timeIntervalSince(lastLaunch ?? now)
            if elapsed > 3.4 {
                launch(in: size, seededByTime: true)
            }
        }

        let hits: Int = sim.step(dt: dt, size: size, now: now)
        if hits > 0 {
            hitCount += hits
        }
    }

    // MARK: Launch helpers
    private func launch(in size: CGSize, seededByTime: Bool) {
        let now = Date()
        lastLaunch = now
        sim.resetBall(size: size, now: now, seeded: seededByTime)
    }

    private func flingGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStart == nil {
                    dragStart = value.startLocation
                    // Park the ball under the finger while aiming.
                    sim.holdBall(at: value.location, size: size)
                } else {
                    sim.holdBall(at: value.location, size: size)
                }
            }
            .onEnded { value in
                dragStart = nil
                // velocity is CGSize, points/sec, available iOS 17+.
                let v: CGSize = value.velocity
                sim.flingBall(from: value.location, velocity: v, size: size)
                lastLaunch = Date()
            }
    }

    // MARK: Drawing
    private func drawField(into ctx: GraphicsContext, size: CGSize, now: Date) {
        guard sim.isConfigured else { return }
        drawWalls(into: ctx, size: size)
        for bumper in sim.bumpers {
            drawBumper(bumper, into: ctx, size: size, now: now)
        }
        drawBall(into: ctx, size: size)
    }

    private func drawWalls(into ctx: GraphicsContext, size: CGSize) {
        let inset: CGFloat = wallInset(size)
        let rect = CGRect(
            x: inset, y: inset,
            width: size.width - inset * 2,
            height: size.height - inset * 2
        )
        let path = Path(roundedRect: rect, cornerRadius: 14, style: .continuous)
        ctx.stroke(
            path,
            with: .color(Color(red: 0.30, green: 0.34, blue: 0.55).opacity(0.55)),
            lineWidth: max(1.0, size.width * 0.012)
        )
    }

    private func drawBumper(_ bumper: Bumper, into ctx: GraphicsContext, size: CGSize, now: Date) {
        let center = bumper.center(in: size)
        let radius: CGFloat = bumper.radius(in: size)
        let pop: CGFloat = bumper.popScale(now: now)
        let glow: Double = bumper.glow(now: now)
        let r: CGFloat = radius * pop

        let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)

        // Outer halo when freshly hit.
        if glow > 0.02 {
            let haloR: CGFloat = r * 1.55
            let haloRect = CGRect(
                x: center.x - haloR, y: center.y - haloR,
                width: haloR * 2, height: haloR * 2
            )
            ctx.fill(
                Circle().path(in: haloRect),
                with: .color(bumper.tint.color.opacity(0.35 * glow))
            )
        }

        // Body with a radial-ish gradient feel (two stacked fills).
        let base: RGB = bumper.tint
        let lit: RGB = base.mix(with: .white, amount: 0.55 * glow + 0.10)
        ctx.fill(Circle().path(in: rect), with: .color(lit.color))

        let innerR: CGFloat = r * 0.62
        let innerRect = CGRect(
            x: center.x - innerR, y: center.y - innerR,
            width: innerR * 2, height: innerR * 2
        )
        ctx.fill(
            Circle().path(in: innerRect),
            with: .color(base.mix(with: .black, amount: 0.25).color)
        )

        // Bright center cap.
        let capR: CGFloat = r * 0.30
        let capRect = CGRect(
            x: center.x - capR, y: center.y - capR,
            width: capR * 2, height: capR * 2
        )
        ctx.fill(
            Circle().path(in: capRect),
            with: .color(RGB.white.mix(with: base, amount: 0.30).color.opacity(0.85))
        )

        // Rim ring.
        ctx.stroke(
            Circle().path(in: rect),
            with: .color(Color.white.opacity(0.25 + 0.5 * glow)),
            lineWidth: max(1.0, r * 0.07)
        )
    }

    private func drawBall(into ctx: GraphicsContext, size: CGSize) {
        let radius: CGFloat = sim.ballRadius(in: size)
        let p = sim.ball
        // Contact shadow.
        let shadowRect = CGRect(
            x: p.x - radius * 1.05,
            y: p.y - radius * 0.85 + radius * 0.6,
            width: radius * 2.1,
            height: radius * 1.7
        )
        ctx.fill(Ellipse().path(in: shadowRect), with: .color(Color.black.opacity(0.30)))

        let rect = CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)
        // Steel body.
        ctx.fill(
            Circle().path(in: rect),
            with: .color(Color(red: 0.78, green: 0.82, blue: 0.90))
        )
        // Shading underside.
        let lowR: CGFloat = radius * 0.85
        let lowRect = CGRect(
            x: p.x - lowR + radius * 0.10,
            y: p.y - lowR + radius * 0.25,
            width: lowR * 2, height: lowR * 2
        )
        ctx.fill(
            Circle().path(in: lowRect),
            with: .color(Color(red: 0.45, green: 0.50, blue: 0.62).opacity(0.65))
        )
        // Specular highlight.
        let hiR: CGFloat = radius * 0.34
        let hiRect = CGRect(
            x: p.x - radius * 0.40 - hiR * 0.5,
            y: p.y - radius * 0.40 - hiR * 0.5,
            width: hiR * 2, height: hiR * 2
        )
        ctx.fill(Circle().path(in: hiRect), with: .color(Color.white.opacity(0.9)))
    }

    // MARK: Layout helpers
    private func wallInset(_ size: CGSize) -> CGFloat {
        return min(size.width, size.height) * 0.04
    }
}

// MARK: - Self-contained RGB color (no UIKit dependency)
private struct RGB {
    var r: Double
    var g: Double
    var b: Double

    var color: Color { Color(red: r, green: g, blue: b) }

    static let white = RGB(r: 1, g: 1, b: 1)
    static let black = RGB(r: 0, g: 0, b: 0)

    func mix(with other: RGB, amount: Double) -> RGB {
        let t = max(0.0, min(1.0, amount))
        return RGB(
            r: r + (other.r - r) * t,
            g: g + (other.g - g) * t,
            b: b + (other.b - b) * t
        )
    }
}

// MARK: - Bumper model
private struct Bumper: Identifiable {
    let id: Int
    var nx: CGFloat          // normalized center x [0,1]
    var ny: CGFloat          // normalized center y [0,1]
    var nr: CGFloat          // normalized radius (relative to min dimension)
    var tint: RGB
    var lastHit: Date? = nil

    func center(in size: CGSize) -> CGPoint {
        CGPoint(x: nx * size.width, y: ny * size.height)
    }

    func radius(in size: CGSize) -> CGFloat {
        nr * min(size.width, size.height)
    }

    // Brief spring-like scale pop after a hit (decays over ~0.45s).
    func popScale(now: Date) -> CGFloat {
        guard let hit = lastHit else { return 1.0 }
        let t: Double = now.timeIntervalSince(hit)
        if t < 0 || t > 0.5 { return 1.0 }
        let decay: Double = exp(-t * 9.0)
        let wobble: Double = sin(t * 26.0)
        return 1.0 + CGFloat(0.22 * decay * wobble + 0.10 * decay)
    }

    // Flash brightness after a hit (decays over ~0.35s).
    func glow(now: Date) -> Double {
        guard let hit = lastHit else { return 0 }
        let t: Double = now.timeIntervalSince(hit)
        if t < 0 || t > 0.5 { return 0 }
        return exp(-t * 8.0)
    }
}

// MARK: - Pinball simulation
private struct PinballSim {
    var ball: CGPoint = .zero
    var velocity: CGSize = .zero      // points / second
    var bumpers: [Bumper] = []
    var isConfigured: Bool = false
    var held: Bool = false

    // Tunable constants (relative to min dimension where spatial).
    private let ballNR: CGFloat = 0.052
    private let friction: Double = 0.55          // per-second velocity retention base
    private let restitution: Double = 1.08       // > 1 adds energy on bumper hits
    private let wallRestitution: Double = 0.86
    private let maxSpeedFactor: Double = 3.2     // * minDim per second (anti-runaway)
    private let minLaunchFactor: Double = 1.6

    func ballRadius(in size: CGSize) -> CGFloat {
        ballNR * min(size.width, size.height)
    }

    private func wallInset(_ size: CGSize) -> CGFloat {
        min(size.width, size.height) * 0.04
    }

    mutating func configure(size: CGSize) {
        bumpers = Self.makeBumpers()
        if !isConfigured {
            ball = CGPoint(x: size.width * 0.5, y: size.height * 0.72)
            velocity = .zero
        }
        isConfigured = true
    }

    private static func makeBumpers() -> [Bumper] {
        // Normalized layout — looks balanced in a tile and a big detail view.
        let tintA = RGB(r: 0.96, g: 0.36, b: 0.45)
        let tintB = RGB(r: 0.36, g: 0.72, b: 0.98)
        let tintC = RGB(r: 0.99, g: 0.78, b: 0.30)
        let tintD = RGB(r: 0.55, g: 0.92, b: 0.62)
        return [
            Bumper(id: 0, nx: 0.30, ny: 0.26, nr: 0.105, tint: tintA),
            Bumper(id: 1, nx: 0.70, ny: 0.26, nr: 0.105, tint: tintB),
            Bumper(id: 2, nx: 0.50, ny: 0.45, nr: 0.115, tint: tintC),
            Bumper(id: 3, nx: 0.25, ny: 0.60, nr: 0.090, tint: tintD),
            Bumper(id: 4, nx: 0.75, ny: 0.60, nr: 0.090, tint: tintD),
            Bumper(id: 5, nx: 0.50, ny: 0.78, nr: 0.080, tint: tintA)
        ]
    }

    private func maxSpeed(in size: CGSize) -> Double {
        maxSpeedFactor * Double(min(size.width, size.height))
    }

    mutating func clampIntoBounds(size: CGSize) {
        let r: CGFloat = ballRadius(in: size)
        let inset: CGFloat = wallInset(size)
        ball.x = min(max(ball.x, inset + r), size.width - inset - r)
        ball.y = min(max(ball.y, inset + r), size.height - inset - r)
    }

    mutating func resetBall(size: CGSize, now: Date, seeded: Bool) {
        held = false
        ball = CGPoint(x: size.width * 0.5, y: size.height * 0.80)
        let minDim = Double(min(size.width, size.height))
        if seeded {
            // Aim generally upward into the bumper field, with horizontal variety.
            let spread: Double = Double.random(in: -0.5 ... 0.5)
            let speed: Double = minDim * Double.random(in: 1.9 ... 2.6)
            let angle: Double = (-Double.pi / 2) + spread
            velocity = CGSize(width: cos(angle) * speed, height: sin(angle) * speed)
        }
    }

    mutating func holdBall(at point: CGPoint, size: CGSize) {
        held = true
        velocity = .zero
        ball = point
        clampIntoBounds(size: size)
    }

    mutating func flingBall(from point: CGPoint, velocity v: CGSize, size: CGSize) {
        held = false
        ball = point
        clampIntoBounds(size: size)
        var vx = Double(v.width)
        var vy = Double(v.height)
        let minDim = Double(min(size.width, size.height))
        let minLaunch = minLaunchFactor * minDim
        let speed = (vx * vx + vy * vy).squareRoot()
        if speed < minLaunch {
            // Give a gentle default shove upward if the flick was tiny.
            if speed < 1 {
                vx = 0
                vy = -minLaunch
            } else {
                let scale = minLaunch / speed
                vx *= scale
                vy *= scale
            }
        }
        velocity = CGSize(width: vx, height: vy)
        clampSpeed(in: size)
    }

    private mutating func clampSpeed(in size: CGSize) {
        let limit = maxSpeed(in: size)
        let vx = Double(velocity.width)
        let vy = Double(velocity.height)
        let s = (vx * vx + vy * vy).squareRoot()
        if s > limit, s > 0 {
            let k = limit / s
            velocity = CGSize(width: vx * k, height: vy * k)
        }
    }

    // Returns number of bumper hits this frame (for haptics).
    mutating func step(dt: Double, size: CGSize, now: Date) -> Int {
        if held { return 0 }
        var hits = 0
        let substeps = 3
        let h = dt / Double(substeps)
        for _ in 0..<substeps {
            hits += integrate(h: h, size: size, now: now)
        }
        // Friction (frame-rate independent exponential-ish decay).
        let retain = pow(friction, dt)
        velocity = CGSize(width: Double(velocity.width) * retain,
                          height: Double(velocity.height) * retain)
        // Settle to rest if very slow to avoid endless micro-drift.
        let minDim = Double(min(size.width, size.height))
        let restThreshold = minDim * 0.06
        let sp = (Double(velocity.width) * Double(velocity.width)
                  + Double(velocity.height) * Double(velocity.height)).squareRoot()
        if sp < restThreshold {
            velocity = CGSize(width: Double(velocity.width) * 0.85,
                              height: Double(velocity.height) * 0.85)
        }
        return hits
    }

    private mutating func integrate(h: Double, size: CGSize, now: Date) -> Int {
        ball.x += CGFloat(Double(velocity.width) * h)
        ball.y += CGFloat(Double(velocity.height) * h)
        var hits = 0
        hits += resolveWalls(size: size)
        hits += resolveBumpers(size: size, now: now)
        clampSpeed(in: size)
        return hits
    }

    private mutating func resolveWalls(size: CGSize) -> Int {
        let r: CGFloat = ballRadius(in: size)
        let inset: CGFloat = wallInset(size)
        let left = inset + r
        let right = size.width - inset - r
        let top = inset + r
        let bottom = size.height - inset - r
        var bounced = false

        if ball.x < left {
            ball.x = left
            velocity.width = abs(velocity.width) * CGFloat(wallRestitution)
            bounced = true
        } else if ball.x > right {
            ball.x = right
            velocity.width = -abs(velocity.width) * CGFloat(wallRestitution)
            bounced = true
        }
        if ball.y < top {
            ball.y = top
            velocity.height = abs(velocity.height) * CGFloat(wallRestitution)
            bounced = true
        } else if ball.y > bottom {
            ball.y = bottom
            velocity.height = -abs(velocity.height) * CGFloat(wallRestitution)
            bounced = true
        }
        return bounced ? 0 : 0   // wall bounces don't fire bumper haptics
    }

    private mutating func resolveBumpers(size: CGSize, now: Date) -> Int {
        let br: CGFloat = ballRadius(in: size)
        var hits = 0
        for i in bumpers.indices {
            let c = bumpers[i].center(in: size)
            let rad = bumpers[i].radius(in: size)
            let dx = Double(ball.x - c.x)
            let dy = Double(ball.y - c.y)
            let dist = (dx * dx + dy * dy).squareRoot()
            let minDist = Double(br + rad)
            if dist < minDist && dist > 0.0001 {
                // Push ball out along the contact normal.
                let nx = dx / dist
                let ny = dy / dist
                let overlap = minDist - dist
                ball.x += CGFloat(nx * overlap)
                ball.y += CGFloat(ny * overlap)

                // Reflect velocity about the normal, add restitution energy.
                let vx = Double(velocity.width)
                let vy = Double(velocity.height)
                let vDotN = vx * nx + vy * ny
                if vDotN < 0 {
                    let rx = vx - 2 * vDotN * nx
                    let ry = vy - 2 * vDotN * ny
                    velocity = CGSize(width: rx * restitution, height: ry * restitution)
                    // Add a small radial kick so it feels lively even on grazes.
                    let minDim = Double(min(size.width, size.height))
                    let kick = minDim * 0.20
                    velocity.width += CGFloat(nx * kick)
                    velocity.height += CGFloat(ny * kick)
                    clampSpeed(in: size)
                    bumpers[i].lastHit = now
                    hits += 1
                }
            }
        }
        return hits
    }
}
