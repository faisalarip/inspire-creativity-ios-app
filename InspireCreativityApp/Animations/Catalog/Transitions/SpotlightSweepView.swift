// catalog-id: tr-spotlight-sweep
import SwiftUI

/// Spotlight Sweep — a moving radial spotlight mask travels across the view, and
/// wherever its soft-edged beam falls the "after" scene is revealed over the
/// "before" scene. A penumbra falloff makes content fade up gradually, like a
/// torch sweeping a dark room.
///
/// - demo == true:  a TimelineView(.animation) drives the beam along a looping
///   path on a ~3.2s cycle so the tile is always alive with no touch.
/// - demo == false: a DragGesture aims the beam; the beam springs toward the
///   finger. Content fades back as the beam moves away (the plain "re-hidden
///   behind the beam" reading).
struct SpotlightSweepView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            if demo {
                demoContent(in: size)
            } else {
                interactiveContent(in: size)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Demo (self-driving)

    private func demoContent(in size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let center = demoBeamCenter(at: t, in: size)
            let radius = beamRadius(for: size)
            sweepStack(beamCenter: center, radius: radius, in: size)
        }
    }

    /// A looping path: a left↔right sweep with a gentle vertical bob.
    /// Period ~3.2s so the spotlight crosses and returns smoothly.
    private func demoBeamCenter(at time: TimeInterval, in size: CGSize) -> CGPoint {
        let period: Double = 3.2
        let phase = (time.truncatingRemainder(dividingBy: period)) / period
        // Smooth back-and-forth on x (triangle-ish via cosine), bob on y.
        let sweep = (1.0 - cos(phase * 2.0 * .pi)) / 2.0          // 0→1→0
        let bob = sin(phase * 2.0 * .pi * 2.0)                    // -1…1, two bobs
        let margin: CGFloat = 0.16
        let x = (margin + CGFloat(sweep) * (1.0 - margin * 2.0)) * size.width
        let y = (0.5 + CGFloat(bob) * 0.16) * size.height
        return CGPoint(x: x, y: y)
    }

    // MARK: - Interactive

    private func interactiveContent(in size: CGSize) -> some View {
        SpotlightSweepView_InteractiveSweep(size: size,
                         radius: beamRadius(for: size)) { center, radius in
            sweepStack(beamCenter: center, radius: radius, in: size)
        }
    }

    // MARK: - Shared composition

    private func sweepStack(beamCenter: CGPoint, radius: CGFloat, in size: CGSize) -> some View {
        ZStack {
            SpotlightSweepView_BeforeScene()
            SpotlightSweepView_AfterScene()
                .mask(spotlightMask(center: beamCenter, radius: radius, in: size))
            // A faint warm rim so the beam reads as light, not just a reveal.
            beamGlow(center: beamCenter, radius: radius, in: size)
                .allowsHitTesting(false)
        }
    }

    private func spotlightMask(center: CGPoint, radius: CGFloat, in size: CGSize) -> some View {
        let cx = size.width > 0 ? center.x / size.width : 0.5
        let cy = size.height > 0 ? center.y / size.height : 0.5
        return RadialGradient(
            stops: [
                .init(color: .white, location: 0.0),
                .init(color: .white, location: 0.55),
                .init(color: .white.opacity(0.0), location: 1.0)
            ],
            center: UnitPoint(x: cx, y: cy),
            startRadius: 0,
            endRadius: radius
        )
    }

    private func beamGlow(center: CGPoint, radius: CGFloat, in size: CGSize) -> some View {
        let cx = size.width > 0 ? center.x / size.width : 0.5
        let cy = size.height > 0 ? center.y / size.height : 0.5
        return RadialGradient(
            stops: [
                .init(color: Color(red: 1.0, green: 0.93, blue: 0.74).opacity(0.22), location: 0.0),
                .init(color: Color(red: 1.0, green: 0.85, blue: 0.55).opacity(0.05), location: 0.5),
                .init(color: .clear, location: 1.0)
            ],
            center: UnitPoint(x: cx, y: cy),
            startRadius: 0,
            endRadius: radius * 0.95
        )
        .blendMode(.screen)
    }

    private func beamRadius(for size: CGSize) -> CGFloat {
        0.45 * min(size.width, size.height)
    }
}

// MARK: - Interactive driver

/// Holds the beam point and springs it toward the finger. Kept separate so the
/// demo path never touches @State (and never fights the TimelineView clock).
private struct SpotlightSweepView_InteractiveSweep<Content: View>: View {
    let size: CGSize
    let radius: CGFloat
    let content: (CGPoint, CGFloat) -> Content

    @State private var beam: CGPoint? = nil

    var body: some View {
        let center = beam ?? CGPoint(x: size.width / 2, y: size.height / 2)
        content(center, radius)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                            beam = clamp(value.location, in: size)
                        }
                    }
            )
    }

    private func clamp(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 0), size.width),
            y: min(max(point.y, 0), size.height)
        )
    }
}

// MARK: - Scenes

/// Dim, cool "before" state — a dark room before the torch arrives.
private struct SpotlightSweepView_BeforeScene: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.06, blue: 0.09),
                    Color(red: 0.07, green: 0.08, blue: 0.13)
                ],
                startPoint: .top, endPoint: .bottom
            )
            SpotlightSweepView_SceneMotif(
                stroke: Color(red: 0.20, green: 0.24, blue: 0.34),
                fill: Color(red: 0.11, green: 0.13, blue: 0.20),
                glyph: Color(red: 0.28, green: 0.33, blue: 0.45),
                dimmed: true
            )
        }
    }
}

/// Bright, warm "after" state — the same motif lit by the spotlight.
private struct SpotlightSweepView_AfterScene: View {
    var body: some View {
        ZStack {
            RadialGradient(
                colors: [
                    Color(red: 0.16, green: 0.12, blue: 0.06),
                    Color(red: 0.09, green: 0.07, blue: 0.05)
                ],
                center: .center, startRadius: 0, endRadius: 220
            )
            SpotlightSweepView_SceneMotif(
                stroke: Color(red: 1.0, green: 0.82, blue: 0.42),
                fill: Color(red: 0.98, green: 0.62, blue: 0.20),
                glyph: Color(red: 1.0, green: 0.95, blue: 0.84),
                dimmed: false
            )
        }
    }
}

/// A simple, layout-independent motif (concentric arc + centered star) so the
/// before/after states share geometry but differ clearly in color/brightness.
private struct SpotlightSweepView_SceneMotif: View {
    let stroke: Color
    let fill: Color
    let glyph: Color
    let dimmed: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let dim = min(size.width, size.height)
            ZStack {
                Circle()
                    .stroke(stroke.opacity(dimmed ? 0.5 : 0.95), lineWidth: dim * 0.018)
                    .frame(width: dim * 0.78, height: dim * 0.78)
                Circle()
                    .stroke(stroke.opacity(dimmed ? 0.28 : 0.6),
                            style: StrokeStyle(lineWidth: dim * 0.012, dash: [dim * 0.05, dim * 0.045]))
                    .frame(width: dim * 0.54, height: dim * 0.54)
                SpotlightSweepView_Star(points: 5, smoothness: 0.46)
                    .fill(fill.opacity(dimmed ? 0.55 : 1.0))
                    .frame(width: dim * 0.34, height: dim * 0.34)
                    .shadow(color: dimmed ? .clear : fill.opacity(0.6),
                            radius: dim * 0.05)
                Image(systemName: "sun.max.fill")
                    .font(.system(size: dim * 0.10, weight: .bold))
                    .foregroundStyle(glyph.opacity(dimmed ? 0.5 : 1.0))
                    .offset(y: dim * 0.30)
            }
            .frame(width: size.width, height: size.height)
        }
    }
}

/// A pointed star shape used by the motif. Pure path math, size-relative.
private struct SpotlightSweepView_Star: Shape {
    var points: Int = 5
    var smoothness: CGFloat = 0.45

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * smoothness
        let count = max(points, 2) * 2
        let step = (.pi * 2.0) / CGFloat(count)
        var angle = -CGFloat.pi / 2.0
        for i in 0..<count {
            let radius = (i % 2 == 0) ? outer : inner
            let pt = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            angle += step
        }
        path.closeSubpath()
        return path
    }
}
