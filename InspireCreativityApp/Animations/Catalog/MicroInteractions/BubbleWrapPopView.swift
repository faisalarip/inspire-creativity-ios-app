// catalog-id: mi-bubble-wrap-pop
import SwiftUI

/// Bubble Wrap Pop — a grid of glossy bubbles that deflate with a wet squish on tap.
///
/// - `demo == true`  → a self-driving `TimelineView(.animation)` loop pops and
///   re-inflates bubbles on staggered per-cell cycles, so the tile is always alive.
/// - `demo == false` → real interactive bubble wrap: tap a bubble to squish it flat
///   (with haptic), and it re-inflates after a short delay.
struct BubbleWrapPopView: View {
    var demo: Bool = false

    // Grid configuration.
    private let columns: Int = 5
    private let rows: Int = 6

    // Interactive state: which bubbles are currently popped (flat).
    @State private var poppedAt: [Int: Date] = [:]
    @State private var lastPoppedIndex: Int = -1

    var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        let cell: CGFloat = cellSide(for: size)
        let gridWidth: CGFloat = cell * CGFloat(columns)
        let gridHeight: CGFloat = cell * CGFloat(rows)

        ZStack {
            backdrop
            TimelineView(.animation) { timeline in
                grid(cell: cell, now: timeline.date)
            }
            .frame(width: gridWidth, height: gridHeight)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .sensoryFeedback(.impact(weight: .light), trigger: lastPoppedIndex)
    }

    private var backdrop: some View {
        RadialGradient(
            colors: [Color(hexCode: "1d1626"), Color(hexCode: "120c1b")],
            center: .topLeading,
            startRadius: 4,
            endRadius: 320
        )
    }

    // MARK: - Grid

    private func grid(cell: CGFloat, now: Date) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<columns, id: \.self) { c in
                        let index: Int = r * columns + c
                        BubbleCell(
                            squish: squish(for: index, now: now),
                            side: cell
                        )
                        .frame(width: cell, height: cell)
                        .contentShape(Rectangle())
                        .onTapGesture { handleTap(index) }
                    }
                }
            }
        }
    }

    // MARK: - Layout helpers

    private func cellSide(for size: CGSize) -> CGFloat {
        let byWidth: CGFloat = size.width / CGFloat(columns)
        let byHeight: CGFloat = size.height / CGFloat(rows)
        return max(8, min(byWidth, byHeight))
    }

    // MARK: - Squish computation
    // squish: 0 = fully inflated (round, glossy), 1 = fully popped (flat dimple).

    private func squish(for index: Int, now: Date) -> CGFloat {
        if demo {
            return demoSquish(for: index, now: now)
        } else {
            return interactiveSquish(for: index, now: now)
        }
    }

    /// Deterministic, staggered self-pop derived from time + a per-cell phase seed.
    /// Each bubble lives on its own ~3s cycle; at most a thin slice of the cycle is
    /// "popped", so the grid is never blank and stays mostly inflated and glossy.
    private func demoSquish(for index: Int, now: Date) -> CGFloat {
        let period: Double = 3.2
        let t: Double = now.timeIntervalSinceReferenceDate
        let phase: Double = cellPhase(index)
        // Normalised position within this cell's own cycle.
        let local: Double = ((t / period) + phase).truncatingRemainder(dividingBy: 1.0)

        // Popped only during a short window of the cycle.
        let popStart: Double = 0.10
        let popEnd: Double = 0.34
        guard local >= popStart, local <= popEnd else { return 0 }

        let span: Double = popEnd - popStart
        let p: Double = (local - popStart) / span        // 0→1 across the window
        // Fast squish in, slower re-inflate out — an asymmetric pulse.
        let shaped: Double = p < 0.32
            ? easeOut(p / 0.32)                           // cave in quickly
            : 1.0 - easeInOut((p - 0.32) / 0.68)          // ease back to round
        return CGFloat(min(1, max(0, shaped)))
    }

    /// Interactive squish: a tapped bubble springs flat then re-inflates after a delay,
    /// computed against the timeline clock so it animates smoothly without per-cell springs.
    private func interactiveSquish(for index: Int, now: Date) -> CGFloat {
        guard let popped = poppedAt[index] else { return 0 }
        let elapsed: Double = now.timeIntervalSince(popped)

        let squishIn: Double = 0.14    // time to cave in
        let hold: Double = 0.9         // stay flat
        let reinflate: Double = 0.5    // ease back to round

        if elapsed < squishIn {
            return CGFloat(easeOut(elapsed / squishIn))
        } else if elapsed < squishIn + hold {
            return 1
        } else if elapsed < squishIn + hold + reinflate {
            let p: Double = (elapsed - squishIn - hold) / reinflate
            return CGFloat(1.0 - easeInOut(p))
        } else {
            return 0
        }
    }

    private func cellPhase(_ index: Int) -> Double {
        // Cheap deterministic hash → spread phases across [0,1).
        var h: UInt64 = UInt64(bitPattern: Int64(index &* 2654435761))
        h ^= h >> 33
        h = h &* 0xff51afd7ed558ccd
        h ^= h >> 33
        return Double(h % 1000) / 1000.0
    }

    // MARK: - Interaction

    private func handleTap(_ index: Int) {
        guard !demo else { return }
        // Re-pop even if already animating, so it always feels responsive.
        poppedAt[index] = Date()
        lastPoppedIndex = index
    }
}

// MARK: - Single bubble

private struct BubbleCell: View {
    /// 0 = inflated, 1 = popped flat.
    let squish: CGFloat
    let side: CGFloat

    var body: some View {
        let inset: CGFloat = side * 0.10
        let diameter: CGFloat = side - inset * 2

        // Anisotropic squish: widen slightly, flatten a lot — a wet cave-in.
        let scaleX: CGFloat = 1.0 + 0.08 * squish
        let scaleY: CGFloat = 1.0 - 0.46 * squish
        // Highlight collapses and dims as the dome flattens.
        let gloss: CGFloat = 1.0 - 0.85 * squish

        ZStack {
            dimple(diameter: diameter)        // the pressed-in seat, always visible
            dome(diameter: diameter, gloss: gloss)
                .scaleEffect(x: scaleX, y: scaleY)
                .shadow(
                    color: Color.black.opacity(0.35 * (1 - squish) + 0.08),
                    radius: 3 * (1 - squish) + 0.5,
                    x: 0,
                    y: 2 * (1 - squish) + 0.5
                )
        }
        .frame(width: diameter, height: diameter)
        .animation(nil, value: squish) // squish is driven by the timeline clock, not implicit anim
    }

    /// The static recessed seat beneath each bubble — keeps a popped cell legible.
    private func dimple(diameter: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color(hexCode: "0d0913"), Color(hexCode: "241a31")],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter * 0.55
                )
            )
            .overlay(
                Circle().strokeBorder(Color.white.opacity(0.05), lineWidth: 0.5)
            )
            .frame(width: diameter * 0.96, height: diameter * 0.96)
    }

    /// The glossy inflated dome.
    private func dome(diameter: CGFloat, gloss: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(hexCode: "b59cff").opacity(0.95),
                        Color(hexCode: "7d5cf0"),
                        Color(hexCode: "4a32a8")
                    ],
                    center: UnitPoint(x: 0.38, y: 0.34),
                    startRadius: 1,
                    endRadius: diameter * 0.7
                )
            )
            .overlay(specularHighlight(diameter: diameter, gloss: gloss))
            .overlay(rimLight(diameter: diameter, gloss: gloss))
            .opacity(0.55 + 0.45 * gloss)
    }

    private func specularHighlight(diameter: CGFloat, gloss: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color.white.opacity(0.95 * gloss), Color.white.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter * 0.22
                )
            )
            .frame(width: diameter * 0.42, height: diameter * 0.42)
            .offset(x: -diameter * 0.16, y: -diameter * 0.18)
    }

    private func rimLight(diameter: CGFloat, gloss: CGFloat) -> some View {
        Circle()
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.4 * gloss),
                        Color.white.opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: max(0.5, diameter * 0.03)
            )
    }
}

// MARK: - Easing

private func easeOut(_ t: Double) -> Double {
    let c: Double = min(1, max(0, t))
    return 1 - pow(1 - c, 2.4)
}

private func easeInOut(_ t: Double) -> Double {
    let c: Double = min(1, max(0, t))
    return c < 0.5 ? 2 * c * c : 1 - pow(-2 * c + 2, 2) / 2
}

// MARK: - Color hex helper

private extension Color {
    init(hexCode hex: String) {
        let s = Scanner(string: hex.hasPrefix("#") ? String(hex.dropFirst()) : hex)
        var rgb: UInt64 = 0
        s.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
