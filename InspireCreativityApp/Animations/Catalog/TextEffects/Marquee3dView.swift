// catalog-id: tx-marquee-3d
import SwiftUI

/// 3D Cylinder Marquee
///
/// A scrolling ticker of words wraps around an invisible vertical-axis drum.
/// Words curl away with perspective at the left/right rim, shrinking, fading
/// and blurring as they rotate off one edge and arrive on the other.
///
/// - `demo == true`  : a self-driving constant-rate spin (no touch needed).
/// - `demo == false` : a real `DragGesture` scrubs/flicks the drum; on release
///                     the spin coasts to a stop via closed-form friction decay.
///
/// Curl direction note: the curl/perspective sign is governed by `perspective`
/// in `wordRotation(...)` together with the angle->degrees mapping. If the drum
/// reads inside-out on device, negate the degrees in `wordRotation` (single spot).
struct Marquee3dView: View {
    var demo: Bool = false

    // The ticker tokens. Kept short so they stay legible inside a ~120pt tile.
    private let words: [String] = [
        "INSPIRE", "CREATE", "DREAM", "BUILD",
        "DESIGN", "SHIP", "MAKE", "FLOW"
    ]

    // MARK: - Interactive drum state (only mutated in gesture callbacks)

    /// Phase committed from finished drags (radians).
    @State private var committedPhase: Double = 0
    /// Live phase contribution from the in-flight drag (radians).
    @State private var liveDragPhase: Double = 0
    /// Release velocity in radians/sec, seeded on `.onEnded`.
    @State private var releaseVelocity: Double = 0
    /// Timestamp of the last release; coast is measured from here.
    @State private var releaseDate: Date = .distantPast
    /// Whether a finger is currently down (pauses the coast).
    @State private var isDragging: Bool = false

    var body: some View {
        GeometryReader { geo in
            let content = TimelineView(.animation) { timeline in
                drum(in: geo.size, now: timeline.date)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .background(backdrop)
            .clipShape(RoundedRectangle(cornerRadius: geo.size.width * 0.06,
                                        style: .continuous))

            if demo {
                content
            } else {
                content.gesture(drumGesture(width: geo.size.width))
            }
        }
    }

    // MARK: - Backdrop

    private var backdrop: some View {
        // Deep neutral panel with a soft vertical light gradient so the drum
        // reads as recessed. Never fully black so the tile is always legible.
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.06, blue: 0.10),
                Color(red: 0.02, green: 0.02, blue: 0.05)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - The rotating drum

    private func drum(in size: CGSize, now: Date) -> some View {
        let phase = currentPhase(now: now)
        let radius = drumRadius(for: size)
        let fontSize = wordFontSize(for: size)
        let count = words.count

        return ZStack {
            // Faint center guide line so the band of the ticker reads as a slot.
            slotHighlight(size: size)

            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                let angle = wordAngle(index: index, count: count, phase: phase)
                wordTile(word: word,
                         angle: angle,
                         radius: radius,
                         fontSize: fontSize)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func slotHighlight(size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: size.height * 0.18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 1, green: 1, blue: 1).opacity(0.06),
                        Color(red: 1, green: 1, blue: 1).opacity(0.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: size.width * 0.9, height: size.height * 0.42)
    }

    // MARK: - Single word tile

    @ViewBuilder
    private func wordTile(word: String,
                          angle: Double,
                          radius: CGFloat,
                          fontSize: CGFloat) -> some View {
        let depth = cos(angle)                 // +1 = front center, -1 = far back
        let xOffset = xPosition(angle: angle, radius: radius)
        let scale = wordScale(depth: depth)
        let opacity = wordOpacity(depth: depth)
        let blur = wordBlur(depth: depth, fontSize: fontSize)

        // Cull words on the far hemisphere: invisible AND behind, so they never
        // clutter the front. There is always >= 1 word near center at full
        // opacity, so the tile is never blank.
        if depth > -0.15 {
            Text(word)
                .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(wordFill(depth: depth))
                .fixedSize()
                .scaleEffect(scale)
                .rotation3DEffect(
                    wordRotation(angle: angle),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .center,
                    perspective: 0.55
                )
                .offset(x: xOffset)
                .blur(radius: blur)
                .opacity(opacity)
                .zIndex(depth)
        }
    }

    private func wordFill(depth: Double) -> LinearGradient {
        // Front words get a warm bright face; rim words desaturate toward steel.
        let frontness = max(0, depth)
        let r = 0.78 + 0.20 * frontness
        let g = 0.80 + 0.18 * frontness
        let b = 0.86 + 0.14 * frontness
        return LinearGradient(
            colors: [
                Color(red: min(r, 1), green: min(g, 1), blue: min(b, 1)),
                Color(red: 0.55 + 0.25 * frontness,
                      green: 0.58 + 0.25 * frontness,
                      blue: 0.70 + 0.20 * frontness)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Per-word math (small, type-annotated helpers)

    /// Base evenly-spaced angle for a word plus the running phase.
    private func wordAngle(index: Int, count: Int, phase: Double) -> Double {
        let base = Double(index) * (2 * .pi) / Double(count)
        return base + phase
    }

    /// Horizontal screen position from the angle on the drum.
    private func xPosition(angle: Double, radius: CGFloat) -> CGFloat {
        radius * CGFloat(sin(angle))
    }

    /// Front words are larger; rim words shrink toward the back.
    private func wordScale(depth: Double) -> CGFloat {
        let s: Double = 0.58 + 0.42 * ((depth + 1) / 2)
        return CGFloat(s)
    }

    /// Fade out toward and past the rim; clamp so center stays fully legible.
    private func wordOpacity(depth: Double) -> Double {
        let raw = (depth + 0.4) / 1.4   // ~0 at the rim, 1 at the front
        return min(1, max(0, raw))
    }

    /// Rim blur grows as words rotate edge-on. Scaled to the type size.
    private func wordBlur(depth: Double, fontSize: CGFloat) -> CGFloat {
        let amount = (1 - depth) / 2      // 0 at front, 1 at back
        let maxBlur = fontSize * 0.08
        return maxBlur * CGFloat(amount)
    }

    /// 3D y-axis rotation. Negate the degrees here to reverse the curl.
    private func wordRotation(angle: Double) -> Angle {
        .degrees(angle * 180 / .pi)
    }

    // MARK: - Layout sizing (relative to the geometry)

    private func drumRadius(for size: CGSize) -> CGFloat {
        size.width * 0.40
    }

    private func wordFontSize(for size: CGSize) -> CGFloat {
        // Scale to the smaller side so it fits both a 120pt tile and a big
        // detail area; cap so detail mode doesn't explode the type.
        let base = min(size.width, size.height)
        return min(base * 0.16, 40)
    }

    // MARK: - Phase composition

    /// Pure function of time: committed + live drag + coast. No state mutation.
    private func currentPhase(now: Date) -> Double {
        if demo {
            return autoPhase(now: now)
        }
        return committedPhase + liveDragPhase + coastPhase(now: now)
    }

    /// Self-driving constant-rate spin for the preview tile (~one lap / 4.5s).
    private func autoPhase(now: Date) -> Double {
        let speed: Double = (2 * .pi) / 4.5
        let t = now.timeIntervalSinceReferenceDate
        return t * speed
    }

    /// Closed-form exponential friction decay of the release flick.
    /// coast(t) = (v0 / k) * (1 - exp(-k * t)) - bounded, settles on its own.
    private func coastPhase(now: Date) -> Double {
        guard !isDragging, releaseVelocity != 0 else { return 0 }
        let friction: Double = 2.4
        let elapsed = now.timeIntervalSince(releaseDate)
        guard elapsed > 0 else { return 0 }
        return (releaseVelocity / friction) * (1 - exp(-friction * elapsed))
    }

    // MARK: - Interaction

    private func drumGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDragging {
                    // First frame of a new drag: fold any in-progress coast into
                    // the committed phase before killing it, so grabbing the drum
                    // mid-flick is continuous (no backward jump).
                    committedPhase += coastPhase(now: Date())
                    releaseDate = .distantPast
                }
                isDragging = true
                releaseVelocity = 0
                // Map horizontal drag distance to drum rotation.
                liveDragPhase = dragToPhase(translationX: value.translation.width,
                                            width: width)
            }
            .onEnded { value in
                // Fold the live drag into the committed phase.
                committedPhase += dragToPhase(translationX: value.translation.width,
                                              width: width)
                liveDragPhase = 0
                // Seed the coast from the release velocity (pts/s -> rad/s).
                releaseVelocity = velocityToPhaseRate(velocityX: value.velocity.width,
                                                      width: width)
                releaseDate = Date()
                isDragging = false
            }
    }

    /// A full drum width of horizontal travel ~ half a revolution.
    private func dragToPhase(translationX: CGFloat, width: CGFloat) -> Double {
        let span = max(width, 1)
        return Double(translationX / span) * .pi
    }

    private func velocityToPhaseRate(velocityX: CGFloat, width: CGFloat) -> Double {
        let span = max(width, 1)
        return Double(velocityX / span) * .pi
    }
}
