// catalog-id: mi-copy-shred
import SwiftUI

// MARK: - Copy Shred-Reform
//
// On copy, the label "Copy" splits into vertical strips that shuffle/scatter
// (paper-shredder in reverse), then reassemble into "Copied" with a checkmark
// sliding in. demo == true self-cycles via a TimelineView clock that sweeps a
// continuous progress 0 → 1 → hold → 0 so the per-strip scatter/stagger math
// is actually exercised; demo == false fires on tap and auto-resets so it
// stays re-tappable.

public struct CopyShredView: View {
    public var demo: Bool = false

    public init(demo: Bool = false) {
        self.demo = demo
    }

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            Group {
                if demo {
                    DemoDriver(size: size)
                } else {
                    InteractiveDriver(size: size)
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Shared progress model

/// A single 0...1 progress drives both modes.
///  0.00 → idle "Copy", fully assembled
///  0.50 → mid-shred (Copy fading/scattered out, Copied scattering in)
///  1.00 → reformed "Copied" + checkmark in
private struct ShredState {
    var progress: CGFloat        // 0...1 overall
    var stripCount: Int

    // How far through the "Copy shreds out" portion (0...1).
    // Wide windows overlap the out/in so no frame is ever blank at the crossover.
    var outPhase: CGFloat {
        clamp((progress - 0.10) / 0.52)
    }

    // How far through the "Copied reforms in" portion (0...1).
    var inPhase: CGFloat {
        clamp((progress - 0.32) / 0.46)
    }

    var copyOpacity: Double {
        // Stays fully visible early, fades as it shreds out.
        Double(1 - smooth(outPhase))
    }

    var copiedOpacity: Double {
        // Fades in as it reforms.
        Double(smooth(inPhase))
    }

    var checkProgress: CGFloat {
        // Slides in only at the tail end.
        smooth(clamp((progress - 0.72) / 0.28))
    }

    /// Per-strip scatter offset (points) for the outgoing "Copy" strips.
    func outOffset(index: Int, height: CGFloat) -> CGSize {
        let amp = height * 0.34
        let t = staggered(outPhase, index: index)
        let dir: CGFloat = (index % 2 == 0) ? -1 : 1
        // Strips fly up/down and drift sideways like shredded ribbons.
        let dy = dir * amp * t
        let dx = (index % 3 == 0 ? -1 : 1) * height * 0.08 * t
        return CGSize(width: dx, height: dy)
    }

    /// Per-strip incoming offset for the assembling "Copied" strips (settles to 0).
    func inOffset(index: Int, height: CGFloat) -> CGSize {
        let amp = height * 0.30
        // inPhase 0 → scattered, 1 → assembled.
        let t = 1 - staggered(inPhase, index: index)
        let dir: CGFloat = (index % 2 == 0) ? 1 : -1
        let dy = dir * amp * t
        return CGSize(width: 0, height: dy)
    }

    func outStripOpacity(index: Int) -> Double {
        Double(1 - staggered(outPhase, index: index))
    }

    func inStripOpacity(index: Int) -> Double {
        Double(staggered(inPhase, index: index))
    }

    // Staggered easing so strips move slightly out of sync (the "shuffle").
    private func staggered(_ p: CGFloat, index: Int) -> CGFloat {
        let span: CGFloat = 0.45
        let start = (CGFloat(index) / CGFloat(max(stripCount - 1, 1))) * span
        let local = clamp((p - start) / (1 - span))
        return smooth(local)
    }

    private func smooth(_ x: CGFloat) -> CGFloat {
        let c = clamp(x)
        return c * c * (3 - 2 * c) // smoothstep
    }

    private func clamp(_ x: CGFloat) -> CGFloat {
        min(max(x, 0), 1)
    }
}

private func clamp(_ x: CGFloat) -> CGFloat {
    min(max(x, 0), 1)
}

private func smooth(_ x: CGFloat) -> CGFloat {
    let c = clamp(x)
    return c * c * (3 - 2 * c)
}

// MARK: - Demo driver (self-cycling)

private struct DemoDriver: View {
    let size: CGSize

    // One full loop: shred-out/reform-in, hold on "Copied", reset, hold on "Copy".
    private let cycle: Double = 3.4

    var body: some View {
        // A TimelineView(.animation) clock sweeps a CONTINUOUS progress so the
        // per-strip scatter / staggered-smoothstep math in ShredState is actually
        // exercised every frame (a PhaseAnimator[0,1,0] would only ever sample the
        // endpoints, collapsing the effect to a plain crossfade). Never blank:
        // copyOpacity fades out as copiedOpacity fades in across the overlap window.
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let progress = Self.loopProgress(t, cycle: cycle)
            ShredContent(progress: progress, size: size, animated: false)
        }
    }

    /// Maps wall-clock time → 0...1 progress with holds at each end so the word
    /// is legible before and after the shred:
    ///   [0.00–0.38] shred "Copy" → reform "Copied"
    ///   [0.38–0.55] hold on "Copied"
    ///   [0.55–0.88] reform back to "Copy"
    ///   [0.88–1.00] hold on "Copy"
    static func loopProgress(_ time: Double, cycle: Double) -> CGFloat {
        let phase = (time.truncatingRemainder(dividingBy: cycle)) / cycle // 0...1
        let p: Double
        switch phase {
        case ..<0.38:
            p = ease(phase / 0.38)              // 0 → 1
        case ..<0.55:
            p = 1                               // hold "Copied"
        case ..<0.88:
            p = 1 - ease((phase - 0.55) / 0.33) // 1 → 0
        default:
            p = 0                               // hold "Copy"
        }
        return CGFloat(p)
    }

    /// Smoothstep so the sweep accelerates in and eases out.
    private static func ease(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }
}

// MARK: - Interactive driver (tap + auto-reset)

private struct InteractiveDriver: View {
    let size: CGSize
    @State private var copied: Bool = false

    var body: some View {
        ShredContent(progress: copied ? 1 : 0, size: size, animated: true)
            .contentShape(Rectangle())
            .onTapGesture { fire() }
            .sensoryFeedbackCompat(trigger: copied)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(copied ? "Copied" : "Copy")
    }

    private func fire() {
        guard !copied else { return }
        withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
            copied = true
        }
        // Auto-reset so the tile stays re-tappable.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.8)) {
                copied = false
            }
        }
    }
}

// MARK: - Content

private struct ShredContent: View {
    var progress: CGFloat
    let size: CGSize
    /// When true, per-strip staggered springs are applied for the tactile feel.
    let animated: Bool

    private let stripCount = 10

    private var state: ShredState {
        ShredState(progress: clamp(progress), stripCount: stripCount)
    }

    private var regionWidth: CGFloat { size.width * 0.84 }
    private var regionHeight: CGFloat { size.height * 0.42 }
    private var fontSize: CGFloat {
        // Sized to "Copied" (the longer word) so it never truncates.
        min(regionHeight * 0.74, regionWidth * 0.26)
    }

    var body: some View {
        ZStack {
            backdrop
            wordStack
        }
        .frame(width: size.width, height: size.height)
    }

    private var backdrop: some View {
        RoundedRectangle(cornerRadius: size.width * 0.10, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(hexCode: 0x1B1726),
                        Color(hexCode: 0x120F1B)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: size.width * 0.10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            )
            .frame(width: size.width * 0.92, height: size.height * 0.66)
    }

    private var wordStack: some View {
        ZStack {
            shredLayer(
                word: "Copy",
                color: Color(hexCode: 0xC7BEE6),
                opacity: state.copyOpacity,
                offset: { state.outOffset(index: $0, height: regionHeight) },
                stripOpacity: { state.outStripOpacity(index: $0) }
            )

            reformLayer(
                word: "Copied",
                color: Color(hexCode: 0x8BE6B0),
                opacity: state.copiedOpacity,
                offset: { state.inOffset(index: $0, height: regionHeight) },
                stripOpacity: { state.inStripOpacity(index: $0) }
            )
            .overlay(alignment: .trailing) {
                checkmark
            }
        }
        .frame(width: regionWidth, height: regionHeight)
    }

    // MARK: Layers

    private func shredLayer(
        word: String,
        color: Color,
        opacity: Double,
        offset: @escaping (Int) -> CGSize,
        stripOpacity: @escaping (Int) -> Double
    ) -> some View {
        ZStack {
            ForEach(0..<stripCount, id: \.self) { i in
                strip(index: i, word: word, color: color)
                    .offset(offset(i))
                    .opacity(stripOpacity(i))
                    .modifier(StripSpring(index: i, animated: animated, value: progress))
            }
        }
        .opacity(opacity)
    }

    private func reformLayer(
        word: String,
        color: Color,
        opacity: Double,
        offset: @escaping (Int) -> CGSize,
        stripOpacity: @escaping (Int) -> Double
    ) -> some View {
        ZStack {
            ForEach(0..<stripCount, id: \.self) { i in
                strip(index: i, word: word, color: color)
                    .offset(offset(i))
                    .opacity(stripOpacity(i))
                    .modifier(StripSpring(index: i, animated: animated, value: progress))
            }
        }
        .opacity(opacity)
    }

    /// One vertical band of the full word, masked from an identical full Text.
    /// Every strip shares the same layout, so offset==0 reconstructs the word
    /// with zero sub-pixel seams.
    private func strip(index: Int, word: String, color: Color) -> some View {
        let bandWidth = regionWidth / CGFloat(stripCount)
        let x = bandWidth * CGFloat(index)
        return label(word: word, color: color)
            .frame(width: regionWidth, height: regionHeight)
            .mask(
                Rectangle()
                    .frame(width: bandWidth, height: regionHeight)
                    .offset(x: x - regionWidth / 2 + bandWidth / 2)
            )
    }

    private func label(word: String, color: Color) -> some View {
        Text(word)
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(width: regionWidth, height: regionHeight)
    }

    // MARK: Checkmark

    private var checkmark: some View {
        let p = state.checkProgress
        let glyph = fontSize * 0.9
        return Image(systemName: "checkmark.circle.fill")
            .font(.system(size: glyph, weight: .bold))
            .foregroundStyle(Color(hexCode: 0x8BE6B0))
            .opacity(Double(p))
            .scaleEffect(0.6 + 0.4 * p)
            .offset(x: glyph * (1.1 - p * 1.1))
            // Sit just past the trailing edge of the word region.
            .offset(x: glyph * 0.9)
    }
}

// MARK: - Per-strip staggered spring

private struct StripSpring: ViewModifier {
    let index: Int
    let animated: Bool
    let value: CGFloat

    func body(content: Content) -> some View {
        if animated {
            content.animation(
                .spring(response: 0.55, dampingFraction: 0.72)
                    .delay(Double(index) * 0.03),
                value: value
            )
        } else {
            content
        }
    }
}

// MARK: - Compatibility helpers

private extension View {
    /// sensoryFeedback is iOS 17+; available at our deployment target, but
    /// kept behind a tiny wrapper for clarity / forward-safety.
    @ViewBuilder
    func sensoryFeedbackCompat(trigger: Bool) -> some View {
        if #available(iOS 17.0, *) {
            self.sensoryFeedback(.success, trigger: trigger) { _, new in new }
        } else {
            self
        }
    }
}

private extension Color {
    init(hexCode hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

// MARK: - Preview
