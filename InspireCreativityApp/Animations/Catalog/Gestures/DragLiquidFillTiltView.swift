// catalog-id: ges-drag-liquid-fill-tilt
import SwiftUI

/// Tilt-Pour Liquid Gauge.
///
/// Drag horizontally to tilt the glass. The liquid surface counter-rotates so it
/// stays level to gravity, sloshing with a wobbling meniscus and a trailing wave
/// whose amplitude tracks how fast you tilt; it settles with a damped spring when
/// you stop. In `demo` mode the tilt auto-rocks on a ~3s loop so the tile pours
/// itself with no touch.
struct DragLiquidFillTiltView: View {
    var demo: Bool = false

    // Live tilt the gesture is pushing toward (radians).
    @State private var targetTilt: CGFloat = 0
    // Smoothed angle actually rendered (integrated toward target each frame).
    @State private var displayTilt: CGFloat = 0
    // Slosh wave amplitude (normalised 0…1-ish) driven by angular velocity.
    @State private var slosh: CGFloat = 0
    // Continuously advancing phase so the meniscus always shimmers.
    @State private var wavePhase: CGFloat = 0
    // Last frame timestamp for fixed-step integration.
    @State private var lastT: Double = 0
    @State private var isDragging: Bool = false
    @State private var velocity: CGFloat = 0

    private let maxTilt: CGFloat = 0.61   // ~35°, clamps the level so corners never drain.
    private let fillRatio: CGFloat = 0.52  // resting liquid level inside the glass.

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                content(in: geo.size)
                    .onChange(of: now) { _, t in
                        step(time: t, size: geo.size)
                    }
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(width: geo.size.width))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Composition

    private func content(in size: CGSize) -> some View {
        let side = min(size.width, size.height) * 0.72
        let glassW = side * 0.74
        let glassH = side

        return ZStack {
            GlassAssembly(
                width: glassW,
                height: glassH,
                tilt: displayTilt,
                slosh: slosh,
                phase: wavePhase,
                fillRatio: fillRatio
            )
            .frame(width: glassW, height: glassH)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Gesture

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDragging = true
                let denom = max(width * 0.5, 1)
                let frac = value.translation.width / denom
                targetTilt = clamp(frac * maxTilt, -maxTilt, maxTilt)
            }
            .onEnded { _ in
                isDragging = false
                // Spring back to level; the rebound itself produces the final slosh.
                targetTilt = 0
            }
    }

    // MARK: - Integrator

    private func step(time t: Double, size: CGSize) {
        guard size.width > 0 else { return }
        if lastT == 0 { lastT = t }
        // Clamp dt so a dropped frame can't blow up the spring.
        let dt = CGFloat(min(max(t - lastT, 0), 1.0 / 30.0))
        lastT = t

        if demo {
            // Auto-rock the tilt on a ~3.1s loop.
            let period: CGFloat = 3.1
            let angle = CGFloat(t).truncatingRemainder(dividingBy: Double(period)) / period
            targetTilt = sin(angle * 2 * .pi) * (maxTilt * 0.92)
        }

        // Critically-ish damped follow of displayTilt → targetTilt.
        let stiffness: CGFloat = isDragging ? 26 : 17
        let damping: CGFloat = 2 * sqrt(stiffness) * 0.62
        let prev = displayTilt
        velocity += (stiffness * (targetTilt - displayTilt) - damping * velocity) * dt
        displayTilt += velocity * dt

        // Angular velocity feeds the slosh; spec: amplitude ~ d(tilt)/dt.
        let angVel = dt > 0 ? (displayTilt - prev) / dt : 0
        let drive = min(abs(angVel) * 0.55, 1.0)
        slosh = max(slosh * pow(0.04, dt) /* ~exp decay */, drive)
        // Hard cap so the meniscus never overflows the glass.
        slosh = min(slosh, 1.0)

        // Phase always advances → a permanent faint shimmer keeps the tile alive.
        let baseSpeed: CGFloat = 1.6
        wavePhase += dt * (baseSpeed + slosh * 7.0)
        if wavePhase > 1000 { wavePhase -= 1000 }
    }

    private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        min(max(v, lo), hi)
    }
}

// MARK: - Glass + liquid assembly

private struct GlassAssembly: View {
    let width: CGFloat
    let height: CGFloat
    let tilt: CGFloat
    let slosh: CGFloat
    let phase: CGFloat
    let fillRatio: CGFloat

    private var corner: CGFloat { min(width, height) * 0.16 }

    var body: some View {
        ZStack {
            glassBack
            liquidLayer
            glassRim
            specular
        }
        .rotationEffect(.radians(Double(tilt)))
    }

    // Dark translucent glass body behind the liquid.
    private var glassBack: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(hexCode: 0x1b2030), Color(hexCode: 0x10131d)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }

    // The fill, clipped to the glass. Surface is counter-rotated to stay level.
    private var liquidLayer: some View {
        LiquidShape(
            tilt: tilt,
            slosh: slosh,
            phase: phase,
            fillRatio: fillRatio
        )
        .fill(
            LinearGradient(
                colors: [Color(hexCode: 0x35e0d6), Color(hexCode: 0x17a9c9), Color(hexCode: 0x1d6fb8)],
                startPoint: .top, endPoint: .bottom
            )
        )
        .overlay(meniscusHighlight)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }

    // Bright line riding the surface to read as a wet meniscus edge.
    private var meniscusHighlight: some View {
        LiquidSurfaceLine(
            tilt: tilt,
            slosh: slosh,
            phase: phase,
            fillRatio: fillRatio
        )
        .stroke(
            LinearGradient(
                colors: [Color.white.opacity(0.0), Color.white.opacity(0.85), Color(hexCode: 0xbafff8).opacity(0.9), Color.white.opacity(0.0)],
                startPoint: .leading, endPoint: .trailing
            ),
            style: StrokeStyle(lineWidth: max(width * 0.012, 1.2), lineCap: .round)
        )
        .blur(radius: 0.4)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }

    // Glass outline + soft inner shading.
    private var glassRim: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.55), Color.white.opacity(0.12), Color.white.opacity(0.30)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                lineWidth: max(width * 0.02, 1.5)
            )
    }

    // Vertical glassy specular streak.
    private var specular: some View {
        RoundedRectangle(cornerRadius: corner * 0.5, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.28), Color.white.opacity(0.02)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .frame(width: width * 0.12)
            .blur(radius: 2)
            .offset(x: -width * 0.26)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .allowsHitTesting(false)
    }
}

// MARK: - Surface geometry helpers

/// Shared math for where the liquid surface sits in the glass's *local* space.
/// The surface is tilted by −tilt so that when the parent rotates by +tilt the
/// surface reads horizontal to gravity. A sine slosh rides along that line.
private enum SurfaceGeometry {
    /// y of the surface at horizontal position x (local glass coords, origin top-left).
    static func surfaceY(
        x: CGFloat,
        rect: CGRect,
        tilt: CGFloat,
        slosh: CGFloat,
        phase: CGFloat,
        fillRatio: CGFloat
    ) -> CGFloat {
        let cx = rect.midX
        let baseY = rect.maxY - rect.height * fillRatio
        // Counter-tilt: surface line slope is −tan(tilt) about the glass centre.
        let slope = -tan(Double(tilt))
        let tilted = baseY + CGFloat(slope) * (x - cx)
        // Slosh wave: a couple of cycles across the width, amplitude from velocity.
        let amp = rect.height * 0.085 * slosh
        let waves: CGFloat = 1.7
        let wave = sin((x - cx) / rect.width * waves * 2 * .pi + phase * 2 * .pi)
        // A second, faster ripple gives the meniscus a permanent faint shimmer.
        let shimmer = sin((x - cx) / rect.width * 4.3 * 2 * .pi - phase * 1.3 * 2 * .pi)
        let ripple = rect.height * 0.012
        return tilted + amp * wave + ripple * shimmer
    }
}

/// The filled liquid body. Big horizontal/vertical overdraw guarantees the
/// rounded-rect clip never reveals a triangular gap at the tilted corners.
private struct LiquidShape: Shape {
    var tilt: CGFloat
    var slosh: CGFloat
    var phase: CGFloat
    var fillRatio: CGFloat

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(tilt, AnimatablePair(slosh, phase)) }
        set {
            tilt = newValue.first
            slosh = newValue.second.first
            phase = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let startX = rect.minX - rect.width
        let endX = rect.maxX + rect.width
        let steps = 48
        let dx = (endX - startX) / CGFloat(steps)

        p.move(to: CGPoint(x: startX, y: surface(startX, rect)))
        var x = startX
        for _ in 0...steps {
            p.addLine(to: CGPoint(x: x, y: surface(x, rect)))
            x += dx
        }
        // Close down far below the glass so the fill always reaches the bottom.
        p.addLine(to: CGPoint(x: endX, y: rect.maxY + rect.height))
        p.addLine(to: CGPoint(x: startX, y: rect.maxY + rect.height))
        p.closeSubpath()
        return p
    }

    private func surface(_ x: CGFloat, _ rect: CGRect) -> CGFloat {
        SurfaceGeometry.surfaceY(
            x: x, rect: rect, tilt: tilt, slosh: slosh, phase: phase, fillRatio: fillRatio
        )
    }
}

/// Just the surface polyline, for the bright meniscus stroke.
private struct LiquidSurfaceLine: Shape {
    var tilt: CGFloat
    var slosh: CGFloat
    var phase: CGFloat
    var fillRatio: CGFloat

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(tilt, AnimatablePair(slosh, phase)) }
        set {
            tilt = newValue.first
            slosh = newValue.second.first
            phase = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let startX = rect.minX - rect.width * 0.2
        let endX = rect.maxX + rect.width * 0.2
        let steps = 48
        let dx = (endX - startX) / CGFloat(steps)
        var x = startX
        p.move(to: CGPoint(x: x, y: surface(x, rect)))
        for _ in 0...steps {
            p.addLine(to: CGPoint(x: x, y: surface(x, rect)))
            x += dx
        }
        return p
    }

    private func surface(_ x: CGFloat, _ rect: CGRect) -> CGFloat {
        SurfaceGeometry.surfaceY(
            x: x, rect: rect, tilt: tilt, slosh: slosh, phase: phase, fillRatio: fillRatio
        )
    }
}

// MARK: - Color hex helper

private extension Color {
    init(hexCode hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
