// catalog-id: ges-swipe-stack-shuffle
import SwiftUI

/// Swipe Deck Shuffle
/// Swipe the top card off a fanned stack; the cards beneath glide up and
/// re-fan with slight per-card rotation jitter, while the flung card tumbles
/// away with spin proportional to swipe speed.
///
/// - `demo == true`  : a self-driving TimelineView loop that auto-flings the
///                     top card each cycle and re-fans the deck, then cycles
///                     the faces so the flung card "returns to the back".
/// - `demo == false` : the real interactive component. Drag the top card; past
///                     a velocity/translation threshold it flings off with spin
///                     and the deck advances + re-fans; otherwise it springs back.
struct SwipeStackShuffleView: View {

    var demo: Bool = false

    // A small fixed palette of card "faces" — drawn, no assets.
    private static let faces: [CardFace] = [
        CardFace(top: Color(red: 0.97, green: 0.45, blue: 0.42),
                 bottom: Color(red: 0.93, green: 0.27, blue: 0.45), glyph: "spade"),
        CardFace(top: Color(red: 0.40, green: 0.70, blue: 0.98),
                 bottom: Color(red: 0.30, green: 0.46, blue: 0.92), glyph: "heart"),
        CardFace(top: Color(red: 0.62, green: 0.82, blue: 0.50),
                 bottom: Color(red: 0.36, green: 0.66, blue: 0.46), glyph: "club"),
        CardFace(top: Color(red: 0.98, green: 0.80, blue: 0.42),
                 bottom: Color(red: 0.95, green: 0.58, blue: 0.28), glyph: "diamond"),
        CardFace(top: Color(red: 0.78, green: 0.62, blue: 0.97),
                 bottom: Color(red: 0.56, green: 0.40, blue: 0.92), glyph: "spade")
    ]

    // Interactive state.
    @State private var order: [Int] = Array(0..<SwipeStackShuffleView.faces.count)
    @State private var drag: CGSize = .zero
    @State private var flying: FlyingCard? = nil
    @State private var commitTick: Int = 0

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                background
                if demo {
                    SwipeStackShuffleView_DemoStack(faces: Self.faces, side: side)
                } else {
                    interactiveStack(side: side)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.impact(weight: .medium), trigger: commitTick)
    }

    // MARK: Background

    private var background: some View {
        LinearGradient(
            colors: [Color(red: 0.07, green: 0.08, blue: 0.13),
                     Color(red: 0.12, green: 0.10, blue: 0.18)],
            startPoint: .top, endPoint: .bottom
        )
    }

    // MARK: Interactive stack

    @ViewBuilder
    private func interactiveStack(side: CGFloat) -> some View {
        let cardW: CGFloat = side * 0.46
        let cardH: CGFloat = cardW * 1.42
        let visible = min(order.count, 4)

        ZStack {
            // Cards beneath, drawn back-to-front so the top is last.
            ForEach(Array(order.suffix(order.count).enumerated()), id: \.element) { pair in
                let depth = order.count - 1 - pair.offset // 0 == top
                if depth < visible {
                    beneathOrTopCard(faceIndex: pair.element,
                                     depth: depth,
                                     cardW: cardW, cardH: cardH)
                }
            }

            // The currently-flying card (a flung copy that tumbles away).
            if let fc = flying {
                Self.cardView(face: Self.faces[fc.faceIndex],
                              width: cardW, height: cardH)
                    .rotationEffect(.degrees(fc.rotation),
                                    anchor: UnitPoint(x: 0.5, y: 1.35))
                    .offset(fc.offset)
                    .opacity(fc.opacity)
            }
        }
        .animation(nil, value: drag)
    }

    @ViewBuilder
    private func beneathOrTopCard(faceIndex: Int, depth: Int,
                                  cardW: CGFloat, cardH: CGFloat) -> some View {
        let base = Self.fan(depth: depth, side: cardW)
        let isTop = depth == 0
        let liveOffset: CGSize = isTop ? combinedTopOffset(base.offset) : base.offset
        let liveRot: Double = isTop ? base.rotation + Double(drag.width) * 0.10 : base.rotation

        Self.cardView(face: Self.faces[faceIndex], width: cardW, height: cardH)
            .scaleEffect(base.scale)
            .rotationEffect(.degrees(liveRot), anchor: UnitPoint(x: 0.5, y: 1.35))
            .offset(liveOffset)
            .zIndex(Double(10 - depth))
            .allowsHitTesting(isTop)
            .gesture(topDragGesture(cardW: cardW), including: isTop ? .all : .subviews)
            .animation(.spring(response: 0.5, dampingFraction: 0.72), value: commitTick)
    }

    private func combinedTopOffset(_ base: CGSize) -> CGSize {
        CGSize(width: base.width + drag.width, height: base.height + drag.height)
    }

    private func topDragGesture(cardW: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                drag = value.translation
            }
            .onEnded { value in
                handleRelease(value, cardW: cardW)
            }
    }

    private func handleRelease(_ value: DragGesture.Value, cardW: CGFloat) {
        let dx = value.translation.width
        let vx = value.predictedEndTranslation.width - value.translation.width
        let throwScore = abs(dx) + abs(vx) * 0.35
        let threshold: CGFloat = cardW * 0.55

        if throwScore > threshold, let topFace = order.last {
            fling(faceIndex: topFace, value: value)
        } else {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                drag = .zero
            }
        }
    }

    private func fling(faceIndex: Int, value: DragGesture.Value) {
        let dx = value.translation.width
        let dy = value.translation.height
        let vx = value.predictedEndTranslation.width
        let vy = value.predictedEndTranslation.height
        let dir: CGFloat = dx >= 0 ? 1 : -1
        let speed = abs(vx - dx) + abs(dx)
        let spin = Double(dir) * Double(180 + min(speed, 600) * 0.5)

        // Seed the flying copy at the current drag position so it doesn't jump.
        flying = FlyingCard(faceIndex: faceIndex,
                            offset: CGSize(width: dx, height: dy),
                            rotation: Double(dx) * 0.10,
                            opacity: 1)
        // Clear the live drag and advance the deck immediately.
        drag = .zero
        rotateDeck()
        commitTick &+= 1

        // Tumble the flying copy away.
        withAnimation(.easeOut(duration: 0.55)) {
            flying?.offset = CGSize(width: dir * 1100, height: dy + vy * 0.6 - 120)
            flying?.rotation = spin
            flying?.opacity = 0
        }
        // Retire the copy after the tumble finishes.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if flying?.faceIndex == faceIndex { flying = nil }
        }
    }

    private func rotateDeck() {
        guard let top = order.last else { return }
        order.removeLast()
        order.insert(top, at: 0)
    }

    // MARK: Shared geometry & drawing

    /// Deterministic fan transform for a card at a given depth (0 == top).
    static func fan(depth: Int, side cardW: CGFloat) -> FanTransform {
        let d = CGFloat(depth)
        let jitterR = Self.jitter(seed: depth, salt: 1.0)        // -1...1
        let jitterX = Self.jitter(seed: depth, salt: 7.0)        // -1...1
        let rot: Double = Double(d) * -4.0 + Double(jitterR) * 3.5
        let offX: CGFloat = d * cardW * 0.030 + jitterX * cardW * 0.045
        let offY: CGFloat = d * cardW * 0.085
        let scale: CGFloat = max(0.80, 1.0 - d * 0.055)
        return FanTransform(offset: CGSize(width: offX, height: offY),
                            rotation: rot, scale: scale)
    }

    /// Stable pseudo-random in -1...1 from an integer seed (computed once, never per-frame).
    static func jitter(seed: Int, salt: Double) -> CGFloat {
        let x = sin(Double(seed) * 12.9898 + salt * 78.233) * 43758.5453
        let frac = x - x.rounded(.down)        // 0..<1
        return CGFloat(frac * 2.0 - 1.0)
    }

    @ViewBuilder
    static func cardView(face: CardFace, width: CGFloat, height: CGFloat) -> some View {
        let corner: CGFloat = width * 0.12
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(colors: [face.top, face.bottom],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(Color.white.opacity(0.25), lineWidth: max(1, width * 0.012))

            cardGlyph(face: face, size: width)

            // Soft top-edge sheen.
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(colors: [Color.white.opacity(0.22), .clear],
                                   startPoint: .top, endPoint: .center)
                )
                .blendMode(.softLight)
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.35), radius: width * 0.08, x: 0, y: width * 0.05)
    }

    @ViewBuilder
    private static func cardGlyph(face: CardFace, size: CGFloat) -> some View {
        let symbol: String = {
            switch face.glyph {
            case "heart":   return "suit.heart.fill"
            case "club":    return "suit.club.fill"
            case "diamond": return "suit.diamond.fill"
            default:        return "suit.spade.fill"
            }
        }()
        VStack {
            HStack {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.13, weight: .bold))
                Spacer()
            }
            Spacer()
            Image(systemName: symbol)
                .font(.system(size: size * 0.40, weight: .bold))
            Spacer()
            HStack {
                Spacer()
                Image(systemName: symbol)
                    .font(.system(size: size * 0.13, weight: .bold))
                    .rotationEffect(.degrees(180))
            }
        }
        .foregroundStyle(Color.white.opacity(0.9))
        .padding(size * 0.10)
    }
}

// MARK: - Demo (self-driving, pure function of timeline time)

private struct SwipeStackShuffleView_DemoStack: View {
    let faces: [SwipeStackShuffleView.CardFace]
    let side: CGFloat

    private let period: Double = 3.2

    var body: some View {
        let cardW: CGFloat = side * 0.46
        let cardH: CGFloat = cardW * 1.42

        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let cycle = Int(floor(t / period))
            let phase = (t / period) - floor(t / period)   // 0..<1
            content(cycle: cycle, phase: phase, cardW: cardW, cardH: cardH)
        }
    }

    @ViewBuilder
    private func content(cycle: Int, phase: Double,
                         cardW: CGFloat, cardH: CGFloat) -> some View {
        let visible = min(faces.count, 4)
        ZStack {
            ForEach(0..<visible, id: \.self) { slot in
                demoCard(slot: slot, cycle: cycle, phase: phase,
                         cardW: cardW, cardH: cardH, visible: visible)
            }
        }
    }

    @ViewBuilder
    private func demoCard(slot: Int, cycle: Int, phase: Double,
                          cardW: CGFloat, cardH: CGFloat, visible: Int) -> some View {
        // Which face sits in this depth slot this cycle (rotates so flung card returns to back).
        let faceIndex = (slot + cycle) % faces.count

        if slot == 0 {
            // Top card: flings off, a fresh one rises into its place.
            demoTopCard(faceIndex: faceIndex, phase: phase, cardW: cardW, cardH: cardH)
        } else {
            // Beneath cards glide up one slot as the deck advances.
            demoBeneathCard(faceIndex: faceIndex, slot: slot, phase: phase,
                            cardW: cardW, cardH: cardH)
        }
    }

    @ViewBuilder
    private func demoTopCard(faceIndex: Int, phase: Double,
                             cardW: CGFloat, cardH: CGFloat) -> some View {
        let base = SwipeStackShuffleView.fan(depth: 0, side: cardW)
        // Fling occupies the first ~45% of the cycle; rest is the new top settling.
        let flingP = smooth(clamp(phase / 0.45))
        let throwX: CGFloat = flingP * cardW * 4.2
        let throwY: CGFloat = -flingP * cardW * 0.6
        let spin: Double = Double(flingP) * 320

        SwipeStackShuffleView.cardView(face: faces[faceIndex], width: cardW, height: cardH)
            .scaleEffect(base.scale)
            .rotationEffect(.degrees(base.rotation + spin),
                            anchor: UnitPoint(x: 0.5, y: 1.35))
            .offset(x: base.offset.width + throwX, y: base.offset.height + throwY)
            .opacity(1.0 - Double(flingP) * 0.9)
            .zIndex(20)
    }

    @ViewBuilder
    private func demoBeneathCard(faceIndex: Int, slot: Int, phase: Double,
                                 cardW: CGFloat, cardH: CGFloat) -> some View {
        // After the fling (~45%), beneath cards interpolate up one slot.
        let riseP = smooth(clamp((phase - 0.35) / 0.5))
        let from = SwipeStackShuffleView.fan(depth: slot, side: cardW)
        let to = SwipeStackShuffleView.fan(depth: slot - 1, side: cardW)
        let off = lerp(from.offset, to.offset, riseP)
        let rot = from.rotation + (to.rotation - from.rotation) * Double(riseP)
        let scl = from.scale + (to.scale - from.scale) * riseP

        SwipeStackShuffleView.cardView(face: faces[faceIndex], width: cardW, height: cardH)
            .scaleEffect(scl)
            .rotationEffect(.degrees(rot), anchor: UnitPoint(x: 0.5, y: 1.35))
            .offset(off)
            .zIndex(Double(10 - slot))
    }

    // MARK: small helpers

    private func clamp(_ v: Double) -> CGFloat { CGFloat(min(1.0, max(0.0, v))) }

    private func smooth(_ v: CGFloat) -> CGFloat { v * v * (3 - 2 * v) } // smoothstep

    private func lerp(_ a: CGSize, _ b: CGSize, _ t: CGFloat) -> CGSize {
        CGSize(width: a.width + (b.width - a.width) * t,
               height: a.height + (b.height - a.height) * t)
    }
}

// MARK: - Model types

extension SwipeStackShuffleView {

    struct CardFace: Identifiable {
        let id = UUID()
        let top: Color
        let bottom: Color
        let glyph: String
    }

    struct FanTransform {
        let offset: CGSize
        let rotation: Double
        let scale: CGFloat
    }

    struct FlyingCard {
        let faceIndex: Int
        var offset: CGSize
        var rotation: Double
        var opacity: Double
    }
}
