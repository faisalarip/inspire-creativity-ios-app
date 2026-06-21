// catalog-id: tr-vortex-spiral
import SwiftUI

// MARK: - Vortex Spiral
// The outgoing view rotates and scales down into a vanishing spiral while
// concentric ring overlays sweep inward, then the next view un-spirals back
// out to full size. Pure transforms + overlay rings, no shader. iOS 17.
//
// A single `progress` (0...1) is the only input to the render. Both card faces
// stay mounted at all times; opacity carries the handoff so the center is never
// blank — at progress ≈ 0.5 the rings peak and both faces are mid-fade, so there
// is always a legible state on screen.
//
// IMPORTANT: the render lives in an `Animatable` child view (`VortexSpiralView_VortexContent`)
// so its `body` is re-evaluated at every interpolated `progress`. Without that,
// SwiftUI would only sample the endpoint outputs (0 and 1) and the non-monotonic
// ring sweep / ring opacity (which peak at 0.5) would never appear.
struct VortexSpiralView: View {
    var demo: Bool = false

    // Interactive: a tap toggles `spiraled`, animating progress 0 <-> 1.
    @State private var spiraled: Bool = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)

            ZStack {
                backdrop

                if demo {
                    autoDrivenContent(side: side)
                } else {
                    interactiveContent(side: side)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Demo loop (self-driving)

    @ViewBuilder
    private func autoDrivenContent(side: CGFloat) -> some View {
        PhaseAnimator([0.0, 1.0]) { value in
            VortexSpiralView_VortexContent(progress: value, side: side)
        } animation: { _ in
            .easeInOut(duration: 1.7)
        }
    }

    // MARK: Interactive (tap to spiral the swap)

    @ViewBuilder
    private func interactiveContent(side: CGFloat) -> some View {
        let progress: Double = spiraled ? 1.0 : 0.0
        VortexSpiralView_VortexContent(progress: progress, side: side)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.72)) {
                    spiraled.toggle()
                }
            }
    }

    // MARK: Backdrop

    private var backdrop: some View {
        RadialGradient(
            colors: [
                Color(red: 0.07, green: 0.08, blue: 0.13),
                Color(red: 0.02, green: 0.02, blue: 0.05)
            ],
            center: .center,
            startRadius: 2,
            endRadius: 240
        )
        .ignoresSafeArea()
    }
}

// MARK: - Animatable vortex render
//
// `progress` is exposed as `animatableData`, so SwiftUI re-evaluates `body`
// at every interpolated progress value during a `withAnimation` transition or
// across `PhaseAnimator` phases. This is what lets the inward ring sweep and
// the mid-transition ring opacity peak (both non-monotonic in progress) play.
private struct VortexSpiralView_VortexContent: View, Animatable {
    var progress: Double
    var side: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let clamped: Double = min(max(progress, 0.0), 1.0)
        let corner: CGFloat = side * 0.14

        ZStack {
            // Face A: full at progress 0, drains into the vortex by ~0.55.
            VortexSpiralView_CardFace(index: 0)
                .modifier(VortexSpiralView_SpiralTransform(progress: faceAProgress(clamped), side: side))
                .opacity(faceAOpacity(clamped))

            // Face B: emerges from the vortex starting ~0.45, full at progress 1.
            VortexSpiralView_CardFace(index: 1)
                .modifier(VortexSpiralView_SpiralTransform(progress: faceBProgress(clamped), side: side))
                .opacity(faceBOpacity(clamped))

            // Concentric ring sweep — peaks at mid-transition so the center
            // always carries something legible during the crossover.
            VortexSpiralView_RingsOverlay(progress: clamped, side: side)
                .opacity(ringOpacity(clamped))
                .allowsHitTesting(false)
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(Color(red: 1, green: 1, blue: 1).opacity(0.10), lineWidth: 1)
        )
    }

    // MARK: Progress mapping helpers
    //
    // Face A: drains 0 -> 0.55 (1 = full present, 0 = fully spiralled away).
    private func faceAProgress(_ p: Double) -> Double {
        let t: Double = min(p / 0.55, 1.0)
        return 1.0 - t
    }

    // Face B: emerges 0.45 -> 1 (0 = fully spiralled away, 1 = full present).
    private func faceBProgress(_ p: Double) -> Double {
        let t: Double = max((p - 0.45) / 0.55, 0.0)
        return min(t, 1.0)
    }

    private func faceAOpacity(_ p: Double) -> Double {
        // Fades out as it drains; never starts from literal 0 at p=0.
        let t: Double = min(p / 0.58, 1.0)
        return max(1.0 - t, 0.0)
    }

    private func faceBOpacity(_ p: Double) -> Double {
        let t: Double = max((p - 0.42) / 0.58, 0.0)
        return min(t, 1.0)
    }

    private func ringOpacity(_ p: Double) -> Double {
        // Triangle peak at p = 0.5, clamped non-negative.
        let tri: Double = 1.0 - abs(p * 2.0 - 1.0)
        return max(tri, 0.0) * 0.9
    }
}

// MARK: - Spiral transform
//
// A single 0...1 `presence` value drives rotation + scale together. At
// presence 1 the face is upright and full; at 0 it is spun several turns and
// shrunk to a floored scale (never literal zero) — the drain-down vortex.
private struct VortexSpiralView_SpiralTransform: ViewModifier {
    var progress: Double   // 1 = present/full, 0 = spiralled away
    var side: CGFloat

    private let turns: Double = 2.5
    private let minScale: CGFloat = 0.06

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .rotationEffect(angle)
            .blur(radius: blur)
    }

    private var scale: CGFloat {
        let presence: CGFloat = CGFloat(progress)
        return minScale + (1.0 - minScale) * presence
    }

    private var angle: Angle {
        // Spins more the further it is drained (presence -> 0).
        let drained: Double = 1.0 - progress
        return .degrees(turns * 360.0 * drained)
    }

    private var blur: CGFloat {
        // A touch of motion-blur as it whirls into the vortex.
        let drained: CGFloat = CGFloat(1.0 - progress)
        return drained * (side * 0.012)
    }
}

// MARK: - Card faces
//
// Two distinct legible faces so the swap actually reads as a transition
// between content, not a single thing vanishing.
private struct VortexSpiralView_CardFace: View {
    let index: Int

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                LinearGradient(
                    colors: palette,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Soft swirl glyph reinforcing the vortex theme.
                VortexSpiralView_SwirlMark()
                    .stroke(
                        Color(red: 1, green: 1, blue: 1).opacity(0.22),
                        style: StrokeStyle(lineWidth: max(s * 0.012, 1.0), lineCap: .round)
                    )
                    .frame(width: s * 0.62, height: s * 0.62)

                VStack(spacing: s * 0.04) {
                    Text(symbol)
                        .font(.system(size: s * 0.30, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(red: 1, green: 1, blue: 1).opacity(0.95))
                    Text(label)
                        .font(.system(size: s * 0.085, weight: .semibold, design: .rounded))
                        .tracking(s * 0.012)
                        .foregroundColor(Color(red: 1, green: 1, blue: 1).opacity(0.78))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipShape(RoundedRectangle(cornerRadius: s * 0.14, style: .continuous))
        }
    }

    private var palette: [Color] {
        if index == 0 {
            return [
                Color(red: 0.36, green: 0.30, blue: 0.92),
                Color(red: 0.62, green: 0.24, blue: 0.78)
            ]
        } else {
            return [
                Color(red: 0.98, green: 0.55, blue: 0.26),
                Color(red: 0.92, green: 0.27, blue: 0.45)
            ]
        }
    }

    private var symbol: String { index == 0 ? "A" : "B" }
    private var label: String { index == 0 ? "ORIGIN" : "ARRIVAL" }
}

// MARK: - Swirl mark (decorative spiral path)
private struct VortexSpiralView_SwirlMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxR: CGFloat = min(rect.width, rect.height) / 2.0
        let turns: Double = 3.0
        let steps: Int = 220

        for i in 0...steps {
            let t: Double = Double(i) / Double(steps)
            let theta: Double = t * turns * 2.0 * .pi
            let r: CGFloat = maxR * CGFloat(t)
            let x: CGFloat = center.x + r * CGFloat(cos(theta))
            let y: CGFloat = center.y + r * CGFloat(sin(theta))
            let pt = CGPoint(x: x, y: y)
            if i == 0 {
                path.move(to: pt)
            } else {
                path.addLine(to: pt)
            }
        }
        return path
    }
}

// MARK: - Concentric ring sweep overlay
//
// Several stroked circles whose radii sweep inward with progress. Clipped to
// the card bounds so they read as a vortex drawing toward the center.
private struct VortexSpiralView_RingsOverlay: View {
    var progress: Double
    var side: CGFloat

    private let count: Int = 5

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                ring(index: i)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: side * 0.14, style: .continuous))
    }

    @ViewBuilder
    private func ring(index i: Int) -> some View {
        let base: Double = Double(i) / Double(count)          // 0...~0.8 staggered
        // Each ring's radius sweeps inward as progress crosses 0.5.
        let sweep: Double = 1.0 - abs(progress * 2.0 - 1.0)   // 0 at ends, 1 at mid
        let phase: Double = max(0.0, min(1.0, base + sweep * 0.6))
        let radius: CGFloat = side * 0.5 * CGFloat(1.0 - phase * 0.85)
        let diameter: CGFloat = max(radius * 2.0, 1.0)
        let line: CGFloat = max(side * 0.012, 1.0)

        Circle()
            .stroke(
                Color(red: 0.85, green: 0.92, blue: 1.0).opacity(0.45),
                lineWidth: line
            )
            .frame(width: diameter, height: diameter)
            .blur(radius: 0.5)
    }
}
