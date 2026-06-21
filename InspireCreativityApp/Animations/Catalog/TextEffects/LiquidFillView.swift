// catalog-id: tx-liquid-fill
import SwiftUI

// MARK: - Liquid Fill Letters
//
// Each glyph is masked by a rising liquid level with a wobbling sine surface
// and a couple of buoyant bubbles, filling from an empty outline to full
// color, with a subtle meniscus highlight at the waterline.
//
// The load-bearing masking is `.mask { Text }`, which clips identically on
// iOS 17 and 18, so no version split touches the core effect. The "empty"
// glyph state is a dim translucent fill with a thin lighter overlay so the
// letters always read as hollow vessels waiting to be filled.

struct LiquidFillView: View {
    var demo: Bool = false

    private let word: String = "LIQUID"

    var body: some View {
        GeometryReader { geo in
            let size: CGSize = geo.size
            let fs: CGFloat = fontSize(for: size)

            TimelineView(.animation) { timeline in
                let t: Double = timeline.date.timeIntervalSinceReferenceDate
                let level: CGFloat = fillLevel(at: t)

                ZStack {
                    // Empty letters — always legible so the tile is never blank.
                    emptyGlyphs(fontSize: fs)

                    // Rising liquid, clipped to the exact glyph shapes.
                    liquidLayer(level: level, time: t)
                        .mask { glyphText(fontSize: fs) }
                }
                .frame(width: size.width, height: size.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Fill progression (fill up, hold, drain — no hard reset flash)

    private func fillLevel(at time: Double) -> CGFloat {
        let period: Double = 3.4
        let phase: Double = time.truncatingRemainder(dividingBy: period) / period
        let raw: Double
        if phase < 0.5 {
            raw = eased(phase / 0.5)           // 0 -> 1 fill
        } else if phase < 0.62 {
            raw = 1.0                           // brief full hold
        } else {
            raw = 1.0 - eased((phase - 0.62) / 0.38)  // 1 -> 0 drain
        }
        // Never fully empty: keep a sliver of liquid so motion always reads.
        return CGFloat(0.06 + raw * 0.94)
    }

    private func eased(_ x: Double) -> Double {
        let c: Double = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)             // smoothstep
    }

    // MARK: Glyph layers

    private func glyphText(fontSize fs: CGFloat) -> some View {
        Text(word)
            .font(.system(size: fs, weight: .heavy, design: .rounded))
            .tracking(fs * 0.04)
            .lineLimit(1)
            .minimumScaleFactor(0.3)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyGlyphs(fontSize fs: CGFloat) -> some View {
        ZStack {
            // Dim translucent body — the "empty" vessel.
            glyphText(fontSize: fs)
                .foregroundStyle(emptyFillColor)
            // Thin lighter edge to suggest a hollow outline.
            glyphText(fontSize: fs)
                .foregroundStyle(outlineColor)
                .blendMode(.screen)
                .opacity(0.5)
        }
    }

    // MARK: Liquid

    private func liquidLayer(level: CGFloat, time: Double) -> some View {
        Canvas { ctx, canvasSize in
            let band: ClosedRange<CGFloat> = glyphBand(in: canvasSize)
            let waterY: CGFloat = band.upperBound - level * (band.upperBound - band.lowerBound)

            drawBody(ctx: ctx, size: canvasSize, waterY: waterY, time: time)
            drawBubbles(ctx: ctx, size: canvasSize, waterY: waterY, time: time)
            drawMeniscus(ctx: ctx, size: canvasSize, waterY: waterY, time: time)
        }
    }

    // The vertical band the glyphs roughly occupy (centered cap-height region).
    private func glyphBand(in size: CGSize) -> ClosedRange<CGFloat> {
        let fs: CGFloat = fontSize(for: size)
        let capHeight: CGFloat = fs * 0.72
        let center: CGFloat = size.height / 2
        let top: CGFloat = center - capHeight / 2
        let bottom: CGFloat = center + capHeight / 2
        return top...bottom
    }

    // MARK: Surface geometry

    private func surfaceY(_ x: CGFloat, size: CGSize, waterY: CGFloat, time: Double) -> CGFloat {
        let amp: CGFloat = max(size.height * 0.012, 1.5)
        let k1: CGFloat = 2.4 * .pi / max(size.width, 1)
        let k2: CGFloat = 5.1 * .pi / max(size.width, 1)
        let p1: CGFloat = CGFloat(time * 1.6)
        let p2: CGFloat = CGFloat(time * 2.7)
        let wobble: CGFloat = sin(x * k1 + p1) * amp + sin(x * k2 + p2) * (amp * 0.45)
        return waterY + wobble
    }

    private func surfacePath(size: CGSize, waterY: CGFloat, time: Double) -> Path {
        var path = Path()
        let step: CGFloat = max(size.width / 48, 2)
        path.move(to: CGPoint(x: 0, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: surfaceY(0, size: size, waterY: waterY, time: time)))
        var x: CGFloat = step
        while x <= size.width {
            path.addLine(to: CGPoint(x: x, y: surfaceY(x, size: size, waterY: waterY, time: time)))
            x += step
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()
        return path
    }

    private func drawBody(ctx: GraphicsContext, size: CGSize, waterY: CGFloat, time: Double) {
        let body: Path = surfacePath(size: size, waterY: waterY, time: time)
        let gradient = Gradient(stops: [
            .init(color: liquidTop, location: 0.0),
            .init(color: liquidMid, location: 0.45),
            .init(color: liquidDeep, location: 1.0)
        ])
        ctx.fill(
            body,
            with: .linearGradient(
                gradient,
                startPoint: CGPoint(x: size.width / 2, y: waterY),
                endPoint: CGPoint(x: size.width / 2, y: size.height)
            )
        )
    }

    private func drawMeniscus(ctx: GraphicsContext, size: CGSize, waterY: CGFloat, time: Double) {
        var line = Path()
        let step: CGFloat = max(size.width / 48, 2)
        line.move(to: CGPoint(x: 0, y: surfaceY(0, size: size, waterY: waterY, time: time)))
        var x: CGFloat = step
        while x <= size.width {
            line.addLine(to: CGPoint(x: x, y: surfaceY(x, size: size, waterY: waterY, time: time)))
            x += step
        }
        ctx.stroke(
            line,
            with: .color(meniscusColor),
            style: StrokeStyle(lineWidth: max(size.height * 0.01, 1.4), lineCap: .round)
        )
    }

    private func drawBubbles(ctx: GraphicsContext, size: CGSize, waterY: CGFloat, time: Double) {
        for seed in bubbleSeeds {
            let cycle: Double = time / seed.duration + seed.offset
            let prog: Double = cycle.truncatingRemainder(dividingBy: 1.0)

            // Bubble rises from near the bottom up toward the waterline.
            let bottom: CGFloat = size.height * 0.96
            let target: CGFloat = waterY + size.height * 0.04
            let by: CGFloat = bottom - CGFloat(prog) * (bottom - target)

            // Only show bubbles that are submerged (below the wobbling surface).
            guard by > waterY else { continue }

            let sway: CGFloat = sin(CGFloat(time) * seed.swaySpeed + seed.phase) * size.width * 0.012
            let bx: CGFloat = size.width * seed.x + sway
            let r: CGFloat = size.height * seed.radius
            let rect = CGRect(x: bx - r, y: by - r, width: r * 2, height: r * 2)

            // Fade in near birth, fade out as it nears the surface.
            let fade: Double = max(min(prog * 5, 1) * min((1 - prog) * 4, 1), 0)
            ctx.fill(Path(ellipseIn: rect),
                     with: .color(bubbleColor.opacity(0.55 * fade)))

            // Tiny specular dot on each bubble.
            let hr: CGFloat = r * 0.4
            let hrect = CGRect(x: bx - r * 0.3 - hr / 2, y: by - r * 0.3 - hr / 2,
                               width: hr, height: hr)
            ctx.fill(Path(ellipseIn: hrect),
                     with: .color(Color(red: 1, green: 1, blue: 1).opacity(0.5 * fade)))
        }
    }

    // MARK: Layout

    private func fontSize(for size: CGSize) -> CGFloat {
        let byHeight: CGFloat = size.height * 0.5
        let byWidth: CGFloat = size.width / CGFloat(max(word.count, 1)) * 1.5
        return min(byHeight, byWidth)
    }

    // MARK: Palette (literals only — no design-system dependency)

    private var liquidTop: Color { Color(red: 0.38, green: 0.82, blue: 0.98) }
    private var liquidMid: Color { Color(red: 0.20, green: 0.56, blue: 0.95) }
    private var liquidDeep: Color { Color(red: 0.10, green: 0.30, blue: 0.78) }
    private var meniscusColor: Color { Color(red: 0.80, green: 0.95, blue: 1.0).opacity(0.9) }
    private var bubbleColor: Color { Color(red: 0.85, green: 0.96, blue: 1.0) }
    private var outlineColor: Color { Color(red: 0.42, green: 0.55, blue: 0.72) }
    private var emptyFillColor: Color { Color(red: 0.30, green: 0.42, blue: 0.62).opacity(0.40) }

    private var bubbleSeeds: [LiquidFillView_BubbleSeed] {
        [
            LiquidFillView_BubbleSeed(x: 0.22, radius: 0.045, duration: 2.6, offset: 0.0,
                       swaySpeed: 2.1, phase: 0.0),
            LiquidFillView_BubbleSeed(x: 0.55, radius: 0.032, duration: 3.3, offset: 0.45,
                       swaySpeed: 2.7, phase: 1.3),
            LiquidFillView_BubbleSeed(x: 0.80, radius: 0.052, duration: 2.9, offset: 0.78,
                       swaySpeed: 1.8, phase: 2.6)
        ]
    }
}

// MARK: - Bubble seed

private struct LiquidFillView_BubbleSeed {
    var x: CGFloat
    var radius: CGFloat
    var duration: Double
    var offset: Double
    var swaySpeed: CGFloat
    var phase: CGFloat
}
