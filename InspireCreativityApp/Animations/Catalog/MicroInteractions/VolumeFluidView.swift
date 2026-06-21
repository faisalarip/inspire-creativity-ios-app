// catalog-id: mi-volume-fluid
import SwiftUI

// MARK: - Public View

/// Fluid Volume Fill — a vertical volume control rendered as liquid in a glass.
/// Dragging raises the level; drag velocity tilts and sloshes the surface,
/// which then settles flat via a clock-driven damped sine. In `demo` mode it
/// ramps the level and self-sloshes so the tile stays alive with no touch.
struct VolumeFluidView: View {
    var demo: Bool = false

    // Level the liquid rises to, 0...1 (set directly, never spring-animated).
    @State private var level: CGFloat = 0.55
    @State private var isDragging: Bool = false
    // Live tilt while a finger is down, driven by drag velocity. Gated on isDragging.
    @State private var liveTilt: CGFloat = 0
    // A recorded slosh impulse: when it started and its initial amplitude/sign.
    @State private var impulseStart: TimeInterval = -100
    @State private var impulseAmp: CGFloat = 0
    @State private var settleTrigger: Int = 0

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            content(size: size)
                .frame(width: size.width, height: size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.impact(weight: .light), trigger: settleTrigger)
    }

    @ViewBuilder
    private func content(size: CGSize) -> some View {
        if demo {
            fluidTimeline()
        } else {
            fluidTimeline()
                .gesture(dragGesture(in: size))
        }
    }

    private func fluidTimeline() -> some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let frame = frameValues(now: now)
            VolumeFluidView_FluidCanvas(
                level: frame.level,
                tilt: frame.tilt,
                slosh: frame.slosh,
                phase: frame.phase
            )
        }
        .contentShape(Rectangle())
    }

    // MARK: - Per-frame physics

    struct FrameValues {
        var level: CGFloat
        var tilt: CGFloat   // overall surface tilt (left↔right)
        var slosh: CGFloat  // standing-wave amplitude
        var phase: CGFloat  // wave phase for the rippling motion
    }

    private func frameValues(now: TimeInterval) -> FrameValues {
        if demo {
            return demoFrame(now: now)
        }
        return interactiveFrame(now: now)
    }

    /// Interactive: level follows the finger; slosh decays from the last impulse.
    private func interactiveFrame(now: TimeInterval) -> FrameValues {
        let elapsed = CGFloat(now - impulseStart)
        let decayed = dampedAmplitude(initial: impulseAmp, elapsed: elapsed)
        let phase = CGFloat(now) * waveSpeed
        let tilt = isDragging ? liveTilt : decayed
        let amp = isDragging ? max(abs(liveTilt) * 0.6, 0.012) : abs(decayed)
        return FrameValues(
            level: clampLevel(level),
            tilt: tilt,
            slosh: amp,
            phase: phase
        )
    }

    /// Demo: everything is a pure function of the clock so the tile auto-plays.
    private func demoFrame(now: TimeInterval) -> FrameValues {
        let period: CGFloat = 5.2
        let t = CGFloat(now).truncatingRemainder(dividingBy: period)
        let u = t / period // 0...1 around the loop

        // Smooth up/down ramp using a cosine so the reversal points are gentle.
        let ramp = 0.5 - 0.5 * cos(u * 2 * .pi)   // 0→1→0
        let lvl = clampLevel(0.22 + ramp * 0.62)  // floored well above empty

        // Each half-period (t=0 and t=period/2) is a ramp reversal — seed a
        // fresh decaying slosh from there. dampedAmplitude carries the cos(ωt).
        let sinceReversal = t.truncatingRemainder(dividingBy: period / 2)
        let amp = dampedAmplitude(initial: 0.09, elapsed: sinceReversal)

        let phase = CGFloat(now) * waveSpeed
        return FrameValues(
            level: lvl,
            tilt: amp,
            slosh: max(abs(amp), 0.016),
            phase: phase
        )
    }

    // MARK: - Physics helpers

    private var waveSpeed: CGFloat { 3.1 }

    /// Damped oscillator: A0 * e^(-k t) * cos(ω t). Returns ~0 once settled.
    private func dampedAmplitude(initial: CGFloat, elapsed: CGFloat) -> CGFloat {
        guard elapsed >= 0 else { return 0 }
        let k: CGFloat = 2.6     // decay rate
        let omega: CGFloat = 7.4 // bob frequency
        let env = exp(-k * elapsed)
        return initial * env * cos(omega * elapsed)
    }

    private func clampLevel(_ v: CGFloat) -> CGFloat {
        min(max(v, 0.12), 0.97)
    }

    // MARK: - Gesture

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDragging = true
                // Map finger Y to level (top = full). Use the glass insets.
                let inset = glassInset(for: size)
                let top = inset.height
                let bottom = size.height - inset.height
                let span = max(bottom - top, 1)
                let raw = (bottom - value.location.y) / span
                level = clampLevel(raw)
                // Vertical velocity drives the live tilt (points/sec → small tilt).
                let vy = value.velocity.height
                liveTilt = clampTilt(-vy / 4200)
            }
            .onEnded { value in
                isDragging = false
                // Hand the live energy to a decaying impulse from this instant.
                let seed = clampTilt(-value.velocity.height / 3200)
                impulseAmp = abs(seed) > 0.0001 ? seed : liveTilt
                impulseStart = Date().timeIntervalSinceReferenceDate
                liveTilt = 0
                settleTrigger &+= 1
            }
    }

    private func clampTilt(_ v: CGFloat) -> CGFloat {
        min(max(v, -0.13), 0.13)
    }

    private func glassInset(for size: CGSize) -> CGSize {
        let m = min(size.width, size.height)
        let pad = max(m * 0.10, 6)
        return CGSize(width: pad, height: pad)
    }
}

// MARK: - Canvas

private struct VolumeFluidView_FluidCanvas: View {
    let level: CGFloat
    let tilt: CGFloat
    let slosh: CGFloat
    let phase: CGFloat

    var body: some View {
        Canvas { context, size in
            let glass = glassRect(in: size)
            let corner = glass.width * 0.16

            drawBackdrop(in: &context, size: size)
            drawGlassBody(in: &context, rect: glass, corner: corner)

            // Clip all liquid to the inner glass and draw.
            context.drawLayer { layer in
                let clip = RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .path(in: glass)
                layer.clip(to: clip)
                drawLiquid(in: &layer, glass: glass)
            }

            drawGlassRim(in: &context, rect: glass, corner: corner)
        }
    }

    // MARK: Geometry

    private func glassRect(in size: CGSize) -> CGRect {
        let m = min(size.width, size.height)
        let pad = max(m * 0.10, 6)
        let w = size.width - pad * 2
        let h = size.height - pad * 2
        // Keep a tall-ish glass even in a square tile.
        let glassW = min(w, h * 0.62)
        let x = (size.width - glassW) / 2
        return CGRect(x: x, y: pad, width: glassW, height: h)
    }

    // MARK: Backdrop

    private func drawBackdrop(in context: inout GraphicsContext, size: CGSize) {
        let bg = Path(CGRect(origin: .zero, size: size))
        let top = Color(red: 0.09, green: 0.07, blue: 0.12)
        let bottom = Color(red: 0.05, green: 0.04, blue: 0.08)
        context.fill(
            bg,
            with: .linearGradient(
                Gradient(colors: [top, bottom]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )
    }

    // MARK: Glass

    private func drawGlassBody(in context: inout GraphicsContext, rect: CGRect, corner: CGFloat) {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous).path(in: rect)
        let fillTop = Color(red: 0.16, green: 0.17, blue: 0.22).opacity(0.55)
        let fillBottom = Color(red: 0.10, green: 0.11, blue: 0.16).opacity(0.55)
        context.fill(
            shape,
            with: .linearGradient(
                Gradient(colors: [fillTop, fillBottom]),
                startPoint: CGPoint(x: rect.minX, y: rect.minY),
                endPoint: CGPoint(x: rect.minX, y: rect.maxY)
            )
        )
    }

    private func drawGlassRim(in context: inout GraphicsContext, rect: CGRect, corner: CGFloat) {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous).path(in: rect)
        // Outer rim.
        context.stroke(
            shape,
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.85, green: 0.88, blue: 0.95).opacity(0.55),
                    Color(red: 0.45, green: 0.50, blue: 0.62).opacity(0.30)
                ]),
                startPoint: CGPoint(x: rect.minX, y: rect.minY),
                endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
            ),
            lineWidth: max(rect.width * 0.018, 1)
        )
        // A soft vertical specular streak on the left for glassiness.
        let streakW = rect.width * 0.10
        let streak = RoundedRectangle(cornerRadius: streakW / 2, style: .continuous)
            .path(in: CGRect(
                x: rect.minX + rect.width * 0.14,
                y: rect.minY + rect.height * 0.06,
                width: streakW,
                height: rect.height * 0.82
            ))
        context.fill(
            streak,
            with: .linearGradient(
                Gradient(colors: [
                    Color.white.opacity(0.14),
                    Color.white.opacity(0.0)
                ]),
                startPoint: CGPoint(x: rect.minX, y: rect.minY),
                endPoint: CGPoint(x: rect.minX, y: rect.maxY)
            )
        )
    }

    // MARK: Liquid

    private func drawLiquid(in context: inout GraphicsContext, glass: CGRect) {
        let surfaceY = surfaceBaseY(in: glass)
        let body = liquidBodyPath(glass: glass, surfaceY: surfaceY)

        // Liquid fill — vivid teal/blue gradient with depth.
        let cTop = Color(red: 0.20, green: 0.78, blue: 0.92)
        let cMid = Color(red: 0.12, green: 0.52, blue: 0.90)
        let cBot = Color(red: 0.08, green: 0.30, blue: 0.78)
        context.fill(
            body,
            with: .linearGradient(
                Gradient(colors: [cTop, cMid, cBot]),
                startPoint: CGPoint(x: glass.minX, y: surfaceY),
                endPoint: CGPoint(x: glass.minX, y: glass.maxY)
            )
        )

        drawSurfaceSheen(in: &context, glass: glass, surfaceY: surfaceY)
        drawMeniscus(in: &context, glass: glass, surfaceY: surfaceY)
        drawBubbles(in: &context, glass: glass, surfaceY: surfaceY)
    }

    /// Base Y of the waterline for the current level (no wave offset).
    private func surfaceBaseY(in glass: CGRect) -> CGFloat {
        glass.maxY - level * glass.height
    }

    /// y of the wave at horizontal fraction `fx` (0...1 across the glass).
    private func waveY(baseY: CGFloat, glass: CGRect, fx: CGFloat) -> CGFloat {
        // Tilt is a linear left↔right component centered at the middle.
        let tiltOffset = tilt * glass.height * (fx - 0.5)
        // Slosh is a standing wave; amplitude scaled to the glass.
        let amp = slosh * glass.height
        let twoPi: CGFloat = 2 * .pi
        let ripple = amp * sin(fx * twoPi + phase) * 0.6
        let ripple2 = amp * sin(fx * twoPi * 2 - phase * 1.3) * 0.25
        return baseY + tiltOffset + ripple + ripple2
    }

    /// The filled liquid body: across the wavy surface, then down and closed.
    private func liquidBodyPath(glass: CGRect, surfaceY: CGFloat) -> Path {
        var path = Path()
        let steps = 26
        let startY = waveY(baseY: surfaceY, glass: glass, fx: 0)
        path.move(to: CGPoint(x: glass.minX, y: startY))
        var i = 1
        while i <= steps {
            let fx = CGFloat(i) / CGFloat(steps)
            let x = glass.minX + fx * glass.width
            let y = waveY(baseY: surfaceY, glass: glass, fx: fx)
            path.addLine(to: CGPoint(x: x, y: y))
            i += 1
        }
        path.addLine(to: CGPoint(x: glass.maxX, y: glass.maxY))
        path.addLine(to: CGPoint(x: glass.minX, y: glass.maxY))
        path.closeSubpath()
        return path
    }

    private func drawSurfaceSheen(in context: inout GraphicsContext, glass: CGRect, surfaceY: CGFloat) {
        // A thin bright band riding just under the surface line.
        var band = Path()
        let steps = 26
        let bandThickness = max(glass.height * 0.012, 1.0)
        let topStart = waveY(baseY: surfaceY, glass: glass, fx: 0)
        band.move(to: CGPoint(x: glass.minX, y: topStart))
        var i = 1
        while i <= steps {
            let fx = CGFloat(i) / CGFloat(steps)
            let x = glass.minX + fx * glass.width
            band.addLine(to: CGPoint(x: x, y: waveY(baseY: surfaceY, glass: glass, fx: fx)))
            i += 1
        }
        i = steps
        while i >= 0 {
            let fx = CGFloat(i) / CGFloat(steps)
            let x = glass.minX + fx * glass.width
            band.addLine(to: CGPoint(x: x, y: waveY(baseY: surfaceY, glass: glass, fx: fx) + bandThickness))
            i -= 1
        }
        band.closeSubpath()
        context.fill(band, with: .color(Color.white.opacity(0.30)))
    }

    private func drawMeniscus(in context: inout GraphicsContext, glass: CGRect, surfaceY: CGFloat) {
        // Soft glow just above the surface to fake a meniscus highlight.
        let glowH = glass.height * 0.06
        let rect = CGRect(
            x: glass.minX,
            y: surfaceY - glowH,
            width: glass.width,
            height: glowH * 2
        )
        let glow = Path(rect)
        context.fill(
            glow,
            with: .linearGradient(
                Gradient(colors: [
                    Color.white.opacity(0.0),
                    Color.white.opacity(0.16),
                    Color.white.opacity(0.0)
                ]),
                startPoint: CGPoint(x: 0, y: rect.minY),
                endPoint: CGPoint(x: 0, y: rect.maxY)
            )
        )
    }

    private func drawBubbles(in context: inout GraphicsContext, glass: CGRect, surfaceY: CGFloat) {
        // A few rising bubbles whose vertical position is driven by `phase`.
        let count = 5
        var idx = 0
        while idx < count {
            let seed = CGFloat(idx) * 1.37
            let fx = (sin(seed * 2.1) * 0.5 + 0.5) * 0.7 + 0.15
            let x = glass.minX + fx * glass.width
            // Rise from bottom toward surface, cycling on phase.
            let cyc = (phase * 0.08 + seed).truncatingRemainder(dividingBy: 1.0)
            let bottomY = glass.maxY - glass.height * 0.04
            let y = bottomY - cyc * (bottomY - surfaceY - 2)
            if y > surfaceY + 2 {
                let r = max(glass.width * (0.02 + 0.012 * CGFloat(idx % 3)), 1.0)
                let dot = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                let alpha = 0.18 * (1 - cyc)
                context.fill(dot, with: .color(Color.white.opacity(alpha)))
            }
            idx += 1
        }
    }
}
