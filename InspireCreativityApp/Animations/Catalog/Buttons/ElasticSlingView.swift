// catalog-id: btn-elastic-sling
import SwiftUI

// MARK: - Elastic Sling
// Drag the button backward like a slingshot; a rubber band stretches between two
// fixed anchors and the band thins + tints with tension. On release the button
// flings forward, snaps taut with an interpolatingSpring twang, and fires.

private enum ElasticSlingView_ElasticSlingPhase: CaseIterable {
    case rest
    case loaded
    case fired

    // Normalized pull vector for this phase.
    // x in [-1, 1] (sideways nudge), y in [-1, 1] (positive = drawn back/down).
    var normalizedPull: CGSize {
        switch self {
        case .rest:   return CGSize(width: 0.0, height: 0.0)
        case .loaded: return CGSize(width: -0.18, height: 1.0)
        case .fired:  return CGSize(width: 0.06, height: -0.30)
        }
    }
}

struct ElasticSlingView: View {
    var demo: Bool = false

    // Interactive state.
    @State private var dragPull: CGSize = .zero
    @State private var fireTick: Int = 0

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            content(in: size)
                .frame(width: size.width, height: size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if demo {
            demoContent(in: size)
        } else {
            interactiveContent(in: size)
        }
    }

    // MARK: Demo (self-driving loop)

    @ViewBuilder
    private func demoContent(in size: CGSize) -> some View {
        PhaseAnimator(ElasticSlingView_ElasticSlingPhase.allCases) { phase in
            slingCore(pull: phasePull(phase, in: size), in: size)
        } animation: { phase in
            phaseAnimation(for: phase)
        }
    }

    // Convert a phase's normalized pull into an absolute pull vector for this size.
    private func phasePull(_ phase: ElasticSlingView_ElasticSlingPhase, in size: CGSize) -> CGSize {
        let n = phase.normalizedPull
        let maxBack: CGFloat = size.height * 0.34
        let maxSide: CGFloat = size.width * 0.22
        return CGSize(width: n.width * maxSide, height: n.height * maxBack)
    }

    private func phaseAnimation(for phase: ElasticSlingView_ElasticSlingPhase) -> Animation {
        switch phase {
        case .rest:
            // Settle gently back to neutral after the twang.
            return .easeOut(duration: 0.55)
        case .loaded:
            // Slow, deliberate draw-back (loading the band).
            return .easeInOut(duration: 1.1)
        case .fired:
            // The launch: snappy, slightly overshooting twang.
            return .interpolatingSpring(stiffness: 280, damping: 9)
        }
    }

    // MARK: Interactive (real component)

    @ViewBuilder
    private func interactiveContent(in size: CGSize) -> some View {
        let maxBack: CGFloat = size.height * 0.34
        let maxSide: CGFloat = size.width * 0.22

        slingCore(pull: dragPull, in: size)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let backward = max(0.0, value.translation.height)
                        let clampedY = min(backward, maxBack)
                        let clampedX = clamp(value.translation.width, limit: maxSide)
                        dragPull = CGSize(width: clampedX, height: clampedY)
                    }
                    .onEnded { _ in
                        // Fling: spring back through neutral with a taut twang.
                        fireTick += 1
                        withAnimation(.interpolatingSpring(stiffness: 280, damping: 9)) {
                            dragPull = .zero
                        }
                    }
            )
            .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.9), trigger: fireTick)
    }

    private func clamp(_ v: CGFloat, limit: CGFloat) -> CGFloat {
        if v > limit { return limit }
        if v < -limit { return -limit }
        return v
    }

    // MARK: Shared render core

    @ViewBuilder
    private func slingCore(pull: CGSize, in size: CGSize) -> some View {
        let geo = ElasticSlingView_SlingGeometry(size: size, pull: pull)

        ZStack {
            backdrop(in: size)

            ElasticSlingView_ElasticBand(start: geo.leftAnchor, end: geo.rightAnchor, hold: geo.holdPoint, stretch: geo.stretch)
                .stroke(
                    bandColor(for: geo.stretch),
                    style: StrokeStyle(lineWidth: bandWidth(for: geo.stretch), lineCap: .round, lineJoin: .round)
                )
                .shadow(color: bandColor(for: geo.stretch).opacity(0.5), radius: 2.0 + geo.stretch * 3.0)

            anchorPost(at: geo.leftAnchor, size: size)
            anchorPost(at: geo.rightAnchor, size: size)

            projectile(at: geo.holdPoint, stretch: geo.stretch, size: size)
        }
    }

    // MARK: Pieces

    @ViewBuilder
    private func backdrop(in size: CGSize) -> some View {
        let r: CGFloat = min(size.width, size.height) * 0.16
        RoundedRectangle(cornerRadius: r, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.085, blue: 0.07),
                        Color(red: 0.055, green: 0.045, blue: 0.038)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .strokeBorder(Color(red: 1.0, green: 0.78, blue: 0.45).opacity(0.10), lineWidth: 1.0)
            )
            .padding(min(size.width, size.height) * 0.04)
    }

    @ViewBuilder
    private func anchorPost(at point: CGPoint, size: CGSize) -> some View {
        let d: CGFloat = min(size.width, size.height) * 0.075
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 0.62, green: 0.50, blue: 0.34),
                        Color(red: 0.30, green: 0.23, blue: 0.15)
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: d
                )
            )
            .overlay(Circle().strokeBorder(Color(red: 0.0, green: 0.0, blue: 0.0).opacity(0.35), lineWidth: 1.0))
            .frame(width: d, height: d)
            .position(point)
    }

    @ViewBuilder
    private func projectile(at point: CGPoint, stretch: CGFloat, size: CGSize) -> some View {
        let base: CGFloat = min(size.width, size.height) * 0.30
        // Squash slightly under high tension for a loaded, tactile feel.
        let squash: CGFloat = 1.0 - stretch * 0.10
        let stretchX: CGFloat = 1.0 + stretch * 0.08
        let glow: CGFloat = 0.25 + stretch * 0.55

        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.84, blue: 0.40),
                            Color(red: 0.95, green: 0.55, blue: 0.18)
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: base
                    )
                )
                .overlay(
                    Circle().strokeBorder(Color(red: 1.0, green: 0.95, blue: 0.80).opacity(0.55), lineWidth: 1.2)
                )

            Image(systemName: "bolt.fill")
                .font(.system(size: base * 0.42, weight: .black))
                .foregroundStyle(Color(red: 0.18, green: 0.10, blue: 0.02))
        }
        .frame(width: base, height: base)
        .scaleEffect(x: stretchX, y: squash, anchor: .center)
        .shadow(color: Color(red: 1.0, green: 0.60, blue: 0.20).opacity(glow), radius: 6.0 + stretch * 8.0)
        .position(point)
    }

    // MARK: Stretch -> visual mappings (kept tiny for the type-checker)

    private func bandWidth(for stretch: CGFloat) -> CGFloat {
        // Thins as it strains: relaxed ~5pt, taut ~1.6pt.
        let relaxed: CGFloat = 5.0
        let taut: CGFloat = 1.6
        return relaxed - (relaxed - taut) * stretch
    }

    private func bandColor(for stretch: CGFloat) -> Color {
        // Interpolate slack (warm tan) -> strained (hot red).
        let r0: Double = 0.55; let g0: Double = 0.42; let b0: Double = 0.28
        let r1: Double = 1.00; let g1: Double = 0.27; let b1: Double = 0.18
        let t: Double = Double(min(max(stretch, 0.0), 1.0))
        let r: Double = r0 + (r1 - r0) * t
        let g: Double = g0 + (g1 - g0) * t
        let b: Double = b0 + (b1 - b0) * t
        return Color(red: r, green: g, blue: b)
    }
}

// MARK: - Geometry helper

private struct ElasticSlingView_SlingGeometry {
    let leftAnchor: CGPoint
    let rightAnchor: CGPoint
    let holdPoint: CGPoint
    let stretch: CGFloat

    init(size: CGSize, pull: CGSize) {
        let w: CGFloat = size.width
        let h: CGFloat = size.height

        // Anchors sit toward the top; the projectile rests just below center span.
        let anchorY: CGFloat = h * 0.30
        leftAnchor = CGPoint(x: w * 0.26, y: anchorY)
        rightAnchor = CGPoint(x: w * 0.74, y: anchorY)

        let restPoint = CGPoint(x: w * 0.5, y: anchorY + h * 0.06)

        // pull is already an absolute offset (points). Apply and clamp on-tile.
        let hx: CGFloat = restPoint.x + pull.width
        let hy: CGFloat = restPoint.y + pull.height
        holdPoint = CGPoint(x: ElasticSlingView_SlingGeometry.clampX(hx, w: w), y: ElasticSlingView_SlingGeometry.clampY(hy, h: h))

        // Stretch magnitude normalized for visual mappings.
        let dx: CGFloat = holdPoint.x - restPoint.x
        let dy: CGFloat = holdPoint.y - restPoint.y
        let dist: CGFloat = (dx * dx + dy * dy).squareRoot()
        let maxBack: CGFloat = h * 0.34
        let maxSide: CGFloat = w * 0.22
        let span: CGFloat = (maxBack * maxBack + maxSide * maxSide).squareRoot()
        stretch = min(max(dist / max(span, 1.0), 0.0), 1.0)
    }

    static func clampX(_ v: CGFloat, w: CGFloat) -> CGFloat {
        let lo: CGFloat = w * 0.12
        let hi: CGFloat = w * 0.88
        return min(max(v, lo), hi)
    }

    static func clampY(_ v: CGFloat, h: CGFloat) -> CGFloat {
        let lo: CGFloat = h * 0.04
        let hi: CGFloat = h * 0.94
        return min(max(v, lo), hi)
    }
}

// MARK: - Animatable V-shaped band

private struct ElasticSlingView_ElasticBand: Shape {
    var start: CGPoint   // left anchor
    var end: CGPoint     // right anchor
    var hold: CGPoint    // projectile / draw point
    var stretch: CGFloat // 0..1 (drives a subtle slack sag when relaxed)

    var animatableData: AnimatablePair<
        AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>>,
        AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat>
    > {
        get {
            AnimatablePair(
                AnimatablePair(
                    AnimatablePair(start.x, start.y),
                    AnimatablePair(end.x, end.y)
                ),
                AnimatablePair(
                    AnimatablePair(hold.x, hold.y),
                    stretch
                )
            )
        }
        set {
            start = CGPoint(x: newValue.first.first.first, y: newValue.first.first.second)
            end = CGPoint(x: newValue.first.second.first, y: newValue.first.second.second)
            hold = CGPoint(x: newValue.second.first.first, y: newValue.second.first.second)
            stretch = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        // When relaxed, let the band sag a touch with a quadratic control.
        let sag: CGFloat = (1.0 - stretch) * 10.0

        p.move(to: start)
        let c1 = CGPoint(x: (start.x + hold.x) / 2.0, y: (start.y + hold.y) / 2.0 + sag)
        p.addQuadCurve(to: hold, control: c1)

        let c2 = CGPoint(x: (hold.x + end.x) / 2.0, y: (hold.y + end.y) / 2.0 + sag)
        p.addQuadCurve(to: end, control: c2)
        return p
    }
}
