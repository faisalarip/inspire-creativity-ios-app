// catalog-id: ld-comet-trail-orbit
import SwiftUI

/// Comet Trail — a bright comet head laps an elliptical orbit, accelerating at
/// perihelion (Kepler), trailing a tapering particle tail that always streams
/// radially away from the focal "sun" (solar-wind motif). Fully self-driving;
/// `demo` does not change behavior because the spec's interaction is "auto".
struct CometTrailOrbitView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { _ in
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    drawScene(in: &context, size: size, time: t)
                }
            }
        }
        .background(background)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Tunables

    private let period: Double = 3.4          // seconds per lap
    private let eccentricity: CGFloat = 0.62  // ellipse + speed variation
    private let trailCount: Int = 46          // particles in the tail
    private let trailStep: Double = 0.018     // time gap between particles (s)
    private let pushDistance: CGFloat = 0.10  // radial anti-focus push per age unit

    private var background: some View {
        // Deep space gradient so the glow reads on the tile and the detail view.
        RadialGradient(
            colors: [
                Color(red: 0.07, green: 0.09, blue: 0.16),
                Color(red: 0.03, green: 0.04, blue: 0.08)
            ],
            center: .center,
            startRadius: 4,
            endRadius: 260
        )
    }

    // MARK: - Geometry

    struct Orbit {
        var center: CGPoint
        var a: CGFloat      // semi-major (x)
        var b: CGFloat      // semi-minor (y)
        var focus: CGPoint  // the "sun"
        var unit: CGFloat   // base size unit for scaling visuals
    }

    private func makeOrbit(size: CGSize) -> Orbit {
        let unit = min(size.width, size.height)
        // Leave margin so the head never clips at aphelion, even in a 120pt tile.
        let a = unit * 0.34
        let b = a * sqrt(max(0.0001, 1 - Double(eccentricity) * Double(eccentricity)))
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let c = a * eccentricity                    // center-to-focus distance
        let focus = CGPoint(x: center.x + c, y: center.y)
        return Orbit(center: center, a: a, b: b, focus: focus, unit: unit)
    }

    /// Solve Kepler's equation M = E - e·sinE for the eccentric anomaly E.
    private func solveE(meanAnomaly M: Double) -> Double {
        let e = Double(eccentricity)
        var E = M
        for _ in 0..<5 {
            let f = E - e * sin(E) - M
            let fp = 1 - e * cos(E)
            E -= f / fp
        }
        return E
    }

    /// Position on the orbit for an absolute time, using a Kepler time mapping.
    private func orbitPos(time: Double, orbit: Orbit) -> CGPoint {
        let M = 2 * Double.pi * (time / period)
        let E = solveE(meanAnomaly: M)
        let x = orbit.center.x + orbit.a * CGFloat(cos(E))
        let y = orbit.center.y + orbit.b * CGFloat(sin(E))
        return CGPoint(x: x, y: y)
    }

    // MARK: - Drawing

    private func drawScene(in context: inout GraphicsContext, size: CGSize, time: Double) {
        let orbit = makeOrbit(size: size)

        drawOrbitGuide(in: &context, orbit: orbit)
        drawSun(in: &context, orbit: orbit, time: time)

        // Instantaneous speed (numeric derivative) drives glow + tail length.
        let head = orbitPos(time: time, orbit: orbit)
        let prev = orbitPos(time: time - 0.012, orbit: orbit)
        let speed = hypot(head.x - prev.x, head.y - prev.y)
        let speedNorm = normalizedSpeed(speed, orbit: orbit)

        drawTail(in: &context, orbit: orbit, time: time, speedNorm: speedNorm)
        drawHead(in: &context, at: head, orbit: orbit, speedNorm: speedNorm)
    }

    /// Map raw per-frame displacement into a 0...1 liveliness factor.
    private func normalizedSpeed(_ speed: CGFloat, orbit: Orbit) -> CGFloat {
        let ref = orbit.unit * 0.012
        let v = speed / max(ref, 0.001)
        return min(1, max(0, (v - 0.4) / 1.6))
    }

    private func drawOrbitGuide(in context: inout GraphicsContext, orbit: Orbit) {
        let rect = CGRect(
            x: orbit.center.x - orbit.a,
            y: orbit.center.y - orbit.b,
            width: orbit.a * 2,
            height: orbit.b * 2
        )
        let path = Path(ellipseIn: rect)
        context.stroke(
            path,
            with: .color(Color(red: 0.36, green: 0.42, blue: 0.62).opacity(0.16)),
            style: StrokeStyle(lineWidth: 1, dash: [2, 5])
        )
    }

    private func drawSun(in context: inout GraphicsContext, orbit: Orbit, time: Double) {
        let pulse = 0.5 + 0.5 * sin(time * 2.0)
        let r = orbit.unit * 0.05
        let glowR = r * (2.4 + 0.5 * CGFloat(pulse))
        let glowRect = CGRect(
            x: orbit.focus.x - glowR,
            y: orbit.focus.y - glowR,
            width: glowR * 2,
            height: glowR * 2
        )
        context.fill(
            Path(ellipseIn: glowRect),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 1.0, green: 0.78, blue: 0.42).opacity(0.45),
                    Color(red: 1.0, green: 0.6, blue: 0.25).opacity(0.0)
                ]),
                center: orbit.focus,
                startRadius: 0,
                endRadius: glowR
            )
        )
        let coreRect = CGRect(
            x: orbit.focus.x - r,
            y: orbit.focus.y - r,
            width: r * 2,
            height: r * 2
        )
        context.fill(
            Path(ellipseIn: coreRect),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 1.0, green: 0.95, blue: 0.8),
                    Color(red: 1.0, green: 0.72, blue: 0.34)
                ]),
                center: orbit.focus,
                startRadius: 0,
                endRadius: r
            )
        )
    }

    private func drawTail(
        in context: inout GraphicsContext,
        orbit: Orbit,
        time: Double,
        speedNorm: CGFloat
    ) {
        // Tail is longer + brighter when the comet moves fast (near perihelion).
        let lengthFactor = 0.55 + 0.45 * speedNorm
        let count = max(8, Int(CGFloat(trailCount) * lengthFactor))
        let push = orbit.unit * pushDistance

        // Draw oldest particle first so the bright young head end paints on top.
        for index in stride(from: count - 1, through: 0, by: -1) {
            let age = Double(index)
            let sampleTime = time - age * trailStep
            let base = orbitPos(time: sampleTime, orbit: orbit)

            // Radial direction away from the focal "sun".
            let dx = base.x - orbit.focus.x
            let dy = base.y - orbit.focus.y
            let len = max(hypot(dx, dy), 0.001)
            let nx = dx / len
            let ny = dy / len

            // Radial anti-focus push dominates so the tail points AWAY from the
            // focus (solar wind) rather than tracing the orbit path.
            let ageNorm = CGFloat(index) / CGFloat(max(1, count - 1))
            let offset = push * ageNorm * (1.0 + 1.4 * speedNorm)
            let pos = CGPoint(x: base.x + nx * offset, y: base.y + ny * offset)

            let fade = pow(1.0 - ageNorm, 1.6)
            let dotR = orbit.unit * (0.026 * fade + 0.004)
            let opacity = Double(fade) * (0.5 + 0.5 * Double(speedNorm))

            let dotRect = CGRect(
                x: pos.x - dotR,
                y: pos.y - dotR,
                width: dotR * 2,
                height: dotR * 2
            )
            let color = tailColor(ageNorm: ageNorm).opacity(opacity)
            context.fill(Path(ellipseIn: dotRect), with: .color(color))
        }
    }

    private func tailColor(ageNorm: CGFloat) -> Color {
        // Hot white-blue near the head, cooling to deep blue at the tip.
        let r = 0.65 + (1.0 - Double(ageNorm)) * 0.35
        let g = 0.78 + (1.0 - Double(ageNorm)) * 0.18
        let b = 1.0
        return Color(red: r, green: g, blue: b)
    }

    private func drawHead(
        in context: inout GraphicsContext,
        at head: CGPoint,
        orbit: Orbit,
        speedNorm: CGFloat
    ) {
        let brightness = 0.6 + 0.4 * speedNorm
        let glowR = orbit.unit * (0.085 + 0.05 * speedNorm)
        let glowRect = CGRect(
            x: head.x - glowR,
            y: head.y - glowR,
            width: glowR * 2,
            height: glowR * 2
        )
        context.fill(
            Path(ellipseIn: glowRect),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 0.85, green: 0.93, blue: 1.0).opacity(0.85 * brightness),
                    Color(red: 0.5, green: 0.72, blue: 1.0).opacity(0.0)
                ]),
                center: head,
                startRadius: 0,
                endRadius: glowR
            )
        )
        let coreR = orbit.unit * (0.022 + 0.008 * speedNorm)
        let coreRect = CGRect(
            x: head.x - coreR,
            y: head.y - coreR,
            width: coreR * 2,
            height: coreR * 2
        )
        context.fill(
            Path(ellipseIn: coreRect),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 1.0, green: 1.0, blue: 1.0),
                    Color(red: 0.78, green: 0.9, blue: 1.0)
                ]),
                center: head,
                startRadius: 0,
                endRadius: coreR
            )
        )
    }
}
