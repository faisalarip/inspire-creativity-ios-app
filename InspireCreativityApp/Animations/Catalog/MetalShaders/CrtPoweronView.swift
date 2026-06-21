// catalog-id: mtl-crt-poweron
// catalog-metal: CrtPoweronView.metal
import SwiftUI

/// CRT Power-On — content renders through a vintage CRT with scanlines, a rolling
/// sync bar, phosphor bloom and a barrel vignette. Tapping fires the power-on
/// "thunk": the picture collapses to a bright horizontal line then blooms back out.
/// Idle, the scanlines breathe and the sync bar rolls forever.
///
/// - demo == true  : self-driving loop — time rolls the scanlines while the
///                   power-on collapse→bloom re-fires on a ~3.2s cycle.
/// - demo == false : the same picture, but the collapse→bloom is triggered by a
///                   tap (with a haptic "thunk"); the timeline sweeps the curve.
struct CrtPoweronView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { proxy in
            CrtPoweronView_CrtScreen(demo: demo, size: proxy.size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Screen

private struct CrtPoweronView_CrtScreen: View {
    let demo: Bool
    let size: CGSize

    /// Reference epoch captured once at appearance. The shader's `time` uniform is
    /// passed as a Float, so it MUST stay small: feeding the raw
    /// `timeIntervalSinceReferenceDate` (~8.0e8 in 2026) into a Float32 quantizes
    /// to ~64s steps, freezing the scanline roll and sync bar. We pass the elapsed
    /// time since this epoch instead, keeping the magnitude tiny and smooth.
    @State private var startEpoch: TimeInterval = Date().timeIntervalSinceReferenceDate
    /// Time origin for the power-on phase. In demo mode it is unused (the loop is
    /// derived purely from the timeline clock); interactively it marks the tap.
    @State private var tapEpoch: Date = .distantPast
    /// Drives the interactive haptic "thunk" exactly once per tap.
    @State private var tapCount: Int = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            // Small, monotonically-increasing time for the shader (Float-safe).
            let shaderTime = now - startEpoch
            let power = powerOnValue(now: now)

            screenContent
                .compositingGroup()
                .colorEffect(
                    ShaderLibrary.crtPowerOn(
                        .float2(Float(max(size.width, 1)), Float(max(size.height, 1))),
                        .float(Float(shaderTime)),
                        .float(Float(power))
                    )
                )
                .background(Color(red: 0.02, green: 0.02, blue: 0.03))
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .contentShape(Rectangle())
                .modifier(CrtPoweronView_TapToPowerOn(demo: demo) {
                    tapEpoch = timeline.date
                    tapCount &+= 1
                })
                .sensoryFeedback(.impact(weight: .heavy), trigger: tapCount)
        }
    }

    private var cornerRadius: CGFloat {
        max(8, min(size.width, size.height) * 0.06)
    }

    // MARK: Power-on curve

    /// The current power-on progress for this frame (0 = collapsed line, 1 = full
    /// picture). Both branches funnel through `powerOnCurve(elapsed:)` so the
    /// collapse→bloom motion is identical and always frame-smooth.
    private func powerOnValue(now: TimeInterval) -> Double {
        if demo {
            // Continuous self-firing cycle: hold on, collapse, flash, bloom, repeat.
            let period: Double = 3.2
            let phase = now.truncatingRemainder(dividingBy: period)
            return powerOnCurve(elapsed: phase, period: period)
        } else {
            let elapsed = now - tapEpoch.timeIntervalSinceReferenceDate
            if elapsed < 0 || elapsed > 3.2 {
                return 1 // resting fully-on between taps
            }
            return powerOnCurve(elapsed: elapsed, period: 3.2)
        }
    }

    /// hold(on) → collapse → bright line dwell → bloom(on). Never returns a value
    /// that would render a blank frame: at the minimum the shader keeps a blown-out
    /// line, and the curve only dips for a brief moment of the cycle.
    private func powerOnCurve(elapsed: Double, period: Double) -> Double {
        let collapseStart: Double = 0.0
        let collapseDur: Double = 0.42
        let lineDwell: Double = 0.10
        let bloomDur: Double = 0.55

        let tCollapseEnd = collapseStart + collapseDur
        let tLineEnd = tCollapseEnd + lineDwell
        let tBloomEnd = tLineEnd + bloomDur

        if elapsed < collapseStart {
            return 1
        } else if elapsed < tCollapseEnd {
            let p = (elapsed - collapseStart) / collapseDur
            return easeIn(1 - p) // 1 → 0
        } else if elapsed < tLineEnd {
            return 0 // bright collapsed line
        } else if elapsed < tBloomEnd {
            let p = (elapsed - tLineEnd) / bloomDur
            return easeOutBack(p) // 0 → 1 with a touch of overshoot-ish bloom
        } else {
            return 1
        }
    }

    private func easeIn(_ x: Double) -> Double { x * x }

    private func easeOutBack(_ x: Double) -> Double {
        let c1 = 1.70158
        let c3 = c1 + 1.0
        let xm = x - 1.0
        let v = 1.0 + c3 * xm * xm * xm + c1 * xm * xm
        return min(max(v, 0), 1)
    }

    // MARK: Displayed picture (what the CRT is showing)

    private var screenContent: some View {
        ZStack {
            CrtPoweronView_SmpteBars()
            CrtPoweronView_TestCardOverlay()
        }
        .drawingGroup() // flatten to a single layer for the colorEffect
    }
}

// MARK: - Tap modifier (interactive only)

private struct CrtPoweronView_TapToPowerOn: ViewModifier {
    let demo: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        if demo {
            content
        } else {
            content.onTapGesture { action() }
        }
    }
}

// MARK: - SMPTE-style color bars

private struct CrtPoweronView_SmpteBars: View {
    private let topBars: [Color] = [
        Color(red: 0.75, green: 0.75, blue: 0.75), // gray
        Color(red: 0.78, green: 0.74, blue: 0.10), // yellow
        Color(red: 0.10, green: 0.74, blue: 0.78), // cyan
        Color(red: 0.12, green: 0.70, blue: 0.18), // green
        Color(red: 0.74, green: 0.12, blue: 0.72), // magenta
        Color(red: 0.78, green: 0.16, blue: 0.14), // red
        Color(red: 0.13, green: 0.16, blue: 0.74)  // blue
    ]

    private let castleBars: [Color] = [
        Color(red: 0.13, green: 0.16, blue: 0.74), // blue
        Color(red: 0.04, green: 0.04, blue: 0.05), // black
        Color(red: 0.74, green: 0.12, blue: 0.72), // magenta
        Color(red: 0.04, green: 0.04, blue: 0.05), // black
        Color(red: 0.10, green: 0.74, blue: 0.78), // cyan
        Color(red: 0.04, green: 0.04, blue: 0.05), // black
        Color(red: 0.75, green: 0.75, blue: 0.75)  // gray
    ]

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                bars(topBars).frame(height: geo.size.height * 0.66)
                bars(castleBars).frame(height: geo.size.height * 0.14)
                pluge(width: geo.size.width).frame(height: geo.size.height * 0.20)
            }
        }
    }

    private func bars(_ colors: [Color]) -> some View {
        HStack(spacing: 0) {
            ForEach(colors.indices, id: \.self) { i in
                colors[i].frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func pluge(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color(red: 0.02, green: 0.10, blue: 0.20).frame(maxWidth: .infinity)
            Color(red: 0.96, green: 0.96, blue: 0.96).frame(maxWidth: .infinity)
            Color(red: 0.05, green: 0.02, blue: 0.18).frame(maxWidth: .infinity)
            Color(red: 0.04, green: 0.04, blue: 0.05).frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Retro test-card overlay

private struct CrtPoweronView_TestCardOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let dim = min(geo.size.width, geo.size.height)
            ZStack {
                Circle()
                    .stroke(Color(red: 0.95, green: 0.95, blue: 0.95).opacity(0.8),
                            lineWidth: max(1.5, dim * 0.012))
                    .frame(width: dim * 0.62, height: dim * 0.62)

                Circle()
                    .fill(Color(red: 0.04, green: 0.05, blue: 0.06).opacity(0.85))
                    .frame(width: dim * 0.40, height: dim * 0.40)

                VStack(spacing: dim * 0.02) {
                    Text("CH 03")
                        .font(.system(size: dim * 0.085, weight: .heavy, design: .monospaced))
                        .foregroundColor(Color(red: 0.55, green: 0.95, blue: 0.65))
                    Text("PAL")
                        .font(.system(size: dim * 0.05, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.95, green: 0.92, blue: 0.55))
                }

                crossHair(dim: dim)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func crossHair(dim: CGFloat) -> some View {
        let w = max(1.0, dim * 0.008)
        let len = dim * 0.30
        return ZStack {
            Rectangle()
                .fill(Color(red: 0.95, green: 0.95, blue: 0.95).opacity(0.7))
                .frame(width: len, height: w)
            Rectangle()
                .fill(Color(red: 0.95, green: 0.95, blue: 0.95).opacity(0.7))
                .frame(width: w, height: len)
        }
    }
}
