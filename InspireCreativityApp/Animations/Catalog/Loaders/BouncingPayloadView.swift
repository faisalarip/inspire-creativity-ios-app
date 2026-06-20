// catalog-id: ld-bouncing-payload
import SwiftUI

/// Bouncing Payload — a classic squash-and-stretch loader.
///
/// A glossy ball drops under gravity, squashes on floor impact, stretches at the
/// apex, and loses a little height each bounce before auto-resetting and dropping
/// again. A blurred ellipse shadow tightens and darkens as the ball nears the floor.
///
/// - `demo == true`  → self-driving `KeyframeAnimator` loop, no touch required.
/// - `demo == false` → identical bounce loop, plus a sideways fling (`DragGesture`)
///   that adds friction-decayed horizontal travel layered onto the vertical bounce.
struct BouncingPayloadView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            BounceStage(size: geo.size, interactive: !demo)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Keyframe state

/// Normalized animatable state driven by independent keyframe tracks.
/// `y` is normalized height: 1 == resting at the top, 0 == touching the floor.
/// Fields are `Double` so they match `KeyframeTrack`'s expected value type.
private struct BounceState {
    var y: Double = 1        // height fraction (1 top → 0 floor)
    var scaleX: Double = 1   // horizontal scale (squash > 1, stretch < 1)
    var scaleY: Double = 1   // vertical scale   (squash < 1, stretch > 1)
}

// MARK: - Stage

private struct BounceStage: View {
    let size: CGSize
    let interactive: Bool

    // Horizontal fling state (interactive mode only).
    @State private var flingOffset: CGFloat = 0   // committed, settling offset
    @State private var dragOffset: CGFloat = 0     // live finger offset while dragging

    var body: some View {
        let metrics = Metrics(size: size)

        ZStack {
            KeyframeAnimator(
                initialValue: BounceState(),
                repeating: true
            ) { state in
                payload(state: state, metrics: metrics)
            } keyframes: { _ in
                bounceTracks()
            }
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .modifier(FlingModifier(
            enabled: interactive,
            metrics: metrics,
            flingOffset: $flingOffset,
            dragOffset: $dragOffset
        ))
    }

    @ViewBuilder
    private func payload(state: BounceState, metrics: Metrics) -> some View {
        let height = state.y                                  // 0…1
        let ballCenterY = metrics.topY + (metrics.floorY - metrics.topY) * (1 - height)
        let xOffset = flingOffset + dragOffset

        ZStack {
            // Shadow rests on the contact line (ball-bottom at impact),
            // so it stays planted beneath the ball rather than floating.
            ShadowBlob(height: height, metrics: metrics)
                .position(x: metrics.centerX + xOffset * 0.85,
                          y: metrics.floorY + metrics.ballRadius * 0.92)

            Ball(scaleX: state.scaleX, scaleY: state.scaleY, radius: metrics.ballRadius)
                .position(x: metrics.centerX + xOffset, y: ballCenterY)
        }
    }
}

// MARK: - Keyframe tracks (the mechanism: independent y / scaleX / scaleY)

@KeyframesBuilder<BounceState>
private func bounceTracks() -> some Keyframes<BounceState> {
        // Vertical height: gravity arcs with damped peaks, ending by easing back
        // up to the top so the loop seam reads as a deliberate rise, not a snap.
        KeyframeTrack(\.y) {
            // Drop 1 (full height) → floor
            CubicKeyframe(0.0, duration: 0.62)
            // Bounce 1 → ~55%
            CubicKeyframe(0.55, duration: 0.42)
            CubicKeyframe(0.0, duration: 0.42)
            // Bounce 2 → ~30%
            CubicKeyframe(0.30, duration: 0.32)
            CubicKeyframe(0.0, duration: 0.32)
            // Bounce 3 → ~13%
            CubicKeyframe(0.13, duration: 0.22)
            CubicKeyframe(0.0, duration: 0.22)
            // Tiny settle hop → ~5%
            CubicKeyframe(0.05, duration: 0.16)
            CubicKeyframe(0.0, duration: 0.16)
            // Reset: rise smoothly back to the top for a seamless loop
            SpringKeyframe(1.0, duration: 0.70, spring: .smooth)
        }

        // Horizontal scale: bulges wide on each floor impact (squash), narrows
        // during the fast fall/rise (stretch), neutral at apex and top.
        KeyframeTrack(\.scaleX) {
            CubicKeyframe(0.86, duration: 0.50)   // stretch thin on the fall
            CubicKeyframe(1.30, duration: 0.12)   // SQUASH wide at impact 1
            CubicKeyframe(0.92, duration: 0.30)   // stretch on rise
            CubicKeyframe(1.00, duration: 0.12)   // apex 1 neutral
            CubicKeyframe(0.92, duration: 0.30)   // stretch on fall
            CubicKeyframe(1.22, duration: 0.10)   // SQUASH impact 2
            CubicKeyframe(0.95, duration: 0.22)   // rise
            CubicKeyframe(1.00, duration: 0.10)   // apex 2
            CubicKeyframe(0.96, duration: 0.22)   // fall
            CubicKeyframe(1.14, duration: 0.08)   // SQUASH impact 3
            CubicKeyframe(1.00, duration: 0.30)   // settle hop
            CubicKeyframe(1.08, duration: 0.08)   // tiny squash
            CubicKeyframe(1.00, duration: 0.78)   // reset neutral
        }

        // Vertical scale: inverse of scaleX — stretches tall on fast travel,
        // flattens on impact. Anchored to the bottom in the Ball view.
        KeyframeTrack(\.scaleY) {
            CubicKeyframe(1.16, duration: 0.50)   // stretch tall on the fall
            CubicKeyframe(0.70, duration: 0.12)   // FLATTEN at impact 1
            CubicKeyframe(1.10, duration: 0.30)   // stretch on rise
            CubicKeyframe(1.00, duration: 0.12)   // apex 1 neutral
            CubicKeyframe(1.10, duration: 0.30)   // stretch on fall
            CubicKeyframe(0.78, duration: 0.10)   // FLATTEN impact 2
            CubicKeyframe(1.06, duration: 0.22)   // rise
            CubicKeyframe(1.00, duration: 0.10)   // apex 2
            CubicKeyframe(1.05, duration: 0.22)   // fall
            CubicKeyframe(0.86, duration: 0.08)   // FLATTEN impact 3
            CubicKeyframe(1.00, duration: 0.30)   // settle hop
            CubicKeyframe(0.92, duration: 0.08)   // tiny flatten
            CubicKeyframe(1.00, duration: 0.78)   // reset neutral
        }
}

// MARK: - Layout metrics

private struct Metrics {
    let size: CGSize
    let ballRadius: CGFloat
    let centerX: CGFloat
    let topY: CGFloat        // ball-center Y at full height
    let floorY: CGFloat      // ball-center Y resting on the floor
    let travelBound: CGFloat // max horizontal travel from center

    init(size: CGSize) {
        self.size = size
        let minDim = min(size.width, size.height)
        let r = max(6, minDim * 0.13)
        self.ballRadius = r
        self.centerX = size.width / 2
        // Floor sits a little above the bottom edge so the shadow has room.
        self.floorY = size.height * 0.80 - r * 0.2
        // Top leaves headroom for the apex stretch.
        self.topY = max(r * 1.2, size.height * 0.16)
        self.travelBound = max(0, size.width / 2 - r * 1.1)
    }
}

// MARK: - Ball

private struct Ball: View {
    let scaleX: CGFloat
    let scaleY: CGFloat
    let radius: CGFloat

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(hexCode: 0xBFF0FF),
                        Color(hexCode: 0x4FC3F7),
                        Color(hexCode: 0x1E73C8),
                        Color(hexCode: 0x0E3F77)
                    ],
                    center: UnitPoint(x: 0.34, y: 0.30),
                    startRadius: radius * 0.05,
                    endRadius: radius * 1.25
                )
            )
            .overlay(specularHighlight)
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: max(0.5, radius * 0.03))
            )
            .frame(width: radius * 2, height: radius * 2)
            // Bottom anchor so squash reads as weight settling onto the floor.
            .scaleEffect(x: scaleX, y: scaleY, anchor: .bottom)
            .shadow(color: Color(hexCode: 0x0E3F77).opacity(0.45),
                    radius: radius * 0.18, x: 0, y: radius * 0.12)
    }

    private var specularHighlight: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [Color.white.opacity(0.9), Color.white.opacity(0.0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: radius * 0.55
                )
            )
            .frame(width: radius * 0.9, height: radius * 0.7)
            .offset(x: -radius * 0.28, y: -radius * 0.34)
            .blendMode(.screen)
    }
}

// MARK: - Shadow

private struct ShadowBlob: View {
    let height: CGFloat   // 0 (floor) … 1 (top)
    let metrics: Metrics

    var body: some View {
        // High → wide & faint; near floor → tight & dark.
        let widthFactor = 0.55 + (1 - height) * 0.55      // 0.55 … 1.10
        let opacity = 0.10 + (1 - height) * 0.30          // 0.10 … 0.40
        let w = metrics.ballRadius * 2 * widthFactor
        let h = max(3, metrics.ballRadius * 0.42 * (0.7 + (1 - height) * 0.6))

        Ellipse()
            .fill(
                RadialGradient(
                    colors: [Color.black.opacity(opacity), Color.black.opacity(0.0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: w * 0.55
                )
            )
            .frame(width: w, height: h)
            .blur(radius: metrics.ballRadius * 0.16)
    }
}

// MARK: - Horizontal fling (interactive mode only)

private struct FlingModifier: ViewModifier {
    let enabled: Bool
    let metrics: Metrics
    @Binding var flingOffset: CGFloat
    @Binding var dragOffset: CGFloat

    func body(content: Content) -> some View {
        if enabled {
            content.gesture(flingGesture)
        } else {
            content
        }
    }

    private var flingGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Live follow, clamped to the stage.
                let proposed = flingOffset + value.translation.width
                dragOffset = clamp(proposed) - flingOffset
            }
            .onEnded { value in
                // Project the flick: a sideways flick adds momentum, then the ball
                // travels and settles back toward center while the bounce continues.
                let projected = flingOffset
                    + value.translation.width
                    + value.predictedEndTranslation.width * 0.35
                let landing = clamp(projected)

                dragOffset = 0
                // Quick momentum throw…
                withAnimation(.easeOut(duration: 0.45)) {
                    flingOffset = landing
                }
                // …then a gentle settle back to center, layered on the bounce loop.
                withAnimation(.spring(response: 1.1, dampingFraction: 0.72).delay(0.45)) {
                    flingOffset = 0
                }
            }
    }

    private func clamp(_ x: CGFloat) -> CGFloat {
        min(metrics.travelBound, max(-metrics.travelBound, x))
    }
}

// MARK: - Color hex helper

private extension Color {
    init(hexCode hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

// MARK: - Preview
