// catalog-id: bg-depth-starfield
import SwiftUI

// MARK: - Depth Starfield
// Three parallax layers (far / mid / near) of point-stars drawn in a Canvas.
// A TimelineView(.animation) advances a forward "warp" so stars stream outward
// from a vanishing point and twinkle via a per-star sine. A DragGesture offsets
// each layer by its depth weight (near streaks, far barely moves); a flick is
// folded into the TIME model (not SwiftUI animation, which Canvas can't
// interpolate) as an exponentially-decaying velocity term so a quick release
// sends near stars streaking like a hyperspace nudge before easing back to drift.

struct DepthStarfieldView: View {
    var demo: Bool = false

    // Persisted star arrays (built once per view identity — never reshuffled in body).
    @State private var layers: [DepthStarfieldView_StarLayer] = DepthStarfieldView.makeLayers()

    // Live drag state.
    @State private var dragOffset: CGSize = .zero

    // Flick decay model — pure time-domain, read by the Canvas each frame.
    @State private var releaseOffset: CGSize = .zero
    @State private var releaseVelocity: CGSize = .zero
    @State private var releaseTime: Double = -1_000

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, canvasSize in
                    drawField(context: context, size: canvasSize, time: t)
                }
                .background(Self.spaceGradient)
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            // Always attach the gesture; in demo mode mask it off so onChanged/onEnded
            // never fire and baseOffset(time:) takes the self-driving demo branch.
            .gesture(starDrag, including: demo ? .subviews : .all)
            .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Gesture

    private var starDrag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                // Velocity ~ predictedEnd - current, captured as the flick impulse.
                let dx = value.predictedEndTranslation.width - value.translation.width
                let dy = value.predictedEndTranslation.height - value.translation.height
                releaseOffset = value.translation
                releaseVelocity = CGSize(width: dx, height: dy)
                releaseTime = Date().timeIntervalSinceReferenceDate
                dragOffset = .zero
            }
    }

    // MARK: Effective offset (drag + decaying flick + idle synthetic motion)

    /// The pointer-space offset applied at depth-weight 1.0, before per-layer scaling.
    private func baseOffset(time: Double) -> CGSize {
        if demo {
            return demoOffset(time: time)
        }
        // Active drag dominates.
        if dragOffset != .zero {
            return dragOffset
        }
        // Decaying flick: offset(t) = releaseOffset*ease + velocity*tau*exp(-dt/tau)
        let dt = time - releaseTime
        if dt < 0 || dt > 6 { return .zero }
        let tau: Double = 0.42
        let decay = exp(-dt / tau)
        let settle = exp(-dt / (tau * 1.6)) // releaseOffset eases home a touch slower
        let vx = Double(releaseVelocity.width) * tau * decay
        let vy = Double(releaseVelocity.height) * tau * decay
        let ox = Double(releaseOffset.width) * settle
        let oy = Double(releaseOffset.height) * settle
        return CGSize(width: vx + ox, height: vy + oy)
    }

    /// In demo mode, synthesize a flick every ~3.2s that exercises real parallax:
    /// a sharp push that decays, so near stars visibly streak and far stars barely move.
    private func demoOffset(time: Double) -> CGSize {
        let period: Double = 3.2
        let phase = time.truncatingRemainder(dividingBy: period)
        // Direction rotates slowly between pulses so it doesn't look mechanical.
        let dirAngle = (time / period) * 1.7
        let dirX = cos(dirAngle)
        let dirY = sin(dirAngle * 0.8)
        // Impulse fires near the start of each period, then decays.
        let tau: Double = 0.5
        let impulse = exp(-phase / tau)
        let strength: Double = 150
        return CGSize(width: dirX * strength * impulse,
                      height: dirY * strength * impulse)
    }

    // MARK: Drawing

    private func drawField(context: GraphicsContext, size: CGSize, time: Double) {
        let w = size.width
        let h = size.height
        guard w > 1, h > 1 else { return }

        let center = CGPoint(x: w / 2, y: h / 2)
        let maxRadius = sqrt(w * w + h * h) / 2 * 1.05
        let unit = min(w, h)

        let offset = baseOffset(time: time)

        // Subtle vanishing-point glow.
        drawCoreGlow(context: context, center: center, unit: unit)

        for layer in layers {
            drawLayer(context: context,
                      layer: layer,
                      center: center,
                      maxRadius: maxRadius,
                      unit: unit,
                      offset: offset,
                      time: time)
        }
    }

    private func drawCoreGlow(context: GraphicsContext, center: CGPoint, unit: CGFloat) {
        let r = unit * 0.32
        let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        let glow = GraphicsContext.Shading.radialGradient(
            Gradient(colors: [
                Color(red: 0.30, green: 0.34, blue: 0.55).opacity(0.30),
                Color(red: 0.10, green: 0.12, blue: 0.22).opacity(0.0)
            ]),
            center: center,
            startRadius: 0,
            endRadius: r
        )
        context.fill(Path(ellipseIn: rect), with: glow)
    }

    private func drawLayer(context: GraphicsContext,
                           layer: DepthStarfieldView_StarLayer,
                           center: CGPoint,
                           maxRadius: CGFloat,
                           unit: CGFloat,
                           offset: CGSize,
                           time: Double) {

        // Per-layer parallax-weighted pointer offset (in points).
        let depth = layer.parallax
        let px = CGFloat(offset.width) * depth * 0.35
        let py = CGFloat(offset.height) * depth * 0.35

        // Pointer offset speed also drives streak length on the near layers.
        let offsetSpeedMag = hypot(Double(offset.width), Double(offset.height)) * Double(depth)

        let warp = time * layer.warpSpeed
        let dotSize = unit * layer.sizeFactor

        for star in layer.stars {
            // Radial position cycles 0->1 outward from the vanishing point.
            let r = fract(star.r0 + CGFloat(warp))

            // Boundary fade: ramp in near the core, ramp out near the edge.
            let fadeIn = smooth01(r / 0.14)
            let fadeOut = 1 - smooth01((r - 0.82) / 0.18)
            let edgeFade = fadeIn * fadeOut
            if edgeFade <= 0.01 { continue }

            // Stars accelerate outward (perspective): position eased toward edge.
            let eased = r * r
            let radius = eased * maxRadius

            let pos = CGPoint(
                x: center.x + star.dirX * radius + px,
                y: center.y + star.dirY * radius + py
            )

            // Twinkle: per-star sine on its own phase.
            let tw = 0.55 + 0.45 * sin(time * layer.twinkleRate + star.phase)
            let baseAlpha = star.brightness * layer.baseAlpha
            let alpha = baseAlpha * Double(edgeFade) * tw

            // Apparent size grows as the star nears the edge.
            let brightnessF = CGFloat(star.brightness)
            let growth = 0.45 + 0.95 * r
            let bright = 0.7 + brightnessF * 0.6
            let pointSize = dotSize * growth * bright

            // Streak length: warp-radial motion + flick offset magnitude on near layers.
            let radialStreak = Double(r) * layer.warpStreak
            let streakLen = CGFloat(radialStreak + offsetSpeedMag * Double(layer.streakGain)) * unit * 0.012

            drawStar(context: context,
                     at: pos,
                     center: center,
                     pointSize: pointSize,
                     streakLen: streakLen,
                     color: layer.color,
                     alpha: alpha)
        }
    }

    private func drawStar(context: GraphicsContext,
                          at pos: CGPoint,
                          center: CGPoint,
                          pointSize: CGFloat,
                          streakLen: CGFloat,
                          color: Color,
                          alpha: Double) {

        let a = min(1.0, max(0.0, alpha))
        let shading = GraphicsContext.Shading.color(color.opacity(a))

        if streakLen > pointSize * 0.9 {
            // Hyperspace streak: a capsule pointing radially away from the core.
            let dx = pos.x - center.x
            let dy = pos.y - center.y
            let dist = max(hypot(dx, dy), 0.0001)
            let nx = dx / dist
            let ny = dy / dist
            let half = min(streakLen, pointSize * 14) * 0.5
            let tail = CGPoint(x: pos.x - nx * half, y: pos.y - ny * half)
            let head = CGPoint(x: pos.x + nx * half, y: pos.y + ny * half)
            var path = Path()
            path.move(to: tail)
            path.addLine(to: head)
            context.stroke(path,
                           with: shading,
                           style: StrokeStyle(lineWidth: pointSize, lineCap: .round))
        } else {
            let rect = CGRect(x: pos.x - pointSize / 2,
                              y: pos.y - pointSize / 2,
                              width: pointSize,
                              height: pointSize)
            context.fill(Path(ellipseIn: rect), with: shading)
        }
    }

    // MARK: Helpers

    private func fract(_ v: CGFloat) -> CGFloat {
        v - floor(v)
    }

    private func smooth01(_ x: CGFloat) -> CGFloat {
        let c = min(1, max(0, x))
        return c * c * (3 - 2 * c)
    }

    static let spaceGradient = LinearGradient(
        colors: [
            Color(red: 0.020, green: 0.024, blue: 0.055),
            Color(red: 0.039, green: 0.039, blue: 0.047),
            Color(red: 0.010, green: 0.012, blue: 0.030)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: DepthStarfieldView_Star generation (deterministic, built once)

    private static func makeLayers() -> [DepthStarfieldView_StarLayer] {
        var rng = DepthStarfieldView_SeededGenerator(seed: 0xC0FFEE_5EED)
        let far = DepthStarfieldView_StarLayer(
            stars: makeStars(count: 130, brightnessRange: 0.20...0.55, rng: &rng),
            parallax: 0.18,
            warpSpeed: 0.014,
            sizeFactor: 0.0085,
            baseAlpha: 0.70,
            twinkleRate: 1.6,
            warpStreak: 0.0,
            streakGain: 0.0,
            color: Color(red: 0.78, green: 0.82, blue: 1.00)
        )
        let mid = DepthStarfieldView_StarLayer(
            stars: makeStars(count: 100, brightnessRange: 0.45...0.85, rng: &rng),
            parallax: 0.55,
            warpSpeed: 0.030,
            sizeFactor: 0.0140,
            baseAlpha: 0.85,
            twinkleRate: 2.4,
            warpStreak: 0.9,
            streakGain: 0.55,
            color: Color(red: 0.88, green: 0.90, blue: 1.00)
        )
        let near = DepthStarfieldView_StarLayer(
            stars: makeStars(count: 70, brightnessRange: 0.65...1.00, rng: &rng),
            parallax: 1.0,
            warpSpeed: 0.058,
            sizeFactor: 0.0210,
            baseAlpha: 1.0,
            twinkleRate: 3.2,
            warpStreak: 2.2,
            streakGain: 1.4,
            color: Color(red: 1.00, green: 0.97, blue: 0.92)
        )
        return [far, mid, near]
    }

    private static func makeStars(count: Int,
                                  brightnessRange: ClosedRange<Double>,
                                  rng: inout DepthStarfieldView_SeededGenerator) -> [DepthStarfieldView_Star] {
        var out: [DepthStarfieldView_Star] = []
        out.reserveCapacity(count)
        for _ in 0..<count {
            let angle = rng.nextUnit() * 2 * Double.pi
            // Bias r0 so stars are spread along the depth axis.
            let r0 = CGFloat(rng.nextUnit())
            let phase = rng.nextUnit() * 2 * Double.pi
            let bSpan = brightnessRange.upperBound - brightnessRange.lowerBound
            let brightness = brightnessRange.lowerBound + rng.nextUnit() * bSpan
            out.append(DepthStarfieldView_Star(
                dirX: CGFloat(cos(angle)),
                dirY: CGFloat(sin(angle)),
                r0: r0,
                phase: phase,
                brightness: brightness
            ))
        }
        return out
    }
}

// MARK: - Models

private struct DepthStarfieldView_Star {
    let dirX: CGFloat      // unit direction from vanishing point
    let dirY: CGFloat
    let r0: CGFloat        // base radial position [0,1)
    let phase: Double      // twinkle phase
    let brightness: Double // [0,1]
}

private struct DepthStarfieldView_StarLayer {
    let stars: [DepthStarfieldView_Star]
    let parallax: CGFloat   // drag depth weight
    let warpSpeed: Double   // forward stream speed
    let sizeFactor: CGFloat // dot size relative to min(w,h)
    let baseAlpha: Double
    let twinkleRate: Double
    let warpStreak: Double  // streak from forward warp
    let streakGain: Double  // streak gain from drag/flick offset
    let color: Color
}

// MARK: - Deterministic RNG (LCG) — never produces a re-shuffle on re-render.

private struct DepthStarfieldView_SeededGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }

    mutating func next() -> UInt64 {
        // SplitMix64
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Uniform Double in [0,1).
    mutating func nextUnit() -> Double {
        Double(next() >> 11) * (1.0 / 9007199254740992.0)
    }
}
