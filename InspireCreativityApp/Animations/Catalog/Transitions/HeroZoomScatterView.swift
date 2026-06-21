// catalog-id: tr-hero-zoom-scatter
import SwiftUI

/// Hero Zoom Scatter
///
/// A tapped grid thumbnail expands to a full detail view while every surrounding
/// grid cell scatters outward and fades, then settles back on dismiss.
///
/// The whole effect is driven by a single shared `progress` value (0 = grid,
/// 1 = hero zoomed). This deliberately avoids `matchedGeometryEffect` + a phase
/// animator (which do not compose, and risk a blank frame inside a small tile):
/// - `demo == true`  -> a TimelineView smoothstep loop with a dwell at each end.
/// - `demo == false` -> a real `onTapGesture` toggling the progress via a spring.
///
/// Both paths feed the same render core, so the demo tile is pixel-faithful to
/// the interactive component.
struct HeroZoomScatterView: View {
    var demo: Bool = false

    // Interactive state.
    @State private var zoomed: Bool = false

    // 3x3 grid; index 4 (the center cell) is the hero.
    private let columns: Int = 3
    private let rows: Int = 3
    private var heroIndex: Int { (rows * columns) / 2 }

    var body: some View {
        GeometryReader { geo in
            if demo {
                demoContent(in: geo.size)
            } else {
                interactiveContent(in: geo.size)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Demo (self-driving)

    private func demoContent(in size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let progress = loopProgress(at: t)
            scene(in: size, progress: progress, staggered: false)
        }
    }

    /// A ~3.4s loop: ease up to fully zoomed, dwell so the detail reads,
    /// ease back down, dwell in the grid state. Never reaches a blank frame.
    private func loopProgress(at time: TimeInterval) -> CGFloat {
        let period: Double = 3.4
        let phase = time.truncatingRemainder(dividingBy: period) / period // 0..<1

        let openEnd: Double = 0.32   // ramp up
        let holdEnd: Double = 0.55   // dwell zoomed
        let closeEnd: Double = 0.85  // ramp down
        // remainder: dwell in grid state

        let raw: Double
        if phase < openEnd {
            raw = smoothstep(phase / openEnd)
        } else if phase < holdEnd {
            raw = 1.0
        } else if phase < closeEnd {
            raw = 1.0 - smoothstep((phase - holdEnd) / (closeEnd - holdEnd))
        } else {
            raw = 0.0
        }
        return CGFloat(raw)
    }

    private func smoothstep(_ x: Double) -> Double {
        let c = min(max(x, 0.0), 1.0)
        return c * c * (3.0 - 2.0 * c)
    }

    // MARK: - Interactive

    private func interactiveContent(in size: CGSize) -> some View {
        let progress: CGFloat = zoomed ? 1.0 : 0.0
        return scene(in: size, progress: progress, staggered: true)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                    zoomed.toggle()
                }
            }
    }

    // MARK: - Shared scene

    private func scene(in size: CGSize, progress: CGFloat, staggered: Bool) -> some View {
        let metrics = HeroZoomScatterView_GridMetrics(size: size, columns: columns, rows: rows)
        return ZStack {
            // Backdrop dims as the hero takes focus.
            Color(red: 0.05, green: 0.06, blue: 0.09)
                .opacity(0.0)
                .background(
                    Color(red: 0.04, green: 0.045, blue: 0.07)
                        .opacity(Double(0.85 * progress))
                )
                .allowsHitTesting(false)

            // Siblings scatter outward & fade.
            ForEach(siblingIndices, id: \.self) { index in
                siblingCell(index: index,
                            metrics: metrics,
                            progress: progress,
                            staggered: staggered)
            }

            // Hero grows from its slot to fill the bounds.
            heroCell(metrics: metrics, progress: progress, staggered: staggered)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private var siblingIndices: [Int] {
        Array(0 ..< (rows * columns)).filter { $0 != heroIndex }
    }

    // MARK: - Hero cell

    @ViewBuilder
    private func heroCell(metrics: HeroZoomScatterView_GridMetrics, progress: CGFloat, staggered: Bool) -> some View {
        let slot = metrics.frame(forIndex: heroIndex)
        let full = metrics.fullFrame
        let rect = lerp(rect: slot, to: full, t: progress)
        let cornerSlot: CGFloat = min(slot.width, slot.height) * 0.22
        let cornerFull: CGFloat = min(full.width, full.height) * 0.10
        let corner = mix(cornerSlot, cornerFull, progress)

        HeroZoomScatterView_HeroTile(progress: progress, corner: corner)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .shadow(color: Color.black.opacity(Double(0.35 * progress)),
                    radius: 18 * progress, x: 0, y: 10 * progress)
            .modifier(HeroZoomScatterView_StaggeredSpring(enabled: staggered, delay: 0, value: progress))
    }

    // MARK: - Sibling cell

    @ViewBuilder
    private func siblingCell(index: Int,
                             metrics: HeroZoomScatterView_GridMetrics,
                             progress: CGFloat,
                             staggered: Bool) -> some View {
        let slot = metrics.frame(forIndex: index)
        let dir = metrics.outwardDirection(forIndex: index)
        let scatter: CGFloat = metrics.scatterDistance
        let dx = dir.dx * scatter * progress
        let dy = dir.dy * scatter * progress
        let scale = 1.0 - 0.12 * progress
        let opacity = Double(max(0.0, 1.0 - 1.15 * progress))
        let ring = metrics.ringDistance(forIndex: index) // 1 for edges, etc.
        let delay = 0.03 * Double(ring)

        HeroZoomScatterView_SiblingTile(hue: metrics.hue(forIndex: index))
            .frame(width: slot.width, height: slot.height)
            .scaleEffect(scale)
            .position(x: slot.midX + dx, y: slot.midY + dy)
            .opacity(opacity)
            .modifier(HeroZoomScatterView_StaggeredSpring(enabled: staggered, delay: delay, value: progress))
    }

    // MARK: - Interpolation helpers

    private func lerp(rect a: CGRect, to b: CGRect, t: CGFloat) -> CGRect {
        CGRect(x: mix(a.minX, b.minX, t),
               y: mix(a.minY, b.minY, t),
               width: mix(a.width, b.width, t),
               height: mix(a.height, b.height, t))
    }

    private func mix(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }
}

// MARK: - Staggered spring modifier

/// Applies a per-cell staggered spring only in the interactive path. In the
/// demo path the progress is already a smooth continuous value, so no implicit
/// animation is attached (it would fight the TimelineView clock).
private struct HeroZoomScatterView_StaggeredSpring: ViewModifier, Animatable {
    let enabled: Bool
    let delay: Double
    let value: CGFloat

    func body(content: Content) -> some View {
        if enabled {
            content.animation(.spring(response: 0.5, dampingFraction: 0.74)
                .delay(delay), value: value)
        } else {
            content
        }
    }
}

// MARK: - Grid metrics

private struct HeroZoomScatterView_GridMetrics {
    let size: CGSize
    let columns: Int
    let rows: Int

    private let inset: CGFloat
    private let gap: CGFloat

    init(size: CGSize, columns: Int, rows: Int) {
        self.size = size
        self.columns = columns
        self.rows = rows
        let minDim = min(size.width, size.height)
        self.inset = minDim * 0.10
        self.gap = minDim * 0.055
    }

    var contentRect: CGRect {
        CGRect(x: inset, y: inset,
               width: max(size.width - inset * 2, 1),
               height: max(size.height - inset * 2, 1))
    }

    var fullFrame: CGRect {
        let pad = min(size.width, size.height) * 0.06
        return CGRect(x: pad, y: pad,
                      width: max(size.width - pad * 2, 1),
                      height: max(size.height - pad * 2, 1))
    }

    private var cellWidth: CGFloat {
        (contentRect.width - gap * CGFloat(columns - 1)) / CGFloat(columns)
    }

    private var cellHeight: CGFloat {
        (contentRect.height - gap * CGFloat(rows - 1)) / CGFloat(rows)
    }

    var scatterDistance: CGFloat {
        min(size.width, size.height) * 0.55
    }

    func column(of index: Int) -> Int { index % columns }
    func row(of index: Int) -> Int { index / columns }

    func frame(forIndex index: Int) -> CGRect {
        let c = column(of: index)
        let r = row(of: index)
        let x = contentRect.minX + CGFloat(c) * (cellWidth + gap)
        let y = contentRect.minY + CGFloat(r) * (cellHeight + gap)
        return CGRect(x: x, y: y, width: max(cellWidth, 1), height: max(cellHeight, 1))
    }

    private var heroCenter: CGPoint {
        let f = frame(forIndex: (rows * columns) / 2)
        return CGPoint(x: f.midX, y: f.midY)
    }

    /// Normalised outward direction from the hero center to this cell's center.
    func outwardDirection(forIndex index: Int) -> CGVector {
        let f = frame(forIndex: index)
        let dx = f.midX - heroCenter.x
        let dy = f.midY - heroCenter.y
        let len = max(sqrt(dx * dx + dy * dy), 0.0001)
        return CGVector(dx: dx / len, dy: dy / len)
    }

    /// Chebyshev ring distance from the hero (used for stagger delay).
    func ringDistance(forIndex index: Int) -> Int {
        let heroC = columns / 2
        let heroR = rows / 2
        return max(abs(column(of: index) - heroC), abs(row(of: index) - heroR))
    }

    func hue(forIndex index: Int) -> Double {
        let total = Double(max(rows * columns - 1, 1))
        return Double(index) / total
    }
}

// MARK: - Hero tile content

private struct HeroZoomScatterView_HeroTile: View {
    let progress: CGFloat
    let corner: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.36, green: 0.52, blue: 0.96),
                            Color(red: 0.62, green: 0.34, blue: 0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                )

            // Detail content fades in only when the hero is mostly expanded,
            // so the zoom reads as "becoming a detail view," not just scaling.
            detailOverlay
                .opacity(Double(detailOpacity))
                .padding(corner * 0.9)
        }
        .compositingGroup()
    }

    private var detailOpacity: CGFloat {
        // Ramp 0 -> 1 across the second half of the zoom.
        let p = (progress - 0.45) / 0.45
        return max(0.0, min(1.0, p))
    }

    private var detailOverlay: some View {
        GeometryReader { g in
            let unit = min(g.size.width, g.size.height)
            VStack(alignment: .leading, spacing: unit * 0.08) {
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: unit * 0.22, height: unit * 0.22)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.system(size: unit * 0.11, weight: .bold))
                            .foregroundStyle(Color(red: 0.45, green: 0.36, blue: 0.95))
                    )
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: unit * 0.04, style: .continuous)
                    .fill(Color.white.opacity(0.88))
                    .frame(width: g.size.width * 0.7, height: unit * 0.09)
                RoundedRectangle(cornerRadius: unit * 0.03, style: .continuous)
                    .fill(Color.white.opacity(0.5))
                    .frame(width: g.size.width * 0.5, height: unit * 0.06)
                RoundedRectangle(cornerRadius: unit * 0.03, style: .continuous)
                    .fill(Color.white.opacity(0.32))
                    .frame(width: g.size.width * 0.88, height: unit * 0.05)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

// MARK: - Sibling tile content

private struct HeroZoomScatterView_SiblingTile: View {
    let hue: Double

    var body: some View {
        GeometryReader { g in
            let r = min(g.size.width, g.size.height) * 0.22
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: r, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
        }
    }

    private var gradientColors: [Color] {
        let base = Color(hue: hue, saturation: 0.42, brightness: 0.62)
        let dark = Color(hue: hue, saturation: 0.5, brightness: 0.4)
        return [base, dark]
    }
}
