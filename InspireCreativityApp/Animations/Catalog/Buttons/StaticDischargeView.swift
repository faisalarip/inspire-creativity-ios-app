// catalog-id: btn-static-discharge
import SwiftUI

/// Static Discharge — drag near the charged button to build a crackling electric
/// arc that jumps the gap toward your finger; closing the gap discharges the
/// circuit with a flash + haptic. Pure SwiftUI (Canvas + TimelineView), no shader.
struct StaticDischargeView: View {
    var demo: Bool = false

    // Interactive state
    @State private var finger: CGPoint? = nil
    @State private var dischargeTime: Date? = nil
    @State private var discharged: Bool = false
    @State private var dischargeCount: Int = 0

    // Loop / flash timing
    private let loopPeriod: Double = 3.2
    private let flashDuration: Double = 0.34

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            TimelineView(.animation) { timeline in
                let now = timeline.date
                Canvas { ctx, canvasSize in
                    draw(ctx: &ctx, size: canvasSize, now: now)
                }
            }
            .gesture(dragGesture(in: size))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.9),
                         trigger: dischargeCount)
        .contentShape(Rectangle())
    }

    // MARK: - Gesture (interactive mode only)

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !demo else { return }
                finger = value.location
                let center = anchorPoint(in: size)
                let gap = distance(value.location, center)
                let threshold = dischargeThreshold(in: size)
                if gap < threshold && !discharged {
                    discharged = true
                    dischargeTime = Date()
                    dischargeCount &+= 1
                }
            }
            .onEnded { _ in
                guard !demo else { return }
                finger = nil
                discharged = false
            }
    }

    // MARK: - Geometry helpers

    /// The electrode terminal the arc jumps from — sits left of center.
    private func anchorPoint(in size: CGSize) -> CGPoint {
        let minSide = min(size.width, size.height)
        return CGPoint(x: size.width * 0.5 - minSide * 0.18,
                       y: size.height * 0.5)
    }

    private func dischargeThreshold(in size: CGSize) -> CGFloat {
        min(size.width, size.height) * 0.16
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }

    // MARK: - Phantom finger (demo mode)

    /// Demo phase 0...1 across the loop period.
    private func loopPhase(_ now: Date) -> Double {
        let t = now.timeIntervalSinceReferenceDate
        return (t.truncatingRemainder(dividingBy: loopPeriod)) / loopPeriod
    }

    /// Phantom finger sweeps in from the right edge toward the electrode,
    /// reaching the gap near phase ~0.72, then snaps back out for the reset.
    private func phantomFinger(in size: CGSize, phase: Double) -> CGPoint {
        let center = anchorPoint(in: size)
        let startX = size.width * 0.94
        let endX = center.x + dischargeThreshold(in: size) * 0.55
        let approach = min(phase / 0.72, 1.0)
        // ease-in so it accelerates toward contact
        let eased = approach * approach
        let x: CGFloat
        if phase < 0.82 {
            x = startX + (endX - startX) * CGFloat(eased)
        } else {
            // reset: pull back out
            let back = (phase - 0.82) / 0.18
            x = endX + (startX - endX) * CGFloat(back)
        }
        // slight vertical wander so it feels hand-driven
        let wobble = CGFloat(sin(phase * .pi * 4.0)) * size.height * 0.045
        return CGPoint(x: x, y: center.y + wobble)
    }

    // MARK: - Flash intensity (unified for both modes)

    /// 0 = no flash, 1 = peak. Derived from time so it decays smoothly per frame.
    private func flashIntensity(now: Date, size: CGSize) -> Double {
        if demo {
            let phase = loopPhase(now)
            // brief flash window centred at the contact moment
            let start = 0.72
            let span = flashDuration / loopPeriod
            guard phase >= start && phase <= start + span else { return 0 }
            let local = (phase - start) / span
            // fast rise, slower fall
            return local < 0.25 ? local / 0.25 : max(0, 1 - (local - 0.25) / 0.75)
        } else {
            guard let dt = dischargeTime else { return 0 }
            let elapsed = now.timeIntervalSince(dt)
            guard elapsed >= 0 && elapsed <= flashDuration else { return 0 }
            let local = elapsed / flashDuration
            return local < 0.2 ? local / 0.2 : max(0, 1 - (local - 0.2) / 0.8)
        }
    }

    // MARK: - Drawing

    private func draw(ctx: inout GraphicsContext, size: CGSize, now: Date) {
        drawButtonBody(ctx: &ctx, size: size)

        let center = anchorPoint(in: size)
        let threshold = dischargeThreshold(in: size)

        // Resolve the active endpoint + gap.
        let endpoint: CGPoint?
        if demo {
            endpoint = phantomFinger(in: size, phase: loopPhase(now))
        } else {
            endpoint = finger
        }

        // Always-present idle electrode + faint static.
        let gap = endpoint.map { distance($0, center) } ?? .greatestFiniteMagnitude
        let span = max(size.width * 0.45, 1)
        let proximity: Double = endpoint == nil ? 0 : max(0, min(1, Double(1 - (gap - threshold) / span)))
        drawElectrode(ctx: &ctx, at: center, size: size, charge: proximity, now: now)

        // Arc — only when there is a live endpoint beyond the contact point.
        if let end = endpoint, gap > threshold * 0.35 {
            drawArc(ctx: &ctx, from: center, to: end, size: size,
                    proximity: proximity, now: now)
        }

        // Discharge flash (radial bloom at the contact / electrode).
        let flash = flashIntensity(now: now, size: size)
        if flash > 0.001 {
            let bloomAt = endpoint ?? center
            let mid = CGPoint(x: (center.x + bloomAt.x) / 2,
                              y: (center.y + bloomAt.y) / 2)
            drawFlash(ctx: &ctx, at: mid, size: size, intensity: flash)
        }
    }

    private func drawButtonBody(ctx: inout GraphicsContext, size: CGSize) {
        let minSide = min(size.width, size.height)
        let inset = minSide * 0.12
        let rect = CGRect(x: inset, y: size.height * 0.5 - minSide * 0.34,
                          width: max(size.width - inset * 2, 1),
                          height: minSide * 0.68)
        let corner = minSide * 0.16
        let path = Path(roundedRect: rect, cornerRadius: corner)

        // Dark metallic plate.
        let plate = Gradient(stops: [
            .init(color: Color(red: 0.10, green: 0.11, blue: 0.15), location: 0),
            .init(color: Color(red: 0.05, green: 0.06, blue: 0.09), location: 1)
        ])
        ctx.fill(path, with: .linearGradient(plate,
                                             startPoint: CGPoint(x: rect.midX, y: rect.minY),
                                             endPoint: CGPoint(x: rect.midX, y: rect.maxY)))

        // Subtle rim light.
        ctx.stroke(path, with: .color(Color(red: 0.30, green: 0.45, blue: 0.65).opacity(0.5)),
                   lineWidth: max(1, minSide * 0.012))

        // Label.
        let label = Text("PRESS")
            .font(.system(size: minSide * 0.13, weight: .heavy, design: .rounded))
            .kerning(minSide * 0.02)
            .foregroundStyle(Color(red: 0.62, green: 0.78, blue: 0.95))
        ctx.draw(label, at: CGPoint(x: rect.midX + minSide * 0.06, y: rect.midY))
    }

    private func drawElectrode(ctx: inout GraphicsContext, at p: CGPoint,
                               size: CGSize, charge: Double, now: Date) {
        let minSide = min(size.width, size.height)
        let r = minSide * 0.06

        // Charged glow halo (always faintly lit so the tile is never blank).
        let baseGlow = 0.22 + charge * 0.6
        let glowRect = CGRect(x: p.x - r * 2.6, y: p.y - r * 2.6,
                              width: r * 5.2, height: r * 5.2)
        let glow = Gradient(stops: [
            .init(color: Color(red: 0.45, green: 0.7, blue: 1.0).opacity(baseGlow), location: 0),
            .init(color: Color(red: 0.2, green: 0.4, blue: 0.9).opacity(0), location: 1)
        ])
        ctx.fill(Path(ellipseIn: glowRect),
                 with: .radialGradient(glow, center: p, startRadius: 0, endRadius: r * 2.6))

        // Metal nub.
        let nub = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
        let metal = Gradient(stops: [
            .init(color: Color(red: 0.85, green: 0.88, blue: 0.95), location: 0),
            .init(color: Color(red: 0.35, green: 0.40, blue: 0.50), location: 1)
        ])
        ctx.fill(nub, with: .radialGradient(metal,
                                            center: CGPoint(x: p.x - r * 0.35, y: p.y - r * 0.35),
                                            startRadius: 0, endRadius: r * 1.8))

        // Tiny idle static sparks crawling on the nub even when idle.
        var rng = StaticDischargeView_LCG(seed: quantizedSeed(now, hz: 14) &+ 991)
        let sparkCount = 3
        for _ in 0..<sparkCount {
            let ang = rng.unit() * 2 * .pi
            let len = r * CGFloat(0.6 + rng.unit() * (0.5 + charge))
            let sp = CGPoint(x: p.x + CGFloat(cos(ang)) * r, y: p.y + CGFloat(sin(ang)) * r)
            let ep = CGPoint(x: sp.x + CGFloat(cos(ang)) * len, y: sp.y + CGFloat(sin(ang)) * len)
            var spark = Path()
            spark.move(to: sp)
            spark.addLine(to: ep)
            ctx.stroke(spark,
                       with: .color(Color(red: 0.7, green: 0.85, blue: 1.0)
                        .opacity(0.35 + charge * 0.4)),
                       lineWidth: max(0.6, minSide * 0.006))
        }
    }

    private func drawArc(ctx: inout GraphicsContext, from a: CGPoint, to b: CGPoint,
                         size: CGSize, proximity: Double, now: Date) {
        let minSide = min(size.width, size.height)
        let intensity = 0.35 + proximity * 0.65
        let roughness = minSide * CGFloat(0.10 + (1 - proximity) * 0.06)

        // Re-jitter at ~16Hz so it crackles without strobing at 120fps.
        let seed = quantizedSeed(now, hz: 16)

        let main = boltPath(from: a, to: b, seed: seed,
                            roughness: roughness, displacement: 0.5, in: size)

        // Wide soft glow underlay.
        ctx.stroke(main,
                   with: .color(Color(red: 0.35, green: 0.6, blue: 1.0)
                    .opacity(0.30 + 0.45 * intensity)),
                   style: StrokeStyle(lineWidth: max(2, minSide * 0.05) * CGFloat(intensity),
                                      lineCap: .round, lineJoin: .round))

        // Mid blue.
        ctx.stroke(main,
                   with: .color(Color(red: 0.55, green: 0.75, blue: 1.0)
                    .opacity(0.55 + 0.4 * intensity)),
                   style: StrokeStyle(lineWidth: max(1.5, minSide * 0.022) * CGFloat(intensity),
                                      lineCap: .round, lineJoin: .round))

        // White-hot core.
        ctx.stroke(main,
                   with: .color(Color(red: 0.9, green: 0.96, blue: 1.0)
                    .opacity(0.7 + 0.3 * intensity)),
                   style: StrokeStyle(lineWidth: max(0.8, minSide * 0.009),
                                      lineCap: .round, lineJoin: .round))

        // A couple of short forks for that electric feel.
        var rng = StaticDischargeView_LCG(seed: seed &+ 7)
        let forkCount = 2
        for _ in 0..<forkCount {
            let t = CGFloat(0.3 + rng.unit() * 0.5)
            let origin = CGPoint(x: a.x + (b.x - a.x) * t,
                                 y: a.y + (b.y - a.y) * t)
            let ang = (rng.unit() - 0.5) * .pi
            let flen = minSide * CGFloat(0.08 + rng.unit() * 0.1)
            let tip = CGPoint(x: origin.x + CGFloat(cos(ang)) * flen,
                              y: origin.y + CGFloat(sin(ang)) * flen)
            let fork = boltPath(from: origin, to: tip, seed: seed &+ UInt64(rng.next() & 0xFF),
                                roughness: roughness * 0.6, displacement: 0.45, in: size)
            ctx.stroke(fork,
                       with: .color(Color(red: 0.6, green: 0.8, blue: 1.0)
                        .opacity(0.4 * intensity)),
                       style: StrokeStyle(lineWidth: max(0.8, minSide * 0.012) * CGFloat(intensity),
                                          lineCap: .round, lineJoin: .round))
        }
    }

    private func drawFlash(ctx: inout GraphicsContext, at p: CGPoint,
                           size: CGSize, intensity: Double) {
        let minSide = min(size.width, size.height)
        let clamped = min(1, intensity)
        let r = minSide * CGFloat(0.25 + 0.45 * clamped)
        let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
        // Clamp peak opacity so the button is never fully hidden.
        let peak = 0.85 * clamped
        let g = Gradient(stops: [
            .init(color: Color(red: 1.0, green: 1.0, blue: 1.0).opacity(peak), location: 0),
            .init(color: Color(red: 0.6, green: 0.8, blue: 1.0).opacity(peak * 0.5), location: 0.4),
            .init(color: Color(red: 0.3, green: 0.5, blue: 1.0).opacity(0), location: 1)
        ])
        ctx.fill(Path(ellipseIn: rect),
                 with: .radialGradient(g, center: p, startRadius: 0, endRadius: max(r, 1)))
    }

    // MARK: - Bolt geometry (recursive midpoint displacement)

    private func boltPath(from a: CGPoint, to b: CGPoint, seed: UInt64,
                          roughness: CGFloat, displacement: CGFloat,
                          in size: CGSize) -> Path {
        var rng = StaticDischargeView_LCG(seed: seed)
        var points: [CGPoint] = [a, b]
        let passes = 5
        var disp = roughness
        for _ in 0..<passes {
            var next: [CGPoint] = []
            next.reserveCapacity(points.count * 2 - 1)
            for i in 0..<(points.count - 1) {
                let p0 = points[i]
                let p1 = points[i + 1]
                next.append(p0)
                let mid = CGPoint(x: (p0.x + p1.x) / 2, y: (p0.y + p1.y) / 2)
                // perpendicular offset
                let dx = p1.x - p0.x
                let dy = p1.y - p0.y
                let len = (dx * dx + dy * dy).squareRoot()
                let nx = len > 0 ? -dy / len : 0
                let ny = len > 0 ? dx / len : 0
                let off = (CGFloat(rng.unit()) - 0.5) * disp * 2
                next.append(CGPoint(x: mid.x + nx * off, y: mid.y + ny * off))
            }
            next.append(points[points.count - 1])
            points = next
            disp *= displacement
        }

        var path = Path()
        path.move(to: points[0])
        for i in 1..<points.count {
            path.addLine(to: points[i])
        }
        return path
    }

    // MARK: - Seeded RNG / time quantization

    /// Quantize the clock to `hz` ticks so jitter regenerates at a controlled
    /// rate (not every frame) — prevents harsh strobing at 120fps.
    private func quantizedSeed(_ now: Date, hz: Double) -> UInt64 {
        let tick = (now.timeIntervalSinceReferenceDate * hz).rounded(.down)
        return UInt64(bitPattern: Int64(tick))
    }
}

/// Tiny seedable linear-congruential generator. SystemRandomNumberGenerator
/// isn't seedable, so we hand-roll one to get stable per-tick randomness.
private struct StaticDischargeView_LCG {
    private var state: UInt64
    init(seed: UInt64) {
        // avoid a zero state
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
    /// Returns a Double in 0...1.
    mutating func unit() -> Double {
        Double(next() >> 11) * (1.0 / 9007199254740992.0)
    }
}
