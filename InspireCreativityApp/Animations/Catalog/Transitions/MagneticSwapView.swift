// catalog-id: tr-magnetic-swap
import SwiftUI

// MARK: - Magnetic Swap
// Two cards trade slots with a springy magnetic pull and overshoot recoil.
// demo == true  -> a self-driving PhaseAnimator loop cycles the swap continuously.
// demo == false -> a real DragGesture on a card drives the swap; release past the
//                  midpoint commits both cards with .spring(bounce:) + a haptic tick.
struct MagneticSwapView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            if demo {
                MagneticSwapView_DemoDriver(size: geo.size)
            } else {
                MagneticSwapView_InteractiveDriver(size: geo.size)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Shared geometry / colors

private enum MagneticSwapView_SwapMetrics {
    // Slot layout is computed from the available size so it reads at 120pt and large.
    static func cardSize(for size: CGSize) -> CGSize {
        let w = min(size.width, size.height * 1.6)
        let cardW = max(28, w * 0.34)
        let cardH = max(36, min(size.height * 0.62, cardW * 1.32))
        return CGSize(width: cardW, height: cardH)
    }

    // Horizontal centers of the two slots, as a fraction-driven absolute point.
    static func leftSlot(for size: CGSize) -> CGPoint {
        CGPoint(x: size.width * 0.31, y: size.height * 0.5)
    }
    static func rightSlot(for size: CGSize) -> CGPoint {
        CGPoint(x: size.width * 0.69, y: size.height * 0.5)
    }

    // Vertical arc amplitude so the two cards pass each other instead of colliding.
    static func arc(for size: CGSize) -> CGFloat {
        min(size.height * 0.22, 26)
    }
}

private enum MagneticSwapView_SwapPalette {
    static let backdropTop = Color(red: 0.07, green: 0.08, blue: 0.11)
    static let backdropBottom = Color(red: 0.04, green: 0.05, blue: 0.07)

    static let cardATop = Color(red: 0.36, green: 0.62, blue: 1.0)
    static let cardABottom = Color(red: 0.20, green: 0.34, blue: 0.92)

    static let cardBTop = Color(red: 1.0, green: 0.52, blue: 0.42)
    static let cardBBottom = Color(red: 0.93, green: 0.30, blue: 0.46)

    static let slotStroke = Color(red: 1.0, green: 1.0, blue: 1.0).opacity(0.10)
}

// MARK: - Pure progress -> layout helpers
// One render path: both drivers feed `progress` (0 = original, 1 = swapped) and
// `lean` (0...1 magnetic-attraction strength) into the same Stage view.

private struct MagneticSwapView_SwapLayout {
    let size: CGSize
    let progress: CGFloat   // 0...1 (can mildly overshoot during a spring)
    let lean: CGFloat       // 0...1 magnetic lean strength

    private var clampedP: CGFloat { min(max(progress, 0), 1) }

    // Card A travels left -> right over the top arc.
    func centerA() -> CGPoint {
        let l = MagneticSwapView_SwapMetrics.leftSlot(for: size)
        let r = MagneticSwapView_SwapMetrics.rightSlot(for: size)
        let x = l.x + (r.x - l.x) * progress
        let arc = MagneticSwapView_SwapMetrics.arc(for: size)
        // bell curve peak at p=0.5, lifting upward (negative y).
        let y = l.y - arc * bell(clampedP)
        return CGPoint(x: x, y: y)
    }

    // Card B travels right -> left under the bottom arc.
    func centerB() -> CGPoint {
        let l = MagneticSwapView_SwapMetrics.leftSlot(for: size)
        let r = MagneticSwapView_SwapMetrics.rightSlot(for: size)
        let x = r.x + (l.x - r.x) * progress
        let arc = MagneticSwapView_SwapMetrics.arc(for: size)
        let y = r.y + arc * bell(clampedP)
        return CGPoint(x: x, y: y)
    }

    // Rotation: a base tilt as it travels, plus a magnetic lean toward the partner
    // that becomes perceptible as the cards approach the swap threshold.
    func rotationA() -> Angle {
        let travel = sin(clampedP * .pi) * 8.0          // gentle banking through the arc
        let magnet = leanCurve() * 14.0 * Double(lean)  // lean toward partner
        return .degrees(Double(travel) + magnet)
    }
    func rotationB() -> Angle {
        let travel = -sin(clampedP * .pi) * 8.0
        let magnet = -leanCurve() * 14.0 * Double(lean)
        return .degrees(Double(travel) + magnet)
    }

    // A tiny pull-together offset so the stationary card visibly "reaches" toward
    // the dragged one before they commit. Scaled by card width to stay legible.
    func magneticPull() -> CGFloat {
        let cw = MagneticSwapView_SwapMetrics.cardSize(for: size).width
        return CGFloat(leanCurve()) * lean * cw * 0.16
    }

    // Lift / scale while mid-flight so the moving card feels picked up.
    func scaleA() -> CGFloat { 1.0 + 0.07 * CGFloat(bell(clampedP)) }
    func scaleB() -> CGFloat { 1.0 + 0.07 * CGFloat(bell(clampedP)) }

    // Shadow grows as the cards lift off their slots.
    func shadowRadius() -> CGFloat {
        let cw = MagneticSwapView_SwapMetrics.cardSize(for: size).width
        return cw * (0.06 + 0.16 * CGFloat(bell(clampedP)))
    }

    private func bell(_ p: CGFloat) -> Double {
        // 0 at the ends, 1 at the middle.
        Double(sin(p * .pi))
    }

    // Lean ramps up as progress approaches the midpoint and fades after passing it.
    private func leanCurve() -> Double {
        let p = Double(clampedP)
        // peak near the midpoint, signed so both halves pull inward.
        let centred = 1.0 - abs(p - 0.5) * 2.0   // 0 at ends, 1 at middle
        return max(0, centred)
    }
}

// MARK: - The shared visual stage

private struct MagneticSwapView_SwapStage: View {
    let layout: MagneticSwapView_SwapLayout
    // labels swap at the midpoint so the cards convincingly trade identities.
    var labelFlipped: Bool

    var body: some View {
        ZStack {
            backdrop
            slotGuides
            // Draw the lower-arc card first so the upper-arc card overlaps it
            // as they cross — sells the physical "lift over" swap.
            cardB
            cardA
        }
    }

    private var backdrop: some View {
        LinearGradient(
            colors: [MagneticSwapView_SwapPalette.backdropTop, MagneticSwapView_SwapPalette.backdropBottom],
            startPoint: .top, endPoint: .bottom
        )
    }

    private var slotGuides: some View {
        let cs = MagneticSwapView_SwapMetrics.cardSize(for: layout.size)
        let l = MagneticSwapView_SwapMetrics.leftSlot(for: layout.size)
        let r = MagneticSwapView_SwapMetrics.rightSlot(for: layout.size)
        return ZStack {
            slotShape(cs).position(l)
            slotShape(cs).position(r)
        }
    }

    private func slotShape(_ cs: CGSize) -> some View {
        RoundedRectangle(cornerRadius: cs.width * 0.18, style: .continuous)
            .strokeBorder(MagneticSwapView_SwapPalette.slotStroke, style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
            .frame(width: cs.width, height: cs.height)
    }

    private var cardA: some View {
        let cs = MagneticSwapView_SwapMetrics.cardSize(for: layout.size)
        let pull = layout.magneticPull()
        return MagneticSwapView_CardFace(
            size: cs,
            top: MagneticSwapView_SwapPalette.cardATop,
            bottom: MagneticSwapView_SwapPalette.cardABottom,
            symbol: labelFlipped ? "bolt.fill" : "sparkles",
            shadow: layout.shadowRadius()
        )
        .scaleEffect(layout.scaleA())
        .rotationEffect(layout.rotationA())
        .position(layout.centerA())
        // pull toward partner (A pulls right toward B's origin slot).
        .offset(x: pull)
    }

    private var cardB: some View {
        let cs = MagneticSwapView_SwapMetrics.cardSize(for: layout.size)
        let pull = layout.magneticPull()
        return MagneticSwapView_CardFace(
            size: cs,
            top: MagneticSwapView_SwapPalette.cardBTop,
            bottom: MagneticSwapView_SwapPalette.cardBBottom,
            symbol: labelFlipped ? "sparkles" : "bolt.fill",
            shadow: layout.shadowRadius()
        )
        .scaleEffect(layout.scaleB())
        .rotationEffect(layout.rotationB())
        .position(layout.centerB())
        // B pulls left toward A's origin slot.
        .offset(x: -pull)
    }
}

private struct MagneticSwapView_CardFace: View {
    let size: CGSize
    let top: Color
    let bottom: Color
    let symbol: String
    let shadow: CGFloat

    var body: some View {
        let radius = size.width * 0.18
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [top, bottom],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .overlay(sheen(radius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color(red: 1, green: 1, blue: 1).opacity(0.22), lineWidth: 1)
            )
            .overlay(glyph)
            .frame(width: size.width, height: size.height)
            .shadow(color: Color(red: 0, green: 0, blue: 0).opacity(0.45),
                    radius: shadow, x: 0, y: shadow * 0.45)
    }

    private func sheen(radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 1, green: 1, blue: 1).opacity(0.30),
                        Color(red: 1, green: 1, blue: 1).opacity(0.0)
                    ],
                    startPoint: .top, endPoint: .center
                )
            )
            .blendMode(.screen)
    }

    private var glyph: some View {
        Image(systemName: symbol)
            .font(.system(size: size.width * 0.30, weight: .bold))
            .foregroundStyle(Color(red: 1, green: 1, blue: 1).opacity(0.92))
            .shadow(color: Color(red: 0, green: 0, blue: 0).opacity(0.3), radius: 2, y: 1)
    }
}

// MARK: - Demo driver (self-playing, no touch, ~3.2s loop)

private struct MagneticSwapView_DemoDriver: View {
    let size: CGSize

    // Phases: hold at 0, swap to 1, hold at 1, swap back to 0.
    private let phases: [CGFloat] = [0, 0, 1, 1, 0]

    var body: some View {
        PhaseAnimator(phases) { p in
            let lean = leanStrength(for: p)
            MagneticSwapView_SwapStage(
                layout: MagneticSwapView_SwapLayout(size: size, progress: p, lean: lean),
                labelFlipped: p >= 0.5
            )
        } animation: { _ in
            // Bouncy commit gives the overshoot recoil; the held phases keep the
            // overall cadence inside the 2.5-4s window without strobing.
            .spring(response: 0.7, dampingFraction: 0.55).delay(0.35)
        }
    }

    private func leanStrength(for p: CGFloat) -> CGFloat {
        // Always show some magnetism so the tile reads as "magnetic" even at rest.
        0.85
    }
}

// MARK: - Interactive driver

private struct MagneticSwapView_InteractiveDriver: View {
    let size: CGSize

    @State private var committed: CGFloat = 0      // 0 or 1: last settled state
    @State private var dragProgress: CGFloat = 0   // live progress while dragging
    @State private var isDragging: Bool = false
    @State private var snapTick: Int = 0           // drives sensory feedback on commit

    var body: some View {
        let progress = isDragging ? dragProgress : committed
        let lean: CGFloat = isDragging ? 1.0 : 0.0

        MagneticSwapView_SwapStage(
            layout: MagneticSwapView_SwapLayout(size: size, progress: progress, lean: lean),
            labelFlipped: progress >= 0.5
        )
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: snapTick)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDragging { isDragging = true }
                let span = travelSpan()
                // Translation along the swap axis; direction depends on which way
                // we're currently swapping (0->1 moves right, 1->0 moves left).
                let raw = committed == 0 ? value.translation.width : -value.translation.width
                let delta = raw / span
                let base = committed
                dragProgress = clamp(base + delta)
            }
            .onEnded { value in
                let span = travelSpan()
                let raw = committed == 0 ? value.translation.width : -value.translation.width
                let velocity = committed == 0 ? value.predictedEndTranslation.width
                                              : -value.predictedEndTranslation.width
                let projected = (raw + (velocity - raw) * 0.25) / span
                let target: CGFloat = (committed + projected) >= 0.5 ? 1 : 0

                let changed = target != committed
                withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                    committed = target
                    dragProgress = target
                    isDragging = false
                }
                if changed { snapTick += 1 } // haptic only on a real commit
            }
    }

    private func travelSpan() -> CGFloat {
        let l = MagneticSwapView_SwapMetrics.leftSlot(for: size)
        let r = MagneticSwapView_SwapMetrics.rightSlot(for: size)
        return max(1, r.x - l.x)
    }

    private func clamp(_ v: CGFloat) -> CGFloat { min(max(v, 0), 1) }
}
