// catalog-id: bg-truchet-flow
import SwiftUI

/// Truchet Flow — a grid of quarter-arc Truchet tiles that perpetually rotate
/// in eased 90° steps along a diagonal wave, re-threading the connected curves
/// into endlessly shifting maze-like loops. Pure SwiftUI Canvas, iOS 17+.
///
/// `interaction` is "auto": both the demo tile and the real component run the
/// same self-driving TimelineView loop, so the tile is never blank or static.
struct TruchetFlowView: View {
    var demo: Bool = false

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            TruchetFlowView_TruchetCanvas(time: t)
        }
        .background(Self.backdrop)
        .clipped()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // Soft graphite backdrop so the bright filaments read at any tile size.
    private static let backdrop = LinearGradient(
        colors: [
            Color(red: 0.04, green: 0.05, blue: 0.08),
            Color(red: 0.02, green: 0.02, blue: 0.04)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Canvas renderer

private struct TruchetFlowView_TruchetCanvas: View {
    let time: Double

    var body: some View {
        Canvas { context, canvasSize in
            draw(in: &context, canvasSize: canvasSize)
        }
    }

    private func draw(in context: inout GraphicsContext, canvasSize: CGSize) {
        let layout = TruchetFlowView_TruchetLayout(canvasSize: canvasSize)
        guard layout.isValid else { return }

        let cell = layout.cell
        let line = max(CGFloat(1.5), cell * 0.16)

        // A faint glow pass underneath the crisp strokes for depth.
        for row in 0..<layout.rows {
            for col in 0..<layout.cols {
                drawCell(
                    &context,
                    row: row,
                    col: col,
                    layout: layout,
                    lineWidth: line,
                    glow: true
                )
            }
        }
        for row in 0..<layout.rows {
            for col in 0..<layout.cols {
                drawCell(
                    &context,
                    row: row,
                    col: col,
                    layout: layout,
                    lineWidth: line,
                    glow: false
                )
            }
        }
    }

    private func drawCell(
        _ context: inout GraphicsContext,
        row: Int,
        col: Int,
        layout: TruchetFlowView_TruchetLayout,
        lineWidth: CGFloat,
        glow: Bool
    ) {
        let cell = layout.cell
        let centerX = layout.originX + (CGFloat(col) + 0.5) * cell
        let centerY = layout.originY + (CGFloat(row) + 0.5) * cell

        let rotation = cellRotation(row: row, col: col)
        let shade = cellColor(row: row, col: col, diagonalSpan: layout.rows + layout.cols)

        // GraphicsContext is a value type with no save/restore stack — copy it
        // per cell so the translate+rotate transforms never accumulate.
        var cellCtx = context
        cellCtx.translateBy(x: centerX, y: centerY)
        cellCtx.rotate(by: .degrees(rotation))

        let arcs = Self.arcPath(cell: cell)
        if glow {
            cellCtx.addFilter(.blur(radius: lineWidth * 1.4))
            cellCtx.stroke(
                arcs,
                with: .color(shade.opacity(0.55)),
                style: StrokeStyle(lineWidth: lineWidth * 1.8, lineCap: .round)
            )
        } else {
            cellCtx.stroke(
                arcs,
                with: .color(shade),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
        }
    }

    /// The canonical quarter-arc pair, drawn in cell-CENTER-local coordinates so
    /// rotation happens about the cell centre. Each arc is centred on an opposite
    /// corner with radius = cell/2, so every endpoint lands exactly on an edge
    /// midpoint — that is what keeps adjacent tiles connected as they rotate.
    ///
    /// The two arcs MUST be separate subpaths. `addArc` follows CGPath rules:
    /// on a non-empty path it inserts a straight line from the current point to
    /// the next arc's start point. Without an explicit `move(to:)` before the
    /// second arc, that draws a spurious diagonal across every tile. The
    /// `move(to:)` forces a disjoint subpath so only the two clean arcs render.
    private static func arcPath(cell: CGFloat) -> Path {
        let r = cell / 2
        var path = Path()
        // Arc centred on the top-left corner (-r, -r): from top-mid to left-mid.
        path.addArc(
            center: CGPoint(x: -r, y: -r),
            radius: r,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        // Start a fresh subpath at the bottom-right arc's start point (bottom-mid)
        // so no connecting line is drawn between the two arcs.
        path.move(to: CGPoint(x: 0, y: r))
        // Arc centred on the bottom-right corner (r, r): from bottom-mid to right-mid.
        path.addArc(
            center: CGPoint(x: r, y: r),
            radius: r,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        return path
    }

    /// Eased, perpetually-advancing 90° stepping that travels along the diagonal.
    /// `localPhase` is offset by the cell's diagonal index so the flips ripple as
    /// a wave; easeInOut dwells near each detent so the maze stays legible.
    private func cellRotation(row: Int, col: Int) -> Double {
        let period: Double = 3.0           // seconds per 90° detent — within 2.5–4s band
        let diagonalDelay: Double = 0.12   // per-cell phase offset along the diagonal
        let diagonal = Double(row + col)

        let localPhase = time / period - diagonal * diagonalDelay
        let step = floor(localPhase)
        let raw = localPhase - step
        let eased = Self.easeInOut(raw)
        return (step + eased) * 90.0
    }

    private static func easeInOut(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }

    /// Hue drift along the diagonal + slow time wash so the labyrinth glows in
    /// shifting teal/violet bands rather than a flat colour.
    private func cellColor(row: Int, col: Int, diagonalSpan: Int) -> Color {
        let span = max(Double(diagonalSpan), 1)
        let diagonalT = Double(row + col) / span
        let wash = (sin(time * 0.35 + diagonalT * 6.0) + 1) / 2
        let hue = 0.52 + 0.22 * wash          // teal -> blue/violet
        let sat = 0.55 + 0.25 * diagonalT
        let bri = 0.85 + 0.15 * wash
        return Color(hue: hue.truncatingRemainder(dividingBy: 1.0),
                     saturation: min(sat, 1.0),
                     brightness: min(bri, 1.0))
    }
}

// MARK: - Layout

/// Derives a square-cell honeycomb-free grid from the available size so the
/// identical code fills a ~120pt tile and a large detail area alike.
private struct TruchetFlowView_TruchetLayout {
    let cell: CGFloat
    let cols: Int
    let rows: Int
    let originX: CGFloat
    let originY: CGFloat

    init(canvasSize: CGSize) {
        let w = max(canvasSize.width, 1)
        let h = max(canvasSize.height, 1)
        let minSide = min(w, h)

        // Target a sensible tile density that scales with the view.
        let targetCells: CGFloat = minSide < 200 ? 5 : 8
        let rawCell = minSide / targetCells
        let c = max(rawCell, 12)

        let colCount = max(Int(ceil(w / c)) + 1, 1)
        let rowCount = max(Int(ceil(h / c)) + 1, 1)

        // Centre the (over-scanned) grid so it always covers the bounds.
        let gridW = CGFloat(colCount) * c
        let gridH = CGFloat(rowCount) * c

        cell = c
        cols = colCount
        rows = rowCount
        originX = (w - gridW) / 2
        originY = (h - gridH) / 2
    }

    var isValid: Bool { cell > 0 && cols > 0 && rows > 0 }
}
