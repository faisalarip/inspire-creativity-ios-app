// catalog-id: ld-pendulum-newton
import SwiftUI

/// Newton's Cradle — five suspended balls; the end ball arcs in, momentum
/// transfers through the dead-still middle three, and the far ball kicks out,
/// alternating sides forever.
///
/// - `demo == true`  → self-driving cradle on a continuous loop.
/// - `demo == false` → drag an end ball up about its pivot; release hands off
///   to the eased auto cradle cycle.
struct PendulumNewtonView: View {
    var demo: Bool = false

    // Loop period for one full left+right strike cycle (seconds).
    private let period: Double = 3.0
    // Maximum swing angle in degrees.
    private let maxAngle: Double = 52

    // Interactive drag state.
    @State private var dragAngle: Double = 0          // current dragged angle (deg, negative = left)
    @State private var isDragging: Bool = false
    @State private var releaseDate: Date? = nil       // when the user let go
    @State private var releaseAngle: Double = 0        // angle at release (deg)

    var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor)
    }

    private var backgroundColor: Color {
        Color(red: 0.039, green: 0.063, blue: 0.078)
    }

    // MARK: - Layout-derived metrics

    private func metrics(for size: CGSize) -> Metrics {
        let w = size.width
        let h = size.height
        let side = min(w, h)

        // Ball diameter sized so five touching balls fit comfortably across.
        let diameter = max(8, side * 0.16)
        let radius = diameter / 2

        // String length scales with available height.
        let stringLength = max(diameter * 1.1, side * 0.42)

        // Suspension bar sits in the upper portion; pivots spaced one diameter
        // apart so balls touch at rest.
        let totalWidth = diameter * 5
        let centerX = w / 2
        let firstPivotX = centerX - totalWidth / 2 + radius
        let barY = h / 2 - stringLength / 2 - radius * 0.4

        return Metrics(
            size: size,
            diameter: diameter,
            radius: radius,
            stringLength: stringLength,
            firstPivotX: firstPivotX,
            barY: barY
        )
    }

    struct Metrics {
        let size: CGSize
        let diameter: CGFloat
        let radius: CGFloat
        let stringLength: CGFloat
        let firstPivotX: CGFloat
        let barY: CGFloat

        func pivot(_ index: Int) -> CGPoint {
            CGPoint(x: firstPivotX + CGFloat(index) * diameter, y: barY)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        let m = metrics(for: size)
        let base = TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let angles = currentAngles(at: t)
            cradle(m: m, angles: angles)
        }
        .contentShape(Rectangle())

        if demo {
            base
        } else {
            base.gesture(dragGesture(for: m))
        }
    }

    @ViewBuilder
    private func cradle(m: Metrics, angles: [Double]) -> some View {
        ZStack {
            suspensionBar(m: m)
            ForEach(0..<5, id: \.self) { i in
                pendulum(index: i, angle: angles[i], m: m)
            }
        }
    }

    // MARK: - Subviews

    private func suspensionBar(m: Metrics) -> some View {
        let leftX = m.pivot(0).x
        let rightX = m.pivot(4).x
        let barWidth = (rightX - leftX) + m.diameter
        return Capsule()
            .fill(barGradient)
            .frame(width: barWidth, height: max(4, m.diameter * 0.18))
            .overlay(
                Capsule()
                    .stroke(Color(red: 1, green: 1, blue: 1).opacity(0.18), lineWidth: 0.6)
            )
            .position(x: (leftX + rightX) / 2, y: m.barY)
            .shadow(color: Color(red: 0, green: 0, blue: 0).opacity(0.5),
                    radius: 4, x: 0, y: 2)
    }

    private var barGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.42, green: 0.46, blue: 0.52),
                Color(red: 0.20, green: 0.23, blue: 0.28)
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    /// A single pendulum (string + ball) rotated about its top pivot.
    private func pendulum(index: Int, angle: Double, m: Metrics) -> some View {
        let pivot = m.pivot(index)
        return PendulumNewtonView_PendulumArm(stringLength: m.stringLength, radius: m.radius)
            .rotationEffect(.degrees(angle), anchor: .top)
            // The arm's natural top is the pivot point; place it there.
            .frame(width: m.diameter, height: m.stringLength + m.diameter)
            .position(x: pivot.x, y: pivot.y + (m.stringLength + m.diameter) / 2)
    }

    // MARK: - Angle model

    /// Phase progress in [0, 1) for the auto loop at a given absolute time.
    private func autoPhase(at t: Double) -> Double {
        let p = (t.truncatingRemainder(dividingBy: period)) / period
        return p < 0 ? p + 1 : p
    }

    /// Pure angle function: a single sine drives one end ball per half-cycle.
    /// Negative = the left end ball swung outward to the left;
    /// positive = the right end ball swung outward to the right.
    /// Returns angles (deg) for all five balls; middle three are always 0.
    private func autoAngles(phase: Double) -> [Double] {
        // Offset so the loop starts with a raised ball rather than centered.
        let shifted = (phase + 0.75).truncatingRemainder(dividingBy: 1.0)
        let s = sin(2.0 * .pi * shifted)
        let left = s < 0 ? maxAngle * s : 0      // s<0 → negative angle (left)
        let right = s > 0 ? maxAngle * s : 0     // s>0 → positive angle (right)
        return [left, 0, 0, 0, right]
    }

    /// Maps a raised left-ball angle (negative, in [-maxAngle, 0]) to the auto
    /// loop phase at which the left ball sits at that angle while swinging down.
    /// The left ball spans phase 0 (fully raised) → 0.25 (centered).
    private func phaseForLeftAngle(_ angle: Double) -> Double {
        let clamped = min(0, max(-maxAngle, angle))
        let s = clamped / maxAngle            // in [-1, 0]
        // left angle = maxAngle * sin(2π(phase + 0.75)); solve for phase.
        return 0.25 + asin(s) / (2.0 * .pi)   // in [0, 0.25]
    }

    /// Resolves the angle array for the current frame, blending in the
    /// interactive drag / release handoff when not in demo mode.
    private func currentAngles(at t: Double) -> [Double] {
        if demo {
            return autoAngles(phase: autoPhase(at: t))
        }

        if isDragging {
            // Left end ball follows the finger; others rest.
            return [dragAngle, 0, 0, 0, 0]
        }

        if let release = releaseDate {
            // Resume the loop at the phase matching the released angle so the
            // dragged left ball continues its eased swing-down without a jump,
            // then hands off to the auto cradle cycle.
            let elapsed = t - release.timeIntervalSinceReferenceDate
            let startPhase = phaseForLeftAngle(releaseAngle)
            let raw = (startPhase + elapsed / period).truncatingRemainder(dividingBy: 1.0)
            return autoAngles(phase: raw < 0 ? raw + 1 : raw)
        }

        // Idle before any interaction: keep it alive with the auto loop too.
        return autoAngles(phase: autoPhase(at: t))
    }

    // MARK: - Gesture

    private func dragGesture(for m: Metrics) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDragging = true
                releaseDate = nil
                // Map horizontal translation to a swing angle about the left
                // pivot. Dragging left raises the left ball (negative angle).
                let dx = value.translation.width
                let dy = value.translation.height
                // atan2 about the pivot gives a natural arc; clamp to maxAngle.
                let raw = atan2(dx, max(1, m.stringLength + dy)) * 180 / .pi
                dragAngle = min(0, max(-maxAngle, raw))
            }
            .onEnded { _ in
                isDragging = false
                releaseAngle = dragAngle
                releaseDate = Date()
            }
    }
}

// MARK: - Pendulum arm (string + ball)

/// A top-anchored arm: a thin string from the top down to a metallic ball.
/// Its visual top edge is the pivot, so rotating with anchor `.top` swings it.
private struct PendulumNewtonView_PendulumArm: View {
    let stringLength: CGFloat
    let radius: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            stringShape
                .stroke(stringGradient, lineWidth: max(1, radius * 0.07))
                .frame(width: radius * 2, height: stringLength)
            PendulumNewtonView_BallView(radius: radius)
        }
    }

    private var stringShape: some Shape {
        PendulumNewtonView_StringLine()
    }

    private var stringGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.55, green: 0.58, blue: 0.62).opacity(0.9),
                Color(red: 0.30, green: 0.32, blue: 0.36).opacity(0.7)
            ],
            startPoint: .top, endPoint: .bottom
        )
    }
}

/// A vertical line down the center of its rect (the string).
private struct PendulumNewtonView_StringLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return p
    }
}

/// A polished chrome ball with a specular highlight.
private struct PendulumNewtonView_BallView: View {
    let radius: CGFloat

    var body: some View {
        Circle()
            .fill(sphereGradient)
            .overlay(rim)
            .overlay(highlight)
            .frame(width: radius * 2, height: radius * 2)
            .shadow(color: Color(red: 0, green: 0, blue: 0).opacity(0.45),
                    radius: radius * 0.18, x: 0, y: radius * 0.12)
    }

    private var sphereGradient: RadialGradient {
        RadialGradient(
            colors: [
                Color(red: 0.86, green: 0.89, blue: 0.94),
                Color(red: 0.55, green: 0.60, blue: 0.68),
                Color(red: 0.20, green: 0.23, blue: 0.29)
            ],
            center: UnitPoint(x: 0.35, y: 0.30),
            startRadius: 0,
            endRadius: radius * 1.9
        )
    }

    private var rim: some View {
        Circle()
            .stroke(Color(red: 1, green: 1, blue: 1).opacity(0.22),
                    lineWidth: max(0.5, radius * 0.04))
    }

    private var highlight: some View {
        Ellipse()
            .fill(Color(red: 1, green: 1, blue: 1).opacity(0.55))
            .frame(width: radius * 0.6, height: radius * 0.4)
            .blur(radius: radius * 0.08)
            .offset(x: -radius * 0.32, y: -radius * 0.42)
    }
}
