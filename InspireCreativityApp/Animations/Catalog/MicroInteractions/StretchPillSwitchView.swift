// catalog-id: mi-stretch-pill-switch
import SwiftUI

// MARK: - Stretch Pill Switch
//
// On toggle the knob stretches into an elongated capsule mid-travel then
// squashes back to a circle on arrival; the track inherits the same elastic
// deformation. The stretch is a per-frame function of a single progress scalar
// (stretch = sin(progress * .pi), peaking mid-travel), so it is computed inside
// Animatable conformances rather than interpolated endpoint-to-endpoint.
//
// demo == true  -> TimelineView(.animation) ping-pongs progress on a ~3s loop.
// demo == false -> a tap toggles isOn; withAnimation(.spring(bounce:0.5))
//                  drives `progress`, fed through an Animatable knob Shape +
//                  Animatable track-squash modifier that recompute each frame.

struct StretchPillSwitchView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if demo {
            StretchPillSwitchView_DemoSwitch(size: size)
        } else {
            StretchPillSwitchView_InteractiveSwitch(size: size)
        }
    }
}

// MARK: - Shared geometry / palette

private enum StretchPillSwitchView_PillPalette {
    static let offTrack = Color(red: 0.20, green: 0.20, blue: 0.26)
    static let onTrackTop = Color(red: 0.36, green: 0.78, blue: 0.55)
    static let onTrackBottom = Color(red: 0.20, green: 0.62, blue: 0.42)
    static let knobTop = Color(red: 0.99, green: 0.99, blue: 1.00)
    static let knobBottom = Color(red: 0.86, green: 0.88, blue: 0.93)
    static let glow = Color(red: 0.45, green: 0.95, blue: 0.68)
}

private struct StretchPillSwitchView_PillMetrics {
    let trackWidth: CGFloat
    let trackHeight: CGFloat
    let diameter: CGFloat
    let inset: CGFloat
    let origin: CGPoint   // top-left of the track within the canvas

    init(canvas: CGSize) {
        // Size everything off the smaller dimension so it reads at 120pt and large.
        let minDim = min(canvas.width, canvas.height)
        let h = minDim * 0.42
        let w = h * 1.85
        trackHeight = h
        trackWidth = w
        inset = h * 0.11
        diameter = h - inset * 2
        origin = CGPoint(x: (canvas.width - w) / 2.0,
                         y: (canvas.height - h) / 2.0)
    }

    // Track tint blends from off-grey to green as progress rises.
    func trackColor(progress p: CGFloat) -> Color {
        let t = max(0, min(1, p))
        let off = StretchPillSwitchView_PillPalette.offTrack
        let on = StretchPillSwitchView_PillPalette.onTrackBottom
        func mix(_ a: Double, _ b: Double) -> Double { a + (b - a) * Double(t) }
        let comp = on.componentsApprox
        let offComp = off.componentsApprox
        return Color(red: mix(offComp.r, comp.r),
                     green: mix(offComp.g, comp.g),
                     blue: mix(offComp.b, comp.b))
    }
}

private extension Color {
    // Coarse component readback for the off/on track blend. Hard-coded fall-back
    // values keep this dependency-free and deterministic.
    var componentsApprox: (r: Double, g: Double, b: Double) {
        if self == StretchPillSwitchView_PillPalette.offTrack { return (0.20, 0.20, 0.26) }
        return (0.20, 0.62, 0.42)
    }
}

// stretch peaks at mid-travel, zero (clean circle) at both ends.
private func stretchAmount(progress p: CGFloat) -> CGFloat {
    max(0, sin(p * .pi))
}

// MARK: - Animatable knob shape
//
// progress 0..1 = travel from left rest to right rest. The capsule width grows
// toward the destination edge (taffy "reaches ahead") while the trailing edge
// lags, then both resolve to a circle on arrival. animatableData = progress so
// the interpolated value is re-evaluated every frame.

private struct StretchPillSwitchView_KnobShape: Shape {
    var progress: CGFloat
    var metrics: StretchPillSwitchView_PillMetrics

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let m = metrics
        let d = m.diameter
        let stretch = stretchAmount(progress: progress)

        // Centre travel between the two rest centres.
        let leftCenter = m.inset + d / 2.0
        let rightCenter = m.trackWidth - m.inset - d / 2.0
        let center = leftCenter + (rightCenter - leftCenter) * progress

        // Taffy: extra length splits asymmetrically toward the travel direction.
        let maxStretch = d * 0.85
        let extra = stretch * maxStretch
        // direction: +1 moving right, -1 moving left (based on travel sign)
        let dir: CGFloat = progress >= 0.5 ? 1.0 : -1.0
        let lead = extra * 0.62      // leading edge reaches ahead
        let trail = extra * 0.38     // trailing edge lags

        let halfBase = d / 2.0
        let leadingX = center + dir * (halfBase + lead)
        let trailingX = center - dir * (halfBase + trail)
        let minX = min(leadingX, trailingX)
        let maxX = max(leadingX, trailingX)

        let capsuleRect = CGRect(x: minX,
                                 y: m.trackHeight / 2.0 - d / 2.0,
                                 width: maxX - minX,
                                 height: d)
        return Capsule(style: .circular).path(in: capsuleRect)
    }
}

// MARK: - Animatable track squash
//
// Vertical scale shrinks at mid-travel (inheriting the knob's elastic
// deformation) and returns to full height at the ends. animatableData = progress
// so the scale is recomputed per frame, not tweened endpoint-to-endpoint.

private struct StretchPillSwitchView_TrackSquash: ViewModifier, Animatable {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let stretch = stretchAmount(progress: progress)
        let yScale = 1.0 - stretch * 0.15   // floor ~0.85, tasteful
        // Knob bulging widens the track a hair horizontally for cohesion.
        let xScale = 1.0 + stretch * 0.025
        return content.scaleEffect(x: xScale, y: yScale, anchor: .center)
    }
}

// MARK: - Reusable visual stack

private struct StretchPillSwitchView_PillBody: View {
    var progress: CGFloat
    var metrics: StretchPillSwitchView_PillMetrics

    var body: some View {
        let m = metrics
        ZStack(alignment: .topLeading) {
            track
            knob
        }
        .frame(width: m.trackWidth, height: m.trackHeight, alignment: .topLeading)
    }

    private var track: some View {
        let m = metrics
        let p = max(0, min(1, progress))
        return ZStack {
            Capsule(style: .circular)
                .fill(m.trackColor(progress: p))
            // Green sheen fades in with progress.
            Capsule(style: .circular)
                .fill(
                    LinearGradient(
                        colors: [StretchPillSwitchView_PillPalette.onTrackTop, StretchPillSwitchView_PillPalette.onTrackBottom],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .opacity(Double(p))
            Capsule(style: .circular)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
        .frame(width: m.trackWidth, height: m.trackHeight)
        .modifier(StretchPillSwitchView_TrackSquash(progress: progress))
        .shadow(color: StretchPillSwitchView_PillPalette.glow.opacity(Double(stretchAmount(progress: progress)) * 0.35),
                radius: 8)
    }

    private var knob: some View {
        let m = metrics
        return StretchPillSwitchView_KnobShape(progress: progress, metrics: m)
            .fill(
                LinearGradient(
                    colors: [StretchPillSwitchView_PillPalette.knobTop, StretchPillSwitchView_PillPalette.knobBottom],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay {
                StretchPillSwitchView_KnobShape(progress: progress, metrics: m)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            }
            .frame(width: m.trackWidth, height: m.trackHeight, alignment: .topLeading)
            .shadow(color: Color.black.opacity(0.28),
                    radius: 3, x: 0, y: 2)
    }
}

// MARK: - Demo (self-driving)

private struct StretchPillSwitchView_DemoSwitch: View {
    var size: CGSize
    private let period: Double = 3.0

    var body: some View {
        let m = StretchPillSwitchView_PillMetrics(canvas: size)
        TimelineView(.animation) { timeline in
            let p = pingPongProgress(at: timeline.date)
            StretchPillSwitchView_PillBody(progress: p, metrics: m)
        }
    }

    private func pingPongProgress(at date: Date) -> CGFloat {
        let t = date.timeIntervalSinceReferenceDate
        // 0->1->0 over `period` seconds, eased so the dwell at the ends reads.
        let phase = (t.truncatingRemainder(dividingBy: period)) / period // 0..1
        let tri = phase < 0.5 ? phase * 2.0 : (1.0 - phase) * 2.0          // 0..1..0
        // ease for a spring-like settle feel
        let eased = easeInOut(tri)
        return CGFloat(eased)
    }

    private func easeInOut(_ x: Double) -> Double {
        let c = max(0, min(1, x))
        return c < 0.5 ? 2 * c * c : 1 - pow(-2 * c + 2, 2) / 2
    }
}

// MARK: - Interactive (tap to toggle)

private struct StretchPillSwitchView_InteractiveSwitch: View {
    var size: CGSize
    @State private var isOn: Bool = false
    @State private var progress: CGFloat = 0

    var body: some View {
        let m = StretchPillSwitchView_PillMetrics(canvas: size)
        StretchPillSwitchView_PillBody(progress: progress, metrics: m)
            .contentShape(Capsule())
            .onTapGesture { toggle() }
            .sensoryFeedback(.impact(flexibility: .soft), trigger: isOn)
    }

    private func toggle() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
            isOn.toggle()
            progress = isOn ? 1 : 0
        }
    }
}
