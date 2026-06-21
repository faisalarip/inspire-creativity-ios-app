// catalog-id: ges-rotate-clock-rewind
import SwiftUI

// Twist-to-Rewind Clock
// Rotate the clock face and the hands wind backward/forward while a ghosted
// scene (a sun arcing over a day/night sky) visually un-happens or replays.
// demo == true  -> self-driving triangle-wave time scrub (no touch).
// demo == false -> two-finger RotateGesture scrubs time; eases to nearest hour.

struct RotateClockRewindView: View {
    var demo: Bool = false

    // Time scrubber, expressed in "hours" across a 12h dial.
    // 0 ... maxHours. The hour hand makes one full turn over this range.
    private let maxHours: Double = 12.0

    // Interactive state.
    @State private var committedT: Double = 7.5      // resting time
    @State private var liveDelta: Double = 0          // hours added by the in-flight twist
    @State private var lastTickHour: Int = 7

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            if demo {
                demoBody(size: size)
            } else {
                interactiveBody(size: size)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Demo (self-driving)

    private func demoBody(size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let t = demoTime(at: timeline.date)
            ClockScene(t: t, maxHours: maxHours, size: size)
        }
    }

    /// Triangle wave: sweep time forward then backward over a ~3.4s loop so the
    /// clock visibly winds and un-winds. Stays inside [0, maxHours].
    private func demoTime(at date: Date) -> Double {
        let period: Double = 3.4
        let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
        // 0->1->0 triangle.
        let tri = phase < 0.5 ? (phase * 2.0) : (2.0 - phase * 2.0)
        // Sweep across most of the dial, but never to the absolute edges so the
        // scene never reads as fully "off".
        let lo = 0.5
        let hi = maxHours - 0.5
        return lo + tri * (hi - lo)
    }

    // MARK: - Interactive

    private var currentT: Double {
        clampTime(committedT + liveDelta)
    }

    private func interactiveBody(size: CGSize) -> some View {
        ClockScene(t: currentT, maxHours: maxHours, size: size)
            .contentShape(Rectangle())
            .gesture(rotationGesture)
            .sensoryFeedback(.selection, trigger: tickHour)
    }

    private var tickHour: Int {
        // Hour 0...11 derived from current time, used to fire a haptic per tick.
        Int(currentT.rounded(.down)) % 12
    }

    private var rotationGesture: some Gesture {
        RotateGesture()
            .onChanged { value in
                // One full rotation (2π) scrubs the whole 12h dial.
                let hours = value.rotation.radians / (2.0 * .pi) * maxHours
                liveDelta = hours
                let h = Int(clampTime(committedT + hours).rounded(.down)) % 12
                if h != lastTickHour { lastTickHour = h }
            }
            .onEnded { value in
                let hours = value.rotation.radians / (2.0 * .pi) * maxHours
                let target = nearestHour(clampTime(committedT + hours))
                withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                    committedT = target
                    liveDelta = 0
                }
            }
    }

    private func clampTime(_ v: Double) -> Double {
        min(max(v, 0), maxHours)
    }

    private func nearestHour(_ v: Double) -> Double {
        let r = v.rounded()
        return min(max(r, 0), maxHours)
    }
}

// MARK: - Scene (single rendering source of truth)

private struct ClockScene: View {
    let t: Double          // time in hours, 0 ... maxHours
    let maxHours: Double
    let size: CGSize

    private var radius: CGFloat { min(size.width, size.height) * 0.5 }

    /// Day progress 0...1 across the dial, used to drive the ghost scene.
    private var dayProgress: Double {
        guard maxHours > 0 else { return 0 }
        return min(max(t / maxHours, 0), 1)
    }

    var body: some View {
        ZStack {
            GhostScene(progress: dayProgress, radius: radius)
            ClockFace(radius: radius)
            ClockHands(t: t, maxHours: maxHours, radius: radius)
            CenterCap(radius: radius)
        }
        .frame(width: radius * 2, height: radius * 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Ghost scene (day/night the hands scrub through)

private struct GhostScene: View {
    let progress: Double   // 0 = start of day, 1 = end of day
    let radius: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(skyGradient)
            sun
            stars
        }
        .frame(width: radius * 1.9, height: radius * 1.9)
        .clipShape(Circle())
        .opacity(0.92)
    }

    // Sun travels along an arc from left horizon, up over the top, down to right.
    private var sunAngle: Double {
        // Map progress 0...1 to angle 180°...360° going over the top (clockwise arc).
        // We trace a semicircle: angle from 180° (left) to 360° (right)
        // measured so the sun peaks at the top.
        180.0 + progress * 180.0
    }

    private var sunPoint: CGPoint {
        let r = radius * 0.62
        let rad = sunAngle * .pi / 180.0
        let x = cos(rad) * r
        let y = sin(rad) * r   // sin negative for top half in screen coords handled below
        return CGPoint(x: x, y: y)
    }

    // How high the sun is (1 at noon, 0 at horizons) -> drives sky color + brightness.
    private var elevation: Double {
        // peaks at progress 0.5
        let e = sin(progress * .pi)
        return max(0, e)
    }

    private var sun: some View {
        let d = radius * 0.34
        // Convert sunPoint (centered, y grows toward bottom of arc) into screen offset.
        // sin(rad) for angles 180->360 is 0 -> negative -> 0, so the sun rides the TOP.
        return Circle()
            .fill(
                RadialGradient(
                    colors: [
                        sunCore.opacity(0.95 * (0.4 + 0.6 * elevation)),
                        sunCore.opacity(0.0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: d * 0.85
                )
            )
            .overlay(
                Circle()
                    .fill(sunCore.opacity(0.35 + 0.55 * elevation))
                    .frame(width: d * 0.46, height: d * 0.46)
            )
            .frame(width: d, height: d)
            .offset(x: sunPoint.x, y: sunPoint.y)
    }

    // Stars fade in as the sun sets (low elevation), giving the "un-happens" feel
    // when time reverses.
    private var stars: some View {
        let nightAmount = 1.0 - elevation
        return Canvas { ctx, sz in
            let pts: [(CGFloat, CGFloat, CGFloat)] = [
                (0.22, 0.24, 1.4), (0.72, 0.20, 1.0), (0.58, 0.34, 1.6),
                (0.34, 0.16, 1.1), (0.82, 0.40, 1.3), (0.16, 0.40, 0.9),
                (0.66, 0.50, 1.2), (0.46, 0.22, 1.0)
            ]
            for (fx, fy, r) in pts {
                let rect = CGRect(
                    x: fx * sz.width - r,
                    y: fy * sz.height - r,
                    width: r * 2,
                    height: r * 2
                )
                ctx.opacity = nightAmount * 0.9
                ctx.fill(Path(ellipseIn: rect), with: .color(starColor))
            }
        }
        .frame(width: radius * 1.9, height: radius * 1.9)
        .allowsHitTesting(false)
    }

    private var skyGradient: LinearGradient {
        // Interpolate between night (low elevation) and day (high elevation).
        let e = elevation
        let top = mix(nightTop, dayTop, e)
        let bottom = mix(nightBottom, dayBottom, e)
        return LinearGradient(
            colors: [top, bottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // Palette helpers (Color(red:green:blue:) literals only).
    private var dayTop: (Double, Double, Double) { (0.30, 0.58, 0.92) }
    private var dayBottom: (Double, Double, Double) { (0.72, 0.86, 0.98) }
    private var nightTop: (Double, Double, Double) { (0.05, 0.06, 0.15) }
    private var nightBottom: (Double, Double, Double) { (0.13, 0.10, 0.26) }
    private var sunCore: Color { Color(red: 1.0, green: 0.86, blue: 0.42) }
    private var starColor: Color { Color(red: 0.92, green: 0.94, blue: 1.0) }

    private func mix(_ a: (Double, Double, Double), _ b: (Double, Double, Double), _ f: Double) -> Color {
        let cf = min(max(f, 0), 1)
        return Color(
            red: a.0 + (b.0 - a.0) * cf,
            green: a.1 + (b.1 - a.1) * cf,
            blue: a.2 + (b.2 - a.2) * cf
        )
    }
}

// MARK: - Clock face (rim + ticks)

private struct ClockFace: View {
    let radius: CGFloat

    var body: some View {
        ZStack {
            // Translucent bezel so the ghost scene reads through.
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.95, blue: 0.97).opacity(0.9),
                            Color(red: 0.55, green: 0.57, blue: 0.66).opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(2, radius * 0.05)
                )
                .frame(width: radius * 1.96, height: radius * 1.96)

            ticks
        }
    }

    private var ticks: some View {
        ForEach(0..<12, id: \.self) { i in
            let isMajor = i % 3 == 0
            let len: CGFloat = isMajor ? radius * 0.16 : radius * 0.09
            let w: CGFloat = isMajor ? max(2, radius * 0.035) : max(1, radius * 0.02)
            Capsule()
                .fill(Color(red: 0.96, green: 0.97, blue: 1.0).opacity(isMajor ? 0.95 : 0.65))
                .frame(width: w, height: len)
                .offset(y: -(radius * 0.86 - len / 2))
                .rotationEffect(.degrees(Double(i) * 30.0))
        }
    }
}

// MARK: - Hands

private struct ClockHands: View {
    let t: Double          // hours, 0 ... maxHours
    let maxHours: Double
    let radius: CGFloat

    // Hour hand: one full turn across the whole dial scrub.
    private var hourAngle: Angle {
        .degrees((t / maxHours) * 360.0)
    }

    // Minute hand: 12x faster, so it whirls as you scrub — the "winding" cue.
    private var minuteAngle: Angle {
        .degrees((t / maxHours) * 360.0 * 12.0)
    }

    var body: some View {
        ZStack {
            hand(length: radius * 0.5, width: max(3, radius * 0.065),
                 color: Color(red: 0.97, green: 0.97, blue: 1.0), angle: hourAngle)
            hand(length: radius * 0.74, width: max(2, radius * 0.04),
                 color: Color(red: 0.85, green: 0.88, blue: 0.98), angle: minuteAngle)
            secondHand
        }
    }

    private func hand(length: CGFloat, width: CGFloat, color: Color, angle: Angle) -> some View {
        Capsule()
            .fill(color)
            .frame(width: width, height: length)
            .offset(y: -length / 2)
            .rotationEffect(angle)
            .shadow(color: Color.black.opacity(0.35), radius: 2, x: 0, y: 1)
    }

    private var secondAngle: Angle {
        .degrees((t / maxHours) * 360.0 * 60.0)
    }

    private var secondHand: some View {
        let length = radius * 0.82
        return Capsule()
            .fill(Color(red: 1.0, green: 0.42, blue: 0.38))
            .frame(width: max(1, radius * 0.018), height: length)
            .offset(y: -length / 2 + radius * 0.12)
            .rotationEffect(secondAngle)
    }
}

private struct CenterCap: View {
    let radius: CGFloat
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 0.98, green: 0.98, blue: 1.0),
                        Color(red: 0.62, green: 0.64, blue: 0.74)
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: radius * 0.14
                )
            )
            .frame(width: radius * 0.14, height: radius * 0.14)
            .shadow(color: Color.black.opacity(0.4), radius: 2, x: 0, y: 1)
    }
}
