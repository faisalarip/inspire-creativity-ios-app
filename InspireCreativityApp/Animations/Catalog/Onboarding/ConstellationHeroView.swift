// catalog-id: ob-constellation-hero
import SwiftUI

/// Constellation Hero — drifting star points that wire themselves into themed
/// constellations (heart, bell, key) by drawing connecting lines with an
/// animatable trim, then twinkle. Swiping re-routes the lines to the next
/// figure; the demo loop self-wires on a timer.
struct ConstellationHeroView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                ConstellationHeroView_CHBackdrop()
                Group {
                    if demo {
                        ConstellationHeroView_CHDemoStage(side: side)
                    } else {
                        ConstellationHeroView_CHInteractiveStage(side: side)
                    }
                }
                .frame(width: side, height: side)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

// MARK: - Figures

private struct ConstellationHeroView_CHFigure {
    let nodes: [CGPoint]   // normalized 0...1, ordered for the connecting polyline
    let closed: Bool
}

private enum ConstellationHeroView_CHCatalog {
    /// Heart traced clockwise from the bottom tip.
    static let heart = ConstellationHeroView_CHFigure(
        nodes: [
            CGPoint(x: 0.50, y: 0.86),
            CGPoint(x: 0.20, y: 0.55),
            CGPoint(x: 0.18, y: 0.34),
            CGPoint(x: 0.31, y: 0.22),
            CGPoint(x: 0.44, y: 0.30),
            CGPoint(x: 0.50, y: 0.40),
            CGPoint(x: 0.56, y: 0.30),
            CGPoint(x: 0.69, y: 0.22),
            CGPoint(x: 0.82, y: 0.34),
            CGPoint(x: 0.80, y: 0.55)
        ],
        closed: true
    )

    /// Bell: domed body, splayed base, hanging clapper.
    static let bell = ConstellationHeroView_CHFigure(
        nodes: [
            CGPoint(x: 0.50, y: 0.16),
            CGPoint(x: 0.36, y: 0.24),
            CGPoint(x: 0.30, y: 0.46),
            CGPoint(x: 0.24, y: 0.66),
            CGPoint(x: 0.18, y: 0.74),
            CGPoint(x: 0.82, y: 0.74),
            CGPoint(x: 0.76, y: 0.66),
            CGPoint(x: 0.70, y: 0.46),
            CGPoint(x: 0.64, y: 0.24),
            CGPoint(x: 0.50, y: 0.16)
        ],
        closed: false
    )

    /// Key: round bow, shaft, two teeth.
    static let key = ConstellationHeroView_CHFigure(
        nodes: [
            CGPoint(x: 0.30, y: 0.24),
            CGPoint(x: 0.22, y: 0.34),
            CGPoint(x: 0.30, y: 0.44),
            CGPoint(x: 0.40, y: 0.40),
            CGPoint(x: 0.52, y: 0.46),
            CGPoint(x: 0.64, y: 0.52),
            CGPoint(x: 0.64, y: 0.66),
            CGPoint(x: 0.72, y: 0.60),
            CGPoint(x: 0.80, y: 0.68),
            CGPoint(x: 0.86, y: 0.60)
        ],
        closed: false
    )

    /// Empty figure — no lines, used as the "before" state so the opening draw
    /// routes cleanly from nothing into the heart.
    static let blank = ConstellationHeroView_CHFigure(nodes: [], closed: false)

    static let all: [ConstellationHeroView_CHFigure] = [heart, bell, key]

    static func figure(_ index: Int) -> ConstellationHeroView_CHFigure {
        all[((index % all.count) + all.count) % all.count]
    }
}

// MARK: - Constellation polyline shape (uses SwiftUI's built-in .trim)

private struct ConstellationHeroView_CHConstellationPath: Shape {
    let figure: ConstellationHeroView_CHFigure
    let inset: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let area = rect.insetBy(dx: inset, dy: inset)
        guard let first = figure.nodes.first else { return path }
        func mapped(_ p: CGPoint) -> CGPoint {
            CGPoint(x: area.minX + p.x * area.width,
                    y: area.minY + p.y * area.height)
        }
        path.move(to: mapped(first))
        for node in figure.nodes.dropFirst() {
            path.addLine(to: mapped(node))
        }
        if figure.closed {
            path.addLine(to: mapped(first))
        }
        return path
    }
}

// MARK: - Star drift math (deterministic, time-based)

private enum ConstellationHeroView_CHStars {
    /// Stable per-index phase so drift never strobes between frames.
    static func phase(_ index: Int) -> Double {
        let s = sin(Double(index) * 12.9898) * 43758.5453
        return (s - floor(s)) * 2.0 * .pi
    }

    /// Small wandering offset for a star, pure function of time.
    static func drift(index: Int, time: Double, amplitude: CGFloat) -> CGSize {
        let ph = phase(index)
        // Pin trig to CGFloat before mixing with the CGFloat amplitude so the
        // numeric type is unambiguous across toolchains.
        let dx = CGFloat(sin(time * 0.6 + ph)) * amplitude
        let dy = CGFloat(cos(time * 0.45 + ph * 1.3)) * amplitude
        return CGSize(width: dx, height: dy)
    }

    /// Per-star twinkle opacity, floored so the sky is never blank.
    static func twinkle(index: Int, time: Double) -> Double {
        let ph = phase(index)
        let raw = sin(time * 1.7 + ph) * 0.5 + 0.5  // 0...1
        return 0.55 + raw * 0.45                     // 0.55...1.0
    }
}

// MARK: - Shared constellation canvas

/// Renders an outgoing figure (un-drawing) cross-faded with an incoming figure
/// (drawing) plus the drifting / twinkling star layer. `progress` 0→1 means a
/// full hand-off from `figure` to `nextFigure`.
private struct ConstellationHeroView_CHConstellationCanvas: View {
    let side: CGFloat
    let figure: ConstellationHeroView_CHFigure
    let nextFigure: ConstellationHeroView_CHFigure
    let progress: CGFloat   // 0...1 cross-trim
    let time: Double
    let twinkleBoost: Double // 0...1 extra glow when a figure is fully wired

    private var inset: CGFloat { side * 0.14 }
    private var lineWidth: CGFloat { max(1.2, side * 0.012) }
    private var starRadius: CGFloat { max(1.6, side * 0.016) }

    var body: some View {
        ZStack {
            outgoingLines
            incomingLines
            starLayer
        }
        .frame(width: side, height: side)
    }

    // Outgoing figure recedes: full when progress==0, gone when progress==1.
    private var outgoingLines: some View {
        let p = 1.0 - progress
        return ConstellationHeroView_CHConstellationPath(figure: figure, inset: inset)
            .trim(from: 0, to: p)
            .stroke(lineGradient(opacity: lineOpacity(p)),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .shadow(color: glowColor.opacity(0.55 * lineOpacity(p)),
                    radius: lineWidth * 1.6)
    }

    // Incoming figure draws in as progress climbs.
    private var incomingLines: some View {
        let p = progress
        return ConstellationHeroView_CHConstellationPath(figure: nextFigure, inset: inset)
            .trim(from: 0, to: p)
            .stroke(lineGradient(opacity: lineOpacity(p)),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .shadow(color: glowColor.opacity(0.55 * lineOpacity(p)),
                    radius: lineWidth * 1.6)
    }

    // Both figures' stars are rendered and crossfaded by progress, so dots never
    // teleport at the midpoint. A blank side stays hidden and forces its partner
    // to full opacity, so the opening draw / blank hand-off is never empty.
    private func starOpacity(outgoing: Bool) -> Double {
        if figure.nodes.isEmpty { return outgoing ? 0 : 1 }
        if nextFigure.nodes.isEmpty { return outgoing ? 1 : 0 }
        return outgoing ? Double(1 - progress) : Double(progress)
    }

    private var starLayer: some View {
        let area = CGRect(x: 0, y: 0, width: side, height: side).insetBy(dx: inset, dy: inset)
        return ZStack {
            starField(figure.nodes, area: area)
                .opacity(starOpacity(outgoing: true))
            starField(nextFigure.nodes, area: area)
                .opacity(starOpacity(outgoing: false))
        }
    }

    private func starField(_ nodes: [CGPoint], area: CGRect) -> some View {
        ZStack {
            ForEach(nodes.indices, id: \.self) { i in
                star(at: nodes[i], index: i, area: area)
            }
        }
    }

    private func star(at norm: CGPoint, index: Int, area: CGRect) -> some View {
        let base = CGPoint(x: area.minX + norm.x * area.width,
                           y: area.minY + norm.y * area.height)
        let drift = ConstellationHeroView_CHStars.drift(index: index, time: time, amplitude: side * 0.012)
        let tw = min(1.0, ConstellationHeroView_CHStars.twinkle(index: index, time: time) + twinkleBoost * 0.25)
        return ZStack {
            Circle()
                .fill(glowColor)
                .frame(width: starRadius * 3.0, height: starRadius * 3.0)
                .blur(radius: starRadius * 1.1)
                .opacity(0.35 * tw)
            Circle()
                .fill(Color(red: 0.98, green: 0.96, blue: 1.0))
                .frame(width: starRadius * 2.0, height: starRadius * 2.0)
                .opacity(tw)
        }
        .position(x: base.x + drift.width, y: base.y + drift.height)
    }

    // MARK: derived style

    private func lineOpacity(_ p: CGFloat) -> Double {
        // Floor so a half-drawn line is always legible; brighten when complete.
        let base = 0.55 + Double(p) * 0.45
        return min(1.0, base + twinkleBoost * 0.2)
    }

    private var glowColor: Color {
        Color(red: 0.62, green: 0.74, blue: 1.0)
    }

    private func lineGradient(opacity: Double) -> LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.75, green: 0.85, blue: 1.0).opacity(opacity),
                Color(red: 0.58, green: 0.66, blue: 1.0).opacity(opacity)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Backdrop

private struct ConstellationHeroView_CHBackdrop: View {
    var body: some View {
        RadialGradient(
            colors: [
                Color(red: 0.10, green: 0.09, blue: 0.18),
                Color(red: 0.05, green: 0.04, blue: 0.10)
            ],
            center: .center,
            startRadius: 0,
            endRadius: 400
        )
    }
}

// MARK: - Demo stage (self-driving)

private struct ConstellationHeroView_CHDemoStage: View {
    let side: CGFloat

    // Per beat the constellation hands off from one figure to the next:
    // hold (twinkle the current figure) → re-route (undraw current / draw next).
    private let beat: Double = 3.4
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation) { context in
            // Relative clock so beat 0 (the opening draw-in) actually plays and
            // the drift/twinkle phase still uses absolute time for variety.
            let t = context.date.timeIntervalSince(start)
            let phase = computePhase(max(0, t))
            ConstellationHeroView_CHConstellationCanvas(
                side: side,
                figure: phase.from,
                nextFigure: phase.to,
                progress: phase.progress,
                time: t,
                twinkleBoost: phase.twinkleBoost
            )
        }
    }

    struct CHPhase {
        let from: ConstellationHeroView_CHFigure
        let to: ConstellationHeroView_CHFigure
        let progress: CGFloat
        let twinkleBoost: Double
    }

    /// Beat 0 routes from a blank figure into the heart (opening draw), so the
    /// first frame already shows the heart's stars — never blank. Every later
    /// beat holds the current figure (twinkling) then re-routes into the next.
    private func computePhase(_ t: Double) -> CHPhase {
        let beatIndex = Int(floor(t / beat))
        let local = t - Double(beatIndex) * beat

        let holdDur = 1.6
        let routeDur = beat - holdDur

        // `current` is the figure shown this beat (held, then un-drawn); `next`
        // is the one it re-routes into. The very first hold doubles as the
        // draw-in from blank so the opening frame is never empty.
        let current = ConstellationHeroView_CHCatalog.figure(beatIndex)
        let next = ConstellationHeroView_CHCatalog.figure(beatIndex + 1)

        if local < holdDur {
            if beatIndex == 0 {
                // Opening: draw the first figure in from blank during the hold.
                let p = easeOutCubic(local / holdDur)
                return CHPhase(from: ConstellationHeroView_CHCatalog.blank, to: current,
                               progress: CGFloat(p), twinkleBoost: p)
            }
            // Hold + twinkle the fully wired current figure.
            return CHPhase(from: current, to: next, progress: 0, twinkleBoost: 1)
        }

        // Re-route: undraw current, draw next.
        let route = easeInOutCubic((local - holdDur) / routeDur)
        return CHPhase(from: current,
                       to: next,
                       progress: CGFloat(route),
                       twinkleBoost: 1 - route)
    }

    private func easeOutCubic(_ x: Double) -> Double {
        let c = 1 - x
        return 1 - c * c * c
    }

    private func easeInOutCubic(_ x: Double) -> Double {
        x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
    }
}

// MARK: - Interactive stage (real swipe)

private struct ConstellationHeroView_CHInteractiveStage: View {
    let side: CGFloat

    @State private var figureIndex: Int = 0
    // Live re-route progress 0...1: 0 = current figure wired, 1 = handed off to
    // the next figure. Updated directly in onChanged so onEnded can spring it.
    @State private var progress: CGFloat = 0
    @State private var dragStart: CGFloat = 0

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            // Glow swells when a figure is fully wired (p near 0 or 1) and dims
            // mid-scrub, so a settled constellation reads as "locked in".
            let boost = 1.0 - Double(min(progress, 1 - progress)) * 2.0
            ConstellationHeroView_CHConstellationCanvas(
                side: side,
                figure: ConstellationHeroView_CHCatalog.figure(figureIndex),
                nextFigure: ConstellationHeroView_CHCatalog.figure(figureIndex + 1),
                progress: progress,
                time: t,
                twinkleBoost: boost
            )
            .contentShape(Rectangle())
            .gesture(dragGesture)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Swipe left advances (draws the next figure); width / side.
                let delta = -value.translation.width / max(side, 1)
                progress = clamp(dragStart + delta)
            }
            .onEnded { value in
                let predicted = -value.predictedEndTranslation.width / max(side, 1)
                let committed = clamp(dragStart + predicted)
                if committed > 0.5 {
                    // Finish the re-route, then re-base onto the new figure (tied
                    // to the spring, so a fast re-grab can't be clobbered) — the
                    // new figure at progress 0 renders identically to progress 1.
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8),
                                  completionCriteria: .logicallyComplete) {
                        progress = 1
                    } completion: {
                        figureIndex += 1
                        progress = 0
                        dragStart = 0
                    }
                } else {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        progress = 0
                    }
                    dragStart = 0
                }
            }
    }

    private func clamp(_ v: CGFloat) -> CGFloat {
        min(1, max(0, v))
    }
}
