// catalog-id: ld-orbital-electrons
import SwiftUI

// MARK: - Orbital Electrons
// Three electron dots travel along tilted elliptical orbits around a glowing
// nucleus. Each orbit has its own period and in-plane rotation, so the dots
// weave in front of and behind the core. Depth is computed from the
// pre-rotation parametric (independent of in-plane rotation) so the z-order
// swaps read as genuine 3D, not a side effect of on-screen Y.
//
// This item's interactiveSpec is "auto — same as previewLoop", so BOTH the
// demo tile and the detail component self-drive via TimelineView(.animation).
// No gesture is wired (a loading spinner has none to wire); the detail simply
// runs the same continuous orbit at a calmer pace and a touch larger scale.

struct OrbitalElectronsView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                OrbitalElectronsView_AtomCanvas(time: t, size: geo.size, compact: demo)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - One orbital track

private struct OrbitalElectronsView_Orbit {
    /// Semi-major axis as a fraction of the layout's short side.
    let semiMajor: CGFloat
    /// Out-of-plane tilt (radians). Drives the semi-minor axis (cos) and the
    /// depth amplitude (sin) — i.e. how far the dot dives behind the nucleus.
    let tilt: CGFloat
    /// In-plane rotation of the whole ellipse on screen (radians).
    let planeRotation: CGFloat
    /// Seconds for one full revolution.
    let period: Double
    /// Starting phase offset (radians) so the three dots desync.
    let phaseOffset: CGFloat
    let color: Color
}

// MARK: - Canvas renderer

private struct OrbitalElectronsView_AtomCanvas: View {
    let time: Double
    let size: CGSize
    let compact: Bool

    private var orbits: [OrbitalElectronsView_Orbit] {
        // Distinct periods so the dots drift out of lockstep and weave.
        // Slightly slower in the larger detail view for a calmer feel.
        let speed: Double = compact ? 1.0 : 0.78
        return [
            OrbitalElectronsView_Orbit(semiMajor: 0.78, tilt: 1.15, planeRotation: 0,
                  period: 2.4 / speed, phaseOffset: 0.0,
                  color: Color(red: 0.39, green: 0.86, blue: 1.00)),     // cyan
            OrbitalElectronsView_Orbit(semiMajor: 0.82, tilt: 1.05, planeRotation: .pi / 3,
                  period: 3.0 / speed, phaseOffset: 2.1,
                  color: Color(red: 0.62, green: 0.55, blue: 1.00)),     // indigo
            OrbitalElectronsView_Orbit(semiMajor: 0.76, tilt: 1.22, planeRotation: 2 * .pi / 3,
                  period: 3.7 / speed, phaseOffset: 4.0,
                  color: Color(red: 1.00, green: 0.55, blue: 0.78))      // pink
        ]
    }

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let s = min(canvasSize.width, canvasSize.height)
            let R = s * 0.40               // base orbit radius
            let nucleusR = s * 0.115       // nucleus core radius
            let allOrbits = orbits

            // 1) Behind pass: ring arcs + dots with depth < 0 (far side).
            drawRingArcs(in: context, orbits: allOrbits, center: center,
                         baseR: R, front: false)
            drawElectrons(in: context, orbits: allOrbits, center: center,
                          baseR: R, s: s, front: false)

            // 2) The glowing nucleus, occluding the far side.
            drawNucleus(in: context, center: center, coreR: nucleusR, s: s)

            // 3) Front pass: ring arcs + dots with depth >= 0 (near side).
            drawRingArcs(in: context, orbits: allOrbits, center: center,
                         baseR: R, front: true)
            drawElectrons(in: context, orbits: allOrbits, center: center,
                          baseR: R, s: s, front: true)
        }
        .background(Color(red: 0.039, green: 0.063, blue: 0.078))
        .drawingGroup()
    }

    // MARK: Parametric point + depth

    /// Returns the on-screen point and a signed depth for a given orbit angle.
    /// Depth comes from the PRE-rotation parametric (R·sinθ·sinα) so its sign
    /// is independent of the in-plane rotation φ — the front/back swap always
    /// lands at θ = 0 and θ = π, never wherever the rotated ellipse looks low.
    private func point(orbit: OrbitalElectronsView_Orbit, theta: CGFloat,
                       center: CGPoint, baseR: CGFloat) -> (CGPoint, CGFloat) {
        let r: CGFloat = baseR * orbit.semiMajor
        let cosA: CGFloat = cos(orbit.tilt)
        let sinA: CGFloat = sin(orbit.tilt)

        let ex: CGFloat = r * cos(theta)
        let ey: CGFloat = r * sin(theta) * cosA
        let depth: CGFloat = r * sin(theta) * sinA

        let cosP: CGFloat = cos(orbit.planeRotation)
        let sinP: CGFloat = sin(orbit.planeRotation)
        let x: CGFloat = ex * cosP - ey * sinP
        let y: CGFloat = ex * sinP + ey * cosP

        let pt = CGPoint(x: center.x + x, y: center.y + y)
        return (pt, depth)
    }

    private func currentTheta(for orbit: OrbitalElectronsView_Orbit) -> CGFloat {
        let frac = CGFloat((time.truncatingRemainder(dividingBy: orbit.period)) / orbit.period)
        return frac * 2 * .pi + orbit.phaseOffset
    }

    // MARK: Ring arcs (behind / front split)

    private func drawRingArcs(in context: GraphicsContext, orbits: [OrbitalElectronsView_Orbit],
                              center: CGPoint, baseR: CGFloat, front: Bool) {
        let steps = 96
        for orbit in orbits {
            var path = Path()
            var penDown = false
            for i in 0...steps {
                let theta = CGFloat(i) / CGFloat(steps) * 2 * .pi
                let (pt, depth) = point(orbit: orbit, theta: theta,
                                        center: center, baseR: baseR)
                let inThisPass = front ? (depth >= 0) : (depth < 0)
                if inThisPass {
                    if penDown {
                        path.addLine(to: pt)
                    } else {
                        path.move(to: pt)
                        penDown = true
                    }
                } else {
                    penDown = false
                }
            }
            let alpha: Double = front ? 0.30 : 0.13
            context.stroke(
                path,
                with: .color(orbit.color.opacity(alpha)),
                style: StrokeStyle(lineWidth: front ? 1.6 : 1.2,
                                   lineCap: .round)
            )
        }
    }

    // MARK: Electron dots (behind / front split)

    private func drawElectrons(in context: GraphicsContext, orbits: [OrbitalElectronsView_Orbit],
                               center: CGPoint, baseR: CGFloat,
                               s: CGFloat, front: Bool) {
        for orbit in orbits {
            let theta = currentTheta(for: orbit)
            let (pt, depth) = point(orbit: orbit, theta: theta,
                                    center: center, baseR: baseR)
            let inThisPass = front ? (depth >= 0) : (depth < 0)
            guard inThisPass else { continue }
            drawDot(in: context, at: pt, depth: depth, orbit: orbit, s: s)
        }
    }

    private func drawDot(in context: GraphicsContext, at pt: CGPoint,
                         depth: CGFloat, orbit: OrbitalElectronsView_Orbit, s: CGFloat) {
        // Normalised depth -1...1: near side reads bigger and brighter.
        let maxDepth: CGFloat = s * 0.40 * orbit.semiMajor * sin(orbit.tilt)
        let norm: CGFloat = maxDepth > 0 ? max(-1, min(1, depth / maxDepth)) : 0
        let sizeScale: CGFloat = 0.80 + 0.45 * (norm + 1) / 2   // 0.80...1.25
        let bright: Double = 0.55 + 0.45 * Double((norm + 1) / 2)

        let dotR: CGFloat = s * 0.045 * sizeScale
        let glowR: CGFloat = dotR * 3.4

        // Soft halo.
        let glowRect = CGRect(x: pt.x - glowR, y: pt.y - glowR,
                              width: glowR * 2, height: glowR * 2)
        let glow = GraphicsContext.Shading.radialGradient(
            Gradient(colors: [
                orbit.color.opacity(0.55 * bright),
                orbit.color.opacity(0.0)
            ]),
            center: pt, startRadius: 0, endRadius: glowR
        )
        context.fill(Path(ellipseIn: glowRect), with: glow)

        // Solid core with a tiny bright center.
        let dotRect = CGRect(x: pt.x - dotR, y: pt.y - dotR,
                             width: dotR * 2, height: dotR * 2)
        let core = GraphicsContext.Shading.radialGradient(
            Gradient(colors: [
                Color.white.opacity(bright),
                orbit.color.opacity(bright)
            ]),
            center: CGPoint(x: pt.x - dotR * 0.25, y: pt.y - dotR * 0.25),
            startRadius: 0, endRadius: dotR
        )
        context.fill(Path(ellipseIn: dotRect), with: core)
    }

    // MARK: Nucleus

    private func drawNucleus(in context: GraphicsContext, center: CGPoint,
                             coreR: CGFloat, s: CGFloat) {
        // Subtle pulse so the core feels alive.
        let pulse: CGFloat = 1.0 + 0.06 * CGFloat(sin(time * 2.2))
        let glowR: CGFloat = coreR * 2.6 * pulse

        // Outer aura.
        let auraRect = CGRect(x: center.x - glowR, y: center.y - glowR,
                              width: glowR * 2, height: glowR * 2)
        let aura = GraphicsContext.Shading.radialGradient(
            Gradient(colors: [
                Color(red: 1.0, green: 0.86, blue: 0.55).opacity(0.45),
                Color(red: 1.0, green: 0.70, blue: 0.40).opacity(0.0)
            ]),
            center: center, startRadius: coreR * 0.4, endRadius: glowR
        )
        context.fill(Path(ellipseIn: auraRect), with: aura)

        // Hot core.
        let cr: CGFloat = coreR * pulse
        let coreRect = CGRect(x: center.x - cr, y: center.y - cr,
                              width: cr * 2, height: cr * 2)
        let core = GraphicsContext.Shading.radialGradient(
            Gradient(colors: [
                Color.white,
                Color(red: 1.0, green: 0.85, blue: 0.55),
                Color(red: 1.0, green: 0.55, blue: 0.30)
            ]),
            center: CGPoint(x: center.x - cr * 0.2, y: center.y - cr * 0.2),
            startRadius: 0, endRadius: cr
        )
        context.fill(Path(ellipseIn: coreRect), with: core)
    }
}
