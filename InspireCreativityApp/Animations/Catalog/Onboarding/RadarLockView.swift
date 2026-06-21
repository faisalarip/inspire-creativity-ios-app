// catalog-id: ob-radar-lock
import SwiftUI

// MARK: - Radar Lock-On Permission
// A location-permission hero: a sweeping radar hunts a wandering blip, then on
// "grant" the reticle snaps inward to lock on, a pin bounces down, and a
// "located" ring ripples out. demo == true self-drives the full hunt→lock loop;
// demo == false locks on tap and replays.

struct RadarLockView: View {
    var demo: Bool = false

    // Frozen blip position captured at the moment of a real tap-grant.
    @State private var lockedBlip: CGPoint = .zero
    // Increments on each tap to re-fire the KeyframeAnimator lock choreography.
    @State private var tapCount: Int = 0
    // Drives the "located" / settled state after a real lock.
    @State private var hasLocked: Bool = false

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            if demo {
                demoRadar(in: size)
            } else {
                interactiveRadar(in: size)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Demo (self-driving, single TimelineView, single phase function)

    private func demoRadar(in size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let s = RadarLockView_RadarState.demoState(at: t, size: size)
            RadarLockView_RadarSceneView(state: s, showLocatedLabel: s.lock.ring > 0.05)
        }
    }

    // MARK: Interactive (sweep on its own clock + KeyframeAnimator lock)

    private func interactiveRadar(in size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let geom = RadarLockView_RadarGeometry(size: size)
            let sweepAngle = RadarLockView_RadarState.huntSweepAngle(at: t)
            let liveBlip = hasLocked ? lockedBlip
                                     : RadarLockView_RadarState.huntBlip(at: t, geom: geom)

            KeyframeAnimator(initialValue: RadarLockView_LockProgress(),
                             trigger: tapCount) { lock in
                let state = RadarLockView_RadarState(
                    sweepAngle: sweepAngle,
                    blip: hasLocked ? lockedBlip : liveBlip,
                    lock: lock,
                    geom: geom
                )
                RadarLockView_RadarSceneView(state: state, showLocatedLabel: lock.ring > 0.05)
            } keyframes: { _ in
                // Reticle snaps inward (overshoot then settle).
                KeyframeTrack(\.reticle) {
                    SpringKeyframe(1.0, duration: 0.45, spring: .bouncy)
                    LinearKeyframe(1.0, duration: 1.6)
                }
                // Pin bounces down shortly after the reticle bites.
                KeyframeTrack(\.pin) {
                    LinearKeyframe(0.0, duration: 0.30)
                    SpringKeyframe(1.0, duration: 0.55,
                                   spring: .init(duration: 0.55, bounce: 0.55))
                    LinearKeyframe(1.0, duration: 1.20)
                }
                // "Located" ring ripples out last and fades.
                KeyframeTrack(\.ring) {
                    LinearKeyframe(0.0, duration: 0.55)
                    CubicKeyframe(1.0, duration: 0.95)
                    LinearKeyframe(1.0, duration: 0.55)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            captureAndLock(in: size)
        }
        .sensoryFeedback(.success, trigger: tapCount)
    }

    private func captureAndLock(in size: CGSize) {
        let geom = RadarLockView_RadarGeometry(size: size)
        let t = Date().timeIntervalSinceReferenceDate
        // Snapshot the blip's live position so lock elements don't drift.
        lockedBlip = RadarLockView_RadarState.huntBlip(at: t, geom: geom)
        hasLocked = true
        tapCount += 1
    }
}

// MARK: - Geometry

private struct RadarLockView_RadarGeometry {
    let center: CGPoint
    let radius: CGFloat

    init(size: CGSize) {
        center = CGPoint(x: size.width / 2, y: size.height / 2)
        radius = min(size.width, size.height) * 0.5 * 0.84
    }
}

// MARK: - Lock progress (multi-track animatable struct)

private struct RadarLockView_LockProgress: Equatable {
    var reticle: CGFloat = 0   // 0 = wide open / invisible, 1 = locked tight
    var pin: CGFloat = 0       // 0 = above, 1 = dropped & settled
    var ring: CGFloat = 0      // 0 = none, 1 = fully expanded & faded
}

// MARK: - Full radar state (pure value the renderer consumes)

private struct RadarLockView_RadarState {
    var sweepAngle: Double      // radians
    var blip: CGPoint           // absolute point
    var lock: RadarLockView_LockProgress
    var geom: RadarLockView_RadarGeometry

    // --- Hunt sub-functions (shared by demo & interactive) ---

    static func huntSweepAngle(at t: TimeInterval) -> Double {
        // Continuous clockwise sweep, ~1 rev / 2.6s.
        let rev = 2.6
        return (t.truncatingRemainder(dividingBy: rev) / rev) * 2 * .pi
    }

    static func huntBlip(at t: TimeInterval, geom: RadarLockView_RadarGeometry) -> CGPoint {
        // A wandering blip on two out-of-phase sines, kept inside the dish.
        let rx = geom.radius * 0.52
        let ry = geom.radius * 0.40
        let ax = sin(t * 0.62) * cos(t * 0.27)
        let ay = sin(t * 0.48 + 1.3)
        let x = geom.center.x + CGFloat(ax) * rx
        let y = geom.center.y + CGFloat(ay) * ry
        return CGPoint(x: x, y: y)
    }

    // --- Demo state: single phase function over a ~3.4s loop ---

    static func demoState(at t: TimeInterval, size: CGSize) -> RadarLockView_RadarState {
        let geom = RadarLockView_RadarGeometry(size: size)
        let period = 3.4
        let p = t.truncatingRemainder(dividingBy: period) / period // 0..1
        let huntEnd = 0.46

        let sweep = huntSweepAngle(at: t)

        if p < huntEnd {
            // Hunting: blip wanders, no lock elements.
            let blip = huntBlip(at: t, geom: geom)
            return RadarLockView_RadarState(sweepAngle: sweep, blip: blip,
                              lock: RadarLockView_LockProgress(), geom: geom)
        }

        // Lock window: freeze the blip at the moment hunting ended.
        let freezeT = t - (p - huntEnd) * period
        let frozenBlip = huntBlip(at: freezeT, geom: geom)

        // Local progress through the lock window.
        let lp = (p - huntEnd) / (1.0 - huntEnd) // 0..1

        var lock = RadarLockView_LockProgress()
        lock.reticle = bouncyRamp(lp, start: 0.00, end: 0.34)
        lock.pin     = bouncyRamp(lp, start: 0.22, end: 0.62)
        lock.ring    = smoothRamp(lp, start: 0.46, end: 1.00)

        return RadarLockView_RadarState(sweepAngle: sweep, blip: frozenBlip,
                          lock: lock, geom: geom)
    }

    // Eased ramp with a slight overshoot, clamped, for snap-in feel.
    static func bouncyRamp(_ x: CGFloat, start: CGFloat, end: CGFloat) -> CGFloat {
        let u = clamped((x - start) / max(end - start, 0.0001))
        let eased = 1 - pow(1 - u, 3)
        let overshoot = sin(u * .pi) * 0.10 * (1 - u)
        return min(1.0, eased + overshoot)
    }

    static func smoothRamp(_ x: CGFloat, start: CGFloat, end: CGFloat) -> CGFloat {
        let u = clamped((x - start) / max(end - start, 0.0001))
        return u * u * (3 - 2 * u) // smoothstep
    }

    static func clamped(_ v: CGFloat) -> CGFloat { min(1, max(0, v)) }
}

// MARK: - Scene renderer (the single shared view)

private struct RadarLockView_RadarSceneView: View {
    let state: RadarLockView_RadarState
    var showLocatedLabel: Bool

    private var palette: RadarLockView_RadarPalette { RadarLockView_RadarPalette() }

    var body: some View {
        ZStack {
            background
            sweepAndDish
            blipDot
            reticle
            locatedRing
            pin
            label
        }
    }

    // Background gradient fill behind the dish.
    private var background: some View {
        RadialGradient(
            colors: [palette.bgInner, palette.bgOuter],
            center: .center,
            startRadius: 0,
            endRadius: state.geom.radius * 1.4
        )
    }

    // Canvas: concentric rings, cross-hair grid, sweep wedge + arm.
    private var sweepAndDish: some View {
        Canvas { ctx, _ in
            drawDish(in: &ctx)
            drawSweep(in: &ctx)
        }
        .allowsHitTesting(false)
    }

    private func drawDish(in ctx: inout GraphicsContext) {
        let c = state.geom.center
        let r = state.geom.radius

        // Concentric rings.
        for i in 1...4 {
            let rr = r * CGFloat(i) / 4.0
            let rect = CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)
            ctx.stroke(
                Circle().path(in: rect),
                with: .color(palette.grid.opacity(i == 4 ? 0.55 : 0.30)),
                lineWidth: i == 4 ? 1.6 : 0.9
            )
        }

        // Cross-hair grid lines.
        var cross = Path()
        cross.move(to: CGPoint(x: c.x - r, y: c.y))
        cross.addLine(to: CGPoint(x: c.x + r, y: c.y))
        cross.move(to: CGPoint(x: c.x, y: c.y - r))
        cross.addLine(to: CGPoint(x: c.x, y: c.y + r))
        ctx.stroke(cross, with: .color(palette.grid.opacity(0.22)), lineWidth: 0.8)
    }

    private func drawSweep(in ctx: inout GraphicsContext) {
        let c = state.geom.center
        let r = state.geom.radius
        let angle = state.sweepAngle

        // Trailing wedge: a cheap filled fan tapering in opacity behind the arm.
        let wedgeSpan = Double.pi * 0.42
        let steps = 9
        for i in 0..<steps {
            let f0 = Double(i) / Double(steps)
            let f1 = Double(i + 1) / Double(steps)
            let a0 = angle - wedgeSpan * f0
            let a1 = angle - wedgeSpan * f1
            var seg = Path()
            seg.move(to: c)
            seg.addLine(to: point(c, r, a0))
            seg.addLine(to: point(c, r, a1))
            seg.closeSubpath()
            let op = (1.0 - f0) * 0.22
            ctx.fill(seg, with: .color(palette.sweep.opacity(op)))
        }

        // Leading arm.
        var arm = Path()
        arm.move(to: c)
        arm.addLine(to: point(c, r, angle))
        ctx.stroke(arm, with: .color(palette.sweep.opacity(0.95)), lineWidth: 2.0)

        // Hub.
        let hubR = r * 0.045
        let hub = CGRect(x: c.x - hubR, y: c.y - hubR, width: hubR * 2, height: hubR * 2)
        ctx.fill(Circle().path(in: hub), with: .color(palette.sweep.opacity(0.9)))
    }

    private func point(_ c: CGPoint, _ r: CGFloat, _ a: Double) -> CGPoint {
        CGPoint(x: c.x + r * CGFloat(cos(a)), y: c.y + r * CGFloat(sin(a)))
    }

    // The wandering / locked blip.
    private var blipDot: some View {
        let r = state.geom.radius
        let baseR = r * 0.05
        // Blip dims a touch once the reticle bites (it's "caught").
        let glow = 1.0 - state.lock.reticle * 0.25
        return Circle()
            .fill(palette.blip)
            .frame(width: baseR * 2, height: baseR * 2)
            .shadow(color: palette.blip.opacity(0.8 * glow), radius: baseR * 1.2)
            .position(state.blip)
            .opacity(0.85 + 0.15 * glow)
    }

    // Reticle: four corner brackets that snap inward onto the blip.
    private var reticle: some View {
        let p = state.lock.reticle
        let r = state.geom.radius
        // Wide when open, tight when locked.
        let span = r * (0.42 - 0.30 * p)
        let opacity = min(1.0, p * 1.6)
        return RadarLockView_ReticleShape(span: span)
            .stroke(palette.reticle.opacity(opacity),
                    style: StrokeStyle(lineWidth: 2.0, lineCap: .round))
            .frame(width: span * 2, height: span * 2)
            .rotationEffect(.degrees(Double((1 - p) * 35)))
            .position(state.blip)
    }

    // "Located" ring ripple expanding out from the lock point.
    private var locatedRing: some View {
        let p = state.lock.ring
        let r = state.geom.radius
        let maxR = r * 0.95
        let cur = r * 0.10 + maxR * p
        let opacity = max(0.0, (1.0 - p)) * 0.9
        return Circle()
            .stroke(palette.ring.opacity(opacity),
                    style: StrokeStyle(lineWidth: 2.5))
            .frame(width: cur * 2, height: cur * 2)
            .position(state.blip)
            .opacity(p > 0.001 ? 1 : 0)
    }

    // Pin that bounces down onto the lock point.
    private var pin: some View {
        let p = state.lock.pin
        let r = state.geom.radius
        let pinH = r * 0.34
        // Rises from above and settles at the blip.
        let dropY = -pinH * 1.6 * (1 - p)
        let opacity = min(1.0, p * 2.2)
        let anchor = CGPoint(x: state.blip.x, y: state.blip.y + dropY)
        return RadarLockView_PinShape()
            .fill(palette.pin)
            .frame(width: pinH * 0.62, height: pinH)
            // Anchor the tip at the bottom of the frame onto the point.
            .offset(y: -pinH / 2)
            .shadow(color: .black.opacity(0.35 * Double(p)), radius: r * 0.03, y: r * 0.02)
            .scaleEffect(0.85 + 0.15 * p)
            .position(anchor)
            .opacity(opacity)
    }

    @ViewBuilder
    private var label: some View {
        if showLocatedLabel {
            VStack {
                Spacer()
                Text("LOCATED")
                    .font(.system(size: max(10, state.geom.radius * 0.14),
                                  weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(palette.ring)
                    .padding(.bottom, state.geom.radius * 0.06)
            }
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }
}

// MARK: - Shapes

private struct RadarLockView_ReticleShape: Shape {
    var span: CGFloat
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let s = span
        let arm = s * 0.45 // length of each corner bracket arm
        let corners: [(CGFloat, CGFloat)] = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
        for (sx, sy) in corners {
            let cx = c.x + sx * s
            let cy = c.y + sy * s
            path.move(to: CGPoint(x: cx - sx * arm, y: cy))
            path.addLine(to: CGPoint(x: cx, y: cy))
            path.addLine(to: CGPoint(x: cx, y: cy - sy * arm))
        }
        return path
    }
}

// A classic map pin: round head + tapered tail, tip at the bottom center.
private struct RadarLockView_PinShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let headR = w * 0.5
        let headC = CGPoint(x: rect.midX, y: rect.minY + headR)

        // Head circle.
        path.addEllipse(in: CGRect(x: headC.x - headR, y: rect.minY,
                                   width: headR * 2, height: headR * 2))
        // Tail to the tip.
        let tip = CGPoint(x: rect.midX, y: rect.maxY)
        path.move(to: CGPoint(x: headC.x - headR * 0.78, y: headC.y + headR * 0.55))
        path.addQuadCurve(to: tip,
                          control: CGPoint(x: headC.x - headR * 0.30, y: h * 0.78))
        path.addLine(to: tip)
        path.addQuadCurve(to: CGPoint(x: headC.x + headR * 0.78, y: headC.y + headR * 0.55),
                          control: CGPoint(x: headC.x + headR * 0.30, y: h * 0.78))
        path.closeSubpath()
        return path
    }
}

// MARK: - Palette

private struct RadarLockView_RadarPalette {
    let bgInner = Color(red: 0.07, green: 0.16, blue: 0.13)
    let bgOuter = Color(red: 0.03, green: 0.06, blue: 0.07)
    let grid    = Color(red: 0.35, green: 0.95, blue: 0.65)
    let sweep   = Color(red: 0.40, green: 1.00, blue: 0.70)
    let blip    = Color(red: 0.55, green: 1.00, blue: 0.78)
    let reticle = Color(red: 1.00, green: 0.92, blue: 0.45)
    let ring    = Color(red: 0.55, green: 0.95, blue: 1.00)
    let pin     = Color(red: 1.00, green: 0.40, blue: 0.42)
}
