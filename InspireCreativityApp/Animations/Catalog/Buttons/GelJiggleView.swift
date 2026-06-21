// catalog-id: btn-gel-jiggle
import SwiftUI

/// Gel Jiggle — a press deforms the button like a gummy block: the surface
/// squashes locally where touched and damped jiggle waves ripple outward
/// through a soft-body boundary before resettling.
///
/// Architecture (one clock, no transaction fighting):
/// A single `TimelineView(.animation)` drives BOTH the outward-traveling
/// ripple phase AND an analytically-evaluated damped-spring amplitude
/// envelope. The envelope reproduces `interpolatingSpring(stiffness:170,
/// damping:6)` exactly — omega0 = sqrt(170) ≈ 13.0, zeta ≈ 0.23 — but
/// evaluated per-frame so it survives the timeline (a `withAnimation` spring
/// on `@State` would be stomped to target every frame by the timeline and the
/// wobble would never decay). Demo and interactive share this path; demo just
/// re-seeds the poke from corners on a loop, interactive seeds it on tap.
public struct GelJiggleView: View {
    public var demo: Bool = false

    public init(demo: Bool = false) {
        self.demo = demo
    }

    // Seed of the current poke. `tapTime` is the reference clock instant.
    @State private var tapTime: Date = .distantPast
    @State private var origin: UnitPoint = .center
    @State private var seedAmplitude: CGFloat = 0
    @State private var hapticTick: Int = 0

    public var body: some View {
        GeometryReader { geo in
            content(size: geo.size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Real haptic only on genuine touch — never in the demo grid.
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.7),
                         trigger: hapticTick)
    }

    @ViewBuilder
    private func content(size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let now: Date = timeline.date
            // Demo auto-pokes from a rotating set of corners.
            let demoSeed = demoPoke(at: now)
            let activeTime: Date = demo ? demoSeed.time : tapTime
            let activeOrigin: UnitPoint = demo ? demoSeed.origin : origin
            let activeAmp: CGFloat = demo ? demoSeed.amplitude : seedAmplitude

            let elapsed: Double = now.timeIntervalSince(activeTime)
            let amplitude: CGFloat = envelope(seed: activeAmp, t: elapsed)
            let phase: Double = ripplePhase(t: elapsed)

            gel(size: size,
                amplitude: amplitude,
                phase: phase,
                origin: activeOrigin)
        }
        .contentShape(Rectangle())
        // `isEnabled:` on gesture(_:) is iOS 18+. iOS 17-safe equivalent:
        // `.subviews` disables this node's gesture (there are no children)
        // for the demo, `.all` enables it for the interactive build.
        .gesture(tapGesture(size: size),
                 including: demo ? .subviews : .all)
    }

    // MARK: - The gel body

    @ViewBuilder
    private func gel(size: CGSize,
                     amplitude: CGFloat,
                     phase: Double,
                     origin: UnitPoint) -> some View {
        let dim: CGFloat = min(size.width, size.height)
        let inset: CGFloat = dim * 0.16
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            .insetBy(dx: inset, dy: inset)
        let corner: CGFloat = min(rect.width, rect.height) * 0.32
        let shape = GelJiggleView_GelShape(amplitude: amplitude,
                             phase: phase,
                             origin: origin,
                             corner: corner)

        // Local squash anchored at the touch point: positive amplitude widens
        // and shortens (splat), so the deformation is non-uniform and reads as
        // jelly, not a uniform scale.
        let squash: CGFloat = clampUnit(abs(amplitude) / 26.0)
        let scaleX: CGFloat = 1.0 + squash * 0.18
        let scaleY: CGFloat = 1.0 - squash * 0.18

        ZStack {
            shape
                .fill(gelGradient(in: rect))
                .overlay { rimHighlight(shape: shape) }
                .overlay { specular(in: rect, origin: origin) }
                .overlay { glossBand(in: rect) }
                .shadow(color: shadowColor,
                        radius: dim * 0.06,
                        x: 0,
                        y: dim * 0.045)
            label(rect: rect)
        }
        .scaleEffect(x: scaleX, y: scaleY, anchor: origin)
    }

    private func label(rect: CGRect) -> some View {
        Text("Tap")
            .font(.system(size: min(rect.width, rect.height) * 0.30,
                          weight: .heavy,
                          design: .rounded))
            .foregroundStyle(labelColor)
            .shadow(color: Color(red: 0.04, green: 0.20, blue: 0.18)
                .opacity(0.55),
                    radius: 0.5, x: 0, y: 1)
            .allowsHitTesting(false)
    }

    // MARK: - Surface shading

    private func gelGradient(in rect: CGRect) -> LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.36, green: 0.93, blue: 0.74),
                Color(red: 0.14, green: 0.78, blue: 0.62),
                Color(red: 0.07, green: 0.55, blue: 0.49)
            ],
            startPoint: .top,
            endPoint: .bottom)
    }

    private func rimHighlight(shape: GelJiggleView_GelShape) -> some View {
        shape
            .stroke(
                LinearGradient(
                    colors: [
                        Color(red: 0.78, green: 1.0, blue: 0.92).opacity(0.9),
                        Color(red: 0.05, green: 0.42, blue: 0.38).opacity(0.6)
                    ],
                    startPoint: .top,
                    endPoint: .bottom),
                lineWidth: 1.4)
    }

    // A bright moving specular blob that tracks the poke origin — sells the
    // wet, glossy jelly read and keeps the tile legible on every frame.
    private func specular(in rect: CGRect, origin: UnitPoint) -> some View {
        let r: CGFloat = min(rect.width, rect.height) * 0.42
        let cx: CGFloat = rect.minX + rect.width * (0.30 + origin.x * 0.40)
        let cy: CGFloat = rect.minY + rect.height * (0.22 + origin.y * 0.30)
        return RadialGradient(
            colors: [
                Color.white.opacity(0.85),
                Color.white.opacity(0.0)
            ],
            center: .topLeading,
            startRadius: 0,
            endRadius: r)
            .frame(width: r * 2, height: r * 2)
            .position(x: cx, y: cy)
            .blendMode(.screen)
            .clipShape(RoundedRectangle(cornerRadius: rect.width * 0.30))
            .allowsHitTesting(false)
    }

    private func glossBand(in rect: CGRect) -> some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.32),
                Color.white.opacity(0.0)
            ],
            startPoint: .top,
            endPoint: .center)
            .clipShape(
                RoundedRectangle(cornerRadius: rect.width * 0.30)
                    .inset(by: rect.width * 0.06))
            .allowsHitTesting(false)
    }

    private var shadowColor: Color {
        Color(red: 0.03, green: 0.28, blue: 0.24).opacity(0.45)
    }

    private var labelColor: Color {
        Color(red: 0.02, green: 0.22, blue: 0.18)
    }

    // MARK: - Damped-spring envelope (analytic, clock-driven)

    /// Reproduces `interpolatingSpring(stiffness:170, damping:6)`:
    /// omega0 = sqrt(170) ≈ 13.04, zeta = 6/(2·sqrt(170)) ≈ 0.230 → underdamped.
    /// sigma = zeta·omega0 ≈ 3.0 /s (decay), omega_d = omega0·sqrt(1-zeta²)
    /// ≈ 12.69 rad/s (ring). Settles in ~1.5 s.
    private func envelope(seed: CGFloat, t: Double) -> CGFloat {
        guard t >= 0, seed != 0 else { return 0 }
        let sigma: Double = 3.0
        let omegaD: Double = 12.69
        let decay: Double = exp(-sigma * t)
        // Clamp so even a stale demo seed dies out and we never linger huge.
        guard decay > 0.001 else { return 0 }
        let osc: Double = cos(omegaD * t)
        return seed * CGFloat(decay * osc)
    }

    /// Monotonically advancing spatial phase so the ripple visibly TRAVELS
    /// outward (a spring alone can't do this — phase must keep climbing).
    private func ripplePhase(t: Double) -> Double {
        guard t >= 0 else { return 0 }
        let speed: Double = 9.0
        return t * speed
    }

    // MARK: - Demo auto-poke

    /// Re-seeds a phantom poke from a rotating set of corners on a ~3 s loop so
    /// the gel auto-wobbles and resettles with no touch. Amplitude is always
    /// generous and the geometry (never opacity) animates — the tile is never
    /// blank.
    private func demoPoke(at date: Date)
        -> (time: Date, origin: UnitPoint, amplitude: CGFloat) {
        let cycle: Double = 3.2
        let stamp: Double = date.timeIntervalSinceReferenceDate
        let index: Int = Int(floor(stamp / cycle))
        let cycleStart: Double = Double(index) * cycle
        let pokeTime = Date(timeIntervalSinceReferenceDate: cycleStart)

        let corners: [UnitPoint] = [
            UnitPoint(x: 0.22, y: 0.26),
            UnitPoint(x: 0.80, y: 0.30),
            UnitPoint(x: 0.50, y: 0.78),
            UnitPoint(x: 0.78, y: 0.74)
        ]
        let origin = corners[((index % corners.count) + corners.count)
                             % corners.count]
        return (pokeTime, origin, 24.0)
    }

    // MARK: - Interactive

    private func tapGesture(size: CGSize) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                let nx: CGFloat = clampUnit(value.location.x / max(size.width, 1))
                let ny: CGFloat = clampUnit(value.location.y / max(size.height, 1))
                origin = UnitPoint(x: nx, y: ny)
                seedAmplitude = 24.0
                tapTime = Date()
                hapticTick &+= 1
            }
    }

    private func clampUnit(_ v: CGFloat) -> CGFloat {
        min(max(v, 0), 1)
    }
}

// MARK: - Soft-body boundary Shape

/// A rounded-rectangle-like boundary whose perimeter samples are displaced
/// outward along their normals by a damped, distance-falloff ripple emanating
/// from `origin`. The displacement is spatially LOCAL — strong near the poke
/// origin and decaying outward — so it can never read as a uniform scale.
/// Not `Animatable`: amplitude and phase are supplied per-frame by the view's
/// single TimelineView clock, so nothing springs through the view tree.
private struct GelJiggleView_GelShape: Shape {
    var amplitude: CGFloat   // signed, from the damped envelope
    var phase: Double        // traveling ripple phase
    var origin: UnitPoint    // poke origin, normalized 0–1
    var corner: CGFloat

    func path(in rect: CGRect) -> Path {
        let base = roundedSamples(in: rect, corner: corner, count: 96)
        let pokePoint = CGPoint(x: rect.minX + rect.width * origin.x,
                                y: rect.minY + rect.height * origin.y)
        let maxDist: CGFloat = sqrt(rect.width * rect.width
                                    + rect.height * rect.height)
        let centre = CGPoint(x: rect.midX, y: rect.midY)

        var displaced: [CGPoint] = []
        displaced.reserveCapacity(base.count)
        for p in base {
            let d: CGFloat = distance(p, pokePoint)
            let disp: CGFloat = displacement(distance: d, maxDist: maxDist)
            // Outward normal approximated as direction from centre to sample.
            let n = normalize(CGPoint(x: p.x - centre.x, y: p.y - centre.y))
            displaced.append(CGPoint(x: p.x + n.x * disp,
                                     y: p.y + n.y * disp))
        }
        return smoothClosedPath(displaced)
    }

    /// Local ripple: high near `origin`, decaying outward (Gaussian falloff),
    /// times a traveling cosine in distance and phase.
    private func displacement(distance d: CGFloat, maxDist: CGFloat) -> CGFloat {
        guard maxDist > 0 else { return 0 }
        let norm: CGFloat = d / maxDist            // 0 at poke … ~1 far edge
        // Gaussian-ish falloff: ~1 at the poke, ~0.1 by half the diagonal.
        let falloff: CGFloat = CGFloat(exp(-Double(norm) * 3.2))
        let k: Double = 11.0                        // spatial frequency
        let wave: Double = cos(Double(norm) * k - phase)
        return amplitude * falloff * CGFloat(wave)
    }

    // MARK: geometry helpers

    private func roundedSamples(in rect: CGRect,
                                corner: CGFloat,
                                count: Int) -> [CGPoint] {
        let r: CGFloat = min(corner, min(rect.width, rect.height) / 2)
        // Build the rounded-rect path, then sample it at even arc fractions.
        let path = Path(roundedRect: rect, cornerRadius: r)
        let total = path.trimmedLength
        guard total > 0 else { return [] }
        var pts: [CGPoint] = []
        pts.reserveCapacity(count)
        for i in 0..<count {
            let f = CGFloat(i) / CGFloat(count)
            if let p = path.point(atFraction: f) {
                pts.append(p)
            }
        }
        return pts
    }

    private func smoothClosedPath(_ pts: [CGPoint]) -> Path {
        var path = Path()
        guard pts.count > 2 else {
            if let f = pts.first {
                path.move(to: f)
                for p in pts.dropFirst() { path.addLine(to: p) }
                path.closeSubpath()
            }
            return path
        }
        // Catmull-Rom through the displaced samples → smooth gummy boundary.
        let n = pts.count
        let start = midpoint(pts[n - 1], pts[0])
        path.move(to: start)
        for i in 0..<n {
            let p0 = pts[i]
            let p1 = pts[(i + 1) % n]
            let mid = midpoint(p0, p1)
            path.addQuadCurve(to: mid, control: p0)
        }
        path.closeSubpath()
        return path
    }

    private func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }

    private func normalize(_ v: CGPoint) -> CGPoint {
        let len = sqrt(v.x * v.x + v.y * v.y)
        guard len > 0.0001 else { return CGPoint(x: 0, y: -1) }
        return CGPoint(x: v.x / len, y: v.y / len)
    }
}

// MARK: - Path arc-length sampling

private extension Path {
    /// Approximate total length by flattening into line segments.
    var trimmedLength: CGFloat {
        var length: CGFloat = 0
        var last: CGPoint? = nil
        var startPoint: CGPoint? = nil
        forEachFlattened { p, isStart in
            if isStart {
                startPoint = p
                last = p
            } else if let l = last {
                length += hypot(p.x - l.x, p.y - l.y)
                last = p
            }
        }
        if let s = startPoint, let l = last {
            length += hypot(s.x - l.x, s.y - l.y)
        }
        return length
    }

    /// Point at a 0–1 fraction of total arc length (closed, wraps to start).
    func point(atFraction fraction: CGFloat) -> CGPoint? {
        let pts = flattenedPoints()
        guard pts.count > 1 else { return pts.first }
        // Build cumulative lengths around the closed loop.
        var cum: [CGFloat] = [0]
        var total: CGFloat = 0
        for i in 1..<pts.count {
            total += hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y)
            cum.append(total)
        }
        // Close the loop.
        let closeLen = hypot(pts[0].x - pts[pts.count - 1].x,
                             pts[0].y - pts[pts.count - 1].y)
        total += closeLen
        guard total > 0 else { return pts.first }

        let target = min(max(fraction, 0), 1) * total
        for i in 1..<cum.count where cum[i] >= target {
            let segLen = cum[i] - cum[i - 1]
            let t = segLen > 0 ? (target - cum[i - 1]) / segLen : 0
            return CGPoint(
                x: pts[i - 1].x + (pts[i].x - pts[i - 1].x) * t,
                y: pts[i - 1].y + (pts[i].y - pts[i - 1].y) * t)
        }
        // In the closing segment.
        let segLen = closeLen
        let t = segLen > 0 ? (target - cum[cum.count - 1]) / segLen : 0
        let a = pts[pts.count - 1]
        let b = pts[0]
        return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    private func flattenedPoints() -> [CGPoint] {
        var pts: [CGPoint] = []
        forEachFlattened { p, _ in pts.append(p) }
        return pts
    }

    /// Walk the path, emitting flattened points. `isStart` marks subpath moves.
    private func forEachFlattened(_ body: (CGPoint, Bool) -> Void) {
        forEach { element in
            switch element {
            case .move(let to):
                body(to, true)
            case .line(let to):
                body(to, false)
            case .quadCurve(let to, _):
                body(to, false)
            case .curve(let to, _, _):
                body(to, false)
            case .closeSubpath:
                break
            }
        }
    }
}
