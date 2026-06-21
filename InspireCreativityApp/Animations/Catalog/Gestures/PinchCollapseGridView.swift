// catalog-id: ges-pinch-collapse-grid
import SwiftUI

/// Pinch-to-Collapse Stack
///
/// Pinching a photo grid closed makes every tile fly inward and fan-stack into a
/// single tilted pile in the center; spreading fingers re-deals them back out
/// across the grid with staggered timing.
///
/// - `demo == true`  → a self-driving TimelineView loop oscillates a virtual pinch
///   so the tile reads as a self-shuffling deck with no touch.
/// - `demo == false` → a real `MagnifyGesture` scrubs the collapse continuously,
///   snapping open/closed with a bouncy spring on release.
struct PinchCollapseGridView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                background
                if demo {
                    DemoDeck(size: size)
                } else {
                    InteractiveDeck(size: size)
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.09),
                Color(red: 0.10, green: 0.10, blue: 0.17)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Demo (self-driving)

private struct DemoDeck: View {
    let size: CGSize

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            DeckCanvas(size: size, progress: PinchDeckMath.demoProgress(at: t))
        }
    }
}

// MARK: - Interactive (real gesture)

private struct InteractiveDeck: View {
    let size: CGSize

    @State private var base: Double = 0          // committed progress
    @State private var live: Double = 0          // live progress during pinch
    @State private var pinching: Bool = false

    private var progress: Double { pinching ? live : base }

    var body: some View {
        DeckCanvas(size: size, progress: progress)
            .contentShape(Rectangle())
            .gesture(pinch)
    }

    private var pinch: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                pinching = true
                // magnification < 1 (pinch in) collapses, > 1 (spread) expands.
                let delta = 1.0 - value.magnification
                live = PinchDeckMath.clamp01(base + delta)
            }
            .onEnded { _ in
                // Snap to the nearer extreme with a bouncy settle.
                let target: Double = live > 0.5 ? 1.0 : 0.0
                // Commit the live value first (no jump), then keep reading `base`.
                base = live
                pinching = false
                withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
                    base = target
                }
            }
    }
}

// MARK: - Shared deck renderer

private struct DeckCanvas: View {
    let size: CGSize
    let progress: Double

    private let cols: Int = 4
    private let rows: Int = 4
    private var count: Int { cols * rows }

    var body: some View {
        let layout = PinchDeckMath.Layout(size: size, cols: cols, rows: rows)
        ZStack {
            ForEach(0..<count, id: \.self) { index in
                tile(index: index, layout: layout)
            }
        }
    }

    private func tile(index: Int, layout: PinchDeckMath.Layout) -> some View {
        let xf = PinchDeckMath.transform(
            index: index,
            count: count,
            progress: progress,
            layout: layout
        )
        return TileFace(index: index, tileSize: layout.tileSize)
            .frame(width: layout.tileSize.width, height: layout.tileSize.height)
            .scaleEffect(xf.scale)
            .rotationEffect(.degrees(xf.rotation))
            .position(xf.position)
            .zIndex(xf.z)
            .shadow(
                color: Color.black.opacity(0.35 * progress),
                radius: 6 * progress,
                x: 0,
                y: 4 * progress
            )
    }
}

// MARK: - A single photo-like tile

private struct TileFace: View {
    let index: Int
    let tileSize: CGSize

    var body: some View {
        let corner: CGFloat = min(tileSize.width, tileSize.height) * 0.16
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(PinchDeckMath.tileGradient(index: index))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
            )
            .overlay(sheen(corner: corner))
    }

    private func sheen(corner: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.22),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .center
                )
            )
            .blendMode(.screen)
    }
}

// MARK: - Math (factored out for type-checker hygiene)

private enum PinchDeckMath {

    struct Layout {
        let size: CGSize
        let cols: Int
        let rows: Int
        let tileSize: CGSize
        let center: CGPoint

        init(size: CGSize, cols: Int, rows: Int) {
            self.size = size
            self.cols = cols
            self.rows = rows
            let pad: CGFloat = min(size.width, size.height) * 0.06
            let usableW = max(size.width - pad * 2, 1)
            let usableH = max(size.height - pad * 2, 1)
            let cellW = usableW / CGFloat(cols)
            let cellH = usableH / CGFloat(rows)
            // Slight inner gap so tiles read as separate photos.
            self.tileSize = CGSize(width: cellW * 0.86, height: cellH * 0.86)
            self.center = CGPoint(x: size.width / 2, y: size.height / 2)
        }

        func gridCenter(of index: Int) -> CGPoint {
            let col = index % cols
            let row = index / cols
            let pad: CGFloat = min(size.width, size.height) * 0.06
            let cellW = (size.width - pad * 2) / CGFloat(cols)
            let cellH = (size.height - pad * 2) / CGFloat(rows)
            let x = pad + cellW * (CGFloat(col) + 0.5)
            let y = pad + cellH * (CGFloat(row) + 0.5)
            return CGPoint(x: x, y: y)
        }
    }

    struct TileTransform {
        let position: CGPoint
        let rotation: Double
        let scale: CGFloat
        let z: Double
    }

    static func clamp01(_ v: Double) -> Double {
        min(max(v, 0.0), 1.0)
    }

    /// Self-driving virtual pinch: oscillates 0 → ~0.85 → 0 on a ~3s loop.
    /// Never reaches a blank extreme; the deck is always legible.
    static func demoProgress(at time: TimeInterval) -> Double {
        let period: Double = 3.2
        let phase = (time.truncatingRemainder(dividingBy: period)) / period
        // Smooth ease in/out via cosine, scaled so it dwells a touch at each end.
        let raw = (1.0 - cos(phase * 2.0 * .pi)) / 2.0   // 0→1→0
        return 0.06 + raw * 0.82
    }

    /// Per-tile staggered progress so the re-deal cascades instead of snapping
    /// all at once. Clamped to [0,1].
    static func staggered(index: Int, count: Int, progress: Double) -> Double {
        let n = max(count - 1, 1)
        let totalStagger: Double = 0.45
        let step = totalStagger / Double(n)
        let start = step * Double(index)
        let span = max(1.0 - totalStagger, 0.2)
        return clamp01((progress - start) / span)
    }

    static func transform(
        index: Int,
        count: Int,
        progress: Double,
        layout: Layout
    ) -> TileTransform {
        let gp = staggered(index: index, count: count, progress: progress)
        let eased = easeInOut(gp)

        let grid = layout.gridCenter(of: index)
        let stack = layout.center

        // Fan-stack: each card lands at a slightly different tilt + jitter so the
        // collapsed pile reads as a shuffled tilted deck.
        let n = max(count - 1, 1)
        let centered = Double(index) - Double(n) / 2.0
        let fanAngle = centered * 4.0                       // degrees across the fan
        let wobble = sin(Double(index) * 1.7) * 3.0         // pseudo-random extra tilt
        let stackRotation = fanAngle + wobble

        let jitterX = CGFloat(cos(Double(index) * 2.3)) * layout.tileSize.width * 0.10
        let jitterY = CGFloat(sin(Double(index) * 1.9)) * layout.tileSize.height * 0.10
        let stackPoint = CGPoint(x: stack.x + jitterX, y: stack.y + jitterY)

        let pos = lerpPoint(grid, stackPoint, eased)
        let rot = lerpD(0.0, stackRotation, eased)

        // Pile slightly larger than a single grid cell to feel like a held deck.
        let scale = CGFloat(lerpD(1.0, 1.12, eased))

        // Stacking order: later cards sit on top of the pile.
        let z = Double(index) * 0.01 + eased * Double(index)

        return TileTransform(position: pos, rotation: rot, scale: scale, z: z)
    }

    // MARK: helpers

    static func easeInOut(_ t: Double) -> Double {
        let c = clamp01(t)
        return c * c * (3.0 - 2.0 * c)
    }

    static func lerpD(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }

    static func lerpPoint(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
        CGPoint(
            x: a.x + (b.x - a.x) * CGFloat(t),
            y: a.y + (b.y - a.y) * CGFloat(t)
        )
    }

    /// Distinct, photo-like gradients per index — no assets, no Color(hex:).
    static func tileGradient(index: Int) -> LinearGradient {
        let palette: [(Double, Double, Double)] = [
            (0.95, 0.45, 0.42), (0.98, 0.70, 0.36), (0.55, 0.80, 0.52),
            (0.36, 0.74, 0.86), (0.52, 0.55, 0.95), (0.86, 0.50, 0.88),
            (0.99, 0.55, 0.66), (0.40, 0.84, 0.74)
        ]
        let a = palette[index % palette.count]
        let b = palette[(index * 3 + 2) % palette.count]
        return LinearGradient(
            colors: [
                Color(red: a.0, green: a.1, blue: a.2),
                Color(red: b.0 * 0.7, green: b.1 * 0.7, blue: b.2 * 0.8)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
