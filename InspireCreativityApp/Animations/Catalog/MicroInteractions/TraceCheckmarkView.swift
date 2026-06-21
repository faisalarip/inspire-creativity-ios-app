// catalog-id: mi-trace-checkmark
import SwiftUI

// MARK: - Trace Checkmark
// A success tick that draws its ring clockwise via trim, then strokes the
// checkmark on with an overshoot snap and a single radial spark at the tip.
// demo == true  -> self-driving TimelineView loop (no touch, never blank).
// demo == false -> plays once on appear; tap to replay, with success haptic.

struct TraceCheckmarkView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                if demo {
                    TraceCheckmarkView_DemoDriver(side: side)
                } else {
                    TraceCheckmarkView_InteractiveDriver(side: side)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Phase math (shared, deterministic)

private enum TraceCheckmarkView_TracePhase {
    // Sub-progress windows inside one normalized 0...1 loop phase.
    static let circleEnd: Double = 0.30
    static let checkStart: Double = 0.30
    static let checkEnd: Double = 0.55
    static let sparkStart: Double = 0.55
    static let sparkEnd: Double = 0.72
    static let holdEnd: Double = 0.88
    // remainder 0.88...1.0 fades out and resets.

    static func clamp(_ v: Double) -> Double { min(1, max(0, v)) }

    static func easeOut(_ t: Double) -> Double {
        let c = clamp(t)
        return 1 - pow(1 - c, 3)
    }

    static func easeInOut(_ t: Double) -> Double {
        let c = clamp(t)
        return c < 0.5 ? 4 * c * c * c : 1 - pow(-2 * c + 2, 3) / 2
    }

    static func mapped(_ value: Double, from a: Double, to b: Double) -> Double {
        guard b > a else { return value >= b ? 1 : 0 }
        return clamp((value - a) / (b - a))
    }

    /// Returns the three render sub-progresses for a normalized phase 0...1.
    static func resolve(_ phase: Double) -> (circle: Double, check: Double, spark: Double, overshoot: Double) {
        let p = clamp(phase)

        // Circle draws first.
        let circle = easeOut(mapped(p, from: 0, to: circleEnd))

        // Check strokes after the circle.
        let check = easeInOut(mapped(p, from: checkStart, to: checkEnd))

        // Spark blooms once the check lands, then decays.
        let sparkRaw = mapped(p, from: sparkStart, to: sparkEnd)
        let spark = sparkRaw

        // Overshoot: a brief 0 -> 1 -> 0 pulse right as the check completes,
        // expressed as scaleEffect (NOT trim, which would clamp at 1).
        let overshootWindowStart = checkEnd - 0.04
        let overshootWindowEnd = sparkEnd
        let ow = mapped(p, from: overshootWindowStart, to: overshootWindowEnd)
        let overshoot = sin(ow * .pi) // 0 -> 1 -> 0

        // Fade-out at the tail so the wrap never flickers to empty hard.
        let fade: Double
        if p > holdEnd {
            fade = 1 - easeInOut(mapped(p, from: holdEnd, to: 1.0))
        } else {
            fade = 1
        }

        return (circle * fade, check * fade, spark * fade, overshoot)
    }
}

// MARK: - Demo driver (self-driving loop)

private struct TraceCheckmarkView_DemoDriver: View {
    let side: CGFloat
    private let period: Double = 3.2

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = (t.truncatingRemainder(dividingBy: period)) / period
            let r = TraceCheckmarkView_TracePhase.resolve(phase)
            TraceCheckmarkView_TraceRenderer(
                side: side,
                circleTrim: r.circle,
                checkTrim: r.check,
                sparkProgress: r.spark,
                overshoot: r.overshoot
            )
        }
    }
}

// MARK: - Interactive driver (play-on-appear, tap to replay)

private struct TraceCheckmarkView_InteractiveDriver: View {
    let side: CGFloat

    @State private var circleTrim: CGFloat = 0
    @State private var checkTrim: CGFloat = 0
    @State private var sparkProgress: CGFloat = 0
    @State private var overshoot: CGFloat = 0
    @State private var completionTick: Int = 0
    @State private var hasPlayed: Bool = false

    var body: some View {
        TraceCheckmarkView_TraceRenderer(
            side: side,
            circleTrim: Double(circleTrim),
            checkTrim: Double(checkTrim),
            sparkProgress: Double(sparkProgress),
            overshoot: Double(overshoot)
        )
        .contentShape(Rectangle())
        .onTapGesture { play() }
        .onAppear {
            if !hasPlayed {
                hasPlayed = true
                // Small delay so the appear transition reads.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    play()
                }
            }
        }
        .sensoryFeedback(.success, trigger: completionTick)
    }

    private func play() {
        // Reset.
        circleTrim = 0
        checkTrim = 0
        sparkProgress = 0
        overshoot = 0

        // 1. Ring draws clockwise.
        withAnimation(.easeOut(duration: 0.55)) {
            circleTrim = 1
        }

        // 2. Check strokes after the ring, with an overshoot scale snap.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.30)) {
                checkTrim = 1
            }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.45).delay(0.18)) {
                overshoot = 1
            }
            withAnimation(.easeOut(duration: 0.35).delay(0.40)) {
                overshoot = 0
            }
        }

        // 3. Spark blooms at the tip on completion + haptic.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            completionTick += 1
            sparkProgress = 0
            withAnimation(.easeOut(duration: 0.45)) {
                sparkProgress = 1
            }
        }
    }
}

// MARK: - Renderer (pure presentation, no animation logic)

private struct TraceCheckmarkView_TraceRenderer: View {
    let side: CGFloat
    let circleTrim: Double
    let checkTrim: Double
    let sparkProgress: Double
    let overshoot: Double

    // Palette (literal RGB only).
    private var accent: Color { Color(red: 0.22, green: 0.83, blue: 0.51) }
    private var accentDeep: Color { Color(red: 0.10, green: 0.62, blue: 0.40) }
    private var guideColor: Color { Color(red: 0.55, green: 0.60, blue: 0.58).opacity(0.22) }
    private var sparkColor: Color { Color(red: 0.78, green: 1.0, blue: 0.86) }

    private var lineWidth: CGFloat { max(2.5, side * 0.055) }
    private var ringInset: CGFloat { lineWidth * 0.9 }

    // Check geometry, normalized to the ring's bounding box (0...1 each axis),
    // measured inside the inset ring rect.
    private func checkPoints(in rect: CGRect) -> (start: CGPoint, mid: CGPoint, end: CGPoint) {
        let w = rect.width
        let h = rect.height
        let x0 = rect.minX
        let y0 = rect.minY
        let start = CGPoint(x: x0 + w * 0.30, y: y0 + h * 0.52)
        let mid = CGPoint(x: x0 + w * 0.44, y: y0 + h * 0.66)
        let end = CGPoint(x: x0 + w * 0.72, y: y0 + h * 0.36)
        return (start, mid, end)
    }

    var body: some View {
        ZStack {
            GeometryReader { geo in
                let rect = squareRect(in: geo.size)
                let inner = rect.insetBy(dx: ringInset, dy: ringInset)
                let pts = checkPoints(in: inner)
                let scale = 1.0 + overshoot * 0.13

                ZStack {
                    // Faint persistent guide ring (never blank).
                    Circle()
                        .stroke(guideColor, style: .init(lineWidth: lineWidth, lineCap: .round))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)

                    // Drawn ring (clockwise from top).
                    Circle()
                        .trim(from: 0, to: circleTrim)
                        .stroke(
                            LinearGradient(
                                colors: [accent, accentDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: .init(lineWidth: lineWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90)) // start at top
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .shadow(color: accent.opacity(0.45 * circleTrim), radius: lineWidth * 0.8)

                    // Checkmark stroke.
                    TraceCheckmarkView_CheckShape(start: pts.start, mid: pts.mid, end: pts.end)
                        .trim(from: 0, to: checkTrim)
                        .stroke(accent, style: .init(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                        .scaleEffect(scale, anchor: .center)
                        .shadow(color: accent.opacity(0.5 * checkTrim), radius: lineWidth * 0.7)

                    // Radial spark at the check tip on completion.
                    TraceCheckmarkView_SparkView(progress: sparkProgress, color: sparkColor, baseSize: side)
                        .position(pts.end)
                        .allowsHitTesting(false)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }

    private func squareRect(in size: CGSize) -> CGRect {
        let s = min(size.width, size.height) * 0.78
        let x = (size.width - s) / 2
        let y = (size.height - s) / 2
        return CGRect(x: x, y: y, width: s, height: s)
    }
}

// MARK: - Check shape

private struct TraceCheckmarkView_CheckShape: Shape {
    let start: CGPoint
    let mid: CGPoint
    let end: CGPoint

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: start)
        p.addLine(to: mid)
        p.addLine(to: end)
        return p
    }
}

// MARK: - Spark (Canvas radial burst)

private struct TraceCheckmarkView_SparkView: View {
    let progress: Double // 0...1
    let color: Color
    let baseSize: CGFloat

    private let rayCount = 8

    var body: some View {
        let p = min(1, max(0, progress))
        // 0 -> 1 -> 0 envelope for opacity; rays push outward as p rises.
        let opacity = sin(p * .pi)
        let reach = baseSize * 0.22
        let canvasSide = baseSize * 0.6

        Canvas { ctx, size in
            guard opacity > 0.001 else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let inner = reach * (0.15 + p * 0.35)
            let outer = reach * (0.45 + p * 0.55)
            let w = max(1.0, baseSize * 0.018)

            for i in 0..<rayCount {
                let angle = (Double(i) / Double(rayCount)) * 2 * .pi
                let a = CGPoint(
                    x: center.x + CGFloat(cos(angle)) * inner,
                    y: center.y + CGFloat(sin(angle)) * inner
                )
                let b = CGPoint(
                    x: center.x + CGFloat(cos(angle)) * outer,
                    y: center.y + CGFloat(sin(angle)) * outer
                )
                var ray = Path()
                ray.move(to: a)
                ray.addLine(to: b)
                ctx.stroke(
                    ray,
                    with: .color(color.opacity(opacity)),
                    style: .init(lineWidth: w, lineCap: .round)
                )
            }

            // Bright core flash.
            let coreR = max(1.0, baseSize * 0.02) * (1 + p)
            let coreRect = CGRect(
                x: center.x - coreR, y: center.y - coreR,
                width: coreR * 2, height: coreR * 2
            )
            ctx.fill(Circle().path(in: coreRect), with: .color(color.opacity(opacity)))
        }
        .frame(width: canvasSide, height: canvasSide)
    }
}
