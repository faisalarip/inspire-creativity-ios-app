// catalog-id: mi-pressure-pop
import SwiftUI

// MARK: - Pressure Pop
// A long-press fills a radial pressure ring that, on completion, releases with a
// sudden scale-pop and an outward shockwave puff.
//
//  - demo == true  : a self-driving ~3s loop (TimelineView) auto-charges the ring,
//                    plays the pop + shockwave, then resets. Pure function of phase.
//  - demo == false : the real interactive component. A long press (0.6s) charges the
//                    ring; on genuine completion a KeyframeAnimator fires the pop and
//                    shockwave, with sensory feedback. Early release drains the ring.

struct PressurePopView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                if demo {
                    PressurePopView_DemoLoop(side: side)
                } else {
                    PressurePopView_Interactive(side: side)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - PressurePopView_Palette

private enum PressurePopView_Palette {
    static let backdrop = Color(red: 0.078, green: 0.063, blue: 0.098)
    static let track = Color(red: 1.0, green: 1.0, blue: 1.0).opacity(0.12)
    static let ringHot = Color(red: 1.0, green: 0.42, blue: 0.45)
    static let ringWarm = Color(red: 1.0, green: 0.66, blue: 0.36)
    static let core = Color(red: 1.0, green: 0.52, blue: 0.42)
    static let coreHi = Color(red: 1.0, green: 0.86, blue: 0.74)
    static let shock = Color(red: 1.0, green: 0.58, blue: 0.50)
}

// MARK: - Demo (self-driving, pure function of one phase t)

private struct PressurePopView_DemoLoop: View {
    let side: CGFloat
    private let period: Double = 3.0

    var body: some View {
        TimelineView(.animation) { context in
            let t = phase(context.date)
            let f = frame(for: t)
            PressurePopView_PopBody(
                side: side,
                ringProgress: f.ring,
                corePop: f.pop,
                shockScale: f.shockScale,
                shockOpacity: f.shockOpacity,
                glow: f.glow
            )
        }
    }

    private func phase(_ date: Date) -> Double {
        let secs = date.timeIntervalSinceReferenceDate
        return (secs.truncatingRemainder(dividingBy: period)) / period
    }

    // One normalized cycle phase 0->1 drives every quantity, so the loop is stateless.
    private func frame(for t: Double) -> PressurePopView_PopFrame {
        // Charge phase: 0.0 ..< 0.55  ring fills 0 -> 1
        // Pop phase:    0.55 ..< 0.78 core punches out, shockwave expands & fades
        // Rest phase:   0.78 ..< 1.0  everything calm, ring empty, core idle-breathes
        if t < 0.55 {
            let p = t / 0.55
            let eased = easeInOut(p)
            // subtle anticipatory squeeze as it nears full charge
            let tension = pow(eased, 3.0) * 0.06
            return PressurePopView_PopFrame(
                ring: eased,
                pop: 1.0 - tension,
                shockScale: 0.2,
                shockOpacity: 0.0,
                glow: eased * 0.6
            )
        } else if t < 0.78 {
            let p = (t - 0.55) / 0.23
            // pop: quick overshoot then settle (1 -> 1.32 -> 1.0)
            let pop = 1.0 + popCurve(p) * 0.32
            let shock = 0.25 + easeOut(p) * 1.15
            let shockOpacity = (1.0 - p) * 0.7
            return PressurePopView_PopFrame(
                ring: 1.0 - easeOut(p),          // ring discharges as it pops
                pop: pop,
                shockScale: shock,
                shockOpacity: shockOpacity,
                glow: 0.6 * (1.0 - p) + 0.4
            )
        } else {
            let p = (t - 0.78) / 0.22
            // gentle idle breathe so the core is never static/blank during rest
            let breathe = sin(p * .pi * 2.0) * 0.018
            return PressurePopView_PopFrame(
                ring: 0.0,
                pop: 1.0 + breathe,
                shockScale: 0.2,
                shockOpacity: 0.0,
                glow: 0.18 + breathe * 2.0
            )
        }
    }

    private func easeInOut(_ x: Double) -> Double {
        x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2
    }
    private func easeOut(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
    // 0 -> 1 -> 0 with a snappy front for the pop overshoot
    private func popCurve(_ x: Double) -> Double {
        let s = sin(x * .pi)
        return s * (1.0 - x * 0.35)
    }
}

private struct PressurePopView_PopFrame {
    let ring: Double
    let pop: Double
    let shockScale: Double
    let shockOpacity: Double
    let glow: Double
}

// MARK: - PressurePopView_Interactive (long-press charges; completion fires the pop)

private struct PressurePopView_Interactive: View {
    let side: CGFloat

    @State private var charging: Bool = false
    @State private var ringProgress: CGFloat = 0
    @State private var popCount: Int = 0

    var body: some View {
        // KeyframeAnimator(trigger:) plays the pop + shockwave once per genuine
        // completion only — never on early release.
        KeyframeAnimator(
            initialValue: PressurePopView_PopAnim(),
            trigger: popCount
        ) { anim in
            PressurePopView_PopBody(
                side: side,
                ringProgress: Double(ringProgress),
                corePop: anim.pop,
                shockScale: anim.shockScale,
                shockOpacity: anim.shockOpacity,
                glow: glowValue(anim)
            )
            .contentShape(Circle())
            .onLongPressGesture(
                minimumDuration: 0.6,
                maximumDistance: 60
            ) {
                // perform: fires only on a real long-press completion
                popCount += 1
            } onPressingChanged: { pressing in
                charging = pressing
                withAnimation(.linear(duration: pressing ? 0.6 : 0.16)) {
                    ringProgress = pressing ? 1 : 0
                }
            }
        } keyframes: { _ in
            // core scale-pop
            KeyframeTrack(\.pop) {
                SpringKeyframe(1.34, duration: 0.18, spring: .snappy)
                SpringKeyframe(1.0, duration: 0.42, spring: .bouncy)
            }
            // shockwave expansion
            KeyframeTrack(\.shockScale) {
                CubicKeyframe(0.3, duration: 0.0)
                CubicKeyframe(1.45, duration: 0.55)
            }
            // shockwave fade
            KeyframeTrack(\.shockOpacity) {
                CubicKeyframe(0.75, duration: 0.0)
                CubicKeyframe(0.0, duration: 0.55)
            }
        }
        // Haptics live only in the interactive path so a grid of demo tiles is silent.
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.9), trigger: popCount)
    }

    private func glowValue(_ anim: PressurePopView_PopAnim) -> Double {
        // a touch of glow while charging, and a flash during the pop
        let chargeGlow = Double(ringProgress) * 0.6
        let popGlow = max(0.0, anim.shockOpacity * 0.6)
        return min(1.0, chargeGlow + popGlow + 0.16)
    }
}

private struct PressurePopView_PopAnim {
    var pop: Double = 1.0
    var shockScale: Double = 0.3
    var shockOpacity: Double = 0.0
}

// MARK: - Shared visual body

private struct PressurePopView_PopBody: View {
    let side: CGFloat
    let ringProgress: Double
    let corePop: Double
    let shockScale: Double
    let shockOpacity: Double
    let glow: Double

    private var ringDiameter: CGFloat { side * 0.62 }
    private var coreDiameter: CGFloat { side * 0.34 }
    private var lineWidth: CGFloat { max(3, side * 0.052) }

    var body: some View {
        ZStack {
            PressurePopView_Palette.backdrop

            shockwave
            trackRing
            progressRing
            core
        }
    }

    // expanding outward puff — fully faded between pops, so it is never the only visible thing
    private var shockwave: some View {
        Circle()
            .stroke(
                PressurePopView_Palette.shock.opacity(shockOpacity),
                lineWidth: lineWidth * 0.7
            )
            .frame(width: ringDiameter, height: ringDiameter)
            .scaleEffect(CGFloat(shockScale))
            .blur(radius: 0.5)
    }

    // always-visible faint track
    private var trackRing: some View {
        Circle()
            .stroke(PressurePopView_Palette.track, lineWidth: lineWidth)
            .frame(width: ringDiameter, height: ringDiameter)
    }

    // the charging fill
    private var progressRing: some View {
        Circle()
            .trim(from: 0, to: CGFloat(min(max(ringProgress, 0), 1)))
            .stroke(
                AngularGradient(
                    colors: [PressurePopView_Palette.ringWarm, PressurePopView_Palette.ringHot, PressurePopView_Palette.ringWarm],
                    center: .center
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .frame(width: ringDiameter, height: ringDiameter)
            .rotationEffect(.degrees(-90))
            .shadow(color: PressurePopView_Palette.ringHot.opacity(glow * 0.8),
                    radius: lineWidth * glow)
    }

    // the central core that pops — always present (idle breathe in demo rest)
    private var core: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [PressurePopView_Palette.coreHi, PressurePopView_Palette.core],
                    center: .init(x: 0.4, y: 0.36),
                    startRadius: 0,
                    endRadius: coreDiameter * 0.7
                )
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.18 + glow * 0.25), lineWidth: 1)
            )
            .frame(width: coreDiameter, height: coreDiameter)
            .scaleEffect(CGFloat(corePop))
            .shadow(color: PressurePopView_Palette.core.opacity(0.35 + glow * 0.4),
                    radius: coreDiameter * 0.25 * CGFloat(glow + 0.4))
    }
}
