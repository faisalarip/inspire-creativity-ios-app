// catalog-id: ld-sand-hourglass
import SwiftUI

/// Sand Hourglass — grains stream from the source chamber through the pinched
/// neck and pile into a sloped heap below; when the source empties the whole
/// glass flips 180° (auto, or on tap when interactive) and the flow reverses.
///
/// Architecture: the sim is a pure function of time. `fill` (0…1) is derived
/// from `now - lastFlip`. The ONLY mutating state is `flipCount` + `lastFlip`,
/// changed from `.onChange` (outside the view-update pass). A single
/// `sourceIsTop` boolean (parity of `flipCount`) drives the draining cone, the
/// growing heap, and the grain direction together so they can never desync.
struct SandHourglassView: View {
    var demo: Bool = false

    // Mutating state — kept minimal and changed only outside body.
    @State private var flipCount: Int = 0
    @State private var lastFlip: Date = .distantPast
    @State private var didAppear: Bool = false

    // Drain duration for one chamber, in seconds.
    private let period: Double = 3.0

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let now = timeline.date
                let fill = drainFraction(now: now)
                let elapsed = elapsedSinceFlip(now: now)

                content(in: geo.size, now: now, fill: fill)
                    // Auto-flip when the source chamber empties. Fired from
                    // onChange so we never mutate state inside the timeline body.
                    .onChange(of: elapsed >= period) { _, full in
                        guard didAppear, full else { return }
                        performFlip(at: now)
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Seed the clock on first frame so a stale init date can't trigger
            // an immediate phantom flip.
            if !didAppear {
                lastFlip = Date()
                didAppear = true
            }
        }
    }

    // MARK: - Derived sim values

    private func elapsedSinceFlip(now: Date) -> Double {
        guard didAppear else { return 0 }
        return max(0, now.timeIntervalSince(lastFlip))
    }

    /// Eased drain fraction 0…1 for the current chamber.
    private func drainFraction(now: Date) -> Double {
        let raw = min(1.0, elapsedSinceFlip(now: now) / period)
        // Ease-in-out so the stream feels like it tapers at the start/end.
        return raw * raw * (3.0 - 2.0 * raw)
    }

    private func performFlip(at now: Date) {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) {
            flipCount += 1
        }
        lastFlip = now
    }

    // MARK: - Composition

    @ViewBuilder
    private func content(in size: CGSize, now: Date, fill: Double) -> some View {
        let metrics = SandHourglassView_SandHourglassMetrics(size: size)
        let sourceIsTop = (flipCount % 2 == 0)

        ZStack {
            backdrop

            ZStack {
                glassBody(metrics: metrics)
                sandLayer(metrics: metrics, fill: fill, sourceIsTop: sourceIsTop)
                grainStream(metrics: metrics, fill: fill, sourceIsTop: sourceIsTop, now: now)
                glassFrame(metrics: metrics)
                neckBand(metrics: metrics)
            }
            // The whole assembly flips in-plane 180° per flip. 2D rotation
            // (not 3D about Y) avoids the horizontal mirror that would warp the
            // asymmetric heap.
            .rotationEffect(.degrees(Double(flipCount) * 180.0))
            .frame(width: metrics.glassWidth, height: metrics.glassHeight)

            capPair(metrics: metrics)
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .modifier(SandHourglassView_TapFlip(enabled: !demo) { performFlip(at: now) })
    }

    private var backdrop: some View {
        RadialGradient(
            colors: [
                Color(red: 0.09, green: 0.12, blue: 0.16),
                Color(red: 0.04, green: 0.05, blue: 0.07)
            ],
            center: .center,
            startRadius: 2,
            endRadius: 220
        )
    }

    // MARK: - Glass

    private func glassBody(metrics: SandHourglassView_SandHourglassMetrics) -> some View {
        SandHourglassView_SandHourglassGlassShape(metrics: metrics)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.16, green: 0.20, blue: 0.26).opacity(0.55),
                        Color(red: 0.08, green: 0.11, blue: 0.15).opacity(0.35)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private func glassFrame(metrics: SandHourglassView_SandHourglassMetrics) -> some View {
        SandHourglassView_SandHourglassGlassShape(metrics: metrics)
            .stroke(
                LinearGradient(
                    colors: [
                        Color(red: 0.78, green: 0.84, blue: 0.92).opacity(0.85),
                        Color(red: 0.40, green: 0.48, blue: 0.58).opacity(0.65)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: max(1.4, metrics.glassWidth * 0.022)
            )
            // Subtle glassy highlight along one edge.
            .overlay(
                SandHourglassView_SandHourglassGlassShape(metrics: metrics)
                    .trim(from: 0.02, to: 0.20)
                    .stroke(Color.white.opacity(0.35),
                            style: StrokeStyle(lineWidth: max(1, metrics.glassWidth * 0.012),
                                               lineCap: .round))
            )
    }

    private func neckBand(metrics: SandHourglassView_SandHourglassMetrics) -> some View {
        Capsule()
            .fill(Color(red: 0.30, green: 0.36, blue: 0.44).opacity(0.7))
            .frame(width: metrics.neckWidth * 1.8,
                   height: metrics.neckHeight * 0.6)
            .position(x: metrics.midX, y: metrics.midY)
    }

    private func capPair(metrics: SandHourglassView_SandHourglassMetrics) -> some View {
        VStack(spacing: 0) {
            cap(metrics: metrics)
            Spacer(minLength: 0)
            cap(metrics: metrics)
        }
        .frame(width: metrics.glassWidth * 1.04, height: metrics.glassHeight)
    }

    private func cap(metrics: SandHourglassView_SandHourglassMetrics) -> some View {
        RoundedRectangle(cornerRadius: metrics.capHeight * 0.45, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.52, green: 0.36, blue: 0.20),
                        Color(red: 0.32, green: 0.21, blue: 0.11)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: metrics.capHeight)
    }

    // MARK: - Sand (cone + heap)

    @ViewBuilder
    private func sandLayer(metrics: SandHourglassView_SandHourglassMetrics,
                           fill: Double,
                           sourceIsTop: Bool) -> some View {
        let sand = sandGradient
        let remaining = 1.0 - fill

        // Draining cone in the source chamber; growing heap in the dest chamber.
        SandHourglassView_SandHourglassConeShape(metrics: metrics, level: remaining, atTop: sourceIsTop)
            .fill(sand)
            .clipShape(SandHourglassView_SandHourglassGlassShape(metrics: metrics))

        SandHourglassView_SandHourglassHeapShape(metrics: metrics, amount: fill, atTop: !sourceIsTop)
            .fill(sand)
            .clipShape(SandHourglassView_SandHourglassGlassShape(metrics: metrics))
            // soft top edge on the heap
            .overlay(
                SandHourglassView_SandHourglassHeapShape(metrics: metrics, amount: fill, atTop: !sourceIsTop)
                    .stroke(Color(red: 0.98, green: 0.86, blue: 0.55).opacity(0.5),
                            lineWidth: 1)
                    .clipShape(SandHourglassView_SandHourglassGlassShape(metrics: metrics))
            )
    }

    private var sandGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.97, green: 0.82, blue: 0.45),
                Color(red: 0.85, green: 0.62, blue: 0.28)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Falling grains (deterministic per-grain functions of time)

    private func grainStream(metrics: SandHourglassView_SandHourglassMetrics,
                             fill: Double,
                             sourceIsTop: Bool,
                             now: Date) -> some View {
        // Hide the stream only at the very end of a chamber, so a fresh stream
        // is always visible just after the flip.
        let intensity = grainIntensity(fill: fill)
        let t = now.timeIntervalSinceReferenceDate

        return Canvas { ctx, _ in
            guard intensity > 0.01 else { return }
            let count = 26
            // Travel goes from the neck toward the destination floor in LOCAL y.
            let startY = metrics.midY
            // Destination floor in local coords (where the heap sits).
            let destFloor = sourceIsTop ? metrics.bottomFloorY : metrics.topFloorY
            let dir: CGFloat = sourceIsTop ? 1 : -1   // +y down, -y up after flip
            let travel = abs(destFloor - startY)

            for i in 0..<count {
                let seed = Double(i) * 0.61803398875
                let phase = (t * 1.15 + seed).truncatingRemainder(dividingBy: 1.0)
                // progress 0 (neck) → 1 (landing)
                let p = CGFloat(phase)
                // small horizontal jitter scattering around the neck axis
                let wobble = sin((t * 3.0) + seed * 6.28) * Double(metrics.neckWidth) * 0.22
                let x = metrics.midX + CGFloat(wobble) * (0.3 + p * 0.7)
                let y = startY + dir * travel * p
                let r = metrics.neckWidth * 0.10

                let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                let alpha = (0.35 + 0.65 * (1 - p)) * CGFloat(intensity)
                ctx.fill(
                    Path(ellipseIn: rect),
                    with: .color(Color(red: 0.99, green: 0.85, blue: 0.50).opacity(Double(alpha)))
                )
            }
        }
        .frame(width: metrics.glassWidth, height: metrics.glassHeight)
        .allowsHitTesting(false)
    }

    private func grainIntensity(fill: Double) -> Double {
        // Fade the stream in at the start and out as the chamber empties.
        let inRamp = min(1.0, fill / 0.06)
        let outRamp = min(1.0, (1.0 - fill) / 0.06)
        return max(0.0, min(inRamp, outRamp))
    }
}

// MARK: - Tap-to-flip modifier (only active when interactive)

private struct SandHourglassView_TapFlip: ViewModifier {
    let enabled: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        if enabled {
            content.onTapGesture { action() }
        } else {
            content
        }
    }
}

// MARK: - Metrics

private struct SandHourglassView_SandHourglassMetrics {
    let size: CGSize
    let glassWidth: CGFloat
    let glassHeight: CGFloat
    let originX: CGFloat
    let originY: CGFloat

    init(size: CGSize) {
        self.size = size
        let side = min(size.width, size.height)
        // Glass is taller than wide.
        let w = side * 0.62
        let h = side * 0.92
        self.glassWidth = w
        self.glassHeight = h
        self.originX = (size.width - w) / 2
        self.originY = (size.height - h) / 2
    }

    // All coordinates below are in the rotated assembly's local frame, which is
    // sized exactly glassWidth × glassHeight (origin at 0,0 top-left).
    var midX: CGFloat { glassWidth / 2 }
    var midY: CGFloat { glassHeight / 2 }

    var capHeight: CGFloat { glassHeight * 0.06 }
    var topFloorY: CGFloat { capHeight }                 // inside top, just below cap
    var bottomFloorY: CGFloat { glassHeight - capHeight } // inside bottom, above cap
    var chamberHeight: CGFloat { midY - topFloorY }

    var neckWidth: CGFloat { glassWidth * 0.12 }
    var neckHeight: CGFloat { glassHeight * 0.05 }
    var bulbWidth: CGFloat { glassWidth }
}

// MARK: - Glass outline shape

private struct SandHourglassView_SandHourglassGlassShape: Shape {
    let metrics: SandHourglassView_SandHourglassMetrics

    func path(in rect: CGRect) -> Path {
        let m = metrics
        let halfNeck = m.neckWidth / 2
        let halfBulb = m.bulbWidth / 2 - m.bulbWidth * 0.04
        let cx = rect.midX
        let top = m.capHeight * 0.5
        let bot = rect.height - m.capHeight * 0.5
        let midY = rect.midY
        let neckTop = midY - m.neckHeight / 2
        let neckBot = midY + m.neckHeight / 2

        var p = Path()
        // Top-left → curve into neck → bottom-left → bottom-right → curve back up.
        p.move(to: CGPoint(x: cx - halfBulb, y: top))
        // left wall down to neck
        p.addCurve(
            to: CGPoint(x: cx - halfNeck, y: neckTop),
            control1: CGPoint(x: cx - halfBulb, y: top + (neckTop - top) * 0.55),
            control2: CGPoint(x: cx - halfNeck, y: neckTop - (neckTop - top) * 0.30)
        )
        // through neck
        p.addLine(to: CGPoint(x: cx - halfNeck, y: neckBot))
        // neck down to bottom-left
        p.addCurve(
            to: CGPoint(x: cx - halfBulb, y: bot),
            control1: CGPoint(x: cx - halfNeck, y: neckBot + (bot - neckBot) * 0.30),
            control2: CGPoint(x: cx - halfBulb, y: bot - (bot - neckBot) * 0.55)
        )
        // bottom edge
        p.addLine(to: CGPoint(x: cx + halfBulb, y: bot))
        // bottom-right up to neck
        p.addCurve(
            to: CGPoint(x: cx + halfNeck, y: neckBot),
            control1: CGPoint(x: cx + halfBulb, y: bot - (bot - neckBot) * 0.55),
            control2: CGPoint(x: cx + halfNeck, y: neckBot + (bot - neckBot) * 0.30)
        )
        // through neck
        p.addLine(to: CGPoint(x: cx + halfNeck, y: neckTop))
        // neck up to top-right
        p.addCurve(
            to: CGPoint(x: cx + halfBulb, y: top),
            control1: CGPoint(x: cx + halfNeck, y: neckTop - (neckTop - top) * 0.30),
            control2: CGPoint(x: cx + halfBulb, y: top + (neckTop - top) * 0.55)
        )
        p.closeSubpath()
        return p
    }
}

// MARK: - Draining cone (source chamber)

/// A cone of sand hanging from the chamber's outer wall down toward the neck.
/// `level` 1 = chamber full, 0 = empty. `atTop` selects which chamber it lives in.
private struct SandHourglassView_SandHourglassConeShape: Shape {
    let metrics: SandHourglassView_SandHourglassMetrics
    var level: Double
    var atTop: Bool

    var animatableData: Double {
        get { level }
        set { level = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let m = metrics
        let cx = rect.midX
        let lvl = CGFloat(max(0, min(1, level)))
        var p = Path()

        if atTop {
            // Surface drops from the top floor toward the neck as it drains.
            let floor = m.topFloorY
            let neckY = rect.midY - m.neckHeight * 0.4
            let surfaceY = floor + (neckY - floor) * (1 - lvl)
            let halfW = (m.bulbWidth / 2 - m.bulbWidth * 0.06) * (0.18 + 0.82 * lvl)
            p.move(to: CGPoint(x: cx - halfW, y: surfaceY))
            p.addLine(to: CGPoint(x: cx + halfW, y: surfaceY))
            // funnel down to the neck mouth
            p.addLine(to: CGPoint(x: cx + m.neckWidth * 0.4, y: neckY))
            p.addLine(to: CGPoint(x: cx - m.neckWidth * 0.4, y: neckY))
            p.closeSubpath()
        } else {
            let floor = m.bottomFloorY
            let neckY = rect.midY + m.neckHeight * 0.4
            let surfaceY = floor - (floor - neckY) * (1 - lvl)
            let halfW = (m.bulbWidth / 2 - m.bulbWidth * 0.06) * (0.18 + 0.82 * lvl)
            p.move(to: CGPoint(x: cx - halfW, y: surfaceY))
            p.addLine(to: CGPoint(x: cx + halfW, y: surfaceY))
            p.addLine(to: CGPoint(x: cx + m.neckWidth * 0.4, y: neckY))
            p.addLine(to: CGPoint(x: cx - m.neckWidth * 0.4, y: neckY))
            p.closeSubpath()
        }
        return p
    }
}

// MARK: - Growing heap (destination chamber, angle-of-repose slope)

/// A sloped heap rising from the chamber's outer floor. `amount` 0 = empty,
/// 1 = chamber full (which is geometrically the cone-full region rotated 180°,
/// so there is no pop at the flip).
private struct SandHourglassView_SandHourglassHeapShape: Shape {
    let metrics: SandHourglassView_SandHourglassMetrics
    var amount: Double
    var atTop: Bool

    var animatableData: Double {
        get { amount }
        set { amount = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let m = metrics
        let cx = rect.midX
        let amt = CGFloat(max(0, min(1, amount)))
        var p = Path()

        if atTop {
            // Heap grows downward from the top cap floor (chamber is "above" neck).
            let floor = m.topFloorY
            let peakMax = rect.midY - m.neckHeight * 0.4
            let peakY = floor + (peakMax - floor) * amt
            let halfW = (m.bulbWidth / 2 - m.bulbWidth * 0.06) * (0.18 + 0.82 * amt)
            // peak at center pointing toward neck, sloping back up to the cap walls
            p.move(to: CGPoint(x: cx - halfW, y: floor))
            p.addLine(to: CGPoint(x: cx, y: peakY))
            p.addLine(to: CGPoint(x: cx + halfW, y: floor))
            p.closeSubpath()
        } else {
            // Heap grows upward from the bottom cap floor (chamber is "below" neck).
            let floor = m.bottomFloorY
            let peakMax = rect.midY + m.neckHeight * 0.4
            let peakY = floor - (floor - peakMax) * amt
            let halfW = (m.bulbWidth / 2 - m.bulbWidth * 0.06) * (0.18 + 0.82 * amt)
            p.move(to: CGPoint(x: cx - halfW, y: floor))
            p.addLine(to: CGPoint(x: cx, y: peakY))
            p.addLine(to: CGPoint(x: cx + halfW, y: floor))
            p.closeSubpath()
        }
        return p
    }
}
