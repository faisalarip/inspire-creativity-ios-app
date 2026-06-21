// catalog-id: tr-page-peel
import SwiftUI

// MARK: - Page Peel
// A corner-anchored faked page curl. The bottom-right corner lifts and rotates
// away via a single rotation3DEffect about the anti-diagonal axis, anchored at
// the opposite (top-leading) corner that stays pinned. A LinearGradient shadow
// gutter widens along the fold and a tinted back-of-page shows through, while
// the next page is revealed underneath.
//
// demo == true  -> a TimelineView self-drives the curl progress 0 -> 1 -> 0.
// demo == false -> a DragGesture on the lifted corner maps finger distance to
//                  the curl progress; release past a threshold springs the page
//                  fully off (advancing to the next page), else springs flat.

struct PagePeelView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { proxy in
            content(in: proxy.size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if demo {
            PagePeelView_PagePeelDemo(size: size)
        } else {
            PagePeelView_PagePeelInteractive(size: size)
        }
    }
}

// MARK: - Shared palette / content

private enum PagePeelView_PeelPalette {
    static let paperTop = Color(red: 0.97, green: 0.96, blue: 0.93)
    static let paperBottom = Color(red: 0.93, green: 0.91, blue: 0.86)
    static let backTintTop = Color(red: 0.82, green: 0.80, blue: 0.74)
    static let backTintBottom = Color(red: 0.70, green: 0.67, blue: 0.60)
    static let ink = Color(red: 0.16, green: 0.17, blue: 0.22)
    static let accentA = Color(red: 0.20, green: 0.52, blue: 0.96)
    static let accentB = Color(red: 0.55, green: 0.30, blue: 0.92)

    static func pageTint(for index: Int) -> Color {
        let palette: [Color] = [
            Color(red: 0.97, green: 0.96, blue: 0.93),
            Color(red: 0.95, green: 0.93, blue: 0.97),
            Color(red: 0.93, green: 0.97, blue: 0.95),
            Color(red: 0.97, green: 0.95, blue: 0.92)
        ]
        return palette[((index % palette.count) + palette.count) % palette.count]
    }
}

// MARK: - A single page's face content

private struct PagePeelView_PageFace: View {
    let index: Int
    let size: CGSize

    private var corner: CGFloat { min(size.width, size.height) * 0.06 }
    private var pad: CGFloat { max(8.0, min(size.width, size.height) * 0.1) }
    private var numberSize: CGFloat { min(size.width, size.height) * 0.42 }
    private var lineColor: Color {
        Color(red: 0.16, green: 0.17, blue: 0.22).opacity(0.10)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [PagePeelView_PeelPalette.pageTint(for: index), PagePeelView_PeelPalette.paperBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            ruledLines

            pageNumber
        }
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(PagePeelView_PeelPalette.ink.opacity(0.08), lineWidth: 1)
        )
    }

    private var ruledLines: some View {
        VStack(spacing: max(6.0, size.height * 0.075)) {
            ForEach(0..<7, id: \.self) { _ in
                Capsule().fill(lineColor).frame(height: 2)
            }
        }
        .padding(.horizontal, pad)
        .padding(.vertical, pad * 0.6)
    }

    private var pageNumber: some View {
        Text("\(index + 1)")
            .font(.system(size: numberSize, weight: .heavy, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [PagePeelView_PeelPalette.accentA, PagePeelView_PeelPalette.accentB],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .minimumScaleFactor(0.3)
            .opacity(0.92)
    }
}

// MARK: - The peeling top page (front + tinted back share ONE rotation)

private struct PagePeelView_PeelingPage: View {
    let frontIndex: Int
    let progress: CGFloat        // 0 = flat, 1 = folded fully back
    let size: CGSize

    // The lifted (bottom-right) corner rotates about the anti-diagonal axis,
    // pinned at the opposite top-leading corner. Stop short of 180 so the back
    // stays visible and the page never flattens perfectly onto the next one.
    private var angle: Double { Double(progress) * 158.0 }
    private var corner: CGFloat { min(size.width, size.height) * 0.06 }

    // Past 90deg the front is hidden and the tinted back faces us. Because the
    // back is a flat gradient, the mirroring rotation3DEffect applies is invisible,
    // so we avoid any counter-rotation.
    private var showBack: Bool { angle >= 90.0 }

    var body: some View {
        ZStack {
            PagePeelView_PageFace(index: frontIndex, size: size)
                .opacity(showBack ? 0 : 1)

            backFace
                .opacity(showBack ? 1 : 0)
        }
        .frame(width: size.width, height: size.height)
        // ASSUMPTION: positive angle lifts the bottom-right corner toward the
        // viewer. If it folds the wrong way on device, negate `angle` or flip
        // the axis signs — geometry is otherwise correct by construction.
        .rotation3DEffect(
            .degrees(angle),
            axis: (x: 1.0, y: -1.0, z: 0.0),
            anchor: .topLeading,
            perspective: 0.55
        )
        // Soft self-shadow that deepens as the page lifts, grounding the curl.
        .shadow(
            color: Color.black.opacity(0.28 * Double(progress)),
            radius: 14 * progress,
            x: -8 * progress,
            y: 8 * progress
        )
    }

    private var backFace: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [PagePeelView_PeelPalette.backTintTop, PagePeelView_PeelPalette.backTintBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(curlSheen)
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(PagePeelView_PeelPalette.ink.opacity(0.12), lineWidth: 1)
            )
    }

    // A bright band running along the fold crease sells the paper's curved back.
    private var curlSheen: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.0),
                Color.white.opacity(0.35),
                Color.white.opacity(0.0)
            ],
            startPoint: .topTrailing,
            endPoint: .bottomLeading
        )
        .blendMode(.softLight)
    }
}

// MARK: - Shadow gutter cast on the next page along the fold

private struct PagePeelView_ShadowGutter: View {
    let progress: CGFloat
    let size: CGSize

    private var corner: CGFloat { min(size.width, size.height) * 0.06 }

    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.0),
                        Color.black.opacity(0.30 * Double(progress)),
                        Color.black.opacity(0.0)
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
            )
            // The gutter widens as the fold opens.
            .scaleEffect(x: 0.4 + 0.9 * progress, y: 0.4 + 0.9 * progress, anchor: .bottomTrailing)
            .opacity(Double(min(1.0, progress * 1.6)))
            .allowsHitTesting(false)
    }
}

// MARK: - Composed peel stack (shared by demo + interactive)

private struct PagePeelView_PeelStack: View {
    let topIndex: Int
    let progress: CGFloat
    let size: CGSize

    var body: some View {
        ZStack {
            // Bottom: the next page, always fully rendered so the edge-on
            // mid-frame never goes blank.
            PagePeelView_PageFace(index: topIndex + 1, size: size)

            // Middle: the fold's cast shadow on the next page.
            PagePeelView_ShadowGutter(progress: progress, size: size)

            // Top: the peeling page itself.
            PagePeelView_PeelingPage(frontIndex: topIndex, progress: progress, size: size)
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - Demo (self-driving)

private struct PagePeelView_PagePeelDemo: View {
    let size: CGSize

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            PagePeelView_PeelStack(topIndex: 0, progress: demoProgress(t), size: insetSize)
                .padding(insetPadding)
        }
        .frame(width: size.width, height: size.height)
    }

    private var insetPadding: CGFloat { min(size.width, size.height) * 0.08 }
    private var insetSize: CGSize {
        CGSize(
            width: max(1, size.width - insetPadding * 2),
            height: max(1, size.height - insetPadding * 2)
        )
    }

    // ~3.4s loop: ease 0 -> 1 -> 0 with a brief hold at each end so the reveal reads.
    private func demoProgress(_ time: TimeInterval) -> CGFloat {
        let period: Double = 3.4
        let phase = (time.truncatingRemainder(dividingBy: period)) / period // 0..1
        let triangle: Double = phase < 0.5 ? (phase * 2.0) : (2.0 - phase * 2.0)
        let eased = easeInOut(triangle)
        return CGFloat(eased)
    }

    private func easeInOut(_ x: Double) -> Double {
        let c = min(max(x, 0.0), 1.0)
        return c * c * (3.0 - 2.0 * c)
    }
}

// MARK: - Interactive (drag the corner)

private struct PagePeelView_PagePeelInteractive: View {
    let size: CGSize

    @State private var topIndex: Int = 0
    @State private var progress: CGFloat = 0
    @State private var dragging: Bool = false

    var body: some View {
        PagePeelView_PeelStack(topIndex: topIndex, progress: progress, size: insetSize)
            .padding(insetPadding)
            .contentShape(Rectangle())
            .gesture(peelGesture)
            .animation(dragging ? nil : .spring(response: 0.5, dampingFraction: 0.72), value: progress)
            .frame(width: size.width, height: size.height)
    }

    private var insetPadding: CGFloat { min(size.width, size.height) * 0.08 }
    private var insetSize: CGSize {
        CGSize(
            width: max(1, size.width - insetPadding * 2),
            height: max(1, size.height - insetPadding * 2)
        )
    }

    // The lifted corner is the bottom-right of the inset page.
    private var liftedCorner: CGPoint {
        CGPoint(x: size.width - insetPadding, y: size.height - insetPadding)
    }

    private var diagonalLength: CGFloat {
        let w = insetSize.width
        let h = insetSize.height
        return max(1.0, sqrt(w * w + h * h))
    }

    private var peelGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                dragging = true
                progress = progressFor(location: value.location)
            }
            .onEnded { value in
                dragging = false
                let final = progressFor(location: value.location)
                if final > 0.5 {
                    // Commit: peel fully off, then swap in the next page flat.
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                        progress = 1.0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                        // Swap the revealed page in instantly: suppress the
                        // `.animation(value: progress)` so the fresh page does
                        // not peel down from folded — it appears flat.
                        var txn = Transaction()
                        txn.disablesAnimations = true
                        withTransaction(txn) {
                            topIndex += 1
                            progress = 0.0
                        }
                    }
                } else {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                        progress = 0.0
                    }
                }
            }
    }

    // Distance the finger has pulled the lifted corner toward the hinge maps to
    // curl progress, clamped to 0...1.
    private func progressFor(location: CGPoint) -> CGFloat {
        let dx = liftedCorner.x - location.x
        let dy = liftedCorner.y - location.y
        let pulled = sqrt(dx * dx + dy * dy)
        let raw = pulled / diagonalLength
        return min(max(raw, 0.0), 1.0)
    }
}
