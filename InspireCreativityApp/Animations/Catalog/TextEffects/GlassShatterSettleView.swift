//
//  GlassShatterSettleView.swift
//  InspireCreativityApp — Bespoke catalog animation
//
//  Glass Shatter Settle: the headline appears as offset angular shards that fly
//  back together from the edges, each glyph rotating and decelerating into
//  perfect alignment — like time-reversed breaking.
//
//  Uses iOS 18 `TextRenderer` for per-glyph transforms; falls back to a plain
//  fade on iOS 17. Self-contained: SwiftUI only.
//  `demo == true`  → self-driving shatter→assemble loop (grid tile).
//  `demo == false` → tap re-fires the assembly (Detail + the buyer's code).
//

// catalog-id: tx-shatter-glass
import SwiftUI

struct GlassShatterSettleView: View {
    var demo: Bool = false
    @State private var assembled = false

    var body: some View {
        if #available(iOS 18.0, *) {
            modern
        } else {
            fallback
        }
    }

    @available(iOS 18.0, *)
    @ViewBuilder private var modern: some View {
        if demo {
            TimelineView(.animation) { ctx in
                shatterText(progress: Self.loopProgress(ctx.date))
            }
        } else {
            shatterText(progress: assembled ? 1 : 0)
                .contentShape(Rectangle())
                .onTapGesture { refire() }
                .onAppear { refire() }
        }
    }

    private func refire() {
        assembled = false
        withAnimation(.spring(response: 0.75, dampingFraction: 0.6)) { assembled = true }
    }

    @available(iOS 18.0, *)
    private func shatterText(progress: CGFloat) -> some View {
        ZStack {
            Color(red: 0.04, green: 0.05, blue: 0.09)
            Text("SHATTER")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.white, Color(red: 0.7, green: 0.9, blue: 1.0)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .textRenderer(ShatterTextRenderer(progress: progress))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fallback: some View {
        ZStack {
            Color(red: 0.04, green: 0.05, blue: 0.09)
            Text("SHATTER")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// scatter → assemble → hold, on a ~3s loop.
    static func loopProgress(_ date: Date) -> CGFloat {
        let period = 3.0
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
        if t < 0.15 { return 0 }
        if t < 0.72 {
            let u = (t - 0.15) / 0.57
            return CGFloat(u * u * (3 - 2 * u))
        }
        return 1
    }
}

@available(iOS 18.0, *)
struct ShatterTextRenderer: TextRenderer {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        let scatter = 1 - max(0, min(progress, 1))
        var index = 0
        for line in layout {
            for run in line {
                for glyph in run {
                    index += 1
                    let seed = Double(index) * 12.9898
                    let dx = CGFloat(cos(seed)) * 130 * scatter
                    let dy = CGFloat(sin(seed * 1.7)) * 90 * scatter
                    let angle = Angle.degrees(cos(seed * 0.7) * 75 * Double(scatter))

                    let rect = glyph.typographicBounds.rect
                    let center = CGPoint(x: rect.midX, y: rect.midY)

                    var copy = ctx
                    copy.opacity = Double(min(1, progress * 1.5))
                    copy.translateBy(x: dx, y: dy)
                    copy.translateBy(x: center.x, y: center.y)
                    copy.rotate(by: angle)
                    copy.translateBy(x: -center.x, y: -center.y)
                    copy.draw(glyph)
                }
            }
        }
    }
}
