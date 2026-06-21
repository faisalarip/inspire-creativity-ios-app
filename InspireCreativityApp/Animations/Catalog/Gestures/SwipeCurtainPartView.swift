// catalog-id: ges-swipe-curtain-part
import SwiftUI

// MARK: - SwipeCurtainPartView
// Swipe outward and two heavy fabric curtains part with rippling folds and
// weighted drag, gathering at the edges with bunched pleats to reveal a lit
// content stage. The inner edges ripple with a sine fold; the pleats compress
// and gain contrast as the cloth gathers. demo == true self-drives a theatrical
// open/close loop; demo == false is an interactive DragGesture.
struct SwipeCurtainPartView: View {
    var demo: Bool = false

    // Interactive state: 0 = fully closed, 1 = fully parted.
    @State private var progress: CGFloat = 0
    @State private var dragStartProgress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            if demo {
                demoBody(size: size)
            } else {
                interactiveBody(size: size)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Demo (self-driving)

    private func demoBody(size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let p = Self.loopProgress(time: t)
            // A gentle phase used to ripple the folds while parting, so the
            // cloth looks alive even when fully open or closed.
            let phase = CGFloat((t.truncatingRemainder(dividingBy: 3.4)) / 3.4)
            stageScene(size: size, progress: p, foldPhase: phase)
        }
    }

    /// Eased ping-pong 0 -> 1 -> 0 on a ~3.4s loop with smooth ends.
    static func loopProgress(time: TimeInterval) -> CGFloat {
        let period: TimeInterval = 3.4
        let x = time.truncatingRemainder(dividingBy: period) / period // 0..1
        // Triangle wave 0..1..0
        let tri = x < 0.5 ? (x / 0.5) : (1 - (x - 0.5) / 0.5)
        // Smoothstep for eased ends.
        let e = tri * tri * (3 - 2 * tri)
        return CGFloat(e)
    }

    // MARK: Interactive

    private func interactiveBody(size: CGSize) -> some View {
        stageScene(size: size, progress: progress, foldPhase: 0.18)
            .contentShape(Rectangle())
            .gesture(dragGesture(width: size.width))
    }

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let half = max(width * 0.5, 1)
                // Map outward swipe distance to part-progress. Either direction
                // of horizontal travel opens the curtains.
                let delta = abs(value.translation.width) / half
                let raw = dragStartProgress + delta * 0.85
                progress = min(max(raw, 0), 1)
            }
            .onEnded { _ in
                let target: CGFloat = progress > 0.5 ? 1 : 0
                // Heavier damping conveys cloth weight.
                withAnimation(.spring(duration: 0.6, bounce: 0.15)) {
                    progress = target
                }
                dragStartProgress = target
            }
    }

    // MARK: Scene composition

    private func stageScene(size: CGSize, progress p: CGFloat, foldPhase: CGFloat) -> some View {
        ZStack {
            SwipeCurtainPartView_StageBackdrop(progress: p)
            SwipeCurtainPartView_CurtainPanel(progress: p, foldPhase: foldPhase, side: .left)
            SwipeCurtainPartView_CurtainPanel(progress: p, foldPhase: foldPhase, side: .right)
            SwipeCurtainPartView_ValanceTrim()
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius(for: size), style: .continuous))
    }

    private func cornerRadius(for size: CGSize) -> CGFloat {
        min(size.width, size.height) * 0.10
    }
}

// MARK: - Curtain side

private enum SwipeCurtainPartView_CurtainSide {
    case left, right
}

// MARK: - Animatable curtain shape

/// One half of the stage curtain. Its outer edge is pinned at the wall; its
/// inner edge travels toward the wall as `progress` -> 1, and the inner edge
/// ripples with a sine fold whose amplitude grows as the cloth gathers.
private struct SwipeCurtainPartView_CurtainShape: Shape {
    var progress: CGFloat   // 0 closed, 1 parted
    var foldPhase: CGFloat  // animates the ripple
    var side: SwipeCurtainPartView_CurtainSide

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(progress, foldPhase) }
        set {
            progress = newValue.first
            foldPhase = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let half = w * 0.5

        // Gathered (bunched) width never collapses to zero — keep a heavy strip.
        let bunchWidth = max(w * 0.16, 22)
        let visibleWidth = bunchWidth + (half - bunchWidth) * (1 - progress)

        // Ripple amplitude grows as it gathers; folds deepen near the edge.
        let amp = (w * 0.012) + (w * 0.05) * progress
        let waves: CGFloat = 3.2

        var path = Path()
        let steps = 26

        switch side {
        case .left:
            // Outer edge pinned at x = 0; inner edge near x = visibleWidth.
            let innerBase = visibleWidth
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: innerBase, y: 0))
            for i in 0...steps {
                let frac = CGFloat(i) / CGFloat(steps)
                let y = frac * h
                let wobble = sin(frac * .pi * waves + foldPhase * .pi * 2)
                let x = innerBase + wobble * amp
                path.addLine(to: CGPoint(x: x, y: y))
            }
            path.addLine(to: CGPoint(x: 0, y: h))
            path.closeSubpath()

        case .right:
            let innerBase = w - visibleWidth
            path.move(to: CGPoint(x: w, y: 0))
            path.addLine(to: CGPoint(x: innerBase, y: 0))
            for i in 0...steps {
                let frac = CGFloat(i) / CGFloat(steps)
                let y = frac * h
                let wobble = sin(frac * .pi * waves + foldPhase * .pi * 2)
                let x = innerBase - wobble * amp
                path.addLine(to: CGPoint(x: x, y: y))
            }
            path.addLine(to: CGPoint(x: w, y: h))
            path.closeSubpath()
        }
        return path
    }
}

// MARK: - Curtain panel (fabric + pleats)

private struct SwipeCurtainPartView_CurtainPanel: View {
    var progress: CGFloat
    var foldPhase: CGFloat
    var side: SwipeCurtainPartView_CurtainSide

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            SwipeCurtainPartView_CurtainShape(progress: progress, foldPhase: foldPhase, side: side)
                .fill(baseGradient)
                .overlay {
                    SwipeCurtainPartView_PleatOverlay(progress: progress, side: side)
                        .clipShape(SwipeCurtainPartView_CurtainShape(progress: progress, foldPhase: foldPhase, side: side))
                }
                .overlay {
                    // Soft inner-edge shadow that deepens as cloth gathers.
                    SwipeCurtainPartView_CurtainShape(progress: progress, foldPhase: foldPhase, side: side)
                        .fill(edgeShade(width: size.width))
                }
                .shadow(color: .black.opacity(0.45), radius: 8, x: shadowX, y: 4)
        }
        .allowsHitTesting(false)
    }

    private var shadowX: CGFloat {
        let mag: CGFloat = 6
        return side == .left ? mag : -mag
    }

    // Deep theatrical red velvet.
    private var baseGradient: LinearGradient {
        let dark = Color(red: 0.32, green: 0.04, blue: 0.07)
        let mid = Color(red: 0.58, green: 0.09, blue: 0.13)
        let bright = Color(red: 0.72, green: 0.13, blue: 0.18)
        let stops: [Gradient.Stop]
        switch side {
        case .left:
            stops = [
                .init(color: dark, location: 0.0),
                .init(color: mid, location: 0.55),
                .init(color: bright, location: 1.0)
            ]
        case .right:
            stops = [
                .init(color: bright, location: 0.0),
                .init(color: mid, location: 0.45),
                .init(color: dark, location: 1.0)
            ]
        }
        return LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
    }

    private func edgeShade(width: CGFloat) -> LinearGradient {
        let intensity = 0.20 + 0.35 * Double(progress)
        let shadow = Color.black.opacity(intensity)
        let clear = Color.black.opacity(0)
        switch side {
        case .left:
            return LinearGradient(
                stops: [
                    .init(color: clear, location: 0.55),
                    .init(color: shadow, location: 1.0)
                ],
                startPoint: .leading, endPoint: .trailing
            )
        case .right:
            return LinearGradient(
                stops: [
                    .init(color: shadow, location: 0.0),
                    .init(color: clear, location: 0.45)
                ],
                startPoint: .leading, endPoint: .trailing
            )
        }
    }
}

// MARK: - Pleat overlay
// Vertical light/shadow stripes that read as cloth folds. They compress
// horizontally and gain contrast as the curtain gathers (progress -> 1).
private struct SwipeCurtainPartView_PleatOverlay: View {
    var progress: CGFloat
    var side: SwipeCurtainPartView_CurtainSide

    private let pleatCount = 9

    var body: some View {
        Canvas { context, size in
            draw(into: &context, size: size)
        }
    }

    private func draw(into context: inout GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        // As progress grows the pleats crowd toward the gathering edge.
        let compression = 1 - 0.62 * progress
        let usable = w * compression
        // Anchor the pleat field at the gathering edge: the left curtain
        // gathers at the left wall (x = 0), the right curtain at the right wall.
        let originX: CGFloat = side == .left ? 0 : (w - usable)

        let contrast = 0.18 + 0.42 * progress
        let bandWidth = usable / CGFloat(pleatCount)
        guard bandWidth > 0 else { return }

        for i in 0..<pleatCount {
            let x0 = originX + CGFloat(i) * bandWidth
            let phaseShade = sin(CGFloat(i) / CGFloat(pleatCount) * .pi * 2)
            // Alternate highlight/shadow per band for fold relief.
            let isHighlight = (i % 2 == 0)
            let baseOpacity = contrast * (0.6 + 0.4 * abs(phaseShade))
            let stripe = Path(CGRect(x: x0, y: 0, width: bandWidth, height: h))
            if isHighlight {
                context.fill(stripe, with: .color(.white.opacity(baseOpacity * 0.5)))
            } else {
                context.fill(stripe, with: .color(.black.opacity(baseOpacity)))
            }
            // Thin crease line at each band boundary.
            var crease = Path()
            crease.move(to: CGPoint(x: x0, y: 0))
            crease.addLine(to: CGPoint(x: x0, y: h))
            context.stroke(crease, with: .color(.black.opacity(0.18 + 0.2 * progress)), lineWidth: 0.75)
        }
    }
}

// MARK: - Stage backdrop (the revealed content)

private struct SwipeCurtainPartView_StageBackdrop: View {
    var progress: CGFloat

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                // Dark stage floor + warm rear wall.
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.04, blue: 0.09),
                        Color(red: 0.12, green: 0.09, blue: 0.16)
                    ],
                    startPoint: .top, endPoint: .bottom
                )

                // Warm spotlight that brightens as the curtains part.
                RadialGradient(
                    colors: [
                        Color(red: 1.0, green: 0.86, blue: 0.55).opacity(0.85 * Double(progress) + 0.08),
                        Color(red: 1.0, green: 0.78, blue: 0.40).opacity(0.0)
                    ],
                    center: .init(x: 0.5, y: 0.42),
                    startRadius: 2,
                    endRadius: max(size.width, size.height) * 0.62
                )

                spotlightStar(size: size)
            }
        }
    }

    // A glowing star at center stage — legible "content" being revealed.
    private func spotlightStar(size: CGSize) -> some View {
        let s = min(size.width, size.height)
        let scale = 0.55 + 0.45 * progress
        return SwipeCurtainPartView_Star(points: 5, inset: 0.45)
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 1.0, green: 0.95, blue: 0.7),
                        Color(red: 1.0, green: 0.78, blue: 0.32)
                    ],
                    center: .center, startRadius: 1, endRadius: s * 0.22
                )
            )
            .frame(width: s * 0.34, height: s * 0.34)
            .scaleEffect(scale)
            .shadow(color: Color(red: 1.0, green: 0.8, blue: 0.4).opacity(0.7 * Double(progress)),
                    radius: 14 * progress)
            .opacity(0.25 + 0.75 * Double(progress))
            .position(x: size.width * 0.5, y: size.height * 0.46)
    }
}

// MARK: - Valance (top fabric trim)

private struct SwipeCurtainPartView_ValanceTrim: View {
    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let h = size.height * 0.16
            ZStack(alignment: .top) {
                SwipeCurtainPartView_Scallop(scallops: 6)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.5, green: 0.07, blue: 0.11),
                                Color(red: 0.34, green: 0.04, blue: 0.07)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(height: h)
                    .shadow(color: .black.opacity(0.4), radius: 5, y: 3)
            }
            .frame(width: size.width, height: size.height, alignment: .top)
        }
        .allowsHitTesting(false)
    }
}

private struct SwipeCurtainPartView_Scallop: Shape {
    var scallops: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: w, y: 0))
        path.addLine(to: CGPoint(x: w, y: h * 0.4))
        let bumpWidth = w / CGFloat(scallops)
        var x = w
        for i in 0..<scallops {
            let nextX = w - CGFloat(i + 1) * bumpWidth
            let midX = (x + nextX) / 2
            path.addQuadCurve(
                to: CGPoint(x: nextX, y: h * 0.4),
                control: CGPoint(x: midX, y: h)
            )
            x = nextX
        }
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.closeSubpath()
        return path
    }
}

// MARK: - SwipeCurtainPartView_Star shape

private struct SwipeCurtainPartView_Star: Shape {
    var points: Int
    var inset: CGFloat // 0..1 inner radius ratio

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * inset
        let total = points * 2
        for i in 0..<total {
            let isOuter = (i % 2 == 0)
            let r = isOuter ? outer : inner
            let angle = (CGFloat(i) / CGFloat(total)) * .pi * 2 - .pi / 2
            let pt = CGPoint(x: center.x + cos(angle) * r,
                             y: center.y + sin(angle) * r)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}
