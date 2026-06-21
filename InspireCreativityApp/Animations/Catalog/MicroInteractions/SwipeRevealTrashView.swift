// catalog-id: mi-swipe-reveal-trash
import SwiftUI

// MARK: - Swipe-Reveal Trash
// Swiping a row leftward reveals a trash action whose lid lifts and bin mouth
// widens proportionally to the pull; released past threshold the row collapses
// inward as if swallowed, then resets. The bin itself is always visible so the
// tile is never blank.
struct SwipeRevealTrashView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if demo {
            SwipeRevealTrashView_DemoDriver(size: size)
        } else {
            SwipeRevealTrashView_InteractiveDriver(size: size)
        }
    }
}

// MARK: - SwipeRevealTrashView_Palette

private enum SwipeRevealTrashView_Palette {
    static let backdrop = Color(red: 0.078, green: 0.063, blue: 0.098)
    static let trayTop = Color(red: 0.745, green: 0.169, blue: 0.196)
    static let trayBottom = Color(red: 0.604, green: 0.106, blue: 0.137)
    static let binBody = Color(red: 0.918, green: 0.925, blue: 0.945)
    static let binShade = Color(red: 0.792, green: 0.808, blue: 0.847)
    static let binMouth = Color(red: 0.137, green: 0.110, blue: 0.157)
    static let lidTop = Color(red: 0.965, green: 0.969, blue: 0.984)
    static let lidEdge = Color(red: 0.808, green: 0.824, blue: 0.863)
    static let rowFill = Color(red: 0.188, green: 0.157, blue: 0.235)
    static let rowStroke = Color(red: 0.388, green: 0.349, blue: 0.475)
    static let rowText = Color(red: 0.918, green: 0.910, blue: 0.949)
    static let rowSubText = Color(red: 0.616, green: 0.596, blue: 0.690)
    static let avatar = Color(red: 0.498, green: 0.408, blue: 0.831)
}

// MARK: - Demo driver (self-running loop)

private struct SwipeRevealTrashView_DemoDriver: View {
    let size: CGSize

    enum Phase: CaseIterable {
        case closed, revealing, swallowing, reset
    }

    var body: some View {
        PhaseAnimator(Phase.allCases) { phase in
            SwipeRevealTrashView_SwipeStage(
                size: size,
                progress: progress(for: phase),
                rowScale: rowScale(for: phase),
                rowOpacity: rowOpacity(for: phase),
                showRow: true
            )
        } animation: { phase in
            switch phase {
            case .closed:     return .easeInOut(duration: 0.5)
            case .revealing:  return .easeInOut(duration: 0.9)
            case .swallowing: return .spring(response: 0.45, dampingFraction: 0.62)
            case .reset:      return .spring(response: 0.55, dampingFraction: 0.85)
            }
        }
    }

    // Reveal progress 0...1 (and slightly beyond at the swallow to feel forceful).
    private func progress(for phase: Phase) -> CGFloat {
        switch phase {
        case .closed:     return 0.0
        case .revealing:  return 0.82
        case .swallowing: return 1.0
        case .reset:      return 0.0
        }
    }

    private func rowScale(for phase: Phase) -> CGFloat {
        switch phase {
        case .swallowing: return 0.0
        default:          return 1.0
        }
    }

    private func rowOpacity(for phase: Phase) -> Double {
        switch phase {
        case .swallowing: return 0.0
        case .reset:      return 1.0
        default:          return 1.0
        }
    }
}

// MARK: - Interactive driver (real DragGesture)

private struct SwipeRevealTrashView_InteractiveDriver: View {
    let size: CGSize

    @State private var progress: CGFloat = 0      // committed reveal 0...1
    @State private var dragProgress: CGFloat = 0  // live drag contribution
    @State private var rowScale: CGFloat = 1
    @State private var rowOpacity: Double = 1
    @State private var showRow: Bool = true
    @State private var crossedThreshold: Bool = false
    @State private var armedHaptic: Bool = false
    @State private var deletedHaptic: Bool = false

    private let threshold: CGFloat = 0.78

    var body: some View {
        SwipeRevealTrashView_SwipeStage(
            size: size,
            progress: effectiveProgress,
            rowScale: rowScale,
            rowOpacity: rowOpacity,
            showRow: showRow
        )
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .sensoryFeedback(.impact(weight: .medium), trigger: armedHaptic)
        .sensoryFeedback(.success, trigger: deletedHaptic)
    }

    private var effectiveProgress: CGFloat {
        min(1, max(0, progress + dragProgress))
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard showRow else { return }
                // Horizontal-dominant left swipe drives the reveal.
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let revealDistance = max(size.width * 0.55, 80)
                let pull = max(0, -value.translation.width)
                let p = min(1.15, pull / revealDistance)
                dragProgress = p
                handleThreshold(for: effectiveProgress)
            }
            .onEnded { value in
                let final = effectiveProgress
                dragProgress = 0
                if final >= threshold {
                    swallow()
                } else {
                    springClosed()
                }
            }
    }

    private func handleThreshold(for value: CGFloat) {
        if value >= threshold, !crossedThreshold {
            crossedThreshold = true
            armedHaptic.toggle()
        } else if value < threshold, crossedThreshold {
            crossedThreshold = false
        }
    }

    private func swallow() {
        deletedHaptic.toggle()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.6)) {
            progress = 1
            rowScale = 0
            rowOpacity = 0
        }
        // Reset after the gulp so the detail view is never permanently empty.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            showRow = false
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                progress = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                rowScale = 1
                showRow = true
                withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                    rowOpacity = 1
                }
            }
        }
    }

    private func springClosed() {
        crossedThreshold = false
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            progress = 0
        }
    }
}

// MARK: - Composited stage (shared by demo + interactive)

private struct SwipeRevealTrashView_SwipeStage: View {
    let size: CGSize
    let progress: CGFloat
    let rowScale: CGFloat
    let rowOpacity: Double
    let showRow: Bool

    var body: some View {
        let metrics = SwipeRevealTrashView_StageMetrics(size: size)
        ZStack {
            SwipeRevealTrashView_Palette.backdrop
            // Red action tray (always present behind the row).
            actionTray(metrics)
            // The trash bin sits inside the tray; it is the persistent element.
            SwipeRevealTrashView_TrashBin(progress: progress, metrics: metrics)
                .frame(width: metrics.binWidth, height: metrics.trayHeight)
                .position(x: metrics.binCenterX, y: metrics.rowCenterY)
            // The row that slides away and gets gulped.
            if showRow {
                SwipeRevealTrashView_RowContent(metrics: metrics)
                    .frame(width: metrics.rowWidth, height: metrics.rowHeight * rowScale)
                    .opacity(rowOpacity)
                    .offset(x: -progress * metrics.revealOffset)
                    .position(x: metrics.rowWidth / 2, y: metrics.rowCenterY)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private func actionTray(_ m: SwipeRevealTrashView_StageMetrics) -> some View {
        RoundedRectangle(cornerRadius: m.corner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [SwipeRevealTrashView_Palette.trayTop, SwipeRevealTrashView_Palette.trayBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: m.rowWidth, height: m.rowHeight)
            .position(x: m.rowWidth / 2, y: m.rowCenterY)
    }
}

// MARK: - Layout metrics derived from tile size

private struct SwipeRevealTrashView_StageMetrics {
    let size: CGSize
    let rowWidth: CGFloat
    let rowHeight: CGFloat
    let rowCenterY: CGFloat
    let corner: CGFloat
    let trayHeight: CGFloat
    let binWidth: CGFloat
    let binCenterX: CGFloat
    let revealOffset: CGFloat

    init(size: CGSize) {
        self.size = size
        let w = size.width
        let h = size.height
        // Row fills most of the width, centered vertically with breathing room.
        self.rowWidth = w
        self.rowHeight = min(h * 0.62, w * 0.7)
        self.rowCenterY = h / 2
        self.corner = min(rowHeight, rowWidth) * 0.16
        self.trayHeight = rowHeight
        // Bin scaled to the tray height so it always reads as a bin at 120pt.
        self.binWidth = min(rowHeight * 0.62, w * 0.34)
        self.binCenterX = w - binWidth * 0.5 - w * 0.07
        // How far the row slides left when fully revealed.
        self.revealOffset = binWidth * 1.55
    }
}

// MARK: - Row content

private struct SwipeRevealTrashView_RowContent: View {
    let metrics: SwipeRevealTrashView_StageMetrics

    var body: some View {
        let m = metrics
        let pad = m.rowHeight * 0.18
        HStack(spacing: m.rowHeight * 0.16) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [SwipeRevealTrashView_Palette.avatar, SwipeRevealTrashView_Palette.avatar.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Image(systemName: "envelope.fill")
                        .font(.system(size: m.rowHeight * 0.2, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                )
                .frame(width: m.rowHeight * 0.46, height: m.rowHeight * 0.46)
            VStack(alignment: .leading, spacing: m.rowHeight * 0.1) {
                RoundedRectangle(cornerRadius: m.rowHeight * 0.06, style: .continuous)
                    .fill(SwipeRevealTrashView_Palette.rowText)
                    .frame(width: m.rowWidth * 0.32, height: m.rowHeight * 0.14)
                RoundedRectangle(cornerRadius: m.rowHeight * 0.05, style: .continuous)
                    .fill(SwipeRevealTrashView_Palette.rowSubText)
                    .frame(width: m.rowWidth * 0.46, height: m.rowHeight * 0.1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, pad)
        .frame(width: m.rowWidth, height: m.rowHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: m.corner, style: .continuous)
                .fill(SwipeRevealTrashView_Palette.rowFill)
                .overlay(
                    RoundedRectangle(cornerRadius: m.corner, style: .continuous)
                        .strokeBorder(SwipeRevealTrashView_Palette.rowStroke.opacity(0.6), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: m.corner, style: .continuous))
    }
}

// MARK: - Trash bin (body + widening mouth + lifting lid)

private struct SwipeRevealTrashView_TrashBin: View {
    let progress: CGFloat
    let metrics: SwipeRevealTrashView_StageMetrics

    var body: some View {
        GeometryReader { geo in
            bin(in: geo.size)
        }
    }

    private func bin(in size: CGSize) -> some View {
        let w = size.width
        let h = size.height
        // Bin body occupies the lower ~64% of the available height.
        let bodyHeight = h * 0.62
        let bodyWidth = w * 0.74
        let bodyTop = h * 0.34
        let bodyX = (w - bodyWidth) / 2

        // Mouth widens with progress.
        let mouthWidth = bodyWidth * (0.5 + 0.42 * progress)
        let mouthHeight = bodyHeight * 0.2
        let mouthX = (w - mouthWidth) / 2
        let mouthY = bodyTop - mouthHeight * 0.35

        // Lid lifts (rotates) about its right hinge as progress rises.
        let lidWidth = bodyWidth * 1.06
        let lidHeight = h * 0.12
        let lidAngle = Angle(degrees: -Double(progress) * 62)

        return ZStack(alignment: .topLeading) {
            // Body
            binBody(width: bodyWidth, height: bodyHeight)
                .offset(x: bodyX, y: bodyTop)

            // Dark mouth opening
            Capsule(style: .continuous)
                .fill(SwipeRevealTrashView_Palette.binMouth)
                .frame(width: mouthWidth, height: mouthHeight)
                .offset(x: mouthX, y: mouthY)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.black.opacity(0.28), lineWidth: 1)
                        .frame(width: mouthWidth, height: mouthHeight)
                        .offset(x: mouthX, y: mouthY)
                )

            // Lid (a rounded slab) hinged at its trailing corner.
            lid(width: lidWidth, height: lidHeight)
                .rotationEffect(lidAngle, anchor: .bottomTrailing)
                .frame(width: lidWidth, height: lidHeight, alignment: .bottomTrailing)
                .offset(x: (w - lidWidth) / 2, y: bodyTop - lidHeight * 0.78)

            // Trash glyph centered on the body, fades as the mouth opens.
            Image(systemName: "trash.fill")
                .font(.system(size: bodyHeight * 0.34, weight: .semibold))
                .foregroundStyle(SwipeRevealTrashView_Palette.trayBottom.opacity(0.75))
                .opacity(Double(0.85 - 0.85 * progress))
                .frame(width: bodyWidth, height: bodyHeight)
                .offset(x: bodyX, y: bodyTop + bodyHeight * 0.06)
        }
        .frame(width: w, height: h)
    }

    private func binBody(width: CGFloat, height: CGFloat) -> some View {
        SwipeRevealTrashView_BinBodyShape()
            .fill(
                LinearGradient(
                    colors: [SwipeRevealTrashView_Palette.binBody, SwipeRevealTrashView_Palette.binShade],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                SwipeRevealTrashView_BinBodyShape()
                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
            )
            .overlay(ribbing(width: width, height: height))
            .frame(width: width, height: height)
    }

    private func ribbing(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: width * 0.12) {
            ForEach(0..<3, id: \.self) { _ in
                Capsule()
                    .fill(SwipeRevealTrashView_Palette.binShade.opacity(0.7))
                    .frame(width: width * 0.05)
            }
        }
        .frame(width: width * 0.6, height: height * 0.62)
        .padding(.top, height * 0.18)
    }

    private func lid(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height * 0.42, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [SwipeRevealTrashView_Palette.lidTop, SwipeRevealTrashView_Palette.lidEdge],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: height * 0.42, style: .continuous)
                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
            )
            .overlay(
                // Small handle nub on the lid.
                Capsule()
                    .fill(SwipeRevealTrashView_Palette.lidEdge)
                    .frame(width: width * 0.22, height: height * 0.42)
                    .offset(y: -height * 0.5)
            )
    }
}

// MARK: - Bin body shape (tapered trapezoid)

private struct SwipeRevealTrashView_BinBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let inset = rect.width * 0.1
        let r = rect.width * 0.14
        let topLeft = CGPoint(x: rect.minX, y: rect.minY)
        let topRight = CGPoint(x: rect.maxX, y: rect.minY)
        let botLeft = CGPoint(x: rect.minX + inset, y: rect.maxY)
        let botRight = CGPoint(x: rect.maxX - inset, y: rect.maxY)

        p.move(to: topLeft)
        p.addLine(to: topRight)
        p.addLine(to: CGPoint(x: botRight.x + r, y: botRight.y - r))
        p.addQuadCurve(
            to: CGPoint(x: botRight.x - r, y: botRight.y),
            control: CGPoint(x: botRight.x, y: botRight.y)
        )
        p.addLine(to: CGPoint(x: botLeft.x + r, y: botLeft.y))
        p.addQuadCurve(
            to: CGPoint(x: botLeft.x - r, y: botLeft.y - r),
            control: CGPoint(x: botLeft.x, y: botLeft.y)
        )
        p.closeSubpath()
        return p
    }
}
