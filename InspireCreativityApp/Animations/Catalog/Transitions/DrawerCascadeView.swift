// catalog-id: tr-drawer-cascade
import SwiftUI

/// Drawer Cascade — stacked horizontal drawer panels slide open sequentially from a
/// closed cabinet, each sliding out further than the last with deepening drop-shadows,
/// the open drawers revealing the destination content behind them.
///
/// - demo == true:  self-driving loop. A TimelineView(.animation) walks a continuous
///   0→1→0 triangle wave; each drawer reads a staggered sub-range of that progress so
///   the cascade pulls out one after another, then retracts, forever. Never blank.
/// - demo == false: real interactive component. An onTapGesture toggles `isOpen`, and
///   each panel carries its own `.delay(index * stagger)` spring so the open animation
///   genuinely cascades down the stack.
struct DrawerCascadeView: View {
    var demo: Bool = false

    private let drawerCount: Int = 5

    var body: some View {
        GeometryReader { geo in
            content(size: geo.size)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(size: CGSize) -> some View {
        if demo {
            DrawerCascadeView_DemoCabinet(size: size, drawerCount: drawerCount)
        } else {
            DrawerCascadeView_InteractiveCabinet(size: size, drawerCount: drawerCount)
        }
    }
}

// MARK: - Demo (self-driving)

private struct DrawerCascadeView_DemoCabinet: View {
    let size: CGSize
    let drawerCount: Int

    private let loop: Double = 3.2

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = (t.truncatingRemainder(dividingBy: loop)) / loop
            // Smooth 0→1→0 triangle, eased so the ends linger (drawers fully out / fully in).
            let raw = triangle(phase)
            let p = ease(raw)
            DrawerCascadeView_Cabinet(size: size, drawerCount: drawerCount) { index in
                staggeredProgress(globalProgress: p, index: index)
            }
        }
    }

    /// Triangle wave 0→1→0 over a unit phase.
    private func triangle(_ x: Double) -> Double {
        x < 0.5 ? x * 2.0 : (1.0 - x) * 2.0
    }

    /// Smoothstep easing so motion settles at both ends.
    private func ease(_ x: Double) -> Double {
        let c = min(max(x, 0.0), 1.0)
        return c * c * (3.0 - 2.0 * c)
    }

    /// Map the single global progress to a per-drawer sub-range so each drawer leads
    /// the one above it — the cascade.
    private func staggeredProgress(globalProgress p: Double, index: Int) -> Double {
        let stagger: Double = 0.10
        let window: Double = 1.0 - stagger * Double(max(drawerCount - 1, 1))
        let start = Double(index) * stagger
        let local = (p - start) / max(window, 0.0001)
        return min(max(local, 0.0), 1.0)
    }
}

// MARK: - Interactive (tap to toggle)

private struct DrawerCascadeView_InteractiveCabinet: View {
    let size: CGSize
    let drawerCount: Int

    @State private var isOpen: Bool = false

    var body: some View {
        DrawerCascadeView_Cabinet(size: size, drawerCount: drawerCount, perDrawerDelay: { index in
            // Top drawer leads; lower drawers follow. This is what gives the cascade
            // under a single isOpen toggle (the spring delay differs per panel).
            Double(index) * 0.075
        }, targetProgress: { _ in
            isOpen ? 1.0 : 0.0
        })
        .contentShape(Rectangle())
        .onTapGesture {
            isOpen.toggle()
        }
    }
}

// MARK: - Shared cabinet + drawer stack

private struct DrawerCascadeView_Cabinet: View {
    let size: CGSize
    let drawerCount: Int

    /// Demo path: continuous progress already computed per index.
    var demoProgress: ((Int) -> Double)? = nil

    /// Interactive path: a per-index spring delay + a target (0/1) the panel animates toward.
    var perDrawerDelay: ((Int) -> Double)? = nil
    var targetProgress: ((Int) -> Double)? = nil

    init(size: CGSize,
         drawerCount: Int,
         demoProgress: @escaping (Int) -> Double) {
        self.size = size
        self.drawerCount = drawerCount
        self.demoProgress = demoProgress
    }

    init(size: CGSize,
         drawerCount: Int,
         perDrawerDelay: @escaping (Int) -> Double,
         targetProgress: @escaping (Int) -> Double) {
        self.size = size
        self.drawerCount = drawerCount
        self.perDrawerDelay = perDrawerDelay
        self.targetProgress = targetProgress
    }

    private var inset: CGFloat { size.width * 0.10 }
    private var cabinetWidth: CGFloat { size.width - inset * 2 }
    private var cabinetHeight: CGFloat { size.height - inset * 2 }
    private var corner: CGFloat { max(size.width * 0.06, 6) }

    private var slotGap: CGFloat { cabinetHeight * 0.04 }
    private var drawerHeight: CGFloat {
        let gaps = slotGap * CGFloat(drawerCount + 1)
        return (cabinetHeight - gaps) / CGFloat(drawerCount)
    }
    private var drawerWidth: CGFloat { cabinetWidth * 0.82 }

    /// Maximum horizontal pull for a given index — lower drawers pull further.
    private func maxPull(for index: Int) -> CGFloat {
        let base = cabinetWidth * 0.16
        let step = cabinetWidth * 0.052
        return base + step * CGFloat(index)
    }

    var body: some View {
        ZStack {
            DrawerCascadeView_CabinetShell(corner: corner)
                .frame(width: cabinetWidth, height: cabinetHeight)

            DrawerCascadeView_DrawerColumn(
                size: size,
                drawerCount: drawerCount,
                drawerWidth: drawerWidth,
                drawerHeight: drawerHeight,
                slotGap: slotGap,
                cabinetHeight: cabinetHeight,
                corner: corner * 0.7,
                maxPull: maxPull,
                demoProgress: demoProgress,
                perDrawerDelay: perDrawerDelay,
                targetProgress: targetProgress
            )
            .frame(width: cabinetWidth, height: cabinetHeight)
        }
        .frame(width: size.width, height: size.height)
    }
}

private struct DrawerCascadeView_CabinetShell: View {
    let corner: CGFloat

    private var bodyColor: Color { Color(red: 0.10, green: 0.12, blue: 0.17) }
    private var frameTop: Color { Color(red: 0.18, green: 0.21, blue: 0.28) }
    private var frameBottom: Color { Color(red: 0.07, green: 0.08, blue: 0.12) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [frameTop, frameBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(Color(red: 0.30, green: 0.34, blue: 0.44).opacity(0.7),
                              lineWidth: 1)
            // Interior cavity — the dark space the drawers reveal.
            RoundedRectangle(cornerRadius: corner * 0.8, style: .continuous)
                .fill(bodyColor)
                .padding(corner * 0.55)
        }
    }
}

private struct DrawerCascadeView_DrawerColumn: View {
    let size: CGSize
    let drawerCount: Int
    let drawerWidth: CGFloat
    let drawerHeight: CGFloat
    let slotGap: CGFloat
    let cabinetHeight: CGFloat
    let corner: CGFloat
    let maxPull: (Int) -> CGFloat

    var demoProgress: ((Int) -> Double)?
    var perDrawerDelay: ((Int) -> Double)?
    var targetProgress: ((Int) -> Double)?

    var body: some View {
        // Top drawer (index 0) is highest in the stack; deeper drawers (higher index)
        // are drawn later so they layer above when pulled — biggest shadow on top.
        ZStack {
            ForEach(0..<drawerCount, id: \.self) { index in
                panel(index: index)
            }
        }
        .frame(width: drawerWidth, height: cabinetHeight, alignment: .center)
    }

    private func yOffset(for index: Int) -> CGFloat {
        let totalDrawerSpan = drawerHeight * CGFloat(drawerCount)
            + slotGap * CGFloat(drawerCount - 1)
        let top = -totalDrawerSpan / 2 + drawerHeight / 2
        return top + CGFloat(index) * (drawerHeight + slotGap)
    }

    @ViewBuilder
    private func panel(index: Int) -> some View {
        let reveal = DrawerCascadeView_RevealSlot(
            width: drawerWidth,
            height: drawerHeight,
            corner: corner
        )
        .offset(y: yOffset(for: index))

        let drawer = drawerView(index: index)

        ZStack {
            reveal
            drawer
        }
    }

    @ViewBuilder
    private func drawerView(index: Int) -> some View {
        if let demoProgress {
            let p = CGFloat(demoProgress(index))
            DrawerCascadeView_DrawerPanel(
                index: index,
                width: drawerWidth,
                height: drawerHeight,
                corner: corner,
                pull: maxPull(index) * p,
                openness: p
            )
            .offset(y: yOffset(for: index))
        } else if let target = targetProgress, let delay = perDrawerDelay {
            DrawerCascadeView_AnimatedDrawer(
                index: index,
                width: drawerWidth,
                height: drawerHeight,
                corner: corner,
                maxPull: maxPull(index),
                yOffset: yOffset(for: index),
                target: CGFloat(target(index)),
                delay: delay(index)
            )
        }
    }
}

/// Interactive wrapper: animates its own progress toward `target` with a per-index
/// spring delay so a single isOpen toggle still cascades.
private struct DrawerCascadeView_AnimatedDrawer: View {
    let index: Int
    let width: CGFloat
    let height: CGFloat
    let corner: CGFloat
    let maxPull: CGFloat
    let yOffset: CGFloat
    let target: CGFloat
    let delay: Double

    var body: some View {
        DrawerCascadeView_DrawerPanel(
            index: index,
            width: width,
            height: height,
            corner: corner,
            pull: maxPull * target,
            openness: target
        )
        .offset(y: yOffset)
        .animation(
            .spring(response: 0.55, dampingFraction: 0.76).delay(delay),
            value: target
        )
    }
}

/// The dark recessed slot a drawer sits in; visible (revealed) once the drawer slides out.
private struct DrawerCascadeView_RevealSlot: View {
    let width: CGFloat
    let height: CGFloat
    let corner: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.06, blue: 0.09),
                        Color(red: 0.02, green: 0.02, blue: 0.04)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                // A hint of "contents" inside the cabinet behind the drawer.
                RoundedRectangle(cornerRadius: corner * 0.7, style: .continuous)
                    .fill(Color(red: 0.16, green: 0.45, blue: 0.62).opacity(0.28))
                    .padding(.horizontal, width * 0.06)
                    .padding(.vertical, height * 0.22)
            )
            .frame(width: width, height: height)
    }
}

/// One drawer face. `pull` is the horizontal slide-out distance (always >= 0),
/// `openness` (0…1) drives shadow depth, handle highlight, and edge shading.
private struct DrawerCascadeView_DrawerPanel: View {
    let index: Int
    let width: CGFloat
    let height: CGFloat
    let corner: CGFloat
    let pull: CGFloat
    let openness: CGFloat

    private var faceTop: Color { Color(red: 0.34, green: 0.40, blue: 0.52) }
    private var faceBottom: Color { Color(red: 0.20, green: 0.24, blue: 0.33) }
    private var edgeColor: Color { Color(red: 0.46, green: 0.53, blue: 0.66) }

    // Deeper drawers cast heavier shadows; the pull amount deepens it further.
    private var shadowRadius: CGFloat {
        let base: CGFloat = 1.5
        let perIndex: CGFloat = 1.4
        let perOpen: CGFloat = 9.0
        return base + perIndex * CGFloat(index) + perOpen * openness
    }

    private var shadowYOffset: CGFloat {
        2.0 + 4.0 * openness + CGFloat(index)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [faceTop, faceBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(topSheen)
            .overlay(handle)
            .overlay(leadingEdge)
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(edgeColor.opacity(0.55), lineWidth: 0.8)
            )
            .frame(width: width, height: height)
            .shadow(
                color: Color.black.opacity(0.35 + 0.30 * Double(openness)),
                radius: shadowRadius,
                x: -shadowRadius * 0.35,
                y: shadowYOffset
            )
            .offset(x: pull)
    }

    // Soft highlight across the top of the drawer face.
    private var topSheen: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.18),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
            )
    }

    // Pill handle, centered; brightens slightly as the drawer opens.
    private var handle: some View {
        Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.62, green: 0.70, blue: 0.84)
                            .opacity(0.75 + 0.25 * Double(openness)),
                        Color(red: 0.30, green: 0.36, blue: 0.47)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: width * 0.30, height: max(height * 0.16, 3))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(0.30), lineWidth: 0.6)
            )
    }

    // The leading (right) edge picks up a brighter rim as it emerges from the cabinet.
    private var leadingEdge: some View {
        HStack {
            Spacer()
            RoundedRectangle(cornerRadius: corner * 0.5, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            edgeColor.opacity(0.0),
                            edgeColor.opacity(0.55 * Double(openness) + 0.10)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width * 0.10)
        }
        .padding(2)
    }
}
