// catalog-id: tr-fold-accordion
import SwiftUI

/// Fold-Down Accordion
///
/// Stacked list rows concertina-collapse along shared horizontal hinges. Each row
/// folds flat (rotation3DEffect about its top edge on the .x axis with a perspective
/// anchor) while its layout slot shrinks, so the whole stack compresses up into a
/// single always-visible header. A per-row darkening LinearGradient hinge overlay
/// fades in at each crease so the collapse reads as one continuous folding ribbon.
///
/// - demo == true:  a PhaseAnimator auto-cycles the collapse progress 0->1->0 so the
///                  rows concertina shut into the header then unfold continuously.
/// - demo == false: tapping the header toggles `collapsed`, driving the collapse via
///                  withAnimation(.spring); per-row hinge angles interpolate from the
///                  single progress with staggered offsets.
struct FoldAccordionView: View {
    var demo: Bool = false

    @State private var collapsed: Bool = false

    private let rowCount: Int = 5

    var body: some View {
        GeometryReader { geo in
            content(size: geo.size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(size: CGSize) -> some View {
        if demo {
            PhaseAnimator([0.0, 1.0]) { phase in
                accordion(progress: CGFloat(phase), size: size)
            } animation: { _ in
                .easeInOut(duration: 1.6)
            }
        } else {
            accordion(progress: collapsed ? 1 : 0, size: size)
        }
    }

    // MARK: - Layout

    private func accordion(progress: CGFloat, size: CGSize) -> some View {
        let metrics = layoutMetrics(for: size)
        return VStack(spacing: metrics.gap) {
            ForEach(0..<rowCount, id: \.self) { index in
                row(index: index, progress: progress, metrics: metrics)
            }
            header(progress: progress, metrics: metrics)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, metrics.sidePadding)
        .padding(.vertical, metrics.sidePadding)
        .contentShape(Rectangle())
    }

    struct Metrics {
        var rowHeight: CGFloat
        var headerHeight: CGFloat
        var gap: CGFloat
        var corner: CGFloat
        var sidePadding: CGFloat
        var fontSize: CGFloat
    }

    private func layoutMetrics(for size: CGSize) -> Metrics {
        let minSide = min(size.width, size.height)
        let scale = minSide / 120.0
        let pad = max(4.0, 6.0 * scale)
        let usableHeight = max(40.0, size.height - pad * 2)
        // Reserve a share for the header; rows split the remainder.
        let headerH = usableHeight * 0.20
        let gap = max(1.0, 1.5 * scale)
        let totalGap = gap * CGFloat(rowCount)
        let rowsH = distributedRowHeight(count: rowCount, available: usableHeight - headerH - totalGap)
        return Metrics(
            rowHeight: rowsH,
            headerHeight: headerH,
            gap: gap,
            corner: max(3.0, 6.0 * scale),
            sidePadding: pad,
            fontSize: max(7.0, 9.0 * scale)
        )
    }

    private func distributedRowHeight(count: Int, available: CGFloat) -> CGFloat {
        Swift.max(8.0, available / CGFloat(count))
    }

    // MARK: - Staggered fold

    /// Bottom row folds first so the stack zips up into the header.
    /// Returns 0 (open / face-on) ... 1 (fully folded / edge-on) for a given row.
    private func localFold(index: Int, progress: CGFloat) -> CGFloat {
        let n = CGFloat(rowCount)
        // Fold order: last row (n-1) starts first, first row last.
        let order = n - 1 - CGFloat(index)
        // Each row gets a window; windows overlap for a continuous ribbon feel.
        let window: CGFloat = 0.55
        let span = Swift.max(0.0001, 1.0 - window)
        let start = (order / Swift.max(1, n - 1)) * span
        let raw = (progress - start) / window
        return clamp(raw)
    }

    private func clamp(_ v: CGFloat) -> CGFloat {
        Swift.min(1.0, Swift.max(0.0, v))
    }

    // MARK: - Row

    private func row(index: Int, progress: CGFloat, metrics: Metrics) -> some View {
        let fold = localFold(index: index, progress: progress)
        let angle = Double(fold) * 88.0          // fold flat against the next row
        let collapsedHeight = metrics.rowHeight * (1.0 - fold)
        let tint = rowTint(index: index)

        return rowFace(index: index, tint: tint, metrics: metrics, fold: fold)
            // Hinge crease shadow: darkens toward the top edge as the row folds.
            .overlay(hingeShadow(corner: metrics.corner).opacity(Double(fold) * 0.9))
            // Edge-on dimming so the folded face reads as in-shadow.
            .brightness(-0.18 * Double(fold))
            .rotation3DEffect(
                .degrees(angle),
                axis: (x: 1, y: 0, z: 0),
                anchor: .top,
                anchorZ: 0,
                perspective: 0.55
            )
            // Collapse the layout slot so the VStack shrinks upward into the header.
            .frame(height: Swift.max(0.5, collapsedHeight), alignment: .top)
            .zIndex(Double(rowCount - index))    // upper rows sit above lower ones
    }

    private func rowFace(index: Int, tint: Color, metrics: Metrics, fold: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: metrics.corner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [tint.opacity(0.96), tint.opacity(0.74)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(alignment: .leading) {
                rowContent(index: index, metrics: metrics)
                    .opacity(1.0 - Double(fold) * 0.85)
            }
            .frame(height: metrics.rowHeight, alignment: .top)
    }

    private func rowContent(index: Int, metrics: Metrics) -> some View {
        HStack(spacing: metrics.fontSize * 0.6) {
            Circle()
                .fill(Color(red: 0.55, green: 0.78, blue: 1.0).opacity(0.85))
                .frame(width: metrics.fontSize * 0.9, height: metrics.fontSize * 0.9)
            VStack(alignment: .leading, spacing: metrics.fontSize * 0.28) {
                Capsule()
                    .fill(Color.white.opacity(0.82))
                    .frame(width: metrics.fontSize * 5.5, height: metrics.fontSize * 0.42)
                Capsule()
                    .fill(Color.white.opacity(0.42))
                    .frame(width: metrics.fontSize * 3.2, height: metrics.fontSize * 0.36)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, metrics.fontSize * 0.8)
    }

    private func hingeShadow(corner: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.85),
                        Color.black.opacity(0.30),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
            )
            .allowsHitTesting(false)
    }

    // MARK: - Header (always opaque, drawn last / on top)

    private func header(progress: CGFloat, metrics: Metrics) -> some View {
        let chevronAngle = Double(progress) * 180.0
        return RoundedRectangle(cornerRadius: metrics.corner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.16, green: 0.20, blue: 0.30),
                        Color(red: 0.09, green: 0.11, blue: 0.17)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(alignment: .top) {
                // Subtle top highlight so the header reads as the lid the rows fold under.
                RoundedRectangle(cornerRadius: metrics.corner, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.6)
            }
            .overlay {
                headerContent(angle: chevronAngle, metrics: metrics)
            }
            .frame(height: metrics.headerHeight)
            .shadow(color: Color.black.opacity(0.35), radius: metrics.corner, x: 0, y: -1)
            .zIndex(Double(rowCount + 1))
            .contentShape(Rectangle())
            .onTapGesture {
                guard !demo else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.74)) {
                    collapsed.toggle()
                }
            }
    }

    private func headerContent(angle: Double, metrics: Metrics) -> some View {
        HStack(spacing: metrics.fontSize * 0.5) {
            Capsule()
                .fill(Color(red: 0.55, green: 0.78, blue: 1.0))
                .frame(width: metrics.fontSize * 4.0, height: metrics.fontSize * 0.5)
            Spacer(minLength: 0)
            Image(systemName: "chevron.down")
                .font(.system(size: metrics.fontSize, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.85))
                .rotationEffect(.degrees(angle))
        }
        .padding(.horizontal, metrics.fontSize * 0.9)
    }

    // MARK: - Colors

    private func rowTint(index: Int) -> Color {
        let palette: [Color] = [
            Color(red: 0.31, green: 0.46, blue: 0.92),
            Color(red: 0.42, green: 0.40, blue: 0.90),
            Color(red: 0.55, green: 0.36, blue: 0.86),
            Color(red: 0.66, green: 0.34, blue: 0.74),
            Color(red: 0.78, green: 0.36, blue: 0.62)
        ]
        return palette[index % palette.count]
    }
}
