// catalog-id: ob-paper-tear
import SwiftUI

// MARK: - PaperTearView
// Page Tear Reveal — dragging from the page edge tears the current page away along a
// procedurally jagged ripped-paper edge that follows your finger, revealing the next
// page underneath with a soft torn-fiber shadow. Release past threshold flicks the torn
// piece off; otherwise the seam springs closed. The demo loop tears a page on a ~3s cycle.
struct PaperTearView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            Group {
                if demo {
                    PaperTearView_DemoTear(size: geo.size)
                } else {
                    PaperTearView_InteractiveTear(size: geo.size)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Demo (self-driving)
private struct PaperTearView_DemoTear: View {
    let size: CGSize

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let cycle: Double = 3.4
            let phase = (t.truncatingRemainder(dividingBy: cycle)) / cycle // 0..1
            let progress = demoProgress(phase)
            let wobble = t * 1.6 // gentle ambient ripple

            PaperTearView_PaperTearCanvas(size: size, progress: progress, wobble: wobble, falling: 0)
        }
    }

    // Ramp up, hold open briefly, then reset quickly so a fresh page is always shown.
    private func demoProgress(_ phase: Double) -> CGFloat {
        let p: Double
        if phase < 0.62 {
            // ease-out tear from 0 -> 1
            let x = phase / 0.62
            p = 1 - pow(1 - x, 2.4)
        } else if phase < 0.78 {
            p = 1 // hold fully torn
        } else {
            // quick reset back to a fresh page
            let x = (phase - 0.78) / 0.22
            p = 1 - easeInOut(x)
        }
        return CGFloat(min(max(p, 0), 1))
    }

    private func easeInOut(_ x: Double) -> Double {
        x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2
    }
}

// MARK: - Interactive
private struct PaperTearView_InteractiveTear: View {
    let size: CGSize

    @State private var progress: CGFloat = 0
    @State private var dragStart: CGFloat = 0
    @State private var falling: CGFloat = 0   // 0 attached, 1 fully flicked away

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            PaperTearView_PaperTearCanvas(size: size,
                            progress: progress,
                            wobble: t * 1.4,
                            falling: falling)
        }
        .contentShape(Rectangle())
        .gesture(tearGesture)
    }

    private var tearGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if falling > 0 { resetTorn() }
                let w = max(size.width, 1)
                let delta = value.translation.width / w
                let raw = dragStart + delta
                progress = clamp(raw)
            }
            .onEnded { value in
                let w = max(size.width, 1)
                let predicted = dragStart + value.predictedEndTranslation.width / w
                let committed = progress > 0.5 || predicted > 0.78
                if committed {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) {
                        progress = 1
                    }
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.6).delay(0.02)) {
                        falling = 1
                    }
                    // After the torn sheet falls away, present the fresh page beneath.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
                        resetTorn()
                    }
                } else {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                        progress = 0
                    }
                    dragStart = 0
                }
            }
    }

    private func resetTorn() {
        progress = 0
        falling = 0
        dragStart = 0
    }

    private func clamp(_ v: CGFloat) -> CGFloat { min(max(v, 0), 1) }
}

// MARK: - Shared canvas renderer
// Composites: bottom (next) page full-frame, then the top (current) page clipped to the
// still-attached region, plus a torn-fiber shadow along the rip line. When `falling` > 0
// the torn-off sheet slides and rotates away to reveal the fresh page.
private struct PaperTearView_PaperTearCanvas: View {
    let size: CGSize
    let progress: CGFloat
    let wobble: Double
    let falling: CGFloat

    var body: some View {
        ZStack {
            bottomPage
            shadowBand
            topPageLayer
        }
        .clipped()
    }

    // The next page, sitting beneath — always fully visible where the top page is torn.
    private var bottomPage: some View {
        PaperTearView_PaperPage(palette: .next)
    }

    // Soft torn-fiber shadow cast by the lifting/attached edge onto the page below.
    private var shadowBand: some View {
        PaperTearView_TornEdgeShape(progress: progress, wobble: wobble, fiber: true)
            .stroke(
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.04, blue: 0.09).opacity(0.0),
                        Color(red: 0.05, green: 0.04, blue: 0.09).opacity(0.55)
                    ],
                    startPoint: .leading, endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: max(size.width, size.height) * 0.018,
                                   lineCap: .round, lineJoin: .round)
            )
            .blur(radius: max(size.width, size.height) * 0.012)
            .offset(x: progress > 0 ? -size.width * 0.012 : 0)
            .opacity(progress > 0.001 && falling < 0.5 ? 1 : 0)
    }

    // The current page, clipped to the attached region (rip line -> right edge),
    // carrying the torn sheet off-screen when `falling` engages.
    private var topPageLayer: some View {
        PaperTearView_PaperPage(palette: .current)
            .overlay(tornFiberHighlight)
            .clipShape(PaperTearView_AttachedRegionShape(progress: progress, wobble: wobble))
            .offset(x: fallingOffsetX, y: fallingOffsetY)
            .rotationEffect(.degrees(Double(falling) * 7), anchor: .bottomTrailing)
            .opacity(1 - Double(falling) * 0.35)
    }

    // A thin lit rim drawn right along the rip so the edge reads as ragged fibers.
    private var tornFiberHighlight: some View {
        PaperTearView_TornEdgeShape(progress: progress, wobble: wobble, fiber: false)
            .stroke(
                Color(red: 0.99, green: 0.98, blue: 0.95).opacity(0.85),
                style: StrokeStyle(lineWidth: max(1.2, max(size.width, size.height) * 0.006),
                                   lineCap: .round, lineJoin: .round)
            )
            .opacity(progress > 0.001 ? 1 : 0)
    }

    private var fallingOffsetX: CGFloat { -size.width * 0.5 * falling }
    private var fallingOffsetY: CGFloat { size.height * 0.35 * falling }
}

// MARK: - Tear geometry
// The rip is a near-vertical jagged line whose x-position = split. The jitter is a PURE
// function of segment index (no RNG, no stored state) so the edge is byte-identical every
// frame — it ripples only via the smooth `wobble` parameter, never boils.
private struct PaperTearView_TornEdge {
    let segments = 26

    // Deterministic pseudo-random in [-1, 1] from an index — stable across all redraws.
    func jitter(_ i: Int) -> CGFloat {
        let s = sin(Double(i) * 12.9898 + 4.137) * 43758.5453
        let f = s - floor(s)            // fract -> [0,1)
        return CGFloat(f * 2 - 1)
    }

    func secondary(_ i: Int) -> CGFloat {
        let s = sin(Double(i) * 7.233 + 1.91) * 21943.21
        let f = s - floor(s)
        return CGFloat(f * 2 - 1)
    }

    // Build the rip line points down the page at split x for the given size.
    func points(in size: CGSize, progress: CGFloat, wobble: Double) -> [CGPoint] {
        let splitX = size.width * progress
        let amp = max(size.width, size.height) * 0.045   // scales with tile/detail
        let micro = amp * 0.4
        var pts: [CGPoint] = []
        for i in 0...segments {
            let ty = CGFloat(i) / CGFloat(segments)
            let y = ty * size.height
            // ambient ripple grows toward the free (top) end, fades at anchored ends
            let envelope = sin(ty * .pi)
            let ripple = sin(wobble + Double(i) * 0.7) * Double(amp) * 0.25 * Double(envelope)
            let jag = jitter(i) * amp + secondary(i) * micro
            let x = splitX + jag + CGFloat(ripple)
            pts.append(CGPoint(x: x, y: y))
        }
        return pts
    }
}

// MARK: - Attached region clip (top page keeps rip-line -> right edge)
private struct PaperTearView_AttachedRegionShape: Shape {
    var progress: CGFloat
    var wobble: Double
    private let edge = PaperTearView_TornEdge()

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let pts = edge.points(in: rect.size, progress: progress, wobble: wobble)
        guard let first = pts.first else { return p }
        p.move(to: first)
        for pt in pts.dropFirst() { p.addLine(to: pt) }
        // close along the right edge -> bottom-right -> top-right
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Rip line as a stroked Shape (used for shadow + fiber highlight)
private struct PaperTearView_TornEdgeShape: Shape {
    var progress: CGFloat
    var wobble: Double
    var fiber: Bool
    private let edge = PaperTearView_TornEdge()

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let pts = edge.points(in: rect.size, progress: progress, wobble: wobble)
        guard let first = pts.first else { return p }
        p.move(to: first)
        for pt in pts.dropFirst() { p.addLine(to: pt) }
        return p
    }
}

// MARK: - Drawn paper page (no assets)
private struct PaperTearView_PaperPage: View {
    enum Palette { case current, next }
    let palette: Palette

    var body: some View {
        ZStack {
            base
            ruledLines
            cornerLabel
        }
    }

    private var base: some View {
        LinearGradient(colors: gradientColors,
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(
                RadialGradient(colors: [Color.white.opacity(0.10), Color.clear],
                               center: .topLeading, startRadius: 0, endRadius: 260)
            )
    }

    // Faint notepad rules so it reads as a real sheet at any size.
    private var ruledLines: some View {
        GeometryReader { g in
            let count = 7
            let step = g.size.height / CGFloat(count + 1)
            Path { path in
                for i in 1...count {
                    let y = step * CGFloat(i)
                    path.move(to: CGPoint(x: g.size.width * 0.10, y: y))
                    path.addLine(to: CGPoint(x: g.size.width * 0.90, y: y))
                }
            }
            .stroke(lineColor, lineWidth: 1)
        }
        .allowsHitTesting(false)
    }

    private var cornerLabel: some View {
        GeometryReader { g in
            Circle()
                .fill(dotColor)
                .frame(width: g.size.width * 0.16, height: g.size.width * 0.16)
                .position(x: g.size.width * 0.22, y: g.size.height * 0.18)
                .opacity(0.9)
        }
        .allowsHitTesting(false)
    }

    private var gradientColors: [Color] {
        switch palette {
        case .current:
            return [Color(red: 0.97, green: 0.96, blue: 0.92),
                    Color(red: 0.91, green: 0.89, blue: 0.83)]
        case .next:
            return [Color(red: 0.16, green: 0.20, blue: 0.34),
                    Color(red: 0.09, green: 0.11, blue: 0.22)]
        }
    }

    private var lineColor: Color {
        switch palette {
        case .current: return Color(red: 0.55, green: 0.60, blue: 0.78).opacity(0.45)
        case .next:    return Color(red: 0.62, green: 0.72, blue: 1.0).opacity(0.28)
        }
    }

    private var dotColor: Color {
        switch palette {
        case .current: return Color(red: 0.92, green: 0.45, blue: 0.40)
        case .next:    return Color(red: 0.55, green: 0.84, blue: 0.92)
        }
    }
}
