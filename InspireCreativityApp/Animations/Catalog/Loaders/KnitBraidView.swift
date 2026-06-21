// catalog-id: ld-knit-braid
import SwiftUI

/// Braiding Threads — three colored strands weave over and under each other in a
/// continuous plait that scrolls upward. Per-crossing over/under z-order falls out
/// of a helix projection: horizontal position uses sin(θ) while depth uses cos(θ),
/// so at any crossing (equal sin) the two strands have opposite cos and the
/// front/back swap lands exactly on the crossing point. Self-driving via
/// TimelineView(.animation); `demo` and the real component render the same braid
/// because the spec marks this interaction as "auto".
struct KnitBraidView: View {
    var demo: Bool = false

    var body: some View {
        // Both branches render the identical self-driving braid (interaction: auto).
        KnitBraidView_BraidCanvas()
    }
}

// MARK: - Live braid

private struct KnitBraidView_BraidCanvas: View {
    // Three bright cord colors on the dark catalog background, stored as RGB
    // components so depth-shading is a plain arithmetic op (no Color resolution).
    private let strandRGB: [(r: Double, g: Double, b: Double)] = [
        (0.98, 0.43, 0.39),  // coral
        (0.40, 0.78, 0.98),  // sky
        (0.98, 0.82, 0.38)   // amber
    ]

    private let background = Color(red: 0.039, green: 0.063, blue: 0.078) // #0a1014
    private let strandCount = 3
    private let slices = 84

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                Canvas { context, size in
                    drawBraid(in: &context, size: size, time: t)
                }
                .background(background)
                .clipped()
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
    }

    // MARK: Geometry

    /// Phase for a strand at a given vertical position and time.
    /// k controls wavelength (how many crossings appear); the `-time` term scrolls
    /// the braid upward; the per-strand offset spreads the three strands by 120°.
    private func phase(y: CGFloat, time: Double, strand: Int, height: CGFloat) -> CGFloat {
        let wavelengths: CGFloat = 2.4
        let k: CGFloat = (wavelengths * 2 * .pi) / max(height, 1)
        let scroll = CGFloat(time) * 2.0
        let strandOffset = CGFloat(strand) * (2 * .pi / CGFloat(strandCount))
        return k * y - scroll + strandOffset
    }

    private func xPosition(y: CGFloat, time: Double, strand: Int, size: CGSize) -> CGFloat {
        let theta = phase(y: y, time: time, strand: strand, height: size.height)
        let amplitude = size.width * 0.18
        return size.width / 2 + amplitude * sin(theta)
    }

    /// Depth in [-1, 1]; +1 is frontmost. Drives draw order and brightness.
    private func depth(y: CGFloat, time: Double, strand: Int, height: CGFloat) -> CGFloat {
        cos(phase(y: y, time: time, strand: strand, height: height))
    }

    // MARK: Drawing

    private func drawBraid(in context: inout GraphicsContext, size: CGSize, time: Double) {
        let lineWidth = max(size.width * 0.11, 3)
        // Extend a little past both edges so the scroll never reveals a blank gap.
        let margin = lineWidth * 1.5
        let top = -margin
        let bottom = size.height + margin
        let span = bottom - top
        let dy = span / CGFloat(slices)

        for i in 0..<slices {
            let y0 = top + CGFloat(i) * dy
            // Slight overlap (1.6 * dy) keeps the cords reading continuous, not dashed.
            let y1 = y0 + dy * 1.6
            let yMid = (y0 + y1) / 2

            drawSlice(in: &context,
                      y0: y0, y1: y1, yMid: yMid,
                      size: size, time: time, lineWidth: lineWidth)
        }
    }

    private func drawSlice(in context: inout GraphicsContext,
                           y0: CGFloat, y1: CGFloat, yMid: CGFloat,
                           size: CGSize, time: Double, lineWidth: CGFloat) {
        // Build per-strand segment data for this slice.
        var segments: [(strand: Int, z: CGFloat, p0: CGPoint, p1: CGPoint)] = []
        segments.reserveCapacity(strandCount)

        for s in 0..<strandCount {
            let x0 = xPosition(y: y0, time: time, strand: s, size: size)
            let x1 = xPosition(y: y1, time: time, strand: s, size: size)
            let z = depth(y: yMid, time: time, strand: s, height: size.height)
            segments.append((s,
                             z,
                             CGPoint(x: x0, y: y0),
                             CGPoint(x: x1, y: y1)))
        }

        // Sort ascending by depth so the frontmost (highest cos) strand draws LAST.
        // This is the over/under mechanism — back strands are painted over by front ones.
        segments.sort { $0.z < $1.z }

        for seg in segments {
            drawSegment(in: &context, seg: seg, lineWidth: lineWidth)
        }
    }

    private func drawSegment(in context: inout GraphicsContext,
                             seg: (strand: Int, z: CGFloat, p0: CGPoint, p1: CGPoint),
                             lineWidth: CGFloat) {
        var path = Path()
        path.move(to: seg.p0)
        path.addLine(to: seg.p1)

        // Brightness lifts the front cords; depthFactor in [0, 1].
        let depthFactor = (seg.z + 1) / 2
        let shaded = shadedColor(strand: seg.strand, depthFactor: depthFactor)

        // A faint dark casing under each cord deepens the woven look.
        let casing = StrokeStyle(lineWidth: lineWidth + 2, lineCap: .round)
        context.stroke(path,
                       with: .color(Color(red: 0.02, green: 0.03, blue: 0.04).opacity(0.65)),
                       style: casing)

        let coreStyle = StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        context.stroke(path, with: .color(shaded), style: coreStyle)

        // A thin specular highlight on the frontmost portion adds the textile sheen.
        if depthFactor > 0.6 {
            let highlightWidth = lineWidth * 0.32
            let hStyle = StrokeStyle(lineWidth: highlightWidth, lineCap: .round)
            let hOpacity = (depthFactor - 0.6) / 0.4
            context.stroke(path,
                           with: .color(Color.white.opacity(0.45 * hOpacity)),
                           style: hStyle)
        }
    }

    /// Darken cords toward the back, brighten toward the front.
    private func shadedColor(strand: Int, depthFactor: CGFloat) -> Color {
        // Map depthFactor [0,1] -> brightness multiplier [0.45, 1.15], clamped.
        let m = Double(0.45 + depthFactor * 0.70)
        let base = strandRGB[strand]
        let r = min(base.r * m, 1)
        let g = min(base.g * m, 1)
        let b = min(base.b * m, 1)
        return Color(red: r, green: g, blue: b)
    }
}
