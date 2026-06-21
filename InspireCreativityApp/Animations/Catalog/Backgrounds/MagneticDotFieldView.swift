// catalog-id: bg-magnetic-dot-field
import SwiftUI

// MARK: - Magnetic Dot Field
//
// A precise lattice of dots drawn in a single Canvas. Each dot is repelled and
// scaled by its distance to an active attractor point — like iron filings under
// a magnet — with a springy settle on release.
//
//   demo == true   self-driving Lissajous orbit drives the attractor forever.
//   demo == false  DragGesture drives the attractor; release springs back with
//                   a damped-cosine overshoot, then relaxes to a faint idle orbit.
//
// Pure SwiftUI + Canvas math, iOS 17. No Metal, no app dependencies.

struct MagneticDotFieldView: View {
    var demo: Bool = false

    // Live drag state — mutated only in gesture callbacks, never in the render closure.
    @State private var dragPoint: CGPoint? = nil
    @State private var releaseDate: Date? = nil
    @State private var releaseLocation: CGPoint = .zero

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let field = resolveField(size: geo.size, time: t)
                Canvas { context, size in
                    drawLattice(context: context, size: size, field: field)
                }
                .contentShape(Rectangle())
                .gesture(dragGesture(in: geo.size))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.039, green: 0.039, blue: 0.047))
    }

    // MARK: Gesture

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !demo else { return }
                dragPoint = value.location
                releaseDate = nil
            }
            .onEnded { value in
                guard !demo else { return }
                dragPoint = nil
                releaseLocation = value.location
                releaseDate = Date()
            }
    }

    // MARK: Field resolution (single attractor + strength for the whole frame)

    /// The active magnetic source for this frame: one point, one strength.
    struct Field {
        var attractor: CGPoint
        var strength: CGFloat   // can dip slightly negative for inward overshoot
    }

    private func resolveField(size: CGSize, time t: TimeInterval) -> Field {
        let idle = idleOrbit(size: size, time: t)

        if demo {
            // Pure self-driving demo: full-strength attractor on the orbit.
            return Field(attractor: idle.point, strength: 1.0)
        }

        // Interactive: live drag overrides everything.
        if let p = dragPoint {
            return Field(attractor: p, strength: 1.0)
        }

        // Released: damped-cosine settle from the release point back to idle.
        if let rd = releaseDate {
            let elapsed = max(0, Date().timeIntervalSince1970 - rd.timeIntervalSince1970)
            return settleField(elapsed: elapsed,
                               idlePoint: idle.point,
                               idleStrength: idle.strength)
        }

        // Untouched idle: faint orbit so an interactive tile still looks alive.
        return Field(attractor: idle.point, strength: idle.strength)
    }

    /// Slow Lissajous orbit. In demo it carries the full ripple; interactively it's
    /// the faint resting motion the field relaxes back into.
    private func idleOrbit(size: CGSize, time t: TimeInterval) -> (point: CGPoint, strength: CGFloat) {
        let w = size.width
        let h = size.height
        // ~3.4s base period so the tile reads as a slow, calm wander.
        let phase = t * 0.46
        let ax: CGFloat = 0.34
        let ay: CGFloat = 0.30
        let cx = w * (0.5 + ax * CGFloat(sin(phase)))
        let cy = h * (0.5 + ay * CGFloat(sin(phase * 1.37 + 1.1)))
        let idleStrength: CGFloat = demo ? 1.0 : 0.42
        return (CGPoint(x: cx, y: cy), idleStrength)
    }

    /// Damped-cosine envelope from a fixed release point toward the idle orbit.
    /// Strength dips below idle once (dots snap inward past rest) then settles.
    /// Attractor point is held near the release location through the first
    /// oscillation, then eased onto the idle orbit so the overshoot stays crisp.
    private func settleField(elapsed: TimeInterval,
                             idlePoint: CGPoint,
                             idleStrength: CGFloat) -> Field {
        let e = CGFloat(elapsed)
        // Envelope: starts at 1, decays with a cosine wobble toward idleStrength.
        let k: CGFloat = 4.2          // decay rate
        let omega: CGFloat = 8.6      // oscillation frequency
        let wobble = exp(-k * e) * cos(omega * e)
        let strength = idleStrength + (1.0 - idleStrength) * wobble

        // Hold the point near release for the first beat, then drift to idle.
        let handoff = clamp((e - 0.35) / 0.65, 0, 1)
        let eased = handoff * handoff * (3 - 2 * handoff) // smoothstep
        let px = releaseLocation.x + (idlePoint.x - releaseLocation.x) * eased
        let py = releaseLocation.y + (idlePoint.y - releaseLocation.y) * eased
        return Field(attractor: CGPoint(x: px, y: py), strength: strength)
    }

    // MARK: Lattice geometry

    /// Lattice spacing derived from the live size so it scales from a 120pt tile
    /// to a large detail area. Caps total dot count for the per-frame distance pass.
    private func latticeMetrics(for size: CGSize) -> (spacing: CGFloat, cols: Int, rows: Int) {
        let minSide = min(size.width, size.height)
        // ~16 dots across the short side; clamp spacing to a sane band.
        let spacing = clamp(minSide / 16.0, 9.0, 30.0)
        let cols = max(2, Int((size.width / spacing).rounded(.down)) + 2)
        let rows = max(2, Int((size.height / spacing).rounded(.down)) + 2)
        return (spacing, cols, rows)
    }

    // MARK: Drawing

    private func drawLattice(context: GraphicsContext, size: CGSize, field: Field) {
        let metrics = latticeMetrics(for: size)
        let spacing = metrics.spacing
        let baseRadius = clamp(spacing * 0.12, 1.0, 3.4)
        // Influence radius: how far the magnet reaches across the field.
        let influence = max(spacing * 5.0, min(size.width, size.height) * 0.42)
        let maxPush = spacing * 1.55

        // Center the lattice within the view.
        let usedW = CGFloat(metrics.cols - 1) * spacing
        let usedH = CGFloat(metrics.rows - 1) * spacing
        let originX = (size.width - usedW) / 2.0
        let originY = (size.height - usedH) / 2.0

        let attractor = field.attractor
        let strength = field.strength

        for r in 0..<metrics.rows {
            for c in 0..<metrics.cols {
                let restX = originX + CGFloat(c) * spacing
                let restY = originY + CGFloat(r) * spacing
                drawDot(context: context,
                        restX: restX, restY: restY,
                        attractor: attractor,
                        strength: strength,
                        influence: influence,
                        maxPush: maxPush,
                        baseRadius: baseRadius)
            }
        }
    }

    private func drawDot(context: GraphicsContext,
                         restX: CGFloat, restY: CGFloat,
                         attractor: CGPoint,
                         strength: CGFloat,
                         influence: CGFloat,
                         maxPush: CGFloat,
                         baseRadius: CGFloat) {
        let dx = restX - attractor.x
        let dy = restY - attractor.y
        let dist = max(0.0001, hypot(dx, dy))

        // Smooth inverse-square-ish falloff, normalized by influence radius.
        let ratio = dist / influence
        let falloff = 1.0 / (1.0 + ratio * ratio * 4.0) // 0..1, peaks at the source
        let active = falloff * strength

        // Push outward along the radial direction.
        let push = maxPush * active
        let nx = dx / dist
        let ny = dy / dist
        let x = restX + nx * push
        let y = restY + ny * push

        // Radius swells near the magnet; brightness too. Base is unconditional
        // so the field is never blank, regardless of strength.
        let radius = baseRadius * (1.0 + 1.7 * max(0, active))
        let glow = clamp(0.22 + 0.78 * max(0, active), 0.22, 1.0)

        let color = dotColor(intensity: glow)
        let rect = CGRect(x: x - radius, y: y - radius,
                          width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .color(color))
    }

    /// Cool-violet resting dot warming to bright cyan-white at the magnet core.
    private func dotColor(intensity: CGFloat) -> Color {
        let i = clamp(intensity, 0, 1)
        let red = 0.34 + 0.55 * i
        let green = 0.40 + 0.55 * i
        let blue = 0.62 + 0.38 * i
        return Color(red: red, green: green, blue: blue).opacity(0.30 + 0.70 * i)
    }

    // MARK: Helpers

    private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        min(max(v, lo), hi)
    }
}
