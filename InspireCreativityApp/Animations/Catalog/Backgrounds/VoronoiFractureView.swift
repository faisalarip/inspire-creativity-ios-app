// catalog-id: bg-voronoi-fracture
import SwiftUI

// MARK: - Voronoi Fracture
// A Canvas renders a coarse field of orbiting Voronoi cells with crisp
// "stained glass" leading. Cells are exact polygons computed via
// Sutherland–Hodgman half-plane clipping (not a pixel sample grid), so the
// seams stay sharp at any size. A tap (or, in demo mode, a time-driven
// synthetic tap) fractures the nearest cell into a splinter burst that heals
// back into the mosaic. Fracture progress is a pure function of timeline time,
// so demo and interactive share one code path.

public struct VoronoiFractureView: View {
    public var demo: Bool = false

    public init(demo: Bool = false) {
        self.demo = demo
    }

    // Per-cell fracture start times (seconds, in the timeline's clock).
    // A value of -1 means "not fractured".
    @State private var fractureStartTimes: [Double] = Array(repeating: -1, count: VoronoiFractureView_VoronoiConfig.seedCount)
    @State private var startDate: Date = .init()

    public var body: some View {
        GeometryReader { geo in
            let size = geo.size
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSince(startDate)
                Canvas { context, canvasSize in
                    VoronoiFractureView_VoronoiRenderer.draw(
                        context: &context,
                        size: canvasSize,
                        time: t,
                        fractureStartTimes: fractureStartTimes,
                        demo: demo
                    )
                }
                .background(Color(red: 0.039, green: 0.039, blue: 0.047))
                .contentShape(Rectangle())
                .gesture(tapGesture(in: size, time: t))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    // Interactive: SpatialTapGesture reports the location; map to nearest seed,
    // stamp its fracture start time. Disabled in demo (the timeline fires its own).
    private func tapGesture(in size: CGSize, time: Double) -> some Gesture {
        SpatialTapGesture(coordinateSpace: .local)
            .onEnded { value in
                guard !demo, size.width > 0, size.height > 0 else { return }
                let seeds = VoronoiFractureView_VoronoiMath.seeds(at: time, size: size)
                let idx = VoronoiFractureView_VoronoiMath.nearestSeedIndex(to: value.location, seeds: seeds)
                if idx >= 0 && idx < fractureStartTimes.count {
                    fractureStartTimes[idx] = time
                }
            }
    }
}

// MARK: - Configuration

private enum VoronoiFractureView_VoronoiConfig {
    static let seedCount: Int = 24
    static let fractureDuration: Double = 1.1     // seconds for a crack to heal
    static let demoCadence: Double = 2.5          // seconds between auto-fractures
    static let strokeWidth: CGFloat = 1.2         // fixed point width (crisp at any size)
}

// MARK: - Seed Math

private enum VoronoiFractureView_VoronoiMath {

    // Deterministic pseudo-random in [0,1) from an integer key.
    static func rand(_ key: Int) -> Double {
        let x = sin(Double(key) * 127.1 + 311.7) * 43758.5453
        return x - floor(x)
    }

    // Orbiting seed centers in absolute view coordinates.
    static func seeds(at time: Double, size: CGSize) -> [CGPoint] {
        let count = VoronoiFractureView_VoronoiConfig.seedCount
        var result: [CGPoint] = []
        result.reserveCapacity(count)
        let w = size.width
        let h = size.height
        for i in 0..<count {
            // Anchor on a loose jittered grid so cells stay well-distributed.
            let cols = 6
            let rows = (count + cols - 1) / cols
            let col = i % cols
            let row = i / cols
            let jitterX = (rand(i * 3 + 1) - 0.5) * 0.6
            let jitterY = (rand(i * 3 + 2) - 0.5) * 0.6
            let baseX = (Double(col) + 0.5) / Double(cols) + jitterX / Double(cols)
            let baseY = (Double(row) + 0.5) / Double(rows) + jitterY / Double(rows)

            // Slow orbit: each seed drifts on its own small ellipse.
            let speed = 0.18 + rand(i * 5 + 7) * 0.22
            let phase = rand(i * 5 + 11) * .pi * 2.0
            let radX = 0.045 + rand(i * 5 + 13) * 0.04
            let radY = 0.045 + rand(i * 5 + 17) * 0.04
            let ox = cos(time * speed + phase) * radX
            let oy = sin(time * speed * 1.1 + phase) * radY

            let nx = min(max(baseX + ox, 0.02), 0.98)
            let ny = min(max(baseY + oy, 0.02), 0.98)
            result.append(CGPoint(x: CGFloat(nx) * w, y: CGFloat(ny) * h))
        }
        return result
    }

    static func nearestSeedIndex(to point: CGPoint, seeds: [CGPoint]) -> Int {
        var best = -1
        var bestDist = CGFloat.greatestFiniteMagnitude
        for (i, s) in seeds.enumerated() {
            let dx = s.x - point.x
            let dy = s.y - point.y
            let d = dx * dx + dy * dy
            if d < bestDist {
                bestDist = d
                best = i
            }
        }
        return best
    }

    static func centroid(of polygon: [CGPoint]) -> CGPoint {
        guard !polygon.isEmpty else { return .zero }
        var sx: CGFloat = 0
        var sy: CGFloat = 0
        for p in polygon {
            sx += p.x
            sy += p.y
        }
        let n = CGFloat(polygon.count)
        return CGPoint(x: sx / n, y: sy / n)
    }
}

// MARK: - Voronoi Polygon (Sutherland–Hodgman half-plane clipping)

private enum VoronoiFractureView_VoronoiClipper {

    // The exact Voronoi cell for `site` = the canvas rect clipped against the
    // perpendicular bisector with every other seed.
    static func cell(for site: CGPoint, among seeds: [CGPoint], rect: CGSize) -> [CGPoint] {
        var poly: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: rect.width, y: 0),
            CGPoint(x: rect.width, y: rect.height),
            CGPoint(x: 0, y: rect.height)
        ]
        for other in seeds {
            if other == site { continue }
            poly = clipHalfPlane(polygon: poly, site: site, other: other)
            if poly.count < 3 { break }
        }
        return poly
    }

    // Keep the part of `polygon` on the `site` side of the bisector between
    // `site` and `other`. A point p is kept iff
    //   dot(p - midpoint, other - site) <= 0   (i.e. p is closer to site).
    private static func clipHalfPlane(polygon: [CGPoint], site: CGPoint, other: CGPoint) -> [CGPoint] {
        guard polygon.count >= 3 else { return [] }
        let mid = CGPoint(x: (site.x + other.x) / 2, y: (site.y + other.y) / 2)
        let nx = other.x - site.x   // normal pointing toward `other`
        let ny = other.y - site.y

        func signedValue(_ p: CGPoint) -> CGFloat {
            (p.x - mid.x) * nx + (p.y - mid.y) * ny
        }

        var output: [CGPoint] = []
        output.reserveCapacity(polygon.count + 1)
        let n = polygon.count
        for i in 0..<n {
            let current = polygon[i]
            let next = polygon[(i + 1) % n]
            let curVal = signedValue(current)
            let nextVal = signedValue(next)
            let curInside = curVal <= 0
            let nextInside = nextVal <= 0

            if curInside {
                output.append(current)
            }
            // Edge crosses the bisector → add intersection.
            if curInside != nextInside {
                let denom = curVal - nextVal
                if abs(denom) > 1e-9 {
                    let tt = curVal / denom
                    let ix = current.x + tt * (next.x - current.x)
                    let iy = current.y + tt * (next.y - current.y)
                    output.append(CGPoint(x: ix, y: iy))
                }
            }
        }
        return output
    }
}

// MARK: - Renderer

private enum VoronoiFractureView_VoronoiRenderer {

    static func draw(
        context: inout GraphicsContext,
        size: CGSize,
        time: Double,
        fractureStartTimes: [Double],
        demo: Bool
    ) {
        guard size.width > 1, size.height > 1 else { return }
        let seeds = VoronoiFractureView_VoronoiMath.seeds(at: time, size: size)

        // Precompute each cell polygon once per frame.
        var polygons: [[CGPoint]] = []
        polygons.reserveCapacity(seeds.count)
        for s in seeds {
            polygons.append(VoronoiFractureView_VoronoiClipper.cell(for: s, among: seeds, rect: size))
        }

        // 1) Draw the COMPLETE intact mosaic first, every frame.
        //    Guarantees the tile is never blank, even mid-fracture.
        drawMosaic(context: &context, polygons: polygons, time: time)

        // 2) Splinter overlay on top (additive crack flash), shared by demo + tap.
        drawFractures(
            context: &context,
            polygons: polygons,
            fractureStartTimes: fractureStartTimes,
            time: time,
            demo: demo,
            count: seeds.count
        )

        // 3) A soft vignette to seat the mosaic in the tile.
        drawVignette(context: &context, size: size)
    }

    private static func cellColor(index: Int, time: Double) -> Color {
        // Each cell cycles hue over time; wrap into [0,1) (Color(hue:) clamps).
        let baseHue = VoronoiFractureView_VoronoiMath.rand(index * 7 + 3)
        let h = baseHue + time * 0.03
        let hue = h - floor(h)
        let sat = 0.55 + VoronoiFractureView_VoronoiMath.rand(index * 7 + 5) * 0.25
        let bri = 0.62 + VoronoiFractureView_VoronoiMath.rand(index * 7 + 9) * 0.28
        return Color(hue: hue, saturation: sat, brightness: bri)
    }

    private static func path(from polygon: [CGPoint]) -> Path {
        var p = Path()
        guard polygon.count >= 3 else { return p }
        p.move(to: polygon[0])
        for i in 1..<polygon.count {
            p.addLine(to: polygon[i])
        }
        p.closeSubpath()
        return p
    }

    private static func drawMosaic(
        context: inout GraphicsContext,
        polygons: [[CGPoint]],
        time: Double
    ) {
        let stroke = Color(red: 0.04, green: 0.05, blue: 0.07)
        for (i, poly) in polygons.enumerated() {
            guard poly.count >= 3 else { continue }
            let p = path(from: poly)
            context.fill(p, with: .color(cellColor(index: i, time: time)))
            // Crisp dark "leading" between panes — fixed point width.
            context.stroke(
                p,
                with: .color(stroke),
                style: StrokeStyle(lineWidth: VoronoiFractureView_VoronoiConfig.strokeWidth, lineJoin: .round)
            )
            // Subtle inner sheen at the top of each pane for glassy depth.
            let centroid = VoronoiFractureView_VoronoiMath.centroid(of: poly)
            let sheen = Path(ellipseIn: CGRect(
                x: centroid.x - 1.2, y: centroid.y - 1.2, width: 2.4, height: 2.4
            ))
            context.fill(sheen, with: .color(.white.opacity(0.10)))
        }
    }

    private static func drawFractures(
        context: inout GraphicsContext,
        polygons: [[CGPoint]],
        fractureStartTimes: [Double],
        time: Double,
        demo: Bool,
        count: Int
    ) {
        for i in 0..<count {
            let progress = fractureProgress(
                index: i,
                fractureStartTimes: fractureStartTimes,
                time: time,
                demo: demo,
                count: count
            )
            guard progress > 0.001, i < polygons.count, polygons[i].count >= 3 else { continue }
            drawSplinters(context: &context, polygon: polygons[i], progress: progress, index: i, time: time)
        }
    }

    // Unified fracture progress: pure function of timeline time.
    // Returns a 1→0 decaying value (eased) while a cell is fracturing.
    private static func fractureProgress(
        index: Int,
        fractureStartTimes: [Double],
        time: Double,
        demo: Bool,
        count: Int
    ) -> Double {
        var start: Double = -1

        if demo {
            // Time-driven synthetic tap: one cell fractures per cadence window.
            let window = Int(floor(time / VoronoiFractureView_VoronoiConfig.demoCadence))
            // Pseudo-randomly pick a cell for this window so it wanders.
            let active = Int(VoronoiFractureView_VoronoiMath.rand(window + 1) * Double(count)) % max(count, 1)
            if active == index {
                start = Double(window) * VoronoiFractureView_VoronoiConfig.demoCadence
            }
        } else if index < fractureStartTimes.count {
            start = fractureStartTimes[index]
        }

        guard start >= 0 else { return 0 }
        let elapsed = time - start
        guard elapsed >= 0, elapsed <= VoronoiFractureView_VoronoiConfig.fractureDuration else { return 0 }
        let raw = 1.0 - elapsed / VoronoiFractureView_VoronoiConfig.fractureDuration  // 1 → 0
        // Snappy burst then ease back: fast attack via sqrt-like curve.
        return raw * raw
    }

    // Fan-triangulate the polygon from its centroid; push each triangle outward
    // by `progress`, drawn as a bright additive splinter over the intact pane.
    private static func drawSplinters(
        context: inout GraphicsContext,
        polygon: [CGPoint],
        progress: Double,
        index: Int,
        time: Double
    ) {
        let centroid = VoronoiFractureView_VoronoiMath.centroid(of: polygon)
        let n = polygon.count
        let push = CGFloat(progress) * 26.0
        let glow = cellColor(index: index, time: time)

        for i in 0..<n {
            let a = polygon[i]
            let b = polygon[(i + 1) % n]
            // Midpoint of this edge defines the outward shard direction.
            let edgeMid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            var dx = edgeMid.x - centroid.x
            var dy = edgeMid.y - centroid.y
            let len = max(sqrt(dx * dx + dy * dy), 0.0001)
            dx /= len
            dy /= len
            // Each shard gets a slight rotational spin as it flies out.
            let spin = CGFloat(progress * (VoronoiFractureView_VoronoiMath.rand(index * 13 + i) - 0.5) * 0.6)
            let off = CGPoint(x: dx * push, y: dy * push)

            let ca = rotate(point: a, around: centroid, by: spin)
            let cb = rotate(point: b, around: centroid, by: spin)
            let shard = [
                CGPoint(x: centroid.x + off.x * 0.35, y: centroid.y + off.y * 0.35),
                CGPoint(x: ca.x + off.x, y: ca.y + off.y),
                CGPoint(x: cb.x + off.x, y: cb.y + off.y)
            ]
            var p = Path()
            p.move(to: shard[0])
            p.addLine(to: shard[1])
            p.addLine(to: shard[2])
            p.closeSubpath()

            let alpha = progress
            context.fill(p, with: .color(glow.opacity(alpha * 0.85)))
            context.stroke(
                p,
                with: .color(.white.opacity(alpha * 0.7)),
                style: StrokeStyle(lineWidth: 0.9, lineJoin: .round)
            )
        }

        // A central crack flash that fades with the burst.
        let flashR = CGFloat(2 + progress * 10)
        let flash = Path(ellipseIn: CGRect(
            x: centroid.x - flashR, y: centroid.y - flashR,
            width: flashR * 2, height: flashR * 2
        ))
        context.fill(flash, with: .color(.white.opacity(progress * 0.5)))
    }

    private static func rotate(point: CGPoint, around c: CGPoint, by angle: CGFloat) -> CGPoint {
        let s = sin(angle)
        let co = cos(angle)
        let dx = point.x - c.x
        let dy = point.y - c.y
        return CGPoint(x: c.x + dx * co - dy * s, y: c.y + dx * s + dy * co)
    }

    private static func drawVignette(context: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        let gradient = Gradient(colors: [
            .clear,
            Color(red: 0.0, green: 0.0, blue: 0.0).opacity(0.32)
        ])
        let maxR = max(size.width, size.height) * 0.75
        context.fill(
            Path(rect),
            with: .radialGradient(
                gradient,
                center: CGPoint(x: size.width / 2, y: size.height / 2),
                startRadius: maxR * 0.45,
                endRadius: maxR
            )
        )
    }
}
