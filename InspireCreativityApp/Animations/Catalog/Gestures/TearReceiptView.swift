// catalog-id: ges-tear-receipt
import SwiftUI

// MARK: - TearReceiptView
// Drag the perforated stub downward to tear it along a procedurally ragged
// perforation. Past the threshold the freed piece detaches and flutters away
// while the remainder springs back up. The jagged edge is generated ONCE with a
// seeded RNG (stable across every frame); only the cut position animates.
struct TearReceiptView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if demo {
            TearReceiptView_DemoReceipt(canvas: size)
        } else {
            TearReceiptView_InteractiveReceipt(canvas: size)
        }
    }
}

// MARK: - Seeded deterministic RNG
// A small, fast, fully deterministic generator. Seeded with a constant so the
// ragged perforation profile is byte-identical on every view re-init.
private struct TearReceiptView_SeededRNG: RandomNumberGenerator {
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
}

// MARK: - Perforation profile (generated once, normalized)
// Amplitudes are stored normalized in roughly [-1, 1] and scaled by geometry at
// draw time, so the same profile reads correctly at 120pt and at full size.
private enum TearReceiptView_Perf {
    static let teeth = 26

    // Normalized vertical wobble of the tear line per tooth, in [-1, 1].
    static let wobble: [CGFloat] = makeWobble()

    // Normalized fiber-fringe length per tooth, in [0.3, 1].
    static let fringe: [CGFloat] = makeFringe()

    private static func makeWobble() -> [CGFloat] {
        var rng = TearReceiptView_SeededRNG(seed: 0xBEEF_CAFE_1234)
        return (0...teeth).map { _ in
            let r = Double(rng.next() >> 11) / Double(1 << 53) // 0..1
            return CGFloat(r * 2.0 - 1.0)
        }
    }

    private static func makeFringe() -> [CGFloat] {
        var rng = TearReceiptView_SeededRNG(seed: 0x00FF_1357_9BDF)
        return (0...teeth).map { _ in
            let r = Double(rng.next() >> 11) / Double(1 << 53) // 0..1
            return CGFloat(0.3 + r * 0.7)
        }
    }
}

// MARK: - Palette helpers (no app dependencies)
private enum TearReceiptView_Paper {
    static let ink = Color(red: 0.13, green: 0.14, blue: 0.20)
    static let faint = Color(red: 0.74, green: 0.75, blue: 0.80)
    static let sheetTop = Color(red: 0.99, green: 0.985, blue: 0.96)
    static let sheetBottom = Color(red: 0.95, green: 0.94, blue: 0.90)
    static let edgeShadow = Color(red: 0.0, green: 0.0, blue: 0.0).opacity(0.18)
    static let accent = Color(red: 0.92, green: 0.32, blue: 0.30)
}

// MARK: - Ragged perforation edge as an Animatable Shape
// `animatableData` is the tear progress ONLY (how far the cut has opened, 0...1).
// The jag arrays are constant stored data and never part of animatableData.
private struct TearReceiptView_RaggedTearEdge: Shape, Animatable {
    /// 0 = perforation still closed, 1 = fully separated.
    var progress: CGFloat
    /// true = clip the KEPT (upper) sheet; false = clip the FREED (lower) stub.
    var keepingUpper: Bool

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        // Pure function of rect + stored props + progress. No RNG here.
        // The ragged edge is anchored at the SHARED SEAM: for the upper sheet
        // that seam is the bottom of its frame (maxY); for the lower stub it is
        // the top of its frame (minY). This makes the two halves abut at the
        // perforation at rest and pull apart only as `progress` rises.
        let teeth = TearReceiptView_Perf.teeth
        let stepX = rect.width / CGFloat(teeth)
        let amp = max(rect.height * 0.06, 6)
        let fringeMax = max(rect.height * 0.05, 5)

        // As progress rises, the two halves pull apart by `gap`.
        let gap = progress * (rect.height * 0.5 + 4)

        var p = Path()
        if keepingUpper {
            let baseY = rect.maxY
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            // Travel right-to-left along the ragged cut, pulled UP by gap.
            for i in stride(from: teeth, through: 0, by: -1) {
                let x = rect.minX + CGFloat(i) * stepX
                let wob = TearReceiptView_Perf.wobble[i] * amp
                let fr = TearReceiptView_Perf.fringe[i] * fringeMax
                let y = baseY + wob - gap - fr
                p.addLine(to: CGPoint(x: x, y: y))
            }
            p.closeSubpath()
        } else {
            let baseY = rect.minY
            p.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            // Travel left-to-right along the ragged cut, pushed DOWN by gap.
            for i in stride(from: 0, through: teeth, by: 1) {
                let x = rect.minX + CGFloat(i) * stepX
                let wob = TearReceiptView_Perf.wobble[i] * amp
                let fr = TearReceiptView_Perf.fringe[i] * fringeMax
                let y = baseY + wob + gap + fr
                p.addLine(to: CGPoint(x: x, y: y))
            }
            p.closeSubpath()
        }
        return p
    }
}

// MARK: - The dotted perforation guide line (drawn at the seam when closed)
private struct TearReceiptView_PerforationGuide: Shape {
    func path(in rect: CGRect) -> Path {
        // The guide is drawn in a frame the same height as the upper sheet and
        // top-aligned, so the shared seam sits at the BOTTOM of this rect.
        let teeth = TearReceiptView_Perf.teeth
        let stepX = rect.width / CGFloat(teeth)
        let baseY = rect.maxY
        let amp = max(rect.height * 0.06, 6)
        var p = Path()
        for i in 0...teeth {
            let x = rect.minX + CGFloat(i) * stepX
            let y = baseY + TearReceiptView_Perf.wobble[i] * amp
            if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
            else { p.addLine(to: CGPoint(x: x, y: y)) }
        }
        return p
    }
}

// MARK: - Receipt face content (printed rows). Scales with the rect.
private struct TearReceiptView_ReceiptFace: View {
    var size: CGSize
    var header: Bool

    var body: some View {
        let pad = max(size.width * 0.10, 8)
        VStack(alignment: .leading, spacing: max(size.height * 0.018, 3)) {
            if header {
                HStack(spacing: max(size.width * 0.03, 4)) {
                    Circle()
                        .fill(TearReceiptView_Paper.accent)
                        .frame(width: max(size.width * 0.08, 7),
                               height: max(size.width * 0.08, 7))
                    bar(widthFactor: 0.42, tall: true)
                    Spacer(minLength: 0)
                }
                .padding(.bottom, max(size.height * 0.01, 2))
            }
            ForEach(0..<rowCount, id: \.self) { idx in
                HStack(spacing: 0) {
                    bar(widthFactor: rowWidths[idx % rowWidths.count])
                    Spacer(minLength: max(size.width * 0.05, 5))
                    bar(widthFactor: 0.16)
                }
            }
        }
        .padding(.horizontal, pad)
        .padding(.vertical, max(size.height * 0.05, 5))
        .frame(width: size.width, alignment: .leading)
    }

    private var rowCount: Int {
        let n = Int(size.height / max(size.height * 0.10, 14))
        return min(max(n, 2), 6)
    }

    private let rowWidths: [CGFloat] = [0.50, 0.62, 0.40, 0.55, 0.34, 0.46]

    private func bar(widthFactor: CGFloat, tall: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(tall ? TearReceiptView_Paper.ink : TearReceiptView_Paper.faint)
            .frame(width: size.width * widthFactor,
                   height: max(size.height * (tall ? 0.05 : 0.035), tall ? 5 : 3))
    }
}

// MARK: - Sheet background (the paper itself with a soft cut shadow)
private struct TearReceiptView_PaperSheet<Content: View>: View {
    var size: CGSize
    var shadowAtBottom: Bool
    var shadowAtTop: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: max(size.width * 0.04, 6), style: .continuous)
                .fill(
                    LinearGradient(colors: [TearReceiptView_Paper.sheetTop, TearReceiptView_Paper.sheetBottom],
                                   startPoint: .top, endPoint: .bottom)
                )
            content()
            if shadowAtBottom {
                LinearGradient(colors: [.clear, TearReceiptView_Paper.edgeShadow],
                               startPoint: .center, endPoint: .bottom)
                    .allowsHitTesting(false)
            }
            if shadowAtTop {
                LinearGradient(colors: [TearReceiptView_Paper.edgeShadow, .clear],
                               startPoint: .top, endPoint: .center)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - Shared rip renderer
// Renders the upper (kept) sheet springing up and the lower (freed) stub
// tearing/fluttering away, given a single `progress` (0...1 tear) and a
// detach state for the flutter.
private struct TearReceiptView_RipStack: View {
    var canvas: CGSize
    var progress: CGFloat       // 0 closed ... 1 fully torn
    var detached: Bool          // freed piece is flying away
    var flutter: CGFloat        // 0...1 flutter timeline for the freed piece

    private var sheetWidth: CGFloat { min(canvas.width * 0.78, canvas.height * 0.62) }
    private var sheetHeight: CGFloat { min(canvas.height * 0.92, sheetWidth * 1.5) }
    private var splitY: CGFloat { sheetHeight * 0.58 } // perforation sits here

    var body: some View {
        ZStack {
            upperSheet
            seamGuide
            lowerStub
        }
        .frame(width: sheetWidth, height: sheetHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // The kept top portion. Springs UP slightly as the tear opens. Always opaque.
    private var upperSheet: some View {
        let topSize = CGSize(width: sheetWidth, height: splitY)
        return TearReceiptView_PaperSheet(size: topSize, shadowAtBottom: true, shadowAtTop: false) {
            TearReceiptView_ReceiptFace(size: topSize, header: true)
        }
        .clipShape(TearReceiptView_RaggedTearEdge(progress: progress, keepingUpper: true))
        .frame(height: sheetHeight, alignment: .top)
        .offset(y: -progress * (sheetHeight * 0.04))
    }

    // Dotted perforation, only visible while the seam is still mostly closed.
    private var seamGuide: some View {
        let topSize = CGSize(width: sheetWidth, height: splitY)
        return TearReceiptView_PerforationGuide()
            .stroke(style: StrokeStyle(lineWidth: max(sheetWidth * 0.012, 1.2),
                                       lineCap: .round, dash: [3, 4]))
            .foregroundColor(TearReceiptView_Paper.faint)
            .frame(width: topSize.width, height: topSize.height)
            .frame(height: sheetHeight, alignment: .top)
            .opacity(Double(max(0, 1 - progress * 2.4)))
            .allowsHitTesting(false)
    }

    // The freed bottom stub. Tears down, then on detach flutters away & fades.
    private var lowerStub: some View {
        let botHeight = sheetHeight - splitY
        let botSize = CGSize(width: sheetWidth, height: botHeight)
        // Flutter physics: grow offset, tilt in 3D, spin a touch, fade only THIS piece.
        let fall = detached ? flutter * (canvas.height * 0.9 + botHeight) : progress * (botHeight * 0.5)
        let drift = detached ? sin(flutter * .pi * 3) * (sheetWidth * 0.22) : 0
        let tilt = detached ? Double(flutter) * 26 : 0
        let spin = detached ? Double(flutter) * 14 : 0
        let fade = detached ? Double(max(0, 1 - flutter * 1.05)) : 1

        return TearReceiptView_PaperSheet(size: botSize, shadowAtBottom: false, shadowAtTop: false) {
            TearReceiptView_ReceiptFace(size: botSize, header: false)
        }
        .clipShape(TearReceiptView_RaggedTearEdge(progress: progress, keepingUpper: false))
        .frame(height: sheetHeight, alignment: .bottom)
        .offset(x: drift, y: fall)
        .rotation3DEffect(.degrees(tilt), axis: (x: 1, y: 0.15, z: 0.4),
                          anchor: .top, perspective: 0.7)
        .rotationEffect(.degrees(spin), anchor: .center)
        .opacity(fade)
    }
}

// MARK: - Interactive variant (demo == false)
private struct TearReceiptView_InteractiveReceipt: View {
    var canvas: CGSize

    @State private var progress: CGFloat = 0
    @State private var detached: Bool = false
    @State private var flutter: CGFloat = 0
    @State private var tickCount: Int = 0

    private let threshold: CGFloat = 0.62

    var body: some View {
        TearReceiptView_RipStack(canvas: canvas, progress: progress, detached: detached, flutter: flutter)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .sensoryFeedback(.selection, trigger: tickCount)
            .sensoryFeedback(.success, trigger: detached) { _, now in now }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !detached else { return }
                let span = max(canvas.height * 0.45, 60)
                let raw = max(0, value.translation.height) / span
                let clamped = min(raw, 1)
                // Tick haptics as the tear crosses perforation notches.
                let newTick = Int(clamped * CGFloat(TearReceiptView_Perf.teeth))
                if newTick != tickCount { tickCount = newTick }
                progress = clamped
            }
            .onEnded { _ in
                guard !detached else { return }
                if progress >= threshold {
                    // Finish the rip, then detach and flutter the freed stub away.
                    withAnimation(.easeIn(duration: 0.16)) { progress = 1 }
                    detached = true
                    withAnimation(.easeIn(duration: 1.05)) { flutter = 1 }
                    // The kept receipt springs up as the piece leaves.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
                        resetForNextTear()
                    }
                } else {
                    // Not far enough — perforation springs back together.
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        progress = 0
                    }
                }
            }
    }

    private func resetForNextTear() {
        // Re-arm with a gentle reveal so a fresh stub is tearable again.
        flutter = 0
        detached = false
        progress = 1
        withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
            progress = 0
        }
    }
}

// MARK: - Demo variant (demo == true) — self-driving, never blank
// Hand-shaped time -> state mapping via TimelineView(.animation) for a clean,
// flash-free loop reset and a guaranteed-legible kept receipt on every frame.
private struct TearReceiptView_DemoReceipt: View {
    var canvas: CGSize
    private let cycle: Double = 3.4 // seconds

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = (t.truncatingRemainder(dividingBy: cycle)) / cycle
            let s = state(for: phase)
            TearReceiptView_RipStack(canvas: canvas,
                     progress: s.progress,
                     detached: s.detached,
                     flutter: s.flutter)
        }
    }

    struct LoopState { var progress: CGFloat; var detached: Bool; var flutter: CGFloat }

    // phase 0.00..0.45 : tear opens (intact -> tearing)
    // phase 0.45..0.80 : freed piece flutters away (the upper sheet stays put)
    // phase 0.80..1.00 : hold + gentle re-arm so the reset never flashes blank
    private func state(for phase: Double) -> LoopState {
        if phase < 0.45 {
            let p = ease(phase / 0.45)
            return LoopState(progress: CGFloat(p), detached: false, flutter: 0)
        } else if phase < 0.80 {
            let f = (phase - 0.45) / 0.35
            return LoopState(progress: 1, detached: true, flutter: CGFloat(ease(f)))
        } else {
            // Re-arm: a fresh stub eases back into place (progress 1 -> 0).
            let r = (phase - 0.80) / 0.20
            let prog = 1 - ease(r)
            return LoopState(progress: CGFloat(prog), detached: false, flutter: 0)
        }
    }

    private func ease(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c) // smoothstep
    }
}
