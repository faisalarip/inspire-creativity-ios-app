// catalog-id: mi-mood-morph-rating
import SwiftUI

// MARK: - Mood-Morph Rating
// A single face whose mouth path continuously morphs from frown to grin as the
// rating value changes. MoodMorphRatingView_Eyes widen near the top score. The mouth is an
// Animatable closed lens (two quadratic curves, constant topology) so the morph
// stays perfectly smooth. demo == true self-drives a sine sweep; demo == false
// is a live DragGesture that snaps to the nearest notch on release.

struct MoodMorphRatingView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { proxy in
            content(in: proxy.size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if demo {
            MoodMorphRatingView_DemoDriver(size: size)
        } else {
            MoodMorphRatingView_InteractiveDriver(size: size)
        }
    }
}

// MARK: - Demo driver (self-running, never blank)

private struct MoodMorphRatingView_DemoDriver: View {
    let size: CGSize
    private let period: Double = 3.2

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = t.truncatingRemainder(dividingBy: period) / period
            // 0 -> 1 -> 0 smooth sweep, starts at frown.
            let morph = (1.0 - cos(2.0 * .pi * phase)) / 2.0
            MoodMorphRatingView_MoodFace(morph: CGFloat(morph), size: size)
        }
    }
}

// MARK: - Interactive driver (real DragGesture)

private struct MoodMorphRatingView_InteractiveDriver: View {
    let size: CGSize
    @State private var morph: CGFloat = 0.0
    @State private var lastNotch: Int = 0

    private let notches: Int = 5 // 0...4 -> five mood steps

    var body: some View {
        let layout = MoodMorphRatingView_FaceLayout(size: size)
        ZStack {
            MoodMorphRatingView_MoodFace(morph: morph, size: size)
        }
        .contentShape(Rectangle())
        .gesture(dragGesture(track: layout.trackRect))
        .sensoryFeedback(.selection, trigger: lastNotch)
        .onAppear {
            // Start at a legible neutral-ish smile so it is never expressionless.
            morph = 0.5
            lastNotch = notchIndex(for: 0.5)
        }
    }

    private func dragGesture(track: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let raw = (value.location.x - track.minX) / max(track.width, 1)
                let clamped = min(max(raw, 0.0), 1.0)
                morph = clamped
                let idx = notchIndex(for: clamped)
                if idx != lastNotch { lastNotch = idx }
            }
            .onEnded { _ in
                let idx = notchIndex(for: morph)
                let snapped = CGFloat(idx) / CGFloat(notches - 1)
                lastNotch = idx
                withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) {
                    morph = snapped
                }
            }
    }

    private func notchIndex(for value: CGFloat) -> Int {
        let scaled = value * CGFloat(notches - 1)
        return Int((scaled).rounded())
    }
}

// MARK: - Layout

private struct MoodMorphRatingView_FaceLayout {
    let size: CGSize

    var side: CGFloat { min(size.width, size.height) }

    /// The face sits in the upper portion; a thin track lives below it.
    var facePadding: CGFloat { side * 0.12 }

    var faceRect: CGRect {
        let s = side * 0.74
        let x = (size.width - s) / 2.0
        let y = (size.height - s) / 2.0 - side * 0.06
        return CGRect(x: x, y: y, width: s, height: s)
    }

    var trackRect: CGRect {
        let f = faceRect
        let w = f.width * 1.04
        let x = (size.width - w) / 2.0
        let h = max(side * 0.05, 6)
        let y = f.maxY + side * 0.08
        return CGRect(x: x, y: y, width: w, height: h)
    }
}

// MARK: - The face (pure function of `morph`)

private struct MoodMorphRatingView_MoodFace: View {
    let morph: CGFloat   // 0 = frown, 1 = grin
    let size: CGSize

    var body: some View {
        let layout = MoodMorphRatingView_FaceLayout(size: size)
        ZStack {
            MoodMorphRatingView_FaceBubble(morph: morph, rect: layout.faceRect)
            MoodMorphRatingView_Eyes(morph: morph, faceRect: layout.faceRect)
            MoodMorphRatingView_MouthLayer(morph: morph, faceRect: layout.faceRect)
            MoodMorphRatingView_NotchTrack(morph: morph, rect: layout.trackRect)
        }
    }
}

// MARK: - Face bubble background

private struct MoodMorphRatingView_FaceBubble: View {
    let morph: CGFloat
    let rect: CGRect

    var body: some View {
        let fill = faceColor(for: morph)
        Circle()
            .fill(
                RadialGradient(
                    colors: [fill.0, fill.1],
                    center: .init(x: 0.35, y: 0.3),
                    startRadius: 1,
                    endRadius: rect.width * 0.85
                )
            )
            .overlay(
                Circle().stroke(
                    Color(red: 0.0, green: 0.0, blue: 0.0).opacity(0.10),
                    lineWidth: max(rect.width * 0.012, 0.5)
                )
            )
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .shadow(color: fill.1.opacity(0.45), radius: rect.width * 0.06, y: rect.width * 0.03)
    }

    /// Warm/golden at high morph, cool/violet at low morph.
    private func faceColor(for m: CGFloat) -> (Color, Color) {
        let t = min(max(m, 0.0), 1.0)
        // sad: muted periwinkle  -> happy: warm gold
        let topR = lerp(0.62, 1.00, t)
        let topG = lerp(0.66, 0.86, t)
        let topB = lerp(0.92, 0.36, t)
        let botR = lerp(0.45, 0.98, t)
        let botG = lerp(0.49, 0.69, t)
        let botB = lerp(0.82, 0.20, t)
        return (
            Color(red: topR, green: topG, blue: topB),
            Color(red: botR, green: botG, blue: botB)
        )
    }
}

// MARK: - MoodMorphRatingView_Eyes

private struct MoodMorphRatingView_Eyes: View {
    let morph: CGFloat
    let faceRect: CGRect

    var body: some View {
        let eyeY = faceRect.minY + faceRect.height * 0.40
        let dx = faceRect.width * 0.20
        let baseSize = faceRect.width * 0.115
        let widen = topRamp(morph)            // 0 until ~0.7, ramps to 1 by 1.0
        let scale = 1.0 + widen * 0.55
        let eyeColor = Color(red: 0.16, green: 0.13, blue: 0.20)

        ZStack {
            eye(color: eyeColor, size: baseSize)
                .scaleEffect(scale)
                .position(x: faceRect.midX - dx, y: eyeY)
            eye(color: eyeColor, size: baseSize)
                .scaleEffect(scale)
                .position(x: faceRect.midX + dx, y: eyeY)
        }
    }

    @ViewBuilder
    private func eye(color: Color, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
            // Catch-light: brighter as eyes widen for a livelier top score.
            Circle()
                .fill(Color(red: 1.0, green: 1.0, blue: 1.0).opacity(0.85))
                .frame(width: size * 0.32, height: size * 0.32)
                .offset(x: -size * 0.18, y: -size * 0.20)
        }
    }

    /// Returns 0 below 0.7, eased ramp to 1 at 1.0.
    private func topRamp(_ m: CGFloat) -> CGFloat {
        let start: CGFloat = 0.7
        guard m > start else { return 0 }
        let t = (m - start) / (1.0 - start)
        // smoothstep
        return t * t * (3 - 2 * t)
    }
}

// MARK: - Mouth

private struct MoodMorphRatingView_MouthLayer: View {
    let morph: CGFloat
    let faceRect: CGRect

    var body: some View {
        let mouthColor = Color(red: 0.16, green: 0.10, blue: 0.16)
        MoodMorphRatingView_MouthShape(morph: morph)
            .fill(mouthColor)
            .overlay(
                MoodMorphRatingView_MouthShape(morph: morph)
                    .stroke(mouthColor, lineWidth: max(faceRect.width * 0.02, 1))
            )
            .frame(width: faceRect.width, height: faceRect.height)
            .position(x: faceRect.midX, y: faceRect.midY)
    }
}

/// A closed-lens mouth made of exactly two quadratic curves + close.
/// Topology is identical at every `morph`, so the morph animates smoothly.
private struct MoodMorphRatingView_MouthShape: Shape {
    var morph: CGFloat // 0 = frown, 1 = grin

    var animatableData: CGFloat {
        get { morph }
        set { morph = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let m = min(max(morph, 0.0), 1.0)

        // Mouth band sits in the lower third of the face rect.
        let cx = rect.midX
        let baseY = rect.minY + rect.height * 0.66
        let halfWidth = rect.width * 0.24

        let left = CGPoint(x: cx - halfWidth, y: cornerY(baseY: baseY, rect: rect, m: m))
        let right = CGPoint(x: cx + halfWidth, y: cornerY(baseY: baseY, rect: rect, m: m))

        // Control point Y for the upper edge and the lower edge.
        // Frown (m=0): both bow UP (smaller y). Grin (m=1): both bow DOWN (larger y).
        // The lens always keeps a non-zero thickness so it reads as a mouth.
        let span = rect.height
        // Center offset of the whole mouth: frown -> up curve, grin -> down curve.
        let curveAmt = lerp(-span * 0.11, span * 0.20, m)   // negative = up (frown)
        let thickness = lerp(span * 0.045, span * 0.085, m) // a touch fuller when grinning

        let upperCtrl = CGPoint(x: cx, y: baseY + curveAmt - thickness)
        let lowerCtrl = CGPoint(x: cx, y: baseY + curveAmt + thickness)

        var path = Path()
        path.move(to: left)
        path.addQuadCurve(to: right, control: upperCtrl)
        path.addQuadCurve(to: left, control: lowerCtrl)
        path.closeSubpath()
        return path
    }

    /// Corners lift slightly upward toward a grin for a richer smile.
    private func cornerY(baseY: CGFloat, rect: CGRect, m: CGFloat) -> CGFloat {
        // grin pulls corners up; frown lets them sit / droop a bit.
        let lift = lerp(rect.height * 0.02, -rect.height * 0.05, m)
        return baseY + lift
    }
}

// MARK: - Notch track (secondary affordance)

private struct MoodMorphRatingView_NotchTrack: View {
    let morph: CGFloat
    let rect: CGRect

    private let notches: Int = 5

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color(red: 0.0, green: 0.0, blue: 0.0).opacity(0.16))
                .frame(width: rect.width, height: rect.height)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.00, green: 0.78, blue: 0.30),
                            Color(red: 0.98, green: 0.55, blue: 0.22)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: max(rect.width * morph, rect.height), height: rect.height)

            HStack(spacing: 0) {
                ForEach(0..<notches, id: \.self) { i in
                    Circle()
                        .fill(Color(red: 1.0, green: 1.0, blue: 1.0).opacity(0.55))
                        .frame(width: rect.height * 0.34, height: rect.height * 0.34)
                        .frame(maxWidth: .infinity)
                        .opacity(i == 0 || i == notches - 1 ? 0.0 : 1.0)
                }
            }
            .frame(width: rect.width, height: rect.height)
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
    }
}

// MARK: - Helpers

private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
    a + (b - a) * t
}
