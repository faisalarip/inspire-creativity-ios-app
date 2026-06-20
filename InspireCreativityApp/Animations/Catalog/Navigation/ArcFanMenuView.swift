// catalog-id: nav-arc-fan-menu
import SwiftUI

/// Arc Fan Menu — a floating action button that fans its child actions out along
/// an arc with a staggered, overshooting spring (dealt out like a hand of cards),
/// then sucks them back into the hub on release.
///
/// - `demo == true`  : self-driving PhaseAnimator loop that auto-blooms/retracts.
/// - `demo == false` : real hold-to-open `LongPressGesture` interaction.
struct ArcFanMenuView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            let layout = FanLayout(size: geo.size)
            ZStack {
                backdrop(layout)
                content(layout)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Branches

    @ViewBuilder
    private func content(_ layout: FanLayout) -> some View {
        if demo {
            DemoFan(layout: layout)
        } else {
            InteractiveFan(layout: layout)
        }
    }

    @ViewBuilder
    private func backdrop(_ layout: FanLayout) -> some View {
        RoundedRectangle(cornerRadius: layout.size.width * 0.12, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(hexCode: "#1b2230"), Color(hexCode: "#101418")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: layout.size.width * 0.12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
            )
    }
}

// MARK: - Layout

/// Centralized polar geometry so the demo and interactive branches share identical math.
private struct FanLayout {
    let size: CGSize

    /// Number of fanned action items.
    let count: Int = 5

    /// Hub anchor — bottom-center, leaving room for the arc to bloom upward.
    var hub: CGPoint {
        CGPoint(x: size.width * 0.5, y: size.height * 0.82)
    }

    var minSide: CGFloat { min(size.width, size.height) }

    /// Bloom radius, tuned to keep all items inside a 120pt tile.
    var radius: CGFloat { minSide * 0.42 }

    var hubDiameter: CGFloat { minSide * 0.22 }

    var itemDiameter: CGFloat { minSide * 0.155 }

    /// Arc spans from pointing left to pointing right, opening upward (a fan).
    /// Returns the unit direction for item `i`.
    func direction(_ i: Int) -> CGSize {
        let startDeg: Double = 200   // up-left
        let endDeg: Double = 340     // up-right
        let t = count > 1 ? Double(i) / Double(count - 1) : 0.5
        let deg = startDeg + (endDeg - startDeg) * t
        let rad = deg * .pi / 180
        return CGSize(width: cos(rad), height: sin(rad))
    }

    func offset(for i: Int, open: Bool) -> CGSize {
        guard open else { return .zero }
        let dir = direction(i)
        return CGSize(width: dir.width * radius, height: dir.height * radius)
    }

    /// Per-item stagger so items arrive a beat after the last.
    func delay(for i: Int) -> Double { Double(i) * 0.05 }
}

// MARK: - Item model

private struct FanAction: Identifiable {
    let id: Int
    let symbol: String
    let tint: Color
}

private let fanActions: [FanAction] = [
    FanAction(id: 0, symbol: "square.and.arrow.up", tint: Color(hexCode: "#5ac8fa")),
    FanAction(id: 1, symbol: "heart.fill",          tint: Color(hexCode: "#ff6482")),
    FanAction(id: 2, symbol: "bookmark.fill",       tint: Color(hexCode: "#ffd60a")),
    FanAction(id: 3, symbol: "bell.fill",           tint: Color(hexCode: "#bf5af2")),
    FanAction(id: 4, symbol: "paperplane.fill",     tint: Color(hexCode: "#30d158"))
]

// MARK: - Shared fan rendering

/// Renders the hub + fanned items for a given `open` state. The driver (PhaseAnimator
/// vs. gesture state) lives in the parent; the polar math + stagger are shared here.
private struct FanBody: View {
    let layout: FanLayout
    let open: Bool

    var body: some View {
        ZStack {
            ForEach(fanActions) { action in
                itemView(action)
            }
            hubView
        }
    }

    // MARK: Items

    @ViewBuilder
    private func itemView(_ action: FanAction) -> some View {
        let off = layout.offset(for: action.id, open: open)
        Circle()
            .fill(
                RadialGradient(
                    colors: [action.tint.opacity(0.95), action.tint.opacity(0.6)],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: layout.itemDiameter
                )
            )
            .overlay(
                Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
            )
            .overlay(
                Image(systemName: action.symbol)
                    .font(.system(size: layout.itemDiameter * 0.42, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .frame(width: layout.itemDiameter, height: layout.itemDiameter)
            .shadow(color: action.tint.opacity(open ? 0.5 : 0), radius: 6, x: 0, y: 3)
            .scaleEffect(open ? 1 : 0.35)
            .opacity(open ? 1 : 0)
            .position(layout.hub)
            .offset(off)
            .animation(
                .spring(response: 0.42, dampingFraction: 0.55)
                    .delay(layout.delay(for: action.id)),
                value: open
            )
    }

    // MARK: Hub — always full opacity, never blank.

    private var hubView: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hexCode: "#ffffff"), Color(hexCode: "#cfd6e4")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.35), radius: open ? 12 : 6, x: 0, y: 4)
            Image(systemName: "plus")
                .font(.system(size: layout.hubDiameter * 0.5, weight: .bold))
                .foregroundStyle(Color(hexCode: "#101418"))
                .rotationEffect(.degrees(open ? 135 : 0))
        }
        .frame(width: layout.hubDiameter, height: layout.hubDiameter)
        .scaleEffect(open ? 0.92 : 1.0)
        .position(layout.hub)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: open)
    }
}

// MARK: - Demo driver (self-running)

private struct DemoFan: View {
    let layout: FanLayout

    var body: some View {
        // Two real phases (closed/open) plus a settle dwell phase stretches the
        // spring cycle into the ~2.5–4s window. PhaseAnimator auto-ping-pongs and
        // preserves each item's per-index delay, yielding genuine staggered overshoot.
        PhaseAnimator(DemoPhase.allCases) { phase in
            FanBody(layout: layout, open: phase.isOpen)
        } animation: { phase in
            switch phase {
            case .closed:    return .spring(response: 0.45, dampingFraction: 0.6)
            case .openBloom: return .spring(response: 0.5, dampingFraction: 0.55)
            case .openHold:  return .easeInOut(duration: 0.9)
            }
        }
    }
}

private enum DemoPhase: CaseIterable {
    case closed, openBloom, openHold

    var isOpen: Bool {
        switch self {
        case .closed:               return false
        case .openBloom, .openHold: return true
        }
    }
}

// MARK: - Interactive driver (hold-to-open)

private struct InteractiveFan: View {
    let layout: FanLayout
    @State private var open: Bool = false

    var body: some View {
        FanBody(layout: layout, open: open)
            .contentShape(Rectangle())
            // Hold-to-open: `pressing` fires true on press-down, false on release/
            // cancel — matching "fan on press, suck back on release".
            .onLongPressGesture(
                minimumDuration: 0.18,
                maximumDistance: 60,
                pressing: { isPressing in
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
                        open = isPressing
                    }
                },
                perform: {}
            )
            .sensoryFeedback(.impact(flexibility: .soft), trigger: open)
    }
}

// MARK: - Color hex helper

private extension Color {
    init(hexCode hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r, g, b, a: Double
        switch s.count {
        case 8:
            r = Double((rgb & 0xFF00_0000) >> 24) / 255
            g = Double((rgb & 0x00FF_0000) >> 16) / 255
            b = Double((rgb & 0x0000_FF00) >> 8) / 255
            a = Double(rgb & 0x0000_00FF) / 255
        case 6:
            r = Double((rgb & 0xFF0000) >> 16) / 255
            g = Double((rgb & 0x00FF00) >> 8) / 255
            b = Double(rgb & 0x0000FF) / 255
            a = 1
        default:
            r = 1; g = 1; b = 1; a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Preview
