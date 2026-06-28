// catalog-id: tx-confetti-letters
import SwiftUI

// MARK: - Letter Confetti Drop
// The word explodes into its glyphs which tumble and fall under gravity,
// bounce off the floor, then magnetically reassemble into the word with a
// spring. demo == true auto-loops the burst; demo == false flings on drag.
//
// iOS 18 uses TextRenderer for true per-glyph slices. iOS 17 falls back to a
// per-character HStack — both drive the SAME closed-form physics so motion is
// identical. Physics is a pure function of elapsed time (no integrator state)
// so the loop is seamless and stable.

struct ConfettiLettersView: View {
    var demo: Bool = false

    private let word = "CONFETTI"
    private let period: Double = 3.0

    @State private var releaseDate: Date? = nil
    @State private var flingSeed: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            content(size: geo.size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(demo ? nil : flingGesture)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Layout

    @ViewBuilder
    private func content(size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let p = phase(now: timeline.date)
            ConfettiText(word: word, fling: activeFling, progress: p, size: size)
        }
    }

    // MARK: Physics phase (0...1 within one explode→reassemble cycle)

    private func phase(now: Date) -> Double {
        if demo {
            let t = now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period)
            return t / period
        }
        guard let release = releaseDate else { return 0 } // legible, assembled
        let elapsed = now.timeIntervalSince(release)
        if elapsed >= period { return 0 }
        return elapsed / period
    }

    private var activeFling: CGSize {
        if demo { return CGSize(width: 0.25, height: -1.0) } // canned lively fling
        return flingSeed
    }

    // MARK: Interaction

    private var flingGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { value in
                let vx = clampVel(value.velocity.width)
                let vy = clampVel(value.velocity.height)
                // Bias upward so the burst always lifts before falling.
                flingSeed = CGSize(width: vx, height: min(vy, -0.4) - 0.6)
                releaseDate = Date()
            }
    }

    private func clampVel(_ v: CGFloat) -> CGFloat {
        let norm = Double(v) / 1400.0
        return CGFloat(max(-1.6, min(1.6, norm)))
    }
}

// MARK: - The text + its dual rendering paths

private struct ConfettiText: View {
    let word: String
    let fling: CGSize
    let progress: Double
    let size: CGSize

    private var fontSize: CGFloat {
        // Scale to the smaller dimension so it fits both a 120pt tile and detail.
        let perGlyph: CGFloat = size.width / CGFloat(max(word.count, 1)) * 1.3
        let byHeight: CGFloat = size.height * 0.4
        let base: CGFloat = min(perGlyph, byHeight)
        return max(14, base)
    }

    var body: some View {
        let font = Font.system(size: fontSize, weight: .heavy, design: .rounded)
        Group {
            if #available(iOS 18.0, macOS 15.0, *) {
                Text(word)
                    .font(font)
                    .foregroundStyle(.white)
                    .textRenderer(
                        ConfettiGlyphRenderer(
                            progress: progress,
                            fling: fling,
                            canvasSize: size
                        )
                    )
            } else {
                FallbackConfettiText(
                    word: word,
                    progress: progress,
                    fling: fling,
                    size: size,
                    font: font
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Per-glyph confetti tint (shared by both render paths)

private func glyphTint(_ index: Int) -> Color {
    let hues: [Double] = [0.95, 0.58, 0.13, 0.45, 0.78]
    return Color(hue: hues[index % hues.count], saturation: 0.7, brightness: 1.0)
}

// MARK: - iOS 18 TextRenderer (true per-glyph slices)

@available(iOS 18.0, macOS 15.0, *)
private struct ConfettiGlyphRenderer: TextRenderer {
    var progress: Double
    var fling: CGSize
    var canvasSize: CGSize

    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        let slices = layout.flatMap { line in line.flatMap { run in run } }
        let count = slices.count
        guard count > 0 else { return }

        for (index, slice) in slices.enumerated() {
            let state = glyphState(
                index: index,
                count: count,
                progress: progress,
                fling: fling,
                size: canvasSize
            )
            let rect = slice.typographicBounds.rect
            let center = CGPoint(x: rect.midX, y: rect.midY)

            var copy = ctx
            copy.translateBy(x: state.offset.width, y: state.offset.height)
            copy.translateBy(x: center.x, y: center.y)
            copy.rotate(by: state.angle)
            copy.scaleBy(x: state.scale, y: state.scale)
            copy.translateBy(x: -center.x, y: -center.y)
            copy.opacity = state.opacity
            // White base glyph × hue == the hue, matching the iOS 17 fallback.
            copy.addFilter(.colorMultiply(glyphTint(index)))
            copy.draw(slice)
        }
    }
}

// MARK: - iOS 17 fallback (per-character HStack driving the same physics)

private struct FallbackConfettiText: View {
    let word: String
    let progress: Double
    let fling: CGSize
    let size: CGSize
    let font: Font

    private var characters: [Character] { Array(word) }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(characters.enumerated()), id: \.offset) { index, char in
                let state = glyphState(
                    index: index,
                    count: characters.count,
                    progress: progress,
                    fling: fling,
                    size: size
                )
                Text(String(char))
                    .font(font)
                    .foregroundStyle(glyphTint(index))
                    .offset(state.offset)
                    .rotationEffect(state.angle)
                    .scaleEffect(state.scale)
                    .opacity(state.opacity)
            }
        }
    }
}

// MARK: - Shared closed-form physics

private struct GlyphState {
    var offset: CGSize
    var angle: Angle
    var scale: CGFloat
    var opacity: Double
}

/// Pure function of elapsed `progress` (0...1) for one explode→reassemble cycle.
/// Returns an OFFSET from the glyph's layout home, so both render paths agree.
private func glyphState(
    index: Int,
    count: Int,
    progress: Double,
    fling: CGSize,
    size: CGSize
) -> GlyphState {
    let p = max(0, min(1, progress))

    // Per-glyph deterministic variation (seeded by index — no shimmer).
    let r1 = pseudoRandom(index, salt: 1)        // 0...1
    let r2 = pseudoRandom(index, salt: 2)
    let r3 = pseudoRandom(index, salt: 3)

    // Scale all magnitudes to the canvas so behavior matches at any tile size.
    let unit: Double = max(min(Double(size.width), Double(size.height)), 1)
    let floorY: Double = Double(size.height) * 0.5 - Double(size.height) * 0.06

    // Phase split: explode/fall/bounce (0 → 0.62), reassemble (0.62 → 1).
    let explodeEnd = 0.62

    if p <= explodeEnd {
        let t = p / explodeEnd // 0...1 within explode
        return explodePhase(
            t: t, r1: r1, r2: r2, r3: r3,
            fling: fling, unit: unit, floorY: floorY, index: index, count: count
        )
    } else {
        let t = (p - explodeEnd) / (1 - explodeEnd) // 0...1 within reassemble
        // Where the glyph "was" when reassembly began (end of explode).
        let from = explodePhase(
            t: 1, r1: r1, r2: r2, r3: r3,
            fling: fling, unit: unit, floorY: floorY, index: index, count: count
        )
        return reassemblePhase(t: t, from: from)
    }
}

private func explodePhase(
    t: Double, r1: Double, r2: Double, r3: Double,
    fling: CGSize, unit: Double, floorY: Double,
    index: Int, count: Int
) -> GlyphState {
    // Launch vector: spread glyphs outward fan + fling bias.
    let centered = Double(index) - Double(count - 1) / 2.0
    let spread = centered / Double(max(count, 1))

    let vx = (spread * 1.1 + (r1 - 0.5) * 0.8 + Double(fling.width)) * unit
    let vyBase = -(0.9 + r2 * 0.7) - Double(fling.height) * 0.5
    let vy = vyBase * unit

    let gravity = 2.6 * unit

    // Closed-form vertical position: home + v0·t + ½g·t²
    var y = vy * t + 0.5 * gravity * t * t
    let x = vx * t

    // Analytic floor bounce: reflect once the parabola crosses the floor.
    // Use a damped |sin| envelope past impact for a clean, stable bounce.
    if y > floorY {
        let overshoot = y - floorY
        // Damped bounce around the floor (loses energy).
        let bounceEnv = exp(-3.0 * t) * abs(sin(t * .pi * 3.0))
        y = floorY - overshoot * 0.0 - bounceEnv * unit * 0.55
        // Keep it from sinking below the floor visually.
        y = min(y, floorY)
    }

    // Spin scales with horizontal launch energy.
    let spin = (vx / unit) * 2.4 + (r3 - 0.5) * 6.0
    let angle = Angle.degrees(spin * t * 180.0)

    // Slight scale pulse on launch, settle to 1.
    let scale = 1.0 + 0.18 * sin(t * .pi)

    // Never fully transparent — floor at 0.62.
    let opacity = 1.0 - 0.38 * smoothstep(0.0, 1.0, t)

    let clampedX = clampOffset(x, limit: unit * 0.9)
    let clampedY = clampOffset(y, limit: unit * 0.9)

    return GlyphState(
        offset: CGSize(width: clampedX, height: clampedY),
        angle: angle,
        scale: CGFloat(scale),
        opacity: max(0.62, opacity)
    )
}

private func reassemblePhase(t: Double, from: GlyphState) -> GlyphState {
    // Magnetic snap home with slight overshoot (ease-out-back).
    let e = easeOutBack(t)
    let w = Double(from.offset.width) * (1 - e)
    let h = Double(from.offset.height) * (1 - e)

    // Unwind rotation back to upright.
    let angle = Angle.degrees(from.angle.degrees * (1 - e))

    // Scale eases to 1 with a tiny pop near the end.
    let pop = 1.0 + 0.12 * sin(min(1, t) * .pi) * t
    let fromScale = Double(from.scale)
    let scale = fromScale + (pop - fromScale) * easeOutCubic(t)

    let opacity = from.opacity + (1.0 - from.opacity) * easeOutCubic(t)

    return GlyphState(
        offset: CGSize(width: w, height: h),
        angle: angle,
        scale: CGFloat(scale),
        opacity: min(1.0, opacity)
    )
}

// MARK: - Math helpers

private func pseudoRandom(_ i: Int, salt: Int) -> Double {
    // Deterministic hash → 0...1. Stable across frames (no shimmer).
    var x = UInt64(bitPattern: Int64(i &* 73856093 ^ salt &* 19349663))
    x ^= x >> 33
    x = x &* 0xff51afd7ed558ccd
    x ^= x >> 33
    return Double(x % 10_000) / 10_000.0
}

private func clampOffset(_ v: Double, limit: Double) -> CGFloat {
    CGFloat(max(-limit, min(limit, v)))
}

private func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
    let t = max(0, min(1, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)
}

private func easeOutCubic(_ t: Double) -> Double {
    let p = 1 - max(0, min(1, t))
    return 1 - p * p * p
}

private func easeOutBack(_ t: Double) -> Double {
    let c1 = 1.70158
    let c3 = c1 + 1
    let x = max(0, min(1, t))
    let p = x - 1
    return 1 + c3 * p * p * p + c1 * p * p
}

// MARK: - Previews



// MARK: - Hex color (self-contained, no app dependency)

private extension Color {
    init(hexCode hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
