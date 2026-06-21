// catalog-id: ld-magnetic-filings
import SwiftUI

/// Magnetic Filings — scattered iron-filing slivers align to the field of a
/// hidden magnetic pole. In `demo` the pole auto-orbits the center; interactively
/// a drag snaps the pole to the finger and the whole field swings to follow.
///
/// Self-contained: SwiftUI only, iOS 17, no app dependencies.
struct MagneticFilingsView: View {
    var demo: Bool = false

    // Pole motion is driven by time + values set ONLY in gesture callbacks,
    // so the Canvas render closure stays a pure read-only function (no state
    // writes during view update).

    /// Normalized (0...1) pole position the field is easing *from*.
    @State private var sourcePole: CGPoint = CGPoint(x: 0.5, y: 0.5)
    /// Normalized (0...1) pole position the field is easing *toward*.
    @State private var targetPole: CGPoint = CGPoint(x: 0.5, y: 0.5)
    /// When the current source→target transition began.
    @State private var transitionStart: Date = .distantPast
    /// True while a finger owns the pole.
    @State private var isDragging: Bool = false
    /// Orbit phase offset (radians) so the idle orbit resumes seamlessly
    /// from wherever the pole was released.
    @State private var orbitPhase: Double = 0
    /// Reference time used to compute the orbit angle.
    @State private var orbitStart: Date = .distantPast

    private let transitionDuration: Double = 0.55
    private let orbitPeriod: Double = 3.2          // seconds per lap when idle
    private let orbitRadius: CGFloat = 0.32        // fraction of min side

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                fieldCanvas(size: geo.size, now: timeline.date)
            }
        }
        .background(Color(red: 0.039, green: 0.063, blue: 0.078)) // #0a1014
        .contentShape(Rectangle())
        .modifier(MagneticFilingsView_PoleDragModifier(enabled: !demo, onChanged: handleDrag, onEnded: handleRelease))
        .onAppear { configureStart() }
    }

    // MARK: - Lifecycle

    private func configureStart() {
        let now = Date()
        if orbitStart == .distantPast { orbitStart = now }
        if transitionStart == .distantPast { transitionStart = now.addingTimeInterval(-transitionDuration) }
    }

    // MARK: - Canvas

    @ViewBuilder
    private func fieldCanvas(size: CGSize, now: Date) -> some View {
        let pole = displayedPole(size: size, now: now)
        Canvas { context, canvasSize in
            drawField(into: &context, size: canvasSize, pole: pole)
        }
        // Glow halo marking the hidden pole — keeps the tile legible at all times.
        .overlay {
            poleGlow(size: size, pole: pole)
        }
    }

    private func poleGlow(size: CGSize, pole: CGPoint) -> some View {
        let dim = min(size.width, size.height)
        let r = max(dim * 0.16, 14)
        return RadialGradient(
            colors: [
                Color(red: 0.55, green: 0.86, blue: 1.0).opacity(0.55),
                Color(red: 0.30, green: 0.62, blue: 0.95).opacity(0.0)
            ],
            center: .center,
            startRadius: 0,
            endRadius: r
        )
        .frame(width: r * 2, height: r * 2)
        .position(pole)
        .allowsHitTesting(false)
        .blendMode(.screen)
    }

    // MARK: - Pole position (pure function of time + callback-set state)

    private func displayedPole(size: CGSize, now: Date) -> CGPoint {
        let s = denormalize(sourcePole, in: size)
        let t = isDragging ? denormalize(targetPole, in: size) : orbitPoint(size: size, now: now)
        let elapsed = now.timeIntervalSince(transitionStart)
        let raw = transitionDuration > 0 ? elapsed / transitionDuration : 1
        let p = CGFloat(easeOut(min(max(raw, 0), 1)))
        return CGPoint(x: lerp(s.x, t.x, p), y: lerp(s.y, t.y, p))
    }

    /// The idle orbit position, phase-shifted so it lines up with the release point.
    private func orbitPoint(size: CGSize, now: Date) -> CGPoint {
        let dim = min(size.width, size.height)
        let cx = size.width / 2
        let cy = size.height / 2
        let r = dim * orbitRadius
        let elapsed = now.timeIntervalSince(orbitStart)
        let angle = (elapsed / orbitPeriod) * 2 * Double.pi + orbitPhase
        // Gentle vertical squash gives the orbit a tilted, lively feel.
        let x = cx + r * CGFloat(cos(angle))
        let y = cy + r * 0.62 * CGFloat(sin(angle))
        return CGPoint(x: x, y: y)
    }

    private func denormalize(_ p: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: p.x * size.width, y: p.y * size.height)
    }

    // MARK: - Drag handling

    private func handleDrag(_ location: CGPoint, _ size: CGSize) {
        let now = Date()
        if !isDragging {
            // Begin transition from wherever the field currently points.
            sourcePole = normalize(displayedPole(size: size, now: now), in: size)
            transitionStart = now
            isDragging = true
        }
        targetPole = normalize(location, in: size)
    }

    private func handleRelease(_ location: CGPoint, _ size: CGSize) {
        let now = Date()
        // Re-phase the idle orbit so it resumes from the release point with no snap.
        rephaseOrbit(toMatch: location, size: size, now: now)
        sourcePole = normalize(location, in: size)
        transitionStart = now
        isDragging = false
    }

    /// Choose orbitPhase + orbitStart so orbitPoint(now) == release location's
    /// nearest point on the orbit ellipse, then let the transition ease onto it.
    private func rephaseOrbit(toMatch location: CGPoint, size: CGSize, now: Date) {
        let cx = size.width / 2
        let cy = size.height / 2
        let dim = min(size.width, size.height)
        let r = max(dim * orbitRadius, 1)
        let dx = Double(location.x - cx) / Double(r)
        let dy = Double(location.y - cy) / Double(r * 0.62)
        let desiredAngle = atan2(dy, dx)
        let elapsed = now.timeIntervalSince(orbitStart)
        let base = (elapsed / orbitPeriod) * 2 * Double.pi
        orbitPhase = desiredAngle - base
    }

    private func normalize(_ p: CGPoint, in size: CGSize) -> CGPoint {
        let w = max(size.width, 1)
        let h = max(size.height, 1)
        return CGPoint(x: p.x / w, y: p.y / h)
    }

    // MARK: - Field drawing

    private func drawField(into context: inout GraphicsContext, size: CGSize, pole: CGPoint) {
        let layout = gridLayout(for: size)
        guard layout.cols > 0, layout.rows > 0 else { return }

        let half = layout.sliverLength / 2
        // Bucket slivers by field strength into a few Paths -> few stroke calls.
        let bucketCount = 4
        var buckets = Array(repeating: Path(), count: bucketCount)

        let maxDist = Double(max(size.width, size.height))

        for r in 0..<layout.rows {
            for c in 0..<layout.cols {
                let cx = layout.originX + CGFloat(c) * layout.spacing
                let cy = layout.originY + CGFloat(r) * layout.spacing
                let dx = Double(pole.x - cx)
                let dy = Double(pole.y - cy)
                let angle = atan2(dy, dx)
                let dist = (dx * dx + dy * dy).squareRoot()

                // Strength: near the pole the slivers are longer/brighter.
                let strength = 1.0 - min(dist / maxDist, 1.0)
                let lengthScale = CGFloat(0.7 + 0.55 * strength)
                let h = half * lengthScale

                let cosA = CGFloat(cos(angle))
                let sinA = CGFloat(sin(angle))
                let p0 = CGPoint(x: cx - cosA * h, y: cy - sinA * h)
                let p1 = CGPoint(x: cx + cosA * h, y: cy + sinA * h)

                let bucket = min(Int(strength * Double(bucketCount)), bucketCount - 1)
                buckets[bucket].move(to: p0)
                buckets[bucket].addLine(to: p1)
            }
        }

        let lineWidth = max(layout.sliverLength * 0.16, 1.1)
        for i in 0..<bucketCount {
            let t = Double(i) / Double(bucketCount - 1)
            let color = filingColor(strength: t)
            context.stroke(
                buckets[i],
                with: .color(color),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
        }
    }

    private func filingColor(strength t: Double) -> Color {
        // Steel-grey far field -> bright cyan-white near the pole.
        let lo = (r: 0.42, g: 0.47, b: 0.55)
        let hi = (r: 0.72, g: 0.92, b: 1.0)
        let rr = lerp(lo.r, hi.r, t)
        let gg = lerp(lo.g, hi.g, t)
        let bb = lerp(lo.b, hi.b, t)
        let alpha = 0.55 + 0.45 * t
        return Color(red: rr, green: gg, blue: bb).opacity(alpha)
    }

    // MARK: - Grid layout

    struct GridLayout {
        var cols: Int
        var rows: Int
        var spacing: CGFloat
        var originX: CGFloat
        var originY: CGFloat
        var sliverLength: CGFloat
    }

    private func gridLayout(for size: CGSize) -> GridLayout {
        let dim = min(size.width, size.height)
        guard dim > 1 else {
            return GridLayout(cols: 0, rows: 0, spacing: 0, originX: 0, originY: 0, sliverLength: 0)
        }
        // Spacing scales with the smaller side so density reads similarly in a
        // 120pt tile and a large detail view.
        let spacing = max(dim / 12.0, 12)
        let sliverLength = spacing * 0.78

        // Cap total slivers for perf (stated risk).
        let maxSlivers = 520
        var cols = max(Int(size.width / spacing), 2)
        var rows = max(Int(size.height / spacing), 2)
        while cols * rows > maxSlivers {
            if cols >= rows { cols -= 1 } else { rows -= 1 }
        }

        let usedW = CGFloat(cols - 1) * spacing
        let usedH = CGFloat(rows - 1) * spacing
        let originX = (size.width - usedW) / 2
        let originY = (size.height - usedH) / 2
        return GridLayout(cols: cols, rows: rows, spacing: spacing,
                          originX: originX, originY: originY, sliverLength: sliverLength)
    }

    // MARK: - Math helpers

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
    private func easeOut(_ t: Double) -> Double { 1 - pow(1 - t, 3) }
}

// MARK: - Drag wiring (conditionally attached)

/// Attaches a zero-distance DragGesture only when interactive, so the piece
/// wins inside a ScrollView. In demo mode no gesture is added.
private struct MagneticFilingsView_PoleDragModifier: ViewModifier {
    let enabled: Bool
    let onChanged: (CGPoint, CGSize) -> Void
    let onEnded: (CGPoint, CGSize) -> Void

    func body(content: Content) -> some View {
        if enabled {
            GeometryReader { geo in
                content
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { onChanged($0.location, geo.size) }
                            .onEnded { onEnded($0.location, geo.size) }
                    )
            }
        } else {
            content
        }
    }
}
