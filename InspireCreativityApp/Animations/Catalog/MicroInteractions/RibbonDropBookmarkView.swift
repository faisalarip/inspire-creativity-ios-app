// catalog-id: mi-ribbon-drop-bookmark
import SwiftUI

/// Ribbon Drop Bookmark
///
/// A cloth ribbon unfurls downward from the top edge with a pendulum swing and a
/// swallowtail-notched bottom, settling with a gentle sway when saved.
///
/// - `demo == true`  : self-driving PhaseAnimator loop that toggles the saved state,
///                     dropping the ribbon with a pendulum swing, settling, then
///                     retracting — on a ~3.4s cycle so the tile always looks alive.
/// - `demo == false` : real interactive component. Tapping toggles `isSaved`, which
///                     triggers the same spring-driven drop-and-sway with a real
///                     pendulum kick that springs back to rest.
struct RibbonDropBookmarkView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                background(size: size)

                if demo {
                    demoLoop(size: size)
                } else {
                    interactive(size: size)
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Demo (self-driving)

    private func demoLoop(size: CGSize) -> some View {
        PhaseAnimator(RibbonDropBookmarkView_RibbonPhase.allCases) { phase in
            stage(
                size: size,
                progress: phase.progress,
                swing: phase.swing
            )
        } animation: { phase in
            switch phase {
            case .hidden:
                return .easeInOut(duration: 0.55)
            case .dropping:
                // Springy drop produces the pendulum overshoot + sway.
                return .spring(response: 0.5, dampingFraction: 0.55)
            case .settled:
                return .spring(response: 0.5, dampingFraction: 0.7)
            }
        }
    }

    // MARK: - Interactive

    private func interactive(size: CGSize) -> some View {
        RibbonDropBookmarkView_InteractiveRibbon(size: size) { progress, swing in
            stage(size: size, progress: progress, swing: swing)
        }
    }

    // MARK: - Shared stage

    private func stage(size: CGSize, progress: CGFloat, swing: CGFloat) -> some View {
        let metrics = RibbonDropBookmarkView_RibbonMetrics(size: size)
        return RibbonDropBookmarkView_RibbonPiece(metrics: metrics, progress: progress, swing: swing)
    }

    // MARK: - Backdrop (always visible — never a blank frame)

    private func background(size: CGSize) -> some View {
        let metrics = RibbonDropBookmarkView_RibbonMetrics(size: size)
        return ZStack {
            // Journal page.
            RoundedRectangle(cornerRadius: metrics.pageCorner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.97, blue: 0.94),
                            Color(red: 0.93, green: 0.91, blue: 0.86)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: metrics.pageCorner, style: .continuous)
                        .stroke(Color(red: 0.0, green: 0.0, blue: 0.0).opacity(0.06), lineWidth: 1)
                )
                .frame(width: metrics.pageWidth, height: metrics.pageHeight)
                .shadow(color: Color(red: 0.0, green: 0.0, blue: 0.0).opacity(0.12),
                        radius: metrics.pageWidth * 0.04, x: 0, y: metrics.pageWidth * 0.02)

            // Faint ruled lines for journal feel.
            RibbonDropBookmarkView_RuledLines(metrics: metrics)

            // Top rail the ribbon hangs from — a persistent visual anchor so the
            // retracted state still reads as "a bookmark slot", never empty.
            RibbonDropBookmarkView_TopRail(metrics: metrics)
        }
    }
}

// MARK: - Phases

private enum RibbonDropBookmarkView_RibbonPhase: CaseIterable {
    case hidden
    case dropping
    case settled

    /// How far the ribbon has unfurled (0 hidden ... 1 fully down).
    var progress: CGFloat {
        switch self {
        case .hidden:   return 0.0
        case .dropping: return 1.0
        case .settled:  return 1.0
        }
    }

    /// Initial pendulum swing (radians) injected at the moment of dropping; the
    /// spring resolves it back toward 0 producing the sway.
    var swing: CGFloat {
        switch self {
        case .hidden:   return 0.0
        case .dropping: return 0.16   // kicks to the side, then springs home
        case .settled:  return 0.0
        }
    }
}

// MARK: - Interactive wrapper

private struct RibbonDropBookmarkView_InteractiveRibbon<Content: View>: View {
    let size: CGSize
    let content: (CGFloat, CGFloat) -> Content

    @State private var isSaved: Bool = false
    @State private var swing: CGFloat = 0

    var body: some View {
        let progress: CGFloat = isSaved ? 1.0 : 0.0

        return content(progress, swing)
            // Spring on the saved transition drives the vertical drop overshoot.
            .animation(.spring(response: 0.5, dampingFraction: 0.55), value: isSaved)
            .contentShape(Rectangle())
            .onTapGesture {
                toggle()
            }
            .sensoryFeedback(.impact(weight: .light), trigger: isSaved)
            .overlay(alignment: .bottom) {
                hint
            }
    }

    private func toggle() {
        isSaved.toggle()
        // Kick the pendulum to one side, then spring it back to rest — this is
        // the named "sway". Dropping swings one way; retracting swings the other.
        swing = isSaved ? 0.16 : -0.12
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
            swing = 0
        }
    }

    private var hint: some View {
        Text(isSaved ? "Saved" : "Tap to save")
            .font(.system(size: max(9, size.width * 0.05), weight: .semibold, design: .rounded))
            .foregroundStyle(Color(red: 0.32, green: 0.28, blue: 0.24).opacity(0.7))
            .padding(.bottom, size.height * 0.05)
            .allowsHitTesting(false)
    }
}

// MARK: - Metrics

private struct RibbonDropBookmarkView_RibbonMetrics {
    let size: CGSize

    var pageWidth: CGFloat { size.width * 0.78 }
    var pageHeight: CGFloat { size.height * 0.86 }
    var pageCorner: CGFloat { min(pageWidth, pageHeight) * 0.06 }

    /// Ribbon geometry.
    var ribbonWidth: CGFloat { pageWidth * 0.2 }
    /// Full length of the ribbon when fully unfurled, measured from the top rail.
    var ribbonLength: CGFloat { pageHeight * 0.74 }
    /// Horizontal position (centre x) of the ribbon — tucked toward the right.
    var ribbonCenterX: CGFloat { size.width / 2 + pageWidth * 0.22 }
    /// The top attachment point (where the ribbon hangs from the rail).
    var topY: CGFloat { (size.height - pageHeight) / 2 }
    var railHeight: CGFloat { pageHeight * 0.05 }
    /// Depth of the swallowtail V notch at the bottom.
    var swallowtail: CGFloat { ribbonWidth * 0.55 }
}

// MARK: - Backdrop pieces

private struct RibbonDropBookmarkView_RuledLines: View {
    let metrics: RibbonDropBookmarkView_RibbonMetrics

    var body: some View {
        let count = 5
        let top = metrics.topY + metrics.pageHeight * 0.22
        let spacing = metrics.pageHeight * 0.13
        return ZStack {
            ForEach(0..<count, id: \.self) { i in
                Rectangle()
                    .fill(Color(red: 0.55, green: 0.5, blue: 0.42).opacity(0.18))
                    .frame(width: metrics.pageWidth * 0.78, height: 1)
                    .position(
                        x: metrics.size.width / 2,
                        y: top + CGFloat(i) * spacing
                    )
            }
        }
    }
}

private struct RibbonDropBookmarkView_TopRail: View {
    let metrics: RibbonDropBookmarkView_RibbonMetrics

    var body: some View {
        RoundedRectangle(cornerRadius: metrics.railHeight / 2, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.36, green: 0.30, blue: 0.27),
                        Color(red: 0.22, green: 0.18, blue: 0.16)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: metrics.pageWidth * 0.92, height: metrics.railHeight)
            .overlay(
                Capsule()
                    .fill(Color(red: 1.0, green: 1.0, blue: 1.0).opacity(0.22))
                    .frame(width: metrics.pageWidth * 0.86, height: metrics.railHeight * 0.28)
                    .offset(y: -metrics.railHeight * 0.2)
            )
            .position(x: metrics.size.width / 2, y: metrics.topY + metrics.railHeight / 2)
            .shadow(color: Color(red: 0.0, green: 0.0, blue: 0.0).opacity(0.18),
                    radius: 2, x: 0, y: 1)
    }
}

// MARK: - Ribbon piece

private struct RibbonDropBookmarkView_RibbonPiece: View {
    let metrics: RibbonDropBookmarkView_RibbonMetrics
    let progress: CGFloat   // 0 retracted ... 1 unfurled
    let swing: CGFloat      // pendulum angle in radians

    var body: some View {
        let p = clamp01(progress)
        let visibleLength = lengthForProgress(p)
        let angle = Angle(radians: Double(swing))

        ribbonBody(length: visibleLength)
            // Anchor the rotation at the TOP attachment point so it reads as a
            // hanging piece of cloth swinging like a pendulum, not a spinning bar.
            .rotationEffect(angle, anchor: .top)
            // Position the top edge at the rail; the body grows downward.
            .position(
                x: metrics.ribbonCenterX,
                y: railBottomY + visibleLength / 2
            )
            // Always keep at least the nub visible so no frame is blank.
            .opacity(1.0)
    }

    // The visible ribbon as a single shape (rectangle + swallowtail notch),
    // gradient-filled with a soft cloth sheen and edge shadow.
    private func ribbonBody(length: CGFloat) -> some View {
        let shape = RibbonDropBookmarkView_SwallowtailRibbon(
            cornerInset: metrics.ribbonWidth * 0.12,
            notchDepth: notchDepth(for: length)
        )
        return shape
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.82, green: 0.16, blue: 0.22),
                        Color(red: 0.66, green: 0.09, blue: 0.16),
                        Color(red: 0.78, green: 0.14, blue: 0.20)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(
                // Centre-line sheen for the folded-cloth highlight.
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color(red: 1.0, green: 1.0, blue: 1.0).opacity(0.28),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .blendMode(.screen)
            )
            .overlay(
                shape
                    .stroke(Color(red: 0.4, green: 0.04, blue: 0.08).opacity(0.4), lineWidth: 0.75)
            )
            .frame(width: metrics.ribbonWidth, height: max(length, 0.001))
            .shadow(color: Color(red: 0.3, green: 0.02, blue: 0.05).opacity(0.35),
                    radius: metrics.ribbonWidth * 0.18,
                    x: metrics.ribbonWidth * 0.12, y: length * 0.02)
    }

    // MARK: helpers

    private var railBottomY: CGFloat {
        metrics.topY + metrics.railHeight * 0.5
    }

    private func lengthForProgress(_ p: CGFloat) -> CGFloat {
        // Always show a small nub even when retracted so the slot reads as
        // occupied; full length at p == 1.
        let nub = metrics.railHeight * 1.1
        return nub + (metrics.ribbonLength - nub) * p
    }

    private func notchDepth(for length: CGFloat) -> CGFloat {
        // Notch only fully forms once enough ribbon has dropped.
        let full = metrics.swallowtail
        let denom = metrics.ribbonLength * 0.4
        guard denom > 0 else { return 0 }
        let ratio = clamp01((length - metrics.railHeight * 2) / denom)
        return full * ratio
    }

    private func clamp01(_ v: CGFloat) -> CGFloat {
        min(1, max(0, v))
    }
}

// MARK: - Swallowtail ribbon shape

/// A rectangle with a V notch cut up into its bottom edge (swallowtail), plus
/// gently inset top corners so the cloth reads as soft rather than a hard bar.
private struct RibbonDropBookmarkView_SwallowtailRibbon: Shape {
    var cornerInset: CGFloat
    var notchDepth: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let notch = min(notchDepth, h * 0.5)
        let inset = min(cornerInset, w * 0.4)

        // Start top-left (slightly inset for a soft shoulder).
        path.move(to: CGPoint(x: rect.minX + inset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + inset),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        // Right edge down to bottom-right.
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        // Up into the V notch centre.
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - notch))
        // Down to bottom-left.
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        // Left edge up to the soft top-left shoulder.
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + inset))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + inset, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}
