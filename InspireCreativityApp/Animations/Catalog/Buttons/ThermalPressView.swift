// catalog-id: btn-thermal-press
import SwiftUI

/// Thermal Press — hold to heat the button through color stages from cool blue
/// to glowing orange with a rising heat-shimmer haze; releasing lets it cool and
/// fade. Pure SwiftUI (no shaders): a single TimelineView(.animation) drives both
/// the auto-demo loop and the interactive press, computing a continuous 0→1 heat
/// value per frame that maps through a manual blue→amber→orange gradient plus a
/// growing glow and an oscillating blurred shimmer overlay.
struct ThermalPressView: View {
    var demo: Bool = false

    // Interactive press state. We drive the actual heat ramp from timestamps so
    // the value is frame-accurate and fully controllable (LongPressGesture only
    // fires once and can't express a continuous "while held" ramp).
    @State private var isPressing: Bool = false
    @State private var pressStart: Date = .distantPast
    @State private var releaseDate: Date = .distantPast
    @State private var heatAtRelease: Double = 0

    // Tuning constants.
    private let rampDuration: Double = 2.0      // seconds to reach redline while held
    private let coolDuration: Double = 1.1      // seconds to cool back to zero
    private let demoPeriod: Double = 3.4        // full heat 0→1→0 demo loop
    private let redline: Double = 0.82          // threshold for the warning haptic

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let now = timeline.date
                let heat = currentHeat(at: now)
                content(heat: heat, size: geo.size, now: now)
                    // Frame-accurate haptic: fires on the render where heat crosses
                    // redline, no @State mutation inside the timeline closure.
                    .sensoryFeedback(.warning, trigger: heat >= redline)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(pressGesture)
    }

    // MARK: - Gesture

    // DragGesture(minimumDistance:0) gives reliable press-down / release callbacks
    // and wins inside a ScrollView, unlike a bare LongPressGesture.
    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !isPressing else { return }
                isPressing = true
                pressStart = Date()
            }
            .onEnded { _ in
                guard isPressing else { return }
                // Capture the heat we actually reached so an early release cools
                // from there instead of snapping to full-hot.
                heatAtRelease = interactiveHeat(at: Date())
                isPressing = false
                releaseDate = Date()
            }
    }

    // MARK: - Heat computation

    private func currentHeat(at date: Date) -> Double {
        if demo {
            return demoHeat(at: date)
        }
        return interactiveHeat(at: date)
    }

    /// Triangle ramp 0→1→0 over `demoPeriod`, smoothed so the auto-demo eases in
    /// and out of the redline rather than turning sharply.
    private func demoHeat(at date: Date) -> Double {
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: demoPeriod)
        let phase = t / demoPeriod                 // 0...1
        let triangle = phase < 0.5 ? phase * 2 : (1 - phase) * 2
        return smooth(triangle)
    }

    /// While pressing: ramp from 0 toward 1 over `rampDuration`, clamped.
    /// After release: ease from `heatAtRelease` back to 0 over `coolDuration`.
    private func interactiveHeat(at date: Date) -> Double {
        if isPressing {
            let elapsed = date.timeIntervalSince(pressStart)
            let raw = max(0, elapsed) / rampDuration
            return min(1, raw)
        }
        let sinceRelease = date.timeIntervalSince(releaseDate)
        if sinceRelease < 0 || sinceRelease >= coolDuration {
            return 0
        }
        let k = 1 - (sinceRelease / coolDuration)   // 1→0
        return heatAtRelease * smooth(k)
    }

    /// Smoothstep easing.
    private func smooth(_ x: Double) -> Double {
        let c = min(1, max(0, x))
        return c * c * (3 - 2 * c)
    }

    // MARK: - Content

    @ViewBuilder
    private func content(heat: Double, size: CGSize, now: Date) -> some View {
        let dim = min(size.width, size.height)
        let cornerR = dim * 0.22
        let glowR = heat * dim * 0.34
        let hot = heatColor(heat)
        let labelText = heat >= redline ? "HOT" : "HOLD"

        ZStack {
            buttonBody(heat: heat, hot: hot, cornerR: cornerR, dim: dim)
                .shadow(color: hot.opacity(0.65 * heat + 0.1), radius: glowR)
                .shadow(color: hot.opacity(0.45 * heat), radius: glowR * 0.45)
                .overlay {
                    shimmer(heat: heat, size: size, cornerR: cornerR, now: now)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerR, style: .continuous)
                        .strokeBorder(rimGradient(heat: heat), lineWidth: max(1, dim * 0.012))
                }

            label(text: labelText, heat: heat, dim: dim)
        }
        .padding(dim * 0.12)
    }

    private func buttonBody(heat: Double, hot: Color, cornerR: CGFloat, dim: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerR, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        hot.opacity(1.0),
                        bodyMidColor(heat: heat),
                        coreColor(heat: heat)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                // Inner core glow that intensifies with heat (a radial hotspot).
                // Radius is relative to the button size so it reads the same in a
                // small grid tile and a large detail view (no hardcoded pixels).
                RoundedRectangle(cornerRadius: cornerR, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                emberColor.opacity(0.85 * heat),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: max(1, dim * 0.5)
                        )
                    )
                    .blendMode(.screen)
            }
    }

    // MARK: - Shimmer overlay

    /// A blurred wavy band that rides up the button. Amplitude and opacity scale
    /// with heat so it is calm-but-present when cool and a rising haze when hot.
    private func shimmer(heat: Double, size: CGSize, cornerR: CGFloat, now: Date) -> some View {
        let t = now.timeIntervalSinceReferenceDate
        let amp = (0.10 + heat * 0.9)
        return ThermalPressView_ShimmerShape(phase: t * 2.4, amplitude: amp)
            .fill(
                LinearGradient(
                    colors: [
                        .white.opacity(0.0),
                        .white.opacity(0.22 + 0.30 * heat),
                        .white.opacity(0.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .blur(radius: max(2, size.width * 0.03))
            .blendMode(.screen)
            .opacity(0.35 + 0.65 * heat)
            .clipShape(RoundedRectangle(cornerRadius: cornerR, style: .continuous))
            .allowsHitTesting(false)
    }

    // MARK: - Label

    private func label(text: String, heat: Double, dim: CGFloat) -> some View {
        Text(text)
            .font(.system(size: max(11, dim * 0.16), weight: .heavy, design: .rounded))
            .tracking(dim * 0.02)
            .foregroundStyle(.white)
            .shadow(color: emberColor.opacity(heat), radius: heat * 6)
            .opacity(0.9)
            .scaleEffect(1 + heat * 0.05)
            .allowsHitTesting(false)
    }

    // MARK: - Color model (manual lerps → Color(red:green:blue:))

    /// Blue → amber → orange, routed through a mid stop so it never goes muddy.
    private func heatColor(_ t: Double) -> Color {
        let cool = (r: 0.16, g: 0.42, b: 0.88)   // cool steel blue
        let mid  = (r: 0.92, g: 0.62, b: 0.20)   // amber
        let hot  = (r: 1.00, g: 0.34, b: 0.10)   // glowing orange
        if t < 0.5 {
            let k = t / 0.5
            return lerp(cool, mid, k)
        }
        let k = (t - 0.5) / 0.5
        return lerp(mid, hot, k)
    }

    private func bodyMidColor(heat: Double) -> Color {
        let cool = (r: 0.10, g: 0.27, b: 0.62)
        let hot  = (r: 0.86, g: 0.22, b: 0.06)
        return lerp(cool, hot, heat)
    }

    private func coreColor(heat: Double) -> Color {
        let cool = (r: 0.05, g: 0.14, b: 0.36)
        let hot  = (r: 0.55, g: 0.10, b: 0.02)
        return lerp(cool, hot, heat)
    }

    private func rimGradient(heat: Double) -> LinearGradient {
        let top = heatColor(min(1, heat + 0.15)).opacity(0.9)
        let bottom = coreColor(heat: heat).opacity(0.7)
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }

    private var emberColor: Color {
        Color(red: 1.0, green: 0.78, blue: 0.30)
    }

    private func lerp(_ a: (r: Double, g: Double, b: Double),
                      _ b: (r: Double, g: Double, b: Double),
                      _ t: Double) -> Color {
        let k = min(1, max(0, t))
        let r = a.r + (b.r - a.r) * k
        let g = a.g + (b.g - a.g) * k
        let bl = a.b + (b.b - a.b) * k
        return Color(red: r, green: g, blue: bl)
    }
}

// MARK: - Shimmer Shape

/// A vertical wavy band whose horizontal edges ripple with `phase`. Used as the
/// heat-shimmer haze; blurred at the call site so the wave reads as a soft glow.
private struct ThermalPressView_ShimmerShape: Shape {
    var phase: Double
    var amplitude: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 18
        let h = rect.height
        let baseWidth = rect.width * 0.5
        let wob = rect.width * 0.18 * amplitude

        // Left edge of the band, rippling top→bottom.
        var left: [CGPoint] = []
        var right: [CGPoint] = []
        for i in 0...steps {
            let f = Double(i) / Double(steps)
            let y = h * f
            let s = sin(f * .pi * 3 + phase)
            let s2 = sin(f * .pi * 5 - phase * 0.7)
            let centerX = rect.midX + wob * (s * 0.6 + s2 * 0.4)
            left.append(CGPoint(x: centerX - baseWidth / 2, y: y))
            right.append(CGPoint(x: centerX + baseWidth / 2, y: y))
        }

        guard let first = left.first else { return path }
        path.move(to: first)
        for p in left.dropFirst() { path.addLine(to: p) }
        for p in right.reversed() { path.addLine(to: p) }
        path.closeSubpath()
        return path
    }
}
