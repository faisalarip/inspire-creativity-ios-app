// catalog-id: tx-gooey-merge
import SwiftUI

// MARK: - Gooey Letter Merge
//
// Characters slide together and their soft blurred-threshold edges fuse into
// gooey metaball blobs, then crisp apart into clean letters, looping the
// melt-and-resolve via a blur + alpha-threshold mask drawn in a Canvas.
//
// Mechanism (pure Canvas, no Metal):
//   * All glyphs are drawn inside ONE drawLayer so their blur halos can overlap
//     and bridge into metaballs.
//   * Filter order matters: SwiftUI applies the LAST-added filter innermost, so
//     to get  content -> blur -> alphaThreshold  the threshold is added FIRST
//     and the blur SECOND.
//   * A single sine phase drives BOTH inter-letter spacing and blur radius so the
//     merge (spacing closed, blur high) and the resolve (spacing open, blur ~0)
//     stay perfectly locked together.
//   * The thresholded blobs are drawn in white and used as the alpha mask for a
//     warm gradient, which supplies the color.
//
// interaction == "auto": both demo branches run the same self-driving loop.
struct GooeyMergeView: View {
    var demo: Bool = false

    private let word = "GOO"

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let phase = self.phase(at: t)
                content(size: size, phase: phase)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Phase

    // A smooth 0...1 melt-and-resolve cycle on a ~3s loop.
    // 0 == fully resolved (crisp, spread). 1 == fully merged (gooey, tight).
    private func phase(at t: TimeInterval) -> CGFloat {
        let period: TimeInterval = 3.0
        let raw = (sin(t / period * 2.0 * .pi) + 1.0) / 2.0 // continuous, no seam
        return CGFloat(raw)
    }

    // MARK: - Composition

    @ViewBuilder
    private func content(size: CGSize, phase: CGFloat) -> some View {
        let dims = GooeyMergeView_Dimensions(size: size)

        ZStack {
            backdrop(dims: dims)

            // The gradient is the visible fill; the white thresholded blobs are
            // the alpha. Canvas background stays clear so the mask is shaped.
            gooGradient(phase: phase)
                .mask {
                    gooCanvas(dims: dims, phase: phase)
                }
                .shadow(color: shadowColor(phase: phase),
                        radius: dims.glow * phase,
                        x: 0, y: 0)
        }
        .frame(width: size.width, height: size.height)
    }

    private func backdrop(dims: GooeyMergeView_Dimensions) -> some View {
        RoundedRectangle(cornerRadius: dims.corner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.015, green: 0.020, blue: 0.040),
                        Color(red: 0.040, green: 0.030, blue: 0.070)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    // MARK: - The metaball Canvas
    //
    // Draws the word's glyphs into a single thresholded+blurred layer so adjacent
    // letters fuse. All output is WHITE; color is supplied by the gradient mask.
    private func gooCanvas(dims: GooeyMergeView_Dimensions, phase: CGFloat) -> some View {
        Canvas { context, canvasSize in
            // Blur shrinks toward ~0 as the word resolves (phase -> 0), giving
            // genuinely crisp letters at rest and gooey blobs at full merge.
            let blurRadius = dims.maxBlur * phase + dims.minBlur

            // FILTER ORDER (critical):
            //   alphaThreshold added FIRST  -> outermost  (runs last)
            //   blur            added SECOND -> innermost  (runs first)
            // Effective pipeline: glyphs -> blur -> alphaThreshold == metaballs.
            context.addFilter(.alphaThreshold(min: 0.5, color: .white))
            context.addFilter(.blur(radius: blurRadius))

            // ONE drawLayer enclosing every glyph so their halos can bridge.
            context.drawLayer { layer in
                self.drawGlyphs(in: layer,
                                canvasSize: canvasSize,
                                dims: dims,
                                phase: phase)
            }
        }
    }

    private func drawGlyphs(in layer: GraphicsContext,
                            canvasSize: CGSize,
                            dims: GooeyMergeView_Dimensions,
                            phase: CGFloat) {
        let chars = Array(word)
        guard !chars.isEmpty else { return }

        // Resolve each glyph once.
        let resolved: [GraphicsContext.ResolvedText] = chars.map { ch in
            let text = Text(String(ch))
                .font(.system(size: dims.fontSize, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            return layer.resolve(text)
        }

        let glyphSizes = resolved.map { $0.measure(in: canvasSize) }
        let totalGlyphWidth = glyphSizes.reduce(CGFloat(0)) { $0 + $1.width }

        // Spacing interpolates between spread (resolved) and tight/overlapping
        // (merged). At full merge the gap goes slightly negative so blur halos
        // overlap and bridge.
        let gap = dims.spreadGap + (dims.mergeGap - dims.spreadGap) * phase
        let count = CGFloat(chars.count)
        let totalWidth = totalGlyphWidth + gap * (count - 1)

        var cursorX = (canvasSize.width - totalWidth) / 2.0
        let centerY = canvasSize.height / 2.0

        for index in resolved.indices {
            let glyphSize = glyphSizes[index]
            let point = CGPoint(x: cursorX + glyphSize.width / 2.0, y: centerY)
            layer.draw(resolved[index], at: point, anchor: .center)
            cursorX += glyphSize.width + gap
        }
    }

    // MARK: - Color & glow

    private func gooGradient(phase: CGFloat) -> LinearGradient {
        // Palette stored as raw RGB components (no Color/UIColor round-trip),
        // so the in-file mix is self-contained and SwiftUI-only.
        let warm: RGB = (0.99, 0.62, 0.30)
        let pink: RGB = (0.98, 0.32, 0.55)
        let violet: RGB = (0.55, 0.35, 0.98)
        let cool: RGB = (0.30, 0.78, 0.98)

        // Hue warms slightly as the letters merge for extra life.
        let topRGB = mix(cool, warm, t: phase)
        let midRGB = mix(pink, warm, t: phase)
        let bottomRGB = mix(violet, pink, t: phase)

        let topColor = color(topRGB)
        let midColor = color(midRGB)
        let bottomColor = color(bottomRGB)

        return LinearGradient(
            colors: [topColor, midColor, bottomColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func shadowColor(phase: CGFloat) -> Color {
        Color(red: 0.98, green: 0.38, blue: 0.60).opacity(0.55 * phase + 0.10)
    }

    // MARK: - Pure RGB interpolation helpers (no UIKit, no Color round-trip)

    private typealias RGB = (r: Double, g: Double, b: Double)

    private func mix(_ a: RGB, _ b: RGB, t: CGFloat) -> RGB {
        let ta = Double(max(0, min(1, t)))
        return (
            r: a.r + (b.r - a.r) * ta,
            g: a.g + (b.g - a.g) * ta,
            b: a.b + (b.b - a.b) * ta
        )
    }

    private func color(_ c: RGB) -> Color {
        Color(red: c.r, green: c.g, blue: c.b)
    }
}

// MARK: - Geometry, all derived from the tile / detail size

private struct GooeyMergeView_Dimensions {
    let fontSize: CGFloat
    let spreadGap: CGFloat
    let mergeGap: CGFloat
    let maxBlur: CGFloat
    let minBlur: CGFloat
    let glow: CGFloat
    let corner: CGFloat

    init(size: CGSize) {
        let minSide = max(1, min(size.width, size.height))

        // Scale the heavy glyphs to the available space; bold + large so strokes
        // survive blur + threshold and never vanish.
        self.fontSize = minSide * 0.46

        // Positive spread when resolved; negative when merged so halos overlap.
        self.spreadGap = minSide * 0.06
        self.mergeGap = -fontSize * 0.34

        // Blur scales with geometry so bridges form identically at 120pt and at
        // a large detail size. Min blur keeps a soft tactile edge even at rest.
        self.maxBlur = fontSize * 0.22
        self.minBlur = max(0.6, fontSize * 0.015)

        self.glow = minSide * 0.10
        self.corner = minSide * 0.18
    }
}
