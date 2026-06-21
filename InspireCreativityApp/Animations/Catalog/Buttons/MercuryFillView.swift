// catalog-id: btn-mercury-fill
import SwiftUI

/// Mercury Fill — a press drops a blob of liquid metal that sloshes side to side
/// under gravity, overshoots, and rebalances to fill the button as a progress
/// level with a reflective meniscus. All motion is hand-rolled and driven from a
/// single TimelineView so the slosh overshoot and the perpetual traveling ripple
/// are both genuinely animated frame-by-frame (a plain withAnimation + Canvas
/// read would teleport the level and kill the slosh).
struct MercuryFillView: View {
    var demo: Bool = false

    // Where the fill animation started from / is heading to (0...1).
    @State private var fillStart: CGFloat = 0.12
    @State private var fillTarget: CGFloat = 0.95
    // Reference time for the current transition.
    @State private var transitionStart: Date = .distantPast
    // Seed energy for the slosh, set when a new pour begins.
    @State private var sloshSeed: CGFloat = 1.0
    // Whether the most recent transition has reported its settle haptic.
    @State private var settledFlag: Bool = false
    // Drives sensoryFeedback in interactive mode.
    @State private var settleTick: Int = 0

    // Demo cadence.
    private let demoLow: CGFloat = 0.14
    private let demoHigh: CGFloat = 0.95
    private let demoPeriod: Double = 3.2

    var body: some View {
        GeometryReader { _ in
            TimelineView(.animation) { timeline in
                let now = timeline.date
                content(now: now)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { handleTap() }
        .sensoryFeedback(.impact(weight: .medium), trigger: settleTick)
        .onAppear {
            // Kick off the first pour so the very first frame is already alive.
            if transitionStart == .distantPast {
                fillStart = demo ? demoLow : 0.12
                fillTarget = demo ? demoHigh : 0.95
                transitionStart = Date()
                sloshSeed = 1.0
            }
        }
    }

    // MARK: - Frame composition

    @ViewBuilder
    private func content(now: Date) -> some View {
        let elapsed = max(0.0, now.timeIntervalSince(transitionStart))
        let cycle: (target: CGFloat, start: CGFloat, restart: Double)? = demo ? demoCycle(now: now) : nil
        let state = resolveState(elapsed: elapsed, cycle: cycle)

        ZStack {
            mercuryCanvas(state: state)
            chrome(state: state)
        }
        .compositingGroup()
    }

    /// In demo mode the pour direction flips automatically each half-period.
    private func demoCycle(now: Date) -> (target: CGFloat, start: CGFloat, restart: Double) {
        let secs = now.timeIntervalSinceReferenceDate
        let phase = secs.truncatingRemainder(dividingBy: demoPeriod)
        let rising = phase < demoPeriod / 2.0
        let segmentStart = secs - (rising ? phase : phase - demoPeriod / 2.0)
        return rising
            ? (demoHigh, demoLow, segmentStart)
            : (demoLow, demoHigh, segmentStart)
    }

    // MARK: - Physics resolution

    struct FillState {
        var fill: CGFloat        // 0...1 settled level (with overshoot baked in)
        var tilt: CGFloat        // -1...1 surface tilt from slosh
        var amp: CGFloat         // traveling-ripple amplitude factor 0...1
        var phase: Double        // perpetual ripple phase
        var glint: CGFloat       // meniscus glint cross-fade 0...1
    }

    private func resolveState(elapsed: Double, cycle: (target: CGFloat, start: CGFloat, restart: Double)?) -> FillState {
        // Use either the persistent interactive transition or the demo's
        // auto-flipping segment as the source of truth.
        let from: CGFloat
        let to: CGFloat
        let t: Double

        if let cycle {
            from = cycle.start
            to = cycle.target
            t = max(0.0, Date().timeIntervalSinceReferenceDate - cycle.restart)
        } else {
            from = fillStart
            to = fillTarget
            t = elapsed
        }

        let level = dampedOvershoot(from: from, to: to, t: t)
        let direction: CGFloat = to >= from ? 1.0 : -1.0

        // Slosh: a fast-decaying sine — fast decay + low frequency reads as
        // metal rather than water.
        let omega: Double = 7.4
        let decay: Double = 3.1
        let env = exp(-decay * t)
        let tilt = direction * sloshSeedFactor() * CGFloat(env * sin(omega * t))

        // Perpetual surface ripple, always present but small at rest.
        let phase = t * 2.2
        let amp = 0.18 + 0.82 * CGFloat(env)  // never fully flat, never blank

        // Meniscus glint crossfades in as the surface settles near the top.
        let glint = max(0.0, min(1.0, level)) * (1.0 - 0.4 * CGFloat(env))

        return FillState(fill: clamp01(level),
                         tilt: clamp(tilt, -1.0, 1.0),
                         amp: clamp01(amp),
                         phase: phase,
                         glint: clamp01(glint))
    }

    private func sloshSeedFactor() -> CGFloat { sloshSeed }

    /// A single overshoot-then-settle curve. Overshoots the target once and
    /// rebalances — the inertia that sells "mercury, not a level snap".
    private func dampedOvershoot(from: CGFloat, to: CGFloat, t: Double) -> CGFloat {
        let span = to - from
        let omega: Double = 6.0
        let zeta: Double = 0.34
        let wd = omega * (1.0 - zeta * zeta).squareRoot()
        let env = exp(-zeta * omega * t)
        // Standard underdamped step response.
        let osc = env * (cos(wd * t) + (zeta * omega / wd) * sin(wd * t))
        let progress = 1.0 - osc
        return from + span * CGFloat(progress)
    }

    // MARK: - Mercury Canvas

    private func mercuryCanvas(state: FillState) -> some View {
        Canvas { ctx, size in
            let radius = min(size.width, size.height) * 0.28
            let bounds = CGRect(origin: .zero, size: size).insetBy(dx: size.width * 0.03,
                                                                    dy: size.height * 0.03)
            let clip = RoundedRectangle(cornerRadius: radius, style: .continuous)
                .path(in: bounds)

            // Dark vial base so the fill always reads against something.
            ctx.fill(clip, with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.07, green: 0.06, blue: 0.05),
                    Color(red: 0.13, green: 0.11, blue: 0.09)
                ]),
                startPoint: CGPoint(x: bounds.midX, y: bounds.minY),
                endPoint: CGPoint(x: bounds.midX, y: bounds.maxY)
            ))

            var liquid = ctx
            liquid.clip(to: clip)
            drawMercury(in: &liquid, bounds: bounds, state: state)

            // Inner vignette to give the glass vial some depth.
            ctx.stroke(clip, with: .color(Color.black.opacity(0.35)),
                       lineWidth: max(1.0, size.height * 0.012))
        }
    }

    private func drawMercury(in ctx: inout GraphicsContext, bounds: CGRect, state: FillState) {
        let surfaceY = surfaceLevel(bounds: bounds, fill: state.fill)
        let amp = bounds.height * 0.045 * state.amp + bounds.width * 0.012
        let tiltOffset = state.tilt * bounds.height * 0.10

        let body = mercurySurface(bounds: bounds,
                                  surfaceY: surfaceY,
                                  amp: amp,
                                  tilt: tiltOffset,
                                  phase: state.phase)

        // Metallic body: dark steel base → bright specular mid → cool deep.
        ctx.fill(body, with: .linearGradient(
            Gradient(stops: [
                .init(color: Color(red: 0.78, green: 0.80, blue: 0.86), location: 0.0),
                .init(color: Color(red: 0.52, green: 0.55, blue: 0.62), location: 0.18),
                .init(color: Color(red: 0.30, green: 0.32, blue: 0.38), location: 0.55),
                .init(color: Color(red: 0.16, green: 0.17, blue: 0.21), location: 1.0)
            ]),
            startPoint: CGPoint(x: bounds.midX, y: surfaceY - amp),
            endPoint: CGPoint(x: bounds.midX, y: bounds.maxY)
        ))

        // Specular sheen band riding just under the surface.
        let sheen = sheenBand(bounds: bounds, surfaceY: surfaceY, amp: amp,
                              tilt: tiltOffset, phase: state.phase)
        ctx.fill(sheen, with: .linearGradient(
            Gradient(colors: [
                Color.white.opacity(0.0),
                Color.white.opacity(0.55),
                Color.white.opacity(0.0)
            ]),
            startPoint: CGPoint(x: bounds.minX, y: surfaceY),
            endPoint: CGPoint(x: bounds.maxX, y: surfaceY)
        ))

        // Meniscus highlight: a crisp bright line tracing the surface crest.
        let crest = surfaceCrest(bounds: bounds, surfaceY: surfaceY, amp: amp,
                                 tilt: tiltOffset, phase: state.phase)
        ctx.stroke(crest,
                   with: .color(Color.white.opacity(0.45 + 0.45 * Double(state.glint))),
                   style: StrokeStyle(lineWidth: max(1.0, bounds.height * 0.012),
                                      lineCap: .round, lineJoin: .round))

        // Travelling glint dot on the meniscus for the "reflective" pop.
        let glintX = bounds.minX + bounds.width * (0.5 + 0.32 * sin(state.phase))
        let glintY = surfaceY + tiltOffset * (glintX - bounds.midX) / max(1.0, bounds.width / 2.0)
            + amp * CGFloat(sin(state.phase + Double(glintX) * 0.05))
        let dot = CGRect(x: glintX - bounds.width * 0.03,
                         y: glintY - bounds.width * 0.03,
                         width: bounds.width * 0.06,
                         height: bounds.width * 0.06)
        ctx.fill(Ellipse().path(in: dot),
                 with: .radialGradient(
                    Gradient(colors: [Color.white.opacity(0.85 * Double(state.glint)),
                                      Color.white.opacity(0.0)]),
                    center: CGPoint(x: dot.midX, y: dot.midY),
                    startRadius: 0.0,
                    endRadius: bounds.width * 0.04))
    }

    // MARK: - Surface geometry

    private func surfaceLevel(bounds: CGRect, fill: CGFloat) -> CGFloat {
        // fill 0 → bottom, fill 1 → top (with small margins so it never clips).
        let top = bounds.minY + bounds.height * 0.06
        let bottom = bounds.maxY - bounds.height * 0.02
        return bottom - (bottom - top) * fill
    }

    private func waveY(x: CGFloat, bounds: CGRect, surfaceY: CGFloat,
                       amp: CGFloat, tilt: CGFloat, phase: Double) -> CGFloat {
        let half = max(1.0, bounds.width / 2.0)
        let rel = (x - bounds.midX) / half                 // -1...1 across width
        let ripple = amp * CGFloat(sin(Double(x) * 0.06 + phase))
            + amp * 0.4 * CGFloat(sin(Double(x) * 0.13 - phase * 1.6))
        let slant = tilt * rel
        return surfaceY + slant + ripple
    }

    /// Filled liquid body: top is the wavy surface, sides + bottom follow bounds.
    private func mercurySurface(bounds: CGRect, surfaceY: CGFloat, amp: CGFloat,
                                tilt: CGFloat, phase: Double) -> Path {
        var path = Path()
        let steps = 28
        path.move(to: CGPoint(x: bounds.minX, y: bounds.maxY))
        let firstY = waveY(x: bounds.minX, bounds: bounds, surfaceY: surfaceY,
                           amp: amp, tilt: tilt, phase: phase)
        path.addLine(to: CGPoint(x: bounds.minX, y: firstY))
        for i in 1...steps {
            let x = bounds.minX + bounds.width * CGFloat(i) / CGFloat(steps)
            let y = waveY(x: x, bounds: bounds, surfaceY: surfaceY,
                          amp: amp, tilt: tilt, phase: phase)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
        path.closeSubpath()
        return path
    }

    /// Just the crest polyline of the surface, for the meniscus highlight.
    private func surfaceCrest(bounds: CGRect, surfaceY: CGFloat, amp: CGFloat,
                              tilt: CGFloat, phase: Double) -> Path {
        var path = Path()
        let steps = 28
        let firstY = waveY(x: bounds.minX, bounds: bounds, surfaceY: surfaceY,
                           amp: amp, tilt: tilt, phase: phase)
        path.move(to: CGPoint(x: bounds.minX, y: firstY))
        for i in 1...steps {
            let x = bounds.minX + bounds.width * CGFloat(i) / CGFloat(steps)
            let y = waveY(x: x, bounds: bounds, surfaceY: surfaceY,
                          amp: amp, tilt: tilt, phase: phase)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }

    /// A thin band just below the surface that carries the moving sheen.
    private func sheenBand(bounds: CGRect, surfaceY: CGFloat, amp: CGFloat,
                           tilt: CGFloat, phase: Double) -> Path {
        var path = Path()
        let steps = 28
        let bandDepth = bounds.height * 0.08
        let firstY = waveY(x: bounds.minX, bounds: bounds, surfaceY: surfaceY,
                           amp: amp, tilt: tilt, phase: phase)
        path.move(to: CGPoint(x: bounds.minX, y: firstY))
        for i in 1...steps {
            let x = bounds.minX + bounds.width * CGFloat(i) / CGFloat(steps)
            let y = waveY(x: x, bounds: bounds, surfaceY: surfaceY,
                          amp: amp, tilt: tilt, phase: phase)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        for i in stride(from: steps, through: 0, by: -1) {
            let x = bounds.minX + bounds.width * CGFloat(i) / CGFloat(steps)
            let y = waveY(x: x, bounds: bounds, surfaceY: surfaceY,
                          amp: amp, tilt: tilt, phase: phase) + bandDepth
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.closeSubpath()
        return path
    }

    // MARK: - Chrome (border + label)

    private func chrome(state: FillState) -> some View {
        GeometryReader { geo in
            let radius = min(geo.size.width, geo.size.height) * 0.28
            ZStack {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color(red: 0.92, green: 0.92, blue: 0.96).opacity(0.9),
                                Color(red: 0.40, green: 0.42, blue: 0.48).opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: max(1.0, geo.size.height * 0.02)
                    )
                    .padding(geo.size.width * 0.03)

                label(progress: state.fill, size: geo.size)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
    }

    private func label(progress: CGFloat, size: CGSize) -> some View {
        let pct = Int((progress * 100).rounded())
        let dim = min(size.width, size.height)
        return VStack(spacing: dim * 0.04) {
            Text(progress > 0.6 ? "FILLED" : "FILL")
                .font(.system(size: dim * 0.16, weight: .heavy, design: .rounded))
                .tracking(dim * 0.02)
            Text("\(pct)%")
                .font(.system(size: dim * 0.12, weight: .semibold, design: .monospaced))
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.55), radius: dim * 0.02, x: 0, y: dim * 0.01)
        .blendMode(.overlay)
        .overlay {
            VStack(spacing: dim * 0.04) {
                Text(progress > 0.6 ? "FILLED" : "FILL")
                    .font(.system(size: dim * 0.16, weight: .heavy, design: .rounded))
                    .tracking(dim * 0.02)
                Text("\(pct)%")
                    .font(.system(size: dim * 0.12, weight: .semibold, design: .monospaced))
                    .opacity(0.6)
            }
            .foregroundStyle(.white.opacity(0.35))
        }
    }

    // MARK: - Interaction

    private func handleTap() {
        guard !demo else { return }
        // Capture the current resolved level as the new start so the pour is
        // continuous even if tapped mid-animation.
        let elapsed = max(0.0, Date().timeIntervalSince(transitionStart))
        let current = dampedOvershoot(from: fillStart, to: fillTarget, t: elapsed)
        fillStart = clamp01(current)
        fillTarget = fillTarget > 0.5 ? 0.12 : 0.95
        transitionStart = Date()
        sloshSeed = 1.0
        settledFlag = false
        scheduleSettle()
    }

    /// Fire the impact haptic once the slosh has decayed (settle), interactive only.
    private func scheduleSettle() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            guard !settledFlag else { return }
            settledFlag = true
            settleTick &+= 1
        }
    }

    // MARK: - Helpers

    private func clamp01(_ v: CGFloat) -> CGFloat { min(1.0, max(0.0, v)) }
    private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        min(hi, max(lo, v))
    }
}
