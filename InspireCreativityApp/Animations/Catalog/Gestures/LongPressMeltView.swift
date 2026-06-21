// catalog-id: ges-long-press-melt
import SwiftUI

/// Long-Press Melt Button
/// Hold the button and it softens, drooping and sagging while gooey teardrop
/// drips form and lengthen along the bottom edge; release springs it back solid.
///
/// The goo is achieved with a Canvas metaball: a rounded-rect body plus several
/// drip circles are drawn into a single `drawLayer` with `.alphaThreshold` + `.blur`
/// filters so overlapping shapes fuse into one liquid mass. That mass is used as a
/// `.mask` over a gradient so the button keeps its color and a glossy highlight.
///
/// Redraw engine is `TimelineView(.animation)` for BOTH demo and interactive modes
/// (PhaseAnimator hands the closure a discrete phase, which would snap the Canvas
/// rather than melt it smoothly). `meltLevel` is derived from time/state each tick.
struct LongPressMeltView: View {
    var demo: Bool = false

    // Interactive press state.
    @State private var pressStart: Date? = nil
    @State private var releaseStart: Date? = nil
    @State private var releaseFromLevel: CGFloat = 0

    // Time to reach full melt while holding.
    private let chargeDuration: Double = 1.6
    // Bouncy snap-back duration on release.
    private let releaseDuration: Double = 0.9

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let now = timeline.date
                let level = currentMeltLevel(now: now)
                meltCanvas(level: level, size: geo.size)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            // Keep the gesture attached in both modes; in demo, route the press to
            // subviews so the self-driving TimelineView loop owns the animation.
            // (An `Optional` gesture via `demo ? nil : pressGesture` does NOT compile
            // on iOS 17 because Optional does not conform to Gesture.)
            .gesture(pressGesture, including: demo ? .subviews : .all)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Melt level

    /// Returns the current melt amount 0...1 for this frame.
    private func currentMeltLevel(now: Date) -> CGFloat {
        if demo {
            return demoMeltLevel(now: now)
        }
        return interactiveMeltLevel(now: now)
    }

    /// Self-driving loop: rest → sag+drip → bouncy snap-back → rest, on ~3.2s.
    private func demoMeltLevel(now: Date) -> CGFloat {
        let period: Double = 3.2
        let t = now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
        // Hold a short solid beat, ramp up with ease, hold full briefly, then a
        // bouncy spring snap-back to solid.
        if t < 0.12 {
            return 0
        } else if t < 0.55 {
            let p = (t - 0.12) / 0.43
            return easeInOut(p)
        } else if t < 0.62 {
            return 1
        } else {
            let p = (t - 0.62) / 0.38
            return springBack(from: 1, progress: p)
        }
    }

    /// Interactive: while pressed, melt grows; on release it springs back to solid.
    private func interactiveMeltLevel(now: Date) -> CGFloat {
        if let start = pressStart {
            let elapsed = now.timeIntervalSince(start)
            return clamp01(CGFloat(elapsed / chargeDuration))
        }
        if let rel = releaseStart {
            let elapsed = now.timeIntervalSince(rel)
            let p = CGFloat(elapsed / releaseDuration)
            if p >= 1 { return 0 }
            return springBack(from: releaseFromLevel, progress: Double(p))
        }
        return 0
    }

    // MARK: - Gesture

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                // DragGesture does not keep firing while stationary, so we record a
                // start instant once and integrate elapsed time in the timeline.
                if pressStart == nil {
                    pressStart = Date()
                    releaseStart = nil
                }
            }
            .onEnded { _ in
                let level = interactiveMeltLevel(now: Date())
                releaseFromLevel = level
                releaseStart = Date()
                pressStart = nil
            }
    }

    // MARK: - Canvas

    @ViewBuilder
    private func meltCanvas(level: CGFloat, size: CGSize) -> some View {
        let metrics = layout(for: size)
        // The fused metaball mass (alphaThreshold + blur) acts as a mask so the
        // gradient body + highlight show through, keeping the button colorful.
        gradientBody(metrics: metrics, level: level)
            .mask(
                Canvas { context, _ in
                    drawGooMask(into: &context, metrics: metrics, level: level)
                }
            )
            .overlay(glossHighlight(metrics: metrics, level: level))
            .overlay(label(metrics: metrics, level: level))
    }

    /// Draws the rounded-rect body and the drip circles into one filtered layer so
    /// overlapping shapes merge into a single liquid blob.
    private func drawGooMask(into context: inout GraphicsContext,
                             metrics: Metrics,
                             level: CGFloat) {
        let blur = metrics.blobRadius * (0.55 + level * 0.35)
        context.addFilter(.alphaThreshold(min: 0.5, color: .white))
        context.addFilter(.blur(radius: blur))
        context.drawLayer { layer in
            // Body sags downward as it melts.
            let sag = metrics.maxSag * level
            let bodyRect = CGRect(
                x: metrics.bodyRect.minX,
                y: metrics.bodyRect.minY,
                width: metrics.bodyRect.width,
                height: metrics.bodyRect.height + sag * 0.6
            )
            let corner = metrics.corner + sag * 0.5
            let bodyPath = Path(roundedRect: bodyRect, cornerRadius: corner)
            layer.fill(bodyPath, with: .color(.white))

            for blob in drips(metrics: metrics, level: level) {
                let circle = Path(ellipseIn: CGRect(
                    x: blob.center.x - blob.radius,
                    y: blob.center.y - blob.radius,
                    width: blob.radius * 2,
                    height: blob.radius * 2
                ))
                layer.fill(circle, with: .color(.white))
            }
        }
    }

    /// Computes drip blob centers + radii along the bottom edge for this melt level.
    private func drips(metrics: Metrics, level: CGFloat) -> [(center: CGPoint, radius: CGFloat)] {
        guard level > 0.02 else { return [] }
        var result: [(center: CGPoint, radius: CGFloat)] = []
        let baseY = metrics.bodyRect.maxY + metrics.maxSag * level * 0.6
        let count = metrics.dripCount
        for i in 0..<count {
            // Each drip has its own phase so they grow at slightly different rates.
            let phase = CGFloat(i) / CGFloat(max(count - 1, 1))
            let xFraction = 0.18 + phase * 0.64
            let x = metrics.bodyRect.minX + metrics.bodyRect.width * xFraction
            // Stagger thresholds so drips appear progressively, center ones first.
            let centerBias = 1 - abs(phase - 0.5) * 1.4
            let threshold = 0.12 + (1 - clamp01(centerBias)) * 0.22
            guard level > threshold else { continue }
            let local = clamp01((level - threshold) / (1 - threshold))
            let eased = easeOut(local)
            // The drip hangs down; its length grows with melt, tip stays in-frame.
            let length = metrics.maxDripLength * eased * (0.7 + centerBias * 0.3)
            let radius = metrics.blobRadius * (0.5 + eased * 0.55)
            let tipY = min(baseY + length, metrics.maxTipY)
            result.append((center: CGPoint(x: x, y: tipY), radius: radius))

            // A thin neck blob connecting the tip toward the body keeps the goo fused.
            let neckY = (baseY + tipY) / 2
            let neckR = radius * 0.75
            result.append((center: CGPoint(x: x, y: neckY), radius: neckR))
        }
        return result
    }

    // MARK: - Decorative layers

    private func gradientBody(metrics: Metrics, level: CGFloat) -> some View {
        // Color warms slightly as it heats / melts.
        let top = Color(red: 0.42 + Double(level) * 0.14,
                        green: 0.36,
                        blue: 0.95 - Double(level) * 0.12)
        let bottom = Color(red: 0.78 + Double(level) * 0.12,
                           green: 0.28,
                           blue: 0.62)
        return LinearGradient(
            colors: [top, bottom],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: metrics.size.width, height: metrics.size.height)
    }

    private func glossHighlight(metrics: Metrics, level: CGFloat) -> some View {
        // A soft top highlight that fades as the surface liquefies.
        let r = metrics.bodyRect
        let glossRect = CGRect(
            x: r.minX + r.width * 0.12,
            y: r.minY + r.height * 0.16,
            width: r.width * 0.76,
            height: r.height * 0.30
        )
        return Capsule()
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.55), Color.white.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: glossRect.width, height: glossRect.height)
            .position(x: glossRect.midX, y: glossRect.midY)
            .opacity(0.9 - Double(level) * 0.6)
            .blendMode(.screen)
            .allowsHitTesting(false)
            .mask(
                Canvas { context, _ in
                    drawGooMask(into: &context, metrics: metrics, level: level)
                }
            )
    }

    private func label(metrics: Metrics, level: CGFloat) -> some View {
        let r = metrics.bodyRect
        // Label drips with the body and fades as goo takes over.
        return Text("HOLD")
            .font(.system(size: metrics.fontSize, weight: .heavy, design: .rounded))
            .kerning(metrics.fontSize * 0.08)
            .foregroundStyle(Color.white.opacity(0.92))
            .scaleEffect(y: 1 + level * 0.18, anchor: .top)
            .position(x: r.midX, y: r.midY + metrics.maxSag * level * 0.35)
            .opacity(0.95 - Double(level) * 0.7)
            .allowsHitTesting(false)
    }

    // MARK: - Layout

    private struct Metrics {
        let size: CGSize
        let bodyRect: CGRect
        let corner: CGFloat
        let blobRadius: CGFloat
        let maxSag: CGFloat
        let maxDripLength: CGFloat
        let maxTipY: CGFloat
        let dripCount: Int
        let fontSize: CGFloat
    }

    /// All geometry scales to the GeometryReader size so the goo fuses correctly in
    /// both a 120pt tile and a large detail area.
    private func layout(for size: CGSize) -> Metrics {
        let w = size.width
        let h = size.height
        let minDim = min(w, h)

        let bodyW = w * 0.62
        let bodyH = h * 0.30
        // Button sits upper-middle so drips have room to hang in-frame.
        let bodyX = (w - bodyW) / 2
        let bodyY = h * 0.22
        let bodyRect = CGRect(x: bodyX, y: bodyY, width: bodyW, height: bodyH)

        let corner = bodyH * 0.42
        let blobRadius = minDim * 0.052
        let maxSag = bodyH * 0.55
        let maxDripLength = h * 0.30
        // Clamp tips so the longest drip never leaves the frame.
        let maxTipY = h * 0.94

        return Metrics(
            size: size,
            bodyRect: bodyRect,
            corner: corner,
            blobRadius: blobRadius,
            maxSag: maxSag,
            maxDripLength: maxDripLength,
            maxTipY: maxTipY,
            dripCount: 4,
            fontSize: bodyH * 0.42
        )
    }

    // MARK: - Math helpers

    private func clamp01(_ x: CGFloat) -> CGFloat {
        min(max(x, 0), 1)
    }

    private func easeInOut(_ x: Double) -> CGFloat {
        let c = min(max(x, 0), 1)
        return CGFloat(c * c * (3 - 2 * c))
    }

    private func easeOut(_ x: CGFloat) -> CGFloat {
        let c = clamp01(x)
        return 1 - (1 - c) * (1 - c)
    }

    /// Analytic damped-spring decay from `from` toward 0 over progress 0...1,
    /// producing the bouncy snap-back. Clamped to never go below 0.
    private func springBack(from: CGFloat, progress: Double) -> CGFloat {
        let p = min(max(progress, 0), 1)
        // Damped cosine: starts at `from`, overshoots slightly through 0, settles.
        let decay = exp(-5.5 * p)
        let osc = cos(7.5 * p)
        let value = from * CGFloat(decay * osc)
        return max(value, 0)
    }
}
