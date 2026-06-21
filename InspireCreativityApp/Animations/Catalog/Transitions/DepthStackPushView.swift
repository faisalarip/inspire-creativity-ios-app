// catalog-id: tr-depth-stack-push
import SwiftUI

/// Depth Stack Push
///
/// The focused card recedes into a z-ordered stack with a scale-down,
/// downward drift and progressive blur while the next card rises forward into
/// focus, like a physical deck being shuffled in 3D space.
///
/// - `demo == true`: a `TimelineView(.animation)` advances the deck one card
///   per period on a continuous loop so the depth shuffle plays itself.
/// - `demo == false`: a horizontal `DragGesture` maps translation to a 0→1
///   push progress; releasing past a threshold commits the push with an
///   interactive spring, otherwise it springs back.
///
/// Both modes share ONE renderer (`DepthStackPushView_DeckLayer`). Each card's attributes are
/// the lerp of its resolved attributes at the current and next integer front,
/// and its `zIndex` always comes from the *integer* front — so the leaving
/// card stays painted on top while it shrinks and only drops to the back once
/// it has fully receded, keeping the depth illusion intact in both modes.
struct DepthStackPushView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let dim = min(size.width, size.height)
            ZStack {
                DepthStackPushView_Background()
                Group {
                    if demo {
                        DepthStackPushView_DemoDriver(dim: dim)
                    } else {
                        DepthStackPushView_InteractiveDriver(dim: dim)
                    }
                }
                .frame(width: size.width, height: size.height)
            }
            .frame(width: size.width, height: size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - DepthStackPushView_Deck model

private enum DepthStackPushView_Deck {
    /// Number of cards in the stack.
    static let count = 5

    /// Period of one full auto-advance in the demo loop (~3.5s, within 2.5–4s).
    static let demoPeriod: Double = 3.5

    /// Visual palette — distinct hues so the layered depth reads clearly.
    static let palette: [DepthStackPushView_DeckPalette] = [
        DepthStackPushView_DeckPalette(top: Color(red: 0.36, green: 0.56, blue: 0.98),
                    bottom: Color(red: 0.20, green: 0.32, blue: 0.78)),
        DepthStackPushView_DeckPalette(top: Color(red: 0.96, green: 0.46, blue: 0.62),
                    bottom: Color(red: 0.76, green: 0.24, blue: 0.46)),
        DepthStackPushView_DeckPalette(top: Color(red: 0.40, green: 0.82, blue: 0.70),
                    bottom: Color(red: 0.16, green: 0.56, blue: 0.52)),
        DepthStackPushView_DeckPalette(top: Color(red: 0.98, green: 0.74, blue: 0.38),
                    bottom: Color(red: 0.86, green: 0.50, blue: 0.18)),
        DepthStackPushView_DeckPalette(top: Color(red: 0.70, green: 0.56, blue: 0.96),
                    bottom: Color(red: 0.46, green: 0.32, blue: 0.80))
    ]

    /// Relative depth of `index` given the integer `front` card.
    /// 0 == focused, larger == deeper. `front` MUST be an integer — the modulo
    /// has a discontinuity at each crossing, so fractional fronts would teleport
    /// the focused card to the back.
    static func relativeDepth(index: Int, front: Int) -> Int {
        let raw = (index - front) % count
        return raw < 0 ? raw + count : raw
    }

    /// Visual attributes for a card at a given (possibly fractional) depth.
    /// Everything scales off the tile's smallest dimension so it renders the
    /// same in a 120pt grid tile and a large detail area.
    static func attributes(forDepth depth: CGFloat, dim: CGFloat) -> DepthStackPushView_CardAttributes {
        let d = max(0, depth)
        let scale: CGFloat = 1.0 - 0.085 * d
        let yOffset: CGFloat = -d * dim * 0.062
        let blur: CGFloat = min(d * dim * 0.012, dim * 0.05)
        // Floor the deepest opacity so no frame is ever blank.
        let fade: CGFloat = 1.0 - 0.18 * d
        let opacity: CGFloat = max(0.32, min(1.0, fade))
        return DepthStackPushView_CardAttributes(scale: max(0.4, scale),
                              yOffset: yOffset,
                              blur: blur,
                              opacity: opacity)
    }

    static func lerp(_ a: DepthStackPushView_CardAttributes, _ b: DepthStackPushView_CardAttributes, _ t: CGFloat) -> DepthStackPushView_CardAttributes {
        let k = max(0, min(1, t))
        return DepthStackPushView_CardAttributes(
            scale: a.scale + (b.scale - a.scale) * k,
            yOffset: a.yOffset + (b.yOffset - a.yOffset) * k,
            blur: a.blur + (b.blur - a.blur) * k,
            opacity: a.opacity + (b.opacity - a.opacity) * k
        )
    }
}

private struct DepthStackPushView_DeckPalette {
    let top: Color
    let bottom: Color
}

private struct DepthStackPushView_CardAttributes {
    var scale: CGFloat
    var yOffset: CGFloat
    var blur: CGFloat
    var opacity: CGFloat
}

// MARK: - Shared renderer

/// Renders the whole deck for a given integer `front` plus a 0→1 `fraction`
/// toward the next front. Used by both the demo and interactive drivers.
private struct DepthStackPushView_DeckLayer: View {
    let front: Int
    let fraction: CGFloat
    let dim: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<DepthStackPushView_Deck.count, id: \.self) { index in
                card(index: index)
            }
        }
    }

    private func card(index: Int) -> some View {
        let relNow = DepthStackPushView_Deck.relativeDepth(index: index, front: front)
        let relNext = DepthStackPushView_Deck.relativeDepth(index: index, front: front + 1)
        let attrsNow = DepthStackPushView_Deck.attributes(forDepth: CGFloat(relNow), dim: dim)
        let attrsNext = DepthStackPushView_Deck.attributes(forDepth: CGFloat(relNext), dim: dim)
        let attrs = DepthStackPushView_Deck.lerp(attrsNow, attrsNext, fraction)

        return DepthStackPushView_DepthCard(palette: DepthStackPushView_Deck.palette[index],
                         label: "0\(index + 1)",
                         attributes: attrs,
                         dim: dim)
            // zIndex from the INTEGER front: the leaving card keeps its high z
            // through the whole transition and only drops behind the deck at
            // the integer crossing, when it has already shrunk — masking the
            // (non-animatable) z snap.
            .zIndex(Double(DepthStackPushView_Deck.count - relNow))
    }
}

// MARK: - Demo driver (self-driving loop)

private struct DepthStackPushView_DemoDriver: View {
    let dim: CGFloat

    var body: some View {
        TimelineView(.animation) { context in
            let progress = context.date.timeIntervalSinceReferenceDate / DepthStackPushView_Deck.demoPeriod
            let wrapped = progress - floor(progress / Double(DepthStackPushView_Deck.count)) * Double(DepthStackPushView_Deck.count)
            let front = Int(wrapped) % DepthStackPushView_Deck.count
            let fraction = CGFloat(eased(wrapped - floor(wrapped)))
            DepthStackPushView_DeckLayer(front: front, fraction: fraction, dim: dim)
        }
    }

    /// Smoothstep so each auto-advance accelerates and settles instead of
    /// sliding linearly — gives the shuffle a tactile, physical cadence.
    private func eased(_ t: Double) -> Double {
        let x = max(0, min(1, t))
        return x * x * (3 - 2 * x)
    }
}

// MARK: - Interactive driver

private struct DepthStackPushView_InteractiveDriver: View {
    let dim: CGFloat

    @State private var committedFront: Int = 0
    @State private var dragFraction: CGFloat = 0
    @State private var commitTick: Int = 0

    var body: some View {
        DepthStackPushView_DeckLayer(front: committedFront, fraction: dragFraction, dim: dim)
            .contentShape(Rectangle())
            .gesture(pushGesture)
            .sensoryFeedback(.selection, trigger: commitTick)
    }

    private var pushGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let travel = max(dim, 1)
                // Forward-only push: a leftward drag advances the deck.
                let raw = -value.translation.width / travel
                dragFraction = max(0, min(1, raw))
            }
            .onEnded { value in
                let travel = max(dim, 1)
                let predicted = -value.predictedEndTranslation.width / travel
                let current = -value.translation.width / travel
                let shouldCommit = current > 0.5 || predicted > 0.85

                if shouldCommit {
                    commitTick += 1
                    withAnimation(.interactiveSpring(response: 0.42,
                                                     dampingFraction: 0.78,
                                                     blendDuration: 0.25)) {
                        dragFraction = 1
                    } completion: {
                        // Re-base on the next integer front. Attributes are
                        // identical before/after (fraction 1 @ front == fraction
                        // 0 @ front+1), so the swap is seamless.
                        committedFront = (committedFront + 1) % DepthStackPushView_Deck.count
                        dragFraction = 0
                    }
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        dragFraction = 0
                    }
                }
            }
    }
}

// MARK: - Card

private struct DepthStackPushView_DepthCard: View {
    let palette: DepthStackPushView_DeckPalette
    let label: String
    let attributes: DepthStackPushView_CardAttributes
    let dim: CGFloat

    var body: some View {
        let corner = dim * 0.09
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(
                LinearGradient(colors: [palette.top, palette.bottom],
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
            )
            .overlay(sheen(corner: corner))
            .overlay(content(corner: corner))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: max(0.5, dim * 0.006))
            )
            .frame(width: dim * 0.62, height: dim * 0.78)
            .shadow(color: Color.black.opacity(0.32),
                    radius: dim * 0.05,
                    x: 0,
                    y: dim * 0.03)
            .scaleEffect(attributes.scale)
            .offset(y: attributes.yOffset)
            .blur(radius: attributes.blur)
            .opacity(attributes.opacity)
    }

    private func sheen(corner: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.28), Color.clear],
                    startPoint: .top,
                    endPoint: .center
                )
            )
            .blendMode(.softLight)
    }

    private func content(corner: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: dim * 0.03) {
            Capsule()
                .fill(Color.white.opacity(0.85))
                .frame(width: dim * 0.16, height: max(2, dim * 0.018))
            Spacer(minLength: 0)
            Text(label)
                .font(.system(size: dim * 0.16, weight: .bold, design: .rounded))
                .foregroundColor(Color.white.opacity(0.92))
            Capsule()
                .fill(Color.white.opacity(0.45))
                .frame(width: dim * 0.30, height: max(2, dim * 0.016))
        }
        .padding(dim * 0.06)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - DepthStackPushView_Background

private struct DepthStackPushView_Background: View {
    var body: some View {
        LinearGradient(
            colors: [Color(red: 0.07, green: 0.08, blue: 0.12),
                     Color(red: 0.03, green: 0.04, blue: 0.07)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
