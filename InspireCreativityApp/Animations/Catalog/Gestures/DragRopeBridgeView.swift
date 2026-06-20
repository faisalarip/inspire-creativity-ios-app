// catalog-id: ges-drag-rope-bridge
import SwiftUI

// MARK: - Sag Rope Bridge
// Drag a point along a taut rope and it sags into a catenary-like curve under
// the load; the planks tilt to follow the line, and on release the sag springs
// back to taut with a bouncy "twang".
//
// Single source of truth: a normalized load position `loadX` (0…1 across the
// span) and a `sag` amount (0 = taut, 1 = max droop). Both the rope `Shape`
// and the plank layout derive from the SAME `profile(x:loadX:)` function, and
// the rope height is *linear* in `sag` — so the Shape's animatableData
// interpolation and the planks' per-view interpolation move identically during
// the release spring and never drift apart.
struct DragRopeBridgeView: View {
    var demo: Bool = false

    // Interactive state (used only when demo == false).
    @State private var loadX: CGFloat = 0.5
    @State private var sag: CGFloat = 0
    @State private var isPressing: Bool = false

    var body: some View {
        GeometryReader { geo in
            if demo {
                demoBody(size: geo.size)
            } else {
                interactiveBody(size: geo.size)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Demo (self-driving)

    @ViewBuilder
    private func demoBody(size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = autoPhase(at: t)
            bridge(size: size, loadX: phase.loadX, sag: phase.sag, pressing: phase.pressing)
        }
    }

    // ~3.4s loop: glide the load point across the span while pulsing the sag,
    // then let it twang back taut. Never blank — the rope is always drawn.
    private func autoPhase(at time: TimeInterval) -> (loadX: CGFloat, sag: CGFloat, pressing: Bool) {
        let period: Double = 3.4
        let p = (time.truncatingRemainder(dividingBy: period)) / period   // 0…1

        // Load point sweeps side to side (smooth cosine ease).
        let sweep = CGFloat(0.5 - 0.32 * cos(p * 2 * .pi))

        // Sag: ease in to a held droop for the first ~70% of the loop, then a
        // springy twang back to taut for the last ~30% (the release).
        let sagVal: CGFloat
        let pressing: Bool
        if p < 0.70 {
            let q = CGFloat(p / 0.70)
            sagVal = easeInOut(q)
            pressing = true
        } else {
            let q = CGFloat((p - 0.70) / 0.30)
            sagVal = 1 - twang(q)          // 1 → 0 with bouncy overshoot
            pressing = false
        }
        return (sweep, max(0, min(1, sagVal)), pressing)
    }

    // MARK: Interactive

    @ViewBuilder
    private func interactiveBody(size: CGSize) -> some View {
        bridge(size: size, loadX: loadX, sag: sag, pressing: isPressing)
            .contentShape(Rectangle())
            .gesture(dragGesture(size: size))
    }

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isPressing = true
                let span = restGeometry(size: size)
                // Horizontal → which point on the rope is loaded.
                loadX = clamp((value.location.x - span.startX) / span.width, 0, 1)
                // Vertical → how far the rope is pulled down past the rest line.
                let pulled = value.location.y - span.restY
                let maxDrop = span.maxSag
                sag = clamp(pulled / maxDrop, 0, 1)
            }
            .onEnded { _ in
                isPressing = false
                withAnimation(.interpolatingSpring(stiffness: 170, damping: 9)) {
                    sag = 0   // twang back to taut; loadX stays put (keeps it linear)
                }
            }
    }

    // MARK: Composed bridge

    @ViewBuilder
    private func bridge(size: CGSize, loadX: CGFloat, sag: CGFloat, pressing: Bool) -> some View {
        let g = restGeometry(size: size)
        ZStack {
            postsAndDeck(geo: g)
            RopeShape(loadX: loadX, sag: sag, geo: g)
                .stroke(ropeGradient, style: StrokeStyle(lineWidth: g.ropeWidth, lineCap: .round))
                .shadow(color: .black.opacity(0.45), radius: g.ropeWidth * 0.5, y: g.ropeWidth * 0.6)
            planks(loadX: loadX, sag: sag, geo: g)
            loadKnob(loadX: loadX, sag: sag, geo: g, pressing: pressing)
        }
    }

    // Two anchor posts plus a faint shadow line showing the taut rest position.
    @ViewBuilder
    private func postsAndDeck(geo g: RestGeometry) -> some View {
        let postW = g.ropeWidth * 1.4
        let postTop = g.restY - g.ropeWidth * 2.2
        let postBottom = min(g.size.height - g.ropeWidth, g.restY + g.maxSag + g.plankH)
        Path { p in
            p.move(to: CGPoint(x: g.startX, y: g.restY))
            p.addLine(to: CGPoint(x: g.endX, y: g.restY))
        }
        .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))

        ForEach([g.startX, g.endX], id: \.self) { x in
            RoundedRectangle(cornerRadius: postW * 0.4)
                .fill(postGradient)
                .frame(width: postW, height: max(postW, postBottom - postTop))
                .position(x: x, y: (postTop + postBottom) / 2)
                .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
        }
    }

    // Wooden planks sampled along the live curve, each tilted to the local tangent.
    @ViewBuilder
    private func planks(loadX: CGFloat, sag: CGFloat, geo g: RestGeometry) -> some View {
        let count = g.plankCount
        ForEach(0..<count, id: \.self) { i in
            let n = CGFloat(i) + 1
            let u = n / CGFloat(count + 1)               // 0…1 along the span (skip anchors)
            let x = g.startX + u * g.width
            let y = ropeY(at: x, loadX: loadX, sag: sag, geo: g)
            let angle = tangentAngle(at: x, loadX: loadX, sag: sag, geo: g)
            // Glint: planks nearer the load (deeper) catch a touch more light.
            let depth = (y - g.restY) / max(1, g.maxSag)
            RoundedRectangle(cornerRadius: g.plankH * 0.32)
                .fill(plankGradient(depth: depth))
                .frame(width: g.plankW, height: g.plankH)
                .overlay(
                    RoundedRectangle(cornerRadius: g.plankH * 0.32)
                        .stroke(Color.black.opacity(0.25), lineWidth: 0.6)
                )
                .rotationEffect(.radians(angle))
                .position(x: x, y: y + g.plankH * 0.5 + g.ropeWidth * 0.2)
                .shadow(color: .black.opacity(0.3), radius: 1.5, y: 1)
        }
    }

    // The grabbable load point — a rope clip / carabiner that rides the curve.
    @ViewBuilder
    private func loadKnob(loadX: CGFloat, sag: CGFloat, geo g: RestGeometry, pressing: Bool) -> some View {
        let x = g.startX + loadX * g.width
        let y = ropeY(at: x, loadX: loadX, sag: sag, geo: g)
        let r = g.ropeWidth * (pressing ? 2.0 : 1.6)
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [Color(hexCode: "#FFE9B0"), Color(hexCode: "#E0A23C")],
                    center: .init(x: 0.35, y: 0.3), startRadius: 0, endRadius: r))
            Circle()
                .stroke(Color(hexCode: "#7A5418"), lineWidth: max(1, r * 0.16))
        }
        .frame(width: r * 2, height: r * 2)
        .position(x: x, y: y)
        .shadow(color: Color(hexCode: "#E0A23C").opacity(pressing ? 0.6 : 0.0), radius: pressing ? 8 : 0)
        .animation(.easeOut(duration: 0.18), value: pressing)
    }

    // MARK: Curve math (single source of truth)

    // Rope height at a given screen-x. Linear in `sag` so Shape interpolation
    // and plank interpolation move in lockstep during the release spring.
    private func ropeY(at x: CGFloat, loadX: CGFloat, sag: CGFloat, geo g: RestGeometry) -> CGFloat {
        let u = clamp((x - g.startX) / g.width, 0, 1)
        return g.restY + g.maxSag * sag * profile(u, loadX: loadX)
    }

    // Local tangent angle from a cheap symmetric finite difference.
    private func tangentAngle(at x: CGFloat, loadX: CGFloat, sag: CGFloat, geo g: RestGeometry) -> CGFloat {
        let dx: CGFloat = max(2, g.width * 0.02)
        let y1 = ropeY(at: x - dx, loadX: loadX, sag: sag, geo: g)
        let y2 = ropeY(at: x + dx, loadX: loadX, sag: sag, geo: g)
        return atan2(y2 - y1, dx * 2)
    }

    // Static droop profile peaked under the load and pinned to 0 at both
    // anchors. A blend of a triangular "load cusp" and a smooth catenary bowl
    // gives a believable rope: a sharp dip at the finger easing into a hanging
    // curve toward the posts.
    private func profile(_ u: CGFloat, loadX: CGFloat) -> CGFloat {
        let lx = clamp(loadX, 0.001, 0.999)
        // Triangular component: 1 at the load, linearly to 0 at the anchors.
        let tri: CGFloat = u <= lx ? (u / lx) : ((1 - u) / (1 - lx))
        // Catenary-ish bowl: a smooth symmetric sag (parabolic), softened.
        let bowl = 4 * u * (1 - u)                // 0 at ends, 1 at center
        // Weight the cusp toward the load, blend in the bowl for a hanging feel.
        let shaped = pow(max(0, tri), 1.35)
        return clamp(0.62 * shaped + 0.38 * bowl * tri, 0, 1)
    }

    // MARK: Rest geometry

    private func restGeometry(size: CGSize) -> RestGeometry {
        let w = size.width
        let h = size.height
        let inset = w * 0.10
        let startX = inset
        let endX = w - inset
        let width = max(1, endX - startX)
        // Rope hangs in the upper-middle so it has room to sag downward.
        let restY = h * 0.34
        let maxSag = max(8, (h * 0.5) - h * 0.04)
        let ropeWidth = max(2.5, min(w, h) * 0.022)
        // Plank count scales a little with width so a small tile isn't crowded.
        let plankCount = w < 200 ? 6 : 8
        let plankW = (width / CGFloat(plankCount + 1)) * 0.82
        let plankH = max(5, min(w, h) * 0.05)
        return RestGeometry(size: size, startX: startX, endX: endX, width: width,
                            restY: restY, maxSag: maxSag, ropeWidth: ropeWidth,
                            plankCount: plankCount, plankW: plankW, plankH: plankH)
    }

    // MARK: Palette

    private var ropeGradient: LinearGradient {
        LinearGradient(colors: [Color(hexCode: "#C9A26B"), Color(hexCode: "#A07A45"), Color(hexCode: "#C9A26B")],
                       startPoint: .leading, endPoint: .trailing)
    }
    private var postGradient: LinearGradient {
        LinearGradient(colors: [Color(hexCode: "#5B4630"), Color(hexCode: "#3A2C1C")],
                       startPoint: .top, endPoint: .bottom)
    }
    private func plankGradient(depth: CGFloat) -> LinearGradient {
        // Planks sitting deeper under the load catch a touch more top light —
        // interpolate the top face between a base and a brighter highlight.
        let glint = clamp(depth, 0, 1) * 0.35
        let top = Color.lerpRGB(
            from: (0.710, 0.521, 0.298),   // #B5854C
            to:   (0.910, 0.773, 0.537),   // #E8C589
            fraction: glint)
        return LinearGradient(colors: [top, Color(hexCode: "#7C5A33")],
                              startPoint: .top, endPoint: .bottom)
    }

    // MARK: Tiny helpers

    private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { min(max(v, lo), hi) }

    private func easeInOut(_ x: CGFloat) -> CGFloat {
        let c = clamp(x, 0, 1)
        return c * c * (3 - 2 * c)
    }

    // Damped bounce 0→1 used for the auto-release twang.
    private func twang(_ x: CGFloat) -> CGFloat {
        let c = clamp(x, 0, 1)
        let decay = exp(-4.0 * c)
        let osc = cos(c * .pi * 3.0)
        return CGFloat(1 - decay * osc)
    }
}

// MARK: - Rest geometry container

private struct RestGeometry {
    let size: CGSize
    let startX: CGFloat
    let endX: CGFloat
    let width: CGFloat
    let restY: CGFloat
    let maxSag: CGFloat
    let ropeWidth: CGFloat
    let plankCount: Int
    let plankW: CGFloat
    let plankH: CGFloat
}

// MARK: - Animatable rope Shape

private struct RopeShape: Shape {
    var loadX: CGFloat
    var sag: CGFloat
    let geo: RestGeometry

    // Animate both load position and sag so the release spring (and any change)
    // interpolates smoothly. Linear-in-sag profile keeps it glued to the planks.
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(loadX, sag) }
        set { loadX = newValue.first; sag = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let samples = 48
        for i in 0...samples {
            let u = CGFloat(i) / CGFloat(samples)
            let x = geo.startX + u * geo.width
            let y = geo.restY + geo.maxSag * sag * profile(u, loadX: loadX)
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        return path
    }

    // Must match DragRopeBridgeView.profile exactly (same source of truth).
    private func profile(_ u: CGFloat, loadX: CGFloat) -> CGFloat {
        let lx = min(max(loadX, 0.001), 0.999)
        let tri: CGFloat = u <= lx ? (u / lx) : ((1 - u) / (1 - lx))
        let bowl = 4 * u * (1 - u)
        let shaped = pow(max(0, tri), 1.35)
        let v = 0.62 * shaped + 0.38 * bowl * tri
        return min(max(v, 0), 1)
    }
}

// MARK: - Color helpers

private extension Color {
    init(hexCode hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r, g, b, a: Double
        if s.count == 8 {
            r = Double((rgb & 0xFF000000) >> 24) / 255
            g = Double((rgb & 0x00FF0000) >> 16) / 255
            b = Double((rgb & 0x0000FF00) >> 8) / 255
            a = Double(rgb & 0x000000FF) / 255
        } else {
            r = Double((rgb & 0xFF0000) >> 16) / 255
            g = Double((rgb & 0x00FF00) >> 8) / 255
            b = Double(rgb & 0x0000FF) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    // Linearly interpolate between two sRGB component triples.
    static func lerpRGB(from a: (Double, Double, Double),
                        to b: (Double, Double, Double),
                        fraction: Double) -> Color {
        let f = min(max(fraction, 0), 1)
        return Color(.sRGB,
                     red: a.0 + (b.0 - a.0) * f,
                     green: a.1 + (b.1 - a.1) * f,
                     blue: a.2 + (b.2 - a.2) * f,
                     opacity: 1)
    }
}
