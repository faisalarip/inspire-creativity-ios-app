// catalog-id: ld-dot-grid-wave
import SwiftUI

// MARK: - Dot Grid Ripple
// A 2D grid of dots pulses in size and brightness as a circular wavefront
// sweeps outward from a moving origin. Each dot is delayed by its distance
// from the wave center. Idle: an auto-emitting origin drifts on a Lissajous
// path. Interactive: taps drop new wavefronts at the finger, layered on top.
struct DotGridWaveView: View {
    var demo: Bool = false

    // Tap-spawned wavefronts: where they started and when (reference-time seconds).
    @State private var waves: [DotGridWaveView_TapWave] = []

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            content(in: size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.039, green: 0.063, blue: 0.078))
        .clipped()
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            canvas(in: size, now: now)
        }
        .contentShape(Rectangle())
        .modifier(DotGridWaveView_TapWaveModifier(enabled: !demo) { location, when in
            registerTap(at: location, when: when)
        })
    }

    private func canvas(in size: CGSize, now: TimeInterval) -> some View {
        Canvas { context, canvasSize in
            draw(in: &context, size: canvasSize, now: now)
        }
    }

    // MARK: Tap handling

    private func registerTap(at location: CGPoint, when: TimeInterval) {
        // Drop rings that have already finished so the array stays bounded.
        let alive = waves.filter { wave in (when - wave.birth) < DotGridWaveView_TapWave.lifetime }
        var next = alive
        next.append(DotGridWaveView_TapWave(origin: location, birth: when))
        // Hard cap as a safety net for rapid tapping.
        if next.count > 8 {
            next.removeFirst(next.count - 8)
        }
        waves = next
    }

    // MARK: Rendering

    private func draw(in context: inout GraphicsContext, size: CGSize, now: TimeInterval) {
        let layout = DotGridWaveView_GridLayout(size: size)
        guard layout.columns > 0, layout.rows > 0 else { return }

        let drift = driftOrigin(in: size, now: now)
        let baseColor = dotColor()

        for row in 0..<layout.rows {
            for col in 0..<layout.columns {
                let center = layout.point(col: col, row: row)
                let energy = totalEnergy(at: center, now: now, drift: drift)
                drawDot(in: &context,
                        center: center,
                        baseRadius: layout.baseRadius,
                        energy: energy,
                        color: baseColor)
            }
        }
    }

    private func drawDot(in context: inout GraphicsContext,
                         center: CGPoint,
                         baseRadius: CGFloat,
                         energy: CGFloat,
                         color: Color) {
        // energy is 0...1. Keep a floor so the grid is never blank/dark.
        let clamped = max(0.0, min(1.0, energy))
        let radius = baseRadius * (0.55 + 0.85 * clamped)
        let opacity = 0.32 + 0.68 * clamped

        let rect = CGRect(x: center.x - radius,
                          y: center.y - radius,
                          width: radius * 2,
                          height: radius * 2)

        // Soft glow under bright dots for a tactile pegboard feel.
        if clamped > 0.55 {
            let glowR = radius * 2.1
            let glowRect = CGRect(x: center.x - glowR,
                                  y: center.y - glowR,
                                  width: glowR * 2,
                                  height: glowR * 2)
            let glow = color.opacity(0.18 * Double(clamped))
            context.fill(Path(ellipseIn: glowRect), with: .color(glow))
        }

        context.fill(Path(ellipseIn: rect), with: .color(color.opacity(opacity)))
    }

    // MARK: Energy model

    // Combine the always-on idle wavefront with any decaying tap rings.
    private func totalEnergy(at point: CGPoint,
                             now: TimeInterval,
                             drift: CGPoint) -> CGFloat {
        var energy = idleEnergy(at: point, now: now, drift: drift)
        for wave in waves {
            energy += tapEnergy(at: point, now: now, wave: wave)
        }
        return energy
    }

    // Continuous distance-delayed sine radiating from the drifting origin.
    private func idleEnergy(at point: CGPoint,
                            now: TimeInterval,
                            drift: CGPoint) -> CGFloat {
        let dist = distance(point, drift)
        let k: Double = 0.045            // distance -> phase delay
        let speed: Double = 3.4          // radians/sec of the base oscillation
        let phase = now * speed - Double(dist) * k
        let raw = (sin(phase) + 1.0) * 0.5            // 0...1
        // Attenuate with distance so it reads as a wavefront, not a uniform pulse.
        let falloff = 1.0 / (1.0 + Double(dist) * 0.012)
        return CGFloat(raw * falloff * 0.85)
    }

    // A finite ring that expands from the tap and dies within its lifetime.
    private func tapEnergy(at point: CGPoint,
                           now: TimeInterval,
                           wave: DotGridWaveView_TapWave) -> CGFloat {
        let age = now - wave.birth
        if age < 0 || age > DotGridWaveView_TapWave.lifetime { return 0 }

        let dist = Double(distance(point, wave.origin))
        let ringRadius = age * DotGridWaveView_TapWave.ringSpeed
        // Gaussian band centred on the traveling ring radius.
        let band = dist - ringRadius
        let sigma: Double = 26.0
        let ring = exp(-(band * band) / (2.0 * sigma * sigma))
        // Fade the whole ring out over its lifetime (ease-out).
        let lifeFrac = age / DotGridWaveView_TapWave.lifetime
        let decay = pow(1.0 - lifeFrac, 1.6)
        return CGFloat(ring * decay)
    }

    // MARK: Drifting origin

    private func driftOrigin(in size: CGSize, now: TimeInterval) -> CGPoint {
        // Lissajous drift keeps the auto wavefront origin roaming the tile.
        let period: Double = 7.0
        let t = (now.truncatingRemainder(dividingBy: period)) / period * (.pi * 2.0)
        let cx = Double(size.width) * 0.5
        let cy = Double(size.height) * 0.5
        let ax = Double(size.width) * 0.32
        let ay = Double(size.height) * 0.32
        let x = cx + ax * sin(t * 1.0)
        let y = cy + ay * sin(t * 1.4 + .pi / 3.0)
        return CGPoint(x: x, y: y)
    }

    private func dotColor() -> Color {
        // Cool aqua-cyan that reads on the dark tint.
        Color(red: 0.42, green: 0.86, blue: 0.96)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return CGFloat((Double(dx * dx) + Double(dy * dy)).squareRoot())
    }
}

// MARK: - Grid layout derived from geometry

private struct DotGridWaveView_GridLayout {
    let columns: Int
    let rows: Int
    let spacing: CGFloat
    let originX: CGFloat
    let originY: CGFloat
    let baseRadius: CGFloat

    init(size: CGSize) {
        let minSide = max(1.0, min(size.width, size.height))
        // Derive a count from width, clamp so both the 120pt tile and a large
        // detail view stay legible and Canvas cost stays bounded.
        let targetSpacing: CGFloat = max(14.0, minSide / 9.0)
        let cols = max(5, min(13, Int((size.width / targetSpacing).rounded())))
        let rws = max(5, min(13, Int((size.height / targetSpacing).rounded())))

        // Spacing that actually fits, then centre the grid.
        let spacingX = cols > 1 ? size.width / CGFloat(cols) : size.width
        let spacingY = rws > 1 ? size.height / CGFloat(rws) : size.height
        let sp = max(8.0, min(spacingX, spacingY))

        self.columns = cols
        self.rows = rws
        self.spacing = sp
        let gridW = sp * CGFloat(cols - 1)
        let gridH = sp * CGFloat(rws - 1)
        self.originX = (size.width - gridW) / 2.0
        self.originY = (size.height - gridH) / 2.0
        self.baseRadius = max(1.5, sp * 0.16)
    }

    func point(col: Int, row: Int) -> CGPoint {
        CGPoint(x: originX + CGFloat(col) * spacing,
                y: originY + CGFloat(row) * spacing)
    }
}

// MARK: - Tap wave model

private struct DotGridWaveView_TapWave: Identifiable {
    let id = UUID()
    let origin: CGPoint
    let birth: TimeInterval

    static let lifetime: Double = 1.8       // seconds a ring stays alive
    static let ringSpeed: Double = 170.0    // points/sec the wavefront expands
}

// MARK: - Conditional tap gesture (interactive mode only)

private struct DotGridWaveView_TapWaveModifier: ViewModifier {
    let enabled: Bool
    let onTap: (CGPoint, TimeInterval) -> Void

    func body(content: Content) -> some View {
        if enabled {
            content.gesture(
                SpatialTapGesture(coordinateSpace: .local)
                    .onEnded { value in
                        onTap(value.location, Date().timeIntervalSinceReferenceDate)
                    }
            )
        } else {
            content
        }
    }
}
