// catalog-id: nav-collapsing-chevron-crumbs
import SwiftUI

// MARK: - Collapsing Chevron Crumbs
// A breadcrumb trail whose older crumbs telescope into a folded chevron-stacked
// chip that springs open like a paper fan on tap, and re-collapses with a
// staggered zip when you pick one.
//
// demo == true  -> self-driving TimelineView loop (deepen -> fan open -> collapse).
//                  The fan is interpolated MANUALLY from a continuous progress,
//                  because matchedGeometryEffect only interpolates across an
//                  animated state transition, never a per-frame TimelineView value.
// demo == false -> the real tap-driven component using @Namespace +
//                  matchedGeometryEffect with index-staggered springs.

public struct CollapsingChevronCrumbsView: View {
    public var demo: Bool = false

    public init(demo: Bool = false) {
        self.demo = demo
    }

    public var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                CollapsingChevronCrumbsView_CCBackground()
                Group {
                    if demo {
                        CollapsingChevronCrumbsView_CCDemoTrail(size: size)
                    } else {
                        CollapsingChevronCrumbsView_CCInteractiveTrail(size: size)
                    }
                }
                .padding(.horizontal, max(8, size.width * 0.05))
            }
            .frame(width: size.width, height: size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Palette

private enum CollapsingChevronCrumbsView_CCPalette {
    static let bg0 = Color(red: 0.043, green: 0.055, blue: 0.071)
    static let bg1 = Color(red: 0.078, green: 0.094, blue: 0.118)

    static let chipFill = Color(red: 0.137, green: 0.165, blue: 0.204)
    static let chipFillHi = Color(red: 0.184, green: 0.220, blue: 0.271)
    static let chipStroke = Color(red: 0.298, green: 0.345, blue: 0.420)

    static let leaf0 = Color(red: 0.353, green: 0.733, blue: 0.965)
    static let leaf1 = Color(red: 0.557, green: 0.553, blue: 0.984)

    static let textBright = Color(red: 0.910, green: 0.937, blue: 0.984)
    static let textDim = Color(red: 0.604, green: 0.659, blue: 0.745)

    static let chevron = Color(red: 0.745, green: 0.804, blue: 0.902)
}

// MARK: - Model

private struct CollapsingChevronCrumbsView_CCCrumb: Identifiable, Equatable {
    let id: Int
    let label: String
    let symbol: String
}

private enum CollapsingChevronCrumbsView_CCData {
    /// Short labels + glyphs so the trail stays legible even in a ~120pt tile.
    static let all: [CollapsingChevronCrumbsView_CCCrumb] = [
        CollapsingChevronCrumbsView_CCCrumb(id: 0, label: "Home", symbol: "house.fill"),
        CollapsingChevronCrumbsView_CCCrumb(id: 1, label: "Files", symbol: "folder.fill"),
        CollapsingChevronCrumbsView_CCCrumb(id: 2, label: "Work", symbol: "tray.full.fill"),
        CollapsingChevronCrumbsView_CCCrumb(id: 3, label: "2026", symbol: "calendar"),
        CollapsingChevronCrumbsView_CCCrumb(id: 4, label: "Specs", symbol: "doc.fill")
    ]
}

// MARK: - Background

private struct CollapsingChevronCrumbsView_CCBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [CollapsingChevronCrumbsView_CCPalette.bg1, CollapsingChevronCrumbsView_CCPalette.bg0],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
    }
}

// MARK: - Shared chip rendering

/// A single breadcrumb pill. `scale`/`opacity` let the demo path animate it
/// without matchedGeometry; the interactive path leaves them at 1.
private struct CollapsingChevronCrumbsView_CCCrumbChip: View {
    let crumb: CollapsingChevronCrumbsView_CCCrumb
    let metric: CGFloat          // base sizing unit (≈ tile-relative)
    var isLeaf: Bool = false
    var compact: Bool = false    // icon-only (used in collapsed stack)
    var dim: Double = 1.0

    private var pad: CGFloat { metric * 0.34 }
    private var iconSize: CGFloat { metric * 0.46 }
    private var fontSize: CGFloat { metric * 0.42 }

    var body: some View {
        HStack(spacing: metric * 0.18) {
            Image(systemName: crumb.symbol)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(iconStyle)
            if !compact {
                Text(crumb.label)
                    .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(isLeaf ? CollapsingChevronCrumbsView_CCPalette.textBright : CollapsingChevronCrumbsView_CCPalette.textDim)
                    .fixedSize()
            }
        }
        .padding(.vertical, pad * 0.55)
        .padding(.horizontal, pad)
        .background(chipBackground)
        .overlay(
            Capsule(style: .continuous)
                .stroke(strokeStyle, lineWidth: 1)
        )
        .opacity(dim)
    }

    private var iconStyle: AnyShapeStyle {
        if isLeaf {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [CollapsingChevronCrumbsView_CCPalette.leaf0, CollapsingChevronCrumbsView_CCPalette.leaf1],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(CollapsingChevronCrumbsView_CCPalette.textDim)
    }

    private var chipBackground: some View {
        Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: isLeaf
                        ? [CollapsingChevronCrumbsView_CCPalette.chipFillHi, CollapsingChevronCrumbsView_CCPalette.chipFill]
                        : [CollapsingChevronCrumbsView_CCPalette.chipFill, CollapsingChevronCrumbsView_CCPalette.chipFill.opacity(0.85)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                Capsule(style: .continuous)
                    .fill(leafGlow)
            )
    }

    private var leafGlow: Color {
        isLeaf ? CollapsingChevronCrumbsView_CCPalette.leaf0.opacity(0.10) : .clear
    }

    private var strokeStyle: Color {
        isLeaf ? CollapsingChevronCrumbsView_CCPalette.leaf0.opacity(0.55) : CollapsingChevronCrumbsView_CCPalette.chipStroke.opacity(0.7)
    }
}

/// The small chevron caret drawn between crumbs and inside the folded stack.
private struct CollapsingChevronCrumbsView_CCChevron: View {
    let metric: CGFloat
    var rotation: Double = 0      // 0 = pointing right (collapsed), 90 = down-ish (open)
    var opacity: Double = 1

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: metric * 0.34, weight: .bold))
            .foregroundStyle(CollapsingChevronCrumbsView_CCPalette.chevron.opacity(0.85))
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
    }
}

// MARK: - DEMO PATH (self-driving, manual interpolation)

private struct CollapsingChevronCrumbsView_CCDemoTrail: View {
    let size: CGSize

    // Loop: deepen -> hold-collapsed -> fan open -> hold-open -> collapse.
    private let period: Double = 3.6

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = (t.truncatingRemainder(dividingBy: period)) / period // 0..1
            let frame = CollapsingChevronCrumbsView_CCDemoFrame(phase: phase)
            content(frame)
        }
    }

    private var metric: CGFloat { max(13, min(size.height, size.width * 0.5) * 0.30) }

    @ViewBuilder
    private func content(_ f: CollapsingChevronCrumbsView_CCDemoFrame) -> some View {
        // Folded crumbs = everything except the leaf; depth grows over the loop.
        let folded = Array(CollapsingChevronCrumbsView_CCData.all.prefix(f.foldedCount))
        let leaf = CollapsingChevronCrumbsView_CCData.all[f.foldedCount]

        HStack(spacing: metric * 0.22) {
            CollapsingChevronCrumbsView_CCFoldedChipDemo(
                folded: folded,
                metric: metric,
                progress: f.open,
                count: f.foldedCount
            )
            CollapsingChevronCrumbsView_CCChevron(metric: metric, rotation: f.open * 90, opacity: 0.6 + 0.4 * f.open)
            CollapsingChevronCrumbsView_CCCrumbChip(crumb: leaf, metric: metric, isLeaf: true)
                .scaleEffect(0.96 + 0.04 * f.leafPulse)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Per-frame derived state for the demo loop.
private struct CollapsingChevronCrumbsView_CCDemoFrame {
    let foldedCount: Int   // how many crumbs are folded behind the chip
    let open: Double       // 0 = stacked chevron, 1 = fully fanned out
    let leafPulse: Double  // 0..1 little settle on the leaf

    init(phase p: Double) {
        // Beat layout across the loop (fractions of period):
        //  0.00–0.18  deepen: a crumb folds in (count grows)
        //  0.18–0.30  hold collapsed
        //  0.30–0.55  fan OPEN (spring-eased)
        //  0.55–0.78  hold open
        //  0.78–1.00  collapse (zip)
        let count: Int
        if p < 0.18 {
            count = 3
        } else {
            count = 4
        }
        self.foldedCount = count

        let o: Double
        if p < 0.30 {
            o = 0
        } else if p < 0.55 {
            o = CollapsingChevronCrumbsView_CCEase.spring((p - 0.30) / 0.25)
        } else if p < 0.78 {
            o = 1
        } else {
            o = 1 - CollapsingChevronCrumbsView_CCEase.inOut((p - 0.78) / 0.22)
        }
        self.open = min(max(o, 0), 1)

        // Leaf gives a tiny pop right when a deeper crumb lands.
        if p < 0.18 {
            self.leafPulse = CollapsingChevronCrumbsView_CCEase.inOut(p / 0.18)
        } else if p < 0.30 {
            self.leafPulse = 1 - CollapsingChevronCrumbsView_CCEase.inOut((p - 0.18) / 0.12)
        } else {
            self.leafPulse = 0
        }
    }
}

/// The folded chip for the demo path. At progress 0 the crumbs overlap as a
/// chevron stack; at progress 1 they fan out inline. Pure manual interpolation,
/// so it works perfectly under a per-frame TimelineView value (no matchedGeometry).
private struct CollapsingChevronCrumbsView_CCFoldedChipDemo: View {
    let folded: [CollapsingChevronCrumbsView_CCCrumb]
    let metric: CGFloat
    let progress: Double   // 0 collapsed -> 1 fanned
    let count: Int

    private var stackOverlap: CGFloat { metric * 0.62 }

    var body: some View {
        ZStack(alignment: .leading) {
            ForEach(Array(folded.enumerated()), id: \.element.id) { idx, crumb in
                let isLast = idx == folded.count - 1
                CollapsingChevronCrumbsView_CCDemoFoldedCrumb(
                    crumb: crumb,
                    index: idx,
                    total: folded.count,
                    metric: metric,
                    progress: staggered(progress, index: idx, total: folded.count),
                    stackOverlap: stackOverlap
                )
                .zIndex(Double(idx))
                .overlay(alignment: .topTrailing) {
                    if isLast && progress < 0.12 {
                        CollapsingChevronCrumbsView_CCStackBadge(count: count, metric: metric)
                            .opacity(1 - progress / 0.12)
                            .offset(x: metric * 0.18, y: -metric * 0.28)
                    }
                }
            }
        }
        // Reserve width so the fanned-out crumbs have room to spread.
        .frame(width: fannedWidth(), alignment: .leading)
    }

    private func fannedWidth() -> CGFloat {
        let collapsed = metric * 1.1 + stackOverlap * CGFloat(max(0, folded.count - 1)) * 0.0
        let perCrumb = metric * 2.4
        let fanned = perCrumb * CGFloat(folded.count)
        return collapsed + (fanned - collapsed) * CGFloat(progress)
    }

    /// Index-based stagger so the fan opens left-to-right like a paper fan.
    private func staggered(_ p: Double, index: Int, total: Int) -> Double {
        guard total > 1 else { return p }
        let span = 0.45
        let start = (Double(index) / Double(total)) * span
        let scaled = (p - start) / (1 - span)
        return min(max(scaled, 0), 1)
    }
}

private struct CollapsingChevronCrumbsView_CCDemoFoldedCrumb: View {
    let crumb: CollapsingChevronCrumbsView_CCCrumb
    let index: Int
    let total: Int
    let metric: CGFloat
    let progress: Double
    let stackOverlap: CGFloat

    var body: some View {
        let collapsedX = CGFloat(index) * (metric * 0.30)
        let fannedX = CGFloat(index) * (metric * 2.4)
        let x = collapsedX + (fannedX - collapsedX) * CGFloat(progress)

        // Folded crumbs read as a chevron stack: compact (icon-only), rotated
        // slightly, dimmed — but NEVER to zero so the tile is always legible.
        let dim = 0.45 + 0.55 * progress
        let tilt = (1 - progress) * Double(total - 1 - index) * -7.0
        let yLift: CGFloat = (1 - CGFloat(progress)) * CGFloat(total - 1 - index) * (metric * 0.06)

        CollapsingChevronCrumbsView_CCCrumbChip(
            crumb: crumb,
            metric: metric,
            isLeaf: false,
            compact: progress < 0.35,
            dim: dim
        )
        .rotationEffect(.degrees(tilt), anchor: .leading)
        .offset(x: x, y: -yLift)
        .scaleEffect(0.92 + 0.08 * progress, anchor: .leading)
    }
}

/// Tiny "+N" badge that sits on the folded chip while collapsed.
private struct CollapsingChevronCrumbsView_CCStackBadge: View {
    let count: Int
    let metric: CGFloat

    var body: some View {
        Text("+\(count)")
            .font(.system(size: metric * 0.3, weight: .heavy, design: .rounded))
            .foregroundStyle(CollapsingChevronCrumbsView_CCPalette.bg0)
            .padding(.horizontal, metric * 0.18)
            .padding(.vertical, metric * 0.05)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [CollapsingChevronCrumbsView_CCPalette.leaf0, CollapsingChevronCrumbsView_CCPalette.leaf1],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            )
    }
}

private enum CollapsingChevronCrumbsView_CCEase {
    static func inOut(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }

    /// A bouncy spring-ish ease used for the fan-open.
    static func spring(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        let s = 1 - pow(1 - c, 2)
        let overshoot = sin(c * .pi) * 0.12 * (1 - c)
        return min(s + overshoot, 1)
    }
}

// MARK: - INTERACTIVE PATH (tap-driven, real matchedGeometryEffect)

private struct CollapsingChevronCrumbsView_CCInteractiveTrail: View {
    let size: CGSize

    @Namespace private var ns
    @State private var expanded: Bool = false
    /// How many leading crumbs are folded behind the chevron chip.
    @State private var foldedCount: Int = 3

    private var metric: CGFloat { max(13, min(size.height, size.width * 0.5) * 0.30) }

    private var foldedCrumbs: [CollapsingChevronCrumbsView_CCCrumb] { Array(CollapsingChevronCrumbsView_CCData.all.prefix(foldedCount)) }
    private var leaf: CollapsingChevronCrumbsView_CCCrumb { CollapsingChevronCrumbsView_CCData.all[foldedCount] }

    var body: some View {
        ZStack {
            if expanded {
                expandedTrail
            } else {
                collapsedTrail
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: expanded)
    }

    // Collapsed: chevron stack chip + leaf.
    private var collapsedTrail: some View {
        HStack(spacing: metric * 0.22) {
            collapsedStack
                .contentShape(Rectangle())
                .onTapGesture { toggle() }
            CollapsingChevronCrumbsView_CCChevron(metric: metric, rotation: 0, opacity: 0.7)
            CollapsingChevronCrumbsView_CCCrumbChip(crumb: leaf, metric: metric, isLeaf: true)
                .matchedGeometryEffect(id: leaf.id, in: ns)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var collapsedStack: some View {
        ZStack(alignment: .leading) {
            ForEach(Array(foldedCrumbs.enumerated()), id: \.element.id) { idx, crumb in
                CollapsingChevronCrumbsView_CCCrumbChip(crumb: crumb, metric: metric, isLeaf: false, compact: true, dim: 0.5 + 0.12 * Double(idx))
                    .matchedGeometryEffect(id: crumb.id, in: ns)
                    .rotationEffect(.degrees(Double(foldedCrumbs.count - 1 - idx) * -7), anchor: .leading)
                    .offset(x: CGFloat(idx) * (metric * 0.30))
                    .zIndex(Double(idx))
            }
        }
        .overlay(alignment: .topTrailing) {
            CollapsingChevronCrumbsView_CCStackBadge(count: foldedCount, metric: metric)
                .offset(x: metric * 0.2, y: -metric * 0.3)
        }
        .frame(width: metric * 1.4 + CGFloat(max(0, foldedCount - 1)) * metric * 0.30, alignment: .leading)
    }

    // Expanded: every crumb inline, index-staggered via per-crumb delay.
    private var expandedTrail: some View {
        HStack(spacing: metric * 0.18) {
            ForEach(Array(CollapsingChevronCrumbsView_CCData.all.prefix(foldedCount + 1).enumerated()), id: \.element.id) { idx, crumb in
                let isLeaf = idx == foldedCount
                CollapsingChevronCrumbsView_CCCrumbChip(crumb: crumb, metric: metric, isLeaf: isLeaf)
                    .matchedGeometryEffect(id: crumb.id, in: ns)
                    .onTapGesture { pick(idx) }
                    .transition(.identity)
                if idx < foldedCount {
                    CollapsingChevronCrumbsView_CCChevron(metric: metric, rotation: 0, opacity: 0.6)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggle() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.66)) {
            expanded.toggle()
        }
    }

    /// Picking a crumb re-collapses with a staggered zip; if you pick an older
    /// crumb the trail shortens (you navigated back up the path).
    private func pick(_ idx: Int) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
            if idx < foldedCount {
                foldedCount = max(1, idx)
            }
            expanded = false
        }
    }
}
