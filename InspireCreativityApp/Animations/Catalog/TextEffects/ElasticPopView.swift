// catalog-id: tx-elastic-pop
import SwiftUI

// MARK: - Per-Character Pop
// Characters spring in from zero scale with an overshoot bounce, one after
// another, each landing with a tiny squash-and-stretch and a soft shadow that
// settles — like letters dropping onto a trampoline surface.
//
// demo == true  → self-driving TimelineView loop: a continuous staggered
//                 "breathing" spring pop. Letters spring up to full scale with
//                 a squash-and-stretch landing, hold legibly, then ease back to
//                 a still-legible floor (popFloor) before the next cycle — they
//                 never fully exit and never re-enter from zero, so the word is
//                 never blank or discontinuous on any frame.
// demo == false → real interactive component: starts fully formed; a tap
//                 replays the staggered per-letter spring pop with the
//                 squash-and-stretch landing.

struct ElasticPopView: View {
    var demo: Bool = false

    private let word = "BOUNCE"
    private let stagger: Double = 0.07

    // Tap-incremented trigger for the interactive (demo == false) path.
    @State private var popToken: Int = 0

    var body: some View {
        GeometryReader { geo in
            let metrics = ElasticPopView_Metrics(size: geo.size, count: word.count)
            ZStack {
                backdrop
                content(metrics: metrics)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !demo else { return }
            popToken += 1
        }
    }

    // MARK: Backdrop

    private var backdrop: some View {
        // The catalog tint (#04050a) as a soft vertical wash.
        LinearGradient(
            colors: [
                Color(red: 0.035, green: 0.043, blue: 0.078),
                Color(red: 0.012, green: 0.016, blue: 0.039)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: Content router

    @ViewBuilder
    private func content(metrics: ElasticPopView_Metrics) -> some View {
        if demo {
            demoRow(metrics: metrics)
        } else {
            interactiveRow(metrics: metrics)
        }
    }

    // MARK: Demo — self-driving loop

    private func demoRow(metrics: ElasticPopView_Metrics) -> some View {
        TimelineView(.animation) { timeline in
            let loop = loopPhase(date: timeline.date)
            characterRow(metrics: metrics) { index in
                demoProgress(loopPhase: loop, index: index)
            }
        }
    }

    // MARK: Interactive — tap to replay

    private func interactiveRow(metrics: ElasticPopView_Metrics) -> some View {
        characterRow(metrics: metrics) { _ in 1.0 }
            .overlay(alignment: .center) {
                // Per-character keyframe pop, retriggered by popToken.
                interactiveOverlay(metrics: metrics)
            }
            // The resting row beneath stays fully formed so the detail view is
            // never blank; the overlay supplies the animated replay.
            .opacity(popToken == 0 ? 1 : 0)
    }

    @ViewBuilder
    private func interactiveOverlay(metrics: ElasticPopView_Metrics) -> some View {
        if popToken > 0 {
            HStack(spacing: metrics.spacing) {
                ForEach(Array(word.enumerated()), id: \.offset) { index, ch in
                    ElasticPopView_KeyframePopCharacter(
                        character: String(ch),
                        fontSize: metrics.fontSize,
                        delay: Double(index) * stagger,
                        trigger: popToken
                    )
                }
            }
        }
    }

    // MARK: Shared row of pop characters

    private func characterRow(
        metrics: ElasticPopView_Metrics,
        progress: @escaping (Int) -> Double
    ) -> some View {
        HStack(spacing: metrics.spacing) {
            ForEach(Array(word.enumerated()), id: \.offset) { index, ch in
                ElasticPopView_PopCharacter(
                    character: String(ch),
                    fontSize: metrics.fontSize,
                    progress: progress(index)
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Demo timing

    // Normalized 0→1 phase over a ~3.2s loop.
    private func loopPhase(date: Date) -> Double {
        let period: Double = 3.2
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period)
        return t / period
    }

    // Per-character progress for the demo loop.
    //
    // A single continuous, seam-safe "breathing" pop per letter:
    //   - A per-letter local phase is offset by the stagger wave, so letters
    //     bounce left-to-right.
    //   - The shaping curve `bump` is exactly 0 at both ends of the local
    //     phase and rises (with a little spring overshoot) to 1 in between.
    //   - We map [0, 1] of that bump onto [popFloor, ~1.0] so the *minimum*
    //     progress any letter ever reaches is popFloor (never 0).
    //
    // Result: progress == popFloor at both phase→0 and phase→1 (no wrap
    // discontinuity), and never below popFloor (never blank: opacity is
    // min(1, prog*1.6) and popFloor*1.6 > 1, so it stays fully opaque).
    private func demoProgress(loopPhase: Double, index: Int) -> Double {
        let count = Double(word.count)
        let norm = count > 1 ? Double(index) / (count - 1) : 0

        // Floor the breathing pop never drops below (keeps every letter legible).
        let popFloor: Double = 0.66

        // Per-letter local phase in [0, 1), staggered left-to-right.
        let spreadFrac: Double = 0.18
        var local = loopPhase - norm * spreadFrac
        local = local - floor(local)          // wrap into [0, 1)

        // Shaping bump: 0 at both ends, springs up to ~1 in between.
        let shaped = bump(local)

        return popFloor + (1.0 - popFloor) * shaped
    }

    // A 0→(overshoot)→hold→0 bump over [0,1] that is exactly 0 at both ends,
    // giving a spring-like rise, a legible hold near the top, then an ease back.
    private func bump(_ x: Double) -> Double {
        let t = clamp(x)
        let riseEnd: Double = 0.34   // spring up
        let fallStart: Double = 0.78 // start easing back

        if t < riseEnd {
            let p = t / riseEnd
            return clamp(easeOutBack(p))      // 0 → ~1 with overshoot
        } else if t < fallStart {
            return 1.0                        // legible hold at full scale
        } else {
            let span = max(1.0 - fallStart, 0.0001)
            let p = (t - fallStart) / span    // 0 → 1
            return clamp(1.0 - easeInCubic(p)) // 1 → 0, smooth landing at the seam
        }
    }

    private func clamp(_ v: Double) -> Double { min(1, max(0, v)) }

    private func easeInCubic(_ x: Double) -> Double { x * x * x }

    // Overshoot ease for the spring rise (back-out). Note easeOutBack(0)==0
    // and easeOutBack(1)==1, so the bump pins to 0 at the seam.
    private func easeOutBack(_ x: Double) -> Double {
        let c1: Double = 1.70158
        let c3: Double = c1 + 1
        let p = x - 1
        return 1 + c3 * p * p * p + c1 * p * p
    }
}

// MARK: - Layout metrics

private struct ElasticPopView_Metrics {
    let fontSize: CGFloat
    let spacing: CGFloat

    init(size: CGSize, count: Int) {
        let w = max(size.width, 1)
        let h = max(size.height, 1)
        // Fit the word horizontally and keep headroom for the bounce vertically.
        let byWidth = w / (CGFloat(max(count, 1)) * 0.92)
        let byHeight = h * 0.42
        let f = min(byWidth, byHeight)
        self.fontSize = max(12, min(f, 120))
        self.spacing = self.fontSize * 0.04
    }
}

// MARK: - Squash/stretch model

// Maps a 0→1 entrance progress to non-uniform scaleX/scaleY, a vertical drop,
// and a soft landing shadow. The non-uniform scales near landing are what
// produce the squash-and-stretch, which fully settles to (1, 1) at rest.
private struct ElasticPopView_PopShape {
    var scaleX: CGFloat
    var scaleY: CGFloat
    var yOffset: CGFloat
    var shadowRadius: CGFloat
    var shadowOpacity: Double
    var opacity: Double

    static func from(progress p: Double, fontSize: CGFloat) -> ElasticPopView_PopShape {
        let prog = min(1, max(0, p))

        // Base uniform scale follows the back-out ease already applied upstream.
        let base = CGFloat(prog)

        // Squash window: a brief non-uniform pulse around the landing (~0.6–0.95).
        // bell peaks near landing; a (1 - prog) falloff forces it to exactly 0
        // at prog == 1 so the letter settles perfectly square at rest.
        let raw = bell(prog, center: 0.80, width: 0.16)
        let settle = max(0, 1 - prog)            // → 0 at rest
        let squash = CGFloat(raw * settle)

        // At landing the letter flattens: wider X, shorter Y, then settles to 1.
        let sx = base + squash * 0.26
        let sy = base - squash * 0.24

        // Drop in from slightly above; settle to baseline with the bounce.
        let drop = (1 - CGFloat(easeOutSoft(prog))) * fontSize * 0.18

        // Shadow grows as the letter approaches the surface.
        let shadowR = fontSize * 0.10 * CGFloat(prog)
        let shadowO = 0.45 * prog

        // Opacity ramps quickly so letters read almost immediately, never harsh.
        let op = min(1, prog * 1.6)

        return ElasticPopView_PopShape(
            scaleX: max(0.001, sx),
            scaleY: max(0.001, sy),
            yOffset: drop,
            shadowRadius: shadowR,
            shadowOpacity: shadowO,
            opacity: op
        )
    }

    // Gaussian-ish bell, 0..1.
    private static func bell(_ x: Double, center: Double, width: Double) -> Double {
        let d = (x - center) / width
        return exp(-d * d)
    }

    private static func easeOutSoft(_ x: Double) -> Double {
        1 - pow(1 - x, 3)
    }
}

// MARK: - Demo character (driven by external progress)

private struct ElasticPopView_PopCharacter: View {
    let character: String
    let fontSize: CGFloat
    let progress: Double

    var body: some View {
        let shape = ElasticPopView_PopShape.from(progress: progress, fontSize: fontSize)
        glyph
            .scaleEffect(x: shape.scaleX, y: shape.scaleY, anchor: .bottom)
            .offset(y: shape.yOffset)
            .shadow(
                color: Color.black.opacity(shape.shadowOpacity),
                radius: shape.shadowRadius,
                x: 0,
                y: shape.shadowRadius * 0.6
            )
            .opacity(shape.opacity)
    }

    private var glyph: some View {
        Text(character)
            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
            .foregroundStyle(glyphFill)
            .lineLimit(1)
            .fixedSize()
    }

    private var glyphFill: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.62, green: 0.83, blue: 1.0),
                Color(red: 0.38, green: 0.55, blue: 0.98)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Interactive character (KeyframeAnimator, replays on tap)

private struct ElasticPopView_KeyframePopCharacter: View {
    let character: String
    let fontSize: CGFloat
    let delay: Double
    let trigger: Int

    struct PopValues {
        var scaleX: CGFloat = 0.001
        var scaleY: CGFloat = 0.001
        var yOffset: CGFloat = 0
        var shadow: Double = 0
        var opacity: Double = 0
    }

    var body: some View {
        KeyframeAnimator(
            initialValue: PopValues(),
            trigger: trigger
        ) { v in
            Text(character)
                .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                .foregroundStyle(fill)
                .lineLimit(1)
                .fixedSize()
                .scaleEffect(x: v.scaleX, y: v.scaleY, anchor: .bottom)
                .offset(y: v.yOffset)
                .shadow(
                    color: Color.black.opacity(v.shadow),
                    radius: fontSize * 0.10 * CGFloat(v.opacity),
                    x: 0,
                    y: fontSize * 0.06 * CGFloat(v.opacity)
                )
                .opacity(v.opacity)
        } keyframes: { _ in
            // scaleX: grows, overshoots wide at landing (stretch), settles to 1.
            KeyframeTrack(\.scaleX) {
                LinearKeyframe(0.001, duration: delay)
                SpringKeyframe(0.82, duration: 0.18, spring: .bouncy)
                SpringKeyframe(1.18, duration: 0.12)   // stretch wide on landing
                SpringKeyframe(1.0, duration: 0.30, spring: .snappy)
            }
            // scaleY: grows tall, then squashes short at landing, settles to 1.
            KeyframeTrack(\.scaleY) {
                LinearKeyframe(0.001, duration: delay)
                SpringKeyframe(1.20, duration: 0.18, spring: .bouncy) // tall arriving
                SpringKeyframe(0.80, duration: 0.12)   // squash short on landing
                SpringKeyframe(1.0, duration: 0.30, spring: .snappy)
            }
            // yOffset: drops in from above, lands at baseline.
            KeyframeTrack(\.yOffset) {
                LinearKeyframe(-fontSize * 0.22, duration: delay)
                SpringKeyframe(0, duration: 0.30, spring: .bouncy)
            }
            // shadow: blooms as it lands, eases off slightly.
            KeyframeTrack(\.shadow) {
                LinearKeyframe(0, duration: delay)
                LinearKeyframe(0, duration: 0.16)
                CubicKeyframe(0.5, duration: 0.12)
                CubicKeyframe(0.38, duration: 0.30)
            }
            // opacity: snaps in fast so the letter is legible immediately.
            KeyframeTrack(\.opacity) {
                LinearKeyframe(0, duration: delay)
                CubicKeyframe(1, duration: 0.12)
            }
        }
    }

    private var fill: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.62, green: 0.83, blue: 1.0),
                Color(red: 0.38, green: 0.55, blue: 0.98)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
