// catalog-id: tr-zipper-unzip
import SwiftUI

// MARK: - Zipper Unzip

/// Two halves of a front cover are joined by interleaving Path-drawn zipper
/// teeth along a center seam. Pulling the slider down separates the halves —
/// the region the puller has passed (above it) spreads open to reveal the
/// destination view behind, while the region below stays meshed.
///
/// progress (p): 0 = fully zipped (puller at top, cover closed)
///               1 = fully unzipped (puller at bottom, destination revealed)
struct ZipperUnzipTransitionView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { proxy in
            ZipperUnzipTransitionView_ZipperBoard(size: proxy.size, demo: demo)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Board

private struct ZipperUnzipTransitionView_ZipperBoard: View {
    let size: CGSize
    let demo: Bool

    // Interactive state
    @State private var progress: CGFloat = 0
    @State private var dragStartProgress: CGFloat? = nil

    // Geometry-derived tooth metrics
    private var toothHeight: CGFloat { max(10, size.height / 16) }
    private var teethCount: Int { max(6, Int(size.height / toothHeight)) }

    // Where the puller sits vertically for a given progress.
    private func pullerY(_ p: CGFloat) -> CGFloat { p * size.height }

    var body: some View {
        if demo {
            PhaseAnimator([CGFloat(0), CGFloat(1)]) { phase in
                content(for: phase)
            } animation: { _ in
                .easeInOut(duration: 1.6)
            }
        } else {
            content(for: progress)
                .gesture(dragGesture)
                .sensoryFeedback(.impact(weight: .light, intensity: 0.6),
                                 trigger: crossedToothCount(progress))
        }
    }

    // The live progress value the visuals should use:
    // in demo it follows the phase; interactively it follows @State.
    private func content(for p: CGFloat) -> some View {
        let py = pullerY(p)
        return ZStack {
            destinationLayer(p: p)
            frontHalves(p: p, pullerY: py)
            seam(p: p, pullerY: py)
            puller(p: p, pullerY: py)
        }
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .contentShape(Rectangle())
    }

    private var cornerRadius: CGFloat { min(size.width, size.height) * 0.10 }

    // MARK: Destination (always mounted, revealed as the cover opens)

    private func destinationLayer(p: CGFloat) -> some View {
        let reveal = Double(min(1, p * 1.2))
        return ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.16, green: 0.36, blue: 0.62),
                    Color(red: 0.34, green: 0.20, blue: 0.55)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            VStack(spacing: size.height * 0.05) {
                Image(systemName: "sparkles")
                    .font(.system(size: min(size.width, size.height) * 0.22,
                                  weight: .semibold))
                    .foregroundStyle(.white)
                Text("Unzipped")
                    .font(.system(size: min(size.width, size.height) * 0.10,
                                  weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .opacity(reveal)
            .scaleEffect(0.92 + 0.08 * reveal)
        }
    }

    // MARK: Front cover halves

    private func frontHalves(p: CGFloat, pullerY: CGFloat) -> some View {
        // Each half splays its top corner outward as the puller descends,
        // forming a V-shaped opening above the puller while staying sealed
        // at the center seam below it.
        ZStack {
            coverHalf(isLeft: true, p: p, pullerY: pullerY)
            coverHalf(isLeft: false, p: p, pullerY: pullerY)
        }
    }

    private func coverHalf(isLeft: Bool, p: CGFloat, pullerY: CGFloat) -> some View {
        let halfW = size.width / 2
        // Maximum horizontal splay of a half's top corner once fully opened.
        let maxSpread = halfW * 0.96
        let spread = maxSpread * easeOut(p)
        let dir: CGFloat = isLeft ? -1 : 1

        return ZipperUnzipTransitionView_ZipperHalfClip(isLeft: isLeft, pullerY: pullerY, spread: spread, size: size)
            .fill(coverGradient(isLeft: isLeft))
            .overlay(
                ZipperUnzipTransitionView_ZipperHalfClip(isLeft: isLeft, pullerY: pullerY, spread: spread, size: size)
                    .fill(coverSheen(isLeft: isLeft))
            )
            .shadow(color: .black.opacity(0.35 * Double(p)),
                    radius: 8 * p, x: dir * 4 * p, y: 0)
    }

    private func coverGradient(isLeft: Bool) -> LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.12, green: 0.13, blue: 0.17),
                Color(red: 0.06, green: 0.07, blue: 0.10)
            ],
            startPoint: isLeft ? .topLeading : .topTrailing,
            endPoint: isLeft ? .bottomTrailing : .bottomLeading
        )
    }

    private func coverSheen(isLeft: Bool) -> LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.10),
                Color.white.opacity(0.0),
                Color.black.opacity(0.12)
            ],
            startPoint: isLeft ? .leading : .trailing,
            endPoint: isLeft ? .trailing : .leading
        )
    }

    // MARK: Seam (the teeth)

    private func seam(p: CGFloat, pullerY: CGFloat) -> some View {
        let halfW = size.width / 2
        let maxSpread = halfW * 0.96
        let spread = maxSpread * easeOut(p)

        return ZStack {
            // Meshed tape below the puller — a darker channel.
            ZipperUnzipTransitionView_ZipperTape(pullerY: pullerY, size: size)
                .fill(Color(red: 0.04, green: 0.04, blue: 0.06))

            ZipperUnzipTransitionView_ZipperTeeth(pullerY: pullerY,
                        spread: spread,
                        toothHeight: toothHeight,
                        teethCount: teethCount,
                        size: size)
                .fill(teethGradient)
                .overlay(
                    ZipperUnzipTransitionView_ZipperTeeth(pullerY: pullerY,
                                spread: spread,
                                toothHeight: toothHeight,
                                teethCount: teethCount,
                                size: size)
                        .stroke(Color.black.opacity(0.35), lineWidth: 0.75)
                )
        }
    }

    private var teethGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.86, green: 0.87, blue: 0.90),
                Color(red: 0.55, green: 0.57, blue: 0.62),
                Color(red: 0.80, green: 0.81, blue: 0.85)
            ],
            startPoint: .leading, endPoint: .trailing
        )
    }

    // MARK: Puller (slider)

    private func puller(p: CGFloat, pullerY: CGFloat) -> some View {
        let bodyW = max(14, size.width * 0.14)
        let bodyH = max(18, size.height * 0.10)
        let tabH = bodyH * 0.85

        return VStack(spacing: 0) {
            // Trapezoidal slider body
            ZipperUnzipTransitionView_PullerBody()
                .fill(pullerGradient)
                .overlay(
                    ZipperUnzipTransitionView_PullerBody()
                        .stroke(Color.black.opacity(0.4), lineWidth: 1)
                )
                .frame(width: bodyW, height: bodyH)
            // Pull tab
            ZStack {
                Capsule()
                    .fill(pullerGradient)
                    .overlay(Capsule().stroke(Color.black.opacity(0.4), lineWidth: 1))
                Capsule()
                    .stroke(Color.black.opacity(0.25), lineWidth: 1)
                    .frame(width: bodyW * 0.28, height: tabH * 0.55)
            }
            .frame(width: bodyW * 0.62, height: tabH)
        }
        .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
        .position(x: size.width / 2, y: max(bodyH / 2, pullerY))
    }

    private var pullerGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.93, green: 0.94, blue: 0.97),
                Color(red: 0.62, green: 0.64, blue: 0.70),
                Color(red: 0.40, green: 0.42, blue: 0.47)
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    // MARK: Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStartProgress == nil { dragStartProgress = progress }
                let base = dragStartProgress ?? progress
                let delta = value.translation.height / max(1, size.height)
                progress = clamp(base + delta)
            }
            .onEnded { value in
                dragStartProgress = nil
                // Use velocity (predicted end) to decide open vs. snap-back.
                let predicted = value.predictedEndTranslation.height
                let base = progress
                let goOpen: Bool
                if predicted > size.height * 0.25 {
                    goOpen = true
                } else if predicted < -size.height * 0.25 {
                    goOpen = false
                } else {
                    goOpen = base > 0.5
                }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                    progress = goOpen ? 1 : 0
                }
            }
    }

    // MARK: Helpers

    private func crossedToothCount(_ p: CGFloat) -> Int {
        Int(p * CGFloat(teethCount))
    }

    private func clamp(_ v: CGFloat) -> CGFloat { min(1, max(0, v)) }

    private func easeOut(_ t: CGFloat) -> CGFloat {
        let c = clamp(t)
        return 1 - (1 - c) * (1 - c)
    }
}

// MARK: - Cover half clip Shape
//
// Each half occupies its side of the board. Its inner edge is flush at the
// center seam from the bottom up to the puller (meshed), then splays out to
// `spread` at the very top so the opening widens into a V above the puller.

private struct ZipperUnzipTransitionView_ZipperHalfClip: Shape {
    let isLeft: Bool
    var pullerY: CGFloat
    var spread: CGFloat
    let size: CGSize

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(pullerY, spread) }
        set { pullerY = newValue.first; spread = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let centerX = rect.midX
        let py = max(0, min(rect.height, pullerY))
        // Inner edge is flush at the center seam from the bottom up to the
        // puller (meshed), then splays out to `spread` at the very top so the
        // opening widens into a V above the puller — closed below, open above.
        var p = Path()

        if isLeft {
            // Down the left edge, across the bottom, up the inner (center)
            // edge to the puller, then out to the splayed top corner.
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addLine(to: CGPoint(x: centerX, y: rect.maxY))
            p.addLine(to: CGPoint(x: centerX, y: py))                   // sealed up to puller
            p.addLine(to: CGPoint(x: centerX - spread, y: rect.minY))   // splay at top
            p.closeSubpath()
        } else {
            p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: centerX, y: rect.maxY))
            p.addLine(to: CGPoint(x: centerX, y: py))
            p.addLine(to: CGPoint(x: centerX + spread, y: rect.minY))
            p.closeSubpath()
        }
        return p
    }
}

// MARK: - Zipper tape (meshed channel below puller)

private struct ZipperUnzipTransitionView_ZipperTape: Shape {
    var pullerY: CGFloat
    let size: CGSize

    var animatableData: CGFloat {
        get { pullerY }
        set { pullerY = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let w = max(3, rect.width * 0.045)
        let py = max(0, min(rect.height, pullerY))
        let r = CGRect(x: rect.midX - w / 2, y: py,
                       width: w, height: max(0, rect.maxY - py))
        return Path(roundedRect: r, cornerRadius: w / 2)
    }
}

// MARK: - Zipper teeth Shape
//
// Interleaved trapezoids along the seam. Below the puller they mesh at the
// center (left and right teeth interlock). Above the puller each side's teeth
// ride outward with the opening half, so they un-mesh tooth-by-tooth.

private struct ZipperUnzipTransitionView_ZipperTeeth: Shape {
    var pullerY: CGFloat
    var spread: CGFloat
    let toothHeight: CGFloat
    let teethCount: Int
    let size: CGSize

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(pullerY, spread) }
        set { pullerY = newValue.first; spread = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centerX = rect.midX
        let py = max(0, min(rect.height, pullerY))
        let toothW = max(6, rect.width * 0.075)
        let h = toothHeight
        let count = teethCount

        for i in 0..<count {
            let topY = CGFloat(i) * h
            let isLeftTooth = (i % 2 == 0)
            // Is this tooth above the puller (separated) or below (meshed)?
            let isOpen = topY + h * 0.5 < py
            // Fraction of how far above the puller (for a graded V spread).
            let openFrac: CGFloat = isOpen
                ? min(1, max(0, (py - (topY + h * 0.5)) / max(1, py)))
                : 0
            let sideSpread = spread * openFrac
            let dir: CGFloat = isLeftTooth ? -1 : 1
            // Meshed teeth poke slightly past center; opened ones ride out.
            let baseOffset: CGFloat = isLeftTooth ? -toothW * 0.15 : toothW * 0.15
            let cx = centerX + baseOffset + dir * sideSpread

            appendTooth(to: &path,
                        centerX: cx,
                        topY: topY,
                        toothW: toothW,
                        h: h,
                        pointsRight: isLeftTooth)
        }
        return path
    }

    // A trapezoid tooth. Left-side teeth point right (into the seam), and
    // right-side teeth point left, so they interleave when meshed.
    private func appendTooth(to path: inout Path,
                             centerX: CGFloat,
                             topY: CGFloat,
                             toothW: CGFloat,
                             h: CGFloat,
                             pointsRight: Bool) {
        let halfW = toothW / 2
        let inset = toothW * 0.30
        let midY = topY + h / 2
        let top = topY + h * 0.12
        let bot = topY + h * 0.88

        var t = Path()
        if pointsRight {
            // wide on the left, tapered point toward the right
            t.move(to: CGPoint(x: centerX - halfW, y: top))
            t.addLine(to: CGPoint(x: centerX + halfW - inset, y: top))
            t.addLine(to: CGPoint(x: centerX + halfW, y: midY))
            t.addLine(to: CGPoint(x: centerX + halfW - inset, y: bot))
            t.addLine(to: CGPoint(x: centerX - halfW, y: bot))
        } else {
            t.move(to: CGPoint(x: centerX + halfW, y: top))
            t.addLine(to: CGPoint(x: centerX - halfW + inset, y: top))
            t.addLine(to: CGPoint(x: centerX - halfW, y: midY))
            t.addLine(to: CGPoint(x: centerX - halfW + inset, y: bot))
            t.addLine(to: CGPoint(x: centerX + halfW, y: bot))
        }
        t.closeSubpath()
        path.addPath(t)
    }
}

// MARK: - Puller body Shape (trapezoid slider)

private struct ZipperUnzipTransitionView_PullerBody: Shape {
    func path(in rect: CGRect) -> Path {
        let inset = rect.width * 0.18
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + inset, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
