// catalog-id: bg-contour-topo
import SwiftUI

/// Contour Topo — stacked topographic ridgelines generated from a sum of
/// slowly phase-shifting sine waves. Each ridge fills downward with an opaque
/// dark band and is stroked with a bright edge; ridges are drawn back-to-front
/// so near ridges occlude far ones, producing real relief depth. The whole map
/// morphs and scrolls like wind over dunes.
///
/// Interaction is "auto": both demo and live modes run the same self-driving
/// TimelineView loop. No touch required — the relief never sits still.
struct ContourTopoView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { _ in
            TimelineView(.animation) { timeline in
                let t: Double = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    drawScene(context: &context, size: size, time: t)
                }
                .drawingGroup()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(groundColor)
        .clipped()
    }

    // MARK: - Layout constants

    /// Number of stacked ridgelines (modest count keeps Canvas cheap per spec).
    private let ridgeCount: Int = 18
    /// Horizontal sample stride in points (coarse for smoothness).
    private let sampleStride: CGFloat = 7.0

    // MARK: - Palette (dark topo ground → cyan ridge edges)

    private var groundColor: Color {
        Color(red: 0.039, green: 0.039, blue: 0.047)
    }

    private func bandColor(for fraction: Double) -> Color {
        // Nearer ridges (fraction → 1) are slightly lighter/warmer to push depth.
        let base: Double = 0.05
        let lift: Double = 0.10 * fraction
        return Color(
            red: base + lift * 0.55,
            green: base + lift * 0.85,
            blue: base + lift * 1.0 + 0.02
        )
    }

    private func strokeColor(for fraction: Double) -> Color {
        // Bright top edge; near ridges glow more.
        let intensity: Double = 0.35 + 0.55 * fraction
        return Color(
            red: 0.30 * intensity,
            green: 0.78 * intensity,
            blue: 0.92 * intensity
        )
    }

    // MARK: - Surface height field

    /// Returns the y position of ridge `line` at horizontal coord `x`.
    /// y = baseline + Σ sin(x·freqᵢ + phaseᵢ + time). Frequencies are scaled to
    /// the view width so the relief reads correctly in a 120pt tile and large area.
    private func surfaceY(_ x: CGFloat, line: Int, size: CGSize, time t: Double) -> CGFloat {
        let width: CGFloat = max(size.width, 1)
        let height: CGFloat = max(size.height, 1)

        // Evenly space ridge baselines down the view, with a little headroom.
        let lineFraction: CGFloat = CGFloat(line) / CGFloat(max(ridgeCount - 1, 1))
        let topInset: CGFloat = height * 0.10
        let baseline: CGFloat = topInset + lineFraction * (height * 0.86)

        // Per-line phase offset so ridges aren't all in lockstep.
        let linePhase: Double = Double(line) * 0.42

        // Normalize x into [0, 2π) cycles across the width.
        let nx: Double = Double(x / width)

        // Three octaves of sine, summed. Each octave has its own spatial
        // frequency, temporal drift speed and amplitude. Amplitudes scale to
        // height so the relief is proportional at any size.
        let h: Double = Double(height)

        let f1: Double = sin(nx * 2.0 * .pi * 1.0 + t * 0.35 + linePhase)
        let a1: Double = h * 0.052

        let f2: Double = sin(nx * 2.0 * .pi * 2.3 - t * 0.22 + linePhase * 1.7)
        let a2: Double = h * 0.026

        let f3: Double = sin(nx * 2.0 * .pi * 4.1 + t * 0.5 + linePhase * 0.6)
        let a3: Double = h * 0.013

        let displacement: Double = f1 * a1 + f2 * a2 + f3 * a3
        return baseline + CGFloat(displacement)
    }

    // MARK: - Drawing

    private func drawScene(context: inout GraphicsContext, size: CGSize, time t: Double) {
        guard size.width > 1, size.height > 1 else { return }
        // Draw back-to-front: farthest (topmost) ridge first so nearer ridges,
        // drawn later, occlude it. This overlap is what reads as relief depth.
        for line in 0..<ridgeCount {
            drawRidge(line: line, context: &context, size: size, time: t)
        }
    }

    private func drawRidge(line: Int, context: inout GraphicsContext, size: CGSize, time t: Double) {
        let fraction: Double = Double(line) / Double(max(ridgeCount - 1, 1))

        // Build the ridge top edge as a sampled path.
        var edge = Path()
        var x: CGFloat = 0
        let endX: CGFloat = size.width
        var first: Bool = true
        while x <= endX {
            let y: CGFloat = surfaceY(x, line: line, size: size, time: t)
            let point = CGPoint(x: x, y: y)
            if first {
                edge.move(to: point)
                first = false
            } else {
                edge.addLine(to: point)
            }
            x += sampleStride
        }
        // Ensure we reach the exact right edge.
        let lastY: CGFloat = surfaceY(endX, line: line, size: size, time: t)
        edge.addLine(to: CGPoint(x: endX, y: lastY))

        // Fill band: close the edge path down to the bottom of the view so the
        // band is opaque and occludes ridges drawn behind (above) it.
        var band = edge
        band.addLine(to: CGPoint(x: endX, y: size.height + 4))
        band.addLine(to: CGPoint(x: 0, y: size.height + 4))
        band.closeSubpath()

        context.fill(band, with: .color(bandColor(for: fraction)))

        // Stroke the bright top edge on top of the band.
        let lineWidth: CGFloat = 0.8 + 1.4 * CGFloat(fraction)
        context.stroke(
            edge,
            with: .color(strokeColor(for: fraction)),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )
    }
}
