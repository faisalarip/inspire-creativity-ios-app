// catalog-id: mi-slide-to-confirm
import SwiftUI
import Foundation

// MARK: - Slide to Confirm
// A handle is dragged along a track that fills behind it with a liquid sheen.
// Reaching the end snaps it shut and morphs the arrow into a checkmark.
// demo == true  -> self-driving PhaseAnimator loop (slide -> lock -> reset).
// demo == false -> real DragGesture, clamped, with spring snap + haptics.
struct SlideToConfirmView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        let metrics = SlideToConfirmView_Metrics(size: size)

        ZStack {
            if demo {
                demoTrack(metrics: metrics)
            } else {
                SlideToConfirmView_InteractiveTrack(metrics: metrics)
            }
        }
        .frame(width: metrics.trackWidth, height: metrics.trackHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Demo (auto-driving)

    @ViewBuilder
    private func demoTrack(metrics: SlideToConfirmView_Metrics) -> some View {
        // Phases: rest -> slid-to-end (locked) -> hold -> reset.
        // Never lands on a blank frame; the held phase shows the checkmark.
        PhaseAnimator([SlideToConfirmView_DemoPhase.rest, .filling, .locked, .hold]) { phase in
            SlideToConfirmView_TrackBody(
                metrics: metrics,
                progress: phase.progress,
                locked: phase.locked
            )
        } animation: { phase in
            switch phase {
            case .rest:    return .easeInOut(duration: 0.35)
            case .filling: return .easeInOut(duration: 1.3)
            case .locked:  return .spring(response: 0.35, dampingFraction: 0.6)
            case .hold:    return .easeInOut(duration: 0.9)
            }
        }
    }
}

// MARK: - Phase model

private enum SlideToConfirmView_DemoPhase: CaseIterable {
    case rest, filling, locked, hold

    var progress: Double {
        switch self {
        case .rest:    return 0.0
        case .filling: return 0.92
        case .locked:  return 1.0
        case .hold:    return 1.0
        }
    }

    var locked: Bool {
        switch self {
        case .rest, .filling: return false
        case .locked, .hold:  return true
        }
    }
}

// MARK: - SlideToConfirmView_Metrics

private struct SlideToConfirmView_Metrics {
    let trackWidth: CGFloat
    let trackHeight: CGFloat
    let handleDiameter: CGFloat
    let inset: CGFloat

    init(size: CGSize) {
        let pad: CGFloat = max(8, size.width * 0.06)
        let w = max(60, size.width - pad * 2)
        // Cap height so it never becomes a giant bar in a large detail area.
        let h = min(max(size.height * 0.34, 44), min(64, w * 0.32))
        self.trackWidth = w
        self.trackHeight = h
        self.inset = max(3, h * 0.09)
        self.handleDiameter = h - inset * 2
    }

    // Center-x travel range of the handle.
    var handleMinX: CGFloat { inset + handleDiameter / 2 }
    var handleMaxX: CGFloat { trackWidth - inset - handleDiameter / 2 }
    var travel: CGFloat { max(1, handleMaxX - handleMinX) }

    func handleCenterX(progress: Double) -> CGFloat {
        handleMinX + travel * CGFloat(progress)
    }
}

// MARK: - Interactive

private struct SlideToConfirmView_InteractiveTrack: View {
    let metrics: SlideToConfirmView_Metrics

    @State private var progress: Double = 0
    @State private var locked: Bool = false
    @State private var dragging: Bool = false
    // Increments on each successful lock so .success haptic re-fires.
    @State private var successTick: Int = 0

    var body: some View {
        SlideToConfirmView_TrackBody(metrics: metrics, progress: progress, locked: locked)
            .contentShape(Rectangle())
            .gesture(drag)
            .sensoryFeedback(.success, trigger: successTick)
            .sensoryFeedback(.impact(weight: .light), trigger: crossingStep)
    }

    // Fires a light tick as the handle crosses quarter steps while dragging.
    private var crossingStep: Int {
        guard dragging else { return -1 }
        return Int(progress * 4)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !locked else { return }
                dragging = true
                let x = value.location.x
                let clamped = min(max(x, metrics.handleMinX), metrics.handleMaxX)
                progress = Double((clamped - metrics.handleMinX) / metrics.travel)
            }
            .onEnded { _ in
                dragging = false
                if progress > 0.9 {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                        progress = 1.0
                        locked = true
                    }
                    successTick += 1
                    // Auto-reset so the control can be tried again.
                    scheduleReset()
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        progress = 0.0
                    }
                }
            }
    }

    private func scheduleReset() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                progress = 0.0
                locked = false
            }
        }
    }
}

// MARK: - Track body (shared renderer)

private struct SlideToConfirmView_TrackBody: View {
    let metrics: SlideToConfirmView_Metrics
    let progress: Double
    let locked: Bool

    private var palette: SlideToConfirmView_Palette { SlideToConfirmView_Palette() }

    var body: some View {
        ZStack(alignment: .leading) {
            trackBase
            fill
            label
            handle
        }
        .frame(width: metrics.trackWidth, height: metrics.trackHeight)
    }

    // MARK: Base groove

    private var trackBase: some View {
        Capsule()
            .fill(palette.trackBase)
            .overlay(
                Capsule()
                    .stroke(palette.trackStroke, lineWidth: 1)
            )
    }

    // MARK: Liquid fill + sheen

    private var fill: some View {
        // Fill follows the handle's trailing edge (handle center + radius).
        let fillWidth = metrics.handleCenterX(progress: progress)
            + metrics.handleDiameter / 2

        return TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Capsule()
                .fill(palette.fillGradient)
                .overlay(sheen(time: t))
                .frame(width: max(metrics.trackHeight, fillWidth))
                .clipShape(Capsule())
        }
        .frame(width: metrics.trackWidth, alignment: .leading)
        .opacity(0.95)
    }

    private func sheen(time: Double) -> some View {
        // A moving diagonal highlight that travels across the filled area.
        let phase = (time.truncatingRemainder(dividingBy: 2.2)) / 2.2
        let span: CGFloat = metrics.trackWidth
        let x = -span + CGFloat(phase) * (span * 2)

        return LinearGradient(
            colors: [
                Color.white.opacity(0.0),
                Color.white.opacity(0.35),
                Color.white.opacity(0.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: span * 0.55)
        .offset(x: x)
        .blendMode(.screen)
        .allowsHitTesting(false)
    }

    // MARK: Label

    private var label: some View {
        // Fades out as the slide progresses; gone once locked.
        Text(locked ? "Confirmed" : "Slide to confirm")
            .font(.system(size: metrics.trackHeight * 0.3, weight: .semibold, design: .rounded))
            .foregroundStyle(labelColor)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: metrics.trackWidth, alignment: .center)
            .opacity(labelOpacity)
            .animation(.easeOut(duration: 0.25), value: locked)
    }

    private var labelColor: Color {
        locked ? Color.white : palette.labelRest
    }

    private var labelOpacity: Double {
        if locked { return 1.0 }
        // Fade the prompt out as the handle covers it.
        return max(0.0, 1.0 - progress * 1.6)
    }

    // MARK: Handle

    private var handle: some View {
        let d = metrics.handleDiameter
        let centerX = metrics.handleCenterX(progress: progress)

        return ZStack {
            Circle()
                .fill(palette.handleFill)
                .overlay(
                    Circle().stroke(palette.handleStroke, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 3, x: 0, y: 1)
            glyph
        }
        .frame(width: d, height: d)
        .scaleEffect(locked ? 1.06 : 1.0)
        .offset(x: centerX - d / 2)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: locked)
    }

    private var glyph: some View {
        Image(systemName: locked ? "checkmark" : "arrow.right")
            .font(.system(size: metrics.handleDiameter * 0.42, weight: .bold))
            .foregroundStyle(palette.glyph)
            .contentTransition(.symbolEffect(.replace))
    }
}

// MARK: - SlideToConfirmView_Palette (no app dependencies; literal colors)

private struct SlideToConfirmView_Palette {
    let trackBase = Color(red: 0.13, green: 0.11, blue: 0.18)
    let trackStroke = Color(red: 0.32, green: 0.28, blue: 0.42).opacity(0.7)
    let labelRest = Color(red: 0.78, green: 0.76, blue: 0.86).opacity(0.85)
    let handleFill = Color(red: 0.97, green: 0.97, blue: 1.0)
    let handleStroke = Color(red: 0.70, green: 0.66, blue: 0.85).opacity(0.5)
    let glyph = Color(red: 0.36, green: 0.20, blue: 0.78)

    var fillGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.42, green: 0.28, blue: 0.92),
                Color(red: 0.55, green: 0.36, blue: 0.98),
                Color(red: 0.36, green: 0.52, blue: 0.99)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
