// catalog-id: tr-column-slat-slide
import SwiftUI

/// Column Slat Slide — a transition where the outgoing card is sliced into
/// vertical column "slats" that slide off-screen at staggered speeds and
/// offsets, revealing the incoming card sitting behind each gap. The staggered
/// timing makes the columns appear to overtake each other in a rippling
/// vertical-blind cascade.
///
/// This is an `auto` transition: both `demo` states self-drive the cascade
/// continuously via `TimelineView(.animation)` — there is no scrub gesture per
/// the spec.
struct ColumnSlatSlideView: View {
    var demo: Bool = false

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            SlatStage(progress: loopProgress(at: t))
        }
    }

    /// Eases a 0→1→0 cascade on a ~3.4s loop with brief dwells at each end so
    /// both the fully-outgoing and fully-incoming states are clearly read.
    private func loopProgress(at time: TimeInterval) -> CGFloat {
        let period: Double = 3.4
        let phase = (time.truncatingRemainder(dividingBy: period)) / period
        // Two halves: 0→1 then 1→0, each smoothed, with a short hold at the apex.
        let raw: Double
        if phase < 0.5 {
            raw = smoothstep(phase / 0.5)
        } else {
            raw = smoothstep((1.0 - phase) / 0.5)
        }
        return CGFloat(raw)
    }

    private func smoothstep(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }
}

// MARK: - Stage

private struct SlatStage: View {
    let progress: CGFloat

    private let slatCount = 6

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Incoming card always fills the frame behind the slats, so no
                // frame is ever blank: p=0 → outgoing, p=1 → incoming.
                CardFace(kind: .incoming)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Outgoing card, sliced into vertical columns. Each column is a
                // full-size copy masked to its own x-range, then offset so it
                // slides away as a unit (global coords stay correct).
                ForEach(0..<slatCount, id: \.self) { index in
                    SlatColumn(
                        index: index,
                        count: slatCount,
                        size: geo.size,
                        offsetY: offsetY(index: index, size: geo.size)
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: corner(for: geo.size), style: .continuous))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func corner(for size: CGSize) -> CGFloat {
        min(size.width, size.height) * 0.12
    }

    /// Per-column vertical offset. Each column has a staggered start delay and a
    /// slightly different speed, so columns overtake one another → cascade.
    /// Columns alternate sliding up / down for a woven-blind feel.
    private func offsetY(index: Int, size: CGSize) -> CGFloat {
        let n = Double(slatCount)
        let i = Double(index)

        // Left-to-right travelling wave: each column starts a beat later.
        let delay = 0.16 * (i / max(n - 1, 1))
        // Mild per-column speed variation so leaders get overtaken.
        let speed = 1.0 + 0.45 * (i / max(n - 1, 1))

        let local = (Double(progress) - delay) * speed
        let p = min(max(local, 0), 1)
        let eased = p * p * (3 - 2 * p) // smoothstep

        // Travel just past the edge to guarantee a clean exit (no hairline).
        let travel = size.height * 1.12
        let direction: CGFloat = (index % 2 == 0) ? -1 : 1
        return direction * CGFloat(eased) * travel
    }
}

// MARK: - One vertical slat

private struct SlatColumn: View {
    let index: Int
    let count: Int
    let size: CGSize
    let offsetY: CGFloat

    var body: some View {
        let columnWidth = size.width / CGFloat(count)
        // Overlap edges by 0.6pt to avoid sub-pixel seams between columns.
        let x = columnWidth * CGFloat(index) - 0.3
        let w = columnWidth + 0.6

        CardFace(kind: .outgoing)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .mask(alignment: .topLeading) {
                Rectangle()
                    .frame(width: w, height: size.height)
                    .offset(x: x)
            }
            .offset(y: offsetY)
    }
}

// MARK: - Card faces

private enum FaceKind {
    case outgoing
    case incoming
}

private struct CardFace: View {
    let kind: FaceKind

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                background(side: side)
                content(side: side)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func background(side: CGFloat) -> some View {
        let colors = kind == .outgoing
            ? [Color(hexCode: 0x1A2030), Color(hexCode: 0x0D1016)]
            : [Color(hexCode: 0x16324A), Color(hexCode: 0x0B1B2A)]
        LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(slatSheen(side: side))
    }

    /// Subtle vertical sheen lines so the column boundaries read as physical slats.
    private func slatSheen(side: CGFloat) -> some View {
        let tint = kind == .outgoing ? Color.white.opacity(0.05) : Color.cyan.opacity(0.06)
        return LinearGradient(
            colors: [tint, .clear, tint],
            startPoint: .leading,
            endPoint: .trailing
        )
        .blendMode(.plusLighter)
    }

    @ViewBuilder
    private func content(side: CGFloat) -> some View {
        let symbol = kind == .outgoing ? "square.grid.3x3.fill" : "checkmark.seal.fill"
        let label = kind == .outgoing ? "PANEL A" : "PANEL B"
        let accent = kind == .outgoing ? Color(hexCode: 0x7C8AA8) : Color(hexCode: 0x35E0C8)

        VStack(spacing: side * 0.08) {
            Image(systemName: symbol)
                .font(.system(size: side * 0.26, weight: .semibold))
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.5), radius: side * 0.05)
            Text(label)
                .font(.system(size: side * 0.1, weight: .heavy, design: .rounded))
                .tracking(side * 0.02)
                .foregroundStyle(.white.opacity(0.92))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Hex color helper

private extension Color {
    init(hexCode hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}
