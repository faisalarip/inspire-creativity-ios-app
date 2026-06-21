// catalog-id: ld-particle-assemble-logo
import SwiftUI

/// Particle Assemble — a scattered cloud of particles flies inward and snaps
/// into a glyph/ring with a spring overshoot, holds, then disperses back into
/// the cloud and loops. Rendered entirely in a single `Canvas` for cheap
/// batch drawing. Self-driving via `TimelineView(.animation)`.
///
/// `interaction == "auto"`: both `demo == true` and `demo == false` run the
/// same self-driving loop. The interactive (non-demo) branch additionally
/// lets a tap re-trigger the assemble for a tactile beat.
struct ParticleAssembleLogoView: View {
    var demo: Bool = false

    // Restart anchor — a tap (interactive branch) re-seeds this so the
    // assemble re-fires from scattered. demo branch leaves it fixed.
    @State private var startDate = Date()

    private let particleCount = 72
    private let cycleDuration: Double = 3.4

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            TimelineView(.animation) { timeline in
                let elapsed = timeline.date.timeIntervalSince(startDate)
                canvas(elapsed: elapsed)
            }
            .id(size.width)   // re-anchor Canvas when the tile resizes
            .contentShape(Rectangle())
            .modifier(ParticleAssembleLogoView_TapRestart(enabled: !demo) { startDate = .now })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Canvas

    @ViewBuilder
    private func canvas(elapsed: Double) -> some View {
        let progress = cycleProgress(elapsed: elapsed)
        Canvas { context, canvasSize in
            draw(into: &context, size: canvasSize, progress: progress)
        }
    }

    private func draw(into context: inout GraphicsContext,
                      size: CGSize,
                      progress: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let minSide = min(size.width, size.height)
        let targetRadius = minSide * 0.30
        let scatterRadius = minSide * 0.46
        let dotBase = max(minSide * 0.018, 1.2)

        // Soft halo when assembled so the formed glyph reads as "lit".
        let formed = formationStrength(progress)
        if formed > 0.02 {
            drawHalo(into: &context,
                     center: center,
                     radius: targetRadius,
                     strength: formed)
        }

        for index in 0..<particleCount {
            let p = particle(index: index,
                             center: center,
                             targetRadius: targetRadius,
                             scatterRadius: scatterRadius)
            let resolved = resolve(particle: p,
                                   index: index,
                                   progress: progress)
            drawDot(into: &context,
                    at: resolved.position,
                    radius: dotBase * resolved.scale,
                    alpha: resolved.alpha,
                    hue: p.hue,
                    glow: resolved.glow)
        }
    }

    // MARK: - Particle model

    struct Particle {
        var target: CGPoint
        var scatter: CGPoint
        var hue: Double      // 0..<1 along the spectrum used for tint
    }

    /// Deterministic — derived purely from `index`, so it is identical on
    /// every SwiftUI struct re-creation (no random() in the hot path).
    private func particle(index: Int,
                          center: CGPoint,
                          targetRadius: CGFloat,
                          scatterRadius: CGFloat) -> Particle {
        let count = Double(particleCount)
        let t = Double(index) / count

        // Target: evenly spaced points on a ring (always legible) with a
        // tiny deterministic radial jitter so it reads organic, not robotic.
        let targetAngle = t * 2.0 * .pi - .pi / 2.0
        let jitter = (hash(index, 7.1) - 0.5) * 0.10
        let tr = targetRadius * CGFloat(1.0 + jitter)
        let target = CGPoint(
            x: center.x + CGFloat(cos(Double(targetAngle))) * tr,
            y: center.y + CGFloat(sin(Double(targetAngle))) * tr
        )

        // Scatter: a different deterministic angle + radius, clamped so dots
        // stay inside bounds (never drawn off-screen / invisible).
        let scatterAngle = hash(index, 21.3) * 2.0 * .pi
        let sr = scatterRadius * CGFloat(0.55 + 0.45 * hash(index, 4.7))
        let scatter = CGPoint(
            x: center.x + CGFloat(cos(Double(scatterAngle))) * sr,
            y: center.y + CGFloat(sin(Double(scatterAngle))) * sr
        )

        return Particle(target: target, scatter: scatter, hue: t)
    }

    // MARK: - Resolution per frame

    struct Resolved {
        var position: CGPoint
        var scale: CGFloat
        var alpha: Double
        var glow: Double
    }

    private func resolve(particle p: Particle,
                         index: Int,
                         progress: Double) -> Resolved {
        let staggerMax = 0.32
        let delay = (Double(index) / Double(particleCount)) * staggerMax

        let assembleEnd = 0.40
        let holdEnd = 0.66

        if progress < assembleEnd {
            // Scatter -> target with spring overshoot (easeOutBack).
            let seg = (progress / assembleEnd)
            let local = staggered(seg, delay: delay, span: staggerMax)
            let eased = easeOutBack(local)
            let pos = lerp(p.scatter, p.target, CGFloat(eased))
            let alpha = 0.45 + 0.55 * local
            let scale = 0.7 + 0.3 * CGFloat(local)
            return Resolved(position: pos, scale: scale, alpha: alpha, glow: local)
        } else if progress < holdEnd {
            // Hold assembled, with a gentle breathing shimmer.
            let holdT = (progress - assembleEnd) / (holdEnd - assembleEnd)
            let breathe = 0.5 - 0.5 * cos(holdT * 2.0 * .pi)
            let scale = 1.0 + 0.12 * CGFloat(breathe)
            return Resolved(position: p.target, scale: scale, alpha: 1.0, glow: 1.0)
        } else {
            // Disperse target -> scatter (plain ease, reverse stagger).
            let seg = (progress - holdEnd) / (1.0 - holdEnd)
            let revDelay = staggerMax - delay
            let local = staggered(seg, delay: revDelay, span: staggerMax)
            let eased = easeInOut(local)
            let pos = lerp(p.target, p.scatter, CGFloat(eased))
            let alpha = 1.0 - 0.55 * local       // floored at 0.45, never blank
            let scale = 1.0 - 0.3 * CGFloat(local)
            let glow = 1.0 - local
            return Resolved(position: pos, scale: scale, alpha: alpha, glow: glow)
        }
    }

    /// 1.0 while assembled (during assemble-end..hold), ramps at the edges.
    private func formationStrength(_ progress: Double) -> Double {
        let assembleEnd = 0.40
        let holdEnd = 0.66
        if progress < assembleEnd {
            return easeInOut(min(1.0, progress / assembleEnd))
        } else if progress < holdEnd {
            return 1.0
        } else {
            let seg = (progress - holdEnd) / (1.0 - holdEnd)
            return 1.0 - easeInOut(seg)
        }
    }

    // MARK: - Drawing helpers

    private func drawDot(into context: inout GraphicsContext,
                         at point: CGPoint,
                         radius: CGFloat,
                         alpha: Double,
                         hue: Double,
                         glow: Double) {
        let r = max(radius, 0.5)
        let color = tint(for: hue)

        if glow > 0.05 {
            let glowRect = CGRect(x: point.x - r * 3.0,
                                  y: point.y - r * 3.0,
                                  width: r * 6.0,
                                  height: r * 6.0)
            let glowShading = GraphicsContext.Shading.radialGradient(
                Gradient(colors: [color.opacity(0.45 * glow * alpha),
                                  color.opacity(0.0)]),
                center: point,
                startRadius: 0,
                endRadius: r * 3.0
            )
            context.fill(Path(ellipseIn: glowRect), with: glowShading)
        }

        let rect = CGRect(x: point.x - r, y: point.y - r,
                          width: r * 2.0, height: r * 2.0)
        context.fill(Path(ellipseIn: rect),
                     with: .color(color.opacity(alpha)))
    }

    private func drawHalo(into context: inout GraphicsContext,
                          center: CGPoint,
                          radius: CGFloat,
                          strength: Double) {
        let outer = radius * 1.7
        let rect = CGRect(x: center.x - outer, y: center.y - outer,
                          width: outer * 2.0, height: outer * 2.0)
        let accent = tint(for: 0.55)
        let shading = GraphicsContext.Shading.radialGradient(
            Gradient(colors: [accent.opacity(0.0),
                              accent.opacity(0.16 * strength),
                              accent.opacity(0.0)]),
            center: center,
            startRadius: radius * 0.4,
            endRadius: outer
        )
        context.fill(Path(ellipseIn: rect), with: shading)
    }

    // MARK: - Color

    /// Cool teal -> cyan -> soft violet spectrum (no design-system deps).
    private func tint(for hue: Double) -> Color {
        let h = hue.truncatingRemainder(dividingBy: 1.0)
        // Interpolate between three anchor colors.
        let a = (red: 0.20, green: 0.85, blue: 0.78)   // teal
        let b = (red: 0.30, green: 0.62, blue: 1.00)   // blue
        let c = (red: 0.62, green: 0.45, blue: 1.00)   // violet
        if h < 0.5 {
            let t = h / 0.5
            return Color(red: lerpD(a.red, b.red, t),
                         green: lerpD(a.green, b.green, t),
                         blue: lerpD(a.blue, b.blue, t))
        } else {
            let t = (h - 0.5) / 0.5
            return Color(red: lerpD(b.red, c.red, t),
                         green: lerpD(b.green, c.green, t),
                         blue: lerpD(b.blue, c.blue, t))
        }
    }

    // MARK: - Math

    private func cycleProgress(elapsed: Double) -> Double {
        let safe = max(elapsed, 0.0)
        let m = safe.truncatingRemainder(dividingBy: cycleDuration)
        return m / cycleDuration
    }

    /// Per-particle local progress with a leading delay window.
    private func staggered(_ seg: Double, delay: Double, span: Double) -> Double {
        let denom = max(1.0 - span, 0.0001)
        let local = (seg - delay) / denom
        return min(max(local, 0.0), 1.0)
    }

    private func easeOutBack(_ x: Double) -> Double {
        let c1 = 1.70158
        let c3 = c1 + 1.0
        let p = x - 1.0
        return 1.0 + c3 * p * p * p + c1 * p * p
    }

    private func easeInOut(_ x: Double) -> Double {
        let c = min(max(x, 0.0), 1.0)
        return c < 0.5 ? 2.0 * c * c : 1.0 - pow(-2.0 * c + 2.0, 2.0) / 2.0
    }

    private func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t,
                y: a.y + (b.y - a.y) * t)
    }

    private func lerpD(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }

    /// Pure deterministic 0..<1 hash from an integer index + salt.
    private func hash(_ i: Int, _ salt: Double) -> Double {
        let v = sin(Double(i) * 12.9898 + salt) * 43758.5453
        return v - v.rounded(.down)
    }
}

/// Conditionally attaches a tap-to-restart gesture (interactive branch only).
private struct ParticleAssembleLogoView_TapRestart: ViewModifier {
    let enabled: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        if enabled {
            content.onTapGesture { action() }
        } else {
            content
        }
    }
}
