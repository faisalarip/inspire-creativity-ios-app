// catalog-id: mtl-jelly-wobble
// catalog-metal: JellyWobbleView.metal
import SwiftUI

/// Jelly Wobble — flinging the surface sends a springy, decaying shockwave that
/// jiggles the pixels like a block of gelatin with directional inertia.
///
/// `.distortionEffect` (iOS 17) offsets each sample coordinate by a radial
/// damped-sine wave emanating from an impulse origin. The wave's amplitude is
/// seeded by the drag velocity and decays via the in-shader damping term, so
/// the panel settles on its own after release.
///
/// - demo == true  : a TimelineView re-seeds a pseudo-random impulse every few
///   seconds (purely from the clock, no cross-frame state) so the panel keeps
///   sloshing with no touch.
/// - demo == false : a DragGesture(minimumDistance: 0) reads the release
///   velocity and location to fire a real impulse.
struct JellyWobbleView: View {
    var demo: Bool = false

    /// Peak displacement in points. maxSampleOffset is sized to match this so
    /// the wobble never clips at the panel edges.
    private let peakAmplitude: CGFloat = 26

    /// One live impulse for the interactive branch.
    @State private var impulse = JellyWobbleView_Impulse.zero

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            TimelineView(.animation) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let state = waveState(now: now, size: size)
                JellyWobbleView_JellyBackdrop()
                    .distortionEffect(
                        ShaderLibrary.jellyWobble(
                            .float(Float(state.time)),
                            .float2(Float(state.origin.x), Float(state.origin.y)),
                            .float(Float(state.amplitude)),
                            .float2(Float(state.dir.dx), Float(state.dir.dy))
                        ),
                        // Worst case the radial crest (~27pt) and the directional
                        // drag slosh (~13pt) align, so budget ~1.6x peak + slack
                        // to guarantee the wobble never clips at the panel edges.
                        maxSampleOffset: CGSize(width: peakAmplitude * 1.6 + 8,
                                                height: peakAmplitude * 1.6 + 8)
                    )
            }
            .contentShape(Rectangle())
            // Attach unconditionally; the hit-test mask disables our gesture in
            // demo mode (Optional<Gesture> doesn't conform to Gesture, so a
            // `demo ? nil : …` ternary would fail to compile).
            .gesture(flingGesture(size: size),
                     including: demo ? .subviews : .all)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Wave state resolution

    struct WaveState {
        var time: Double          // seconds elapsed since the active impulse
        var origin: CGPoint
        var amplitude: CGFloat
        var dir: CGVector         // normalized fling direction (or zero)
    }

    private func waveState(now: TimeInterval, size: CGSize) -> WaveState {
        demo ? demoState(now: now, size: size) : liveState(now: now, size: size)
    }

    /// Stateless demo: derive a fresh impulse from the integer cycle index so a
    /// new nudge fires every `period` seconds with no @State mutation per frame.
    private func demoState(now: TimeInterval, size: CGSize) -> WaveState {
        let period: Double = 3.2
        let cycle = floor(now / period)
        let phase = now - cycle * period

        let h1 = hash(cycle * 1.0 + 0.13)
        let h2 = hash(cycle * 1.0 + 0.57)
        let h3 = hash(cycle * 1.0 + 0.91)

        let ox = (0.2 + 0.6 * h1) * Double(size.width)
        let oy = (0.2 + 0.6 * h2) * Double(size.height)
        let origin = CGPoint(x: ox, y: oy)
        let angle: Double = h3 * .pi * 2.0
        let dir = CGVector(dx: cos(angle), dy: sin(angle))
        // Vary the kick so some cycles slosh harder than others.
        let amp = peakAmplitude * CGFloat(0.6 + 0.4 * hash(cycle + 0.33))

        return WaveState(time: phase, origin: origin, amplitude: amp, dir: dir)
    }

    /// Interactive: elapsed since the stored impulse fired; amplitude is held at
    /// its seeded value and the shader's decay term settles it over time.
    private func liveState(now: TimeInterval, size: CGSize) -> WaveState {
        let elapsed = max(0, now - impulse.startDate)
        // Let the impulse fully expire so the resting state is undistorted.
        let amp: CGFloat = elapsed > 3.0 ? 0 : impulse.amplitude
        let fallbackOrigin = CGPoint(x: size.width / 2, y: size.height / 2)
        let origin = impulse.origin == .zero ? fallbackOrigin : impulse.origin
        return WaveState(time: elapsed,
                         origin: origin,
                         amplitude: amp,
                         dir: impulse.dir)
    }

    // MARK: - Gesture

    private func flingGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { value in
                let v = value.velocity                // points / second (iOS 17)
                let speed = hypot(v.width, v.height)
                let location = value.location

                // Map fling speed → amplitude, clamped to the peak.
                let mapped = min(peakAmplitude, peakAmplitude * speed / 2400)
                // A tap with no velocity still gives a gentle, non-directional nudge.
                let amp = max(peakAmplitude * 0.35, mapped)

                let dir: CGVector
                if speed > 1 {
                    dir = CGVector(dx: v.width / speed, dy: v.height / speed)
                } else {
                    dir = .zero
                }

                impulse = JellyWobbleView_Impulse(
                    startDate: Date().timeIntervalSinceReferenceDate,
                    origin: clampedPoint(location, in: size),
                    amplitude: amp,
                    dir: dir
                )
            }
    }

    private func clampedPoint(_ p: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: min(max(0, p.x), size.width),
                y: min(max(0, p.y), size.height))
    }

    /// Deterministic 0…1 pseudo-random hash from a Double seed.
    private func hash(_ x: Double) -> Double {
        let v = sin(x * 127.1 + 311.7) * 43758.5453
        return v - floor(v)
    }
}

// MARK: - JellyWobbleView_Impulse model

private struct JellyWobbleView_Impulse {
    var startDate: TimeInterval
    var origin: CGPoint
    var amplitude: CGFloat
    var dir: CGVector

    static let zero = JellyWobbleView_Impulse(startDate: -100,
                              origin: .zero,
                              amplitude: 0,
                              dir: .zero)
}

// MARK: - Backdrop

/// High-frequency content so the coordinate warp is actually visible. A solid
/// fill would distort invisibly — we need bold edges (grid + rings + label).
private struct JellyWobbleView_JellyBackdrop: View {
    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.10, blue: 0.22),
                        Color(red: 0.16, green: 0.06, blue: 0.26)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                gridLayer(size: size)
                ringLayer(size: size)
                label(size: size)
            }
            .frame(width: size.width, height: size.height)
        }
    }

    private func gridLayer(size: CGSize) -> some View {
        let spacing = max(14, min(size.width, size.height) / 9)
        let cols = Int((size.width / spacing).rounded(.up)) + 1
        let rows = Int((size.height / spacing).rounded(.up)) + 1
        let lineColor = Color(red: 0.45, green: 0.72, blue: 1.0).opacity(0.32)
        return Path { path in
            for c in 0...cols {
                let x = CGFloat(c) * spacing
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for r in 0...rows {
                let y = CGFloat(r) * spacing
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
        }
        .stroke(lineColor, lineWidth: 1)
    }

    private func ringLayer(size: CGSize) -> some View {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxR = max(size.width, size.height) * 0.55
        let count = 5
        let step = maxR / CGFloat(count)
        let ringColor = Color(red: 1.0, green: 0.55, blue: 0.78).opacity(0.5)
        return Path { path in
            for i in 1...count {
                let radius = step * CGFloat(i)
                let rect = CGRect(x: center.x - radius,
                                  y: center.y - radius,
                                  width: radius * 2,
                                  height: radius * 2)
                path.addEllipse(in: rect)
            }
        }
        .stroke(ringColor, lineWidth: 1.5)
    }

    private func label(size: CGSize) -> some View {
        let fontSize = max(15, min(size.width, size.height) * 0.16)
        return Text("JELLY")
            .font(.system(size: fontSize, weight: .black, design: .rounded))
            .tracking(fontSize * 0.05)
            .foregroundStyle(Color(red: 1.0, green: 0.97, blue: 0.78))
            .shadow(color: Color(red: 1.0, green: 0.45, blue: 0.6).opacity(0.6),
                    radius: 6)
    }
}
