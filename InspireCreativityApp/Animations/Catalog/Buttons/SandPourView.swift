// catalog-id: btn-sand-pour
import SwiftUI

// MARK: - Sand Pour
// On tap the button drains its grains downward like an hourglass: particles
// stream through a central pinch to refill a lower chamber that morphs into a
// success label. Pure SwiftUI Canvas + TimelineView. iOS 17.

public struct SandPourView: View {
    public var demo: Bool = false

    public init(demo: Bool = false) {
        self.demo = demo
    }

    // One full pour in interactive mode, in seconds.
    private let pourDuration: Double = 2.6
    // Demo loop: drain time + a short "settled" hold so the success label reads.
    private let demoCycle: Double = 3.6
    private let demoHold: Double = 0.9

    @State private var pourStart: Date? = nil
    @State private var didComplete: Bool = false

    public var body: some View {
        GeometryReader { proxy in
            content(size: proxy.size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !demo else { return }
            startPour()
        }
        .sensoryFeedback(trigger: didComplete) { _, now in
            now ? .success : nil
        }
    }

    @ViewBuilder
    private func content(size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let p = progress(at: timeline.date)
            hourglass(size: size, p: p)
        }
    }

    // MARK: - Progress source

    private func progress(at date: Date) -> CGFloat {
        if demo {
            let t = date.timeIntervalSinceReferenceDate
            let phase = t.truncatingRemainder(dividingBy: demoCycle)
            // Drain over (demoCycle - demoHold), then hold full-pile before wrap.
            let drain = max(demoCycle - demoHold, 0.001)
            let raw = min(max(phase / drain, 0), 1)
            return CGFloat(raw)
        } else {
            guard let start = pourStart else { return 0 }
            let elapsed = date.timeIntervalSince(start)
            return CGFloat(min(max(elapsed / pourDuration, 0), 1))
        }
    }

    private func startPour() {
        didComplete = false
        pourStart = .now
        DispatchQueue.main.asyncAfter(deadline: .now() + pourDuration) {
            didComplete = true
        }
    }

    // MARK: - Composed view

    @ViewBuilder
    private func hourglass(size: CGSize, p: CGFloat) -> some View {
        let geo = SandPourView_HourglassGeometry(size: size)
        ZStack {
            background(geo: geo)
            SandPourView_SandCanvas(geo: geo, progress: p)
            glassFrame(geo: geo)
            successOverlay(geo: geo, p: p)
        }
    }

    // MARK: - Static chrome

    @ViewBuilder
    private func background(geo: SandPourView_HourglassGeometry) -> some View {
        RoundedRectangle(cornerRadius: geo.tileCorner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.12, green: 0.10, blue: 0.07),
                        Color(red: 0.07, green: 0.06, blue: 0.045)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: geo.tileCorner, style: .continuous)
                    .stroke(Color(red: 0.30, green: 0.26, blue: 0.18).opacity(0.55), lineWidth: 1)
            )
    }

    @ViewBuilder
    private func glassFrame(geo: SandPourView_HourglassGeometry) -> some View {
        let glass = SandPourView_HourglassShape(geo: geo)
        ZStack {
            // Soft glass tint so the chamber reads even when empty.
            glass
                .fill(Color(red: 0.55, green: 0.65, blue: 0.72).opacity(0.06))
            // Specular vertical highlight down the glass.
            glass
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1, green: 1, blue: 1).opacity(0.16),
                            Color(red: 1, green: 1, blue: 1).opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            glass
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.78, green: 0.80, blue: 0.85).opacity(0.85),
                            Color(red: 0.40, green: 0.42, blue: 0.48).opacity(0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: geo.frameLine
                )
            // Pinch end-caps.
            Capsule()
                .fill(Color(red: 0.70, green: 0.72, blue: 0.78).opacity(0.85))
                .frame(width: geo.neckHalf * 2.4, height: geo.frameLine * 1.6)
                .position(x: geo.center.x, y: geo.neckY)
        }
    }

    @ViewBuilder
    private func successOverlay(geo: SandPourView_HourglassGeometry, p: CGFloat) -> some View {
        let appear = morphAmount(p)
        ZStack {
            Circle()
                .fill(Color(red: 0.36, green: 0.70, blue: 0.42))
                .frame(width: geo.badge, height: geo.badge)
                .shadow(color: Color(red: 0.36, green: 0.70, blue: 0.42).opacity(0.6),
                        radius: geo.badge * 0.18)
            Image(systemName: "checkmark")
                .font(.system(size: geo.badge * 0.5, weight: .heavy))
                .foregroundStyle(.white)
        }
        .scaleEffect(0.6 + 0.4 * appear)
        .opacity(Double(appear))
        .position(x: geo.center.x, y: geo.lowerCenterY)
        .allowsHitTesting(false)
    }

    // Crossfade window p in [0.82, 1.0].
    private func morphAmount(_ p: CGFloat) -> CGFloat {
        let lo: CGFloat = 0.82
        guard p > lo else { return 0 }
        let t = (p - lo) / (1 - lo)
        // Smoothstep for a gentle pop.
        return t * t * (3 - 2 * t)
    }
}

// MARK: - Geometry

private struct SandPourView_HourglassGeometry {
    let size: CGSize
    let center: CGPoint
    let tileCorner: CGFloat
    let frameLine: CGFloat

    // Vertical anchors.
    let topY: CGFloat       // top inner edge of upper chamber
    let neckY: CGFloat      // pinch
    let bottomY: CGFloat    // bottom inner edge of lower chamber

    // Horizontal half-widths.
    let topHalf: CGFloat
    let neckHalf: CGFloat
    let grainRadius: CGFloat
    let badge: CGFloat

    init(size: CGSize) {
        self.size = size
        let minSide = min(size.width, size.height)
        self.center = CGPoint(x: size.width / 2, y: size.height / 2)
        self.tileCorner = minSide * 0.16

        // Hourglass occupies a centered portrait box.
        let h = minSide * 0.78
        self.topY = center.y - h / 2
        self.bottomY = center.y + h / 2
        self.neckY = center.y

        self.topHalf = minSide * 0.30
        self.neckHalf = max(minSide * 0.035, 2.4)
        self.frameLine = max(minSide * 0.018, 1.4)
        self.grainRadius = max(minSide * 0.012, 1.0)
        self.badge = minSide * 0.42
    }

    var lowerCenterY: CGFloat { (neckY + bottomY) / 2 }

    // Half-width of the glass funnel at a given y.
    func halfWidth(atY y: CGFloat) -> CGFloat {
        if y <= neckY {
            let t = (y - topY) / max(neckY - topY, 0.001) // 0 top -> 1 neck
            return topHalf + (neckHalf - topHalf) * clamp01(t)
        } else {
            let t = (y - neckY) / max(bottomY - neckY, 0.001) // 0 neck -> 1 bottom
            return neckHalf + (topHalf - neckHalf) * clamp01(t)
        }
    }
}

private func clamp01(_ v: CGFloat) -> CGFloat { min(max(v, 0), 1) }

// MARK: - Hourglass outline shape

private struct SandPourView_HourglassShape: Shape {
    let geo: SandPourView_HourglassGeometry

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = geo.center.x
        let cap = geo.topHalf * 0.34 // rounded chamber lip inset

        // Start top-left, go clockwise: upper chamber -> neck -> lower chamber.
        path.move(to: CGPoint(x: cx - geo.topHalf + cap, y: geo.topY))
        path.addLine(to: CGPoint(x: cx + geo.topHalf - cap, y: geo.topY))
        path.addQuadCurve(
            to: CGPoint(x: cx + geo.topHalf, y: geo.topY + cap),
            control: CGPoint(x: cx + geo.topHalf, y: geo.topY)
        )
        // Right wall funnels to neck.
        path.addLine(to: CGPoint(x: cx + geo.neckHalf, y: geo.neckY))
        // Down into lower chamber.
        path.addLine(to: CGPoint(x: cx + geo.topHalf, y: geo.bottomY - cap))
        path.addQuadCurve(
            to: CGPoint(x: cx + geo.topHalf - cap, y: geo.bottomY),
            control: CGPoint(x: cx + geo.topHalf, y: geo.bottomY)
        )
        path.addLine(to: CGPoint(x: cx - geo.topHalf + cap, y: geo.bottomY))
        path.addQuadCurve(
            to: CGPoint(x: cx - geo.topHalf, y: geo.bottomY - cap),
            control: CGPoint(x: cx - geo.topHalf, y: geo.bottomY)
        )
        path.addLine(to: CGPoint(x: cx - geo.neckHalf, y: geo.neckY))
        path.addLine(to: CGPoint(x: cx - geo.topHalf, y: geo.topY + cap))
        path.addQuadCurve(
            to: CGPoint(x: cx - geo.topHalf + cap, y: geo.topY),
            control: CGPoint(x: cx - geo.topHalf, y: geo.topY)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Grain seed (immutable, computed once)

private struct SandPourView_GrainSeed {
    let column: CGFloat       // -1...1 horizontal slot in top chamber
    let depth: CGFloat        // 0 (top of upper chamber, leaves last) ... 1 (nearest neck, leaves first)
    let releaseFraction: CGFloat // when in [0,1] this grain begins to fall
    let fallSpan: CGFloat     // how long the fall takes, in progress units
    let pileColumn: CGFloat   // -1...1 landing slot
    let pileRow: CGFloat      // 0 (lands first, bottom) ... 1 (lands last, top)
    let xJitter: CGFloat      // small per-grain offset
    let shade: CGFloat        // 0...1 amber brightness pick
}

private enum SandPourView_SandModel {
    static let grainCount = 360

    static let seeds: [SandPourView_GrainSeed] = {
        var rng = SandPourView_SeededRandom(seed: 0x5A4D)
        var out: [SandPourView_GrainSeed] = []
        out.reserveCapacity(grainCount)
        for i in 0..<grainCount {
            let depth = CGFloat(i) / CGFloat(grainCount - 1)
            // Grains nearer the neck (high depth) leave first.
            let release = depth * 0.62 + rng.next() * 0.06
            let span = 0.16 + rng.next() * 0.10
            let col = rng.next() * 2 - 1
            // Pile fills bottom-up: first-to-leave lands lowest.
            let pileRow = depth
            let pileCol = rng.next() * 2 - 1
            out.append(
                SandPourView_GrainSeed(
                    column: col,
                    depth: depth,
                    releaseFraction: min(release, 0.80),
                    fallSpan: span,
                    pileColumn: pileCol,
                    pileRow: pileRow,
                    xJitter: rng.next() * 2 - 1,
                    shade: rng.next()
                )
            )
        }
        return out
    }()
}

// Tiny deterministic LCG so the grain field is stable across frames & instances.
private struct SandPourView_SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 2862933555777941757 &+ 3037000493 }
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let v = (state >> 33) & 0xFFFFFF
        return CGFloat(v) / CGFloat(0xFFFFFF)
    }
}

// MARK: - Grain position as a pure function of progress

private func grainPosition(seed: SandPourView_GrainSeed, p: CGFloat, geo: SandPourView_HourglassGeometry) -> (point: CGPoint, falling: Bool) {
    let release = seed.releaseFraction
    let landed = min(release + seed.fallSpan, 1)

    if p <= release {
        // Resting in the upper chamber. The top sand surface drops as grains
        // leave, so resting grains sit between a descending surface and the neck.
        return (restingTopPoint(seed: seed, p: p, geo: geo), false)
    } else if p >= landed {
        // Parked in the pile.
        return (pilePoint(seed: seed, geo: geo), false)
    } else {
        // Falling through the neck.
        let t = (p - release) / max(seed.fallSpan, 0.001)
        return (fallingPoint(seed: seed, t: clamp01(t), geo: geo), true)
    }
}

// Upper chamber: surface recedes toward the neck as p grows.
private func restingTopPoint(seed: SandPourView_GrainSeed, p: CGFloat, geo: SandPourView_HourglassGeometry) -> CGPoint {
    // Fraction of upper sand already gone (drives the falling surface).
    let drained = clamp01(p / 0.62)
    let surfaceY = geo.topY + (geo.neckY - geo.topY) * (0.10 + 0.78 * drained)
    // This grain's vertical slot among still-resting grains.
    let restY = surfaceY + (geo.neckY - surfaceY) * (1 - seed.depth) * 0.92
    let half = geo.halfWidth(atY: restY) - geo.grainRadius * 2
    let x = geo.center.x + seed.column * max(half, 1)
    return CGPoint(x: x, y: restY)
}

// Falling: top rest spot -> neck pinch -> pile slot, with gravity easing.
private func fallingPoint(seed: SandPourView_GrainSeed, t: CGFloat, geo: SandPourView_HourglassGeometry) -> CGPoint {
    let startY = geo.topY + (geo.neckY - geo.topY) * 0.82
    let endY = pilePoint(seed: seed, geo: geo).y
    // Quadratic (gravity) ease for vertical fall.
    let easedV = t * t
    let y = startY + (endY - startY) * easedV

    // Horizontal: funnel toward the neck (x≈center) around the midpoint, then
    // spread out to the landing column.
    let startX = geo.center.x + seed.column * (geo.topHalf * 0.45)
    let neckX = geo.center.x + seed.xJitter * geo.neckHalf * 0.6
    let endX = pilePoint(seed: seed, geo: geo).x

    let x: CGFloat
    if t < 0.5 {
        let s = t / 0.5
        x = startX + (neckX - startX) * easeInOut(s)
    } else {
        let s = (t - 0.5) / 0.5
        x = neckX + (endX - neckX) * easeInOut(s)
    }
    return CGPoint(x: x, y: y)
}

// Pile in the lower chamber, filling bottom-up.
private func pilePoint(seed: SandPourView_GrainSeed, geo: SandPourView_HourglassGeometry) -> CGPoint {
    // pileRow 0 -> bottom, 1 -> higher. Pile height grows toward the neck.
    let pileTopY = geo.neckY + (geo.bottomY - geo.neckY) * 0.30
    let y = geo.bottomY - (geo.bottomY - pileTopY) * seed.pileRow
    // Cone profile: wider near the bottom.
    let local = (geo.bottomY - y) / max(geo.bottomY - pileTopY, 0.001) // 0 bottom -> 1 top
    let maxHalf = geo.halfWidth(atY: y) - geo.grainRadius * 2
    let coneHalf = maxHalf * (1 - 0.55 * local)
    let x = geo.center.x + seed.pileColumn * max(coneHalf, 1)
    return CGPoint(x: x, y: y - geo.grainRadius)
}

private func easeInOut(_ t: CGFloat) -> CGFloat {
    if t < 0.5 { return 2 * t * t }
    let u = -2 * t + 2
    return 1 - (u * u) / 2
}

// MARK: - Sand Canvas

private struct SandPourView_SandCanvas: View {
    let geo: SandPourView_HourglassGeometry
    let progress: CGFloat

    var body: some View {
        Canvas { context, _ in
            drawSand(into: &context)
        }
    }

    private func drawSand(into context: inout GraphicsContext) {
        // Clip to the glass so grains never spill outside the chamber.
        let clip = SandPourView_HourglassShape(geo: geo).path(in: .zero)
        context.clip(to: clip)

        // Three amber buckets -> 3 fills instead of 360.
        var light = Path()
        var mid = Path()
        var dark = Path()
        let r = geo.grainRadius

        for seed in SandPourView_SandModel.seeds {
            let result = grainPosition(seed: seed, p: progress, geo: geo)
            let pt = result.point
            // Falling grains streak vertically to read as motion through the neck.
            let h = result.falling ? r * 3.6 : r * 2
            let rect = CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: h)
            if seed.shade > 0.66 {
                light.addEllipse(in: rect)
            } else if seed.shade > 0.33 {
                mid.addEllipse(in: rect)
            } else {
                dark.addEllipse(in: rect)
            }
        }

        context.fill(light, with: .color(Color(red: 0.93, green: 0.80, blue: 0.52)))
        context.fill(mid, with: .color(Color(red: 0.85, green: 0.69, blue: 0.40)))
        context.fill(dark, with: .color(Color(red: 0.72, green: 0.55, blue: 0.30)))
    }
}
