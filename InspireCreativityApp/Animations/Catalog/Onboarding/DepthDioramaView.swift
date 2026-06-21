// catalog-id: ob-depth-diorama
import SwiftUI

// Depth Diorama Swipe
// A 4-layer, code-drawn parallax scene (sky, hills, midground, foreground).
// Dragging scrubs a paged "camera"; layers offset by their depth factor so the
// world has real depth. Released, it springs to the nearest page with each layer
// overshooting at its own parallaxed rate. In demo mode a TimelineView pans the
// camera gently side to side on a loop so the tile stays alive with no touch.

struct DepthDioramaView: View {
    var demo: Bool = false

    // Page state (interactive mode). Progress is measured in *page units*:
    // 0 = first page, 1 = second page, 2 = third page.
    @State private var page: Int = 1
    @State private var liveProgress: CGFloat = 1   // animatable camera position in page units
    @State private var dragFraction: CGFloat = 0   // live drag contribution, page units

    private let pageCount: Int = 3

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            content(size: size)
                .frame(width: size.width, height: size.height)
                .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Seed interactive camera at the middle page.
            liveProgress = CGFloat(startPage)
            page = startPage
        }
    }

    private var startPage: Int { pageCount / 2 }

    // MARK: - Content router

    @ViewBuilder
    private func content(size: CGSize) -> some View {
        if demo {
            demoScene(size: size)
        } else {
            interactiveScene(size: size)
        }
    }

    // MARK: - Demo (self-driving)

    private func demoScene(size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            // ~3.4s loop. Pan the camera around the middle page by ±0.62 of a page
            // so we reveal neighbouring scene content without ever sweeping past
            // the covered strip width.
            let phase = t.truncatingRemainder(dividingBy: 3.4) / 3.4
            let swing = sin(phase * 2 * .pi)
            let progress = CGFloat(startPage) + CGFloat(swing) * 0.62
            diorama(progress: progress, size: size)
        }
    }

    // MARK: - Interactive (real component)

    private func interactiveScene(size: CGSize) -> some View {
        let progress = liveProgress + dragFraction
        let pageWidth = max(size.width, 1)

        return diorama(progress: progress, size: size)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // translation.width / pageWidth -> page progress.
                        // Drag left (negative) advances forward (+progress).
                        var frac = -value.translation.width / pageWidth
                        let raw = CGFloat(page) + frac
                        // Rubber-band beyond the first/last page so over-drag
                        // resists instead of running off the scene.
                        if raw < 0 {
                            frac -= raw * 0.55
                        } else if raw > CGFloat(pageCount - 1) {
                            frac -= (raw - CGFloat(pageCount - 1)) * 0.55
                        }
                        dragFraction = frac
                    }
                    .onEnded { value in
                        let predicted = -value.predictedEndTranslation.width / pageWidth
                        let projected = CGFloat(page) + predicted
                        let target = clampPage(Int(projected.rounded()))

                        // Fold the live drag into liveProgress, then spring to the
                        // target page so layers overshoot at their own rates.
                        liveProgress += dragFraction
                        dragFraction = 0
                        page = target

                        let velocity = -value.velocity.width / pageWidth
                        withAnimation(
                            .interpolatingSpring(mass: 1.0, stiffness: 130, damping: 16, initialVelocity: Double(velocity))
                        ) {
                            liveProgress = CGFloat(target)
                        }
                    }
            )
    }

    private func clampPage(_ p: Int) -> Int {
        min(max(p, 0), pageCount - 1)
    }

    // MARK: - Shared offset math

    /// The single source of truth for both modes.
    /// offset = progress (in page units) * depth * pageWidth, negated so that
    /// increasing progress moves the world left (camera moves right).
    private func layerOffset(depth: CGFloat, progress: CGFloat, pageWidth: CGFloat) -> CGFloat {
        -progress * depth * pageWidth
    }

    /// Width each layer must be drawn at so no edge ever reveals blank, including
    /// the foreground (depth ~1.0) translating a full pageWidth per page across
    /// all pages, plus headroom for the spring overshoot.
    private func stripWidth(pageWidth: CGFloat) -> CGFloat {
        let pages = CGFloat(pageCount)
        let overshootMargin = pageWidth * 0.9
        return pageWidth * pages + overshootMargin
    }

    // MARK: - The diorama (4 layers)

    private func diorama(progress: CGFloat, size: CGSize) -> some View {
        let w = size.width
        let h = size.height
        let strip = stripWidth(pageWidth: w)

        // Depth factors: slow sky -> fast foreground.
        let skyDepth: CGFloat = 0.10
        let hillDepth: CGFloat = 0.32
        let midDepth: CGFloat = 0.62
        let fgDepth: CGFloat = 1.00

        return ZStack {
            skyLayer(strip: strip, height: h, progress: progress, pageWidth: w)
                .offset(x: layerOffset(depth: skyDepth, progress: progress, pageWidth: w))

            hillsLayer(strip: strip, height: h)
                .offset(x: layerOffset(depth: hillDepth, progress: progress, pageWidth: w))

            midgroundLayer(strip: strip, height: h, pageWidth: w)
                .offset(x: layerOffset(depth: midDepth, progress: progress, pageWidth: w))

            foregroundLayer(strip: strip, height: h)
                .offset(x: layerOffset(depth: fgDepth, progress: progress, pageWidth: w))
        }
        .frame(width: w, height: h)
    }

    // MARK: Layer 1 — Sky (with travelling sun/moon detents)

    private func skyLayer(strip: CGFloat, height: CGFloat, progress: CGFloat, pageWidth: CGFloat) -> some View {
        // Blend the sky gradient across pages: dawn -> day -> dusk.
        let frac = progress / CGFloat(max(pageCount - 1, 1))
        let topColor = blendColor(
            RGB(0.16, 0.21, 0.42),   // dawn indigo
            RGB(0.36, 0.62, 0.92),   // day blue
            RGB(0.45, 0.24, 0.40),   // dusk plum
            t: frac
        )
        let bottomColor = blendColor(
            RGB(0.55, 0.45, 0.58),
            RGB(0.78, 0.88, 0.96),
            RGB(0.95, 0.62, 0.46),
            t: frac
        )

        return ZStack {
            LinearGradient(
                colors: [topColor, bottomColor],
                startPoint: .top,
                endPoint: .bottom
            )
            celestialBody(strip: strip, height: height, frac: frac)
        }
        .frame(width: strip, height: height)
    }

    private func celestialBody(strip: CGFloat, height: CGFloat, frac: CGFloat) -> some View {
        // Sun arcs up and across the sky as we move through pages.
        let cx = strip * (0.22 + 0.56 * frac)
        let arc = CGFloat(sin(Double(frac) * .pi))   // 0 -> 1 -> 0
        let cy = height * (0.42 - 0.20 * arc)
        let r = max(height * 0.13, 14)
        let warm = blendColor(
            RGB(1.0, 0.93, 0.78),
            RGB(1.0, 0.97, 0.86),
            RGB(1.0, 0.78, 0.55),
            t: frac
        )
        return Circle()
            .fill(
                RadialGradient(
                    colors: [warm, warm.opacity(0.0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: r * 1.6
                )
            )
            .frame(width: r * 2.2, height: r * 2.2)
            .position(x: cx, y: cy)
    }

    // MARK: Layer 2 — Far hills

    private func hillsLayer(strip: CGFloat, height: CGFloat) -> some View {
        DepthDioramaView_HillsShape(baseline: 0.46, amplitude: 0.12, waves: 4.5, phase: 0.0)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.34, green: 0.45, blue: 0.55),
                        Color(red: 0.22, green: 0.32, blue: 0.42)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: strip, height: height)
    }

    // MARK: Layer 3 — Midground hills with trees (props)

    private func midgroundLayer(strip: CGFloat, height: CGFloat, pageWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            DepthDioramaView_HillsShape(baseline: 0.62, amplitude: 0.16, waves: 3.0, phase: 1.3)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.20, green: 0.40, blue: 0.34),
                            Color(red: 0.12, green: 0.28, blue: 0.24)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: strip, height: height)

            // A few trees spaced along the strip — distinct props per "page".
            ForEach(0..<7, id: \.self) { i in
                let x = strip * (0.10 + 0.12 * CGFloat(i))
                let baseY = height * (0.60 + 0.015 * CGFloat(i % 3))
                tree(height: height * (0.16 + 0.03 * CGFloat(i % 2)))
                    .position(x: x, y: baseY)
            }
        }
        .frame(width: strip, height: height)
    }

    private func tree(height treeH: CGFloat) -> some View {
        VStack(spacing: -treeH * 0.28) {
            DepthDioramaView_Triangle()
                .fill(Color(red: 0.10, green: 0.30, blue: 0.22))
                .frame(width: treeH * 0.7, height: treeH * 0.7)
            DepthDioramaView_Triangle()
                .fill(Color(red: 0.13, green: 0.34, blue: 0.25))
                .frame(width: treeH * 0.9, height: treeH * 0.8)
        }
    }

    // MARK: Layer 4 — Foreground ground + grass tufts

    private func foregroundLayer(strip: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            DepthDioramaView_HillsShape(baseline: 0.86, amplitude: 0.06, waves: 5.0, phase: 0.4)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.16, green: 0.24, blue: 0.16),
                            Color(red: 0.06, green: 0.12, blue: 0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: strip, height: height)

            ForEach(0..<14, id: \.self) { i in
                let x = strip * (0.04 + 0.066 * CGFloat(i))
                grassTuft(height: height * (0.10 + 0.04 * CGFloat(i % 3)))
                    .position(x: x, y: height * (0.86 + 0.01 * CGFloat(i % 2)))
            }
        }
        .frame(width: strip, height: height)
    }

    private func grassTuft(height tuftH: CGFloat) -> some View {
        Capsule()
            .fill(Color(red: 0.10, green: 0.20, blue: 0.12))
            .frame(width: max(tuftH * 0.18, 2), height: tuftH)
    }

    // MARK: - Color blending helper (dawn -> day -> dusk)

    /// A plain RGB triple so blending stays pure-Swift (no UIKit round-trip).
    struct RGB {
        var r: CGFloat
        var g: CGFloat
        var b: CGFloat
        init(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) {
            self.r = r
            self.g = g
            self.b = b
        }
        var color: Color {
            Color(red: Double(r), green: Double(g), blue: Double(b))
        }
    }

    private func blendColor(_ a: RGB, _ b: RGB, _ c: RGB, t: CGFloat) -> Color {
        let tt = min(max(t, 0), 1)
        if tt < 0.5 {
            return mix(a, b, ratio: tt / 0.5).color
        } else {
            return mix(b, c, ratio: (tt - 0.5) / 0.5).color
        }
    }

    private func mix(_ a: RGB, _ b: RGB, ratio: CGFloat) -> RGB {
        let r = min(max(ratio, 0), 1)
        return RGB(
            a.r + (b.r - a.r) * r,
            a.g + (b.g - a.g) * r,
            a.b + (b.b - a.b) * r
        )
    }
}

// MARK: - Shapes

/// A rolling hills silhouette filling from a baseline to the bottom of the rect.
private struct DepthDioramaView_HillsShape: Shape {
    var baseline: CGFloat   // 0..1 fraction of height where the ridge sits
    var amplitude: CGFloat  // 0..1 fraction of height of the wave swing
    var waves: CGFloat      // number of wave humps across the width
    var phase: CGFloat      // phase offset in radians

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let baseY = h * baseline
        let amp = h * amplitude
        let step: CGFloat = max(w / 80, 2)

        path.move(to: CGPoint(x: 0, y: h))
        var x: CGFloat = 0
        while x <= w {
            let theta = (x / w) * waves * 2 * .pi + phase
            let y = baseY - CGFloat(sin(Double(theta))) * amp
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }
        path.addLine(to: CGPoint(x: w, y: h))
        path.closeSubpath()
        return path
    }
}

/// An upward-pointing triangle (tree canopy tier).
private struct DepthDioramaView_Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
