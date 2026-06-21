// catalog-id: ld-liquid-flask-fill
import SwiftUI

/// Liquid Flask Fill
/// A rounded flask fills from the bottom with tinted liquid whose surface tilts
/// and sloshes with inertia, settling level after a damped spring overshoot, while
/// tiny bubbles rise through the liquid.
///
/// - `demo == true`  : self-driving — the surface tilts on a slow sine and the fill
///                     level breathes up and down on a timer. Never blank.
/// - `demo == false` : interactive — a DragGesture maps horizontal translation to
///                     surface tilt and vertical translation to fill level. On release
///                     the surface settles level with a damped overshoot.
///
/// Everything is recomputed each frame from time + drag state (no animatableData),
/// so the timeline-driven traveling wave and the release overshoot compose cleanly.
struct LiquidFlaskFillView: View {
    var demo: Bool = false

    // MARK: - Interactive drag state

    /// Live tilt in radians while dragging (horizontal translation).
    @State private var dragTilt: CGFloat = 0
    /// Live fill level 0...1 while dragging (vertical translation).
    @State private var dragFill: CGFloat = 0.55
    /// Fill level captured at the moment a drag begins.
    @State private var fillAtDragStart: CGFloat = 0.55
    /// True while the finger is down.
    @State private var isDragging: Bool = false

    /// Reference-time snapshot of the release moment, used to seed the damped slosh.
    @State private var releaseTime: TimeInterval = 0
    /// Tilt magnitude at release; the slosh decays from here.
    @State private var releaseTilt: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let phase = now * 1.6            // traveling-wave phase, always moving
                let state = resolvedState(now: now)
                flask(in: geo.size, fill: state.fill, tilt: state.tilt, phase: phase, now: now)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        // Single view type: keep the gesture installed but mask it off in demo mode.
        .gesture(dragGesture, including: demo ? .subviews : .all)
    }

    // MARK: - State resolution

    struct LiquidState {
        var fill: CGFloat
        var tilt: CGFloat
    }

    /// Computes the current fill + tilt for this frame depending on mode and drag phase.
    private func resolvedState(now: TimeInterval) -> LiquidState {
        if demo {
            return autoState(now: now)
        }
        if isDragging {
            return LiquidState(fill: dragFill, tilt: dragTilt)
        }
        // Released: damped harmonic slosh back to level.
        let dt: Double = now - releaseTime
        let tilt = settleTilt(elapsed: dt)
        return LiquidState(fill: dragFill, tilt: tilt)
    }

    /// Self-driving loop: a gentle ~3.2s breathing fill and a slow tilt sine.
    private func autoState(now: TimeInterval) -> LiquidState {
        let fillWave: CGFloat = CGFloat(sin(now * 0.9))            // -1...1
        let fill: CGFloat = 0.575 + 0.275 * fillWave              // 0.30...0.85
        let tilt: CGFloat = CGFloat(sin(now * 1.25)) * 0.20        // ~±11.5°
        return LiquidState(fill: fill, tilt: tilt)
    }

    /// Hand-rolled damped oscillation for the release overshoot.
    /// tilt(Δ) = releaseTilt · e^(-k·Δ) · cos(ω·Δ)
    private func settleTilt(elapsed: Double) -> CGFloat {
        let clamped = max(0, elapsed)
        let k: Double = 3.4        // damping
        let omega: Double = 7.0    // angular frequency of the slosh
        let envelope = exp(-k * clamped)
        let osc = cos(omega * clamped)
        return releaseTilt * CGFloat(envelope * osc)
    }

    // MARK: - Composition

    @ViewBuilder
    private func flask(in size: CGSize, fill: CGFloat, tilt: CGFloat, phase: Double, now: TimeInterval) -> some View {
        let dims = flaskDimensions(for: size)
        let shape = RoundedRectangle(cornerRadius: dims.corner, style: .continuous)

        ZStack {
            // Glass body backdrop.
            shape
                .fill(glassFill)
                .frame(width: dims.width, height: dims.height)

            // Liquid + bubbles, clipped to the flask interior.
            liquidLayer(dims: dims, fill: fill, tilt: tilt, phase: phase, now: now)
                .frame(width: dims.width, height: dims.height)
                .clipShape(shape)

            // Glass rim + highlight.
            shape
                .strokeBorder(rimGradient, lineWidth: max(1.4, dims.width * 0.018))
                .frame(width: dims.width, height: dims.height)

            glassHighlight(dims: dims)
                .frame(width: dims.width, height: dims.height)
                .clipShape(shape)
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func liquidLayer(dims: FlaskDimensions, fill: CGFloat, tilt: CGFloat, phase: Double, now: TimeInterval) -> some View {
        let interior = CGSize(width: dims.width, height: dims.height)
        let surfaceY = surfaceLineY(in: interior, fill: fill)
        let amplitude = dims.waveAmplitude(tilt: tilt)
        let meniscusWidth = max(1.0, dims.width * 0.012)

        ZStack {
            // The liquid body.
            LiquidFlaskFillView_LiquidShape(fill: fill, tilt: tilt, phase: phase, amplitude: amplitude)
                .fill(liquidGradient)
                .overlay {
                    // Brighter meniscus band riding the surface.
                    LiquidFlaskFillView_LiquidShape(fill: fill, tilt: tilt, phase: phase, amplitude: amplitude)
                        .stroke(meniscusColor, lineWidth: meniscusWidth)
                        .blur(radius: 0.6)
                }

            // Rising bubbles, only below the surface line.
            bubbles(interior: interior, surfaceY: surfaceY, fill: fill, now: now)
        }
    }

    @ViewBuilder
    private func bubbles(interior: CGSize, surfaceY: CGFloat, fill: CGFloat, now: TimeInterval) -> some View {
        Canvas { context, _ in
            guard fill > 0.04 else { return }
            let count = 11
            let bottom = interior.height
            for i in 0..<count {
                let seed = Double(i) * 12.9898
                let speed: Double = 0.45 + frac(sin(seed) * 43758.5453) * 0.5
                let xJitter: CGFloat = CGFloat(frac(sin(seed + 4.1) * 22578.1459))
                let radius: CGFloat = 1.4 + CGFloat(frac(sin(seed + 7.7) * 9301.17)) * 2.2

                // Vertical travel cycles from bottom up to the surface line.
                let cyclePos = frac(now * speed + Double(i) / Double(count))
                let travel = bottom - surfaceY
                let y = bottom - CGFloat(cyclePos) * travel
                guard y > surfaceY else { continue }

                // Gentle horizontal wobble as it rises.
                let wobble = CGFloat(sin(now * 2.0 + seed)) * (interior.width * 0.02)
                let x = interior.width * (0.12 + 0.76 * xJitter) + wobble

                // Fade in near the bottom, fade out as it nears the surface.
                let nearSurface = (y - surfaceY) / max(travel, 1)
                let alpha = Double(min(1, nearSurface * 3.0)) * 0.6

                let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
            }
        }
    }

    @ViewBuilder
    private func glassHighlight(dims: FlaskDimensions) -> some View {
        let w = dims.width
        let h = dims.height
        Capsule()
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.30), Color.white.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: w * 0.10, height: h * 0.72)
            .offset(x: -w * 0.28, y: -h * 0.04)
            .blur(radius: 1.0)
    }

    // MARK: - Geometry helpers

    struct FlaskDimensions {
        var width: CGFloat
        var height: CGFloat
        var corner: CGFloat

        func waveAmplitude(tilt: CGFloat) -> CGFloat {
            // Tilt drives surface slope; amplitude grows a touch with |tilt| for slosh feel.
            let base: CGFloat = height * 0.018
            let tiltBoost: CGFloat = abs(tilt) * height * 0.10
            return base + tiltBoost
        }
    }

    private func flaskDimensions(for size: CGSize) -> FlaskDimensions {
        let side = min(size.width, size.height)
        // A tall rounded flask: narrower than tall, comfortably inside the tile.
        let width = side * 0.56
        let height = side * 0.86
        let corner = width * 0.42
        return FlaskDimensions(width: width, height: height, corner: corner)
    }

    /// Y position of the resting surface line (no wave) inside the interior.
    private func surfaceLineY(in interior: CGSize, fill: CGFloat) -> CGFloat {
        let clamped = min(max(fill, 0), 1)
        return interior.height * (1 - clamped)
    }

    // MARK: - Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    fillAtDragStart = dragFill
                }
                // Horizontal translation -> tilt, clamped to ~±25°.
                let maxTilt: CGFloat = 0.44   // radians (~25°)
                let tiltRaw = value.translation.width / 160.0
                dragTilt = min(max(tiltRaw, -maxTilt), maxTilt)

                // Vertical translation -> fill delta (drag up fills, down empties).
                let fillDelta = -value.translation.height / 220.0
                dragFill = min(max(fillAtDragStart + fillDelta, 0), 1)
            }
            .onEnded { _ in
                isDragging = false
                releaseTilt = dragTilt
                releaseTime = Date().timeIntervalSinceReferenceDate
            }
    }

    // MARK: - Palette

    private var liquidGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.20, green: 0.78, blue: 0.92),
                Color(red: 0.10, green: 0.52, blue: 0.86),
                Color(red: 0.06, green: 0.34, blue: 0.74)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var meniscusColor: Color {
        Color(red: 0.62, green: 0.92, blue: 1.0).opacity(0.85)
    }

    private var glassFill: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.16, green: 0.20, blue: 0.26).opacity(0.55),
                Color(red: 0.08, green: 0.11, blue: 0.16).opacity(0.55)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var rimGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.55),
                Color.white.opacity(0.12),
                Color.white.opacity(0.30)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Math helpers

    /// Fractional part, always in 0..<1.
    private func frac(_ x: Double) -> Double {
        let f = x - floor(x)
        return f
    }
}

// MARK: - Liquid Shape

/// Draws the liquid body as a region under a tilted, traveling sine surface.
/// All inputs are plain values (recomputed per frame); no animatableData is used
/// because animation is driven externally by TimelineView + time-based slosh.
private struct LiquidFlaskFillView_LiquidShape: Shape {
    var fill: CGFloat       // 0...1
    var tilt: CGFloat       // radians, surface slope
    var phase: Double       // traveling-wave phase
    var amplitude: CGFloat  // wave amplitude in points

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let clampedFill = min(max(fill, 0), 1)
        guard clampedFill > 0.001 else { return path }

        let baseY: CGFloat = rect.height * (1 - clampedFill)
        let slope: CGFloat = CGFloat(tan(Double(tilt)))   // surface tilt as vertical offset per unit x
        let midX: CGFloat = rect.width / 2
        let waveLength: CGFloat = rect.width * 0.9
        let k: CGFloat = (2 * .pi) / max(waveLength, 1)

        let step: CGFloat = max(2, rect.width / 48)
        var x: CGFloat = 0

        path.move(to: CGPoint(x: 0, y: surfaceY(at: 0, baseY: baseY, slope: slope, midX: midX, k: k)))
        while x <= rect.width {
            let y = surfaceY(at: x, baseY: baseY, slope: slope, midX: midX, k: k)
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }
        // Ensure the right edge is captured.
        let edgeY = surfaceY(at: rect.width, baseY: baseY, slope: slope, midX: midX, k: k)
        path.addLine(to: CGPoint(x: rect.width, y: edgeY))

        // Close down the right side, across the bottom, up the left.
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }

    private func surfaceY(at x: CGFloat, baseY: CGFloat, slope: CGFloat, midX: CGFloat, k: CGFloat) -> CGFloat {
        let tiltOffset: CGFloat = (x - midX) * slope
        let waveOffset: CGFloat = amplitude * CGFloat(sin(Double(k * x) + phase))
        return baseY + tiltOffset + waveOffset
    }
}
