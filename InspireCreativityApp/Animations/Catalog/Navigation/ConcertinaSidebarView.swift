// catalog-id: nav-concertina-sidebar
import SwiftUI

// MARK: - Concertina Sidebar
// Sidebar rows reveal as an accordion bellows: each row unfolds from a flattened
// sliver with a staggered spring (top-to-bottom), and collapses by squeezing back
// into a visible stack of thin slivers. A faint rotation3DEffect adds the pleat
// catching light.
//
//  - demo == true  : a self-driving TimelineView(.animation) breathes the panel
//                    open -> hold -> closed -> hold on a ~4s loop. Collapsed rows
//                    stay as a visible stack (never blank).
//  - demo == false : a real tappable menu button toggles `open` with a staggered
//                    per-row spring.

struct ConcertinaSidebarView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            ConcertinaSidebarView_ConcertinaContent(demo: demo, size: geo.size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // Shared palette (single source of truth referenced from every subview).
    static let ink = Color(red: 0.92, green: 0.94, blue: 0.97)
    static let accent = Color(red: 0.36, green: 0.78, blue: 0.98)
}

// MARK: - Content

private struct ConcertinaSidebarView_ConcertinaContent: View {
    let demo: Bool
    let size: CGSize

    @State private var open: Bool = true

    // Menu rows. Kept short so the panel reads in a 120pt tile.
    private let rows: [ConcertinaSidebarView_SidebarRowModel] = [
        ConcertinaSidebarView_SidebarRowModel(symbol: "square.grid.2x2.fill", title: "Dashboard"),
        ConcertinaSidebarView_SidebarRowModel(symbol: "tray.full.fill",       title: "Inbox"),
        ConcertinaSidebarView_SidebarRowModel(symbol: "chart.bar.fill",       title: "Insights"),
        ConcertinaSidebarView_SidebarRowModel(symbol: "person.2.fill",        title: "Team"),
        ConcertinaSidebarView_SidebarRowModel(symbol: "gearshape.fill",       title: "Settings")
    ]

    var body: some View {
        if demo {
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                panel(globalProgress: loopProgress(at: t))
            }
        } else {
            panel(globalProgress: open ? 1.0 : 0.0)
        }
    }

    // MARK: Layout

    private func panel(globalProgress: Double) -> some View {
        let metrics = ConcertinaSidebarView_PanelMetrics(size: size, rowCount: rows.count)
        return VStack(spacing: 0) {
            header(metrics: metrics)
            rowStack(globalProgress: globalProgress, metrics: metrics)
        }
        .padding(metrics.outerPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(panelBackground(metrics: metrics))
    }

    private func header(metrics: ConcertinaSidebarView_PanelMetrics) -> some View {
        HStack(spacing: metrics.headerSpacing) {
            menuButton(metrics: metrics)
            if metrics.showsHeaderTitle {
                Text("Menu")
                    .font(.system(size: metrics.titleFont, weight: .semibold, design: .rounded))
                    .foregroundStyle(ConcertinaSidebarView.ink.opacity(0.9))
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(height: metrics.headerHeight)
        .padding(.bottom, metrics.headerGap)
    }

    @ViewBuilder
    private func menuButton(metrics: ConcertinaSidebarView_PanelMetrics) -> some View {
        if demo {
            // Non-interactive in the tile; just a static hamburger mark.
            ConcertinaSidebarView_HamburgerMark(size: metrics.chevronSize)
                .frame(width: metrics.buttonSize, height: metrics.buttonSize)
                .background(buttonBackground)
        } else {
            Button {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                    open.toggle()
                }
            } label: {
                ConcertinaSidebarView_ChevronGlyph(open: open, size: metrics.chevronSize)
                    .frame(width: metrics.buttonSize, height: metrics.buttonSize)
                    .background(buttonBackground)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(ConcertinaSidebarView.accent.opacity(0.18))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(ConcertinaSidebarView.accent.opacity(0.35), lineWidth: 1)
            )
    }

    private func rowStack(globalProgress: Double, metrics: ConcertinaSidebarView_PanelMetrics) -> some View {
        VStack(spacing: metrics.rowSpacing) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, model in
                ConcertinaSidebarView_ConcertinaRow(
                    model: model,
                    index: index,
                    count: rows.count,
                    progress: rowProgress(globalProgress: globalProgress, index: index),
                    demo: demo,
                    metrics: metrics
                )
            }
        }
    }

    private func panelBackground(metrics: ConcertinaSidebarView_PanelMetrics) -> some View {
        RoundedRectangle(cornerRadius: metrics.panelCorner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.09, green: 0.11, blue: 0.14),
                        Color(red: 0.06, green: 0.07, blue: 0.10)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: metrics.panelCorner, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            )
    }

    // MARK: Progress math

    /// Per-row progress with a top-to-bottom stagger. The stagger compresses the
    /// useful range of the global progress so earlier rows lead and later rows trail.
    private func rowProgress(globalProgress: Double, index: Int) -> Double {
        let count = max(rows.count, 1)
        let stagger = 0.45                       // total fraction reserved for the cascade
        let per = stagger / Double(count)
        let start = per * Double(index)
        let span = 1.0 - stagger
        let local = (globalProgress - start) / max(span, 0.0001)
        return clamp(local, lower: 0.0, upper: 1.0)
    }

    /// Self-driving schedule for demo: ease-open -> hold -> ease-closed -> hold.
    /// 4.0s loop (sits inside the 2.5-4s window).
    private func loopProgress(at time: Double) -> Double {
        let period = 4.0
        let phase = time.truncatingRemainder(dividingBy: period) / period   // 0..1
        let openDur = 0.30      // fraction spent opening
        let holdOpen = 0.20
        let closeDur = 0.30
        // remaining ~0.20 holds closed
        if phase < openDur {
            return easeInOut(phase / openDur)
        } else if phase < openDur + holdOpen {
            return 1.0
        } else if phase < openDur + holdOpen + closeDur {
            let p = (phase - openDur - holdOpen) / closeDur
            return easeInOut(1.0 - p)
        } else {
            return 0.0
        }
    }

    private func easeInOut(_ x: Double) -> Double {
        let c = clamp(x, lower: 0.0, upper: 1.0)
        return c * c * (3.0 - 2.0 * c)
    }

    private func clamp(_ x: Double, lower: Double, upper: Double) -> Double {
        min(max(x, lower), upper)
    }
}

// MARK: - Row

private struct ConcertinaSidebarView_ConcertinaRow: View {
    let model: ConcertinaSidebarView_SidebarRowModel
    let index: Int
    let count: Int
    let progress: Double          // 0 = squeezed sliver, 1 = fully unfolded
    let demo: Bool
    let metrics: ConcertinaSidebarView_PanelMetrics

    var body: some View {
        let p = progress

        // Floor the collapsed state so the panel squeezes into a *visible* stack,
        // never a blank frame. Scale eases from a thin sliver up to full height.
        let minScale: CGFloat = 0.10
        let scaleY = minScale + (1.0 - minScale) * CGFloat(p)

        // Opacity floor keeps collapsed rows legible (>= ~0.22).
        let opacity = 0.22 + 0.78 * p

        // Faint bellows pleat: the fold tips toward the viewer when collapsed.
        let foldAngle = (1.0 - p) * 58.0       // degrees

        // Collapsed rows overlap slightly to read as a stack of pleats.
        let collapseOffset = CGFloat(1.0 - p) * metrics.collapseStackOffset

        // Per-row staggered spring in tap mode (the bellows "wow"). Guarded to the
        // interactive branch so it never fights the per-frame TimelineView in demo.
        let rowAnimation: Animation? = demo
            ? nil
            : .spring(response: 0.5, dampingFraction: 0.72).delay(Double(index) * 0.06)

        return content
            .frame(height: metrics.rowHeight)
            .scaleEffect(x: 1.0, y: scaleY, anchor: .top)
            .rotation3DEffect(
                .degrees(foldAngle),
                axis: (x: 1, y: 0, z: 0),
                anchor: .top,
                anchorZ: 0,
                perspective: 0.55
            )
            .offset(y: -collapseOffset)
            .opacity(opacity)
            .zIndex(Double(count - index))     // upper rows fold over lower ones
            .animation(rowAnimation, value: progress)
    }

    private var content: some View {
        HStack(spacing: metrics.rowSpacing) {
            iconWell
            if metrics.showsRowTitle {
                Text(model.title)
                    .font(.system(size: metrics.rowFont, weight: .medium, design: .rounded))
                    .foregroundStyle(ConcertinaSidebarView.ink.opacity(0.92))
                    .lineLimit(1)
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, metrics.rowHPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(rowBackground)
    }

    private var iconWell: some View {
        Image(systemName: model.symbol)
            .font(.system(size: metrics.iconFont, weight: .semibold))
            .foregroundStyle(ConcertinaSidebarView.accent)
            .frame(width: metrics.iconWell, height: metrics.iconWell)
    }

    private var rowBackground: some View {
        // Top-edge highlight + body fill fakes the pleat catching light.
        RoundedRectangle(cornerRadius: metrics.rowCorner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.10),
                        Color.white.opacity(0.03)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: metrics.rowCorner, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.75)
            )
    }
}

// MARK: - Chevron / Hamburger marks

private struct ConcertinaSidebarView_ChevronGlyph: View {
    let open: Bool
    let size: CGFloat

    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(ConcertinaSidebarView.accent)
            .rotationEffect(.degrees(open ? 90 : 0))
            .scaleEffect(open ? 1.0 : 0.92)
    }
}

private struct ConcertinaSidebarView_HamburgerMark: View {
    let size: CGFloat
    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(ConcertinaSidebarView.accent)
    }
}

// MARK: - Model

private struct ConcertinaSidebarView_SidebarRowModel: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
}

// MARK: - Metrics (all derived from the available size)

private struct ConcertinaSidebarView_PanelMetrics {
    let size: CGSize
    let rowCount: Int

    // A coarse "is this a tiny tile?" gate to drop labels in the grid preview.
    private var isCompact: Bool { size.width < 200 || size.height < 200 }

    var outerPadding: CGFloat { isCompact ? 7 : 16 }
    var panelCorner: CGFloat { isCompact ? 12 : 22 }

    var headerHeight: CGFloat {
        let h = size.height * 0.16
        return min(max(h, 22), 52)
    }
    var headerGap: CGFloat { isCompact ? 5 : 12 }
    var headerSpacing: CGFloat { isCompact ? 6 : 12 }
    var showsHeaderTitle: Bool { !isCompact }
    var titleFont: CGFloat { 16 }

    var buttonSize: CGFloat { min(headerHeight, isCompact ? 24 : 40) }
    var chevronSize: CGFloat { isCompact ? 10 : 16 }

    // Rows fill the remaining vertical space evenly so it works in tile + detail.
    var rowSpacing: CGFloat { isCompact ? 4 : 9 }

    private var availableRowSpace: CGFloat {
        let used = outerPadding * 2 + headerHeight + headerGap
        let spacingTotal = rowSpacing * CGFloat(max(rowCount - 1, 0))
        return max(size.height - used - spacingTotal, CGFloat(rowCount) * 6)
    }
    var rowHeight: CGFloat { availableRowSpace / CGFloat(max(rowCount, 1)) }

    var rowCorner: CGFloat { min(rowHeight * 0.32, isCompact ? 8 : 14) }
    var rowHPadding: CGFloat { isCompact ? 6 : 14 }
    var rowFont: CGFloat { isCompact ? 11 : 15 }
    var showsRowTitle: Bool { !isCompact && rowHeight > 26 }

    var iconWell: CGFloat { min(rowHeight * 0.72, isCompact ? 18 : 30) }
    var iconFont: CGFloat { isCompact ? 9 : 14 }

    // How far collapsed rows slide up to overlap into a stack of pleats.
    var collapseStackOffset: CGFloat { rowHeight * 0.42 }
}
