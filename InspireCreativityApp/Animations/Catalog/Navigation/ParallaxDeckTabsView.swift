// catalog-id: nav-parallax-deck-tabs
import SwiftUI

/// Parallax Deck Tabs
///
/// Tabs live on three stacked depth planes. The selected tab rises toward the
/// viewer while neighbors recede and blur, with a light rotation3DEffect tilt
/// that gives the deck a parallax feel as selection moves. Selection becomes a
/// Z-axis move, not an X-axis slide — the active tab physically lifts out of a
/// deck of cards.
///
/// - demo == true : a PhaseAnimator auto-cycles which card is frontmost so the
///   deck keeps lifting one card forward and pushing the rest back, alive with
///   no touch.
/// - demo == false: tap a card to select it; a single spring drives the
///   Z-rise, neighbor recede, blur and tilt.
struct ParallaxDeckTabsView: View {
    var demo: Bool = false

    private let tabs: [ParallaxDeckTabsView_DeckTab] = ParallaxDeckTabsView_DeckTab.sample
    @State private var selected: Int = 1

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                background

                if demo {
                    autoDriving(in: size)
                } else {
                    interactive(in: size)
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Backdrop

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.06, blue: 0.10),
                Color(red: 0.10, green: 0.11, blue: 0.16)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Auto-driving (demo)

    private func autoDriving(in size: CGSize) -> some View {
        PhaseAnimator(Array(0..<tabs.count)) { phase in
            deck(selectedIndex: phase, in: size)
        } animation: { _ in
            .spring(duration: 0.45, bounce: 0.3)
        }
    }

    // MARK: - Interactive

    private func interactive(in size: CGSize) -> some View {
        deck(selectedIndex: selected, in: size)
            .animation(.spring(response: 0.5, dampingFraction: 0.68), value: selected)
    }

    // MARK: - Deck

    @ViewBuilder
    private func deck(selectedIndex: Int, in size: CGSize) -> some View {
        let metrics = ParallaxDeckTabsView_DeckMetrics(size: size)

        ZStack {
            ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                cardView(tab: tab, index: index, selectedIndex: selectedIndex, metrics: metrics)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func cardView(tab: ParallaxDeckTabsView_DeckTab, index: Int, selectedIndex: Int, metrics: ParallaxDeckTabsView_DeckMetrics) -> some View {
        let distance: Double = Double(index - selectedIndex)
        let clamped: Double = max(-2.0, min(2.0, distance))
        let absClamped: Double = abs(clamped)

        ParallaxDeckTabsView_DeckCard(tab: tab, isFront: index == selectedIndex, metrics: metrics)
            .frame(width: metrics.cardWidth, height: metrics.cardHeight)
            .scaleEffect(scale(absClamped))
            .blur(radius: blurRadius(absClamped))
            .rotation3DEffect(
                .degrees(tilt(clamped)),
                axis: (x: 0, y: 1, z: 0),
                anchor: .center,
                perspective: 0.55
            )
            .offset(x: xOffset(clamped, metrics: metrics), y: yOffset(absClamped, metrics: metrics))
            .opacity(opacity(absClamped))
            .shadow(
                color: Color.black.opacity(shadowOpacity(absClamped)),
                radius: shadowRadius(absClamped),
                x: 0,
                y: shadowYOffset(absClamped)
            )
            .zIndex(zValue(absClamped))
            .contentShape(Rectangle())
            .onTapGesture {
                guard !demo else { return }
                selected = index
            }
    }

    // MARK: - Transform helpers (pure functions of clamped distance)

    private func scale(_ absD: Double) -> CGFloat {
        // Front card largest; recede ~14% per plane, floored so far cards stay legible.
        let s: Double = 1.0 - absD * 0.14
        return CGFloat(max(0.7, s))
    }

    private func blurRadius(_ absD: Double) -> CGFloat {
        // Front card sharp; neighbors soften, capped so they never dissolve.
        CGFloat(min(7.0, absD * 3.6))
    }

    private func tilt(_ d: Double) -> Double {
        // Signed tilt away from center sells the parallax depth, kept small.
        max(-11.0, min(11.0, d * 7.0))
    }

    private func xOffset(_ d: Double, metrics: ParallaxDeckTabsView_DeckMetrics) -> CGFloat {
        // Fan the deck sideways so back cards peek out behind the front one.
        CGFloat(d) * metrics.xSpread
    }

    private func yOffset(_ absD: Double, metrics: ParallaxDeckTabsView_DeckMetrics) -> CGFloat {
        // Front card lifts up; receding cards sink down into the stack.
        CGFloat(absD) * metrics.ySink
    }

    private func opacity(_ absD: Double) -> Double {
        // Never fully transparent — floored so every plane stays readable.
        max(0.45, 1.0 - absD * 0.26)
    }

    private func zValue(_ absD: Double) -> Double {
        // Closer to selected => higher in the stack.
        2.0 - absD
    }

    private func shadowOpacity(_ absD: Double) -> Double {
        absD < 0.5 ? 0.42 : 0.18
    }

    private func shadowRadius(_ absD: Double) -> CGFloat {
        absD < 0.5 ? 18.0 : 8.0
    }

    private func shadowYOffset(_ absD: Double) -> CGFloat {
        absD < 0.5 ? 14.0 : 6.0
    }
}

// MARK: - Layout metrics

private struct ParallaxDeckTabsView_DeckMetrics {
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let xSpread: CGFloat
    let ySink: CGFloat
    let corner: CGFloat
    let compact: Bool

    init(size: CGSize) {
        let minSide: CGFloat = min(size.width, size.height)
        compact = minSide < 220
        cardWidth = max(40, min(size.width * 0.62, 320))
        cardHeight = max(54, min(size.height * 0.72, 360))
        xSpread = cardWidth * 0.20
        ySink = cardHeight * 0.055
        corner = compact ? 14 : 24
    }
}

// MARK: - Card model

private struct ParallaxDeckTabsView_DeckTab: Identifiable {
    let id: Int
    let title: String
    let systemImage: String
    let top: Color
    let bottom: Color

    static let sample: [ParallaxDeckTabsView_DeckTab] = [
        ParallaxDeckTabsView_DeckTab(id: 0, title: "Discover", systemImage: "sparkles",
                top: Color(red: 0.36, green: 0.32, blue: 0.86),
                bottom: Color(red: 0.20, green: 0.18, blue: 0.55)),
        ParallaxDeckTabsView_DeckTab(id: 1, title: "Create", systemImage: "wand.and.stars",
                top: Color(red: 0.95, green: 0.42, blue: 0.55),
                bottom: Color(red: 0.62, green: 0.21, blue: 0.42)),
        ParallaxDeckTabsView_DeckTab(id: 2, title: "Library", systemImage: "books.vertical.fill",
                top: Color(red: 0.30, green: 0.74, blue: 0.78),
                bottom: Color(red: 0.13, green: 0.44, blue: 0.52)),
        ParallaxDeckTabsView_DeckTab(id: 3, title: "Profile", systemImage: "person.crop.circle.fill",
                top: Color(red: 0.98, green: 0.74, blue: 0.36),
                bottom: Color(red: 0.70, green: 0.45, blue: 0.16))
    ]
}

// MARK: - Card view

private struct ParallaxDeckTabsView_DeckCard: View {
    let tab: ParallaxDeckTabsView_DeckTab
    let isFront: Bool
    let metrics: ParallaxDeckTabsView_DeckMetrics

    var body: some View {
        ZStack {
            base
            sheen
            content
        }
        .overlay(border)
        .clipShape(RoundedRectangle(cornerRadius: metrics.corner, style: .continuous))
    }

    private var base: some View {
        RoundedRectangle(cornerRadius: metrics.corner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [tab.top, tab.bottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var sheen: some View {
        RoundedRectangle(cornerRadius: metrics.corner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(isFront ? 0.28 : 0.14),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
            )
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: metrics.corner, style: .continuous)
            .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
    }

    @ViewBuilder
    private var content: some View {
        if metrics.compact {
            compactContent
        } else {
            fullContent
        }
    }

    private var compactContent: some View {
        Image(systemName: tab.systemImage)
            .font(.system(size: 26, weight: .semibold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
    }

    private var fullContent: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 64, height: 64)
                Image(systemName: tab.systemImage)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text(tab.title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
        }
        .padding(.horizontal, 12)
    }
}
