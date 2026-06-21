// catalog-id: ges-hold-charge-burst
import SwiftUI

// MARK: - Hold-to-Charge Burst
//
// Press and hold to charge a core that pulses, swells, and accumulates
// orbiting energy rings; release fires a particle burst whose size scales
// with how long you held.
//
// Architecture (per design review):
//  - A single always-on TimelineView(.animation) drives BOTH the auto demo
//    loop and the real interactive component.
//  - Charge is TIME-driven (elapsed since pressStart), never delta-driven,
//    so a perfectly still hold still charges.
//  - All @State writes happen only in gesture callbacks; the timeline closure
//    is a pure function of (now, pressStart, burstStart, chargeAtRelease).
//  - Particle randomness is precomputed once per index (deterministic), so the
//    burst is a coherent explosion rather than per-frame noise.
//  - Pulse uses a fixed frequency with charge-driven amplitude (no
//    instantaneous-frequency seam stutter).
public struct HoldChargeBurstView: View {
    public var demo: Bool = false

    // Interactive state — written ONLY in gesture callbacks.
    @State private var pressStart: Date? = nil
    @State private var burstStart: Date? = nil
    @State private var chargeAtRelease: Double = 0

    public init(demo: Bool = false) {
        self.demo = demo
    }

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let side = min(size.width, size.height)

            TimelineView(.animation) { timeline in
                let now = timeline.date
                let frame = makeFrame(now: now)

                ChargeBurstScene(state: frame, side: side)
                    .frame(width: size.width, height: size.height)
            }
            .contentShape(Rectangle())
            // iOS-17-safe gesture wiring: the `including:` mask disables this
            // gesture in demo (no subview gestures exist, so nothing fires and
            // no @State is written), and enables it in interactive mode.
            .gesture(chargeGesture, including: demo ? .subviews : .all)
            // Escalating haptic per charge band (interactive only).
            .modifier(
                ChargeHaptics(
                    enabled: !demo,
                    band: liveChargeBand,
                    burstStart: burstStart
                )
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    // MARK: Gesture

    private var chargeGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                // Fire once per press: start the charge clock. onChanged may
                // never fire again if the finger holds still — that's fine,
                // charge is derived from elapsed time, not deltas.
                if pressStart == nil {
                    pressStart = Date()
                    burstStart = nil
                }
            }
            .onEnded { _ in
                if let start = pressStart {
                    let held = Date().timeIntervalSince(start)
                    chargeAtRelease = charge(forHeld: held)
                }
                pressStart = nil
                burstStart = Date()
            }
    }

    // Live charge band for haptics — pure derivation, fires on band crossings.
    private var liveChargeBand: Int {
        guard !demo, let start = pressStart else { return 0 }
        let held = Date().timeIntervalSince(start)
        return Int(charge(forHeld: held) * 5.0)
    }

    // MARK: Frame model

    /// Computes the full visual state for `now`, branching on demo vs interactive.
    private func makeFrame(now: Date) -> ChargeState {
        if demo {
            return demoState(now: now)
        } else {
            return interactiveState(now: now)
        }
    }

    /// Demo path: a pure function of the timeline date. No phase @State.
    private func demoState(now: Date) -> ChargeState {
        let loop: Double = 3.4
        let t = now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: loop)

        let chargeWindow: Double = 2.2   // build-up
        let burstWindow: Double = 1.0    // explosion + reform
        // (small idle tail fills the remainder of the loop)

        var charge: Double = 0
        var burstProgress: Double = -1   // <0 => not bursting
        var pulsePhase: Double = now.timeIntervalSinceReferenceDate

        if t < chargeWindow {
            // Ease-in build so the swell feels like accumulating strain.
            let p = t / chargeWindow
            charge = easeInOut(p)
        } else if t < chargeWindow + burstWindow {
            // Hold peak charge as the burst plays; core re-forms within it.
            charge = 1.0
            burstProgress = (t - chargeWindow) / burstWindow
        } else {
            charge = 0
        }

        // Keep pulse phase continuous and seam-safe (fixed frequency).
        pulsePhase = now.timeIntervalSinceReferenceDate

        return ChargeState(
            charge: charge,
            burstProgress: burstProgress,
            burstCharge: 1.0,
            pulsePhase: pulsePhase
        )
    }

    /// Interactive path: derived purely from Date/Double @State + now.
    private func interactiveState(now: Date) -> ChargeState {
        let burstWindow: Double = 1.1
        let pulsePhase = now.timeIntervalSinceReferenceDate

        // Bursting takes precedence and is finite.
        if let bStart = burstStart {
            let bt = now.timeIntervalSince(bStart)
            if bt < burstWindow {
                return ChargeState(
                    charge: 0,
                    burstProgress: bt / burstWindow,
                    burstCharge: chargeAtRelease,
                    pulsePhase: pulsePhase
                )
            }
            // Burst finished — fall through to idle WITHOUT writing state.
            return ChargeState(
                charge: 0,
                burstProgress: -1,
                burstCharge: chargeAtRelease,
                pulsePhase: pulsePhase
            )
        }

        // Charging: charge grows with elapsed hold time (still-hold safe).
        if let pStart = pressStart {
            let held = now.timeIntervalSince(pStart)
            return ChargeState(
                charge: charge(forHeld: held),
                burstProgress: -1,
                burstCharge: 0,
                pulsePhase: pulsePhase
            )
        }

        // Idle.
        return ChargeState(
            charge: 0,
            burstProgress: -1,
            burstCharge: 0,
            pulsePhase: pulsePhase
        )
    }

    // MARK: Helpers

    /// Maps a held duration (seconds) to a clamped 0...1 charge with ease-in.
    private func charge(forHeld held: Double) -> Double {
        let full: Double = 1.8 // seconds to fully charge
        let raw = min(max(held / full, 0), 1)
        return easeInOut(raw)
    }

    private func easeInOut(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        return c * c * (3.0 - 2.0 * c)
    }
}

// MARK: - Visual state passed each frame

private struct ChargeState {
    var charge: Double          // 0...1 current charge (drives swell/rings)
    var burstProgress: Double   // <0 = not bursting, else 0...1
    var burstCharge: Double     // 0...1 charge captured at release (burst size)
    var pulsePhase: Double      // continuous time for pulse oscillation
}

// MARK: - Scene renderer

private struct ChargeBurstScene: View {
    let state: ChargeState
    let side: CGFloat

    var body: some View {
        ZStack {
            background
            orbitingRings
            coreView
            burstCanvas
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var isBursting: Bool { state.burstProgress >= 0 }

    // Charge color ramps from cool teal to hot magenta as it builds.
    private func chargeColor(_ c: Double) -> Color {
        let t = min(max(c, 0), 1)
        let r = 0.30 + 0.62 * t
        let g = 0.78 - 0.40 * t
        let b = 0.92 - 0.30 * t
        return Color(red: r, green: g, blue: b)
    }

    // MARK: Layers

    private var background: some View {
        let glow = chargeColor(max(state.charge, isBursting ? state.burstCharge * 0.6 : 0))
        let intensity = isBursting ? 0.18 : (0.08 + 0.20 * state.charge)
        return RadialGradient(
            colors: [
                glow.opacity(intensity),
                Color(red: 0.05, green: 0.05, blue: 0.09).opacity(0.0)
            ],
            center: .center,
            startRadius: 0,
            endRadius: side * 0.55
        )
        .blendMode(.plusLighter)
    }

    private var coreView: some View {
        // The core is ALWAYS visible: it never fades through zero. During a
        // burst it re-forms (scales up from a small idle size) instead of
        // disappearing, guaranteeing no blank frame at the loop seam.
        let baseRadius = side * 0.085
        let swell = 1.0 + 0.85 * state.charge
        // Fixed-frequency pulse, charge-driven amplitude (seam-safe).
        let pulseAmp = 0.04 + 0.16 * state.charge
        let pulse = 1.0 + pulseAmp * sin(state.pulsePhase * 6.0)

        var scale = swell * pulse

        if isBursting {
            // Core flashes outward then re-forms small -> grows back.
            let p = state.burstProgress
            let reform = reformScale(p)
            scale = reform
        }

        let radius = baseRadius * scale
        let c = chargeColor(state.charge)
        let hot = chargeColor(min(state.charge + 0.25, 1.0))

        return ZStack {
            // Soft halo
            Circle()
                .fill(c.opacity(0.35))
                .frame(width: radius * 2.6, height: radius * 2.6)
                .blur(radius: side * 0.03)

            // Solid core
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 1, green: 1, blue: 1), hot, c],
                        center: .center,
                        startRadius: 0,
                        endRadius: radius
                    )
                )
                .frame(width: radius * 2, height: radius * 2)
                .overlay(
                    Circle()
                        .strokeBorder(Color(red: 1, green: 1, blue: 1).opacity(0.55), lineWidth: side * 0.006)
                        .frame(width: radius * 2, height: radius * 2)
                )
                .shadow(color: c.opacity(0.8), radius: side * 0.05 * (0.4 + state.charge))
        }
    }

    /// Core scale during burst: a quick flash-out, then re-form from small.
    private func reformScale(_ p: Double) -> Double {
        if p < 0.18 {
            // Flash outward
            return 1.0 + 3.5 * (p / 0.18)
        } else {
            // Re-form: shrink to a small seed then ease back to idle size.
            let q = (p - 0.18) / 0.82
            let seed = 0.25
            return seed + (1.0 - seed) * easeOut(q)
        }
    }

    // Orbiting energy rings — count and brightness grow with charge.
    private var orbitingRings: some View {
        let ringCount = Int((state.charge * 4.0).rounded(.down)) // 0...4
        let baseR = side * 0.14
        let c = chargeColor(state.charge)
        let spin = state.pulsePhase

        return ZStack {
            ForEach(0..<max(ringCount, 0), id: \.self) { i in
                let idx = Double(i)
                let ringRadius = baseR + idx * side * 0.055
                let tilt = 18.0 + idx * 26.0
                let speed = 1.2 + idx * 0.5
                let opacity = isBursting ? 0.0 : (0.65 - 0.1 * idx)

                Ellipse()
                    .strokeBorder(c.opacity(opacity), lineWidth: side * 0.012)
                    .frame(width: ringRadius * 2, height: ringRadius * 2 * 0.42)
                    .rotation3DEffect(
                        .degrees(tilt),
                        axis: (x: 1, y: 0.35, z: 0)
                    )
                    .rotationEffect(.radians(spin * speed))
                    .overlay(orbitDot(ringRadius: ringRadius, spin: spin * speed, color: c, opacity: opacity))
            }
        }
    }

    private func orbitDot(ringRadius: CGFloat, spin: Double, color: Color, opacity: Double) -> some View {
        let dotSize = side * 0.028
        let x = cos(spin) * ringRadius
        let y = sin(spin) * ringRadius * 0.42
        return Circle()
            .fill(color.opacity(opacity + 0.2))
            .frame(width: dotSize, height: dotSize)
            .shadow(color: color.opacity(opacity), radius: side * 0.02)
            .offset(x: x, y: y)
            .rotation3DEffect(.degrees(0), axis: (x: 1, y: 0, z: 0))
    }

    // Particle burst — Canvas, sized by captured charge.
    private var burstCanvas: some View {
        Canvas { ctx, canvasSize in
            guard isBursting else { return }
            let p = state.burstProgress
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let maxReach = side * (0.30 + 0.55 * state.burstCharge)
            let particleCount = 14 + Int(state.burstCharge * 22) // 14...36
            let baseColor = chargeColor(min(state.burstCharge + 0.2, 1.0))

            let eased = easeOutCubic(p)
            let fade = 1.0 - smoothFade(p)

            for i in 0..<particleCount {
                let seed = BurstParticles.seeds[i % BurstParticles.seeds.count]
                let angle = seed.angle
                let speed = seed.speed
                let sizeJitter = seed.sizeJitter

                let dist = maxReach * speed * eased
                let x = center.x + cos(angle) * dist
                let y = center.y + sin(angle) * dist

                let pSize = side * (0.014 + 0.02 * sizeJitter) * (1.0 - 0.4 * eased)
                let rect = CGRect(
                    x: x - pSize / 2,
                    y: y - pSize / 2,
                    width: pSize,
                    height: pSize
                )

                var sub = ctx
                sub.opacity = fade
                sub.addFilter(.blur(radius: side * 0.004))
                sub.fill(Path(ellipseIn: rect), with: .color(baseColor.opacity(0.9)))

                // Trailing spark line for energy streaking outward.
                if i % 3 == 0 {
                    var line = Path()
                    let tailDist = dist - maxReach * speed * 0.12
                    let tx = center.x + cos(angle) * max(tailDist, 0)
                    let ty = center.y + sin(angle) * max(tailDist, 0)
                    line.move(to: CGPoint(x: tx, y: ty))
                    line.addLine(to: CGPoint(x: x, y: y))
                    var ls = ctx
                    ls.opacity = fade * 0.7
                    ls.stroke(
                        line,
                        with: .color(baseColor.opacity(0.8)),
                        style: StrokeStyle(lineWidth: pSize * 0.6, lineCap: .round)
                    )
                }
            }

            // Expanding shockwave ring.
            let ringR = maxReach * eased * 1.05
            let ringRect = CGRect(
                x: center.x - ringR,
                y: center.y - ringR,
                width: ringR * 2,
                height: ringR * 2
            )
            var ring = ctx
            ring.opacity = (1.0 - eased) * 0.8
            ring.stroke(
                Path(ellipseIn: ringRect),
                with: .color(Color(red: 1, green: 1, blue: 1).opacity(0.9)),
                style: StrokeStyle(lineWidth: side * 0.01 * (1.0 - eased) + side * 0.002)
            )
        }
        .allowsHitTesting(false)
    }

    // MARK: Easing

    private func easeOut(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        return 1 - (1 - c) * (1 - c)
    }

    private func easeOutCubic(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        let inv = 1 - c
        return 1 - inv * inv * inv
    }

    /// Fade-out of burst particles toward the end of the burst window.
    private func smoothFade(_ p: Double) -> Double {
        let start = 0.55
        guard p > start else { return 0 }
        let q = (p - start) / (1.0 - start)
        return min(max(q, 0), 1)
    }
}

// MARK: - Deterministic precomputed particle seeds
//
// Generated ONCE at type-load with a fixed seed so the burst is a coherent
// explosion. Never call random() inside the per-frame Canvas closure.
private enum BurstParticles {
    struct Seed {
        let angle: Double
        let speed: Double
        let sizeJitter: Double
    }

    static let seeds: [Seed] = {
        var rng = SplitMix64(seed: 0x9E3779B97F4A7C15)
        var out: [Seed] = []
        let count = 40
        for i in 0..<count {
            // Spread base angle evenly, then jitter for organic look.
            let base = (Double(i) / Double(count)) * 2.0 * .pi
            let jitter = (rng.nextDouble() - 0.5) * (2.0 * .pi / Double(count)) * 1.6
            let angle = base + jitter
            let speed = 0.55 + rng.nextDouble() * 0.45      // 0.55...1.0
            let sizeJitter = rng.nextDouble()               // 0...1
            out.append(Seed(angle: angle, speed: speed, sizeJitter: sizeJitter))
        }
        return out
    }()
}

// Tiny deterministic PRNG so seeds are stable & reproducible.
private struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func nextDouble() -> Double {
        return Double(next() >> 11) * (1.0 / 9007199254740992.0)
    }
}

// MARK: - Haptics modifier
//
// Two distinct triggers, both gated on the interactive path:
//  - escalating .impact on charge-band crossings
//  - .success once on release (burstStart changes exactly once)
private struct ChargeHaptics: ViewModifier {
    let enabled: Bool
    let band: Int
    let burstStart: Date?

    func body(content: Content) -> some View {
        content
            .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: enabled ? band : 0)
            .sensoryFeedback(.success, trigger: burstTriggerValue)
    }

    // Changes exactly once per release; stays constant otherwise.
    private var burstTriggerValue: Int {
        guard enabled, let s = burstStart else { return 0 }
        return Int(s.timeIntervalSinceReferenceDate)
    }
}
