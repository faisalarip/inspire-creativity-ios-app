// catalog-id: nav-inkbleed-segment
import SwiftUI

/// Ink Bleed Segment — a segmented control where tapping a segment drops a spot
/// of ink that organically bleeds outward to fill exactly that segment's bounds
/// with a feathered, slightly jittering edge, while the previously-selected
/// segment's ink simultaneously drains away.
///
/// Rendering is done with `Canvas` clipped per-segment. Fill progress is a *pure
/// function of time* computed inside a `TimelineView(.animation)` render closure
/// (Canvas does not interpolate `withAnimation`-driven state), so the bleed tweens
/// smoothly in both the interactive and the self-driving demo modes.
struct InkbleedSegmentView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            InkbleedSegmentView_InkbleedSegmentControl(demo: demo, size: geo.size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Control

private struct InkbleedSegmentView_InkbleedSegmentControl: View {
    let demo: Bool
    let size: CGSize

    private let labels = ["Ink", "Bleed", "Flow"]

    /// The currently committed selection.
    @State private var selectedIndex: Int = 0
    /// Fill values captured at the moment the last transition began.
    @State private var fromFills: [Double] = [1, 0, 0]
    /// When the current transition started (TimelineView clock).
    @State private var transitionStart: Date = .distantPast
    /// Origins (0...1 within each segment) of the ink drop per segment.
    @State private var origins: [CGPoint]

    /// Duration of one bleed transition.
    private let transitionDuration: Double = 0.45
    /// Demo dwell per segment.
    private let demoDwell: Double = 1.0

    init(demo: Bool, size: CGSize) {
        self.demo = demo
        self.size = size
        _origins = State(initialValue: Array(repeating: CGPoint(x: 0.5, y: 0.5), count: 3))
    }

    var body: some View {
        let metrics = InkbleedSegmentView_Metrics(size: size, count: labels.count)

        TimelineView(.animation) { timeline in
            let now = timeline.date
            ZStack {
                background(metrics: metrics)
                inkCanvas(now: now, metrics: metrics)
                labelsOverlay(now: now, metrics: metrics)
            }
            .frame(width: metrics.width, height: metrics.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(RoundedRectangle(cornerRadius: 24))
    }

    // MARK: Layers

    private func background(metrics: InkbleedSegmentView_Metrics) -> some View {
        let shape = RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
        return shape
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.93, green: 0.91, blue: 0.86),
                        Color(red: 0.88, green: 0.85, blue: 0.79)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay(
                shape.stroke(Color(red: 0.74, green: 0.70, blue: 0.62), lineWidth: 1)
            )
            .frame(width: metrics.width, height: metrics.height)
    }

    private func inkCanvas(now: Date, metrics: InkbleedSegmentView_Metrics) -> some View {
        let fills = currentFills(now: now)
        let t = now.timeIntervalSinceReferenceDate
        return Canvas { ctx, _ in
            for i in 0..<labels.count {
                let progress = fills[i]
                guard progress > 0.001 else { continue }
                let rect = metrics.segmentRect(i)
                drawBlob(in: &ctx, rect: rect, progress: progress,
                         origin: origin(i), time: t, seed: Double(i),
                         cornerRadius: metrics.innerCornerRadius)
            }
        }
        .frame(width: metrics.width, height: metrics.height)
    }

    private func labelsOverlay(now: Date, metrics: InkbleedSegmentView_Metrics) -> some View {
        let fills = currentFills(now: now)
        return ZStack {
            ForEach(0..<labels.count, id: \.self) { i in
                segmentLabel(index: i, fill: fills[i], metrics: metrics)
            }
        }
        .frame(width: metrics.width, height: metrics.height)
        .contentShape(Rectangle())
        .gesture(tapGesture(metrics: metrics))
    }

    private func segmentLabel(index i: Int, fill: Double, metrics: InkbleedSegmentView_Metrics) -> some View {
        let rect = metrics.segmentRect(i)
        // Label flips from dark (on paper) to near-white (on ink) as the fill rises.
        let inkAmount = min(1.0, fill * 1.15)
        let textColor = Color(
            red: 0.12 + 0.84 * inkAmount,
            green: 0.13 + 0.83 * inkAmount,
            blue: 0.16 + 0.80 * inkAmount
        )
        return Text(labels[i])
            .font(.system(size: metrics.fontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(textColor)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .shadow(color: Color.black.opacity(0.18 * inkAmount), radius: 1, y: 0.5)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }

    // MARK: Ink drawing

    private func drawBlob(in ctx: inout GraphicsContext,
                          rect: CGRect,
                          progress: Double,
                          origin: CGPoint,
                          time: Double,
                          seed: Double,
                          cornerRadius: CGFloat) {
        var layer = ctx
        // 1. Clip to this segment's rounded rect — ink can never spill into neighbours.
        let segClip = Path(roundedRect: rect, cornerRadius: cornerRadius, style: .continuous)
        layer.clip(to: segClip)

        let center = CGPoint(
            x: rect.minX + origin.x * rect.width,
            y: rect.minY + origin.y * rect.height
        )
        // Reach the far diagonal so progress == 1 floods every corner.
        let maxReach = hypot(rect.width, rect.height)
        let baseRadius = CGFloat(progress) * maxReach * 1.04
        guard baseRadius > 0.5 else { return }

        // Build the wobbly front. `peak` is its maximum radial extent so the
        // feather can be aimed exactly at the irregular rim.
        let wobble = wobblyPath(center: center, radius: baseRadius,
                                time: time, seed: seed)

        // 2. Intersect the clip with the wobbly blob → containment AND an irregular,
        //    organic boundary (a radial gradient alone is radially symmetric).
        layer.clip(to: wobble.path)
        // 3. Soften that irregular cut so it reads as wet ink, not a hard stamp.
        //    (blur is added AFTER both clips, so it cannot bleed past the segment.)
        layer.addFilter(.blur(radius: max(0.6, baseRadius * 0.045)))

        let inkCore = Color(red: 0.07, green: 0.09, blue: 0.13)
        let inkEdge = Color(red: 0.10, green: 0.13, blue: 0.20)

        // 4. Feathered fill: dense core → translucent rim, with the rim landing at
        //    the wobbly edge (endRadius == path peak), so the feather is the boundary.
        let gradient = Gradient(stops: [
            .init(color: inkCore, location: 0.0),
            .init(color: inkCore, location: 0.66),
            .init(color: inkEdge.opacity(0.9), location: 0.85),
            .init(color: inkEdge.opacity(0.45), location: 0.95),
            .init(color: inkEdge.opacity(0.0), location: 1.0)
        ])
        let shading = GraphicsContext.Shading.radialGradient(
            gradient,
            center: center,
            startRadius: 0,
            endRadius: max(wobble.peak, 1)
        )
        // Fill the whole segment rect; the wobbly clip shapes it, the gradient feathers it.
        layer.fill(segClip, with: shading)

        // A few soaking satellite droplets near the front for organic bleed.
        drawSatellites(in: &layer, center: center, radius: baseRadius,
                       time: time, seed: seed, color: inkEdge)
    }

    /// A closed, time-animated wobbly circle plus its maximum radial extent.
    private func wobblyPath(center: CGPoint, radius: CGFloat,
                            time: Double, seed: Double) -> (path: Path, peak: CGFloat) {
        var path = Path()
        let steps = 48
        let amp = 0.08 + 0.025 * sin(time * 0.9 + seed)   // breathing edge amplitude
        var peak: CGFloat = radius
        for s in 0...steps {
            let frac = Double(s) / Double(steps)
            let angle = frac * 2 * Double.pi
            // Layered sine lobes (time-based, never re-seeded randomness).
            let w = 1.0
                + amp * sin(angle * 3 + time * 1.6 + seed * 1.7)
                + amp * 0.6 * sin(angle * 5 - time * 1.1 + seed)
                + amp * 0.4 * sin(angle * 8 + time * 0.7)
            let r = radius * CGFloat(max(0.2, w))
            if r > peak { peak = r }
            let p = CGPoint(
                x: center.x + r * CGFloat(cos(angle)),
                y: center.y + r * CGFloat(sin(angle))
            )
            if s == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return (path, peak)
    }

    private func drawSatellites(in ctx: inout GraphicsContext,
                                center: CGPoint, radius: CGFloat,
                                time: Double, seed: Double, color: Color) {
        guard radius > 6 else { return }
        let count = 5
        for k in 0..<count {
            let a = Double(k) / Double(count) * 2 * Double.pi + seed
            let drift = 0.78 + 0.16 * sin(time * 1.3 + Double(k) * 2.1 + seed)
            let dr = radius * CGFloat(drift)
            let p = CGPoint(
                x: center.x + dr * CGFloat(cos(a + time * 0.25)),
                y: center.y + dr * CGFloat(sin(a + time * 0.25))
            )
            let dotR = radius * 0.06 * CGFloat(0.7 + 0.4 * sin(time * 2 + Double(k)))
            let dot = Path(ellipseIn: CGRect(x: p.x - dotR, y: p.y - dotR,
                                             width: dotR * 2, height: dotR * 2))
            ctx.fill(dot, with: .color(color.opacity(0.35)))
        }
    }

    // MARK: Fill computation (time-driven)

    private func currentFills(now: Date) -> [Double] {
        if demo { return demoFills(now: now) }
        return interactiveFills(now: now)
    }

    private func interactiveFills(now: Date) -> [Double] {
        let elapsed = now.timeIntervalSinceReferenceDate
            - transitionStart.timeIntervalSinceReferenceDate
        let raw = elapsed / transitionDuration
        let t = min(1.0, max(0.0, raw))
        let eased = easeOut(t)
        var result = [Double](repeating: 0, count: labels.count)
        for i in 0..<labels.count {
            let target: Double = (i == selectedIndex) ? 1.0 : 0.0
            let from = i < fromFills.count ? fromFills[i] : 0
            result[i] = from + (target - from) * eased
        }
        return result
    }

    /// Self-driving fills, computed purely from the clock — no state mutation.
    /// Each segment dwells `demoDwell`; the leading `transitionDuration` of every
    /// dwell tweens the new segment up and the previous one down.
    private func demoFills(now: Date) -> [Double] {
        let period = demoDwell * Double(labels.count)
        let phase = now.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: period)
        let slot = Int(phase / demoDwell)                 // current segment index
        let prev = (slot - 1 + labels.count) % labels.count
        let localT = phase - Double(slot) * demoDwell     // time within this dwell
        let eased = easeOut(min(1.0, localT / transitionDuration))
        var result = [Double](repeating: 0, count: labels.count)
        for i in 0..<labels.count {
            if i == slot {
                result[i] = eased
            } else if i == prev {
                result[i] = 1 - eased
            } else {
                result[i] = 0
            }
        }
        return result
    }

    /// Demo ink origin varies per segment so the bleed never looks mechanical.
    private func demoOrigin(_ i: Int) -> CGPoint {
        let xs: [CGFloat] = [0.28, 0.5, 0.72]
        return CGPoint(x: xs[i % xs.count], y: 0.5)
    }

    private func origin(_ i: Int) -> CGPoint {
        demo ? demoOrigin(i) : origins[i]
    }

    private func easeOut(_ t: Double) -> Double {
        1 - pow(1 - t, 3)
    }

    // MARK: Interaction

    private func tapGesture(metrics: InkbleedSegmentView_Metrics) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                guard !demo else { return }
                let i = metrics.segmentIndex(forX: value.location.x)
                commit(to: i, at: value.location, metrics: metrics)
            }
    }

    private func commit(to index: Int, at location: CGPoint, metrics: InkbleedSegmentView_Metrics) {
        guard index != selectedIndex else { return }
        let now = Date()
        // Snapshot the fills as they are right now so the new transition tweens
        // smoothly from the live state (handles rapid re-taps mid-bleed).
        fromFills = currentFills(now: now)
        // Ink origin = local tap point inside the tapped segment (fallback center).
        let rect = metrics.segmentRect(index)
        let ox = rect.width > 0 ? (location.x - rect.minX) / rect.width : 0.5
        let oy = rect.height > 0 ? (location.y - rect.minY) / rect.height : 0.5
        origins[index] = CGPoint(
            x: min(0.95, max(0.05, ox)),
            y: min(0.9, max(0.1, oy))
        )
        selectedIndex = index
        transitionStart = now
    }
}

// MARK: - Layout metrics

private struct InkbleedSegmentView_Metrics {
    let width: CGFloat
    let height: CGFloat
    let count: Int
    let inset: CGFloat
    let cornerRadius: CGFloat

    init(size: CGSize, count: Int) {
        // Clamp to a control-shaped band so it reads well in both a 120pt tile
        // and a large detail area.
        let w = max(40, size.width)
        let h = max(28, size.height)
        let bandHeight = min(h, max(40, w * 0.32))
        self.width = w
        self.height = min(h, bandHeight)
        self.count = max(1, count)
        self.inset = max(3, self.height * 0.08)
        self.cornerRadius = min(self.height / 2, 26)
    }

    var innerWidth: CGFloat { width - inset * 2 }
    var innerHeight: CGFloat { height - inset * 2 }
    var segmentWidth: CGFloat { innerWidth / CGFloat(count) }
    var innerCornerRadius: CGFloat { max(0, cornerRadius - inset) }

    var fontSize: CGFloat {
        max(9, min(18, height * 0.34))
    }

    func segmentRect(_ i: Int) -> CGRect {
        CGRect(
            x: inset + segmentWidth * CGFloat(i),
            y: inset,
            width: segmentWidth,
            height: innerHeight
        )
    }

    func segmentIndex(forX x: CGFloat) -> Int {
        let local = x - inset
        let raw = Int(local / max(1, segmentWidth))
        return min(count - 1, max(0, raw))
    }
}
