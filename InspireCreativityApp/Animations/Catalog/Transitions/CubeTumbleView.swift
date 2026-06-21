// catalog-id: tr-cube-tumble
import SwiftUI

// MARK: - Cube Tumble
// Pages map to the faces of a 3D cube that rotates through 90° turns with
// true perspective foreshortening, advancing one view per face.
//
// Mechanism: a two-face hinge. Both faces share the same center pivot
// (axis Y, anchor .center) with a `perspective:` m34 set on
// `.rotation3DEffect`. The outgoing face rotates 0→90° while the incoming
// face rotates −90°→0° with the next page's content; a z-order / opacity
// swap around the edge-on point keeps the seam from tearing and never
// reveals mirrored backface content.
//
// demo == true  : a self-driving TimelineView(.animation) continuously
//                 tumbles the cube through successive faces on a ~3s/face
//                 loop — always legible, never blank.
// demo == false : a horizontal DragGesture(minimumDistance: 0) scrubs the
//                 rotation mid-turn; on release it rubber-bands to the
//                 nearest 90° face, using predictedEndTranslation to decide
//                 whether to advance or snap back, with a spring + haptic.

struct CubeTumbleView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) * 0.74
            ZStack {
                CubeTumbleView_CubeBackdrop()
                Group {
                    if demo {
                        CubeTumbleView_DemoCube(side: side)
                    } else {
                        CubeTumbleView_InteractiveCube(side: side)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Shared model

private enum CubeTumbleView_CubePalette {
    // Four distinct page faces so the rotation reads as *pages* turning,
    // not one panel spinning. Returns a top/bottom gradient pair.
    static func face(_ index: Int) -> (Color, Color, String) {
        let i = ((index % 4) + 4) % 4
        switch i {
        case 0:
            return (Color(red: 0.30, green: 0.55, blue: 0.98),
                    Color(red: 0.16, green: 0.30, blue: 0.74), "01")
        case 1:
            return (Color(red: 0.98, green: 0.46, blue: 0.40),
                    Color(red: 0.78, green: 0.22, blue: 0.34), "02")
        case 2:
            return (Color(red: 0.42, green: 0.86, blue: 0.62),
                    Color(red: 0.16, green: 0.55, blue: 0.42), "03")
        default:
            return (Color(red: 0.86, green: 0.66, blue: 0.36),
                    Color(red: 0.62, green: 0.40, blue: 0.16), "04")
        }
    }
}

private struct CubeTumbleView_CubeBackdrop: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.06, blue: 0.09),
                Color(red: 0.09, green: 0.10, blue: 0.15)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - A single cube face

private struct CubeTumbleView_CubeFace: View {
    let pageIndex: Int
    let side: CGFloat

    var body: some View {
        let (top, bottom, label) = CubeTumbleView_CubePalette.face(pageIndex)
        RoundedRectangle(cornerRadius: side * 0.10, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [top, bottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(faceDetail(label: label, top: top))
            .overlay(
                RoundedRectangle(cornerRadius: side * 0.10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
            )
            .frame(width: side, height: side)
    }

    private func faceDetail(label: String, top: Color) -> some View {
        ZStack {
            // A soft sheen so the perspective foreshortening catches light.
            RoundedRectangle(cornerRadius: side * 0.10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.28), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
            VStack(spacing: side * 0.06) {
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: side * 0.18, height: side * 0.18)
                    .overlay(
                        Text(label)
                            .font(.system(size: side * 0.09, weight: .heavy, design: .rounded))
                            .foregroundColor(top)
                    )
                Text("PAGE")
                    .font(.system(size: side * 0.085, weight: .bold, design: .rounded))
                    .tracking(side * 0.02)
                    .foregroundColor(.white.opacity(0.92))
            }
        }
    }
}

// MARK: - Hinge: two faces sharing the center pivot

private struct CubeTumbleView_CubeHinge: View {
    /// Page index currently considered the "front" baseline.
    let basePage: Int
    /// Continuous turn progress in degrees within the current 90° step.
    /// 0   → base page flat and centered.
    /// 90  → next page flat and centered.
    /// May go slightly negative or past 90 while scrubbing.
    let degrees: Double
    let side: CGFloat
    /// Direction of travel: +1 advancing to next page, used for content.
    let direction: Int

    private var perspective: CGFloat { 0.62 }

    var body: some View {
        let t = degrees
        // Outgoing (base) face: rotates 0 → 90.
        // Incoming (neighbor) face: rotates -90 → 0, showing adjacent page.
        let outgoingAngle = t
        let incomingAngle = t - 90.0 * Double(directionSign)

        let outgoingPage = basePage
        let incomingPage = basePage + directionSign

        // Crossfade / z-order swap around the edge-on midpoint (45°).
        let mid = 45.0
        let outFront = abs(t) < mid

        ZStack {
            face(page: incomingPage, angle: incomingAngle)
                .opacity(faceOpacity(for: incomingAngle))
                .zIndex(outFront ? 0 : 1)
            face(page: outgoingPage, angle: outgoingAngle)
                .opacity(faceOpacity(for: outgoingAngle))
                .zIndex(outFront ? 1 : 0)
        }
    }

    private var directionSign: Int { direction >= 0 ? 1 : -1 }

    private func face(page: Int, angle: Double) -> some View {
        CubeTumbleView_CubeFace(pageIndex: page, side: side)
            .rotation3DEffect(
                .degrees(angle),
                axis: (x: 0, y: 1, z: 0),
                anchor: .center,
                perspective: perspective
            )
    }

    // Fade a face out as it approaches edge-on (±90°) so we never show the
    // razor-thin sliver or any mirrored backface.
    private func faceOpacity(for angle: Double) -> Double {
        let a = min(abs(angle), 90.0)
        // Full opacity until ~55°, then ramp to 0 by 90°.
        if a <= 55 { return 1 }
        let fade = (90.0 - a) / 35.0
        return max(0, min(1, fade))
    }
}

// MARK: - Demo: self-driving auto-tumble

private struct CubeTumbleView_DemoCube: View {
    let side: CGFloat
    private let secondsPerFace: Double = 3.0

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let faces = elapsed / secondsPerFace
            let base = Int(floor(faces))
            let frac = faces - Double(base)
            // Ease the per-face turn so it accelerates in and settles out,
            // dwelling briefly flat at each face for legibility.
            let eased = easedTurn(frac)
            let degrees = eased * 90.0

            CubeTumbleView_CubeHinge(
                basePage: base,
                degrees: degrees,
                side: side,
                direction: 1
            )
        }
    }

    // Dwell flat at the start/end of each step, smooth turn in the middle.
    private func easedTurn(_ x: Double) -> Double {
        let dwell = 0.22
        if x < dwell { return 0 }
        if x > 1 - dwell { return 1 }
        let p = (x - dwell) / (1 - 2 * dwell)
        // smoothstep
        return p * p * (3 - 2 * p)
    }
}

// MARK: - Interactive: drag to scrub, spring-snap on release

private struct CubeTumbleView_InteractiveCube: View {
    let side: CGFloat

    @State private var basePage: Int = 0
    @State private var dragDegrees: Double = 0
    @State private var snapTrigger: Int = 0

    // How many drag points equal a full 90° face turn.
    private var pointsPerFace: CGFloat { max(side, 120) }

    var body: some View {
        CubeTumbleView_CubeHinge(
            basePage: basePage,
            degrees: dragDegrees,
            side: side,
            direction: dragDegrees >= 0 ? 1 : -1
        )
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: snapTrigger)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Dragging left advances to the next face (+degrees).
                let raw = -value.translation.width / pointsPerFace * 90.0
                dragDegrees = clampScrub(raw)
            }
            .onEnded { value in
                let predicted = -value.predictedEndTranslation.width / pointsPerFace * 90.0
                resolveSnap(current: dragDegrees, predicted: clampScrub(predicted))
            }
    }

    // Allow a little overscroll past the current step while scrubbing.
    private func clampScrub(_ d: Double) -> Double {
        min(max(d, -120), 120)
    }

    private func resolveSnap(current: Double, predicted: Double) {
        // Decide the target step (-1, 0, or +1 relative to base) using the
        // predicted end position so a flick commits even from a small drag.
        let decider = predicted
        let target: Double
        let pageDelta: Int

        if decider >= 45 {
            target = 90
            pageDelta = 1
        } else if decider <= -45 {
            target = -90
            pageDelta = -1
        } else {
            target = 0
            pageDelta = 0
        }

        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
            dragDegrees = target
        }

        // After the spring lands on the neighbor face, fold that face back
        // to the flat baseline (degrees → 0) by committing the page index.
        if pageDelta != 0 {
            snapTrigger &+= 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.46) {
                basePage += pageDelta
                dragDegrees = 0
            }
        } else {
            // Snapped back to base; reset trigger so a returned scrub
            // still feels responsive.
            dragDegrees = 0
        }
    }
}
