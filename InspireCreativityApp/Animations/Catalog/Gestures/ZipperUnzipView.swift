// catalog-id: ges-zipper-unzip
import SwiftUI

// MARK: - Zipper Unseal
// Drag the pull head downward and interlocking teeth disengage one pair at a
// time right at the moving front, splitting a sealed fabric panel open to
// reveal the content beneath with a faint cloth flex.

struct ZipperUnzipView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            if demo {
                ZipperUnzipView_DemoDriver(size: geo.size)
            } else {
                ZipperUnzipView_InteractiveZipper(size: geo.size)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Tunables

private enum ZipperUnzipView_Zip {
    static let toothCount: Int = 24
    // Window over which a tooth transitions from interlocked -> splayed,
    // measured in normalized track units. ~1.5x tooth spacing keeps the
    // disengagement reading as a traveling front rather than all-at-once.
    static let window: CGFloat = 0.07
}

// MARK: - Demo driver (self-running, no touch)

private struct ZipperUnzipView_DemoDriver: View {
    let size: CGSize

    var body: some View {
        TimelineView(.animation) { context in
            let front = Self.frontFromTime(context.date)
            ZipperUnzipView_ZipperBody(front: front, size: size, showHint: true)
        }
    }

    // Smoothed triangle wave on a ~3.4s loop with a short dwell at each end
    // so the sealed and fully-open states are both legible.
    private static func frontFromTime(_ date: Date) -> CGFloat {
        let period: Double = 3.4
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
        // Triangle 0->1->0
        let tri: Double = t < 0.5 ? (t * 2.0) : (2.0 - t * 2.0)
        // Dwell + ease: smoothstep maps a slightly clamped range, so the ends
        // hold briefly and the middle travels smoothly.
        let clamped = min(max((tri - 0.06) / 0.88, 0.0), 1.0)
        let eased = clamped * clamped * (3.0 - 2.0 * clamped)
        return CGFloat(eased)
    }
}

// MARK: - Interactive zipper (real component)

private struct ZipperUnzipView_InteractiveZipper: View {
    let size: CGSize
    @State private var front: CGFloat = 0
    @State private var dragging = false

    private var teethPassed: Int { Int((front * CGFloat(ZipperUnzipView_Zip.toothCount)).rounded(.down)) }

    var body: some View {
        ZipperUnzipView_ZipperBody(front: front, size: size, showHint: front > 0.04)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .sensoryFeedback(.selection, trigger: teethPassed)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                dragging = true
                let h = max(size.height, 1)
                let raw = value.location.y / h
                front = min(max(raw, 0), 1)
            }
            .onEnded { _ in
                dragging = false
                // Settle: spring to whichever end is closer.
                let target: CGFloat = front > 0.5 ? 1 : 0
                withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                    front = target
                }
            }
    }
}

// MARK: - Shared zipper body

private struct ZipperUnzipView_ZipperBody: View {
    let front: CGFloat        // 0 = sealed at top, 1 = fully open
    let size: CGSize
    var showHint: Bool = false

    private var trackWidth: CGFloat { min(size.width, size.height) * 0.10 }
    private var contentInset: CGFloat { min(size.width, size.height) * 0.12 }

    var body: some View {
        ZStack {
            revealedContent
            panels
            teeth
            pullHead
        }
    }

    // MARK: Content beneath the panels

    private var revealedContent: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.20, green: 0.62, blue: 0.86),
                        Color(red: 0.36, green: 0.30, blue: 0.78)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .top) {
                hintLabel
                    .opacity(showHint ? Double(min(front * 1.6, 1.0)) : 0)
                    .padding(.top, size.height * 0.18)
            }
            .padding(contentInset)
    }

    private var hintLabel: some View {
        VStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: min(size.width, size.height) * 0.16, weight: .semibold))
            Text("UNSEALED")
                .font(.system(size: min(size.width, size.height) * 0.07,
                               weight: .heavy, design: .rounded))
                .tracking(2)
        }
        .foregroundStyle(.white.opacity(0.92))
    }

    // MARK: Fabric panels

    private var panels: some View {
        let gap = maxGap * eased(front)
        return ZStack {
            ZipperUnzipView_FabricPanel(front: front, side: .left)
                .fill(panelGradient)
                .overlay(panelSeamShade(side: .left))
            ZipperUnzipView_FabricPanel(front: front, side: .right)
                .fill(panelGradient)
                .overlay(panelSeamShade(side: .right))
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.28), radius: 6, x: 0, y: 2)
        .accessibilityHidden(true)
        .environment(\.zipGap, gap)
    }

    private var maxGap: CGFloat { size.width * 0.34 }

    private var panelGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.16, green: 0.17, blue: 0.22),
                Color(red: 0.10, green: 0.11, blue: 0.15)
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    private func panelSeamShade(side: ZipperUnzipView_PanelSide) -> some View {
        // A soft highlight along the inner (seam) edge to suggest folded cloth.
        ZipperUnzipView_FabricPanel(front: front, side: side)
            .stroke(
                LinearGradient(
                    colors: [.white.opacity(0.10), .clear],
                    startPoint: side == .left ? .trailing : .leading,
                    endPoint: side == .left ? .leading : .trailing
                ),
                lineWidth: 2
            )
            .blur(radius: 1)
    }

    // MARK: Teeth

    private var teeth: some View {
        let centerX = size.width / 2
        let topY = contentInset * 0.6
        let bottomY = size.height - contentInset * 0.6
        let span = max(bottomY - topY, 1)
        return ZStack {
            ForEach(0..<ZipperUnzipView_Zip.toothCount, id: \.self) { index in
                let p = CGFloat(index) / CGFloat(max(ZipperUnzipView_Zip.toothCount - 1, 1))
                ZipperUnzipView_ToothPair(
                    openness: openness(for: p),
                    width: trackWidth,
                    parity: index % 2 == 0
                )
                .position(x: centerX, y: topY + p * span)
            }
        }
    }

    // openness: 0 = interlocked at center, 1 = splayed apart.
    // Tooth above the front (p < front) opens; below stays sealed.
    private func openness(for p: CGFloat) -> CGFloat {
        let x = (front - p) / ZipperUnzipView_Zip.window
        return smoothstep(x)
    }

    // MARK: Pull head

    private var pullHead: some View {
        let centerX = size.width / 2
        let topY = contentInset * 0.6
        let bottomY = size.height - contentInset * 0.6
        let y = topY + front * (bottomY - topY)
        let d = trackWidth * 1.9
        return ZStack {
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.90, green: 0.91, blue: 0.95),
                            Color(red: 0.62, green: 0.64, blue: 0.70)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: d, height: d * 1.15)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(.white.opacity(0.5), lineWidth: 1)
                )
            // Pull tab hanging below the slider.
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(red: 0.74, green: 0.76, blue: 0.82))
                .frame(width: d * 0.34, height: d * 0.7)
                .offset(y: d * 0.85)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
        .position(x: centerX, y: y)
    }

    // MARK: Easing helpers

    private func eased(_ v: CGFloat) -> CGFloat { smoothstep(v) }

    private func smoothstep(_ x: CGFloat) -> CGFloat {
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }
}

// MARK: - Tooth pair

private struct ZipperUnzipView_ToothPair: View {
    let openness: CGFloat   // 0 interlocked .. 1 splayed
    let width: CGFloat
    let parity: Bool

    var body: some View {
        let toothW = width * 0.92
        let toothH = width * 0.62
        let splay = width * 1.4 * openness
        let rot = Double(openness) * (parity ? 26 : 22)
        HStack(spacing: 0) {
            singleTooth(toothW, toothH)
                .rotationEffect(.degrees(-rot), anchor: .trailing)
                .offset(x: -splay)
            singleTooth(toothW, toothH)
                .rotationEffect(.degrees(rot), anchor: .leading)
                .offset(x: splay)
        }
    }

    private func singleTooth(_ w: CGFloat, _ h: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: h * 0.32, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.86, green: 0.87, blue: 0.92),
                        Color(red: 0.58, green: 0.60, blue: 0.67)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .frame(width: w, height: h)
            .overlay(
                RoundedRectangle(cornerRadius: h * 0.32, style: .continuous)
                    .stroke(.black.opacity(0.22), lineWidth: 0.5)
            )
    }
}

// MARK: - Fabric panel shape

private enum ZipperUnzipView_PanelSide { case left, right }

private struct ZipperUnzipView_FabricPanel: Shape, @preconcurrency Animatable {
    var front: CGFloat
    let side: ZipperUnzipView_PanelSide

    var animatableData: CGFloat {
        get { front }
        set { front = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let gap = rect.width * 0.34 * smooth(front)
        let centerX = rect.midX
        let inset: CGFloat = rect.width * 0.06
        let topY = rect.minY + inset
        let botY = rect.maxY - inset
        // Inner seam edge: gathers wider toward the top (where it's open),
        // tapers to the center at the unzip front for a cloth-flex curve.
        var path = Path()
        if side == .left {
            let outer = rect.minX + inset
            path.move(to: CGPoint(x: outer, y: topY))
            // top inner corner pulled left by the gap
            path.addLine(to: CGPoint(x: centerX - gap, y: topY))
            // flex curve down toward the sealed center
            path.addQuadCurve(
                to: CGPoint(x: centerX, y: botY),
                control: CGPoint(x: centerX - gap * 0.55, y: rect.midY)
            )
            path.addLine(to: CGPoint(x: outer, y: botY))
            path.closeSubpath()
        } else {
            let outer = rect.maxX - inset
            path.move(to: CGPoint(x: outer, y: topY))
            path.addLine(to: CGPoint(x: centerX + gap, y: topY))
            path.addQuadCurve(
                to: CGPoint(x: centerX, y: botY),
                control: CGPoint(x: centerX + gap * 0.55, y: rect.midY)
            )
            path.addLine(to: CGPoint(x: outer, y: botY))
            path.closeSubpath()
        }
        return path
    }

    private func smooth(_ x: CGFloat) -> CGFloat {
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }
}

// MARK: - Environment passthrough (kept lightweight)

private struct ZipperUnzipView_ZipGapKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

private extension EnvironmentValues {
    var zipGap: CGFloat {
        get { self[ZipperUnzipView_ZipGapKey.self] }
        set { self[ZipperUnzipView_ZipGapKey.self] = newValue }
    }
}
