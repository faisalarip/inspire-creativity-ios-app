// catalog-id: tx-elastic-rope
import SwiftUI

// MARK: - Elastic Rope Text
// Drag anywhere on the line to pluck the nearest glyphs toward your finger on
// damped springs; release and a traveling recoil wave snaps everything back.
// Idle, a virtual touch point sweeps the line so the rope ripples on its own.

public struct ElasticRopeView: View {
    public var demo: Bool = false

    public init(demo: Bool = false) {
        self.demo = demo
    }

    private let phrase: String = "ELASTIC"

    public var body: some View {
        GeometryReader { proxy in
            content(in: proxy.size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        let amplitude = ElasticRopeView_ElasticRopeMath.amplitude(for: size)
        let fontSize = ElasticRopeView_ElasticRopeMath.fontSize(for: size, charCount: phrase.count)

        ElasticRopeView_ElasticRopeStage(
            phrase: phrase,
            demo: demo,
            size: size,
            amplitude: amplitude,
            fontSize: fontSize
        )
    }
}

// MARK: - Shared math (single source of truth for displacement)

private enum ElasticRopeView_ElasticRopeMath {

    static func amplitude(for size: CGSize) -> CGFloat {
        // Clamp pull strength to the tile so glyphs never fly off / clip.
        let base = min(size.width, size.height) * 0.42
        return max(8, min(base, 80))
    }

    static func fontSize(for size: CGSize, charCount: Int) -> CGFloat {
        let byWidth = size.width / (CGFloat(max(charCount, 1)) * 0.72)
        let byHeight = size.height * 0.42
        return max(13, min(min(byWidth, byHeight), 64))
    }

    /// Falloff weight in fraction-space (0...1 along the line).
    /// Nearest glyph to the touch fraction gets the strongest pull.
    static func weight(glyphFraction: CGFloat, touchFraction: CGFloat) -> CGFloat {
        let d = abs(glyphFraction - touchFraction)
        let sigma: CGFloat = 0.18
        let x = d / sigma
        return CGFloat(exp(Double(-x * x)))      // Gaussian bell, peak 1 at the finger
    }

    /// Pure displacement for one glyph given its position along the line and the
    /// current touch state. Returns an (dx, dy) offset in points.
    /// `touchFraction`/`touchY` describe where the finger (or virtual sweep) is.
    /// `pull` is 0...1 active grip strength; `recoil` carries the snap-back wave.
    static func displacement(
        glyphFraction: CGFloat,
        touchFraction: CGFloat,
        touchY: CGFloat,
        pull: CGFloat,
        recoil: ElasticRopeView_RecoilState,
        amplitude: CGFloat,
        index: Int,
        count: Int
    ) -> CGSize {

        // 1. Active grip: glyphs near the finger are tugged toward it.
        let w = weight(glyphFraction: glyphFraction, touchFraction: touchFraction)
        let dir = touchFraction - glyphFraction
        let gripX = dir * amplitude * w * pull
        let gripY = touchY * amplitude * 0.55 * w * pull

        // 2. Recoil: after release, a damped spring wave travels down the line.
        var recoilX: CGFloat = 0
        var recoilY: CGFloat = 0
        if recoil.active {
            // Per-index delay so the snap-back ripples along the rope.
            let travel = CGFloat(index) / CGFloat(max(count - 1, 1))
            let delayed = recoil.elapsed - travel * 0.28
            if delayed > 0 {
                let decay = CGFloat(exp(Double(-delayed * 6.5)))
                let osc = CGFloat(sin(Double(delayed * 34)))
                let releaseWeight = weight(
                    glyphFraction: glyphFraction,
                    touchFraction: recoil.fraction
                )
                let energy = recoil.strength * releaseWeight * decay
                recoilX = (recoil.fraction - glyphFraction) * amplitude * 0.9 * osc * energy
                recoilY = recoil.y * amplitude * 0.5 * osc * energy
            }
        }

        return CGSize(width: gripX + recoilX, height: gripY + recoilY)
    }
}

/// Snapshot of the release-recoil wave.
private struct ElasticRopeView_RecoilState {
    var active: Bool = false
    var fraction: CGFloat = 0.5   // where the finger let go (0...1)
    var y: CGFloat = 0            // vertical pull at release (normalized)
    var strength: CGFloat = 0     // 0...1 captured grip strength
    var elapsed: Double = 0       // seconds since release
}

// MARK: - Stage: one always-on TimelineView drives both modes

private struct ElasticRopeView_ElasticRopeStage: View {
    let phrase: String
    let demo: Bool
    let size: CGSize
    let amplitude: CGFloat
    let fontSize: CGFloat

    // Live drag state (interactive mode only).
    @State private var isDragging: Bool = false
    @State private var dragFraction: CGFloat = 0.5
    @State private var dragY: CGFloat = 0

    // Release info, captured the instant the finger lifts.
    @State private var releaseDate: Date? = nil
    @State private var releaseFraction: CGFloat = 0.5
    @State private var releaseY: CGFloat = 0
    @State private var releaseStrength: CGFloat = 0

    private var characters: [Character] { Array(phrase) }

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date
            let t = now.timeIntervalSinceReferenceDate
            let state = resolveTouch(now: now, t: t)

            ZStack {
                background
                ropeContent(state: state)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture, including: demo ? .none : .all)
        }
    }

    // MARK: Touch resolution

    struct TouchState {
        var fraction: CGFloat
        var y: CGFloat
        var pull: CGFloat
        var recoil: ElasticRopeView_RecoilState
    }

    private func resolveTouch(now: Date, t: TimeInterval) -> TouchState {
        if !demo && isDragging {
            // Live grip.
            return TouchState(
                fraction: dragFraction,
                y: dragY,
                pull: 1.0,
                recoil: ElasticRopeView_RecoilState(active: false)
            )
        }

        // Build any active recoil wave from the last release.
        var recoil = ElasticRopeView_RecoilState(active: false)
        if let release = releaseDate {
            let elapsed = now.timeIntervalSince(release)
            if elapsed < 1.4 {
                recoil = ElasticRopeView_RecoilState(
                    active: true,
                    fraction: releaseFraction,
                    y: releaseY,
                    strength: releaseStrength,
                    elapsed: elapsed
                )
            }
        }

        if demo {
            // Virtual sweep travels the line on a ~3.2s loop, always visible.
            let period: Double = 3.2
            let phase = (t.truncatingRemainder(dividingBy: period)) / period
            let frac = 0.5 + 0.46 * CGFloat(sin(phase * 2 * .pi))
            let yWobble = 0.5 * CGFloat(sin(phase * 4 * .pi))
            // Pull eases in/out so the rope breathes rather than snapping.
            let pull = 0.55 + 0.45 * CGFloat(0.5 - 0.5 * cos(phase * 4 * .pi))
            return TouchState(fraction: frac, y: yWobble, pull: pull, recoil: recoil)
        }

        // Interactive, idle (not dragging): gentle auto sine so the tile stays alive.
        let period: Double = 3.6
        let phase = (t.truncatingRemainder(dividingBy: period)) / period
        let frac = 0.5 + 0.30 * CGFloat(sin(phase * 2 * .pi))
        let idlePull: CGFloat = recoil.active ? 0 : 0.28
        return TouchState(fraction: frac, y: 0, pull: idlePull, recoil: recoil)
    }

    // MARK: Content (iOS 18 TextRenderer, with iOS 17 fallback)

    @ViewBuilder
    private func ropeContent(state: TouchState) -> some View {
        if #available(iOS 18.0, *) {
            renderedText(state: state)
        } else {
            fallbackText(state: state)
        }
    }

    @available(iOS 18.0, *)
    @ViewBuilder
    private func renderedText(state: TouchState) -> some View {
        let renderer = ElasticRopeView_ElasticRopeRenderer(
            touchFraction: state.fraction,
            touchY: state.y,
            pull: state.pull,
            recoil: state.recoil,
            amplitude: amplitude,
            count: characters.count
        )
        styledText
            .textRenderer(renderer)
    }

    // iOS 17 fallback: per-character offset HStack sharing the same math.
    @ViewBuilder
    private func fallbackText(state: TouchState) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(characters.enumerated()), id: \.offset) { idx, ch in
                let frac = characters.count <= 1
                    ? 0.5
                    : CGFloat(idx) / CGFloat(characters.count - 1)
                let offset = ElasticRopeView_ElasticRopeMath.displacement(
                    glyphFraction: frac,
                    touchFraction: state.fraction,
                    touchY: state.y,
                    pull: state.pull,
                    recoil: state.recoil,
                    amplitude: amplitude,
                    index: idx,
                    count: characters.count
                )
                Text(String(ch))
                    .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                    .kerning(1.5)
                    .foregroundStyle(glyphStyle)
                    .offset(x: offset.width, y: offset.height)
            }
        }
    }

    private var styledText: some View {
        Text(phrase)
            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
            .kerning(2)
            .foregroundStyle(glyphStyle)
    }

    private var glyphStyle: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.62, green: 0.86, blue: 1.00),
                Color(red: 0.46, green: 0.62, blue: 0.98),
                Color(red: 0.78, green: 0.58, blue: 0.99)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.015, green: 0.020, blue: 0.040),
                Color(red: 0.040, green: 0.050, blue: 0.090)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDragging = true
                releaseDate = nil
                let f = size.width > 0 ? value.location.x / size.width : 0.5
                dragFraction = min(max(f, 0), 1)
                // Vertical pull normalized about the line center.
                let center = size.height / 2
                let dy = size.height > 0 ? (value.location.y - center) / (size.height / 2) : 0
                dragY = min(max(dy, -1), 1)
            }
            .onEnded { value in
                isDragging = false
                let f = size.width > 0 ? value.location.x / size.width : 0.5
                releaseFraction = min(max(f, 0), 1)
                releaseY = dragY
                releaseStrength = 1.0
                releaseDate = Date()
            }
    }
}

// MARK: - iOS 18 TextRenderer

@available(iOS 18.0, *)
private struct ElasticRopeView_ElasticRopeRenderer: TextRenderer {
    let touchFraction: CGFloat
    let touchY: CGFloat
    let pull: CGFloat
    let recoil: ElasticRopeView_RecoilState
    let amplitude: CGFloat
    let count: Int

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        // Collect every glyph slice in reading order so we can index them
        // for the per-glyph traveling recoil wave.
        var slices: [Text.Layout.RunSlice] = []
        for line in layout {
            for run in line {
                for slice in run {
                    slices.append(slice)
                }
            }
        }

        let total = max(slices.count, 1)
        for (idx, slice) in slices.enumerated() {
            let glyphFraction = total <= 1
                ? 0.5
                : CGFloat(idx) / CGFloat(total - 1)

            let offset = ElasticRopeView_ElasticRopeMath.displacement(
                glyphFraction: glyphFraction,
                touchFraction: touchFraction,
                touchY: touchY,
                pull: pull,
                recoil: recoil,
                amplitude: amplitude,
                index: idx,
                count: count
            )

            var copy = context
            copy.translateBy(x: offset.width, y: offset.height)
            copy.draw(slice)
        }
    }
}
