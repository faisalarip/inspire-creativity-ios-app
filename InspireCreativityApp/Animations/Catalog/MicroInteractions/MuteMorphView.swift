// catalog-id: mi-mute-morph
import SwiftUI

// MARK: - Mute Wave Morph
// Tapping the speaker collapses three animated sound waves inward and draws a
// slash across it; unmuting springs the waves back out. A single fluid morph
// driven by one `muteProgress` value (0 = audible, 1 = muted).

struct MuteMorphView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            Group {
                if demo {
                    MuteMorphView_DemoDriver(side: side)
                } else {
                    MuteMorphView_InteractiveDriver(side: side)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Drivers

/// Self-driving loop for tile previews. Never blank: the speaker body is always
/// drawn; only the waves retract and the slash strokes on across the ~3.2s loop.
private struct MuteMorphView_DemoDriver: View {
    let side: CGFloat
    private let period: Double = 3.2

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let progress = Self.loopProgress(time: t, period: period)
            MuteMorphView_MuteGlyph(progress: progress, side: side)
        }
    }

    /// Ping-pong 0->1->0 with a smoothstep ease and a short hold at each end so
    /// both the audible and muted states are legible for a beat.
    static func loopProgress(time: Double, period: Double) -> CGFloat {
        let phase = (time.truncatingRemainder(dividingBy: period)) / period
        // First half ramps to muted, second half ramps back.
        let triangle: Double = phase < 0.5 ? phase * 2.0 : (1.0 - phase) * 2.0
        // Hold at the extremes by stretching the middle of the ramp.
        let held = smoothHold(triangle)
        return CGFloat(smoothstep(held))
    }

    static func smoothHold(_ x: Double) -> Double {
        // Push values toward 0 and 1 to create a dwell at each end.
        let c = min(max(x, 0.0), 1.0)
        return c * c * (3.0 - 2.0 * c)
    }

    static func smoothstep(_ x: Double) -> Double {
        let c = min(max(x, 0.0), 1.0)
        return c * c * (3.0 - 2.0 * c)
    }
}

/// Real interactive component: a tap toggles `isMuted` with a spring.
private struct MuteMorphView_InteractiveDriver: View {
    let side: CGFloat
    @State private var muteProgress: CGFloat = 0

    var body: some View {
        MuteMorphView_MuteGlyph(progress: muteProgress, side: side)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) {
                    muteProgress = muteProgress < 0.5 ? 1 : 0
                }
            }
            .sensoryFeedback(.selection, trigger: muteProgress >= 0.5)
    }
}

// MARK: - Glyph composition

/// The full speaker glyph. `progress` 0 = waves out / no slash,
/// 1 = waves retracted / slash fully drawn.
private struct MuteMorphView_MuteGlyph: View {
    let progress: CGFloat
    let side: CGFloat

    private var unit: CGFloat { side }

    private var mutedTint: Color {
        Color(red: 1.0, green: 0.40, blue: 0.42)
    }
    private var bodyTint: Color {
        // Interpolate audible (cyan-blue) -> muted (red) directly from the
        // known component endpoints. Self-contained, no UIKit color bridging.
        Color(
            red: lerpD(0.45, 1.0, progress),
            green: lerpD(0.78, 0.40, progress),
            blue: lerpD(1.0, 0.42, progress)
        )
    }

    var body: some View {
        ZStack {
            background
            content
        }
        .frame(width: unit, height: unit)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: unit * 0.22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.09, blue: 0.13),
                        Color(red: 0.05, green: 0.05, blue: 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: unit * 0.22, style: .continuous)
                    .strokeBorder(bodyTint.opacity(0.18), lineWidth: max(0.6, unit * 0.006))
            )
    }

    private var content: some View {
        ZStack {
            glow
            waves
            speaker
            slash
        }
        .frame(width: unit * 0.62, height: unit * 0.62)
    }

    // Soft halo behind the glyph; never fully off so the tile stays alive.
    private var glow: some View {
        Circle()
            .fill(bodyTint.opacity(0.16 + 0.10 * (1 - progress)))
            .blur(radius: unit * 0.06)
            .scaleEffect(0.9 + 0.10 * (1 - progress))
    }

    private var speaker: some View {
        MuteMorphView_SpeakerBody()
            .fill(bodyTint)
            .overlay(
                MuteMorphView_SpeakerBody()
                    .stroke(Color.white.opacity(0.10), lineWidth: max(0.5, unit * 0.004))
            )
            .shadow(color: bodyTint.opacity(0.5 * progress), radius: unit * 0.03)
    }

    // Three concentric arcs that retract outer-first as progress rises.
    private var waves: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                waveArc(index: index)
            }
        }
    }

    private func waveArc(index: Int) -> some View {
        // Outer arcs retract first: give later indices an earlier collapse.
        let stagger = CGFloat(index) * 0.22
        let local = clamp01((progress - stagger) / (1.0 - stagger))
        let extend = 1.0 - local                 // 1 = fully out, 0 = retracted
        let lineWidth = max(1.0, unit * 0.034)
        return MuteMorphView_WaveArc(index: index, extend: extend)
            .trim(from: 0, to: extend)
            .stroke(
                bodyTint.opacity(0.35 + 0.55 * extend),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .scaleEffect(0.82 + 0.18 * extend)   // pull inward toward the cone
    }

    private var slash: some View {
        MuteMorphView_SlashLine()
            .trim(from: 0, to: progress)
            .stroke(
                mutedTint,
                style: StrokeStyle(lineWidth: max(1.2, unit * 0.040), lineCap: .round)
            )
            .shadow(color: mutedTint.opacity(0.6 * progress), radius: unit * 0.02)
    }
}

// MARK: - Shapes

/// A flat speaker icon: a rectangular driver plus a triangular cone, sitting in
/// the left third of the rect so the waves have room on the right.
private struct MuteMorphView_SpeakerBody: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let midY = rect.midY

        // Square driver box.
        let boxLeft = rect.minX + w * 0.06
        let boxRight = rect.minX + w * 0.30
        let boxTop = midY - h * 0.14
        let boxBottom = midY + h * 0.14
        path.addRoundedRect(
            in: CGRect(x: boxLeft, y: boxTop, width: boxRight - boxLeft, height: boxBottom - boxTop),
            cornerSize: CGSize(width: w * 0.02, height: w * 0.02)
        )

        // Triangular cone flaring out to the right.
        let coneTop = midY - h * 0.30
        let coneBottom = midY + h * 0.30
        let coneRight = rect.minX + w * 0.50
        path.move(to: CGPoint(x: boxRight - w * 0.01, y: boxTop))
        path.addLine(to: CGPoint(x: coneRight, y: coneTop))
        path.addLine(to: CGPoint(x: coneRight, y: coneBottom))
        path.addLine(to: CGPoint(x: boxRight - w * 0.01, y: boxBottom))
        path.closeSubpath()

        return path
    }
}

/// Concentric right-opening arcs centered on the speaker cone mouth.
private struct MuteMorphView_WaveArc: Shape {
    let index: Int
    var extend: CGFloat  // animatable retract amount, 1 = out, 0 = in

    var animatableData: CGFloat {
        get { extend }
        set { extend = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        // Arc center sits at the cone mouth on the right of the speaker.
        let center = CGPoint(x: rect.minX + w * 0.50, y: rect.midY)
        let baseRadius = w * 0.16
        let step = w * 0.13
        let radius = baseRadius + CGFloat(index) * step
        // Spread of each arc narrows slightly as it retracts.
        let spread: CGFloat = 38 + 6 * extend
        path.addArc(
            center: center,
            radius: max(radius, 0.5),
            startAngle: .degrees(Double(-spread)),
            endAngle: .degrees(Double(spread)),
            clockwise: false
        )
        _ = h
        return path
    }
}

/// Diagonal mute slash from upper-left to lower-right across the glyph.
private struct MuteMorphView_SlashLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset: CGFloat = rect.width * 0.06
        path.move(to: CGPoint(x: rect.minX + inset, y: rect.minY + inset))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - inset))
        return path
    }
}

// MARK: - Math helpers

private func clamp01(_ x: CGFloat) -> CGFloat {
    min(max(x, 0), 1)
}

/// Linear interpolation between two Double endpoints by a clamped CGFloat t.
private func lerpD(_ a: Double, _ b: Double, _ t: CGFloat) -> Double {
    a + (b - a) * Double(clamp01(t))
}
