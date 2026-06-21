// catalog-id: tx-fold-origami
import SwiftUI

/// Origami Letter Unfold — each glyph unfolds from a flat folded triangle,
/// hinging open across two creases with 3D rotation and a gradient fold-shadow
/// that resolves to a flat face, staggered like a paper fan opening.
///
/// - demo == true  : self-driving PhaseAnimator-style loop (via TimelineView)
///                   folds the word shut then open on a ~2.8s loop.
/// - demo == false : tap to replay the staggered unfold from folded triangles
///                   to flat faces.
struct FoldOrigamiView: View {
    var demo: Bool = false

    // The short word keeps the per-letter fan legible inside a ~120pt tile.
    private let word: [Character] = Array("FOLD")

    // Loop timing for the auto-driving preview.
    private let loopDuration: Double = 2.8

    // How much of the loop each successive letter is delayed (paper-fan stagger).
    private let stagger: Double = 0.16
    // The window over which a single letter completes its unfold.
    private let foldWindow: Double = 0.55

    @State private var tapProgress: Double = 1.0
    @State private var loopStart: Date = .now

    var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if demo {
            autoDriven(in: size)
        } else {
            interactive(in: size)
        }
    }

    // MARK: - Auto-driving preview

    private func autoDriven(in size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(loopStart)
            let global = loopProgress(t)
            letterRow(in: size, globalProgress: global)
        }
    }

    // Maps elapsed time to a 0→1→0 triangle wave so the fan opens then folds shut.
    private func loopProgress(_ elapsed: Double) -> Double {
        let phase = (elapsed / loopDuration).truncatingRemainder(dividingBy: 1.0)
        // Ease the ramp so the open/close feels paper-soft, not linear.
        let ramp = phase < 0.5 ? phase * 2.0 : (1.0 - phase) * 2.0
        return easeInOut(ramp)
    }

    // MARK: - Interactive (tap to replay)

    private func interactive(in size: CGSize) -> some View {
        letterRow(in: size, globalProgress: tapProgress)
            .onTapGesture {
                replayUnfold()
            }
    }

    private func replayUnfold() {
        // Snap shut instantly, then unfold open with a staggered spring-ish ramp.
        tapProgress = 0.0
        withAnimation(.timingCurve(0.22, 0.9, 0.3, 1.0, duration: 1.5)) {
            tapProgress = 1.0
        }
    }

    // MARK: - Shared layout

    private func letterRow(in size: CGSize, globalProgress: Double) -> some View {
        let metrics = layoutMetrics(for: size)
        return HStack(spacing: metrics.spacing) {
            ForEach(Array(word.enumerated()), id: \.offset) { index, char in
                FoldOrigamiView_FoldingLetter(
                    character: char,
                    fontSize: metrics.fontSize,
                    progress: letterProgress(globalProgress, index: index)
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // Per-letter progress: stagger the start, then complete over a fixed window.
    private func letterProgress(_ global: Double, index: Int) -> Double {
        let start = Double(index) * stagger
        let local = (global - start) / foldWindow
        return clamp01(local)
    }

    // MARK: - Metrics

    struct Metrics {
        let fontSize: CGFloat
        let spacing: CGFloat
    }

    private func layoutMetrics(for size: CGSize) -> Metrics {
        let count = CGFloat(max(word.count, 1))
        // Reserve some breathing room; size the type to the smaller axis budget.
        let widthBudget: CGFloat = size.width * 0.82
        let perLetterWidth = widthBudget / count
        // Glyph aspect heuristic: width ≈ 0.66 * fontSize for this caps word.
        let byWidth = perLetterWidth / 0.78
        let byHeight = size.height * 0.5
        let raw = min(byWidth, byHeight)
        let fontSize = max(14.0, min(raw, 120.0))
        let spacing = max(1.0, fontSize * 0.06)
        return Metrics(fontSize: fontSize, spacing: spacing)
    }

    // MARK: - Math helpers

    private func clamp01(_ v: Double) -> Double {
        min(1.0, max(0.0, v))
    }

    private func easeInOut(_ x: Double) -> Double {
        // Smoothstep.
        let c = min(1.0, max(0.0, x))
        return c * c * (3.0 - 2.0 * c)
    }
}

// MARK: - FoldOrigamiView_FoldingLetter

/// One glyph rendered as two half-faces hinging open along a central crease.
/// progress == 0 → folded shut (a foreshortened triangle, still legible),
/// progress == 1 → flat, the two halves recomposing into the whole glyph.
private struct FoldOrigamiView_FoldingLetter: View {
    let character: Character
    let fontSize: CGFloat
    let progress: Double   // 0 folded ... 1 flat

    // Clamp the maximum fold so the "shut" extreme is a legible foreshortened
    // triangle rather than an invisible edge-on line (never-blank guarantee).
    private let maxFold: Double = 74.0

    // Paper tints.
    private let paper = Color(red: 0.97, green: 0.96, blue: 0.93)
    private let ink = Color(red: 0.07, green: 0.08, blue: 0.11)

    var body: some View {
        ZStack {
            topHalf
            bottomHalf
        }
        .frame(width: glyphWidth, height: glyphHeight)
        // A faint cast shadow that grows when folded for a touch of depth.
        .background(castShadow)
        .compositingGroup()
        .opacity(faceOpacity)
    }

    // MARK: - Halves

    private var topHalf: some View {
        glyphFace
            .mask(halfMask(top: true))
            .overlay(creaseShadow(top: true).mask(halfMask(top: true)))
            .rotation3DEffect(
                .degrees(foldAngle),
                axis: (x: 1.0, y: 0.22, z: 0.0),
                anchor: .bottom,
                perspective: 0.55
            )
    }

    private var bottomHalf: some View {
        glyphFace
            .mask(halfMask(top: false))
            .overlay(creaseShadow(top: false).mask(halfMask(top: false)))
            .rotation3DEffect(
                .degrees(-foldAngle),
                axis: (x: 1.0, y: -0.22, z: 0.0),
                anchor: .top,
                perspective: 0.55
            )
    }

    // The actual letter face — identical frame for both copies so the flat
    // state recomposes seamlessly with no seam between halves.
    private var glyphFace: some View {
        Text(String(character))
            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
            .foregroundStyle(ink)
            .frame(width: glyphWidth, height: glyphHeight)
    }

    // MARK: - Masks

    private func halfMask(top: Bool) -> some View {
        VStack(spacing: 0) {
            if top {
                Rectangle().fill(.black)
                Rectangle().fill(.clear)
            } else {
                Rectangle().fill(.clear)
                Rectangle().fill(.black)
            }
        }
        .frame(width: glyphWidth, height: glyphHeight)
    }

    // MARK: - Crease shadow

    // A gradient that darkens toward the crease and fades as the face opens flat.
    private func creaseShadow(top: Bool) -> some View {
        let start: UnitPoint = top ? .bottom : .top
        let end: UnitPoint = top ? .top : .bottom
        return LinearGradient(
            colors: [
                Color.black.opacity(creaseOpacity),
                Color.black.opacity(creaseOpacity * 0.18),
                Color.clear
            ],
            startPoint: start,
            endPoint: end
        )
        .blendMode(.multiply)
    }

    // MARK: - Cast shadow under the folded paper

    private var castShadow: some View {
        Ellipse()
            .fill(Color.black.opacity(0.10 + 0.10 * (1.0 - clampedProgress)))
            .frame(width: glyphWidth * 0.82, height: glyphHeight * 0.16)
            .blur(radius: 3)
            .offset(y: glyphHeight * 0.46)
    }

    // MARK: - Derived values

    private var clampedProgress: Double {
        min(1.0, max(0.0, progress))
    }

    // Fold angle: full clamped fold when shut, 0 when flat/open.
    private var foldAngle: Double {
        maxFold * (1.0 - clampedProgress)
    }

    // Crease shadow strongest when folded, fading to nothing when flat.
    private var creaseOpacity: Double {
        0.55 * (1.0 - clampedProgress)
    }

    // Keep the glyph fully visible; only nudge opacity at the very start so a
    // freshly-snapped-shut letter still reads.
    private var faceOpacity: Double {
        0.55 + 0.45 * clampedProgress
    }

    private var glyphWidth: CGFloat {
        fontSize * 0.78
    }

    private var glyphHeight: CGFloat {
        fontSize * 1.12
    }
}
