// catalog-id: mtl-wax-melt
// catalog-metal: WaxMeltView.metal
import SwiftUI

/// Wax Melt — a long-press heats the panel so its pixels sag and drip downward
/// into molten wax strands that pool at the bottom, then re-solidify upward on
/// release. `demo == true` self-melts and reforms on a slow eased sine loop.
///
/// The melt is a single `[[ stitchable ]]` distortionEffect whose `melt` uniform
/// (0…1) scales a per-column noise-weighted downward pull. Both demo and
/// interactive modes derive `melt` *analytically* each frame from one
/// `TimelineView(.animation)` — a shader argument is opaque to SwiftUI and will
/// not interpolate via `withAnimation`, so we never animate the uniform directly.
struct WaxMeltView: View {
    var demo: Bool = false

    // Interactive press state. We store the transition's start time and the
    // melt value it started from, then ramp analytically off the timeline clock.
    @State private var pressed: Bool = false
    @State private var transitionStart: Date = .distantPast
    @State private var fromMelt: Double = 0

    // Tunables.
    private let demoPeriod: Double = 3.2     // seconds for a full solid→molten→solid cycle
    private let rampDuration: Double = 0.9   // seconds to fully melt / reform on press

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                let melt = currentMelt(now: tl.date, clock: t)
                meltedContent(size: size, time: t, melt: melt)
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .gesture(pressGesture)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Melt driver (analytic, never animated as a uniform)

    private func currentMelt(now: Date, clock t: Double) -> Double {
        if demo {
            // Eased sine 0→1→0 over demoPeriod. Never reaches a blank state.
            let phase = (t.truncatingRemainder(dividingBy: demoPeriod)) / demoPeriod
            let raw = (1 - cos(phase * 2 * .pi)) / 2     // 0→1→0
            return easeInOut(raw)
        } else {
            let target: Double = pressed ? 1 : 0
            let elapsed = now.timeIntervalSince(transitionStart)
            guard elapsed >= 0 else { return fromMelt }
            let p = min(max(elapsed / rampDuration, 0), 1)
            return lerp(fromMelt, target, easeInOut(p))
        }
    }

    private var pressGesture: some Gesture {
        // minimumDistance: 0 so the panel wins inside a ScrollView and the press
        // registers immediately; it doubles as a press-and-hold driver.
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                if !pressed {
                    fromMelt = meltAtTransitionEdge(target: 1)
                    transitionStart = Date()
                    pressed = true
                }
            }
            .onEnded { _ in
                fromMelt = meltAtTransitionEdge(target: 0)
                transitionStart = Date()
                pressed = false
            }
    }

    /// Estimates the current melt value at the instant a new transition begins so
    /// the ramp picks up smoothly from wherever the previous ramp had reached.
    private func meltAtTransitionEdge(target: Double) -> Double {
        let prevTarget: Double = pressed ? 1 : 0
        let elapsed = Date().timeIntervalSince(transitionStart)
        guard elapsed >= 0 else { return fromMelt }
        let p = min(max(elapsed / rampDuration, 0), 1)
        return lerp(fromMelt, prevTarget, easeInOut(p))
    }

    // MARK: - Content

    @ViewBuilder
    private func meltedContent(size: CGSize, time: Double, melt: Double) -> some View {
        // maxSampleOffset height ≥ the furthest upward sample distance (≈ full
        // view height) so long drip strands never clip; a little horizontal
        // wobble room too.
        let maxOffset = CGSize(width: 14, height: max(size.height, 1))
        WaxMeltView_WaxPanel(melt: melt)
            .distortionEffect(
                ShaderLibrary.waxMelt(
                    .float(Float(time)),
                    .float(Float(melt)),
                    .float2(Float(size.width), Float(size.height))
                ),
                maxSampleOffset: maxOffset
            )
            // A warm bloom that intensifies as the wax heats up.
            .overlay(heatGlow(melt: melt))
    }

    private func heatGlow(melt: Double) -> some View {
        RadialGradient(
            colors: [
                Color(red: 1.0, green: 0.62, blue: 0.30).opacity(0.42 * melt),
                Color(red: 1.0, green: 0.40, blue: 0.18).opacity(0.0)
            ],
            center: .center,
            startRadius: 2,
            endRadius: 140
        )
        .blendMode(.screen)
        .allowsHitTesting(false)
    }

    // MARK: - Math helpers

    private func easeInOut(_ x: Double) -> Double {
        // Smoothstep-style ease.
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }
}

// MARK: - The thing that melts (textured so the drip is legible)

private struct WaxMeltView_WaxPanel: View {
    var melt: Double

    var body: some View {
        ZStack {
            base
            stripes
            badge
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var base: some View {
        // A waxy candle-slab gradient; warms toward orange as it melts.
        LinearGradient(
            colors: [
                Color(red: 0.96, green: 0.90, blue: 0.78),
                Color(red: 0.93, green: 0.74, blue: 0.52),
                Color(red: 0.86, green: 0.52, blue: 0.34),
                Color(red: 0.62, green: 0.30, blue: 0.22)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.50, blue: 0.20).opacity(0.55 * melt),
                    Color(red: 1.0, green: 0.30, blue: 0.12).opacity(0.0)
                ],
                startPoint: .bottom,
                endPoint: .center
            )
        )
    }

    private var stripes: some View {
        // Horizontal banding gives the distortion something to streak.
        GeometryReader { g in
            let h = g.size.height
            let bands = 9
            let bandH = h / CGFloat(bands)
            ZStack {
                ForEach(0..<bands, id: \.self) { i in
                    Rectangle()
                        .fill(Color.white.opacity(i % 2 == 0 ? 0.10 : 0.0))
                        .frame(height: bandH)
                        .offset(y: CGFloat(i) * bandH - h / 2 + bandH / 2)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var badge: some View {
        VStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.86, blue: 0.55),
                            Color(red: 1.0, green: 0.55, blue: 0.25)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color(red: 0.4, green: 0.12, blue: 0.05).opacity(0.5),
                        radius: 2, x: 0, y: 1)
            Text("HOLD")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .tracking(3)
                .foregroundStyle(Color(red: 0.30, green: 0.14, blue: 0.08))
            Text("to melt")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.45, green: 0.22, blue: 0.14).opacity(0.9))
        }
        .padding(10)
    }
}
