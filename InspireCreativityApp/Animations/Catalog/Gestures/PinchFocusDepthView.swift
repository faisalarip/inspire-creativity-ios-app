// catalog-id: ges-pinch-focus-depth
import SwiftUI

// MARK: - Pinch Depth Diorama
// Pinch to dolly a virtual camera through stacked parallax planes.
// Foreground scales/slides faster than background; blur tracks the focused depth.
// demo == true  -> self-driving TimelineView dolly loop (front -> back -> front).
// demo == false -> interactive MagnifyGesture mapped to focusDepth, snaps on release.

struct PinchFocusDepthView: View {
    var demo: Bool = false

    // Committed camera depth (0 = front plane in focus, 1 = back plane in focus).
    @State private var focusDepth: CGFloat = 0.35
    // Live additive delta produced while a pinch is in progress.
    @State private var liveDelta: CGFloat = 0

    private let planeCount: Int = 4

    var body: some View {
        GeometryReader { geo in
            if demo {
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    diorama(size: geo.size, depth: loopDepth(t))
                }
            } else {
                interactive(size: geo.size)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    // MARK: Interactive branch

    private func interactive(size: CGSize) -> some View {
        let depth = clampDepth(focusDepth + liveDelta)
        return diorama(size: size, depth: depth)
            .contentShape(Rectangle())
            .gesture(
                MagnifyGesture(minimumScaleDelta: 0)
                    .onChanged { value in
                        // MagnifyGesture is relative: magnification == 1 at pinch start.
                        // Pinch OUT (mag > 1) dollies toward the front (depth -> 0).
                        let sensitivity: CGFloat = 0.9
                        liveDelta = -(CGFloat(value.magnification) - 1) * sensitivity
                    }
                    .onEnded { _ in
                        let committed = clampDepth(focusDepth + liveDelta)
                        liveDelta = 0
                        // Snap to the nearest plane's depth.
                        let snapped = nearestPlaneDepth(committed)
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                            focusDepth = snapped
                        }
                    }
            )
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: focusDepth)
    }

    // MARK: Shared render path (used by BOTH demo loop and interactive view)

    private func diorama(size: CGSize, depth: CGFloat) -> some View {
        ZStack {
            backdrop(size: size, focusDepth: depth)
            ForEach(0..<planeCount, id: \.self) { index in
                planeLayer(index: index, size: size, focusDepth: depth)
            }
            vignette(size: size)
            focusReadout(size: size, focusDepth: depth)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: Backdrop sky

    private func backdrop(size: CGSize, focusDepth: CGFloat) -> some View {
        // Sky warms slightly as the camera dollies toward the front.
        let warmth = 1 - focusDepth
        let top = Color(red: 0.07 + 0.04 * warmth, green: 0.08, blue: 0.16)
        let bottom = Color(red: 0.16 + 0.10 * warmth, green: 0.11, blue: 0.22)
        return LinearGradient(
            colors: [top, bottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: A single parallax plane

    @ViewBuilder
    private func planeLayer(index: Int, size: CGSize, focusDepth: CGFloat) -> some View {
        let layerDepth = planeDepth(index)            // 0 (front) ... 1 (back)
        let coeff = depthCoeff(layerDepth)            // far planes move/scale less
        let dolly = focusDepth - layerDepth           // signed distance from camera

        // Foreground planes (low layerDepth) react harder than the background.
        let scale = clampScale(1 + dolly * (0.55 * (1 - coeff) + 0.12))
        let slide = -dolly * (1 - coeff) * size.height * 0.34

        let dist = abs(layerDepth - focusDepth)
        let blurRadius = min(dist * 9.0, 7.5)         // clamped, modest radii
        let opacity = max(0.42, 1 - dist * 0.55)      // opacity floor: never blank

        planeContent(index: index, size: size)
            .scaleEffect(scale, anchor: .center)
            .offset(y: slide)
            .blur(radius: blurRadius)
            .opacity(opacity)
    }

    // MARK: Plane artwork (back -> front)

    @ViewBuilder
    private func planeContent(index: Int, size: CGSize) -> some View {
        switch index {
        case 0: backHills(size: size)      // farthest
        case 1: midOrbs(size: size)
        case 2: foreRidge(size: size)
        default: nearLeaves(size: size)    // closest
        }
    }

    // Plane 0 — distant rolling hills + sun
    private func backHills(size: CGSize) -> some View {
        let w = size.width
        let h = size.height
        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 1.0, green: 0.86, blue: 0.62),
                                 Color(red: 0.96, green: 0.62, blue: 0.42)],
                        center: .center, startRadius: 0, endRadius: w * 0.22
                    )
                )
                .frame(width: w * 0.38, height: w * 0.38)
                .offset(x: w * 0.18, y: -h * 0.18)
            HillShape(crest: 0.62, amp: 0.05)
                .fill(Color(red: 0.30, green: 0.27, blue: 0.46))
        }
    }

    // Plane 1 — drifting orbs / mid clouds
    private func midOrbs(size: CGSize) -> some View {
        let w = size.width
        let h = size.height
        let spots: [(CGFloat, CGFloat, CGFloat)] = [
            (-0.30, -0.05, 0.30),
            (0.05, 0.10, 0.42),
            (0.34, -0.12, 0.26)
        ]
        return ZStack {
            ForEach(0..<spots.count, id: \.self) { i in
                let s = spots[i]
                Circle()
                    .fill(Color(red: 0.62, green: 0.55, blue: 0.82).opacity(0.85))
                    .frame(width: w * s.2, height: w * s.2)
                    .offset(x: w * s.0, y: h * s.1)
            }
        }
    }

    // Plane 2 — nearer ridge silhouette
    private func foreRidge(size: CGSize) -> some View {
        HillShape(crest: 0.74, amp: 0.10)
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.20, green: 0.16, blue: 0.32),
                             Color(red: 0.12, green: 0.10, blue: 0.22)],
                    startPoint: .top, endPoint: .bottom
                )
            )
    }

    // Plane 3 — foreground foliage framing the bottom corners (closest, moves most)
    private func nearLeaves(size: CGSize) -> some View {
        let w = size.width
        let h = size.height
        let leaf = LinearGradient(
            colors: [Color(red: 0.10, green: 0.13, blue: 0.10),
                     Color(red: 0.04, green: 0.06, blue: 0.05)],
            startPoint: .top, endPoint: .bottom
        )
        return ZStack {
            LeafShape()
                .fill(leaf)
                .frame(width: w * 0.7, height: h * 0.7)
                .rotationEffect(.degrees(-24))
                .offset(x: -w * 0.34, y: h * 0.40)
            LeafShape()
                .fill(leaf)
                .frame(width: w * 0.62, height: h * 0.62)
                .rotationEffect(.degrees(34))
                .scaleEffect(x: -1, y: 1)
                .offset(x: w * 0.36, y: h * 0.44)
        }
    }

    // MARK: Overlays

    private func vignette(size: CGSize) -> some View {
        RadialGradient(
            colors: [Color.clear, Color(red: 0.02, green: 0.02, blue: 0.05).opacity(0.55)],
            center: .center,
            startRadius: min(size.width, size.height) * 0.30,
            endRadius: max(size.width, size.height) * 0.72
        )
        .allowsHitTesting(false)
    }

    // A small depth indicator dot strip so the focused plane is always legible.
    private func focusReadout(size: CGSize, focusDepth: CGFloat) -> some View {
        let dotSize = max(4.0, min(size.width, size.height) * 0.035)
        let gap = dotSize * 1.4
        return HStack(spacing: gap) {
            ForEach(0..<planeCount, id: \.self) { index in
                let d = planeDepth(index)
                let active = abs(d - focusDepth) < (0.5 / CGFloat(planeCount))
                Circle()
                    .fill(Color.white.opacity(active ? 0.95 : 0.30))
                    .frame(width: active ? dotSize * 1.25 : dotSize,
                           height: active ? dotSize * 1.25 : dotSize)
            }
        }
        .padding(.vertical, dotSize)
        .padding(.horizontal, dotSize * 1.6)
        .background(
            Capsule().fill(Color(red: 0.0, green: 0.0, blue: 0.0).opacity(0.28))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, max(6.0, size.height * 0.06))
        .allowsHitTesting(false)
    }

    // MARK: Math helpers

    private func planeDepth(_ index: Int) -> CGFloat {
        guard planeCount > 1 else { return 0 }
        // index 0 = back (depth 1) ... last = front (depth 0)
        return CGFloat(planeCount - 1 - index) / CGFloat(planeCount - 1)
    }

    private func depthCoeff(_ layerDepth: CGFloat) -> CGFloat {
        // Larger for far planes -> they scale/slide less.
        return 0.30 + 0.55 * layerDepth
    }

    private func nearestPlaneDepth(_ value: CGFloat) -> CGFloat {
        var best = planeDepth(0)
        var bestDist = abs(best - value)
        for i in 1..<planeCount {
            let d = planeDepth(i)
            let dist = abs(d - value)
            if dist < bestDist {
                best = d
                bestDist = dist
            }
        }
        return best
    }

    private func clampDepth(_ v: CGFloat) -> CGFloat {
        min(max(v, 0), 1)
    }

    private func clampScale(_ v: CGFloat) -> CGFloat {
        min(max(v, 0.55), 1.85)
    }

    // Eased front -> back -> front loop (~3.4s) for the demo tile.
    private func loopDepth(_ time: TimeInterval) -> CGFloat {
        let period: Double = 3.4
        let phase = (time.truncatingRemainder(dividingBy: period)) / period // 0..1
        // Triangle wave 0 -> 1 -> 0, then smootherstep for an eased dolly.
        let tri = phase < 0.5 ? phase * 2 : (1 - phase) * 2
        let eased = tri * tri * (3 - 2 * tri)
        return clampDepth(CGFloat(eased))
    }
}

// MARK: - Shapes

private struct HillShape: Shape {
    var crest: CGFloat   // baseline height (fraction of height, from top)
    var amp: CGFloat     // hump amplitude (fraction of height)

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let baseY = rect.height * crest
        let a = rect.height * amp
        p.move(to: CGPoint(x: rect.minX, y: baseY))
        let steps = 24
        for i in 0...steps {
            let x = rect.width * CGFloat(i) / CGFloat(steps)
            let phase = CGFloat(i) / CGFloat(steps) * .pi * 2
            let y = baseY - sin(phase) * a - sin(phase * 0.5) * a * 0.5
            p.addLine(to: CGPoint(x: x, y: y))
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control: CGPoint(x: rect.minX - w * 0.05, y: rect.midY)
        )
        p.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control: CGPoint(x: rect.maxX + w * 0.05, y: rect.midY)
        )
        // a couple of veins for texture
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.minY + h * 0.1))
        p.closeSubpath()
        return p
    }
}
