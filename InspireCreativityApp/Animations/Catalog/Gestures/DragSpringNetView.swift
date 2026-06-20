// catalog-id: ges-drag-spring-net
import SwiftUI

// MARK: - Trampoline Net Drag
/// Press into a woven mesh net and it deforms into a stretched pocket with the
/// surrounding grid lines pulling taut; release launches a ball upward
/// proportional to the depression depth.
///
/// - `demo == true`  : a self-driving loop pushes a virtual press point down and
///                     releases, flinging the ball on rebound (no touch needed).
/// - `demo == false` : the real interactive component — drag into the net, lift
///                     to fling the ball.
struct DragSpringNetView: View {
    var demo: Bool = false

    // Grid resolution (kept coarse for perf — ~10×10 nodes).
    private let cols = 10
    private let rows = 10

    // Interactive state ---------------------------------------------------
    // NOTE: Canvas reads these synchronously inside its closure and does NOT
    // interpolate withAnimation-driven values. So all motion (ball arc + net
    // twang) is derived from `timeline.date` against `launchTime`, exactly like
    // the demo path — never from a @State mutated under withAnimation.
    @State private var pressUnit: CGPoint = CGPoint(x: 0.5, y: 0.5) // press point in 0…1
    @State private var pressDepth: CGFloat = 0                      // live pocket depth while pressing 0…1
    @State private var ballX: CGFloat = 0.5                         // horizontal unit position
    @State private var isPressing: Bool = false

    // Flight state (release → ballistic arc + twang) ----------------------
    @State private var launchTime: Date? = nil   // when the finger lifted
    @State private var launchDepth: CGFloat = 0  // depression depth captured at release
    @State private var launchTrigger: Int = 0    // bumped on release → haptic (interactive only)

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            if demo {
                demoCanvas(size: size)
            } else {
                interactiveCanvas(size: size)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hexCode: "#0d0e16"))
    }

    // MARK: - Demo (self-driving)

    private func demoCanvas(size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let s = demoState(time: t)
            netCanvas(size: size,
                      press: s.press,
                      depth: s.depth,
                      ballX: s.ballX,
                      ballY: s.ballY)
        }
    }

    /// Drives press/depth/ball from a ~3.4s loop clock.
    private func demoState(time: TimeInterval) -> (press: CGPoint, depth: CGFloat, ballX: CGFloat, ballY: CGFloat) {
        let period: Double = 3.4
        let phase = (time.truncatingRemainder(dividingBy: period)) / period // 0…1

        // Press point drifts gently so the pocket isn't always dead-center.
        let px = 0.5 + 0.16 * CGFloat(sin(time * 0.9))
        let py = 0.52 + 0.05 * CGFloat(cos(time * 0.7))
        let press = CGPoint(x: px, y: py)

        // Phase A (0…0.45): push in, depth ramps up with ease.
        // Phase B (0.45…1): release — net twangs flat, ball arcs up & falls back.
        if phase < 0.45 {
            let p = phase / 0.45
            let d = CGFloat(easeInOut(p))
            return (press, d, px, 0) // ball rides the pocket center while pressing
        } else {
            // Real seconds since release so the shared physics helpers apply.
            let launchDepth: CGFloat = 1.0
            let releaseSeconds = (phase - 0.45) * period
            let by = ballisticArc(t: releaseSeconds, depth: launchDepth)
            let dp = launchDepth * springTwang(t: releaseSeconds)
            return (press, dp, px, by)
        }
    }

    // MARK: - Interactive

    private func interactiveCanvas(size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let s = interactiveState(now: timeline.date)
            netCanvas(size: size,
                      press: pressUnit,
                      depth: s.depth,
                      ballX: ballX,
                      ballY: s.ballY)
        }
        .contentShape(Rectangle())
        .gesture(dragGesture(size: size))
        .sensoryFeedback(.impact(weight: .medium), trigger: launchTrigger)
    }

    /// Derives the rendered depth + ball height from the clock, never from a
    /// withAnimation-mutated @State (Canvas would not interpolate that).
    private func interactiveState(now: Date) -> (depth: CGFloat, ballY: CGFloat) {
        if isPressing {
            // Live press: net follows the finger, ball waits in the pocket.
            return (pressDepth, 0)
        }
        guard let start = launchTime else {
            return (0, 0) // at rest, ready for the next drag
        }
        let t = now.timeIntervalSince(start)
        let flight = flightDuration(depth: launchDepth)
        if t >= flight {
            return (0, 0) // settled — repeatable
        }
        let by = ballisticArc(t: t, depth: launchDepth)
        let dp = launchDepth * springTwang(t: t) // net relaxes flat with a twang (signed = overshoot)
        return (dp, by)
    }

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isPressing = true
                launchTime = nil // cancel any in-flight ball; finger grabs the net
                let ux = clampUnit(value.location.x / max(size.width, 1))
                let uy = clampUnit(value.location.y / max(size.height, 1))
                pressUnit = CGPoint(x: ux, y: uy)
                ballX = ux

                // Depth grows with how far the finger has pulled "into" the net
                // (downward translation), normalized by view height.
                let pull = max(0, value.translation.height) / max(size.height, 1)
                pressDepth = min(1, pull * 1.6 + 0.15) // a little depth on touch-down
            }
            .onEnded { _ in
                launchDepth = pressDepth
                isPressing = false
                launchTime = .now           // start the clock-driven flight
                launchTrigger &+= 1          // haptic (interactive only)
            }
    }

    // MARK: - Unified Net Renderer (shared by both modes)

    private func netCanvas(size: CGSize,
                           press: CGPoint,
                           depth: CGFloat,
                           ballX: CGFloat,
                           ballY: CGFloat) -> some View {
        Canvas { ctx, canvasSize in
            let layout = NetLayout(size: canvasSize, cols: cols, rows: rows)

            // Pocket-center darkening to sell the well.
            drawWellShadow(ctx: &ctx, layout: layout, press: press, depth: depth)

            // Woven grid (taut lines between displaced nodes).
            drawWeave(ctx: &ctx, layout: layout, press: press, depth: depth)

            // The launched ball.
            drawBall(ctx: &ctx, layout: layout,
                     press: press, depth: depth,
                     ballX: ballX, ballY: ballY)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Node displacement

    /// A single net node's position after radial pull toward the press point.
    private func displacedNode(row: Int, col: Int,
                               layout: NetLayout,
                               press: CGPoint, depth: CGFloat) -> CGPoint {
        let base = layout.basePoint(row: row, col: col)
        guard abs(depth) > 0.0005 else { return base } // signed: <0 = rebound overshoot

        let pressPx = CGPoint(x: press.x * layout.size.width,
                              y: press.y * layout.size.height)
        let dx = pressPx.x - base.x
        let dy = pressPx.y - base.y
        let dist2 = dx * dx + dy * dy

        // Cheap Gaussian-ish falloff: nodes near the press get pulled most.
        let sigma = layout.minDim * 0.42
        let falloff = exp(-dist2 / (2 * sigma * sigma))
        let pull = falloff * depth

        // Horizontal pull toward the press (the weave converging) + a vertical
        // sag component so the pocket reads as a depression.
        let nx = base.x + dx * pull * 0.55
        let sag = layout.minDim * 0.30 * pull
        let ny = base.y + dy * pull * 0.45 + sag
        return CGPoint(x: nx, y: ny)
    }

    // MARK: - Drawing helpers

    private func drawWellShadow(ctx: inout GraphicsContext,
                                layout: NetLayout,
                                press: CGPoint, depth: CGFloat) {
        guard depth > 0.02 else { return }
        let center = CGPoint(x: press.x * layout.size.width,
                             y: press.y * layout.size.height + layout.minDim * 0.20 * depth)
        let r = layout.minDim * (0.18 + 0.30 * depth)
        let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        let shade = GraphicsContext.Shading.radialGradient(
            Gradient(colors: [
                Color.black.opacity(0.45 * Double(depth)),
                Color.clear
            ]),
            center: center, startRadius: 0, endRadius: r)
        ctx.fill(Path(ellipseIn: rect), with: shade)
    }

    private func drawWeave(ctx: inout GraphicsContext,
                           layout: NetLayout,
                           press: CGPoint, depth: CGFloat) {
        // Precompute displaced nodes once per frame.
        var pts = [[CGPoint]](repeating: [CGPoint](repeating: .zero, count: cols),
                              count: rows)
        for r in 0..<rows {
            for c in 0..<cols {
                pts[r][c] = displacedNode(row: r, col: c, layout: layout,
                                          press: press, depth: depth)
            }
        }

        let baseColor = Color(hexCode: "#5b7cff")
        let hotColor = Color(hexCode: "#8fa9ff")
        let lineW: CGFloat = max(0.8, layout.minDim * 0.012)

        // Horizontal threads.
        for r in 0..<rows {
            var path = Path()
            path.move(to: pts[r][0])
            for c in 1..<cols { path.addLine(to: pts[r][c]) }
            let tension = threadTension(rowOrCol: r, count: rows, depth: depth)
            ctx.stroke(path,
                       with: .color(baseColor.opacity(0.55 + 0.4 * tension)),
                       lineWidth: lineW)
        }
        // Vertical threads.
        for c in 0..<cols {
            var path = Path()
            path.move(to: pts[0][c])
            for r in 1..<rows { path.addLine(to: pts[r][c]) }
            let tension = threadTension(rowOrCol: c, count: cols, depth: depth)
            ctx.stroke(path,
                       with: .color(hotColor.opacity(0.40 + 0.45 * tension)),
                       lineWidth: lineW)
        }

        // Glow nodes near the pocket.
        if depth > 0.05 {
            let nodeR = max(0.8, layout.minDim * 0.014)
            for r in stride(from: 0, to: rows, by: 1) {
                for c in stride(from: 0, to: cols, by: 1) {
                    let p = pts[r][c]
                    let d = nodeGlow(at: p, press: press, layout: layout)
                    guard d > 0.15 else { continue }
                    let rect = CGRect(x: p.x - nodeR, y: p.y - nodeR,
                                      width: nodeR * 2, height: nodeR * 2)
                    ctx.fill(Path(ellipseIn: rect),
                             with: .color(Color(hexCode: "#cfe0ff").opacity(Double(d) * Double(depth))))
                }
            }
        }
    }

    /// Brightens threads as the net tightens.
    private func threadTension(rowOrCol: Int, count: Int, depth: CGFloat) -> Double {
        let center = Double(count - 1) / 2.0
        let dist = abs(Double(rowOrCol) - center) / max(center, 1)
        let proximity = 1.0 - dist
        return Double(depth) * (0.4 + 0.6 * proximity)
    }

    private func nodeGlow(at p: CGPoint, press: CGPoint, layout: NetLayout) -> CGFloat {
        let pressPx = CGPoint(x: press.x * layout.size.width,
                              y: press.y * layout.size.height)
        let dx = pressPx.x - p.x
        let dy = pressPx.y - p.y
        let d2 = dx * dx + dy * dy
        let sigma = layout.minDim * 0.34
        return exp(-d2 / (2 * sigma * sigma))
    }

    private func drawBall(ctx: inout GraphicsContext,
                          layout: NetLayout,
                          press: CGPoint, depth: CGFloat,
                          ballX: CGFloat, ballY: CGFloat) {
        let r = layout.minDim * 0.085

        // Resting plane = net surface at the press point (sinks with depth).
        let restY = layout.size.height * press.y + layout.minDim * 0.30 * depth
        // Launch height lifts the ball up; clamp so it never leaves the frame.
        let lift = layout.size.height * 0.62 * ballY
        let cy = max(r + 2, restY - lift)
        let cx = max(r, min(layout.size.width - r, ballX * layout.size.width))
        let center = CGPoint(x: cx, y: cy)

        // Soft contact shadow on the net plane.
        let shadowScale = 1.0 - 0.5 * Double(ballY)
        let sr = r * CGFloat(shadowScale)
        let srect = CGRect(x: cx - sr, y: restY - sr * 0.35,
                           width: sr * 2, height: sr * 0.7)
        ctx.fill(Path(ellipseIn: srect),
                 with: .color(Color.black.opacity(0.30 * shadowScale)))

        // The ball: glossy radial gradient.
        let brect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        let grad = GraphicsContext.Shading.radialGradient(
            Gradient(colors: [
                Color(hexCode: "#ffd36b"),
                Color(hexCode: "#ff8c42"),
                Color(hexCode: "#e0591f")
            ]),
            center: CGPoint(x: center.x - r * 0.3, y: center.y - r * 0.35),
            startRadius: 0, endRadius: r * 1.4)
        ctx.fill(Path(ellipseIn: brect), with: grad)

        // Specular highlight.
        let hr = r * 0.34
        let hrect = CGRect(x: center.x - r * 0.42, y: center.y - r * 0.5,
                           width: hr * 2, height: hr * 2)
        ctx.fill(Path(ellipseIn: hrect),
                 with: .color(Color.white.opacity(0.7)))
    }

    // MARK: - Shared flight physics (clock-driven, used by both modes)

    /// Total seconds the launched ball stays in the air, scaled by launch depth.
    private func flightDuration(depth: CGFloat) -> Double {
        let apex = min(1.0, max(0.12, Double(depth)))
        return 0.85 + 0.75 * apex
    }

    /// Ball height in unit space (0 = net plane, 1 = full apex) at time `t`
    /// seconds after release. Asymmetric arc: snappy rise, gravity-weighted fall.
    private func ballisticArc(t: Double, depth: CGFloat) -> CGFloat {
        let dur = flightDuration(depth: depth)
        guard t > 0, t < dur else { return 0 }
        let apex = min(1.0, max(0.12, Double(depth)))
        let p = t / dur                    // 0…1 over the flight
        // Parabolic arc 0→1→0 with a slight skew so the fall lingers.
        let skew = pow(p, 0.85)            // reach apex a touch sooner
        let arc = 4 * skew * (1 - skew)
        return CGFloat(apex * arc)
    }

    /// Damped-spring relaxation for the net "twang" after release:
    /// exp(-k·t)·cos(ω·t) → ~bounce 0.5. Returns a multiplier on launch depth.
    private func springTwang(t: Double) -> CGFloat {
        guard t > 0 else { return 1 }
        let k = 7.5        // decay
        let omega = 17.0   // oscillation
        let v = exp(-k * t) * cos(omega * t)
        return CGFloat(max(-0.25, v)) // allow a small overshoot below the plane
    }

    // MARK: - Math utilities

    private func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }

    private func clampUnit(_ v: CGFloat) -> CGFloat { min(1, max(0, v)) }
}

// MARK: - Net layout geometry

private struct NetLayout {
    let size: CGSize
    let cols: Int
    let rows: Int
    let inset: CGFloat
    let minDim: CGFloat

    init(size: CGSize, cols: Int, rows: Int) {
        self.size = size
        self.cols = cols
        self.rows = rows
        self.minDim = min(size.width, size.height)
        self.inset = self.minDim * 0.10
    }

    func basePoint(row: Int, col: Int) -> CGPoint {
        let usableW = size.width - inset * 2
        let usableH = size.height - inset * 2
        let x = inset + usableW * CGFloat(col) / CGFloat(max(cols - 1, 1))
        let y = inset + usableH * CGFloat(row) / CGFloat(max(rows - 1, 1))
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Hex color helper

private extension Color {
    init(hexCode hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: s).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch s.count {
        case 3: // RGB (12-bit)
            (r, g, b, a) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17, 255)
        case 6: // RGB (24-bit)
            (r, g, b, a) = (int >> 16, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8: // ARGB (32-bit)
            (r, g, b, a) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF, int >> 24)
        default:
            (r, g, b, a) = (255, 255, 255, 255)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - Preview
