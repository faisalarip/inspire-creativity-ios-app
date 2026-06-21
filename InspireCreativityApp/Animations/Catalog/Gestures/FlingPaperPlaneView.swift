// catalog-id: ges-fling-paper-plane
import SwiftUI

/// Fling a folded paper plane and it launches along your vector, then glides in a
/// gentle banking descent with subtle pitch bobbing before nosing down to land.
///
/// - `demo == true`  → a self-driving `TimelineView(.animation)` loop auto-launches the
///   plane each cycle, glides it in a banking descent and lands it on the pad, then resets.
/// - `demo == false` → a real interactive component: drag the plane, release to fling it
///   along your vector (seeded from `predictedEndTranslation`), watch it glide and land,
///   then drag again to re-throw.
struct FlingPaperPlaneView: View {
    var demo: Bool = false

    // Interactive launch parameters. The TimelineView closure is a PURE function of these
    // plus elapsed time — nothing is integrated/accumulated during the render pass.
    @State private var launchDate: Date? = nil
    @State private var launchVelocity: CGVector = .zero   // normalized units / second
    @State private var dragOrigin: CGPoint = .zero        // normalized launch point
    @State private var dragTranslation: CGSize = .zero    // live finger offset (points)
    @State private var isDragging: Bool = false

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                background
                if demo {
                    demoLayer(in: size)
                } else {
                    interactiveLayer(in: size)
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

// MARK: - Backdrop

private extension FlingPaperPlaneView {
    var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.09, green: 0.12, blue: 0.22),
                Color(red: 0.05, green: 0.06, blue: 0.12)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Demo (self-driving) layer

private extension FlingPaperPlaneView {
    /// Total loop length in seconds. The last `restFraction` of it shows the plane resting
    /// on the pad so the cycle seam reads as an intentional pause, never a blank teleport.
    var cycle: Double { 3.4 }
    var restFraction: Double { 0.16 }

    func demoLayer(in size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let phase = loopPhase(timeline.date)
            let launch = demoLaunchVelocity()
            let origin = demoOrigin
            let flightSpan = cycle * (1.0 - restFraction)
            // During the rest beat, freeze at the landed state of the last flight frame.
            let elapsed = min(phase, flightSpan)
            let state = glideState(t: elapsed, v0: launch, origin: origin, in: size)

            ZStack(alignment: .topLeading) {
                landingPad(at: demoLandingPoint, in: size)
                glideTrail(state: state, in: size)
                planeAndShadow(state: state, in: size)
            }
            .frame(width: size.width, height: size.height)
        }
    }

    /// Position within the current loop, in seconds [0, cycle).
    func loopPhase(_ date: Date) -> Double {
        let t = date.timeIntervalSinceReferenceDate
        return t.truncatingRemainder(dividingBy: cycle)
    }

    /// Launch point for the auto loop: lower-left pad.
    var demoOrigin: CGPoint { CGPoint(x: 0.16, y: 0.78) }

    /// Fixed launch vector for the loop. Negative y == upward in view space.
    func demoLaunchVelocity() -> CGVector {
        CGVector(dx: 0.62, dy: -0.92)
    }

    /// Where the demo plane actually touches down — derived from the same closed-form
    /// glide model (and pinned to `ground`) so the pad sits exactly under the landed plane.
    /// The four constants MUST match the locals in `glideState`.
    var demoLandingPoint: CGPoint {
        let v = demoLaunchVelocity()
        let o = demoOrigin
        let k: Double = 1.55
        let gravity: Double = 0.46
        let lift: Double = 0.34
        let ground: CGFloat = 0.82
        let tLand = landingTime(v0: v, origin: o, k: k, gravity: gravity,
                                lift: lift, ground: ground)
        let landed = trajectory(t: tLand, v0: v, origin: o,
                                k: k, gravity: gravity, lift: lift)
        return CGPoint(x: landed.x, y: Double(ground))
    }
}

// MARK: - Interactive layer

private extension FlingPaperPlaneView {
    func interactiveLayer(in size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let state = currentInteractiveState(now: timeline.date, in: size)
            ZStack(alignment: .topLeading) {
                landingPad(at: restOrigin, in: size)
                glideTrail(state: state, in: size)
                planeAndShadow(state: state, in: size)
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .gesture(dragGesture(in: size))
        }
    }

    /// Resolve the plane state for interactive mode across its three beats:
    /// idle-at-rest, dragging-with-finger, and post-release glide.
    func currentInteractiveState(now: Date, in size: CGSize) -> GlideState {
        if isDragging {
            return draggingState(in: size)
        }
        guard let launchDate else {
            return restState(at: restOrigin)
        }
        let t = now.timeIntervalSince(launchDate)
        return glideState(t: t, v0: launchVelocity, origin: dragOrigin, in: size)
    }

    /// The home pad position for the interactive plane.
    var restOrigin: CGPoint { CGPoint(x: 0.5, y: 0.7) }

    /// Plane held under the finger: tracks the live translation, nose tilts toward motion.
    func draggingState(in size: CGSize) -> GlideState {
        let w = max(size.width, 1)
        let h = max(size.height, 1)
        let pos = CGPoint(
            x: dragOrigin.x + dragTranslation.width / w,
            y: dragOrigin.y + dragTranslation.height / h
        )
        // Tilt the nose toward where the launch will go (opposite the pull-back).
        let pullX = -dragTranslation.width
        let pullY = -dragTranslation.height
        let mag = hypot(pullX, pullY)
        let heading: Double = mag > 6 ? atan2(pullY, pullX) : -.pi / 2
        return GlideState(
            position: clampInside(pos),
            rotation: heading,
            scale: 1.06,
            shadowSpread: 0.9
        )
    }

    func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    launchDate = nil
                    // Grab from wherever the plane rests.
                    dragOrigin = restOrigin
                }
                dragTranslation = value.translation
            }
            .onEnded { value in
                isDragging = false
                let w = max(size.width, 1)
                let h = max(size.height, 1)
                // Seed the launch vector from the overshoot (predicted - current).
                // `predictedEndTranslation` is available since iOS 13; this avoids relying
                // on `DragGesture.Value.velocity`.
                let overX = value.predictedEndTranslation.width - value.translation.width
                let overY = value.predictedEndTranslation.height - value.translation.height
                let releasePoint = CGPoint(
                    x: dragOrigin.x + value.translation.width / w,
                    y: dragOrigin.y + value.translation.height / h
                )
                let vScale: CGFloat = 1.9
                var v = CGVector(dx: overX / w * vScale, dy: overY / h * vScale)
                v = clampVelocity(v)
                dragOrigin = clampInside(releasePoint)
                launchVelocity = v
                launchDate = Date()
            }
    }
}

// MARK: - Shared glide model (pure function of time)

/// A fully-resolved render state. Computed deterministically from launch params + time;
/// never mutated during the render pass.
private struct GlideState {
    var position: CGPoint      // normalized [0,1] view fractions
    var rotation: Double       // radians; 0 == nose pointing +x
    var scale: CGFloat         // 1 == baseline
    var shadowSpread: CGFloat  // 0 (tight, near ground) .. 1 (soft, high up)
}

private extension FlingPaperPlaneView {
    /// Closed-form glide. No ODE stepping — every value is a direct function of `t`.
    ///
    /// Horizontal drift bleeds off exponentially (lift/drag): `x = v0x·(1 − e^(−k t))/k`.
    /// Vertically the plane holds (lift) then steepens (gravity wins) into a nose-down
    /// descent. Heading follows the velocity derivative so "nosing down to land" falls out
    /// for free. After touchdown the plane is pinned and a damped-sinusoid settle owns the
    /// rotation (so an at-rest `atan2` of near-zero velocity can't jitter the nose).
    func glideState(t: Double, v0: CGVector, origin: CGPoint, in size: CGSize) -> GlideState {
        guard t > 0 else { return restState(at: origin) }

        let k: Double = 1.55         // horizontal drag constant
        let gravity: Double = 0.46   // descent strength
        let lift: Double = 0.34      // early upward hold
        let ground: CGFloat = 0.82   // landing height (view fraction)

        let raw = trajectory(t: t, v0: v0, origin: origin, k: k, gravity: gravity, lift: lift)
        let tLand = landingTime(v0: v0, origin: origin, k: k, gravity: gravity,
                                lift: lift, ground: ground)

        if t >= tLand {
            // Post-landing: pin on the ground; rotation eases via a damped wobble settle.
            let landed = trajectory(t: tLand, v0: v0, origin: origin,
                                    k: k, gravity: gravity, lift: lift)
            let landedPos = CGPoint(x: landed.x, y: Double(ground))
            let settle = landingSettle(since: t - tLand)
            return GlideState(
                position: clampInside(landedPos),
                rotation: settle,
                scale: 1.0,
                shadowSpread: 0.05
            )
        }

        // In-flight: heading from the trajectory's velocity, plus pitch-bob and bank.
        let vel = trajectoryVelocity(t: t, v0: v0, k: k, gravity: gravity, lift: lift)
        let heading = atan2(vel.dy, vel.dx)
        let pitchBob: Double = 0.10 * sin(t * 6.2)
        let bank = bankAngle(forwardSpeed: vel.dx)
        let altitude = max(0.0, Double((ground - CGFloat(raw.y)) / ground))

        return GlideState(
            position: clampInside(raw),
            rotation: heading + pitchBob + bank,
            scale: 1.0 + 0.05 * CGFloat(altitude),
            shadowSpread: CGFloat(altitude)
        )
    }

    /// Closed-form position at time `t` (normalized view fractions).
    func trajectory(t: Double, v0: CGVector, origin: CGPoint,
                    k: Double, gravity: Double, lift: Double) -> CGPoint {
        let decay = (1.0 - exp(-k * t)) / k
        let x = Double(origin.x) + Double(v0.dx) * decay
        // Vertical: initial velocity (incl. lift hold) bleeds via the same decay,
        // then gravity adds an accelerating downward term.
        let vy0 = Double(v0.dy) - lift   // more negative early -> rises/holds
        let y = Double(origin.y) + vy0 * decay + 0.5 * gravity * t * t
        return CGPoint(x: x, y: y)
    }

    /// Analytic velocity (derivative of `trajectory`) used for the flight heading.
    func trajectoryVelocity(t: Double, v0: CGVector,
                            k: Double, gravity: Double, lift: Double) -> CGVector {
        let dDecay = exp(-k * t)         // d/dt of (1 − e^(−k t))/k
        let vx = Double(v0.dx) * dDecay
        let vy0 = Double(v0.dy) - lift
        let vy = vy0 * dDecay + gravity * t
        return CGVector(dx: vx, dy: vy)
    }

    /// Find (by sampling) the first time the path crosses the ground line.
    func landingTime(v0: CGVector, origin: CGPoint, k: Double, gravity: Double,
                     lift: Double, ground: CGFloat) -> Double {
        var t = 0.04
        let step = 0.02
        let limit = 6.0
        while t < limit {
            let p = trajectory(t: t, v0: v0, origin: origin,
                               k: k, gravity: gravity, lift: lift)
            if CGFloat(p.y) >= ground { return t }
            t += step
        }
        return limit
    }

    /// Damped-sinusoid settle for the post-landing nose wobble, easing to level (0).
    func landingSettle(since dt: Double) -> Double {
        let amp = 0.20
        let damp = 5.0
        let omega = 13.0
        return amp * exp(-damp * dt) * cos(omega * dt)
    }

    /// Bank scaled by forward speed — faster drift, more bank.
    func bankAngle(forwardSpeed vx: Double) -> Double {
        let normalized = max(-1.0, min(1.0, vx / 0.8))
        return 0.12 * normalized
    }

    func restState(at origin: CGPoint) -> GlideState {
        GlideState(
            position: origin,
            rotation: -.pi / 2 + 0.05,   // resting nose slightly up
            scale: 1.0,
            shadowSpread: 0.05
        )
    }

    func clampInside(_ p: CGPoint) -> CGPoint {
        CGPoint(
            x: min(0.94, max(0.06, p.x)),
            y: min(0.92, max(0.06, p.y))
        )
    }

    func clampVelocity(_ v: CGVector) -> CGVector {
        let maxMag: CGFloat = 1.7
        let mag = hypot(v.dx, v.dy)
        guard mag > maxMag else { return v }
        let s = maxMag / mag
        return CGVector(dx: v.dx * s, dy: v.dy * s)
    }
}

// MARK: - Rendering

private extension FlingPaperPlaneView {
    func planeAndShadow(state: GlideState, in size: CGSize) -> some View {
        let span = min(size.width, size.height)
        let planeSize = span * 0.22 * state.scale
        let center = CGPoint(x: state.position.x * size.width,
                             y: state.position.y * size.height)
        // Contact shadow sits below the plane; softens & spreads with altitude.
        let shadowDrop = span * (0.06 + 0.18 * state.shadowSpread)
        let shadowScale = 1.0 - 0.45 * state.shadowSpread
        let shadowOpacity = 0.30 - 0.18 * Double(state.shadowSpread)

        return ZStack {
            Ellipse()
                .fill(Color(red: 0, green: 0, blue: 0).opacity(shadowOpacity))
                .frame(width: planeSize * 0.9 * shadowScale,
                       height: planeSize * 0.26 * shadowScale)
                .blur(radius: 3 + 6 * state.shadowSpread)
                .position(x: center.x, y: center.y + shadowDrop)

            PaperPlaneShape()
                .fill(planeBodyGradient)
                .overlay(
                    PaperPlaneShape()
                        .stroke(Color(red: 1, green: 1, blue: 1).opacity(0.55),
                                lineWidth: 0.8)
                )
                .overlay(
                    PaperCreaseShape()
                        .stroke(Color(red: 0.10, green: 0.12, blue: 0.20).opacity(0.5),
                                lineWidth: 0.8)
                )
                .frame(width: planeSize, height: planeSize)
                .rotationEffect(.radians(state.rotation))
                .shadow(color: Color(red: 0, green: 0, blue: 0).opacity(0.25),
                        radius: 2, x: 0, y: 1)
                .position(center)
        }
    }

    var planeBodyGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.98, green: 0.98, blue: 1.0),
                Color(red: 0.80, green: 0.84, blue: 0.94)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// A faint motion trail behind the plane while it is airborne and moving.
    func glideTrail(state: GlideState, in size: CGSize) -> some View {
        let span = min(size.width, size.height)
        let center = CGPoint(x: state.position.x * size.width,
                             y: state.position.y * size.height)
        let len = span * 0.5 * state.shadowSpread
        let dx = cos(state.rotation)
        let dy = sin(state.rotation)
        let tail = CGPoint(x: center.x - dx * len, y: center.y - dy * len)
        let tipOpacity = 0.22 * Double(state.shadowSpread)

        return Path { p in
            p.move(to: center)
            p.addLine(to: tail)
        }
        .stroke(
            LinearGradient(
                colors: [
                    Color(red: 1, green: 1, blue: 1).opacity(0.0),
                    Color(red: 0.7, green: 0.8, blue: 1.0).opacity(tipOpacity)
                ],
                startPoint: .leading,
                endPoint: .trailing
            ),
            style: StrokeStyle(lineWidth: 2, lineCap: .round)
        )
        .allowsHitTesting(false)
    }

    func landingPad(at origin: CGPoint, in size: CGSize) -> some View {
        let w = min(size.width, size.height) * 0.22
        let p = CGPoint(x: origin.x * size.width, y: origin.y * size.height)
        return Capsule()
            .fill(Color(red: 1, green: 1, blue: 1).opacity(0.05))
            .frame(width: w, height: w * 0.16)
            .position(x: p.x, y: p.y + w * 0.30)
            .allowsHitTesting(false)
    }
}

// MARK: - Plane geometry

/// A folded paper-plane silhouette. Nose points toward +x (rotation 0).
private struct PaperPlaneShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let nose = CGPoint(x: rect.minX + w * 0.98, y: rect.midY)
        let topTail = CGPoint(x: rect.minX + w * 0.02, y: rect.minY + h * 0.16)
        let tailNotch = CGPoint(x: rect.minX + w * 0.28, y: rect.midY)
        let bottomTail = CGPoint(x: rect.minX + w * 0.02, y: rect.maxY - h * 0.16)

        p.move(to: nose)
        p.addLine(to: topTail)
        p.addLine(to: tailNotch)
        p.addLine(to: bottomTail)
        p.closeSubpath()
        return p
    }
}

/// The center crease line of the fold (drawn as a subtle dividing line).
private struct PaperCreaseShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let nose = CGPoint(x: rect.minX + rect.width * 0.98, y: rect.midY)
        let tail = CGPoint(x: rect.minX + rect.width * 0.28, y: rect.midY)
        p.move(to: nose)
        p.addLine(to: tail)
        return p
    }
}
