// catalog-id: btn-fuse-spark
import SwiftUI

// MARK: - Fuse Spark
// A long-press lights a fuse that burns along the button's perimeter with a
// traveling spark + sputtering particles + trailing smoke, detonating the
// action when the burn reaches the end. Pure SwiftUI, iOS 17.
//
// demo == true  -> a self-driving TimelineView loop auto-burns the fuse,
//                  detonates, rests, and repeats on a ~3s cadence.
// demo == false -> a real interactive hold: a DragGesture(minimumDistance: 0)
//                  burns the fuse while held and lets it fizzle back on early
//                  release; reaching the end fires the detonation.

struct FuseSparkView: View {
    var demo: Bool = false

    // Interactive (demo == false) state.
    @State private var progress: CGFloat = 0          // 0...1 burnt fraction
    @State private var isPressing: Bool = false
    @State private var didFire: Bool = false
    @State private var detonation: CGFloat = 0          // 0...1 burst envelope
    @State private var lastTick: Date? = nil
    @State private var fireCount: Int = 0               // sensoryFeedback trigger
    @State private var smoke: [FuseSparkView_SmokeParticle] = []
    @State private var burst: [FuseSparkView_BurstParticle] = []
    @State private var emitAccumulator: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                FuseSparkView_FuseBody(
                    size: size,
                    progress: demo ? 0 : progress,   // demo path drives its own progress
                    detonation: demo ? 0 : detonation,
                    isPressing: demo ? false : isPressing,
                    smoke: demo ? [] : smoke,
                    burst: demo ? [] : burst,
                    demo: demo
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .modifier(FuseSparkView_InteractiveDriver(
                demo: demo,
                size: size,
                progress: $progress,
                isPressing: $isPressing,
                didFire: $didFire,
                detonation: $detonation,
                lastTick: $lastTick,
                fireCount: $fireCount,
                smoke: $smoke,
                burst: $burst,
                emitAccumulator: $emitAccumulator
            ))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Interactive driver (demo == false)

private struct FuseSparkView_InteractiveDriver: ViewModifier {
    let demo: Bool
    let size: CGSize

    @Binding var progress: CGFloat
    @Binding var isPressing: Bool
    @Binding var didFire: Bool
    @Binding var detonation: CGFloat
    @Binding var lastTick: Date?
    @Binding var fireCount: Int
    @Binding var smoke: [FuseSparkView_SmokeParticle]
    @Binding var burst: [FuseSparkView_BurstParticle]
    @Binding var emitAccumulator: CGFloat

    func body(content: Content) -> some View {
        if demo {
            content
        } else {
            content
                .overlay {
                    // Hidden timeline that integrates dt to drive the burn.
                    TimelineView(.animation) { timeline in
                        Color.clear
                            .onChange(of: timeline.date) { _, newDate in
                                step(to: newDate)
                            }
                    }
                    .allowsHitTesting(false)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !didFire { isPressing = true }
                        }
                        .onEnded { _ in
                            isPressing = false
                        }
                )
                .sensoryFeedback(.success, trigger: fireCount)
        }
    }

    private func step(to date: Date) {
        guard let last = lastTick else {
            lastTick = date
            return
        }
        let dt = CGFloat(max(0, min(0.05, date.timeIntervalSince(last))))
        lastTick = date
        guard dt > 0 else { return }

        let perimeter = FuseSparkView_FusePath.path(in: size)
        let sparkPoint = FuseSparkView_FusePath.point(on: perimeter, at: progress, in: size)

        if didFire {
            // Detonation envelope rises fast then eases away; auto-reset.
            detonation = min(1, detonation + dt / 0.45)
            updateParticles(dt: dt, sparkPoint: sparkPoint, emitSmoke: false)
            if detonation >= 1 && burst.allSatisfy({ $0.life <= 0 }) && smoke.isEmpty {
                reset()
            }
            return
        }

        if isPressing {
            progress = min(1, progress + dt / 2.0)   // ~2s to detonate
            emitSmokeTrail(dt: dt, at: sparkPoint)
            if progress >= 1 {
                fire(at: sparkPoint)
            }
        } else if progress > 0 {
            progress = max(0, progress - dt / 0.6)    // fizzle back ~0.6s
            emitSmokeTrail(dt: dt * 0.4, at: sparkPoint)
        }
        updateParticles(dt: dt, sparkPoint: sparkPoint, emitSmoke: false)
    }

    private func fire(at point: CGPoint) {
        didFire = true
        detonation = 0
        fireCount &+= 1
        spawnBurst(at: point)
    }

    private func reset() {
        didFire = false
        isPressing = false
        progress = 0
        detonation = 0
        smoke.removeAll()
        burst.removeAll()
        emitAccumulator = 0
    }

    private func emitSmokeTrail(dt: CGFloat, at point: CGPoint) {
        emitAccumulator += dt
        let interval: CGFloat = 0.045
        while emitAccumulator >= interval {
            emitAccumulator -= interval
            if smoke.count < 24 {
                smoke.append(FuseSparkView_SmokeParticle.spawn(at: point))
            }
        }
    }

    private func spawnBurst(at point: CGPoint) {
        let count = 22
        for i in 0..<count {
            burst.append(FuseSparkView_BurstParticle.spawn(at: point, index: i, total: count))
        }
    }

    private func updateParticles(dt: CGFloat, sparkPoint: CGPoint, emitSmoke: Bool) {
        for i in smoke.indices { smoke[i].update(dt: dt) }
        smoke.removeAll { $0.life <= 0 }
        for i in burst.indices { burst[i].update(dt: dt) }
        burst.removeAll { $0.life <= 0 }
    }
}

// MARK: - Rendered button body

private struct FuseSparkView_FuseBody: View {
    let size: CGSize
    let progress: CGFloat
    let detonation: CGFloat
    let isPressing: Bool
    let smoke: [FuseSparkView_SmokeParticle]
    let burst: [FuseSparkView_BurstParticle]
    let demo: Bool

    var body: some View {
        if demo {
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let loop = demoLoop(t)
                render(progress: loop.progress,
                       detonation: loop.detonation,
                       pressing: loop.progress > 0 && loop.detonation == 0,
                       smoke: loop.smoke,
                       burst: loop.burst)
            }
        } else {
            render(progress: progress,
                   detonation: detonation,
                   pressing: isPressing,
                   smoke: smoke,
                   burst: burst)
        }
    }

    // Stateless ~3s sawtooth used in demo mode.
    private func demoLoop(_ time: TimeInterval) -> FuseSparkView_DemoFrame {
        let period: Double = 3.1
        let phase = time.truncatingRemainder(dividingBy: period)
        let burnDur: Double = 2.0
        let detoDur: Double = 0.5
        var progress: CGFloat = 0
        var detonation: CGFloat = 0

        if phase < burnDur {
            progress = CGFloat(phase / burnDur)
        } else if phase < burnDur + detoDur {
            progress = 1
            detonation = CGFloat((phase - burnDur) / detoDur)
        } else {
            progress = 0
            detonation = 0
        }

        let perimeter = FuseSparkView_FusePath.path(in: size)
        let sparkPoint = FuseSparkView_FusePath.point(on: perimeter, at: progress, in: size)

        // Deterministic smoke trail behind the spark.
        var smoke: [FuseSparkView_SmokeParticle] = []
        if phase < burnDur {
            for i in 0..<8 {
                let back = progress - CGFloat(i) * 0.025
                guard back > 0 else { continue }
                let p = FuseSparkView_FusePath.point(on: perimeter, at: back, in: size)
                let age = CGFloat(i) / 8.0
                smoke.append(FuseSparkView_SmokeParticle.deterministic(at: p, age: age, seed: i))
            }
        }

        // Deterministic detonation burst.
        var burst: [FuseSparkView_BurstParticle] = []
        if detonation > 0 {
            let count = 20
            for i in 0..<count {
                burst.append(FuseSparkView_BurstParticle.deterministic(
                    at: sparkPoint, index: i, total: count, t: detonation))
            }
        }
        return FuseSparkView_DemoFrame(progress: progress, detonation: detonation,
                         smoke: smoke, burst: burst)
    }

    @ViewBuilder
    private func render(progress: CGFloat,
                        detonation: CGFloat,
                        pressing: Bool,
                        smoke: [FuseSparkView_SmokeParticle],
                        burst: [FuseSparkView_BurstParticle]) -> some View {
        let perimeter = FuseSparkView_FusePath.path(in: size)
        let sparkPoint = FuseSparkView_FusePath.point(on: perimeter, at: progress, in: size)
        let pop: CGFloat = 1 + detonationPop(detonation)
        let flash = detonationFlash(detonation)

        ZStack {
            // Button plate.
            FuseSparkView_FacePlate(size: size, pressing: pressing, flash: flash)
                .scaleEffect(pop)

            // Unlit fuse cord (always visible -> never blank).
            perimeter
                .stroke(unlitColor,
                        style: StrokeStyle(lineWidth: cordWidth, lineCap: .round))
                .scaleEffect(pop)

            // Charred / burnt trail.
            perimeter
                .trim(from: 0, to: max(0, progress))
                .stroke(charColor,
                        style: StrokeStyle(lineWidth: cordWidth * 0.85, lineCap: .round))
                .scaleEffect(pop)

            // Glowing hot edge just behind the spark.
            perimeter
                .trim(from: max(0, progress - 0.06), to: max(0, progress))
                .stroke(emberGradient,
                        style: StrokeStyle(lineWidth: cordWidth, lineCap: .round))
                .blur(radius: 1.2)
                .scaleEffect(pop)

            // Label.
            label(detonation: detonation)
                .scaleEffect(pop)

            // Particles (smoke + spark sputter + detonation burst) — one Canvas.
            particleCanvas(sparkPoint: sparkPoint,
                           progress: progress,
                           detonation: detonation,
                           smoke: smoke,
                           burst: burst)
                .allowsHitTesting(false)

            // Live spark head (glued to the trim end).
            if progress > 0 && progress < 1 {
                spark(at: sparkPoint)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func label(detonation: CGFloat) -> some View {
        let fired = detonation > 0.15
        Text(fired ? "FIRED" : "HOLD")
            .font(.system(size: max(11, min(size.height, size.width) * 0.16),
                          weight: .heavy, design: .rounded))
            .tracking(1.5)
            .foregroundStyle(
                fired
                ? Color(red: 1.0, green: 0.86, blue: 0.55)
                : Color(red: 0.92, green: 0.88, blue: 0.80)
            )
            .shadow(color: fired
                    ? Color(red: 1.0, green: 0.55, blue: 0.18).opacity(0.9)
                    : .black.opacity(0.4),
                    radius: fired ? 8 : 2)
    }

    // MARK: spark head

    @ViewBuilder
    private func spark(at point: CGPoint) -> some View {
        let core = max(4, min(size.width, size.height) * 0.05)
        ZStack {
            Circle()
                .fill(Color(red: 1.0, green: 0.74, blue: 0.30))
                .frame(width: core * 2.6, height: core * 2.6)
                .blur(radius: core * 0.9)
                .opacity(0.85)
            Circle()
                .fill(Color(red: 1.0, green: 0.95, blue: 0.78))
                .frame(width: core, height: core)
                .blur(radius: 0.5)
        }
        .position(point)
    }

    // MARK: particle canvas

    private func particleCanvas(sparkPoint: CGPoint,
                                progress: CGFloat,
                                detonation: CGFloat,
                                smoke: [FuseSparkView_SmokeParticle],
                                burst: [FuseSparkView_BurstParticle]) -> some View {
        Canvas { context, _ in
            drawSmoke(smoke, in: context)
            drawSputter(at: sparkPoint, progress: progress, in: context)
            drawBurst(burst, detonation: detonation, in: context)
        }
        .frame(width: size.width, height: size.height)
    }

    private func drawSmoke(_ smoke: [FuseSparkView_SmokeParticle], in context: GraphicsContext) {
        for p in smoke {
            let r = p.radius
            let rect = CGRect(x: p.position.x - r, y: p.position.y - r,
                              width: r * 2, height: r * 2)
            let gray = Color(red: 0.55, green: 0.53, blue: 0.50)
            context.fill(Circle().path(in: rect),
                         with: .color(gray.opacity(p.opacity)))
        }
    }

    private func drawSputter(at point: CGPoint,
                             progress: CGFloat,
                             in context: GraphicsContext) {
        guard progress > 0 && progress < 1 else { return }
        // A few deterministic sputter sparks flicking off the spark head.
        let t = progress * 137.0
        for i in 0..<4 {
            let a = Double(i) * 1.9 + Double(t)
            let dist = 4.0 + (sin(a * 3.1) * 0.5 + 0.5) * 7.0
            let dx = CGFloat(cos(a)) * CGFloat(dist)
            let dy = CGFloat(sin(a)) * CGFloat(dist) - 2
            let r = CGFloat(1.0 + (sin(a * 5) * 0.5 + 0.5) * 1.4)
            let pos = CGPoint(x: point.x + dx, y: point.y + dy)
            let rect = CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)
            let c = Color(red: 1.0, green: 0.78, blue: 0.36)
            context.fill(Circle().path(in: rect), with: .color(c.opacity(0.9)))
        }
    }

    private func drawBurst(_ burst: [FuseSparkView_BurstParticle],
                           detonation: CGFloat,
                           in context: GraphicsContext) {
        for p in burst {
            let r = p.radius
            let rect = CGRect(x: p.position.x - r, y: p.position.y - r,
                              width: r * 2, height: r * 2)
            let c = p.color
            context.fill(Circle().path(in: rect),
                         with: .color(c.opacity(p.opacity)))
        }
    }

    // MARK: visual helpers

    private var minSide: CGFloat { min(size.width, size.height) }
    private var cordWidth: CGFloat { max(2.5, minSide * 0.035) }

    private var unlitColor: Color {
        Color(red: 0.42, green: 0.34, blue: 0.26)
    }
    private var charColor: Color {
        Color(red: 0.12, green: 0.10, blue: 0.10)
    }
    private var emberGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.86, blue: 0.45),
                Color(red: 1.0, green: 0.45, blue: 0.12)
            ],
            startPoint: .leading, endPoint: .trailing)
    }

    private func detonationPop(_ d: CGFloat) -> CGFloat {
        // Pop UP then settle — never below 1.0 (never collapses).
        guard d > 0 else { return 0 }
        let env = sin(Double(d) * .pi)            // 0 -> 1 -> 0
        return CGFloat(env) * 0.12
    }

    private func detonationFlash(_ d: CGFloat) -> CGFloat {
        guard d > 0 else { return 0 }
        let env = sin(Double(min(1, d * 1.4)) * .pi)
        return CGFloat(max(0, env))
    }
}

// MARK: - Face plate

private struct FuseSparkView_FacePlate: View {
    let size: CGSize
    let pressing: Bool
    let flash: CGFloat

    var body: some View {
        let r = min(size.width, size.height) * 0.22
        RoundedRectangle(cornerRadius: r, style: .continuous)
            .fill(plateGradient)
            .overlay {
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .stroke(Color(red: 0.30, green: 0.24, blue: 0.18),
                            lineWidth: 1)
            }
            .overlay {
                // Detonation flash glow.
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .fill(Color(red: 1.0, green: 0.70, blue: 0.30))
                    .opacity(Double(flash) * 0.7)
                    .blur(radius: 6)
            }
            .shadow(color: Color(red: 1.0, green: 0.45, blue: 0.12)
                        .opacity(pressing ? 0.45 : 0.0),
                    radius: pressing ? 10 : 0)
    }

    private var plateGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.16, green: 0.13, blue: 0.10),
                Color(red: 0.10, green: 0.075, blue: 0.055)
            ],
            startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Fuse path geometry

private enum FuseSparkView_FusePath {
    /// Inset rounded-rect perimeter that the fuse burns along.
    static func path(in size: CGSize) -> Path {
        let inset = max(3, min(size.width, size.height) * 0.06)
        let rect = CGRect(x: inset, y: inset,
                          width: max(1, size.width - inset * 2),
                          height: max(1, size.height - inset * 2))
        let radius = min(rect.width, rect.height) * 0.22
        return Path(roundedRect: rect, cornerRadius: radius)
    }

    /// Point exactly on the trim end — uses the SAME trimming as `.trim`,
    /// so the spark stays glued to the burnt edge around the corners.
    static func point(on perimeter: Path, at progress: CGFloat, in size: CGSize) -> CGPoint {
        let p = max(0, min(1, progress))
        if p <= 0.0001 {
            return startPoint(of: perimeter, in: size)
        }
        let trimmed = perimeter.trimmedPath(from: 0, to: p)
        if let pt = trimmed.currentPoint {
            return pt
        }
        return startPoint(of: perimeter, in: size)
    }

    private static func startPoint(of perimeter: Path, in size: CGSize) -> CGPoint {
        // Tiny trim gives the true starting point of the path.
        let trimmed = perimeter.trimmedPath(from: 0, to: 0.001)
        return trimmed.currentPoint ?? CGPoint(x: size.width / 2, y: size.height * 0.06)
    }
}

// MARK: - Particle models

private struct FuseSparkView_SmokeParticle {
    var position: CGPoint
    var velocity: CGVector
    var life: CGFloat        // 1 -> 0
    var maxLife: CGFloat
    var baseRadius: CGFloat

    var opacity: Double {
        Double(max(0, life / maxLife)) * 0.35
    }
    var radius: CGFloat {
        let grow = 1 + (1 - life / maxLife) * 1.6
        return baseRadius * grow
    }

    mutating func update(dt: CGFloat) {
        position.x += velocity.dx * dt
        position.y += velocity.dy * dt
        velocity.dy -= 6 * dt   // drift up
        velocity.dx *= (1 - 0.6 * dt)
        life -= dt
    }

    static func spawn(at point: CGPoint) -> FuseSparkView_SmokeParticle {
        let jx = CGFloat.random(in: -4...4)
        let jy = CGFloat.random(in: -3...1)
        return FuseSparkView_SmokeParticle(
            position: CGPoint(x: point.x + jx, y: point.y + jy),
            velocity: CGVector(dx: CGFloat.random(in: -8...8),
                               dy: CGFloat.random(in: -22 ... -8)),
            life: 0.8, maxLife: 0.8,
            baseRadius: CGFloat.random(in: 1.6...3.0))
    }

    /// Deterministic variant for the demo loop (no randomness per frame).
    static func deterministic(at point: CGPoint, age: CGFloat, seed: Int) -> FuseSparkView_SmokeParticle {
        let s = CGFloat(seed)
        let jx = CGFloat(sin(Double(s) * 2.3)) * 4
        let rise = age * 18
        var p = FuseSparkView_SmokeParticle(
            position: CGPoint(x: point.x + jx, y: point.y - rise),
            velocity: .zero,
            life: 1 - age, maxLife: 1,
            baseRadius: 1.8 + age * 1.5)
        p.life = max(0.01, 1 - age)
        return p
    }
}

private struct FuseSparkView_BurstParticle {
    var position: CGPoint
    var velocity: CGVector
    var life: CGFloat
    var maxLife: CGFloat
    var baseRadius: CGFloat
    var color: Color

    var opacity: Double { Double(max(0, life / maxLife)) }
    var radius: CGFloat { baseRadius * max(0.2, life / maxLife) }

    mutating func update(dt: CGFloat) {
        position.x += velocity.dx * dt
        position.y += velocity.dy * dt
        velocity.dy += 80 * dt          // gravity
        velocity.dx *= (1 - 0.9 * dt)
        velocity.dy *= (1 - 0.9 * dt)
        life -= dt
    }

    static func spawn(at point: CGPoint, index: Int, total: Int) -> FuseSparkView_BurstParticle {
        let angle = (Double(index) / Double(total)) * 2 * .pi
                    + Double.random(in: -0.3...0.3)
        let speed = CGFloat.random(in: 60...170)
        return FuseSparkView_BurstParticle(
            position: point,
            velocity: CGVector(dx: CGFloat(cos(angle)) * speed,
                               dy: CGFloat(sin(angle)) * speed),
            life: CGFloat.random(in: 0.4...0.7),
            maxLife: 0.7,
            baseRadius: CGFloat.random(in: 1.5...3.5),
            color: Self.emberColor())
    }

    /// Deterministic radial burst for the demo loop, parameterized by t (0..1).
    static func deterministic(at point: CGPoint, index: Int, total: Int, t: CGFloat) -> FuseSparkView_BurstParticle {
        let angle = (Double(index) / Double(total)) * 2 * .pi
        let speed: CGFloat = 60 + CGFloat(index % 5) * 22
        let dist = speed * t * 0.9
        let pos = CGPoint(
            x: point.x + CGFloat(cos(angle)) * dist,
            y: point.y + CGFloat(sin(angle)) * dist + (t * t) * 30)
        var p = FuseSparkView_BurstParticle(
            position: pos,
            velocity: .zero,
            life: max(0.01, 1 - t),
            maxLife: 1,
            baseRadius: 2.8,
            color: Self.emberColor(index: index))
        p.baseRadius = 2.8
        return p
    }

    private static func emberColor(index: Int = 0) -> Color {
        let warm = index % 3
        switch warm {
        case 0: return Color(red: 1.0, green: 0.88, blue: 0.55)
        case 1: return Color(red: 1.0, green: 0.60, blue: 0.20)
        default: return Color(red: 1.0, green: 0.42, blue: 0.16)
        }
    }
}

private struct FuseSparkView_DemoFrame {
    var progress: CGFloat
    var detonation: CGFloat
    var smoke: [FuseSparkView_SmokeParticle]
    var burst: [FuseSparkView_BurstParticle]
}
