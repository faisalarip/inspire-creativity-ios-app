// catalog-id: mtl-develop-pixels
// catalog-metal: DevelopPixelsView.metal
import SwiftUI

/// Develop — content begins as huge mosaic blocks and resolves to full
/// resolution as a slider thumb is dragged across it, like a developing
/// Polaroid revealing pixel by pixel. A `.layerEffect` Metal shader snaps
/// each pixel's sample coordinate to the center of a grid cell, then the
/// cell-size uniform animates large → 1px.
///
/// - `demo == true`  : a self-driving TimelineView loop ramps the develop
///                     progress 0 → 1 → 0 on a slow eased cycle so the tile
///                     auto-develops and re-pixelates with no touch.
/// - `demo == false` : a real slider track + thumb. A DragGesture maps the
///                     thumb x (clamped 0…1) directly to develop progress;
///                     releasing holds the current position.
struct DevelopPixelsView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { proxy in
            content(size: proxy.size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    @ViewBuilder
    private func content(size: CGSize) -> some View {
        if demo {
            DevelopPixelsView_DemoDevelop(size: size)
        } else {
            DevelopPixelsView_InteractiveDevelop(size: size)
        }
    }
}

// MARK: - Shared tuning

private enum DevelopPixelsView_DevelopTuning {
    /// Roughly how many mosaic blocks span the width at the coarsest state.
    /// Driving cell size off the live size keeps the block *count* constant
    /// whether the view is a 120pt tile or a large detail area.
    static let blocksAcross: CGFloat = 9

    static func maxCell(for size: CGSize) -> CGFloat {
        let basis = max(min(size.width, size.height), 1)
        return max(basis / blocksAcross, 6)
    }

    /// Maps 0…1 develop progress to a cell size in points.
    /// progress 0 → coarse blocks, progress 1 → sharp (1px).
    static func cellSize(progress: CGFloat, maxCell: CGFloat) -> CGFloat {
        let p = min(max(progress, 0), 1)
        return 1 + (maxCell - 1) * (1 - p)
    }
}

// MARK: - Demo (self-driving)

private struct DevelopPixelsView_DemoDevelop: View {
    let size: CGSize

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let progress = developProgress(time: t)
            DevelopPixelsView_DevelopStage(size: size, progress: progress, thumb: nil)
        }
    }

    /// 0 → 1 → 0 on a ~3.6s loop, easing into both extremes so the image
    /// fully develops (1.0) and fully re-pixelates (0.0) each cycle.
    private func developProgress(time: Double) -> CGFloat {
        let period: Double = 3.6
        let phase = (time.truncatingRemainder(dividingBy: period)) / period
        // Triangle wave 0→1→0 so both endpoints are reached exactly.
        let tri = phase < 0.5 ? phase * 2 : (1 - phase) * 2
        // Smoothstep ease so it dwells slightly at sharp and at blocky.
        let eased = tri * tri * (3 - 2 * tri)
        return CGFloat(eased)
    }
}

// MARK: - Interactive (real slider)

private struct DevelopPixelsView_InteractiveDevelop: View {
    let size: CGSize

    @State private var progress: CGFloat = 0.62
    @GestureState private var dragging: Bool = false

    var body: some View {
        let geo = sliderGeometry(for: size)
        ZStack {
            DevelopPixelsView_DevelopStage(size: size, progress: progress, thumb: thumbInfo(geo: geo))
        }
        .contentShape(Rectangle())
        .gesture(dragGesture(geo: geo))
        .sensoryFeedback(.selection, trigger: detent)
    }

    // Fire a soft tick as the image crosses into "developed".
    private var detent: Bool { progress > 0.92 }

    private func dragGesture(geo: DevelopPixelsView_SliderGeometry) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($dragging) { _, state, _ in state = true }
            .onChanged { value in
                let x = value.location.x
                let raw = (x - geo.minX) / max(geo.span, 1)
                progress = min(max(raw, 0), 1)
            }
        // No .onEnded reset: releasing holds the current position.
    }

    private func thumbInfo(geo: DevelopPixelsView_SliderGeometry) -> DevelopPixelsView_ThumbInfo {
        DevelopPixelsView_ThumbInfo(
            x: geo.minX + geo.span * progress,
            y: geo.trackY,
            trackMinX: geo.minX,
            trackSpan: geo.span,
            radius: geo.thumbRadius,
            active: dragging
        )
    }

    private func sliderGeometry(for size: CGSize) -> DevelopPixelsView_SliderGeometry {
        let inset = max(size.width * 0.08, 12)
        let thumbRadius = max(min(size.width, size.height) * 0.05, 7)
        let trackY = size.height - max(size.height * 0.12, 18)
        return DevelopPixelsView_SliderGeometry(
            minX: inset,
            span: max(size.width - inset * 2, 1),
            trackY: trackY,
            thumbRadius: thumbRadius
        )
    }
}

private struct DevelopPixelsView_SliderGeometry {
    let minX: CGFloat
    let span: CGFloat
    let trackY: CGFloat
    let thumbRadius: CGFloat
}

private struct DevelopPixelsView_ThumbInfo {
    let x: CGFloat
    let y: CGFloat
    let trackMinX: CGFloat
    let trackSpan: CGFloat
    let radius: CGFloat
    let active: Bool
}

// MARK: - Stage: composed content + develop shader + optional slider UI

private struct DevelopPixelsView_DevelopStage: View {
    let size: CGSize
    let progress: CGFloat
    let thumb: DevelopPixelsView_ThumbInfo?

    var body: some View {
        let maxCell = DevelopPixelsView_DevelopTuning.maxCell(for: size)
        let cell = DevelopPixelsView_DevelopTuning.cellSize(progress: progress, maxCell: maxCell)
        ZStack {
            developedScene(maxCell: maxCell, cell: cell)
            if let thumb {
                DevelopPixelsView_SliderOverlay(info: thumb)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func developedScene(maxCell: CGFloat, cell: CGFloat) -> some View {
        DevelopPixelsView_DevelopScene()
            .layerEffect(
                ShaderLibrary.developPixels(.float(Float(cell))),
                maxSampleOffset: CGSize(width: maxCell, height: maxCell),
                isEnabled: cell > 1.01
            )
    }
}

// MARK: - The colorful scene that gets pixel-developed

private struct DevelopPixelsView_DevelopScene: View {
    var body: some View {
        ZStack {
            sky
            sun
            farHills
            nearHills
            water
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .drawingGroup() // flatten so the shader samples one composited layer
    }

    private var sky: some View {
        LinearGradient(
            colors: [
                Color(red: 0.99, green: 0.78, blue: 0.40),
                Color(red: 0.97, green: 0.55, blue: 0.42),
                Color(red: 0.78, green: 0.39, blue: 0.55),
                Color(red: 0.40, green: 0.30, blue: 0.58)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var sun: some View {
        GeometryReader { proxy in
            let s = proxy.size
            let r = min(s.width, s.height) * 0.20
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 1.0, green: 0.97, blue: 0.80).opacity(0.85),
                                Color(red: 1.0, green: 0.85, blue: 0.55).opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: r * 2.4
                        )
                    )
                    .frame(width: r * 4.8, height: r * 4.8)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 1.0, green: 0.99, blue: 0.88),
                                Color(red: 1.0, green: 0.86, blue: 0.50)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: r
                        )
                    )
                    .frame(width: r * 2, height: r * 2)
            }
            .position(x: s.width * 0.66, y: s.height * 0.34)
        }
    }

    private var farHills: some View {
        GeometryReader { proxy in
            let s = proxy.size
            DevelopPixelsView_HillShape(crest: 0.58, amplitude: 0.07, phase: 0.0)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.56, green: 0.34, blue: 0.52),
                            Color(red: 0.42, green: 0.27, blue: 0.50)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: s.width, height: s.height)
        }
    }

    private var nearHills: some View {
        GeometryReader { proxy in
            let s = proxy.size
            DevelopPixelsView_HillShape(crest: 0.70, amplitude: 0.10, phase: 1.7)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.24, green: 0.20, blue: 0.40),
                            Color(red: 0.13, green: 0.12, blue: 0.28)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: s.width, height: s.height)
        }
    }

    private var water: some View {
        GeometryReader { proxy in
            let s = proxy.size
            let top = s.height * 0.78
            LinearGradient(
                colors: [
                    Color(red: 0.85, green: 0.52, blue: 0.46),
                    Color(red: 0.46, green: 0.32, blue: 0.55),
                    Color(red: 0.20, green: 0.18, blue: 0.40)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: s.width, height: s.height - top)
            .position(x: s.width / 2, y: top + (s.height - top) / 2)
        }
    }
}

/// A smooth rolling hill silhouette filling the lower part of the frame.
private struct DevelopPixelsView_HillShape: Shape {
    /// Crest baseline as a fraction of height (0 = top, 1 = bottom).
    var crest: CGFloat
    /// Wave amplitude as a fraction of height.
    var amplitude: CGFloat
    /// Phase offset so layered hills don't align.
    var phase: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let baseY = rect.height * crest
        let amp = rect.height * amplitude
        let steps = 28
        path.move(to: CGPoint(x: 0, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: baseY))
        for i in 0...steps {
            let fx = CGFloat(i) / CGFloat(steps)
            let x = rect.minX + fx * rect.width
            let wave = sin(fx * .pi * 2 + phase) + 0.4 * sin(fx * .pi * 5 + phase)
            let y = baseY - wave * amp
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Slider overlay (interactive affordance)

private struct DevelopPixelsView_SliderOverlay: View {
    let info: DevelopPixelsView_ThumbInfo

    var body: some View {
        ZStack {
            track
            fill
            thumb
        }
        .allowsHitTesting(false)
    }

    private var track: some View {
        Capsule()
            .fill(Color.white.opacity(0.22))
            .frame(width: info.trackSpan, height: trackHeight)
            .position(x: info.trackMinX + info.trackSpan / 2, y: info.y)
    }

    private var fill: some View {
        let w = max(info.x - info.trackMinX, 0)
        return Capsule()
            .fill(Color.white.opacity(0.9))
            .frame(width: w, height: trackHeight)
            .position(x: info.trackMinX + w / 2, y: info.y)
    }

    private var thumb: some View {
        let r = info.radius * (info.active ? 1.18 : 1.0)
        return ZStack {
            Circle()
                .fill(Color.white.opacity(0.30))
                .frame(width: r * 2.6, height: r * 2.6)
                .blur(radius: r * 0.5)
            Circle()
                .fill(Color.white)
                .frame(width: r * 2, height: r * 2)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
        }
        .position(x: info.x, y: info.y)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: info.active)
    }

    private var trackHeight: CGFloat { max(info.radius * 0.5, 3) }
}
