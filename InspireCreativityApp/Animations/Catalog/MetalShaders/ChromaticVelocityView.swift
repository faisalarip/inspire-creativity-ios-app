// catalog-id: mtl-chromatic-velocity
// catalog-metal: ChromaticVelocityView.metal
import SwiftUI

/// Chromatic Velocity — RGB channels split apart proportional to drag velocity,
/// smearing into a prismatic streak on fast flicks and snapping back to crisp on
/// release. The demo loop oscillates the split with an eased sine.
///
/// The split is fed to a `.layerEffect` Metal shader that samples the layer three
/// times (one per R/G/B) at offset coords and recombines them. Min iOS 17.
struct ChromaticVelocityView: View {

    var demo: Bool = false

    // Live interactive drag state. These are mutated only inside gesture
    // callbacks (safe) — never inside the TimelineView closure (which only reads).
    @State private var dragSplit: CGFloat = 0          // velocity-driven split while dragging
    @State private var dragDir: CGVector = CGVector(dx: 1, dy: 0)
    @State private var dragOffset: CGSize = .zero      // content follows the finger
    @State private var isDragging: Bool = false
    @State private var releaseSplit: CGFloat = 0       // split captured at release
    @State private var releaseDir: CGVector = CGVector(dx: 1, dy: 0)
    @State private var releaseTime: Date? = nil        // when the flick was released

    var body: some View {
        GeometryReader { geo in
            let dim = min(geo.size.width, geo.size.height)
            let maxSplit = self.maxSplit(for: dim)

            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let resolved = resolvedSplit(now: timeline.date, maxSplit: maxSplit)

                content(dim: dim, time: t)
                    .offset(demo ? .zero : dragOffset)
                    .modifier(
                        ChromaticVelocityView_ChromaticSplit(
                            split: resolved.magnitude,
                            dir: resolved.direction,
                            maxOffset: maxSplit
                        )
                    )
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(demo ? nil : dragGesture(maxSplit: maxSplit))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.06, green: 0.04, blue: 0.03))
    }

    // MARK: - Split resolution

    /// The split magnitude + direction to feed the shader on this frame.
    private func resolvedSplit(now: Date, maxSplit: CGFloat) -> (magnitude: CGFloat, direction: CGVector) {
        if demo {
            // Eased sine 0 -> max -> 0 on a ~3.2s loop. Direction slowly rotates
            // so the prism exhaust sweeps around rather than sitting on one axis.
            let t = now.timeIntervalSinceReferenceDate
            let phase = (t.truncatingRemainder(dividingBy: 3.2)) / 3.2     // 0..1
            let eased = (1 - cos(phase * 2 * Double.pi)) / 2               // 0..1..0
            let angle = t * 0.7
            let dir = CGVector(dx: cos(angle), dy: sin(angle))
            return (CGFloat(eased) * maxSplit, dir)
        }

        if isDragging {
            return (clamp(dragSplit, 0, maxSplit), normalized(dragDir))
        }

        // Released: analytic exponential decay from the captured flick split.
        if let release = releaseTime {
            let dt = now.timeIntervalSince(release)
            let decay = exp(-6.5 * dt)                                     // ~0.5s to crisp
            let mag = clamp(releaseSplit * CGFloat(decay), 0, maxSplit)
            return (mag, normalized(releaseDir))
        }

        return (0, CGVector(dx: 1, dy: 0))
    }

    private func maxSplit(for dim: CGFloat) -> CGFloat {
        // Cap the split to a modest fraction of the view so the three samples stay
        // within maxSampleOffset and don't clip at the edges.
        max(8, dim * 0.16)
    }

    // MARK: - Gesture

    private func dragGesture(maxSplit: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDragging = true
                releaseTime = nil

                // Velocity -> split magnitude. Fast flicks widen the prism.
                let vx = value.velocity.width
                let vy = value.velocity.height
                let speed = hypot(vx, vy)
                let mag = clamp(speed / 90.0, 0, maxSplit)
                dragSplit = mag

                // Direction of the split tracks the motion vector (fallback to x).
                if speed > 1 {
                    dragDir = CGVector(dx: vx / speed, dy: vy / speed)
                }

                // Content follows the finger so the prism reads as motion exhaust.
                dragOffset = CGSize(
                    width: value.translation.width * 0.18,
                    height: value.translation.height * 0.18
                )
            }
            .onEnded { value in
                isDragging = false

                // Capture release split from the predicted fling speed, then let
                // resolvedSplit() decay it analytically back to crisp.
                let vx = value.predictedEndTranslation.width - value.translation.width
                let vy = value.predictedEndTranslation.height - value.translation.height
                let predicted = hypot(vx, vy)
                let snapMag = clamp((dragSplit + predicted / 120.0), 0, maxSplit)

                releaseSplit = snapMag
                releaseDir = normalized(dragDir)
                releaseTime = Date()
                dragSplit = 0

                // Spring the content back to center.
                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                    dragOffset = .zero
                }
            }
    }

    // MARK: - Content (self-contained, high-contrast — the edges where the split reads)

    private func content(dim: CGFloat, time: TimeInterval) -> some View {
        ZStack {
            // Faint moving guide rings for extra crisp edges to refract.
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(ringColor(i), lineWidth: max(1.5, dim * 0.012))
                    .frame(width: dim * (0.42 + CGFloat(i) * 0.2))
                    .opacity(0.5)
            }

            VStack(spacing: dim * 0.04) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: dim * 0.28, weight: .black))
                    .foregroundStyle(Color(red: 0.98, green: 0.98, blue: 1.0))

                Text("VELOCITY")
                    .font(.system(size: dim * 0.11, weight: .heavy, design: .rounded))
                    .tracking(dim * 0.012)
                    .foregroundStyle(Color(red: 0.96, green: 0.92, blue: 0.82))
            }
            .shadow(color: Color(red: 0, green: 0, blue: 0).opacity(0.35), radius: dim * 0.02)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backdrop(time: time))
        .drawingGroup() // flatten into one layer so layerEffect samples a composite
    }

    private func backdrop(time: TimeInterval) -> some View {
        let drift = sin(time * 0.4) * 0.5 + 0.5
        return LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.06, blue: 0.16),
                Color(red: 0.16, green: 0.08, blue: 0.10),
                Color(red: 0.06, green: 0.05, blue: 0.12)
            ],
            startPoint: UnitPoint(x: drift, y: 0),
            endPoint: UnitPoint(x: 1 - drift, y: 1)
        )
    }

    private func ringColor(_ i: Int) -> Color {
        switch i {
        case 0: return Color(red: 0.40, green: 0.85, blue: 1.0)
        case 1: return Color(red: 1.0, green: 0.45, blue: 0.75)
        default: return Color(red: 0.95, green: 0.85, blue: 0.40)
        }
    }

    // MARK: - Math helpers

    private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        min(max(v, lo), hi)
    }

    private func normalized(_ v: CGVector) -> CGVector {
        let len = hypot(v.dx, v.dy)
        guard len > 0.0001 else { return CGVector(dx: 1, dy: 0) }
        return CGVector(dx: v.dx / len, dy: v.dy / len)
    }
}

// MARK: - layerEffect wrapper

/// Applies the chromatic-velocity RGB split shader. Factored into its own modifier
/// to keep the body type-checker-friendly.
private struct ChromaticVelocityView_ChromaticSplit: ViewModifier {
    let split: CGFloat
    let dir: CGVector
    let maxOffset: CGFloat

    func body(content: Content) -> some View {
        let dx = Float(dir.dx)
        let dy = Float(dir.dy)
        let s = Float(split)
        return content.layerEffect(
            ShaderLibrary.chromaticVelocity(
                .float(s),
                .float2(dx, dy)
            ),
            maxSampleOffset: CGSize(width: maxOffset + 2, height: maxOffset + 2)
        )
    }
}
