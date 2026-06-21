// catalog-id: ld-radar-sweep
import SwiftUI

// MARK: - Radar Sweep
// A rotating gradient wedge sweeps around a circular grid of range rings.
// Randomly-placed (but FIXED) blips ignite as the beam crosses them, then
// fade on a CRT-phosphor exponential decay. Brightness is a pure stateless
// function of the current sweep angle — no per-blip mutation during render.

struct RadarSweepView: View {
    var demo: Bool = false

    // Phosphor green palette (no app dependencies, literal colors only).
    private let beamColor = Color(red: 0.36, green: 1.0, blue: 0.55)
    private let gridColor = Color(red: 0.22, green: 0.62, blue: 0.40)
    private let bgInner = Color(red: 0.02, green: 0.07, blue: 0.05)
    private let bgOuter = Color(red: 0.01, green: 0.03, blue: 0.02)

    // Fixed blips: angle + radiusFraction. Generated ONCE, never per frame.
    private let blips: [Blip] = RadarSweepView.makeBlips()

    // Interactive (demo == false) scrub state.
    @State private var manualAngle: Double? = nil   // non-nil while dragging

    // Sweep tuning.
    private let degreesPerSecond: Double = 110       // ~3.3s per revolution
    private let tau: Double = 48                      // phosphor tail length in degrees

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = side * 0.46

            ZStack {
                background(radius: radius)
                TimelineView(.animation) { timeline in
                    let auto = autoAngle(at: timeline.date)
                    let angle = manualAngle ?? auto
                    scope(center: center, radius: radius, sweep: angle)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            // NOTE: `.gesture(demo ? nil : gesture)` fails to type-check on iOS 17
            // because Optional<Gesture> does not conform to Gesture. Always pass a
            // concrete gesture and mask it off in demo mode via `including:`.
            .gesture(scrubGesture(center: center), including: demo ? .subviews : .all)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Layers

    private func background(radius: CGFloat) -> some View {
        RadialGradient(
            colors: [bgInner, bgOuter],
            center: .center,
            startRadius: 0,
            endRadius: max(radius * 1.4, 1)
        )
    }

    @ViewBuilder
    private func scope(center: CGPoint, radius: CGFloat, sweep: Double) -> some View {
        ZStack {
            rangeRings(center: center, radius: radius)
            crosshair(center: center, radius: radius)
            blipLayer(center: center, radius: radius, sweep: sweep)
            beam(center: center, radius: radius, sweep: sweep)
            hub(center: center, radius: radius)
        }
        .clipShape(Circle().path(in: scopeRect(center: center, radius: radius)))
        .overlay(
            Circle()
                .stroke(gridColor.opacity(0.9), lineWidth: 1.5)
                .frame(width: radius * 2, height: radius * 2)
                .position(center)
        )
    }

    private func scopeRect(center: CGPoint, radius: CGFloat) -> CGRect {
        CGRect(x: center.x - radius, y: center.y - radius,
               width: radius * 2, height: radius * 2)
    }

    // Concentric range rings.
    private func rangeRings(center: CGPoint, radius: CGFloat) -> some View {
        ForEach(1..<4, id: \.self) { i in
            let frac = CGFloat(i) / 4.0
            Circle()
                .stroke(gridColor.opacity(0.30), lineWidth: 1)
                .frame(width: radius * 2 * frac, height: radius * 2 * frac)
                .position(center)
        }
    }

    // Crosshair: four lines at 0/45/90/135 degrees through the center.
    private func crosshair(center: CGPoint, radius: CGFloat) -> some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                Rectangle()
                    .fill(gridColor.opacity(0.22))
                    .frame(width: radius * 2, height: 1)
                    .rotationEffect(.degrees(Double(i) * 45))
                    .position(center)
            }
        }
    }

    // The rotating gradient wedge (transparent -> green) trailing the leading edge.
    private func beam(center: CGPoint, radius: CGFloat, sweep: Double) -> some View {
        let grad = AngularGradient(
            gradient: Gradient(stops: [
                .init(color: beamColor.opacity(0.0), location: 0.0),
                .init(color: beamColor.opacity(0.05), location: 0.55),
                .init(color: beamColor.opacity(0.22), location: 0.86),
                .init(color: beamColor.opacity(0.55), location: 0.99),
                .init(color: beamColor.opacity(0.0), location: 1.0)
            ]),
            center: .center
        )
        return ZStack {
            // Soft wedge fill rotated to the sweep angle.
            Circle()
                .fill(grad)
                .frame(width: radius * 2, height: radius * 2)
                .rotationEffect(.degrees(sweep), anchor: .center)
                .position(center)
            // Crisp leading edge line of the sweep.
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [beamColor.opacity(0.0), beamColor.opacity(0.95)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(width: radius, height: 2)
                .offset(x: radius / 2)
                .rotationEffect(.degrees(sweep), anchor: .center)
                .position(center)
                .shadow(color: beamColor.opacity(0.6), radius: 4)
        }
        .compositingGroup()
    }

    // Blips drawn in a single Canvas; brightness = phosphor decay of the sweep.
    private func blipLayer(center: CGPoint, radius: CGFloat, sweep: Double) -> some View {
        Canvas { ctx, _ in
            for blip in blips {
                let bright = brightness(for: blip.angle, sweep: sweep)
                let p = point(center: center, radius: radius, blip: blip)
                drawBlip(ctx: &ctx, at: p, brightness: bright, size: blip.size)
            }
        }
    }

    private func drawBlip(ctx: inout GraphicsContext, at p: CGPoint,
                          brightness: Double, size: CGFloat) {
        let glow = size * (1.4 + 2.2 * brightness)
        let glowRect = CGRect(x: p.x - glow, y: p.y - glow, width: glow * 2, height: glow * 2)
        let coreRect = CGRect(x: p.x - size, y: p.y - size, width: size * 2, height: size * 2)

        // Soft halo.
        ctx.fill(
            Circle().path(in: glowRect),
            with: .radialGradient(
                Gradient(colors: [
                    beamColor.opacity(0.45 * brightness),
                    beamColor.opacity(0.0)
                ]),
                center: p, startRadius: 0, endRadius: glow
            )
        )
        // Bright core (with a faint resting floor so it stays legible).
        ctx.fill(
            Circle().path(in: coreRect),
            with: .color(beamColor.opacity(0.20 + 0.80 * brightness))
        )
    }

    private func hub(center: CGPoint, radius: CGFloat) -> some View {
        let d = max(4, radius * 0.05)
        return Circle()
            .fill(beamColor.opacity(0.9))
            .frame(width: d, height: d)
            .shadow(color: beamColor.opacity(0.8), radius: 4)
            .position(center)
    }

    // MARK: Math (stateless phosphor decay)

    private func autoAngle(at date: Date) -> Double {
        let t = date.timeIntervalSinceReferenceDate
        return (t * degreesPerSecond).truncatingRemainder(dividingBy: 360)
    }

    // How far (in degrees, 0..<360) the beam has swept *past* this blip.
    // small lag -> just illuminated (bright); near 360 -> about to be hit again (dim).
    private func brightness(for blipAngle: Double, sweep: Double) -> Double {
        var lag = (sweep - blipAngle).truncatingRemainder(dividingBy: 360)
        if lag < 0 { lag += 360 }
        let decay = exp(-lag / tau)
        return max(decay, 0.06)   // resting floor keeps blips faintly visible
    }

    private func point(center: CGPoint, radius: CGFloat, blip: Blip) -> CGPoint {
        let r = radius * blip.radiusFraction
        let rad: CGFloat = CGFloat(blip.angle) * .pi / 180
        return CGPoint(x: center.x + r * cos(rad), y: center.y + r * sin(rad))
    }

    // MARK: Interaction (demo == false): drag to scrub, release resumes auto.

    private func scrubGesture(center: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let dx = value.location.x - center.x
                let dy = value.location.y - center.y
                var deg = atan2(dy, dx) * 180 / .pi
                if deg < 0 { deg += 360 }
                manualAngle = deg
            }
            .onEnded { _ in
                manualAngle = nil   // resume self-driving sweep
            }
    }

    // MARK: Fixed blip generation (ONCE, at init — never per frame).

    struct Blip {
        let angle: Double          // degrees, 0..<360
        let radiusFraction: CGFloat
        let size: CGFloat
    }

    private static func makeBlips() -> [Blip] {
        // Deterministic seeded generator so positions are fixed and never teleport.
        var rng = SeededGenerator(seed: 0xC0FFEE)
        var result: [Blip] = []
        for _ in 0..<7 {
            let angle = Double.random(in: 0..<360, using: &rng)
            let frac = CGFloat(Double.random(in: 0.22...0.92, using: &rng))
            let size = CGFloat(Double.random(in: 2.2...4.0, using: &rng))
            result.append(Blip(angle: angle, radiusFraction: frac, size: size))
        }
        return result
    }

    struct SeededGenerator: RandomNumberGenerator {
        private var state: UInt64
        init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }
}
