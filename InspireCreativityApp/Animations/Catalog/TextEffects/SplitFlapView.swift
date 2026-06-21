// catalog-id: tx-split-flap
import SwiftUI

// MARK: - Split-Flap Departure
// A mechanical airport split-flap board. Each character rolls through a
// clatter of random glyphs and locks onto a target letter via a double-hinge
// 3D fold (two stacked half-glyph flaps, each rotating only 90 deg so there is
// no back-face / mirror handling). Tiles cascade left-to-right with a per-tile
// delay. demo == true cycles through words on a self-driving ~3.2s loop;
// demo == false re-fires the cascade to a new word on tap.

public struct SplitFlapView: View {
    public var demo: Bool = false

    public init(demo: Bool = false) {
        self.demo = demo
    }

    public var body: some View {
        GeometryReader { geo in
            SplitFlapView_SplitFlapBoard(demo: demo, size: geo.size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Board

private struct SplitFlapView_SplitFlapBoard: View {
    let demo: Bool
    let size: CGSize

    // Short words (3-6 chars) so the board stays legible inside a ~120pt tile.
    private static let words: [String] = ["FLY", "GATE", "BOARD", "DEPART", "CLEAR", "JAZZ"]

    // Timing budget. With charCount intermediate flips at flipDur each, plus the
    // cascade stagger, the last tile must finish comfortably before `period`.
    private let period: Double = 3.2
    private let flipDur: Double = 0.13
    private let stagger: Double = 0.14
    private let intermediateCount: Int = 5

    // Interactive state (demo == false). Time-derived from `cycleStart`.
    @State private var cycleStart: Date = .now
    @State private var tapIndex: Int = 0

    private var columns: Int {
        Self.words.map(\.count).max() ?? 6
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let layout = layout(for: timeline.date)
            board(layout: layout)
        }
        // Tap re-fires the cascade to the next word (faithful to interactiveSpec).
        .contentShape(Rectangle())
        .onTapGesture {
            guard !demo else { return }
            tapIndex += 1
            cycleStart = .now
        }
    }

    // MARK: Layout metrics derived from available size

    struct Metrics {
        var cardW: CGFloat
        var cardH: CGFloat
        var fontSize: CGFloat
        var spacing: CGFloat
    }

    private func metrics() -> Metrics {
        let cols = CGFloat(columns)
        let spacing: CGFloat = max(2, min(size.width, size.height) * 0.025)
        // Fit `cols` cards plus inter-card spacing across the width, leaving margin.
        let usableW = size.width * 0.92
        let cardW = max(8, (usableW - spacing * (cols - 1)) / cols)
        // Split-flap cards are tall; cap by height too.
        let cardH = min(cardW * 1.5, size.height * 0.62)
        let fontSize = min(cardH * 0.72, cardW * 1.05)
        return Metrics(cardW: cardW, cardH: cardH, fontSize: fontSize, spacing: spacing)
    }

    // MARK: Time -> word + local time

    struct BoardLayout {
        var oldWord: String
        var newWord: String
        var localT: Double
        var cycleIndex: Int
    }

    private func layout(for date: Date) -> BoardLayout {
        let n = Self.words.count
        if demo {
            // Self-driving: derive everything purely from elapsed time.
            let t = date.timeIntervalSinceReferenceDate
            let cycleIndex = Int(floor(t / period))
            let localT = t - Double(cycleIndex) * period
            let newWord = Self.words[((cycleIndex % n) + n) % n]
            let oldWord = Self.words[(((cycleIndex - 1) % n) + n) % n]
            return BoardLayout(oldWord: oldWord, newWord: newWord, localT: localT, cycleIndex: cycleIndex)
        } else {
            // Interactive: time since the last tap drives the same render path.
            let localT = max(0, date.timeIntervalSince(cycleStart))
            let newWord = Self.words[((tapIndex % n) + n) % n]
            let oldWord = Self.words[(((tapIndex - 1) % n) + n) % n]
            return BoardLayout(oldWord: oldWord, newWord: newWord, localT: localT, cycleIndex: tapIndex)
        }
    }

    // MARK: Views

    private func board(layout: BoardLayout) -> some View {
        let m = metrics()
        return HStack(spacing: m.spacing) {
            ForEach(0..<columns, id: \.self) { col in
                SplitFlapView_FlapTile(
                    oldChar: char(layout.oldWord, at: col),
                    targetChar: char(layout.newWord, at: col),
                    localT: layout.localT,
                    tileIndex: col,
                    cycleIndex: layout.cycleIndex,
                    flipDur: flipDur,
                    stagger: stagger,
                    intermediateCount: intermediateCount,
                    metrics: m
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, m.spacing)
    }

    // Pad shorter words with blanks so every word uses the same column count.
    private func char(_ word: String, at index: Int) -> Character {
        let chars = Array(word)
        return index < chars.count ? chars[index] : " "
    }
}

// MARK: - Single flap tile

private struct SplitFlapView_FlapTile: View {
    let oldChar: Character
    let targetChar: Character
    let localT: Double
    let tileIndex: Int
    let cycleIndex: Int
    let flipDur: Double
    let stagger: Double
    let intermediateCount: Int
    let metrics: SplitFlapView_SplitFlapBoard.Metrics

    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ")

    // Deterministic pseudo-random glyph from a seed (stable across frames).
    private func glyph(step: Int) -> Character {
        var h = UInt64(bitPattern: Int64(cycleIndex &* 92821 &+ tileIndex &* 6151 &+ step &* 2654435761))
        h ^= h >> 33
        h = h &* 0xff51afd7ed558ccd
        h ^= h >> 33
        let idx = Int(h % UInt64(Self.alphabet.count))
        return Self.alphabet[idx]
    }

    // The full clatter sequence: old -> N random glyphs -> target.
    private var sequence: [Character] {
        var chars: [Character] = [oldChar]
        for s in 0..<intermediateCount {
            chars.append(glyph(step: s))
        }
        chars.append(targetChar)
        return chars
    }

    var body: some View {
        let chars = sequence
        let localTile = localT - Double(tileIndex) * stagger
        let lastStart = Double(chars.count - 1) * flipDur

        Group {
            if localTile <= 0 {
                // Before this tile starts: hold the old glyph fully formed.
                SplitFlapView_StaticCard(char: oldChar, metrics: metrics)
            } else if localTile >= lastStart {
                // Settled on the target glyph.
                SplitFlapView_StaticCard(char: targetChar, metrics: metrics)
            } else {
                let flipIdx = min(Int(localTile / flipDur), chars.count - 2)
                let p = (localTile - Double(flipIdx) * flipDur) / flipDur
                SplitFlapView_FlippingCard(
                    from: chars[flipIdx],
                    to: chars[flipIdx + 1],
                    progress: min(max(p, 0), 1),
                    metrics: metrics
                )
            }
        }
        .frame(width: metrics.cardW, height: metrics.cardH)
    }
}

// MARK: - Card chrome (shared)

private func cardFace() -> some View {
    RoundedRectangle(cornerRadius: 3, style: .continuous)
        .fill(
            LinearGradient(
                colors: [
                    Color(red: 0.11, green: 0.12, blue: 0.15),
                    Color(red: 0.05, green: 0.05, blue: 0.07)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
}

private let glyphColor = Color(red: 0.96, green: 0.96, blue: 0.93)

// One half (top or bottom) of a glyph card. The glyph is rendered centered in
// the FULL card height, then cropped to a half — so the glyph's vertical center
// lands exactly on the seam (cardH / 2).
private struct SplitFlapView_HalfCard: View {
    let char: Character
    let top: Bool
    let metrics: SplitFlapView_SplitFlapBoard.Metrics

    var body: some View {
        let w = metrics.cardW
        let h = metrics.cardH
        ZStack {
            cardFace()
            Text(String(char))
                .font(.system(size: metrics.fontSize, weight: .bold, design: .monospaced))
                .foregroundStyle(glyphColor)
                .frame(width: w, height: h)
        }
        // Crop the (full-height) content to the requested half BEFORE any rotation.
        .frame(width: w, height: h, alignment: .center)
        .frame(height: h / 2, alignment: top ? .top : .bottom)
        .clipped()
        // The dark seam line across the middle of the board.
        .overlay(alignment: top ? .bottom : .top) {
            Rectangle()
                .fill(Color(red: 0.0, green: 0.0, blue: 0.0).opacity(0.55))
                .frame(height: 1.2)
        }
    }
}

// A fully-formed (non-flipping) card: top half + bottom half stacked.
private struct SplitFlapView_StaticCard: View {
    let char: Character
    let metrics: SplitFlapView_SplitFlapBoard.Metrics

    var body: some View {
        VStack(spacing: 0) {
            SplitFlapView_HalfCard(char: char, top: true, metrics: metrics)
            SplitFlapView_HalfCard(char: char, top: false, metrics: metrics)
        }
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(Color.black.opacity(0.35), lineWidth: 0.75)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 1.5, x: 0, y: 1)
    }
}

// MARK: - The flipping card (double-hinge)

private struct SplitFlapView_FlippingCard: View {
    let from: Character
    let to: Character
    let progress: Double // 0...1 for a single old->new flip
    let metrics: SplitFlapView_SplitFlapBoard.Metrics

    private let perspective: CGFloat = 0.55

    var body: some View {
        let p = progress
        let h = metrics.cardH

        ZStack {
            // 1. Static background: new top half is revealed as the old top falls away.
            VStack(spacing: 0) {
                SplitFlapView_HalfCard(char: to, top: true, metrics: metrics)
                // 2. Static bottom: old bottom stays until the new bottom flap covers it.
                SplitFlapView_HalfCard(char: from, top: false, metrics: metrics)
            }

            // 3. Falling top flap: old TOP hinges down from the seam (0 -> -90deg).
            if p < 0.5 {
                let topP = p / 0.5 // 0...1
                SplitFlapView_HalfCard(char: from, top: true, metrics: metrics)
                    .frame(height: h / 2, alignment: .top)
                    .offset(y: -h / 4)
                    .rotation3DEffect(
                        .degrees(-90 * topP),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .bottom,
                        anchorZ: 0,
                        perspective: perspective
                    )
                    .brightness(-0.18 * topP)
                    .blur(radius: blurAmount(for: topP))
            } else {
                // 4. Falling bottom flap: new BOTTOM swings up to the seam (+90 -> 0).
                let botP = (p - 0.5) / 0.5 // 0...1
                SplitFlapView_HalfCard(char: to, top: false, metrics: metrics)
                    .frame(height: h / 2, alignment: .bottom)
                    .offset(y: h / 4)
                    .rotation3DEffect(
                        .degrees(90 * (1 - botP)),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .top,
                        anchorZ: 0,
                        perspective: perspective
                    )
                    .brightness(-0.18 * (1 - botP))
                    .blur(radius: blurAmount(for: 1 - botP))
            }
        }
        .frame(width: metrics.cardW, height: metrics.cardH)
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(Color.black.opacity(0.35), lineWidth: 0.75)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 2, x: 0, y: 1.5)
    }

    // Motion blur peaks mid-swing (fastest angular speed) for the clatter feel.
    private func blurAmount(for t: Double) -> CGFloat {
        let v = sin(t * .pi) // 0 at ends, 1 mid-swing
        return CGFloat(v) * 0.7
    }
}
