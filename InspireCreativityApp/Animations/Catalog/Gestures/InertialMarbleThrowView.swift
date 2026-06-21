// catalog-id: ges-inertial-marble-throw
import SwiftUI

// MARK: - Inertial Marble Tray
// Fling a marble across a bordered tray; it coasts with friction, banks off the
// walls with energy loss, and rolls to a stop, casting a moving contact shadow.
//
// demo == true  -> self-driving loop: auto-launches with a seeded velocity,
//                  banks off the walls, decays to rest, then re-launches.
// demo == false -> interactive: DragGesture finger-follow, release seeds launch
//                  velocity from predictedEndTranslation.

struct InertialMarbleThrowView: View {
    var demo: Bool = false

    @State private var sim = MarbleSim()
    @State private var lastBounce: Int = 0

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let bounds = MarbleBounds(size: size, radius: marbleRadius(for: size))
                    drawTray(in: &context, size: size)
                    drawShadow(in: &context, bounds: bounds)
                    drawMarble(in: &context, bounds: bounds)
                }
                .onChange(of: timeline.date) { _, now in
                    sim.step(date: now, bounds: MarbleBounds(size: geo.size,
                                                             radius: marbleRadius(for: geo.size)),
                             demo: demo)
                    lastBounce = sim.bounceCount
                }
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(in: geo.size))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7),
                         trigger: demo ? 0 : lastBounce)
    }

    // MARK: Sizing

    private func marbleRadius(for size: CGSize) -> CGFloat {
        let minSide = min(size.width, size.height)
        return max(7, minSide * 0.13)
    }

    // MARK: Gesture

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !demo else { return }
                let bounds = MarbleBounds(size: size, radius: marbleRadius(for: size))
                sim.beginDragIfNeeded(at: value.startLocation, bounds: bounds)
                sim.dragTo(value.location, bounds: bounds)
            }
            .onEnded { value in
                guard !demo else { return }
                let bounds = MarbleBounds(size: size, radius: marbleRadius(for: size))
                let predicted = value.predictedEndTranslation
                let current = value.translation
                let vx = (predicted.width - current.width)
                let vy = (predicted.height - current.height)
                sim.release(velocity: CGVector(dx: vx, dy: vy), bounds: bounds)
            }
    }

    // MARK: Drawing

    private func drawTray(in context: inout GraphicsContext, size: CGSize) {
        let inset: CGFloat = 4
        let rect = CGRect(x: inset, y: inset,
                          width: size.width - inset * 2,
                          height: size.height - inset * 2)
        let corner = min(rect.width, rect.height) * 0.16
        let shape = Path(roundedRect: rect, cornerRadius: corner)

        let floor = Gradient(colors: [
            Color(red: 0.10, green: 0.11, blue: 0.16),
            Color(red: 0.05, green: 0.05, blue: 0.09)
        ])
        context.fill(shape, with: .linearGradient(
            floor,
            startPoint: CGPoint(x: rect.minX, y: rect.minY),
            endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))

        // Inner rim highlight for a raised-tray feel.
        let rimColor = Color(red: 0.42, green: 0.46, blue: 0.58).opacity(0.55)
        context.stroke(shape, with: .color(rimColor), lineWidth: 2)

        let innerRect = rect.insetBy(dx: 3, dy: 3)
        let innerShape = Path(roundedRect: innerRect,
                              cornerRadius: max(0, corner - 3))
        context.stroke(innerShape,
                       with: .color(Color(red: 0.0, green: 0.0, blue: 0.0).opacity(0.35)),
                       lineWidth: 1.5)
    }

    private func drawShadow(in context: inout GraphicsContext, bounds: MarbleBounds) {
        let p = sim.displayPosition(in: bounds)
        let r = bounds.radius
        // Shadow drifts slightly below/right of the marble and softens with height-feel.
        let shadowRect = CGRect(x: p.x - r * 1.05 + 3,
                                y: p.y - r * 0.55 + r * 0.85,
                                width: r * 2.1,
                                height: r * 1.05)
        var shadowCtx = context
        shadowCtx.addFilter(.blur(radius: r * 0.35))
        shadowCtx.fill(Path(ellipseIn: shadowRect),
                       with: .color(Color(red: 0, green: 0, blue: 0).opacity(0.45)))
    }

    private func drawMarble(in context: inout GraphicsContext, bounds: MarbleBounds) {
        let p = sim.displayPosition(in: bounds)
        let r = bounds.radius
        let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
        let sphere = Path(ellipseIn: rect)

        // Body: cool glass marble with an off-center light center.
        let body = Gradient(stops: [
            .init(color: Color(red: 0.55, green: 0.78, blue: 0.95), location: 0.0),
            .init(color: Color(red: 0.24, green: 0.46, blue: 0.78), location: 0.45),
            .init(color: Color(red: 0.08, green: 0.16, blue: 0.36), location: 1.0)
        ])
        context.fill(sphere, with: .radialGradient(
            body,
            center: CGPoint(x: p.x - r * 0.32, y: p.y - r * 0.36),
            startRadius: 0,
            endRadius: r * 1.7))

        // Rim shade for volume.
        context.stroke(sphere,
                       with: .color(Color(red: 0, green: 0, blue: 0).opacity(0.35)),
                       lineWidth: max(1, r * 0.06))

        // Specular highlight.
        let hi = CGRect(x: p.x - r * 0.55, y: p.y - r * 0.62,
                        width: r * 0.7, height: r * 0.5)
        context.fill(Path(ellipseIn: hi),
                     with: .color(Color(red: 1, green: 1, blue: 1).opacity(0.85)))

        // Tiny secondary glint.
        let glint = CGRect(x: p.x + r * 0.2, y: p.y + r * 0.28,
                           width: r * 0.22, height: r * 0.18)
        context.fill(Path(ellipseIn: glint),
                     with: .color(Color(red: 1, green: 1, blue: 1).opacity(0.35)))
    }
}

// MARK: - Bounds helper

private struct MarbleBounds {
    let size: CGSize
    let radius: CGFloat

    // Playable rect (tray interior) the marble center is confined to.
    var inset: CGFloat { 7 + radius }
    var minX: CGFloat { inset }
    var maxX: CGFloat { max(inset, size.width - inset) }
    var minY: CGFloat { inset }
    var maxY: CGFloat { max(inset, size.height - inset) }
    var center: CGPoint { CGPoint(x: size.width / 2, y: size.height / 2) }
}

// MARK: - Inertial simulation (reference type: safe to mutate from onChange)

private final class MarbleSim {
    enum Phase { case idle, dragging, free }

    var position: CGPoint = .zero
    var velocity: CGVector = .zero
    var phase: Phase = .idle
    var bounceCount: Int = 0

    private var lastTick: Date?
    private var seeded = false
    private var restTimer: TimeInterval = 0      // time spent essentially at rest
    private var demoLaunchTimer: TimeInterval = 0 // safety re-launch guard

    private let friction: CGFloat = 1.6      // per-second velocity damping coefficient
    private let restitution: CGFloat = 0.72  // wall energy retained on bounce
    private let stopSpeed: CGFloat = 8       // px/s below which we consider "resting"

    // MARK: Step

    func step(date: Date, bounds: MarbleBounds, demo: Bool) {
        guard bounds.size.width > 1, bounds.size.height > 1 else { return }

        if !seeded {
            seeded = true
            position = bounds.center
            if demo { seedLaunch(in: bounds) } else { phase = .idle }
        }

        let dt = clampedDelta(to: date)
        guard dt > 0 else { return }

        if phase == .dragging {
            confine(to: bounds) // keep finger-following marble inside the tray
            return
        }

        integrate(dt: dt, bounds: bounds)

        let speed = hypot(velocity.dx, velocity.dy)
        if speed < stopSpeed {
            velocity = .zero
            restTimer += dt
            if phase == .free { phase = .idle }
        } else {
            restTimer = 0
        }

        if demo {
            demoLaunchTimer += dt
            // Re-launch once it has settled, or as a hard safety after ~3.4s.
            if (phase == .idle && restTimer > 0.5) || demoLaunchTimer > 3.4 {
                seedLaunch(in: bounds)
            }
        }
    }

    private func integrate(dt: CGFloat, bounds: MarbleBounds) {
        // Semi-implicit: advance position, apply friction, then resolve walls.
        position.x += velocity.dx * dt
        position.y += velocity.dy * dt

        let damp = max(0, 1 - friction * dt)
        velocity.dx *= damp
        velocity.dy *= damp

        reflectWalls(bounds: bounds)
    }

    private func reflectWalls(bounds: MarbleBounds) {
        var didBounce = false

        if position.x < bounds.minX {
            position.x = bounds.minX
            if velocity.dx < 0 { velocity.dx = -velocity.dx * restitution; didBounce = true }
        } else if position.x > bounds.maxX {
            position.x = bounds.maxX
            if velocity.dx > 0 { velocity.dx = -velocity.dx * restitution; didBounce = true }
        }

        if position.y < bounds.minY {
            position.y = bounds.minY
            if velocity.dy < 0 { velocity.dy = -velocity.dy * restitution; didBounce = true }
        } else if position.y > bounds.maxY {
            position.y = bounds.maxY
            if velocity.dy > 0 { velocity.dy = -velocity.dy * restitution; didBounce = true }
        }

        if didBounce { bounceCount &+= 1 }
    }

    // MARK: Launch / drag

    private func seedLaunch(in bounds: MarbleBounds) {
        // Start near a corner-ish point and throw across the tray on a diagonal.
        let startX = bounds.minX + (bounds.maxX - bounds.minX) * 0.22
        let startY = bounds.maxY - (bounds.maxY - bounds.minY) * 0.18
        position = CGPoint(x: startX, y: startY)

        let minSide = max(1, min(bounds.size.width, bounds.size.height))
        let base = minSide * 6.0 // scale launch speed to the tile so it banks a couple walls
        // Alternate the throw direction each launch for variety.
        let dir: CGFloat = (bounceCount % 2 == 0) ? 1 : -1
        velocity = CGVector(dx: base * 0.95 * dir, dy: -base * 0.75)
        phase = .free
        restTimer = 0
        demoLaunchTimer = 0
    }

    func beginDragIfNeeded(at start: CGPoint, bounds: MarbleBounds) {
        guard phase != .dragging else { return }
        phase = .dragging
        velocity = .zero
        restTimer = 0
        demoLaunchTimer = 0
    }

    func dragTo(_ location: CGPoint, bounds: MarbleBounds) {
        position = location
        confine(to: bounds)
    }

    func release(velocity v: CGVector, bounds: MarbleBounds) {
        // Tune raw predicted-translation delta into px/s. predictedEndTranslation
        // already represents the projected fling; scale gives it real momentum.
        let k: CGFloat = 5.0
        velocity = CGVector(dx: v.dx * k, dy: v.dy * k)
        phase = .free
        restTimer = 0
    }

    // MARK: Helpers

    private func confine(to bounds: MarbleBounds) {
        position.x = min(max(position.x, bounds.minX), bounds.maxX)
        position.y = min(max(position.y, bounds.minY), bounds.maxY)
    }

    private func clampedDelta(to date: Date) -> CGFloat {
        defer { lastTick = date }
        guard let last = lastTick else { return 0 }
        let raw = date.timeIntervalSince(last)
        if raw <= 0 { return 0 }
        return CGFloat(min(raw, 1.0 / 30.0)) // clamp so a stalled frame can't teleport
    }

    func displayPosition(in bounds: MarbleBounds) -> CGPoint {
        if position == .zero { return bounds.center }
        return position
    }
}
