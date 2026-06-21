// catalog-id: bg-hex-pulse
import SwiftUI

// MARK: - Hex Pulse
// A tight honeycomb of hexagon cells whose scale + brightness pulse in
// expanding rings radiating from the tile center. A glowing wave washes
// outward across the tessellation and fades toward the edges.
//
// interaction == "auto": both the demo tile and the detail view show the
// same self-driving radial pulse — there is no gesture in this piece.
struct HexPulseView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                HexPulseView_HexPulseCanvas(time: t, size: geo.size)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.039, green: 0.039, blue: 0.047))
        .clipped()
    }
}

// MARK: - Canvas renderer

private struct HexPulseView_HexPulseCanvas: View {
    let time: Double
    let size: CGSize

    // ~3.2s loop for the radial wave.
    private let loopPeriod: Double = 3.2
    // Target columns across the width (honeycomb stays dense but capped).
    private let targetColumns: Int = 8

    var body: some View {
        Canvas { context, canvasSize in
            draw(in: &context, canvasSize: canvasSize)
        }
        .drawingGroup()
    }

    private func draw(in context: inout GraphicsContext, canvasSize: CGSize) {
        let layout = HexPulseView_HexLayout(size: canvasSize, targetColumns: targetColumns)
        let center = CGPoint(x: canvasSize.width / 2.0, y: canvasSize.height / 2.0)

        // Max distance used for both wave phase delay and edge fade.
        let maxDist = max(hypot(canvasSize.width, canvasSize.height) / 2.0, 1.0)

        // Continuous phase advancing once per loop period.
        let phase: Double = (time / loopPeriod) * 2.0 * .pi
        // How tightly the wave wraps from center to edge (rings).
        let radialFreq: Double = 3.0

        for row in 0..<layout.rows {
            for col in 0..<layout.columns {
                let c = layout.cellCenter(row: row, col: col)
                let dist = hypot(Double(c.x - center.x), Double(c.y - center.y))
                let normDist = min(dist / maxDist, 1.0)

                let wave = waveValue(normDist: normDist, phase: phase, radialFreq: radialFreq)
                let edge = edgeFade(normDist: normDist)

                let scale = cellScale(wave: wave)
                let opacity = cellOpacity(wave: wave, edge: edge)
                let color = cellColor(wave: wave)

                drawHex(
                    in: &context,
                    center: c,
                    radius: layout.hexRadius * scale,
                    color: color,
                    opacity: opacity
                )
            }
        }
    }

    // MARK: Per-cell math (kept small for type-checker hygiene)

    /// 0…1 brightness wave: bright ring travels outward as phase advances.
    private func waveValue(normDist: Double, phase: Double, radialFreq: Double) -> Double {
        let s = sin(phase - normDist * radialFreq * .pi)
        return 0.5 + 0.5 * s
    }

    /// Scale floored so a cell never collapses to nothing.
    private func cellScale(wave: Double) -> Double {
        let minScale: Double = 0.58
        let maxScale: Double = 1.0
        return minScale + (maxScale - minScale) * wave
    }

    /// Opacity floored AND edge-faded; never fully transparent near center.
    private func cellOpacity(wave: Double, edge: Double) -> Double {
        let minOpacity: Double = 0.30
        let maxOpacity: Double = 1.0
        let base = minOpacity + (maxOpacity - minOpacity) * wave
        return base * edge
    }

    /// Interpolate fill from a dim teal to a bright cyan glow (no .brightness clip).
    private func cellColor(wave: Double) -> Color {
        let dim = (r: 0.07, g: 0.20, b: 0.28)
        let lit = (r: 0.42, g: 0.92, b: 1.0)
        let r = dim.r + (lit.r - dim.r) * wave
        let g = dim.g + (lit.g - dim.g) * wave
        let b = dim.b + (lit.b - dim.b) * wave
        return Color(red: r, green: g, blue: b)
    }

    /// Radial edge fade: full near center, dimming toward the boundary,
    /// but kept above a floor so edge cells stay faintly legible.
    private func edgeFade(normDist: Double) -> Double {
        let floor: Double = 0.22
        let fade = 1.0 - normDist * normDist
        return floor + (1.0 - floor) * max(fade, 0.0)
    }

    // MARK: Hexagon drawing

    private func drawHex(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        color: Color,
        opacity: Double
    ) {
        guard radius > 0.5 else { return }
        let path = hexPath(center: center, radius: radius)
        context.fill(path, with: .color(color.opacity(opacity)))
        // Crisp seam stroke for the HUD / honeycomb read.
        context.stroke(
            path,
            with: .color(Color(red: 0.55, green: 0.95, blue: 1.0).opacity(opacity * 0.35)),
            lineWidth: 0.75
        )
    }

    /// Pointy-top hexagon path centered at `center`.
    private func hexPath(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        for i in 0..<6 {
            let angle = (Double(i) * 60.0 - 90.0) * .pi / 180.0
            let x = center.x + radius * CGFloat(cos(angle))
            let y = center.y + radius * CGFloat(sin(angle))
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Honeycomb layout

/// Derives a pointy-top honeycomb packing from the available size.
private struct HexPulseView_HexLayout {
    let hexRadius: CGFloat
    let columns: Int
    let rows: Int

    private let horizontalSpacing: CGFloat
    private let verticalSpacing: CGFloat
    private let originX: CGFloat
    private let originY: CGFloat

    init(size: CGSize, targetColumns: Int) {
        // Floor dimensions to a positive minimum so radius > 0 is guaranteed.
        // GeometryReader can report .zero on a first/transition pass; without
        // this, radius == 0 makes `Int(ceil(h / 0))` an infinity/NaN trap.
        let w = max(size.width, 1.0)
        let h = max(size.height, 1.0)
        let cols = max(targetColumns, 3)
        // Pointy-top hex: width = sqrt(3) * radius. Pack columns across width.
        let hexWidth = w / CGFloat(cols)
        let radius = hexWidth / CGFloat(3.0.squareRoot())

        self.hexRadius = radius
        self.columns = cols + 1 // overscan one column for full bleed
        self.horizontalSpacing = hexWidth
        // Pointy-top vertical packing: rows step by 0.75 * height; height = 2*radius.
        self.verticalSpacing = radius * 1.5

        let rowCount = Int(ceil(h / (radius * 1.5))) + 2
        self.rows = max(rowCount, 3)

        // Center the grid; alternate-row offset handled in cellCenter.
        self.originX = 0
        self.originY = 0
    }

    /// Pointy-top honeycomb: odd rows shifted right by half a column.
    func cellCenter(row: Int, col: Int) -> CGPoint {
        let rowOffset: CGFloat = (row % 2 == 0) ? 0 : horizontalSpacing / 2.0
        let x = originX + CGFloat(col) * horizontalSpacing + rowOffset
        let y = originY + CGFloat(row) * verticalSpacing
        return CGPoint(x: x, y: y)
    }
}
