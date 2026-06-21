// catalog-id: tr-fan-deck
import SwiftUI

/// Fan Deck — a stack of cards fans out radially like a held hand of playing
/// cards, then collapses back into a single stack centered on the chosen card.
///
/// `demo == true`  → a PhaseAnimator self-drives the fan progress 0→1→0 on a
///                   ~3s loop so the tile looks alive with no touch.
/// `demo == false` → tap the deck to fan it out; tap any fanned card to
///                   recollapse the stack centered on that card.
struct FanDeckView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                backdrop
                content(in: geo.size)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Content router

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if demo {
            FanDeckView_DemoFan(size: size)
        } else {
            FanDeckView_InteractiveFan(size: size)
        }
    }

    private var backdrop: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.08, blue: 0.12),
                        Color(red: 0.04, green: 0.05, blue: 0.08)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
}

// MARK: - Demo (self-driving loop)

private struct FanDeckView_DemoFan: View {
    let size: CGSize

    var body: some View {
        PhaseAnimator([0.0, 1.0]) { progress in
            FanDeckView_FanLayout(progress: progress, centerIndex: FanDeckView_FanConfig.centerDefault, size: size)
        } animation: { _ in
            // Slow, bouncy spring so each phase snaps then dwells: ~3s cycle.
            .spring(response: 0.95, dampingFraction: 0.55)
        }
    }
}

// MARK: - Interactive (tap to fan / tap card to recollapse)

private struct FanDeckView_InteractiveFan: View {
    let size: CGSize

    @State private var fanned: Bool = false
    @State private var centerIndex: Int = FanDeckView_FanConfig.centerDefault
    @State private var frontIndex: Int = FanDeckView_FanConfig.centerDefault

    var body: some View {
        FanDeckView_FanLayout(
            progress: fanned ? 1.0 : 0.0,
            centerIndex: centerIndex,
            frontIndex: frontIndex,
            size: size,
            onTapCard: handleTap(_:)
        )
        .contentShape(Rectangle())
        .onTapGesture { toggleFan() }
        .animation(.spring(response: 0.5, dampingFraction: 0.62), value: fanned)
        .animation(.spring(response: 0.5, dampingFraction: 0.62), value: centerIndex)
        .sensoryFeedback(.impact(weight: .light), trigger: fanned)
    }

    private func toggleFan() {
        fanned.toggle()
    }

    private func handleTap(_ index: Int) {
        if fanned {
            // Recollapse centered on the chosen card; raise it to the front
            // first so it collapses to the top of the deck (never hidden).
            frontIndex = index
            centerIndex = index
            fanned = false
        } else {
            fanned = true
        }
    }
}

// MARK: - Shared renderer

/// Single layout used identically by both modes. Only the *source* of
/// `progress` differs, so demo and interactive always look the same.
private struct FanDeckView_FanLayout: View {
    let progress: CGFloat
    let centerIndex: Int
    var frontIndex: Int = FanDeckView_FanConfig.centerDefault
    let size: CGSize
    var onTapCard: ((Int) -> Void)? = nil

    var body: some View {
        let metrics = FanDeckView_FanMetrics(size: size)
        ZStack {
            ForEach(0..<FanDeckView_FanConfig.count, id: \.self) { i in
                card(i, metrics: metrics)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func card(_ i: Int, metrics: FanDeckView_FanMetrics) -> some View {
        FanDeckView_CardFace(index: i, size: metrics.card)
            // Pivot every card about the SAME low point so tops spread in an
            // arc while bottoms stay pinned — a true fan, not a scale.
            .rotationEffect(.degrees(angle(for: i)), anchor: metrics.pivotAnchor)
            // Residual non-progress offset keeps the collapsed state reading
            // as a layered deck rather than one flat card.
            .offset(y: residualOffset(for: i))
            .offset(y: metrics.pivotLift)
            .zIndex(zIndex(for: i))
            .contentShape(Rectangle())
            .onTapGesture { onTapCard?(i) }
    }

    // Single source of truth for the angle. centerIndex stays upright; the
    // fan is symmetric around it; progress→0 brings every card back to rest.
    private func angle(for i: Int) -> Double {
        let spread = CGFloat(i - centerIndex) * FanDeckView_FanConfig.perCardDegrees
        let floor = CGFloat(i - centerIndex) * FanDeckView_FanConfig.collapsedDegrees
        let value = floor + (spread - floor) * progress
        return Double(value)
    }

    private func residualOffset(for i: Int) -> CGFloat {
        CGFloat(i - centerIndex) * FanDeckView_FanConfig.deckStep
    }

    private func zIndex(for i: Int) -> Double {
        if i == frontIndex { return 100 }
        // Cards nearer the chosen center sit higher in the deck.
        return Double(FanDeckView_FanConfig.count - abs(i - centerIndex))
    }
}

// MARK: - Geometry

private struct FanDeckView_FanConfig {
    static let count: Int = 5
    static let centerDefault: Int = 2
    static let perCardDegrees: CGFloat = 15   // fanned spread per card
    static let collapsedDegrees: CGFloat = 1.4 // residual tilt when stacked
    static let deckStep: CGFloat = 1.6        // residual y-step when stacked
}

private struct FanDeckView_FanMetrics {
    let card: CGSize
    let pivotLift: CGFloat
    let pivotAnchor: UnitPoint

    init(size: CGSize) {
        let minSide = min(size.width, size.height)
        let h = max(40, minSide * 0.55)
        let w = h * 0.66
        card = CGSize(width: w, height: h)
        // Anchor low on the card and lift the whole stack down a touch so the
        // fanned arc stays inside a near-square tile (no parent clipping).
        pivotAnchor = UnitPoint(x: 0.5, y: 0.92)
        pivotLift = minSide * 0.10
    }
}

// MARK: - Card face

private struct FanDeckView_CardFace: View {
    let index: Int
    let size: CGSize

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(faceGradient)
            .overlay(border)
            .overlay(pip)
            .frame(width: size.width, height: size.height)
            .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)
    }

    private var cornerRadius: CGFloat { max(6, size.width * 0.12) }

    private var faceGradient: LinearGradient {
        LinearGradient(
            colors: [topTint, bottomTint],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var topTint: Color {
        Color(red: 0.99, green: 0.98, blue: 0.96)
    }

    private var bottomTint: Color {
        // Subtle per-card hue variation so the fan reads as distinct cards.
        let t = Double(index) / Double(max(1, FanDeckView_FanConfig.count - 1))
        let r = 0.90 - 0.04 * t
        let g = 0.92 - 0.10 * t
        let b = 0.98 - 0.02 * t
        return Color(red: r, green: g, blue: b)
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(Color.black.opacity(0.12), lineWidth: 1)
    }

    private var pip: some View {
        // A small colored suit pip in the upper-left corner per card.
        Circle()
            .fill(pipColor)
            .frame(width: size.width * 0.16, height: size.width * 0.16)
            .padding(size.width * 0.14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var pipColor: Color {
        let palette: [Color] = [
            Color(red: 0.85, green: 0.22, blue: 0.28),
            Color(red: 0.18, green: 0.20, blue: 0.24),
            Color(red: 0.90, green: 0.55, blue: 0.16),
            Color(red: 0.20, green: 0.52, blue: 0.74),
            Color(red: 0.36, green: 0.62, blue: 0.34)
        ]
        return palette[index % palette.count]
    }
}
