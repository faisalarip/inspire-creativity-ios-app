// catalog-id: btn-piston-pump
import SwiftUI

// MARK: - Piston Pump
// Hold-to-confirm. A mechanical piston pumps up and down, each stroke building
// pressure in a gauge. The longer you hold, the faster the piston cycles and the
// more the gauge fills, until it redlines and fires. Release early drains it back.
//
// Architecture: ONE TimelineView(.animation) drives a fileprivate integrator
// (PistonPumpView_PistonPumpSim) so the piston oscillation and the gauge fill share a single
// clock — cadence stays perfectly synced. The piston frequency rises with held
// progress, and we integrate PHASE (not scaled time) so the stroke never jumps
// when the speed changes mid-cycle.

struct PistonPumpView: View {
    var demo: Bool = false

    @State private var sim = PistonPumpView_PistonPumpSim()
    @State private var pressing: Bool = false
    @State private var fireTick: Int = 0
    @State private var drainTick: Int = 0

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)

            TimelineView(.animation) { timeline in
                // Advance the simulation off a single clock. All per-frame mutable
                // state lives on the class (safe to mutate here — no @State writes
                // inside the view-update closure).
                let snapshot = sim.advance(
                    date: timeline.date,
                    demo: demo,
                    pressing: pressing
                )

                PistonPumpView_PistonPumpScene(
                    state: snapshot,
                    side: side
                )
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .modifier(
                PistonPumpView_PistonInteraction(
                    demo: demo,
                    pressing: $pressing,
                    fireTick: $fireTick,
                    drainTick: $drainTick
                )
            )
            .sensoryFeedback(.success, trigger: demo ? 0 : fireTick)
            .sensoryFeedback(.impact(weight: .light), trigger: demo ? 0 : drainTick)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Interaction (interactive vs. demo)

/// The long-press `onPressingChanged:` callback is the only reliable "while held"
/// signal on iOS 17 — a bare LongPressGesture fires once at the end and cannot
/// drive rising progress. `perform` fires at the redline moment (~2.5s) where
/// bumping a @State trigger is safe. Demo mode attaches no gesture and no haptics.
private struct PistonPumpView_PistonInteraction: ViewModifier {
    let demo: Bool
    @Binding var pressing: Bool
    @Binding var fireTick: Int
    @Binding var drainTick: Int

    func body(content: Content) -> some View {
        if demo {
            content
        } else {
            content.onLongPressGesture(
                minimumDuration: 2.5,
                maximumDistance: 60,
                perform: {
                    fireTick &+= 1
                },
                onPressingChanged: { isPressing in
                    if !isPressing && pressing {
                        // Released before redline -> gauge will drain.
                        drainTick &+= 1
                    }
                    pressing = isPressing
                }
            )
        }
    }
}

// MARK: - Simulation

/// Held on the view as @State (value-type box around a reference). All per-frame
/// mutation happens here, off the SwiftUI state graph, which is the standard
/// pattern for TimelineView-driven sims.
private struct PistonPumpView_PistonPumpSim {
    private let core = Core()

    func advance(date: Date, demo: Bool, pressing: Bool) -> PistonPumpView_PistonState {
        core.advance(date: date, demo: demo, pressing: pressing)
    }

    final class Core {
        private var lastT: TimeInterval?
        private var progress: CGFloat = 0      // 0...1 pressure
        private var pistonPhase: CGFloat = 0   // integrated angle (radians)
        private var fired: Bool = false
        private var holdAfterFire: CGFloat = 0 // brief redline-pop dwell
        private var flash: CGFloat = 0         // 0...1 fire flash

        // Demo auto-cycle: a phantom hold that builds, fires, pops, resets.
        private var demoClock: TimeInterval = 0

        func advance(date: Date, demo: Bool, pressing: Bool) -> PistonPumpView_PistonState {
            let now = date.timeIntervalSinceReferenceDate
            let raw = lastT.map { now - $0 } ?? 0
            lastT = now
            // Clamp dt so a backgrounded/first frame doesn't fast-forward the sim.
            let dt = CGFloat(max(0.0, min(raw, 1.0 / 30.0)))

            let held: Bool
            if demo {
                held = updateDemo(dt: dt)
            } else {
                held = pressing
            }

            updatePressure(dt: dt, held: held)
            integratePiston(dt: dt)
            updateFire(dt: dt)

            return PistonPumpView_PistonState(
                progress: progress,
                pistonOffset: sin(pistonPhase),     // -1...1, used by scene
                flash: flash,
                fired: fired,
                redlined: progress >= 0.999
            )
        }

        // Phantom hold on a ~3.4s loop: hold ~2.6s (build + redline pop), then
        // release and let it drain, never blanking — idle state stays legible.
        private func updateDemo(dt: CGFloat) -> Bool {
            demoClock += TimeInterval(dt)
            let loop: TimeInterval = 3.4
            if demoClock >= loop {
                demoClock -= loop
                fired = false
                holdAfterFire = 0
            }
            // Hold for the first 2.6s of the loop, then release.
            return demoClock < 2.6
        }

        private func updatePressure(dt: CGFloat, held: Bool) {
            if fired {
                // Hold the redline briefly, then bleed off after the pop.
                holdAfterFire += dt
                if holdAfterFire > 0.45 {
                    progress = max(0, progress - dt * 1.6)
                    if progress <= 0.001 {
                        fired = false
                        holdAfterFire = 0
                    }
                }
                return
            }

            if held {
                // Fill so progress ~ 1 at ~2.5s (the long-press redline moment).
                // Slight ease so the last bit feels like it's straining.
                let rate: CGFloat = 0.40 + progress * 0.10
                progress = min(1, progress + dt * rate)
                if progress >= 0.999 {
                    fired = true
                    flash = 1
                    holdAfterFire = 0
                }
            } else {
                // Released early -> drain back down, faster than it filled.
                progress = max(0, progress - dt * 0.95)
            }
        }

        // Integrate phase, never scale time. Frequency rises with progress so the
        // piston visibly accelerates, but offset = sin(phase) stays continuous —
        // no teleport when the speed changes mid-stroke.
        private func integratePiston(dt: CGFloat) {
            let minHz: CGFloat = 0.9
            let maxHz: CGFloat = 5.2
            // Even at rest the piston idles slowly so the tile is never frozen.
            let activity = max(progress, fired ? 1 : 0.18)
            let hz = minHz + (maxHz - minHz) * activity
            pistonPhase += dt * hz * 2 * .pi
            if pistonPhase > 2 * .pi { pistonPhase -= 2 * .pi }
        }

        private func updateFire(dt: CGFloat) {
            if flash > 0 {
                flash = max(0, flash - dt * 2.2)
            }
        }
    }
}

private struct PistonPumpView_PistonState {
    var progress: CGFloat
    var pistonOffset: CGFloat   // -1...1
    var flash: CGFloat          // 0...1
    var fired: Bool
    var redlined: Bool
}

// MARK: - Scene

private struct PistonPumpView_PistonPumpScene: View {
    let state: PistonPumpView_PistonState
    let side: CGFloat

    private var accent: Color {
        // Cool steel-blue ramping toward hot redline as pressure builds.
        let p = state.progress
        return Color(
            red: 0.28 + 0.62 * Double(p),
            green: 0.55 - 0.30 * Double(p),
            blue: 0.78 - 0.55 * Double(p)
        )
    }

    var body: some View {
        ZStack {
            background
            PistonPumpView_GaugeArc(progress: state.progress, side: side)
                .frame(width: side * 0.86, height: side * 0.86)
            PistonPumpView_PistonAssembly(
                offset: state.pistonOffset,
                progress: state.progress,
                redlined: state.redlined,
                accent: accent
            )
            .frame(width: side * 0.50, height: side * 0.66)

            centerLabel
            flashOverlay
        }
        .frame(width: side, height: side)
        .compositingGroup()
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: side * 0.20, style: .continuous)
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 0.16, green: 0.17, blue: 0.20),
                        Color(red: 0.07, green: 0.075, blue: 0.09)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: side * 0.7
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: side * 0.20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: side * 0.012)
            )
            .frame(width: side, height: side)
    }

    private var centerLabel: some View {
        let symbol = state.fired ? "checkmark" : "bolt.fill"
        return Image(systemName: symbol)
            .font(.system(size: side * 0.12, weight: .heavy))
            .foregroundStyle(state.fired ? Color(red: 0.45, green: 0.95, blue: 0.55) : accent)
            .opacity(0.0)            // hidden behind piston cap; kept for fired glow
            .allowsHitTesting(false)
            .overlay(alignment: .bottom) {
                Text(state.fired ? "FIRED" : (state.redlined ? "REDLINE" : "HOLD"))
                    .font(.system(size: side * 0.075, weight: .bold, design: .rounded))
                    .tracking(side * 0.012)
                    .foregroundStyle(labelColor)
                    .offset(y: side * 0.40)
            }
    }

    private var labelColor: Color {
        if state.fired { return Color(red: 0.50, green: 0.95, blue: 0.60) }
        if state.redlined { return Color(red: 0.96, green: 0.34, blue: 0.30) }
        return Color.white.opacity(0.55)
    }

    private var flashOverlay: some View {
        RoundedRectangle(cornerRadius: side * 0.20, style: .continuous)
            .fill(Color(red: 1.0, green: 0.95, blue: 0.7))
            .opacity(Double(state.flash) * 0.55)
            .blendMode(.screen)
            .allowsHitTesting(false)
            .frame(width: side, height: side)
    }
}

// MARK: - Gauge arc

private struct PistonPumpView_GaugeArc: View {
    let progress: CGFloat
    let side: CGFloat

    var body: some View {
        ZStack {
            // Track
            Circle()
                .trim(from: 0.0, to: 0.75)
                .stroke(
                    Color.white.opacity(0.10),
                    style: StrokeStyle(lineWidth: trackWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(135))

            // Filled pressure
            Circle()
                .trim(from: 0.0, to: 0.75 * progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color(red: 0.30, green: 0.62, blue: 0.92), location: 0.0),
                            .init(color: Color(red: 0.40, green: 0.85, blue: 0.70), location: 0.45),
                            .init(color: Color(red: 0.95, green: 0.78, blue: 0.25), location: 0.78),
                            .init(color: Color(red: 0.95, green: 0.28, blue: 0.22), location: 1.0)
                        ]),
                        center: .center,
                        startAngle: .degrees(135),
                        endAngle: .degrees(135 + 270)
                    ),
                    style: StrokeStyle(lineWidth: fillWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(135))
                .shadow(color: glowColor.opacity(Double(min(progress, 1)) * 0.8),
                        radius: fillWidth * 0.9)

            // Redline zone marker (last ~15% of the sweep)
            Circle()
                .trim(from: 0.75 * 0.86, to: 0.75)
                .stroke(
                    Color(red: 0.95, green: 0.25, blue: 0.20).opacity(progress >= 0.999 ? 0.95 : 0.30),
                    style: StrokeStyle(lineWidth: trackWidth * 0.4, lineCap: .butt)
                )
                .rotationEffect(.degrees(135))
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // Scale stroke widths off the tile size so the gauge reads correctly in both
    // a ~120pt grid tile and a large detail view (no fixed-pixel hairlines).
    private var trackWidth: CGFloat { max(2.5, side * 0.026) }
    private var fillWidth: CGFloat { max(3, side * 0.032) }

    private var glowColor: Color {
        progress >= 0.999
            ? Color(red: 0.95, green: 0.30, blue: 0.22)
            : Color(red: 0.35, green: 0.70, blue: 0.90)
    }
}

// MARK: - Piston assembly

private struct PistonPumpView_PistonAssembly: View {
    let offset: CGFloat       // -1...1 from sin(phase)
    let progress: CGFloat
    let redlined: Bool
    let accent: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cylinderH = h * 0.78
            let cylinderW = w * 0.62
            // Stroke pushes the head down within the cylinder as it pumps.
            let travel = cylinderH * 0.30
            // Map sin(-1...1) -> 0...1 downstroke fraction.
            let down = (offset + 1) / 2
            let headY = -travel * 0.5 + travel * down

            ZStack {
                // Cylinder body
                RoundedRectangle(cornerRadius: cylinderW * 0.18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.30, green: 0.31, blue: 0.35),
                                Color(red: 0.14, green: 0.15, blue: 0.18)
                            ],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cylinderW * 0.18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .frame(width: cylinderW, height: cylinderH)

                // Compressed-gas glow at the base, brighter under pressure.
                Capsule()
                    .fill(accent)
                    .frame(width: cylinderW * 0.7, height: cylinderH * 0.26)
                    .blur(radius: cylinderW * 0.18)
                    .opacity(0.25 + Double(progress) * 0.65)
                    .offset(y: cylinderH * 0.30)

                // Connecting rod
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.78, green: 0.80, blue: 0.86),
                                Color(red: 0.45, green: 0.47, blue: 0.52)
                            ],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: cylinderW * 0.22, height: cylinderH * 0.95)
                    .offset(y: headY)

                // Piston head / cap
                pistonHead(width: cylinderW * 0.82)
                    .offset(y: headY - cylinderH * 0.30)
            }
            .frame(width: w, height: h)
            .position(x: w / 2, y: h / 2)
        }
    }

    private func pistonHead(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: width * 0.22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.92, green: 0.93, blue: 0.97),
                        Color(red: 0.55, green: 0.57, blue: 0.63)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: width * 0.22, style: .continuous)
                    .stroke(accent.opacity(redlined ? 0.9 : 0.45), lineWidth: redlined ? 2.5 : 1.2)
            )
            .frame(width: width, height: width * 0.42)
            .shadow(color: accent.opacity(Double(progress) * 0.7), radius: width * 0.12)
    }
}
