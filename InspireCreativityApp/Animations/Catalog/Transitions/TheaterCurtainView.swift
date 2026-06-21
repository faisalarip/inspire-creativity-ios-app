// catalog-id: tr-theater-curtain
import SwiftUI

// MARK: - Theater Curtain
// Two gathered velvet curtain panels, drawn as pleated Animatable Shapes,
// draw apart from the center to reveal the stage behind.
//   demo == true  -> a PhaseAnimator loops openFraction 0 -> 1 -> 0.
//   demo == false -> tap toggles the curtain open / closed with a spring.

struct TheaterCurtainView: View {
    var demo: Bool = false

    @State private var isOpen: Bool = false

    var body: some View {
        GeometryReader { proxy in
            content(size: proxy.size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    @ViewBuilder
    private func content(size: CGSize) -> some View {
        if demo {
            PhaseAnimator([CGFloat(0.0), CGFloat(1.0)]) { open in
                stage(size: size, open: open)
            } animation: { _ in
                .spring(response: 1.5, dampingFraction: 0.78)
            }
        } else {
            stage(size: size, open: isOpen ? 1.0 : 0.0)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.7, dampingFraction: 0.72)) {
                        isOpen.toggle()
                    }
                }
        }
    }

    // MARK: - Stage (backdrop + two curtain panels)

    private func stage(size: CGSize, open: CGFloat) -> some View {
        ZStack {
            TheaterCurtainView_StageBackdrop(open: open)

            TheaterCurtainView_CurtainPanel(openFraction: open, side: .leading, size: size)
            TheaterCurtainView_CurtainPanel(openFraction: open, side: .trailing, size: size)
        }
    }
}

// MARK: - Stage backdrop

private struct TheaterCurtainView_StageBackdrop: View {
    var open: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                // Deep stage floor.
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.04, blue: 0.07),
                        Color(red: 0.10, green: 0.07, blue: 0.11),
                        Color(red: 0.04, green: 0.03, blue: 0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Warm follow-spot that blooms brighter as the reveal happens.
                RadialGradient(
                    colors: [
                        Color(red: 1.0, green: 0.92, blue: 0.74).opacity(0.55 * Double(open) + 0.10),
                        Color(red: 0.95, green: 0.78, blue: 0.50).opacity(0.20 * Double(open)),
                        .clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.42),
                    startRadius: 2,
                    endRadius: max(size.width, size.height) * 0.62
                )

                // Floorboard glow line for a hint of depth.
                LinearGradient(
                    colors: [.clear, Color(red: 0.55, green: 0.40, blue: 0.22).opacity(0.30 * Double(open))],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }
        }
    }
}

// MARK: - One curtain panel

private struct TheaterCurtainView_CurtainPanel: View {
    enum Side { case leading, trailing }

    var openFraction: CGFloat
    var side: Side
    var size: CGSize

    var body: some View {
        let shape = TheaterCurtainView_CurtainPanelShape(openFraction: openFraction)
        panelBody(shape: shape)
            // Mirror the trailing panel so the pair is symmetric about the center.
            .scaleEffect(x: side == .trailing ? -1 : 1, y: 1, anchor: .center)
    }

    @ViewBuilder
    private func panelBody(shape: TheaterCurtainView_CurtainPanelShape) -> some View {
        ZStack {
            // Velvet body: horizontal multi-stop gradient -> folds bunch as the
            // shape narrows on opening.
            LinearGradient(
                stops: TheaterCurtainView_VelvetPalette.stops(),
                startPoint: .leading,
                endPoint: .trailing
            )
            .clipShape(shape)

            // Vertical depth shading: darker at top (under the valance) and toward hem.
            LinearGradient(
                colors: [
                    Color.black.opacity(0.32),
                    Color.clear,
                    Color.black.opacity(0.10),
                    Color.black.opacity(0.30)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(shape)
            .blendMode(.multiply)

            // Moving sheen riding across the folds.
            TheaterCurtainView_SheenOverlay(openFraction: openFraction)
                .clipShape(shape)
                .blendMode(.screen)

            // Crisp inner-edge highlight where the gathered fabric catches light.
            shape
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.86, blue: 0.74).opacity(0.0),
                            Color(red: 1.0, green: 0.88, blue: 0.76).opacity(0.45),
                            Color(red: 1.0, green: 0.86, blue: 0.74).opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.2
                )
        }
        .compositingGroup()
        .shadow(
            color: Color.black.opacity(0.45),
            radius: 10 + 8 * openFraction,
            x: 6 + 8 * openFraction,
            y: 4
        )
    }
}

// MARK: - Velvet palette

private enum TheaterCurtainView_VelvetPalette {
    // Alternating darker / lighter velvet reds. A fixed set of stops means the
    // folds compress automatically as the clipped shape narrows.
    static func stops() -> [Gradient.Stop] {
        let deep = Color(red: 0.34, green: 0.03, blue: 0.07)
        let mid = Color(red: 0.58, green: 0.07, blue: 0.12)
        let bright = Color(red: 0.78, green: 0.16, blue: 0.21)
        let shadow = Color(red: 0.22, green: 0.02, blue: 0.05)

        var result: [Gradient.Stop] = []
        let foldCount: Int = 9
        for index in 0...foldCount {
            let location = CGFloat(index) / CGFloat(foldCount)
            let phase = index % 2 == 0
            let crest = index % 3 == 0
            let color: Color = crest ? bright : (phase ? deep : mid)
            result.append(Gradient.Stop(color: color, location: location))
            // Tuck a thin shadow line at each fold valley.
            if index < foldCount {
                let valley = location + (0.5 / CGFloat(foldCount))
                result.append(Gradient.Stop(color: shadow, location: valley))
            }
        }
        return result
    }
}

// MARK: - Moving sheen

private struct TheaterCurtainView_SheenOverlay: View {
    var openFraction: CGFloat

    var body: some View {
        // A diagonal band of light that drifts across the panel as it gathers.
        let travel: CGFloat = -0.4 + 1.4 * openFraction
        LinearGradient(
            colors: [
                Color.clear,
                Color(red: 1.0, green: 0.95, blue: 0.85).opacity(0.0),
                Color(red: 1.0, green: 0.96, blue: 0.88).opacity(0.35),
                Color(red: 1.0, green: 0.95, blue: 0.85).opacity(0.0),
                Color.clear
            ],
            startPoint: UnitPoint(x: travel - 0.25, y: 0.0),
            endPoint: UnitPoint(x: travel + 0.25, y: 1.0)
        )
    }
}

// MARK: - Animatable curtain shape

private struct TheaterCurtainView_CurtainPanelShape: Shape {
    var openFraction: CGFloat

    var animatableData: CGFloat {
        get { openFraction }
        set { openFraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let clamped = min(max(openFraction, 0), 1)

        // The leading panel covers the left half when closed. As it opens it
        // narrows toward the left edge but never collapses past a bunched floor.
        let halfWidth = rect.width / 2.0
        let minWidth = halfWidth * 0.16           // bunched velvet floor — never blank
        let panelWidth = minWidth + (halfWidth - minWidth) * (1.0 - clamped)

        let left = rect.minX
        let topY = rect.minY
        let bottomY = rect.maxY

        // Scalloped inner edge: a fixed number of vertical scallops so the
        // wavelength compresses for free as panelWidth shrinks.
        let innerBase = left + panelWidth
        let scallopCount: Int = 7
        let scallopDepth = panelWidth * (0.10 + 0.16 * clamped)

        // Bottom hem: sine pleats, fixed count -> bunches as the panel narrows.
        let hemCount: Int = 8
        let hemRise = rect.height * (0.02 + 0.07 * clamped)

        // --- Top edge: straight under the valance.
        path.move(to: CGPoint(x: left, y: topY))
        path.addLine(to: CGPoint(x: innerBase, y: topY))

        // --- Inner (right) edge: scalloped, gathering inward as it opens.
        let innerSteps: Int = scallopCount * 6
        for step in 0...innerSteps {
            let t = CGFloat(step) / CGFloat(innerSteps)
            let y = topY + t * (bottomY - topY)
            let wave = sin(t * CGFloat(scallopCount) * .pi * 2.0)
            // Scallops deepen toward the bottom where fabric pools.
            let depthRamp = 0.35 + 0.65 * t
            let x = innerBase - scallopDepth * depthRamp * (0.5 + 0.5 * wave)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        // --- Bottom hem: sine pleats from inner edge back to the left edge.
        let hemSteps: Int = hemCount * 5
        let hemStartX = innerBase - scallopDepth * (0.5)
        for step in 0...hemSteps {
            let t = CGFloat(step) / CGFloat(hemSteps)
            let x = hemStartX + (left - hemStartX) * t
            let wave = sin(t * CGFloat(hemCount) * .pi * 2.0)
            let y = bottomY - hemRise * (0.5 + 0.5 * wave)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        // --- Left edge back up to the start (outer edge stays anchored).
        path.addLine(to: CGPoint(x: left, y: topY))
        path.closeSubpath()

        return path
    }
}
