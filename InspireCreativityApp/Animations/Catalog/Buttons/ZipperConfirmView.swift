// catalog-id: btn-zipper-confirm
import SwiftUI

// MARK: - ZipperConfirmView
// Long-press then drag a zipper pull across the button. Interlocking teeth
// mesh behind the pull until it fully closes and locks into a confirmed state.
// demo == true  -> self-driving TimelineView loop (silent, no haptics).
// demo == false -> real LongPressGesture.sequenced(before: DragGesture).
struct ZipperConfirmView: View {
    var demo: Bool = false

    // Interactive state
    @State private var progress: CGFloat = 0          // 0 = open, 1 = closed/locked
    @State private var locked: Bool = false           // flips false->true to fire haptic

    // Live drag position during the sequenced gesture. @GestureState auto-resets
    // to nil on release, so meshing follows the finger live, then falls back to the
    // committed `progress` when the drag ends.
    @GestureState private var dragLocationX: CGFloat? = nil

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                background

                if demo {
                    demoZipper(in: size)
                } else {
                    interactiveZipper(in: size)
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.success, trigger: locked) // declarative; only flips when !demo
    }

    // MARK: Background

    private var background: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.09, blue: 0.07),
                        Color(red: 0.16, green: 0.14, blue: 0.10)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .padding(4)
    }

    // MARK: Demo driver (pure function of timeline.date)

    private func demoZipper(in size: CGSize) -> some View {
        TimelineView(.animation) { context in
            let p = ZipperConfirmView.demoProgress(at: context.date)
            ZipperConfirmView_ZipperBody(progress: p, locked: p >= 0.999, size: size)
        }
    }

    /// Cycle: ease close 0->1 (~2s), hold locked (~0.8s), snap open (~0.4s), pause (~0.6s).
    private static func demoProgress(at date: Date) -> CGFloat {
        let cycle: Double = 3.8
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)

        let closeDur: Double = 2.0
        let holdDur: Double = 0.8
        let openDur: Double = 0.4

        if t < closeDur {
            // ease-in-out close
            let x = t / closeDur
            return CGFloat(easeInOut(x))
        } else if t < closeDur + holdDur {
            return 1.0
        } else if t < closeDur + holdDur + openDur {
            // quick snap open
            let x = (t - closeDur - holdDur) / openDur
            return CGFloat(1.0 - easeInOut(x))
        } else {
            return 0.0
        }
    }

    private static func easeInOut(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        return c < 0.5 ? 2 * c * c : 1 - pow(-2 * c + 2, 2) / 2
    }

    // MARK: Interactive driver

    private func interactiveZipper(in size: CGSize) -> some View {
        let width = max(size.width, 1)
        // Effective progress: live drag while the finger is down, committed value otherwise.
        let liveProgress: CGFloat = {
            if let x = dragLocationX {
                return min(max(x / width, 0), 1)
            }
            return progress
        }()

        return ZipperConfirmView_ZipperBody(progress: liveProgress, locked: locked, size: size)
            .contentShape(Rectangle())
            .gesture(zipperGesture(width: width))
    }

    private func zipperGesture(width: CGFloat) -> some Gesture {
        // LongPress arms, then a 0-distance drag drives close progress. We use
        // .updating + .onEnded (not .onChanged): SequenceGesture.Value is not
        // Equatable, so .onChanged would fail to type-check.
        LongPressGesture(minimumDuration: 0.1)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($dragLocationX) { value, state, _ in
                switch value {
                case .first:
                    // long-press arming: keep showing committed state
                    state = nil
                case .second(_, let drag):
                    if let drag {
                        state = drag.location.x
                    }
                }
            }
            .onEnded { value in
                if locked { return } // lock is terminal; ignore further drag
                let endX: CGFloat
                switch value {
                case .first:
                    endX = progress * width
                case .second(_, let drag):
                    endX = drag?.location.x ?? (progress * width)
                }
                let p = min(max(endX / max(width, 1), 0), 1)
                if p >= 0.95 {
                    completeLock()
                } else {
                    withAnimation(.interpolatingSpring(stiffness: 180, damping: 16)) {
                        progress = 0
                    }
                }
            }
    }

    private func completeLock() {
        withAnimation(.interpolatingSpring(stiffness: 200, damping: 14)) {
            progress = 1
        }
        if !locked {
            locked = true // fires .success haptic via sensoryFeedback(trigger:)
        }
    }
}

// MARK: - Zipper body (single renderer used by both drivers)

private struct ZipperConfirmView_ZipperBody: View {
    let progress: CGFloat   // 0 open .. 1 closed
    let locked: Bool
    let size: CGSize

    // Visual tuning
    private let toothCount: Int = 16

    private var confirmedTint: Color {
        Color(red: 0.42, green: 0.78, blue: 0.45) // confirmed green
    }
    private var openTint: Color {
        Color(red: 0.74, green: 0.70, blue: 0.62) // brushed-metal tape
    }
    private var teethMetal: Color {
        Color(red: 0.86, green: 0.84, blue: 0.78)
    }

    var body: some View {
        let w = size.width
        let h = size.height
        let inset: CGFloat = 16
        let usableW = max(w - inset * 2, 1)
        let seamY = h / 2
        let pullX = inset + usableW * progress

        // Max vertical separation of the two tapes at the fully-open far edge.
        let maxGap = min(h * 0.22, 26)

        return ZStack {
            // The two tapes + teeth
            ForEach(0..<toothCount, id: \.self) { i in
                tooth(
                    index: i,
                    inset: inset,
                    usableW: usableW,
                    seamY: seamY,
                    pullX: pullX,
                    maxGap: maxGap
                )
            }

            // Confirmed glow wash on the closed (left) portion
            closedWash(inset: inset, usableW: usableW, pullX: pullX)

            // Pull head straddling the seam
            pullHead(at: pullX, seamY: seamY)

            // Status label
            label
                .frame(width: w, height: h, alignment: .center)
        }
        .frame(width: w, height: h)
    }

    // MARK: Per-tooth pair (top points down, bottom points up, interleaved)

    @ViewBuilder
    private func tooth(
        index i: Int,
        inset: CGFloat,
        usableW: CGFloat,
        seamY: CGFloat,
        pullX: CGFloat,
        maxGap: CGFloat
    ) -> some View {
        let step = usableW / CGFloat(toothCount)
        let toothW = step * 0.92
        let centerX = inset + step * (CGFloat(i) + 0.5)

        // Is this tooth behind (left of) the pull head? -> meshed/closed.
        let meshed = centerX <= pullX

        // Gap below the pull tapers from 0 (at the pull) to maxGap at the far edge.
        let distRight = max(centerX - pullX, 0)
        let denom = max(inset + usableW - pullX, 1)
        let gapFraction = distRight / denom
        let gap = meshed ? 0 : maxGap * gapFraction

        let toothH = min(step * 0.95, seamY * 0.78)
        let toothColor = meshed ? confirmedTint : openTint

        // Top tape tooth points DOWN toward the seam.
        let topY = seamY - gap - toothH / 2
        // Bottom tape tooth points UP toward the seam, offset half a tooth horizontally.
        let bottomY = seamY + gap + toothH / 2
        let bottomX = centerX + step * 0.5

        ZStack {
            ZipperConfirmView_ToothShape(pointingDown: true)
                .fill(
                    LinearGradient(
                        colors: [toothColor.opacity(0.95), toothColor.opacity(0.6)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    ZipperConfirmView_ToothShape(pointingDown: true)
                        .stroke(Color.black.opacity(0.18), lineWidth: 0.6)
                )
                .frame(width: toothW, height: toothH)
                .position(x: centerX, y: topY)

            ZipperConfirmView_ToothShape(pointingDown: false)
                .fill(
                    LinearGradient(
                        colors: [toothColor.opacity(0.6), toothColor.opacity(0.95)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    ZipperConfirmView_ToothShape(pointingDown: false)
                        .stroke(Color.black.opacity(0.18), lineWidth: 0.6)
                )
                .frame(width: toothW, height: toothH)
                .position(x: bottomX, y: bottomY)
        }
        .shadow(color: .black.opacity(meshed ? 0.25 : 0.12), radius: 1, y: 0.5)
    }

    // MARK: Confirmed wash over the meshed section

    private func closedWash(inset: CGFloat, usableW: CGFloat, pullX: CGFloat) -> some View {
        let washW = max(pullX - inset, 0)
        return RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(confirmedTint.opacity(0.16))
            .frame(width: washW, height: size.height * 0.5)
            .position(x: inset + washW / 2, y: size.height / 2)
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }

    // MARK: Pull head

    private func pullHead(at x: CGFloat, seamY: CGFloat) -> some View {
        let bodyW: CGFloat = 22
        let bodyH = min(size.height * 0.6, 44)
        return ZStack {
            // Slider body (rounded trapezoid-ish)
            ZipperConfirmView_PullHeadShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.93, green: 0.92, blue: 0.88),
                            Color(red: 0.62, green: 0.60, blue: 0.55)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    ZipperConfirmView_PullHeadShape().stroke(Color.black.opacity(0.25), lineWidth: 0.8)
                )
                .frame(width: bodyW, height: bodyH)

            // Tab
            Capsule()
                .fill(Color(red: 0.34, green: 0.32, blue: 0.29))
                .frame(width: 5, height: bodyH * 0.5)
                .offset(y: bodyH * 0.5)
        }
        .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
        .position(x: x, y: seamY)
        .allowsHitTesting(false)
    }

    // MARK: Label

    @ViewBuilder
    private var label: some View {
        if locked || progress >= 0.95 {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                Text("Confirmed")
                    .fontWeight(.semibold)
            }
            .font(.system(size: 14, design: .rounded))
            .foregroundStyle(confirmedTint)
            .opacity(0.95)
            .transition(.opacity)
        } else {
            Text("Slide to confirm")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.55 - Double(progress) * 0.45))
        }
    }
}

// MARK: - Shapes

/// A single zipper tooth: a chamfered triangle/trapezoid pointing up or down.
private struct ZipperConfirmView_ToothShape: Shape {
    let pointingDown: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let cham = w * 0.28 // chamfer on the tip so teeth read as metal nubs
        if pointingDown {
            p.move(to: CGPoint(x: 0, y: 0))
            p.addLine(to: CGPoint(x: w, y: 0))
            p.addLine(to: CGPoint(x: w, y: h * 0.45))
            p.addLine(to: CGPoint(x: w - cham, y: h))
            p.addLine(to: CGPoint(x: cham, y: h))
            p.addLine(to: CGPoint(x: 0, y: h * 0.45))
        } else {
            p.move(to: CGPoint(x: cham, y: 0))
            p.addLine(to: CGPoint(x: w - cham, y: 0))
            p.addLine(to: CGPoint(x: w, y: h * 0.55))
            p.addLine(to: CGPoint(x: w, y: h))
            p.addLine(to: CGPoint(x: 0, y: h))
            p.addLine(to: CGPoint(x: 0, y: h * 0.55))
        }
        p.closeSubpath()
        return p
    }
}

/// The zipper pull/slider body.
private struct ZipperConfirmView_PullHeadShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let r: CGFloat = min(w, h) * 0.28
        var p = Path()
        // Narrower at the bottom (where the tab hangs), wider at the top.
        let topInset = w * 0.04
        let botInset = w * 0.18
        p.move(to: CGPoint(x: topInset + r, y: 0))
        p.addLine(to: CGPoint(x: w - topInset - r, y: 0))
        p.addQuadCurve(to: CGPoint(x: w - topInset, y: r),
                       control: CGPoint(x: w - topInset, y: 0))
        p.addLine(to: CGPoint(x: w - botInset, y: h - r))
        p.addQuadCurve(to: CGPoint(x: w - botInset - r, y: h),
                       control: CGPoint(x: w - botInset, y: h))
        p.addLine(to: CGPoint(x: botInset + r, y: h))
        p.addQuadCurve(to: CGPoint(x: botInset, y: h - r),
                       control: CGPoint(x: botInset, y: h))
        p.addLine(to: CGPoint(x: topInset, y: r))
        p.addQuadCurve(to: CGPoint(x: topInset + r, y: 0),
                       control: CGPoint(x: topInset, y: 0))
        p.closeSubpath()
        return p
    }
}
