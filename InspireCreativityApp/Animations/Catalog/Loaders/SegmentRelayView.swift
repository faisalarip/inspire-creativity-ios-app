// catalog-id: ld-segment-relay
import SwiftUI

/// Segment Relay — twelve discrete rounded segments arranged in a ring light up
/// one-by-one in a baton-pass relay, each lit segment fading on a trailing comet
/// tail as the next ignites.
///
/// Both `demo == true` and `demo == false` are self-driving (the spec's
/// interaction is "auto"). The interactive build adds a subtle direction/speed
/// nudge gesture so a touch still produces a tactile response, while never
/// stopping the relay.
struct SegmentRelayView: View {

    var demo: Bool = false

    // Ring configuration.
    private let segmentCount: Int = 12

    // Interactive state — a horizontal drag nudges relay speed & direction.
    // Idle (and `demo`) keep the baton walking on its own.
    @State private var speedScale: Double = 1.0

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            content(size: size, full: proxy.size)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        // `.gesture(_:including:)` is the idiomatic way to conditionally disable
        // a gesture: an `Optional<Gesture>` does not conform to `Gesture`, so a
        // `demo ? nil : speedGesture` ternary would fail to type-check.
        .gesture(speedGesture, including: demo ? .none : .all)
    }

    // MARK: - Content

    @ViewBuilder
    private func content(size: CGFloat, full: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            // Phase advances continuously; `speedScale` lets the gesture nudge it
            // without ever stalling (clamped away from zero).
            let phase = relayPhase(at: t)
            ZStack {
                backdrop(size: size)
                ring(size: size, phase: phase)
                hub(size: size, phase: phase)
            }
            .frame(width: full.width, height: full.height)
        }
    }

    // MARK: - Backdrop

    private func backdrop(size: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 0.05, green: 0.07, blue: 0.10),
                        Color(red: 0.02, green: 0.03, blue: 0.05)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.62
                )
            )
            .frame(width: size * 0.98, height: size * 0.98)
    }

    // MARK: - Ring of segments

    private func ring(size: CGFloat, phase: Double) -> some View {
        // The head position walks the ring; fractional so the leading edge
        // glides between discrete segments for a smoother baton hand-off.
        let head = phase * Double(segmentCount)
        return ZStack {
            ForEach(0..<segmentCount, id: \.self) { index in
                segment(index: index, size: size, head: head)
            }
        }
    }

    @ViewBuilder
    private func segment(index: Int, size: CGFloat, head: Double) -> some View {
        let intensity = intensity(for: index, head: head)
        let segLength = size * 0.20
        let segWidth = size * 0.072
        let radius = size * 0.355
        let angle = Double(index) / Double(segmentCount) * 360.0
        let glow = color(glowRGB)

        Capsule(style: .continuous)
            .fill(segmentFill(intensity: intensity))
            .frame(width: segWidth, height: segLength)
            .shadow(
                color: glow.opacity(0.85 * intensity),
                radius: size * 0.05 * intensity,
                x: 0,
                y: 0
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(
                        Color.white.opacity(0.16 + 0.34 * intensity),
                        lineWidth: max(0.5, size * 0.004)
                    )
                    .frame(width: segWidth, height: segLength)
            )
            .offset(y: -radius)
            .rotationEffect(.degrees(angle))
            // Lit segments lift very slightly toward the viewer.
            .scaleEffect(1.0 + 0.06 * intensity)
    }

    private func segmentFill(intensity: Double) -> LinearGradient {
        let dim: RGB = (0.12, 0.16, 0.21)
        let lit = blend(dim, glowRGB, intensity)
        let litBright = blend(lit, (0.85, 0.97, 1.0), intensity * 0.55)
        return LinearGradient(
            colors: [color(litBright), color(lit)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Center hub

    private func hub(size: CGFloat, phase: Double) -> some View {
        // A faint pulsing core that breathes once per lap, tying the relay together.
        let pulse = 0.5 + 0.5 * sin(phase * 2.0 * .pi)
        let core = size * 0.10
        let glow = color(glowRGB)
        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            glow.opacity(0.55 + 0.30 * pulse),
                            glow.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: core * 1.8
                    )
                )
                .frame(width: core * 3.4, height: core * 3.4)
            Circle()
                .fill(Color(red: 0.55, green: 0.85, blue: 1.0).opacity(0.9))
                .frame(width: core * 0.5, height: core * 0.5)
                .blur(radius: size * 0.004)
        }
    }

    // MARK: - Relay math

    /// Continuous lap phase in [0, 1). One lap takes ~3s at speedScale 1.0,
    /// which keeps the tile alive on a satisfying ~2.5–4s rhythm.
    private func relayPhase(at time: TimeInterval) -> Double {
        let lapDuration: Double = 3.0
        let effective = time * clampedSpeed() / lapDuration
        let wrapped = effective.truncatingRemainder(dividingBy: 1.0)
        return wrapped < 0 ? wrapped + 1.0 : wrapped
    }

    /// Each segment's brightness from its angular distance *behind* the head,
    /// producing the trailing comet tail. The segment at/just-passed the head is
    /// brightest; opacity decays around the ring so older segments fade out.
    private func intensity(for index: Int, head: Double) -> Double {
        let n = Double(segmentCount)
        // Distance measured as "how far behind the head this segment sits",
        // walking backward around the ring (0 = on the head).
        var behind = head - Double(index)
        behind = behind.truncatingRemainder(dividingBy: n)
        if behind < 0 { behind += n }

        // Exponential phosphor-style decay for the tail.
        let tailLength: Double = 4.5
        let decayed = exp(-behind / tailLength)

        // A small floor so segments are never fully invisible — the ring always
        // reads as a complete, legible loader on every frame.
        let floor: Double = 0.14
        return floor + (1.0 - floor) * decayed
    }

    private func clampedSpeed() -> Double {
        // Never zero: the relay always keeps moving, the gesture only nudges it.
        max(0.35, min(2.4, speedScale))
    }

    // MARK: - Interaction

    private var speedGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Horizontal drag maps to relay speed. Right = faster, left =
                // slower. (Clamped well away from zero so the relay never stalls.)
                let delta = value.translation.width / 120.0
                speedScale = 1.0 + delta
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    speedScale = 1.0
                }
            }
    }

    // MARK: - Palette helpers

    private typealias RGB = (Double, Double, Double)

    /// Cyan-leaning activity tint, carried as a self-contained RGB tuple so the
    /// blending math stays in numeric space (no UIKit `UIColor` round-trip).
    private var glowRGB: RGB { (0.30, 0.78, 1.0) }

    private func color(_ c: RGB) -> Color {
        Color(red: c.0, green: c.1, blue: c.2)
    }

    private func blend(_ a: RGB, _ b: RGB, _ t: Double) -> RGB {
        let ct = max(0.0, min(1.0, t))
        return (
            a.0 + (b.0 - a.0) * ct,
            a.1 + (b.1 - a.1) * ct,
            a.2 + (b.2 - a.2) * ct
        )
    }
}
