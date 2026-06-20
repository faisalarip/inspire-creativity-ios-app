// catalog-id: ges-crumple-dismiss
import SwiftUI

// MARK: - Crumple-to-Dismiss
// Pinch a note: it crumples inward into a wrinkled paper ball with procedural
// crease shading, then on release tosses off-screen with a tumbling spin.
// Canvas crease facets only — no Metal. Facets are seeded once so they never
// shimmer between frames.

public struct CrumpleDismissView: View {
    public var demo: Bool = false

    public init(demo: Bool = false) {
        self.demo = demo
    }

    public var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            if demo {
                DemoCrumple(side: side, canvas: proxy.size)
            } else {
                InteractiveCrumple(side: side, canvas: proxy.size)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Shared geometry / state

private struct CrumpleState {
    /// 0 = flat note, 1 = fully balled-up paper.
    var crumple: CGFloat = 0
    /// Tumbling rotation in degrees (used during toss).
    var tumble: Double = 0
    /// Off-screen translation as a fraction of the tile (toss).
    var toss: CGSize = .zero
    /// Overall opacity (fades as it leaves).
    var opacity: Double = 1
}

// MARK: - Demo (self-driving)

private struct DemoCrumple: View {
    let side: CGFloat
    let canvas: CGSize

    private let facets = CreaseField.seeded(count: 22, seed: 0xC0FFEE)

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = Self.phase(at: t)
            let outgoing = Self.outgoingState(phase: phase)
            let incoming = Self.incomingState(phase: phase)

            // Two layers: the note being tossed off, and a fresh note that
            // arrives at center *before* the old one fully leaves — so the
            // tile is never blank, while the toss still flies off-screen.
            ZStack {
                if incoming.opacity > 0.001 {
                    NotePaper(side: side, canvas: canvas,
                              state: incoming, facets: facets)
                }
                if outgoing.opacity > 0.001 {
                    NotePaper(side: side, canvas: canvas,
                              state: outgoing, facets: facets)
                }
                CaptionHint(side: side,
                            label: labelFor(outgoing.crumple, incoming: incoming),
                            opacity: 1)
            }
        }
    }

    private func labelFor(_ outC: CGFloat, incoming: CrumpleState) -> String {
        // Once the incoming fresh note has arrived, prompt to pinch again.
        if incoming.opacity > 0.4 { return "pinch to crumple" }
        if outC < 0.18 { return "pinch to crumple" }
        return outC < 0.92 ? "scrunching…" : ""
    }

    private static func phase(at t: TimeInterval) -> Double {
        let period: Double = 3.4
        return (t.truncatingRemainder(dividingBy: period)) / period // 0..1
    }

    /// The note currently on screen: holds flat → crumples → tosses off.
    private static func outgoingState(phase: Double) -> CrumpleState {
        var s = CrumpleState()
        switch phase {
        case ..<0.12: // settled flat — gentle breathing so it never looks dead
            let p = phase / 0.12
            s.crumple = 0.04 * sin(p * .pi)
        case ..<0.50: // crumple inward
            let p = (phase - 0.12) / 0.38
            s.crumple = easeInOut(p)
        case ..<0.60: // squeeze hold (fully balled)
            s.crumple = 1
            let p = (phase - 0.50) / 0.10
            s.tumble = 8 * sin(p * .pi * 2) // tiny jitter under pressure
        case ..<0.84: // toss off-screen, tumbling
            let p = (phase - 0.60) / 0.24
            let e = easeIn(p)
            s.crumple = 1
            s.tumble = 8 + 560 * e
            s.toss = CGSize(width: 1.5 * e, height: -0.5 * e + 1.2 * e * e)
            s.opacity = Double(1 - max(0, (p - 0.5) / 0.5))
        default: // fully gone for the remainder of the loop
            s.opacity = 0
        }
        return s
    }

    /// A fresh flat note that fades/scales in at center during the toss,
    /// then becomes the resting note until the next cycle's `outgoing` takes
    /// over. Present and legible across the entire handoff window.
    private static func incomingState(phase: Double) -> CrumpleState {
        var s = CrumpleState()
        // Begins arriving while the old ball is still mid-flight (~0.70),
        // fully present by ~0.82, then sits flat through the wrap-around.
        let start = 0.70
        guard phase >= start else { s.opacity = 0; return s }
        let p = min(1, (phase - start) / 0.12)
        s.crumple = 1 - easeOut(p) // unfurls from a ball to flat
        s.opacity = Double(easeOut(p))
        s.tumble = 18 * (1 - p)    // tiny settle wobble
        return s
    }

    private static func easeInOut(_ x: Double) -> CGFloat {
        CGFloat(x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2)
    }
    private static func easeIn(_ x: Double) -> Double { x * x }
    private static func easeOut(_ x: Double) -> Double { 1 - (1 - x) * (1 - x) }
}

// MARK: - Interactive (real gesture)

private struct InteractiveCrumple: View {
    let side: CGFloat
    let canvas: CGSize

    private let facets = CreaseField.seeded(count: 22, seed: 0xC0FFEE)

    @State private var state = CrumpleState()
    @State private var liveCrumple: CGFloat = 0   // tracked during pinch
    @State private var dismissed = false
    @State private var feedback = false

    private let threshold: CGFloat = 0.55

    var body: some View {
        ZStack {
            NotePaper(side: side,
                      canvas: canvas,
                      state: state,
                      facets: facets)
            CaptionHint(side: side, label: label, opacity: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(pinch)
        .sensoryFeedbackCompat(trigger: feedback)
        .onTapGesture { if dismissed { reset() } }
    }

    private var label: String {
        if dismissed { return "tap to restore" }
        if state.crumple < 0.05 { return "pinch to crumple" }
        return state.crumple < threshold ? "release to keep" : "release to toss"
    }

    private var pinch: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0)
            .onChanged { value in
                guard !dismissed else { return }
                // Pinching in => magnification < 1 => crumple grows.
                let raw = 1 - value.magnification
                let c = min(1, max(0, raw * 1.6))
                liveCrumple = c
                state.crumple = c
                state.tumble = Double(c) * 14 * sin(Double(c) * .pi * 3)
            }
            .onEnded { _ in
                guard !dismissed else { return }
                if liveCrumple >= threshold {
                    toss()
                } else {
                    unfold()
                }
                liveCrumple = 0
            }
    }

    private func toss() {
        feedback.toggle()
        dismissed = true
        withAnimation(.spring(response: 0.65, dampingFraction: 0.72)) {
            state.crumple = 1
            state.tumble = 540
            state.toss = CGSize(width: 1.5, height: 1.2)
            state.opacity = 0
        }
    }

    private func unfold() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            state.crumple = 0
            state.tumble = 0
            state.toss = .zero
            state.opacity = 1
        }
    }

    private func reset() {
        state.toss = .zero
        state.tumble = 0
        state.crumple = 1
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
            state.crumple = 0
            state.opacity = 1
        }
        dismissed = false
    }
}

// MARK: - The note + crease canvas

private struct NotePaper: View {
    let side: CGFloat
    let canvas: CGSize
    let state: CrumpleState
    let facets: CreaseField

    var body: some View {
        let c = state.crumple
        // Shrink as it balls up; never below a legible size.
        let scale = 1 - 0.42 * c
        // Flat note is a rounded rectangle; balls toward a circle.
        let corner = (0.10 + 0.40 * c) * paperSide

        ZStack {
            paperBody(corner: corner, c: c)
                .frame(width: paperSide, height: paperSide)
                .overlay {
                    CreaseCanvas(field: facets, crumple: c)
                        .clipShape(RoundedRectangle(cornerRadius: corner,
                                                    style: .continuous))
                }
                .overlay {
                    // Ball highlight — a soft rim of light once crumpled.
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.55 * c),
                                                    .clear,
                                                    .black.opacity(0.30 * c)],
                                           startPoint: .topLeading,
                                           endPoint: .bottomTrailing),
                            lineWidth: max(0.5, side * 0.012))
                }
                .compositingGroup()
                .shadow(color: .black.opacity(0.18 + 0.22 * c),
                        radius: side * (0.04 + 0.05 * c),
                        x: 0, y: side * (0.02 + 0.03 * c))
        }
        .frame(width: paperSide, height: paperSide)
        .scaleEffect(scale)
        .rotation3DEffect(.degrees(state.tumble),
                          axis: (x: 0.35, y: 0.85, z: 0.45),
                          perspective: 0.55)
        .offset(x: state.toss.width * canvas.width,
                y: state.toss.height * canvas.height)
        .opacity(state.opacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var paperSide: CGFloat { side * 0.72 }

    @ViewBuilder
    private func paperBody(corner: CGFloat, c: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(hexCode: 0xFFFDF5),
                             Color.mix(0xF4EFDD, 0xE7DFC6, c)],
                    startPoint: .top, endPoint: .bottom)
            )
            .overlay {
                // Faint ruled lines that survive lightly into the ball.
                RuledLines(side: paperSide)
                    .stroke(Color(hexCode: 0x9FB4D8).opacity(0.45 * (1 - c)),
                            lineWidth: max(0.5, side * 0.006))
                    .clipShape(RoundedRectangle(cornerRadius: corner,
                                                style: .continuous))
            }
    }
}

// MARK: - Tile-anchored caption hint (sits on the tile, not the tossed note)

private struct CaptionHint: View {
    let side: CGFloat
    let label: String
    var opacity: Double = 1

    var body: some View {
        if !label.isEmpty {
            Text(label)
                .font(.system(size: max(8, side * 0.075), weight: .semibold,
                              design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, side * 0.06)
                .padding(.vertical, side * 0.025)
                .background(.black.opacity(0.28), in: Capsule())
                .padding(.bottom, side * 0.04)
                .opacity(opacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity,
                       alignment: .bottom)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Ruled note lines

private struct RuledLines: Shape {
    let side: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let rows = 5
        let inset = rect.width * 0.14
        for i in 1...rows {
            let y = rect.minY + rect.height * CGFloat(i) / CGFloat(rows + 1)
            p.move(to: CGPoint(x: rect.minX + inset, y: y))
            p.addLine(to: CGPoint(x: rect.maxX - inset, y: y))
        }
        return p
    }
}

// MARK: - Procedural crease facets (Canvas, seeded once)

private struct CreaseCanvas: View {
    let field: CreaseField
    let crumple: CGFloat

    var body: some View {
        Canvas { ctx, size in
            guard crumple > 0.001 else { return }
            // Facet opacity ramps in with crumple; each facet has a depth that
            // controls whether it reads as a lit ridge or a shadowed valley.
            let amount = Double(min(1, crumple))
            for facet in field.facets {
                let path = facet.path(in: size)
                let lit = facet.depth > 0
                let mag = abs(facet.depth)
                let base = mag * 0.9 * amount
                let color: Color = lit
                    ? Color.white.opacity(base * 0.7)
                    : Color.black.opacity(base * 0.55)
                ctx.fill(path, with: .color(color))
            }
            // A few sharp crease lines layered on top for definition.
            for line in field.creaseLines {
                var p = Path()
                p.move(to: line.a.scaled(to: size))
                p.addLine(to: line.b.scaled(to: size))
                ctx.stroke(p,
                           with: .color(.black.opacity(0.28 * amount)),
                           lineWidth: max(0.5, size.width * 0.01))
            }
        }
        .blendMode(.softLight)
        .opacity(0.55 + 0.45 * Double(crumple))
    }
}

// MARK: - Seeded crease geometry (generated once, never shimmers)

private struct CreaseField {
    struct Facet {
        var points: [UnitPoint]   // 3–4 polygon points in unit space
        var depth: Double         // signed: + lit ridge, - dark valley

        func path(in size: CGSize) -> Path {
            var p = Path()
            guard let first = points.first else { return p }
            p.move(to: first.scaled(to: size))
            for pt in points.dropFirst() {
                p.addLine(to: pt.scaled(to: size))
            }
            p.closeSubpath()
            return p
        }
    }
    struct Line { var a: UnitPoint; var b: UnitPoint }

    var facets: [Facet]
    var creaseLines: [Line]

    static func seeded(count: Int, seed: UInt64) -> CreaseField {
        var rng = SplitMix64(seed: seed)
        var facets: [Facet] = []
        facets.reserveCapacity(count)

        for _ in 0..<count {
            // Anchor each facet near a random center, give it 3–4 spokes.
            let cx = rng.unit()
            let cy = rng.unit()
            let r = 0.06 + 0.16 * rng.unit()
            let corners = rng.unit() > 0.5 ? 4 : 3
            var pts: [UnitPoint] = []
            let startAngle = rng.unit() * .pi * 2
            for k in 0..<corners {
                let frac = Double(k) / Double(corners)
                let ang = startAngle + frac * .pi * 2 + (rng.unit() - 0.5) * 0.7
                let rad = r * (0.6 + 0.6 * rng.unit())
                let x = cx + CGFloat(cos(ang)) * rad
                let y = cy + CGFloat(sin(ang)) * rad
                pts.append(UnitPoint(x: min(1, max(0, x)),
                                     y: min(1, max(0, y))))
            }
            let depth = (rng.unit() - 0.5) * 2 // -1..1
            facets.append(Facet(points: pts, depth: depth))
        }

        var lines: [Line] = []
        let lineCount = 7
        for _ in 0..<lineCount {
            let a = UnitPoint(x: rng.unit(), y: rng.unit())
            let bx = a.x + (rng.unit() - 0.5) * 0.5
            let by = a.y + (rng.unit() - 0.5) * 0.5
            let b = UnitPoint(x: min(1, max(0, bx)), y: min(1, max(0, by)))
            lines.append(Line(a: a, b: b))
        }

        return CreaseField(facets: facets, creaseLines: lines)
    }
}

// MARK: - Deterministic RNG (so creases are fixed per view)

private struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    /// Uniform 0..1.
    mutating func unit() -> CGFloat {
        CGFloat(next() >> 11) / CGFloat(UInt64(1) << 53)
    }
}

// MARK: - Helpers

private extension UnitPoint {
    func scaled(to size: CGSize) -> CGPoint {
        CGPoint(x: x * size.width, y: y * size.height)
    }
}

private extension Color {
    init(hexCode hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
    /// Linear RGB blend toward another hex color (0 = self, 1 = other).
    static func mix(_ a: UInt32, _ b: UInt32, _ t: CGFloat) -> Color {
        let k = Double(min(1, max(0, t)))
        func chan(_ h: UInt32, _ shift: UInt32) -> Double {
            Double((h >> shift) & 0xFF) / 255
        }
        let r = chan(a, 16) * (1 - k) + chan(b, 16) * k
        let g = chan(a, 8) * (1 - k) + chan(b, 8) * k
        let bl = chan(a, 0) * (1 - k) + chan(b, 0) * k
        return Color(red: r, green: g, blue: bl)
    }
}

private extension View {
    @ViewBuilder
    func sensoryFeedbackCompat(trigger: Bool) -> some View {
        if #available(iOS 17.0, *) {
            self.sensoryFeedback(.impact(weight: .medium), trigger: trigger)
        } else {
            self
        }
    }
}
