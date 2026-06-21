// catalog-id: tx-ransom-note
import SwiftUI

/// Ransom Note Assembly — letters slap onto the page as mismatched cut-out
/// clippings, each with a random typeface, tilt, torn-paper background and
/// drop shadow, entering with a quick scale-overshoot stamp.
///
/// - `demo == true`  : a self-driving TimelineView re-rolls the collage and
///   replays the staggered slap-in on a ~2.6s loop. The word stays fully
///   assembled and legible at every frame (letters re-stamp in place, they
///   never clear to empty).
/// - `demo == false` : tapping anywhere re-seeds the randomness and replays
///   the staggered scale-overshoot slap-in.
struct RansomNoteView: View {
    var demo: Bool = false

    // The shared driver. Bumping it re-rolls every letter's attributes and
    // restarts the stamp-in stagger. In demo mode a TimelineView bumps it;
    // interactively a tap bumps it.
    @State private var generation: Int = 1
    @State private var reseedTime: Date = .now

    private let phrase: [Character] = Array("RANSOM")
    private let cycle: Double = 2.6

    var body: some View {
        GeometryReader { proxy in
            let metrics = RansomNoteView_Metrics(size: proxy.size, count: phrase.count)
            ZStack {
                background
                content(metrics: metrics)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Content (driven vs. interactive)

    @ViewBuilder
    private func content(metrics: RansomNoteView_Metrics) -> some View {
        if demo {
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let gen = Int(t / cycle) + 1
                let phase = (t.truncatingRemainder(dividingBy: cycle)) / cycle
                collage(metrics: metrics, generation: gen, cyclePhase: phase)
            }
        } else {
            TimelineView(.animation) { timeline in
                let elapsed = timeline.date.timeIntervalSince(reseedTime)
                let phase = min(max(elapsed / cycle, 0), 1)
                collage(metrics: metrics, generation: generation, cyclePhase: phase)
            }
            // Expand the hit area to fill the whole tile so a tap ANYWHERE
            // (including the margins) re-seeds, per the behavior contract.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                generation += 1
                reseedTime = .now
            }
        }
    }

    // MARK: - Collage

    private func collage(metrics: RansomNoteView_Metrics, generation gen: Int, cyclePhase: Double) -> some View {
        HStack(spacing: metrics.spacing) {
            ForEach(Array(phrase.enumerated()), id: \.offset) { index, character in
                let attrs = RansomNoteView_LetterAttributes(generation: gen, index: index, baseSize: metrics.fontSize)
                let stamp = stampPhase(cyclePhase: cyclePhase, index: index)
                RansomNoteView_LetterClipping(character: character, attrs: attrs, stamp: stamp)
            }
        }
        .padding(.horizontal, metrics.spacing)
    }

    // MARK: - Stagger timing

    /// Returns a per-letter "stamp phase" in [0, 1] describing where this letter
    /// is in its own slap-in window. Letters rest (phase 0) before their slice,
    /// run 0→1 across their slice (one-by-one), then rest (phase 1) after. The
    /// RansomNoteView_LetterClipping turns 0 and 1 into the SAME settled look (scale 1.0), with
    /// the overshoot happening in between — so a letter is legible at every
    /// frame, including the cycle boundary, yet still slaps in sequentially.
    private func stampPhase(cyclePhase: Double, index: Int) -> Double {
        let count = max(phrase.count, 1)
        // Slap-in cascade occupies the first ~72% of the cycle, leaving a short
        // settled beat before the collage re-rolls.
        let window = 0.72
        let perLetter = window / Double(count)
        let start = perLetter * Double(index)
        // Each letter's own pop runs slightly longer than its slot for overlap.
        let span = perLetter * 1.35
        let local = (cyclePhase - start) / max(span, 0.0001)
        return min(max(local, 0), 1)
    }

    // MARK: - Background (paper-ish base)

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.10, blue: 0.13),
                    Color(red: 0.05, green: 0.05, blue: 0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // Faint vignette so the bright clippings pop.
            RadialGradient(
                colors: [Color.white.opacity(0.04), Color.clear],
                center: .center,
                startRadius: 0,
                endRadius: 220
            )
        }
    }
}

// MARK: - Layout metrics

private struct RansomNoteView_Metrics {
    let fontSize: CGFloat
    let spacing: CGFloat

    init(size: CGSize, count: Int) {
        let w = max(size.width, 1)
        let h = max(size.height, 1)
        let n = CGFloat(max(count, 1))
        // Per-letter footprint at rest ≈ 0.94 × fontSize (glyph + padding).
        // Budget the 1.4× scale-overshoot and ±13° tilt plus an outer margin
        // so the whole word stays inside the tile even at peak pop.
        let footprintPerLetter: CGFloat = 0.94
        let overshootBudget: CGFloat = 1.45
        let marginFactor: CGFloat = 0.86
        let byWidth = (w * marginFactor) / (n * footprintPerLetter * overshootBudget)
        let byHeight = h * 0.30
        let raw = min(byWidth, byHeight)
        fontSize = max(min(raw, 96), 9)
        spacing = max(fontSize * 0.03, 1)
    }
}

// MARK: - Per-letter randomized attributes

/// Pure function of (generation, index) — deterministic so it is stable across
/// the many body re-evaluations a TimelineView triggers per second. Randomness
/// only changes when `generation` changes.
private struct RansomNoteView_LetterAttributes {
    let design: Font.Design
    let weight: Font.Weight
    let italic: Bool
    let size: CGFloat
    let rotation: Double
    let yOffset: CGFloat
    let paper: Color
    let ink: Color
    let tornInset: CGFloat
    let tornSeed: UInt64

    init(generation: Int, index: Int, baseSize: CGFloat) {
        let seedValue = UInt64(bitPattern: Int64(generation &* 1_000 &+ index &+ 7))
        tornSeed = seedValue &* 0x2545F4914F6CDD1D | 1
        var rng = RansomNoteView_SeededGenerator(seed: seedValue)

        let designs: [Font.Design] = [.default, .serif, .rounded, .monospaced]
        design = designs[Int(rng.next() % UInt64(designs.count))]

        let weights: [Font.Weight] = [.regular, .medium, .semibold, .bold, .heavy, .black]
        weight = weights[Int(rng.next() % UInt64(weights.count))]

        italic = (rng.next() % 4 == 0)

        // Size jitter so clippings look cut at different scales.
        let sizeJitter = 0.82 + rng.unit() * 0.4
        size = baseSize * CGFloat(sizeJitter)

        // Tilt: mismatched paste angles.
        rotation = (rng.unit() * 2 - 1) * 13

        // Slight vertical scatter along the baseline.
        yOffset = CGFloat((rng.unit() * 2 - 1)) * baseSize * 0.10

        // Paper tints — newsprint / magazine clipping palette.
        paper = RansomNoteView_LetterAttributes.paperColor(&rng)
        ink = RansomNoteView_LetterAttributes.inkColor(&rng)

        tornInset = CGFloat(0.10 + rng.unit() * 0.08)
    }

    private static func paperColor(_ rng: inout RansomNoteView_SeededGenerator) -> Color {
        let palette: [(Double, Double, Double)] = [
            (0.96, 0.94, 0.88),   // cream newsprint
            (0.98, 0.97, 0.95),   // bright white
            (0.92, 0.86, 0.70),   // aged tan
            (0.86, 0.90, 0.94),   // cool grey
            (0.99, 0.84, 0.36),   // highlighter yellow
            (0.95, 0.55, 0.42),   // warm coral scrap
            (0.62, 0.82, 0.74)    // mint scrap
        ]
        let c = palette[Int(rng.next() % UInt64(palette.count))]
        return Color(red: c.0, green: c.1, blue: c.2)
    }

    private static func inkColor(_ rng: inout RansomNoteView_SeededGenerator) -> Color {
        let palette: [(Double, Double, Double)] = [
            (0.07, 0.07, 0.09),   // near-black ink
            (0.10, 0.10, 0.12),
            (0.55, 0.08, 0.10),   // red ink
            (0.10, 0.18, 0.45)    // blue ballpoint
        ]
        let c = palette[Int(rng.next() % UInt64(palette.count))]
        return Color(red: c.0, green: c.1, blue: c.2)
    }

    var font: Font {
        let base = Font.system(size: size, weight: weight, design: design)
        return italic ? base.italic() : base
    }
}

// MARK: - A single torn-paper letter clipping

private struct RansomNoteView_LetterClipping: View {
    let character: Character
    let attrs: RansomNoteView_LetterAttributes
    /// 0 = resting (not yet stamped or fully settled), runs 0→1 across the
    /// letter's slap-in slice with an overshoot in the middle.
    let stamp: Double

    var body: some View {
        let scale = stampScale(stamp)
        let activity = popActivity(stamp)          // 0 at rest, ~1 mid-pop
        let settleRotation = attrs.rotation * (1.0 + activity * 0.55)
        let isActive = stamp > 0.001 && stamp < 0.999

        clipping
            .rotationEffect(.degrees(settleRotation))
            .offset(y: attrs.yOffset - CGFloat(activity) * attrs.size * 0.12)
            .scaleEffect(scale)
            .opacity(stampOpacity(stamp))
            .zIndex(isActive ? 1 : 0)
    }

    private var clipping: some View {
        Text(String(character))
            .font(attrs.font)
            .foregroundStyle(attrs.ink)
            .padding(.horizontal, attrs.size * 0.16)
            .padding(.vertical, attrs.size * 0.10)
            .background {
                RansomNoteView_TornPaper(inset: attrs.tornInset, seed: attrs.tornSeed)
                    .fill(attrs.paper)
                    .overlay {
                        RansomNoteView_TornPaper(inset: attrs.tornInset, seed: attrs.tornSeed)
                            .stroke(Color.black.opacity(0.13), lineWidth: 0.6)
                    }
                    .shadow(color: Color.black.opacity(0.45),
                            radius: attrs.size * 0.10,
                            x: attrs.size * 0.04,
                            y: attrs.size * 0.06)
            }
    }

    // Pop-in-place: rests at 1.0, punches up to ~1.4 at the slice midpoint,
    // then settles back to 1.0. Because both ends are 1.0 the cycle boundary
    // is seamless and the letter is never small or blank.
    private func stampScale(_ p: Double) -> CGFloat {
        if p <= 0 || p >= 1 { return 1.0 }
        // Rise quickly, settle with a damped tail.
        let rise = sin(min(p / 0.30, 1.0) * Double.pi / 2)   // 0→1 fast
        let fall = 1 - pow(max((p - 0.30) / 0.70, 0), 2)      // 1→0 slow
        let amplitude = p < 0.30 ? rise : fall
        let value = 1.0 + 0.40 * max(min(amplitude, 1), 0)
        return CGFloat(value)
    }

    // How "mid-pop" the letter is (drives the lift and extra tilt).
    private func popActivity(_ p: Double) -> Double {
        if p <= 0 || p >= 1 { return 0 }
        return sin(p * Double.pi)
    }

    // Opacity floored at 0.78 so the word is always legible. It dips only very
    // slightly at the start of a pop to read as a fresh slap, never near blank.
    private func stampOpacity(_ p: Double) -> Double {
        if p <= 0 || p >= 1 { return 1.0 }
        let dip = 0.22 * (1 - sin(min(p / 0.18, 1.0) * Double.pi / 2))
        return 1.0 - dip
    }
}

// MARK: - Torn-paper edge shape

/// A rectangle whose edges are nibbled with small irregular notches to suggest
/// a hand-torn clipping. Deterministic per `seed` so it is stable across frames
/// yet varies per letter and per re-roll.
private struct RansomNoteView_TornPaper: Shape {
    let inset: CGFloat
    let seed: UInt64

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let teeth = 9
        let amp = min(rect.width, rect.height) * inset * 0.4

        var rng = RansomNoteView_SeededGenerator(seed: seed)

        // Walk the perimeter producing a jagged torn outline.
        let points = perimeterPoints(rect: rect, teeth: teeth, amp: amp, rng: &rng)
        guard let first = points.first else { return path }
        path.move(to: first)
        for p in points.dropFirst() {
            path.addLine(to: p)
        }
        path.closeSubpath()
        return path
    }

    private func perimeterPoints(rect: CGRect, teeth: Int, amp: CGFloat, rng: inout RansomNoteView_SeededGenerator) -> [CGPoint] {
        var pts: [CGPoint] = []
        let edges: [(CGPoint, CGPoint)] = [
            (CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY)),
            (CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.maxY)),
            (CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)),
            (CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.minY))
        ]
        for (a, b) in edges {
            for i in 0..<teeth {
                let f = CGFloat(i) / CGFloat(teeth)
                let x = a.x + (b.x - a.x) * f
                let y = a.y + (b.y - a.y) * f
                // Offset perpendicular-ish by a small jitter to nibble the edge.
                let jitter = (CGFloat(rng.unit()) * 2 - 1) * amp
                let isHorizontal = abs(b.y - a.y) < abs(b.x - a.x)
                let px = isHorizontal ? x : x + jitter
                let py = isHorizontal ? y + jitter : y
                pts.append(CGPoint(x: px, y: py))
            }
        }
        return pts
    }
}

// MARK: - Deterministic RNG

/// SplitMix64 — a tiny, fast, fully deterministic generator so per-letter
/// attributes are a pure function of their seed (never re-rolled per frame).
private struct RansomNoteView_SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // Avoid a zero state.
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// A Double in [0, 1).
    mutating func unit() -> Double {
        Double(next() >> 11) * (1.0 / 9007199254740992.0)
    }
}
