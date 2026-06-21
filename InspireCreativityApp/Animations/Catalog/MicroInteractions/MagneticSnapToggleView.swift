// catalog-id: mi-magnetic-snap-toggle
import SwiftUI

/// Magnetic Snap Toggle — a draggable toggle whose knob accelerates with
/// spring overshoot toward the nearest end on release, the track color
/// sweeping behind it. `demo == true` auto-cycles the magnetic yank, no touch.
struct MagneticSnapToggleView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            let metrics = MagneticSnapToggleView_ToggleMetrics(size: geo.size)
            Group {
                if demo {
                    MagneticSnapToggleView_DemoToggle(metrics: metrics)
                } else {
                    MagneticSnapToggleView_InteractiveToggle(metrics: metrics)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Layout metrics (size-relative, recomputed from live geometry)

private struct MagneticSnapToggleView_ToggleMetrics {
    let trackWidth: CGFloat
    let trackHeight: CGFloat
    let knobDiameter: CGFloat
    let padding: CGFloat
    let overshootReserve: CGFloat
    let originX: CGFloat
    let centerY: CGFloat

    init(size: CGSize) {
        let maxTrackW = max(size.width - 24, 40)
        let idealW = min(maxTrackW, size.width * 0.74)
        let idealH = min(size.height * 0.42, idealW * 0.5)
        let h = max(min(idealH, idealW * 0.55), 22)
        self.trackHeight = h
        self.trackWidth = max(idealW, h * 1.9)
        self.padding = h * 0.12
        self.knobDiameter = h - padding * 2
        // Headroom so a 0.6-damping spring overshoots without poking past the capsule.
        self.overshootReserve = max(h * 0.16, 4)
        self.originX = (size.width - trackWidth) / 2
        self.centerY = size.height / 2
    }

    /// Horizontal distance the knob center travels between resting ends.
    var travel: CGFloat {
        max(trackWidth - knobDiameter - padding * 2 - overshootReserve * 2, 1)
    }

    /// Knob center X (local to the track) for normalized progress 0...1.
    func knobCenterX(progress: Double) -> CGFloat {
        let p = CGFloat(min(max(progress, 0), 1))
        return padding + overshootReserve + knobDiameter / 2 + travel * p
    }
}

// MARK: - Shared visual (track + fill + knob), parameterized by progress

private struct MagneticSnapToggleView_ToggleBody: View {
    let metrics: MagneticSnapToggleView_ToggleMetrics
    let progress: Double
    let isDragging: Bool

    private var clamped: Double { min(max(progress, 0), 1) }

    private var fillColor: Color {
        let t = clamped
        return Color(red: lerp(0.20, 0.30, t),
                     green: lerp(0.22, 0.80, t),
                     blue: lerp(0.28, 0.46, t))
    }

    var body: some View {
        ZStack(alignment: .leading) {
            trackBase
            trackFill
            knob
        }
        .frame(width: metrics.trackWidth, height: metrics.trackHeight)
        .position(x: metrics.originX + metrics.trackWidth / 2, y: metrics.centerY)
    }

    private var trackBase: some View {
        Capsule()
            .fill(Color(red: 0.13, green: 0.13, blue: 0.17))
            .overlay(
                Capsule().stroke(Color(red: 0.30, green: 0.30, blue: 0.36), lineWidth: 1)
            )
    }

    private var trackFill: some View {
        let knobX = metrics.knobCenterX(progress: clamped)
        let fillW = max(knobX + metrics.knobDiameter / 2 + metrics.padding,
                        metrics.trackHeight)
        return Capsule()
            .fill(
                LinearGradient(colors: [fillColor.opacity(0.95), fillColor.opacity(0.62)],
                               startPoint: .leading, endPoint: .trailing)
            )
            .frame(width: fillW)
            .opacity(0.18 + clamped * 0.82)
            .frame(width: metrics.trackWidth, alignment: .leading)
            .clipShape(Capsule())
            .allowsHitTesting(false)
    }

    private var knob: some View {
        let d = metrics.knobDiameter
        let cx = metrics.knobCenterX(progress: clamped)
        return Circle()
            .fill(
                LinearGradient(colors: [Color(red: 1, green: 1, blue: 1),
                                        Color(red: 0.88, green: 0.90, blue: 0.94)],
                               startPoint: .top, endPoint: .bottom)
            )
            .frame(width: d, height: d)
            .overlay(
                Circle().stroke(Color(red: 0, green: 0, blue: 0).opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color(red: 0, green: 0, blue: 0).opacity(0.30),
                    radius: isDragging ? 5 : 3, x: 0, y: isDragging ? 3 : 2)
            .scaleEffect(isDragging ? 1.07 : 1.0)
            .position(x: cx, y: metrics.trackHeight / 2)
    }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
}

// MARK: - Interactive (demo == false)

private struct MagneticSnapToggleView_InteractiveToggle: View {
    let metrics: MagneticSnapToggleView_ToggleMetrics

    @State private var progress: Double = 0
    @State private var dragStartProgress: Double = 0
    @State private var isDragging = false
    @State private var snapCount: Int = 0       // changes only on landing -> .impact
    @State private var midCrossings: Int = 0    // changes on live midpoint cross -> .selection
    @State private var wasPastMid: Bool = false

    var body: some View {
        MagneticSnapToggleView_ToggleBody(metrics: metrics, progress: progress, isDragging: isDragging)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .sensoryFeedback(.selection, trigger: midCrossings)
            .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.85), trigger: snapCount)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    dragStartProgress = progress
                    wasPastMid = progress >= 0.5
                }
                let delta = Double(value.translation.width / max(metrics.travel, 1))
                progress = min(max(dragStartProgress + delta, 0), 1)
                let pastMid = progress >= 0.5
                if pastMid != wasPastMid {
                    wasPastMid = pastMid
                    midCrossings += 1
                }
            }
            .onEnded { value in
                isDragging = false
                let moved = abs(value.translation.width)
                let target: Double
                if moved < 6 {
                    // No meaningful drag -> treat as a tap, flip to the opposite end.
                    target = dragStartProgress < 0.5 ? 1 : 0
                } else {
                    // Snap to the nearest end by current position (midpoint rule).
                    target = progress >= 0.5 ? 1 : 0
                }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                    progress = target
                }
                snapCount += 1
            }
    }
}

// MARK: - Demo (demo == true) — self-driving magnetic yank loop

private struct MagneticSnapToggleView_DemoToggle: View {
    let metrics: MagneticSnapToggleView_ToggleMetrics

    var body: some View {
        PhaseAnimator(MagneticSnapToggleView_DemoPhase.allCases) { phase in
            MagneticSnapToggleView_ToggleBody(metrics: metrics, progress: phase.progress, isDragging: phase.dragging)
        } animation: { phase in
            phase.animation
        }
    }
}

private enum MagneticSnapToggleView_DemoPhase: CaseIterable {
    case settleOff, yankOn, holdOn, yankOff, holdOff

    var progress: Double {
        switch self {
        case .settleOff: return 0
        case .yankOn:    return 1
        case .holdOn:    return 1
        case .yankOff:   return 0
        case .holdOff:   return 0
        }
    }

    var dragging: Bool {
        // Lift the knob during the snap legs for a tactile, alive feel.
        switch self {
        case .yankOn, .yankOff:             return true
        case .settleOff, .holdOn, .holdOff: return false
        }
    }

    var animation: Animation {
        switch self {
        case .settleOff:
            return .easeInOut(duration: 0.12)
        case .yankOn:
            return .spring(response: 0.35, dampingFraction: 0.6).delay(0.15)
        case .holdOn:
            return .easeInOut(duration: 0.1).delay(0.95)
        case .yankOff:
            return .spring(response: 0.35, dampingFraction: 0.6).delay(0.15)
        case .holdOff:
            return .easeInOut(duration: 0.1).delay(0.95)
        }
    }
}
