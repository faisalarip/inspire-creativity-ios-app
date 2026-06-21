// catalog-id: tx-handwriting
import SwiftUI

// MARK: - Handwriting Stroke
// A script headline draws itself stroke by stroke as if written by an invisible
// pen: a trimmed Path reveal with a small ink-nib dot that leads the line and
// lifts off between letters. Both demo and interactive modes are the same
// self-driving draw-on loop (interactiveSpec: "auto — same as previewLoop"),
// so everything is driven from a single TimelineView(.animation) progress value
// to keep the stroke reveal and the nib position perfectly locked.

public struct HandwritingView: View {
    public var demo: Bool = false

    public init(demo: Bool = false) {
        self.demo = demo
    }

    public var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        // ~3.4s loop: draw, brief hold at full, gentle fade of the bright ink,
        // then restart. The ghost guideline is always visible so no frame is
        // ever blank.
        let period: Double = 3.4
        ZStack {
            backdrop(in: size)
            TimelineView(.animation) { timeline in
                let t: Double = timeline.date.timeIntervalSinceReferenceDate
                let loop: Double = t.truncatingRemainder(dividingBy: period) / period
                let progress: CGFloat = drawProgress(for: loop)
                let inkOpacity: Double = inkFade(for: loop)
                HandwritingView_HandwritingCanvas(
                    progress: progress,
                    inkOpacity: inkOpacity,
                    canvasSize: size
                )
            }
        }
    }

    // MARK: Static backdrop

    private func backdrop(in size: CGSize) -> some View {
        let dim: CGFloat = min(size.width, size.height)
        return ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.06, blue: 0.10),
                    Color(red: 0.02, green: 0.02, blue: 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // faint ruled baseline so the script reads as written on paper
            HandwritingView_RuledLine()
                .stroke(
                    Color(red: 1.0, green: 1.0, blue: 1.0).opacity(0.05),
                    style: StrokeStyle(lineWidth: max(0.6, dim * 0.006))
                )
        }
    }

    // MARK: Progress shaping

    // Maps the raw 0..1 loop into a draw curve that:
    //  - eases the pen across the page (ease-in-out),
    //  - holds at full for a short beat,
    //  - never returns a degenerate 0 (clamped to a small floor).
    private func drawProgress(for loop: Double) -> CGFloat {
        let drawPortion: Double = 0.78   // fraction of the loop spent drawing
        if loop >= drawPortion {
            return 1.0                   // hold + fade phase: stay fully drawn
        }
        let x: Double = loop / drawPortion
        let eased: Double = x * x * (3.0 - 2.0 * x) // smoothstep
        return CGFloat(max(0.02, eased))
    }

    // The bright ink layer gently fades out at the very end of the loop, so the
    // restart is a soft dissolve rather than a hard blank cut.
    private func inkFade(for loop: Double) -> Double {
        let fadeStart: Double = 0.9
        if loop < fadeStart { return 1.0 }
        let x: Double = (loop - fadeStart) / (1.0 - fadeStart)
        return max(0.0, 1.0 - x)
    }
}

// MARK: - Handwriting canvas

private struct HandwritingView_HandwritingCanvas: View {
    let progress: CGFloat
    let inkOpacity: Double
    let canvasSize: CGSize

    var body: some View {
        let dim: CGFloat = min(canvasSize.width, canvasSize.height)
        let lineWidth: CGFloat = max(2.0, dim * 0.022)
        let path: Path = HandwritingView_ScriptSignature.path(in: canvasSize)
        let nib: CGPoint = nibPoint(in: path)

        ZStack {
            ghostLayer(path: path, lineWidth: lineWidth)
            inkLayer(path: path, lineWidth: lineWidth)
            nibDot(at: nib, lineWidth: lineWidth)
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }

    // MARK: Layers

    // Always-visible faint full stroke: the guideline the pen "follows".
    private func ghostLayer(path: Path, lineWidth: CGFloat) -> some View {
        path.stroke(
            Color(red: 0.55, green: 0.62, blue: 0.85).opacity(0.14),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )
    }

    // The bright drawn-so-far ink, with a soft glow.
    private func inkLayer(path: Path, lineWidth: CGFloat) -> some View {
        let ink: Color = Color(red: 0.75, green: 0.88, blue: 1.0)
        return path
            .trimmedPath(from: 0, to: progress)
            .stroke(
                ink,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
            .shadow(color: ink.opacity(0.55), radius: lineWidth * 0.8)
            .opacity(inkOpacity)
    }

    // The traveling ink-nib dot at the current tip of the stroke.
    private func nibDot(at point: CGPoint, lineWidth: CGFloat) -> some View {
        let r: CGFloat = lineWidth * 0.9
        let core: Color = Color(red: 0.95, green: 0.98, blue: 1.0)
        let halo: Color = Color(red: 0.65, green: 0.82, blue: 1.0)
        return ZStack {
            Circle()
                .fill(halo.opacity(0.45))
                .frame(width: r * 2.6, height: r * 2.6)
                .blur(radius: r * 0.6)
            Circle()
                .fill(core)
                .frame(width: r * 1.4, height: r * 1.4)
                .shadow(color: halo.opacity(0.8), radius: r)
        }
        .position(point)
        .opacity(inkOpacity)
    }

    // MARK: Nib position

    // The tip of the drawn stroke. trimmedPath(...).currentPoint is nil at
    // progress ≈ 0 and across subpath "pen lifts", so fall back to a real
    // on-path point (the path's first move) to keep the nib on screen on
    // every frame rather than the path's end.
    private func nibPoint(in path: Path) -> CGPoint {
        if let p = path.trimmedPath(from: 0, to: progress).currentPoint {
            return p
        }
        if let first = path.boundingRect.isNull ? nil : Optional(path.boundingRect.origin) {
            return first
        }
        return path.cgPath.currentPoint
    }
}

// MARK: - Ruled baseline (decorative paper line)

private struct HandwritingView_RuledLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let y: CGFloat = rect.midY + rect.height * 0.20
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.06, y: y))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.06, y: y))
        return p
    }
}

// MARK: - Script signature path

// A stylized cursive "hello" flourish built from normalized 0..1 control points
// scaled to the canvas. Multiple subpaths (move(to:) between letters) create the
// natural "lifts off at each letter's end" — the nib jumps between strokes.
private enum HandwritingView_ScriptSignature {

    // Control points are expressed in a normalized space and mapped into a
    // centered, aspect-aware box so the script stays legible in a 120pt tile
    // and a large detail area alike.
    static func path(in size: CGSize) -> Path {
        let dim: CGFloat = min(size.width, size.height)
        // A wide writing box centered in the available space.
        let boxW: CGFloat = min(size.width * 0.84, dim * 2.6)
        let boxH: CGFloat = boxW * 0.42
        let originX: CGFloat = (size.width - boxW) / 2.0
        let originY: CGFloat = (size.height - boxH) / 2.0

        func pt(_ nx: CGFloat, _ ny: CGFloat) -> CGPoint {
            CGPoint(x: originX + nx * boxW, y: originY + ny * boxH)
        }

        var path = Path()
        appendH(to: &path, pt: pt)
        appendE(to: &path, pt: pt)
        appendDoubleL(to: &path, pt: pt)
        appendO(to: &path, pt: pt)
        appendFlourish(to: &path, pt: pt)
        return path
    }

    private typealias Mapper = (CGFloat, CGFloat) -> CGPoint

    // h: a tall ascender looping down into a hump.
    private static func appendH(to path: inout Path, pt: Mapper) {
        path.move(to: pt(0.04, 0.30))
        path.addCurve(
            to: pt(0.08, 0.80),
            control1: pt(0.10, 0.02),
            control2: pt(0.10, 0.55)
        )
        path.addCurve(
            to: pt(0.16, 0.50),
            control1: pt(0.07, 0.95),
            control2: pt(0.12, 0.40)
        )
        path.addCurve(
            to: pt(0.20, 0.80),
            control1: pt(0.20, 0.58),
            control2: pt(0.21, 0.95)
        )
    }

    // e: a small closed loop.
    private static func appendE(to path: inout Path, pt: Mapper) {
        path.move(to: pt(0.23, 0.62))
        path.addCurve(
            to: pt(0.30, 0.55),
            control1: pt(0.25, 0.48),
            control2: pt(0.32, 0.46)
        )
        path.addCurve(
            to: pt(0.27, 0.82),
            control1: pt(0.29, 0.66),
            control2: pt(0.22, 0.78)
        )
        path.addQuadCurve(
            to: pt(0.34, 0.74),
            control: pt(0.32, 0.86)
        )
    }

    // ll: two ascender loops.
    private static func appendDoubleL(to path: inout Path, pt: Mapper) {
        path.move(to: pt(0.37, 0.80))
        path.addCurve(
            to: pt(0.40, 0.18),
            control1: pt(0.33, 0.45),
            control2: pt(0.36, 0.20)
        )
        path.addCurve(
            to: pt(0.42, 0.80),
            control1: pt(0.44, 0.16),
            control2: pt(0.41, 0.55)
        )

        path.move(to: pt(0.45, 0.80))
        path.addCurve(
            to: pt(0.48, 0.18),
            control1: pt(0.41, 0.45),
            control2: pt(0.44, 0.20)
        )
        path.addCurve(
            to: pt(0.50, 0.80),
            control1: pt(0.52, 0.16),
            control2: pt(0.49, 0.55)
        )
    }

    // o: a round closed loop.
    private static func appendO(to path: inout Path, pt: Mapper) {
        path.move(to: pt(0.55, 0.60))
        path.addCurve(
            to: pt(0.62, 0.62),
            control1: pt(0.55, 0.46),
            control2: pt(0.63, 0.46)
        )
        path.addCurve(
            to: pt(0.56, 0.66),
            control1: pt(0.61, 0.80),
            control2: pt(0.54, 0.80)
        )
        path.addQuadCurve(
            to: pt(0.60, 0.58),
            control: pt(0.56, 0.55)
        )
    }

    // Trailing underline flourish — the signature swoosh.
    private static func appendFlourish(to path: inout Path, pt: Mapper) {
        path.move(to: pt(0.60, 0.58))
        path.addCurve(
            to: pt(0.92, 0.74),
            control1: pt(0.74, 0.40),
            control2: pt(0.82, 0.92)
        )
        path.addQuadCurve(
            to: pt(0.66, 0.88),
            control: pt(0.99, 0.62)
        )
    }
}
