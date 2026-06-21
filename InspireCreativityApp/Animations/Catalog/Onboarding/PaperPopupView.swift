// catalog-id: ob-paper-popup
import SwiftUI

/// Pop-Up Book — flat shape-drawn scenery hinges upward off the center spine using
/// 3D rotation so the illustration physically pops up from the fold, while the
/// previous page folds back down.
///
/// - `demo == true`  → a self-driving TimelineView loop that turns pages on a timer.
/// - `demo == false` → an interactive horizontal drag that scrubs the page turn and
///   commits / springs back on release.
struct PaperPopupView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                PaperPopupView_BookBackground()
                if demo {
                    PaperPopupView_DemoStage(size: size)
                } else {
                    PaperPopupView_InteractiveStage(size: size)
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Page model

/// A small palette describing one pop-up spread. Three distinct scenes so the
/// page-turn visibly swaps content.
private struct PaperPopupView_PopupScene {
    let sky: (Color, Color)
    let ground: Color
    let accent: Color
    let kind: PaperPopupView_SceneKind
}

private enum PaperPopupView_SceneKind {
    case meadow      // house + trees + sun
    case mountains   // peaks + moon
    case city        // skyline + stars
}

private enum PaperPopupView_PopupScenes {
    static let all: [PaperPopupView_PopupScene] = [
        PaperPopupView_PopupScene(
            sky: (Color(red: 0.42, green: 0.66, blue: 0.92),
                  Color(red: 0.83, green: 0.90, blue: 0.98)),
            ground: Color(red: 0.46, green: 0.72, blue: 0.42),
            accent: Color(red: 0.98, green: 0.82, blue: 0.32),
            kind: .meadow
        ),
        PaperPopupView_PopupScene(
            sky: (Color(red: 0.18, green: 0.22, blue: 0.40),
                  Color(red: 0.45, green: 0.40, blue: 0.62)),
            ground: Color(red: 0.34, green: 0.40, blue: 0.55),
            accent: Color(red: 0.95, green: 0.94, blue: 0.86),
            kind: .mountains
        ),
        PaperPopupView_PopupScene(
            sky: (Color(red: 0.10, green: 0.13, blue: 0.27),
                  Color(red: 0.30, green: 0.20, blue: 0.42)),
            ground: Color(red: 0.16, green: 0.18, blue: 0.30),
            accent: Color(red: 0.99, green: 0.74, blue: 0.42),
            kind: .city
        )
    ]

    static func scene(_ index: Int) -> PaperPopupView_PopupScene {
        all[((index % all.count) + all.count) % all.count]
    }
}

// MARK: - Persistent backdrop (never hinges, always legible)

private struct PaperPopupView_BookBackground: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.20, green: 0.16, blue: 0.24),
                             Color(red: 0.09, green: 0.07, blue: 0.12)],
                    startPoint: .top, endPoint: .bottom
                )
                openBook(width: w, height: h)
            }
        }
        .allowsHitTesting(false)
    }

    /// The open book base spread: two warm paper pages meeting at a shadowed spine.
    private func openBook(width w: CGFloat, height h: CGFloat) -> some View {
        let pageTop = h * 0.18
        let pageH = h * 0.66
        let pageW = w * 0.88
        let x = (w - pageW) / 2
        return ZStack {
            RoundedRectangle(cornerRadius: h * 0.04, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.98, green: 0.96, blue: 0.90),
                                 Color(red: 0.92, green: 0.88, blue: 0.79)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: pageW, height: pageH)
                .position(x: w / 2, y: pageTop + pageH / 2)
                .shadow(color: .black.opacity(0.35), radius: h * 0.03, y: h * 0.012)

            // Spine shadow down the center fold.
            LinearGradient(
                colors: [Color.black.opacity(0.0),
                         Color.black.opacity(0.22),
                         Color.black.opacity(0.0)],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: w * 0.10, height: pageH)
            .position(x: w / 2, y: pageTop + pageH / 2)
            .blur(radius: w * 0.012)

            // Page lines suggesting paper.
            ForEach(0..<2, id: \.self) { side in
                ruleLines(width: pageW / 2 - x * 0.4)
                    .frame(width: pageW / 2 - x * 0.4, height: pageH * 0.5)
                    .position(
                        x: side == 0 ? w * 0.30 : w * 0.70,
                        y: pageTop + pageH * 0.72
                    )
            }
        }
    }

    private func ruleLines(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(0..<4, id: \.self) { _ in
                Capsule()
                    .fill(Color(red: 0.62, green: 0.55, blue: 0.45).opacity(0.30))
                    .frame(height: 2)
            }
        }
    }
}

// MARK: - Angle mapping shared by both drivers

/// Maps a continuous turn progress `p` (0 = page settled flat & standing,
/// 1 = fully turned to the next page) to hinge angles for the incoming and
/// outgoing pop-up layers.
///
/// At rest the *current* scene stands up at 0° (facing the viewer). As the page
/// turns the current scene lays back toward -90° while the next scene rises from
/// 90° to 0°.
private func hingeAngles(for p: Double) -> (incoming: Double, outgoing: Double) {
    let clamped = min(max(p, 0), 1)
    let eased = smoothstep(clamped)
    let outgoing: Double = -90.0 * eased        // 0 → -90 (lays flat away)
    let incoming: Double = 90.0 * (1.0 - eased) // 90 → 0  (stands up)
    return (incoming, outgoing)
}

private func smoothstep(_ x: Double) -> Double {
    x * x * (3.0 - 2.0 * x)
}

// MARK: - Demo (self-driving)

private struct PaperPopupView_DemoStage: View {
    let size: CGSize
    private let period: Double = 3.4

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = t.truncatingRemainder(dividingBy: period) / period
            let pageIndex = Int(t / period)

            // Hold flat ~55% of the loop, turn the page over the remaining ~45%.
            let progress = turnProgress(phase)

            PaperPopupView_PopupSpread(
                size: size,
                progress: progress,
                outgoingIndex: pageIndex,
                incomingIndex: pageIndex + 1
            )
        }
    }

    private func turnProgress(_ phase: Double) -> Double {
        let hold = 0.55
        if phase < hold { return 0 }
        return (phase - hold) / (1.0 - hold)
    }
}

// MARK: - Interactive (drag-scrubbed)

private struct PaperPopupView_InteractiveStage: View {
    let size: CGSize

    @State private var pageIndex: Int = 0
    @State private var dragProgress: Double = 0   // live scrub 0…1
    @State private var settleProgress: Double = 0 // animated commit/return

    var body: some View {
        let active = max(dragProgress, settleProgress)
        PaperPopupView_PopupSpread(
            size: size,
            progress: active,
            outgoingIndex: pageIndex,
            incomingIndex: pageIndex + 1
        )
        .contentShape(Rectangle())
        .gesture(turnGesture)
    }

    private var turnGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Dragging left advances the page; clamp 0…1.
                let raw = -value.translation.width / max(size.width * 0.7, 1)
                dragProgress = min(max(raw, 0), 1)
            }
            .onEnded { value in
                let predicted = -value.predictedEndTranslation.width / max(size.width * 0.7, 1)
                let shouldCommit = dragProgress > 0.5 || predicted > 0.85
                if shouldCommit {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                        settleProgress = 1
                    }
                    // Advance after the fold completes, then reset the scrub state.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                        pageIndex += 1
                        dragProgress = 0
                        settleProgress = 0
                    }
                } else {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        dragProgress = 0
                        settleProgress = 0
                    }
                }
            }
    }
}

// MARK: - The spread: two hinged scenery layers sharing the spine

private struct PaperPopupView_PopupSpread: View {
    let size: CGSize
    let progress: Double
    let outgoingIndex: Int
    let incomingIndex: Int

    var body: some View {
        let angles = hingeAngles(for: progress)
        // Spine line: the hinge sits a bit below center so scenery stands above it.
        let spineY = size.height * 0.74
        let stageH = size.height * 0.52
        let stageW = size.width * 0.80

        ZStack {
            // Outgoing scene — folds DOWN/back as the page turns.
            PaperPopupView_PopupLayer(
                scene: PaperPopupView_PopupScenes.scene(outgoingIndex),
                angle: angles.outgoing,
                stageW: stageW,
                stageH: stageH
            )
            .position(x: size.width / 2, y: spineY)
            .zIndex(zForAngle(angles.outgoing))

            // Incoming scene — stands UP from the fold to face the viewer.
            PaperPopupView_PopupLayer(
                scene: PaperPopupView_PopupScenes.scene(incomingIndex),
                angle: angles.incoming,
                stageW: stageW,
                stageH: stageH
            )
            .position(x: size.width / 2, y: spineY)
            .zIndex(zForAngle(angles.incoming))
        }
    }

    /// A layer that is more upright (angle nearer 0) should sit on top.
    private func zForAngle(_ angle: Double) -> Double {
        // 0° → high, ±90° → low.
        2.0 - abs(angle) / 90.0
    }
}

/// One scenery layer: its hinge edge coincides with the spread's spine, pivoting
/// about its bottom edge with perspective so it pops up off the page.
private struct PaperPopupView_PopupLayer: View {
    let scene: PaperPopupView_PopupScene
    let angle: Double
    let stageW: CGFloat
    let stageH: CGFloat

    var body: some View {
        PaperPopupView_SceneryArt(scene: scene, width: stageW, height: stageH)
            .frame(width: stageW, height: stageH)
            // Hinge about the bottom edge (the spine) with depth perspective.
            .rotation3DEffect(
                .degrees(angle),
                axis: (x: 1, y: 0, z: 0),
                anchor: .bottom,
                perspective: 0.62
            )
            // Bottom of art rests ON the spine line (.position centers it there).
            .offset(y: -stageH / 2)
            // Fold shadow deepens as the piece lays back; never fully hides art.
            .overlay {
                Color.black
                    .opacity(foldShade)
                    .blendMode(.multiply)
                    .allowsHitTesting(false)
            }
            .compositingGroup()
            .opacity(layerOpacity)
    }

    /// Darken as the piece rotates away from upright (depth shading).
    private var foldShade: Double {
        let t = abs(angle) / 90.0
        return 0.45 * t
    }

    /// Keep upright pieces fully visible; only the deeply-folded one dims a touch.
    private var layerOpacity: Double {
        let t = abs(angle) / 90.0
        return 1.0 - 0.25 * t
    }
}

// MARK: - Scenery art (bold silhouettes, readable at 120pt)

private struct PaperPopupView_SceneryArt: View {
    let scene: PaperPopupView_PopupScene
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .bottom) {
            // Stand-up backdrop card (the "page" the scene is printed on).
            RoundedRectangle(cornerRadius: width * 0.05, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [scene.sky.0, scene.sky.1],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: width, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: width * 0.05, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                )

            content
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: width * 0.05, style: .continuous))

            // Tab/base strip at the hinge that reads as the folded mount.
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.97, green: 0.95, blue: 0.88),
                                 Color(red: 0.85, green: 0.80, blue: 0.70)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: width, height: height * 0.07)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch scene.kind {
        case .meadow:    PaperPopupView_MeadowArt(scene: scene, w: width, h: height)
        case .mountains: PaperPopupView_MountainArt(scene: scene, w: width, h: height)
        case .city:      PaperPopupView_CityArt(scene: scene, w: width, h: height)
        }
    }
}

private struct PaperPopupView_MeadowArt: View {
    let scene: PaperPopupView_PopupScene
    let w: CGFloat
    let h: CGFloat

    var body: some View {
        ZStack {
            // Sun.
            Circle()
                .fill(scene.accent)
                .frame(width: w * 0.20, height: w * 0.20)
                .position(x: w * 0.76, y: h * 0.26)
                .shadow(color: scene.accent.opacity(0.6), radius: w * 0.04)

            // Rolling ground.
            PaperPopupView_HillShape()
                .fill(scene.ground)
                .frame(width: w, height: h * 0.5)
                .position(x: w / 2, y: h * 0.78)

            // House.
            PaperPopupView_HouseShape()
                .fill(Color(red: 0.86, green: 0.42, blue: 0.34))
                .frame(width: w * 0.28, height: h * 0.34)
                .position(x: w * 0.36, y: h * 0.64)

            // Trees.
            PaperPopupView_TreeShape()
                .fill(Color(red: 0.22, green: 0.50, blue: 0.30))
                .frame(width: w * 0.16, height: h * 0.30)
                .position(x: w * 0.66, y: h * 0.66)
            PaperPopupView_TreeShape()
                .fill(Color(red: 0.26, green: 0.56, blue: 0.34))
                .frame(width: w * 0.12, height: h * 0.22)
                .position(x: w * 0.80, y: h * 0.70)
        }
    }
}

private struct PaperPopupView_MountainArt: View {
    let scene: PaperPopupView_PopupScene
    let w: CGFloat
    let h: CGFloat

    var body: some View {
        ZStack {
            // Moon.
            Circle()
                .fill(scene.accent)
                .frame(width: w * 0.16, height: w * 0.16)
                .position(x: w * 0.74, y: h * 0.24)
                .shadow(color: scene.accent.opacity(0.5), radius: w * 0.05)

            // Back peaks.
            PaperPopupView_PeaksShape(peaks: 3, jitter: 0.0)
                .fill(scene.ground.opacity(0.7))
                .frame(width: w, height: h * 0.55)
                .position(x: w / 2, y: h * 0.74)

            // Front peaks (snow-capped).
            PaperPopupView_PeaksShape(peaks: 2, jitter: 0.12)
                .fill(Color(red: 0.26, green: 0.30, blue: 0.46))
                .frame(width: w, height: h * 0.42)
                .position(x: w / 2, y: h * 0.82)

            PaperPopupView_SnowCapsShape()
                .fill(Color.white.opacity(0.9))
                .frame(width: w, height: h * 0.42)
                .position(x: w / 2, y: h * 0.82)
        }
    }
}

private struct PaperPopupView_CityArt: View {
    let scene: PaperPopupView_PopupScene
    let w: CGFloat
    let h: CGFloat

    var body: some View {
        ZStack {
            // Stars.
            ForEach(0..<6, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: w * 0.018, height: w * 0.018)
                    .position(
                        x: w * (0.12 + 0.14 * CGFloat(i)),
                        y: h * (0.18 + 0.06 * CGFloat(i % 3))
                    )
            }
            // Crescent accent.
            Circle()
                .fill(scene.accent)
                .frame(width: w * 0.13, height: w * 0.13)
                .position(x: w * 0.80, y: h * 0.22)

            // Skyline.
            PaperPopupView_SkylineShape()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.22, green: 0.24, blue: 0.40),
                                 Color(red: 0.12, green: 0.13, blue: 0.24)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: w, height: h * 0.55)
                .position(x: w / 2, y: h * 0.76)

            // Lit windows.
            PaperPopupView_WindowsShape()
                .fill(scene.accent.opacity(0.9))
                .frame(width: w, height: h * 0.55)
                .position(x: w / 2, y: h * 0.76)
        }
    }
}

// MARK: - Shapes

private struct PaperPopupView_HillShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.midX, y: rect.minY)
        )
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct PaperPopupView_HouseShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let roofH = rect.height * 0.42
        let bodyTop = rect.minY + roofH
        // Roof.
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: bodyTop))
        p.addLine(to: CGPoint(x: rect.minX, y: bodyTop))
        p.closeSubpath()
        // Body.
        let bodyW = rect.width * 0.74
        let bx = rect.minX + (rect.width - bodyW) / 2
        p.addRect(CGRect(x: bx, y: bodyTop, width: bodyW, height: rect.maxY - bodyTop))
        return p
    }
}

private struct PaperPopupView_TreeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Trunk.
        let trunkW = rect.width * 0.18
        let trunkH = rect.height * 0.26
        p.addRect(CGRect(
            x: rect.midX - trunkW / 2,
            y: rect.maxY - trunkH,
            width: trunkW, height: trunkH
        ))
        // Three stacked canopy triangles, widening toward the base.
        let tiers = 3
        let canopyH = rect.height - trunkH
        for i in 0..<tiers {
            let f = CGFloat(i)
            let top: CGFloat = rect.minY + canopyH * (f / CGFloat(tiers)) * 0.8
            let bottom: CGFloat = rect.minY + canopyH * (f + 1.4) / CGFloat(tiers) * 0.8
            let tierW: CGFloat = rect.width * (0.42 + 0.18 * f)
            p.move(to: CGPoint(x: rect.midX, y: top))
            p.addLine(to: CGPoint(x: rect.midX + tierW / 2, y: bottom))
            p.addLine(to: CGPoint(x: rect.midX - tierW / 2, y: bottom))
            p.closeSubpath()
        }
        return p
    }
}

private struct PaperPopupView_PeaksShape: Shape {
    let peaks: Int
    let jitter: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        let segment = rect.width / CGFloat(peaks)
        for i in 0..<peaks {
            let baseX = rect.minX + segment * CGFloat(i)
            let peakX = baseX + segment * (0.5 + jitter * (i.isMultiple(of: 2) ? 1 : -1))
            let peakY = rect.minY + rect.height * (0.05 + jitter)
            p.addLine(to: CGPoint(x: peakX, y: peakY))
            p.addLine(to: CGPoint(x: baseX + segment, y: rect.maxY))
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct PaperPopupView_SnowCapsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let segment = rect.width / 2
        for i in 0..<2 {
            let baseX = rect.minX + segment * CGFloat(i)
            let peakX = baseX + segment * (0.5 + 0.12 * (i.isMultiple(of: 2) ? 1 : -1))
            let peakY = rect.minY + rect.height * 0.17
            let capH = rect.height * 0.16
            let leftX = peakX - segment * 0.16
            let rightX = peakX + segment * 0.16
            p.move(to: CGPoint(x: peakX, y: peakY))
            p.addLine(to: CGPoint(x: rightX, y: peakY + capH))
            p.addQuadCurve(
                to: CGPoint(x: leftX, y: peakY + capH),
                control: CGPoint(x: peakX, y: peakY + capH * 0.5)
            )
            p.closeSubpath()
        }
        return p
    }
}

private struct PaperPopupView_SkylineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let heights: [CGFloat] = [0.45, 0.72, 0.55, 0.88, 0.62, 0.78, 0.5]
        let n = heights.count
        let bw = rect.width / CGFloat(n)
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        for i in 0..<n {
            let x0 = rect.minX + bw * CGFloat(i)
            let topY = rect.maxY - rect.height * heights[i]
            p.addLine(to: CGPoint(x: x0, y: topY))
            p.addLine(to: CGPoint(x: x0 + bw, y: topY))
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct PaperPopupView_WindowsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let heights: [CGFloat] = [0.45, 0.72, 0.55, 0.88, 0.62, 0.78, 0.5]
        let n = heights.count
        let bw = rect.width / CGFloat(n)
        let win = bw * 0.18
        for i in 0..<n {
            let x0 = rect.minX + bw * CGFloat(i)
            let topY = rect.maxY - rect.height * heights[i]
            let rows = max(1, Int((rect.maxY - topY) / (win * 2.2)))
            for r in 0..<rows {
                for c in 0..<2 {
                    if (r + c + i).isMultiple(of: 2) { continue }
                    let wx = x0 + bw * (0.28 + 0.40 * CGFloat(c))
                    let wy = topY + win * 1.6 + CGFloat(r) * win * 2.2
                    if wy + win > rect.maxY { continue }
                    p.addRect(CGRect(x: wx, y: wy, width: win, height: win * 1.3))
                }
            }
        }
        return p
    }
}
