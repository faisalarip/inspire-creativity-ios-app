// catalog-id: btn-cube-roll
import SwiftUI

// MARK: - Cube Roll
//
// Tapping rolls the button as a 3D cube tumbling one face forward; each face
// shows a different state (idle, loading, success) and lands with a heavy
// bounce. A single continuous `angle` (degrees, only ever decreasing) is the
// source of truth. Faces are ephemeral: at any instant we draw exactly the two
// faces in the front hemisphere, assigning their content from a step counter
// (mod 3) over [idle, loading, success]. This sidesteps the 3-states-vs-4-cube-
// faces mismatch and means the button can tumble forward forever.
//
// demo == true  -> TimelineView drives angle = -90 * (step + easeOutBack(frac)),
//                  rolling forward continuously with a heavy bounce per face,
//                  no backward-spin at the loop seam.
// demo == false -> tap fires withAnimation(.spring(...)) { angle -= 90 } and a
//                  haptic on landing (fired from the animation completion).
//
// iOS 17 only: TimelineView, rotation3DEffect(anchorZ:), spring,
// sensoryFeedback, and withAnimation(completionCriteria:) are all available on
// 17. No iOS-18 API used.

struct CubeRollView: View {
    var demo: Bool = false

    // Interactive state.
    @State private var angle: Double = 0          // degrees, decreasing (<= 0)
    @State private var tapCount: Int = 0          // haptic trigger (on landing)

    var body: some View {
        GeometryReader { proxy in
            let side = sideLength(for: proxy.size)
            Group {
                if demo {
                    demoBody(side: side)
                } else {
                    interactiveBody(side: side)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Sizing

    private func sideLength(for size: CGSize) -> CGFloat {
        let base = min(size.width, size.height)
        return max(base * 0.6, 36)
    }

    // MARK: Demo (self-driving)

    private func demoBody(side: CGFloat) -> some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let driven = demoAngle(at: t)
            cube(angle: driven, side: side)
        }
    }

    /// Continuous, ever-decreasing angle. One face per `stepDuration`; the
    /// easeOutBack on the fractional step overshoots past the landing then
    /// settles, producing the heavy bounce. Continuous at the seam
    /// (easeOutBack(0)=0, easeOutBack(1)=1) so there is no backward spin.
    ///
    /// `time` is folded into one 3-face cycle first so the math stays in small
    /// numbers (avoids subtracting two ~1e10 doubles); the cube content cycles
    /// mod 3 anyway, so folding the angle to [0, 3 steps) is visually identical.
    private func demoAngle(at time: TimeInterval) -> Double {
        let stepDuration: Double = 1.1        // 3-face cycle ~= 3.3s (in 2.5-4s window)
        let cycle: Double = stepDuration * 3.0
        let folded = time.truncatingRemainder(dividingBy: cycle)
        let wrapped = folded < 0 ? folded + cycle : folded
        let raw = wrapped / stepDuration
        let step = floor(raw)
        let frac = raw - step
        let eased = easeOutBack(frac)
        return -90.0 * (step + eased)
    }

    private func easeOutBack(_ x: Double) -> Double {
        let c1: Double = 1.70158
        let c3: Double = c1 + 1.0
        let p = x - 1.0
        return 1.0 + c3 * p * p * p + c1 * p * p
    }

    // MARK: Interactive (real component)

    private func interactiveBody(side: CGFloat) -> some View {
        cube(angle: angle, side: side)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.5),
                              completionCriteria: .logicallyComplete) {
                    angle -= 90
                } completion: {
                    // Heavy "landing" haptic once the roll settles.
                    tapCount += 1
                }
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: tapCount)
            .accessibilityElement()
            .accessibilityLabel("Cube roll button")
            .accessibilityHint("Double tap to roll the cube to the next state")
            .accessibilityAddTraits(.isButton)
    }

    // MARK: Cube renderer (shared by both modes)
    //
    // `angle` is <= 0 and decreasing, so p = -angle/90 >= 0 and increasing.
    // The two faces straddling the viewer are `lo = floor(p)` and `hi = lo+1`.
    // Face k is dead-front when p == k; its local rotation is angle + 90*k,
    // which stays inside (-90, +90] for these two -> always front hemisphere,
    // so no mirrored back faces. The farther face (larger |local|) is painted
    // first so the nearer face draws on top.

    @ViewBuilder
    private func cube(angle: Double, side: CGFloat) -> some View {
        let p = max(0.0, -angle / 90.0)
        let lo = floor(p)
        let hi = lo + 1.0

        let localLo = angle + 90.0 * lo     // in (-90, 0]
        let localHi = angle + 90.0 * hi     // in (0, +90]

        let stateLo = CubeRollView_CubeFace.allCases[modIndex(lo)]
        let stateHi = CubeRollView_CubeFace.allCases[modIndex(hi)]

        let loIsFarther = abs(localLo) >= abs(localHi)

        ZStack {
            if loIsFarther {
                faceView(stateLo, local: localLo, side: side) // farther: first
                faceView(stateHi, local: localHi, side: side) // nearer: last
            } else {
                faceView(stateHi, local: localHi, side: side) // farther: first
                faceView(stateLo, local: localLo, side: side) // nearer: last
            }
        }
    }

    private func modIndex(_ value: Double) -> Int {
        let count = CubeRollView_CubeFace.allCases.count
        let i = Int(value) % count
        return i < 0 ? i + count : i
    }

    private func faceView(_ face: CubeRollView_CubeFace, local: Double, side: CGFloat) -> some View {
        CubeRollView_CubeFaceContent(face: face, side: side)
            .frame(width: side, height: side)
            .rotation3DEffect(
                .degrees(local),
                axis: (x: 1, y: 0, z: 0),
                anchor: .center,
                anchorZ: side / 2,          // pivot at the cube center
                perspective: 0.5
            )
    }
}

// MARK: - Faces

private enum CubeRollView_CubeFace: Int, CaseIterable {
    case idle
    case loading
    case success
}

private struct CubeRollView_CubeFaceContent: View {
    let face: CubeRollView_CubeFace
    let side: CGFloat

    private var corner: CGFloat { side * 0.22 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(faceGradient)
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(rimColor, lineWidth: max(side * 0.012, 0.8))
                .blendMode(.overlay)
            content
        }
        .compositingGroup()
        .shadow(color: Color(red: 0, green: 0, blue: 0).opacity(0.35),
                radius: side * 0.06, x: 0, y: side * 0.04)
    }

    // MARK: per-face content

    @ViewBuilder
    private var content: some View {
        switch face {
        case .idle:    idleContent
        case .loading: loadingContent
        case .success: successContent
        }
    }

    private var idleContent: some View {
        VStack(spacing: side * 0.06) {
            Image(systemName: "cube.fill")
                .font(.system(size: side * 0.30, weight: .semibold))
            Text("ROLL")
                .font(.system(size: side * 0.13, weight: .bold, design: .rounded))
                .tracking(side * 0.02)
        }
        .foregroundStyle(Color(red: 1.0, green: 0.97, blue: 0.92))
    }

    private var loadingContent: some View {
        VStack(spacing: side * 0.07) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color(red: 0.06, green: 0.05, blue: 0.04))
                .scaleEffect(max(side * 0.012, 0.6))
            Text("WORKING")
                .font(.system(size: side * 0.115, weight: .bold, design: .rounded))
                .tracking(side * 0.015)
                .foregroundStyle(Color(red: 0.10, green: 0.08, blue: 0.06))
        }
    }

    private var successContent: some View {
        VStack(spacing: side * 0.06) {
            Image(systemName: "checkmark")
                .font(.system(size: side * 0.30, weight: .heavy))
            Text("DONE")
                .font(.system(size: side * 0.13, weight: .bold, design: .rounded))
                .tracking(side * 0.02)
        }
        .foregroundStyle(Color(red: 1.0, green: 1.0, blue: 1.0))
    }

    // MARK: per-face styling

    private var faceGradient: LinearGradient {
        switch face {
        case .idle:
            // Warm dark, matches tint #16120e.
            return LinearGradient(
                colors: [
                    Color(red: 0.20, green: 0.16, blue: 0.11),
                    Color(red: 0.086, green: 0.071, blue: 0.055)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .loading:
            // Amber working state.
            return LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.80, blue: 0.36),
                    Color(red: 0.95, green: 0.62, blue: 0.18)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .success:
            // Fresh green success state.
            return LinearGradient(
                colors: [
                    Color(red: 0.30, green: 0.80, blue: 0.49),
                    Color(red: 0.13, green: 0.62, blue: 0.41)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var rimColor: Color {
        Color(red: 1.0, green: 1.0, blue: 1.0).opacity(0.30)
    }
}
