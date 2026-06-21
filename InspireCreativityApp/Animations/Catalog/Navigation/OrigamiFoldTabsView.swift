// catalog-id: nav-origami-fold-tabs
import SwiftUI

/// Origami Fold Tabs — a tab bar built from paper panels.
///
/// Tapping a tab folds the strip inward along two crease lines, the chosen
/// icon pops forward off the page with a soft shadow, then the strip unfolds
/// flat again. The fold is a transient *pulse* (0 → peak → 0) on every switch,
/// not an end-state — at rest the bar lies flat with a persistent selection
/// indicator under the active tab.
///
/// - `demo == true`  : a self-driving loop auto-advances through the tabs,
///                     replaying the full crease-in → icon-pop → unfold cycle.
/// - `demo == false` : tap a tab; a KeyframeAnimator pulses the fold and
///                     commits the new selection at the peak of the crease.
struct OrigamiFoldTabsView: View {
    var demo: Bool = false

    // Persistent selection (the tab that stays highlighted at rest).
    @State private var selectedTab: Int = 0
    // The index whose fold pulse is currently playing (the icon that pops).
    @State private var activeTab: Int = 0

    private let tabCount: Int = 4

    var body: some View {
        GeometryReader { geo in
            if demo {
                demoStrip(geo: geo)
            } else {
                interactiveStrip(geo: geo)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Demo (self-driving)

    @ViewBuilder
    private func demoStrip(geo: GeometryProxy) -> some View {
        // Period per tab; one full crease pulse plays inside each period.
        let period: Double = 1.3
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = t / period
            let index = Int(floor(phase)) % tabCount
            let local = phase - floor(phase)            // 0..<1 within this tab
            let fold = pulse(local)                     // 0 → 1 → 0 envelope

            strip(geo: geo, selected: index, popped: index, foldProgress: fold)
        }
    }

    // MARK: - Interactive (tap-driven)

    @ViewBuilder
    private func interactiveStrip(geo: GeometryProxy) -> some View {
        // KeyframeAnimator re-keys on `activeTab`; the fold track pulses
        // 0 → peak → 0 each time a tab is tapped.
        KeyframeAnimator(initialValue: CGFloat(0.0), trigger: activeTab) { fold in
            strip(geo: geo,
                  selected: selectedTab,
                  popped: activeTab,
                  foldProgress: fold)
        } keyframes: { _ in
            KeyframeTrack(\CGFloat.self) {
                SpringKeyframe(1.0, duration: 0.26, spring: .init(duration: 0.26, bounce: 0.30))
                SpringKeyframe(0.0, duration: 0.30, spring: .init(duration: 0.30, bounce: 0.22))
            }
        }
    }

    // MARK: - Shared strip (identical render for demo + interactive)

    /// The whole control. `selected` drives the persistent highlight,
    /// `popped` is the icon that lifts forward, `foldProgress` is the 0→1→0 pulse.
    @ViewBuilder
    private func strip(geo: GeometryProxy,
                       selected: Int,
                       popped: Int,
                       foldProgress: CGFloat) -> some View {
        let size = geo.size
        let slotW: CGFloat = size.width / CGFloat(tabCount)
        // Strip is centred vertically and sized to leave breathing room in a tile.
        let stripH: CGFloat = min(size.height * 0.62, slotW * 1.15)
        let stripW: CGFloat = size.width
        let stripY: CGFloat = size.height / 2

        ZStack {
            paperBackdrop(width: stripW, height: stripH)
                .position(x: size.width / 2, y: stripY)

            // The creasing two-panel base layer.
            foldingPanels(slotW: slotW,
                          stripH: stripH,
                          stripW: stripW,
                          selected: selected,
                          foldProgress: foldProgress)
                .position(x: size.width / 2, y: stripY)

            // The chosen icon, lifted forward on its own layer.
            poppingIcon(slotW: slotW,
                        stripH: stripH,
                        popped: popped,
                        foldProgress: foldProgress)
                .position(x: slotCenterX(index: popped, slotW: slotW),
                          y: stripY)
        }
        .compositingGroup()
        .contentShape(Rectangle())
        .modifier(OrigamiFoldTabsView_TapTabs(enabled: !demo, tabCount: tabCount, slotW: slotW) { idx in
            selectTab(idx)
        })
    }

    // MARK: - Layers

    private func paperBackdrop(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height * 0.22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [paperLight, paperDark],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: height * 0.22, style: .continuous)
                    .stroke(creaseLine.opacity(0.30), lineWidth: 1)
            )
            .frame(width: width, height: height)
            .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 4)
    }

    /// Two HStacks creased toward the centre line via mirrored rotation3DEffect.
    @ViewBuilder
    private func foldingPanels(slotW: CGFloat,
                               stripH: CGFloat,
                               stripW: CGFloat,
                               selected: Int,
                               foldProgress: CGFloat) -> some View {
        // Modest angle so the demo never collapses to a line. Spec: cap perspective.
        let creaseAngle: Double = 34.0 * Double(foldProgress)
        let halfCount: Int = tabCount / 2
        let perspective: CGFloat = 0.6

        HStack(spacing: 0) {
            // Left half — hinges on its LEADING edge, folds back to the right.
            panelRow(range: 0..<halfCount,
                     slotW: slotW, stripH: stripH,
                     selected: selected, foldProgress: foldProgress)
                .rotation3DEffect(.degrees(creaseAngle),
                                  axis: (x: 0, y: 1, z: 0),
                                  anchor: .leading,
                                  perspective: perspective)
                .brightness(-0.10 * Double(foldProgress))

            // Right half — hinges on its TRAILING edge, folds back to the left.
            panelRow(range: halfCount..<tabCount,
                     slotW: slotW, stripH: stripH,
                     selected: selected, foldProgress: foldProgress)
                .rotation3DEffect(.degrees(-creaseAngle),
                                  axis: (x: 0, y: 1, z: 0),
                                  anchor: .trailing,
                                  perspective: perspective)
                .brightness(-0.10 * Double(foldProgress))
        }
        .frame(width: stripW, height: stripH)
        // Centre crease shading: darkens as the bar folds in.
        .overlay(centerCrease(height: stripH, foldProgress: foldProgress))
    }

    /// A contiguous row of base tab slots (icons sit flat here; the popped one
    /// is hidden because its forward-lifted copy renders in the overlay).
    @ViewBuilder
    private func panelRow(range: Range<Int>,
                          slotW: CGFloat,
                          stripH: CGFloat,
                          selected: Int,
                          foldProgress: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(range, id: \.self) { idx in
                tabSlot(index: idx,
                        slotW: slotW,
                        stripH: stripH,
                        selected: selected,
                        foldProgress: foldProgress)
            }
        }
    }

    private func tabSlot(index: Int,
                         slotW: CGFloat,
                         stripH: CGFloat,
                         selected: Int,
                         foldProgress: CGFloat) -> some View {
        let isSelected = index == selected
        // The base copy of the popping icon fades out as it lifts forward.
        let baseIconOpacity: Double = isSelected ? (1.0 - 0.85 * Double(foldProgress)) : 0.55
        let iconSize: CGFloat = stripH * 0.34

        return VStack(spacing: stripH * 0.10) {
            Image(systemName: symbolName(index))
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(isSelected ? accent : ink.opacity(0.65))
                .opacity(baseIconOpacity)

            // Persistent selection dot — independent of the fold pulse.
            Capsule()
                .fill(accent)
                .frame(width: isSelected ? slotW * 0.30 : 0,
                       height: stripH * 0.055)
                .opacity(isSelected ? 1 : 0)
        }
        .frame(width: slotW, height: stripH)
        .contentShape(Rectangle())
    }

    /// The selected icon lifted toward the viewer with a soft tracking shadow.
    @ViewBuilder
    private func poppingIcon(slotW: CGFloat,
                             stripH: CGFloat,
                             popped: Int,
                             foldProgress: CGFloat) -> some View {
        let iconSize: CGFloat = stripH * 0.34
        let lift: CGFloat = foldProgress              // 0..1
        let scale: CGFloat = 1.0 + 0.42 * lift
        let forwardAngle: Double = -26.0 * Double(lift)   // tilt toward viewer
        let shadowRadius: CGFloat = 2 + 12 * lift
        let shadowY: CGFloat = 2 + 9 * lift

        Image(systemName: symbolName(popped))
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(accent)
            .scaleEffect(scale)
            .rotation3DEffect(.degrees(forwardAngle),
                              axis: (x: 1, y: 0, z: 0),
                              anchor: .bottom,
                              perspective: 0.5)
            .shadow(color: .black.opacity(0.35 * Double(lift)),
                    radius: shadowRadius, x: 0, y: shadowY)
            // Never fully invisible — at rest it sits flush on the base icon.
            .opacity(0.15 + 0.85 * Double(lift) + 0.001)
    }

    private func centerCrease(height: CGFloat, foldProgress: CGFloat) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        creaseLine.opacity(0.0),
                        creaseLine.opacity(0.45 * Double(foldProgress)),
                        creaseLine.opacity(0.0)
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .frame(width: height * 0.10, height: height)
            .blur(radius: 1)
            .allowsHitTesting(false)
    }

    // MARK: - Logic

    private func selectTab(_ idx: Int) {
        guard idx != selectedTab || idx != activeTab else { return }
        // Commit the persistent selection up front so the dot is correct, then
        // re-key the fold pulse via `activeTab` to play the crease flourish.
        selectedTab = idx
        activeTab = idx
    }

    /// 0 → 1 → 0 envelope across a normalised local time `u` in [0, 1).
    private func pulse(_ u: Double) -> CGFloat {
        // sin gives a smooth bloom that returns to flat and holds near 0 at the
        // tail so the bar reads clearly flat before the next tab fires.
        let eased = sin(min(max(u, 0), 1) * .pi)
        return CGFloat(eased * eased)   // sharpen the peak slightly
    }

    private func slotCenterX(index: Int, slotW: CGFloat) -> CGFloat {
        slotW * (CGFloat(index) + 0.5)
    }

    private func symbolName(_ index: Int) -> String {
        let names = ["house.fill", "magnifyingglass", "heart.fill", "person.fill"]
        return names[index % names.count]
    }

    // MARK: - Palette (literal colors — no app dependencies)

    private var paperLight: Color { Color(red: 0.97, green: 0.96, blue: 0.93) }
    private var paperDark: Color  { Color(red: 0.90, green: 0.88, blue: 0.83) }
    private var ink: Color        { Color(red: 0.18, green: 0.20, blue: 0.24) }
    private var accent: Color     { Color(red: 0.91, green: 0.36, blue: 0.27) }
    private var creaseLine: Color { Color(red: 0.45, green: 0.42, blue: 0.38) }
}

// MARK: - Tap routing

/// Maps a tap's x position to a tab index. Kept as a modifier so the shared
/// `strip` renders identically in demo (disabled) and interactive (enabled).
private struct OrigamiFoldTabsView_TapTabs: ViewModifier {
    let enabled: Bool
    let tabCount: Int
    let slotW: CGFloat
    let onSelect: (Int) -> Void

    func body(content: Content) -> some View {
        if enabled {
            content.gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        let raw = Int(value.location.x / max(slotW, 1))
                        let idx = min(max(raw, 0), tabCount - 1)
                        onSelect(idx)
                    }
            )
        } else {
            content
        }
    }
}
