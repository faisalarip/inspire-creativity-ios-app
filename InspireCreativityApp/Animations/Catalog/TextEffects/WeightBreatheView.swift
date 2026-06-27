// catalog-id: tx-weight-breathe
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Variable Weight Breathe
///
/// A headline that continuously inhales and exhales by interpolating a font's
/// weight axis every frame under `TimelineView(.animation)`. Because SwiftUI's
/// `Font.Weight` is not `Animatable`, the effect bridges through `UIFont`: each
/// word rebuilds its `Font` per frame from `UIFont.systemFont(ofSize:weight:)`
/// using a *continuous* `UIFont.Weight(rawValue:)` driven by a sine wave. A
/// per-word phase offset makes the line breathe like a living organism rather
/// than pulsing in unison.
///
/// `demo == true` and `demo == false` run the identical self-driving loop — the
/// spec's interaction is "auto", so the "real" component *is* the breathing
/// animation (no gesture).
struct WeightBreatheView: View {

    var demo: Bool = false

    // The headline, split into words so each can carry its own phase offset.
    private let words: [String] = ["Breathe", "in", "out"]

    // Animation tuning.
    private let breathPeriod: Double = 3.0          // seconds per full inhale/exhale
    private let perWordPhase: Double = 0.55          // radians of lag per word
    private let minRaw: CGFloat = -0.05              // lightest weight (still legible)
    private let weightSwing: CGFloat = 0.46          // amplitude toward heavy

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                content(in: size, time: t)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(background)
        }
    }

    // MARK: - Composition

    private func content(in size: CGSize, time: Double) -> some View {
        let base = min(size.width, size.height)
        let fontSize = max(13.0, base * 0.26)
        let avgPhase = averagePhase(time: time)

        return ZStack {
            // Soft breathing halo behind the type that swells with the average weight.
            breathHalo(base: base, intensity: avgPhase)

            wordLine(fontSize: fontSize, time: time)
                .padding(.horizontal, base * 0.08)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func wordLine(fontSize: CGFloat, time: Double) -> some View {
        HStack(spacing: fontSize * 0.32) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                wordView(word, index: index, fontSize: fontSize, time: time)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.4)
    }

    private func wordView(_ word: String, index: Int, fontSize: CGFloat, time: Double) -> some View {
        let raw = weightRaw(index: index, time: time)
        let normalized = normalize(raw: raw)               // 0 (light) ... 1 (heavy)
        let glow = 0.18 + normalized * 0.45

        return Text(word)
            .font(weightFont(size: fontSize, raw: raw))
            .foregroundStyle(textGradient(intensity: normalized))
            .shadow(color: glowColor.opacity(glow), radius: fontSize * 0.18 * normalized)
            .kerning(fontSize * 0.01)
            .animation(nil, value: raw)                     // per-frame value, no implicit anim
    }

    // MARK: - Weight bridge (the heart of the effect)

    /// Continuous weight via `UIFont.Weight(rawValue:)` on iOS or `NSFont.Weight(rawValue:)`
    /// on macOS. The raw axis is a true `CGFloat` (light ≈ -0.4, regular 0, semibold 0.3,
    /// bold 0.4, black 0.62), and intermediate values interpolate — this is the continuous
    /// swell/slim that discrete `.bold` steps cannot produce.
    private func weightFont(size: CGFloat, raw: CGFloat) -> Font {
        let clamped = min(max(raw, -0.5), 0.85)
        #if canImport(UIKit)
        let resolved = UIFont.systemFont(ofSize: size, weight: UIFont.Weight(rawValue: clamped))
        return Font(resolved)
        #elseif canImport(AppKit)
        let resolved = NSFont.systemFont(ofSize: size, weight: NSFont.Weight(rawValue: clamped))
        return Font(resolved as CTFont)
        #endif
    }

    private func weightRaw(index: Int, time: Double) -> CGFloat {
        let phase = time * (2.0 * .pi / breathPeriod) + Double(index) * perWordPhase
        let wave = CGFloat(sin(phase))                      // -1 ... 1
        let unit = (wave + 1.0) / 2.0                        // 0 ... 1
        return minRaw + unit * weightSwing
    }

    // MARK: - Helpers

    private func normalize(raw: CGFloat) -> CGFloat {
        guard weightSwing > 0 else { return 0.5 }
        let unit = (raw - minRaw) / weightSwing
        return min(max(unit, 0.0), 1.0)
    }

    /// Average breathing intensity across all words, for the shared halo.
    private func averagePhase(time: Double) -> CGFloat {
        guard !words.isEmpty else { return 0.5 }
        var sum: CGFloat = 0
        for index in words.indices {
            sum += normalize(raw: weightRaw(index: index, time: time))
        }
        return sum / CGFloat(words.count)
    }

    private func textGradient(intensity: CGFloat) -> LinearGradient {
        // Compile-time-known endpoints, kept as plain RGB tuples so the blend is
        // fully self-contained (no UIColor round-trip needed).
        let warm: (Double, Double, Double) = (1.0, 0.96, 0.92)
        let cool: (Double, Double, Double) = (0.78, 0.84, 0.95)
        let top = blend(cool, warm, amount: intensity)
        let bottom = blend(cool, warm, amount: intensity * 0.6)
        return LinearGradient(
            colors: [top, bottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func blend(_ a: (Double, Double, Double),
                       _ b: (Double, Double, Double),
                       amount: CGFloat) -> Color {
        let m: Double = Double(min(max(amount, 0.0), 1.0))
        return Color(
            red: a.0 + (b.0 - a.0) * m,
            green: a.1 + (b.1 - a.1) * m,
            blue: a.2 + (b.2 - a.2) * m
        )
    }

    // MARK: - Decorative layers

    private func breathHalo(base: CGFloat, intensity: CGFloat) -> some View {
        let scale = 0.85 + intensity * 0.35
        let opacity = 0.10 + Double(intensity) * 0.22
        return RadialGradient(
            colors: [glowColor.opacity(opacity), glowColor.opacity(0.0)],
            center: .center,
            startRadius: 0,
            endRadius: base * 0.6
        )
        .scaleEffect(scale)
        .blur(radius: base * 0.04)
        .allowsHitTesting(false)
    }

    private var glowColor: Color {
        Color(red: 0.55, green: 0.70, blue: 1.0)
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.016, green: 0.020, blue: 0.039),
                Color(red: 0.043, green: 0.055, blue: 0.094)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
