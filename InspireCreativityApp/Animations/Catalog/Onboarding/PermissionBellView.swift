// catalog-id: ob-permission-bell
import SwiftUI

/// Wake-the-Bell notification permission hero.
///
/// A dim, sleeping notification bell that wakes when you long-press "Allow":
/// it rocks harder and harder as you hold, sound-wave rings pulse outward, a red
/// badge pops in with a spring, and on release past the threshold it settles with
/// a happy nod. `demo == true` self-drives the full wake-and-ring cycle on a loop.
struct PermissionBellView: View {
    var demo: Bool = false

    // Interactive hold state. `progress` itself is always derived analytically
    // inside the TimelineView from these anchors, so there is never a blank frame.
    @State private var isPressing: Bool = false
    @State private var pressStart: Date = .distantPast
    @State private var releaseAt: Date = .distantPast
    @State private var releaseProgress: Double = 0
    @State private var didLock: Bool = false
    @State private var lockTick: Int = 0

    // Tunables (seconds).
    private let windUp: Double = 1.15          // hold time to reach full progress
    private let lockThreshold: Double = 0.72   // progress needed to lock on release
    private let releaseDecay: Double = 0.55    // calm-down duration after a short hold

    var body: some View {
        GeometryReader { geo in
            let side: CGFloat = min(geo.size.width, geo.size.height)
            TimelineView(.animation) { timeline in
                let t: Double = timeline.date.timeIntervalSinceReferenceDate
                let progress: Double = demo ? demoProgress(t) : livePressProgress(now: timeline.date)
                let locked: Bool = demo ? (demoProgress(t) > lockThreshold && demoRinging(t))
                                        : didLock
                stage(side: side, t: t, progress: progress, locked: locked)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(holdGesture, including: demo ? .none : .all)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Haptics only in the live, interactive component — never in a grid of demo tiles.
        .modifier(PermissionBellView_LockHaptic(tick: lockTick, enabled: !demo))
    }

    // MARK: - Composed stage

    @ViewBuilder
    private func stage(side: CGFloat, t: Double, progress: Double, locked: Bool) -> some View {
        let p: Double = clamp01(progress)
        // Bell rocks with an amplitude that ramps with progress. Frequency rises
        // a touch as it winds up so it visibly speeds toward ringing.
        let rockFreq: Double = 7.5 + p * 4.5
        let rockAmp: Double = 27.0 * easeOut(p)
        let rock: Double = sin(t * rockFreq) * rockAmp

        // A gentle "settle nod" near lock: a small extra eased tilt that decays.
        let nod: Double = locked ? sin(t * 9.0) * 3.0 * Double(1.0) : 0

        let bellAngle: Double = rock + nod
        let dim: Double = 0.46 + 0.54 * p        // never fully dark — always legible

        ZStack {
            backdrop(side: side, progress: p)

            PermissionBellView_SoundWaveRings(side: side, t: t, progress: p, active: p > 0.18)

            PermissionBellView_BellGlyph(side: side,
                      angle: bellAngle,
                      dim: dim,
                      glow: p)

            PermissionBellView_NotificationBadge(side: side, shown: locked, t: t)

            promptLabel(side: side, progress: p, locked: locked)
        }
        .frame(width: side, height: side)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // Soft radial glow behind the bell that brightens as it wakes.
    private func backdrop(side: CGFloat, progress: Double) -> some View {
        let warm = Color(red: 1.0, green: 0.82, blue: 0.42)
        return RadialGradient(
            colors: [warm.opacity(0.28 * progress), .clear],
            center: .init(x: 0.5, y: 0.42),
            startRadius: 0,
            endRadius: side * 0.5
        )
        .frame(width: side, height: side)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func promptLabel(side: CGFloat, progress: Double, locked: Bool) -> some View {
        let txt: String = locked ? "Notifications On" : (progress > 0.05 ? "Hold to wake…" : "Hold to Allow")
        let on = Color(red: 0.36, green: 0.85, blue: 0.62)
        let off = Color(red: 0.78, green: 0.80, blue: 0.86)
        Text(txt)
            .font(.system(size: max(9, side * 0.072), weight: .semibold, design: .rounded))
            .foregroundStyle(locked ? on : off)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, side * 0.05)
            .frame(width: side, alignment: .center)
            .offset(y: side * 0.40)
            .allowsHitTesting(false)
    }

    // MARK: - Gesture (interactive only)

    private var holdGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                if !isPressing {
                    isPressing = true
                    pressStart = Date()
                    didLock = false
                }
            }
            .onEnded { _ in
                let held: Double = max(0, Date().timeIntervalSince(pressStart))
                let reached: Double = clamp01(held / windUp)
                isPressing = false
                if reached >= lockThreshold {
                    didLock = true
                    lockTick &+= 1
                } else {
                    didLock = false
                    releaseAt = Date()
                    releaseProgress = reached
                }
            }
    }

    // MARK: - Progress sources

    /// Live progress driven by *time held*, not drag distance.
    private func livePressProgress(now: Date) -> Double {
        if didLock { return 1.0 }
        if isPressing {
            let held: Double = max(0, now.timeIntervalSince(pressStart))
            return clamp01(held / windUp)
        }
        // Calming back down after a short hold.
        let since: Double = now.timeIntervalSince(releaseAt)
        if since < releaseDecay && releaseProgress > 0 {
            let k: Double = clamp01(since / releaseDecay)
            return releaseProgress * (1.0 - easeOut(k))
        }
        return 0
    }

    /// Self-driving envelope: sleep → wind-up rock → ring/lock → settle nod → reset.
    /// Loop length ~3.4s. Floored so the bell is never invisible.
    private func demoProgress(_ t: Double) -> Double {
        let loop: Double = 3.4
        let phase: Double = (t.truncatingRemainder(dividingBy: loop) + loop)
            .truncatingRemainder(dividingBy: loop)
        if phase < 0.45 {                       // resting / waking start
            return 0.05
        } else if phase < 1.7 {                 // winding up
            return easeInOut(clamp01((phase - 0.45) / 1.25))
        } else if phase < 2.65 {                // held at full, ringing
            return 1.0
        } else {                                // settle back to sleep
            return 1.0 - easeInOut(clamp01((phase - 2.65) / 0.75))
        }
    }

    private func demoRinging(_ t: Double) -> Bool {
        let loop: Double = 3.4
        let phase: Double = (t.truncatingRemainder(dividingBy: loop) + loop)
            .truncatingRemainder(dividingBy: loop)
        return phase >= 1.55 && phase < 2.65
    }

    // MARK: - Math helpers

    private func clamp01(_ v: Double) -> Double { min(1, max(0, v)) }
    private func easeOut(_ x: Double) -> Double { 1 - pow(1 - clamp01(x), 3) }
    private func easeInOut(_ x: Double) -> Double {
        let c = clamp01(x)
        return c < 0.5 ? 4 * c * c * c : 1 - pow(-2 * c + 2, 3) / 2
    }
}

// MARK: - Bell glyph

private struct PermissionBellView_BellGlyph: View {
    let side: CGFloat
    let angle: Double
    let dim: Double
    let glow: Double

    var body: some View {
        let bellSize: CGFloat = side * 0.46
        let warm = Color(red: 1.0, green: 0.80, blue: 0.36)
        // Direct RGB lerp from cool (sleeping) to warm (awake) by `glow`.
        // Both endpoints are literal constants, so no UIKit color round-trip is needed.
        let k: Double = min(1, max(0, glow))
        let tint = Color(red: 0.62 + (1.0 - 0.62) * k,
                         green: 0.66 + (0.80 - 0.66) * k,
                         blue: 0.78 + (0.36 - 0.78) * k)

        Image(systemName: "bell.fill")
            .resizable()
            .scaledToFit()
            .frame(width: bellSize, height: bellSize)
            .foregroundStyle(tint)
            .opacity(dim)
            .shadow(color: warm.opacity(0.55 * glow),
                    radius: side * 0.05 * CGFloat(glow))
            // Pivot from the crown so it swings like a hung bell.
            .rotationEffect(.degrees(angle), anchor: .top)
            .offset(y: -side * 0.04)
            .allowsHitTesting(false)
    }
}

// MARK: - Sound-wave rings

private struct PermissionBellView_SoundWaveRings: View {
    let side: CGFloat
    let t: Double
    let progress: Double
    let active: Bool

    var body: some View {
        let warm = Color(red: 1.0, green: 0.78, blue: 0.40)
        let count = 3
        let maxR: CGFloat = side * 0.42
        let speed: Double = 0.7 + progress * 0.8   // rings emit faster as it winds up

        ZStack {
            ForEach(0..<count, id: \.self) { i in
                let local = ringPhase(index: i, count: count, speed: speed)
                let radius: CGFloat = maxR * CGFloat(local) * CGFloat(0.4 + progress * 0.6)
                let opacity: Double = active ? (1.0 - local) * 0.7 * progress : 0
                Circle()
                    .stroke(warm.opacity(opacity),
                            lineWidth: max(1.2, side * 0.02 * CGFloat(1.0 - local)))
                    .frame(width: radius * 2, height: radius * 2)
            }
        }
        .offset(y: -side * 0.04)
        .allowsHitTesting(false)
    }

    private func ringPhase(index: Int, count: Int, speed: Double) -> Double {
        let raw = t * speed + Double(index) / Double(count)
        return raw.truncatingRemainder(dividingBy: 1.0)
    }
}

// MARK: - Notification badge

private struct PermissionBellView_NotificationBadge: View {
    let side: CGFloat
    let shown: Bool
    let t: Double

    var body: some View {
        let badgeSize: CGFloat = side * 0.16
        let red = Color(red: 0.96, green: 0.26, blue: 0.30)
        // Subtle breathing while present, so a locked tile still feels alive.
        let breathe: Double = shown ? 1.0 + sin(t * 4.0) * 0.04 : 0.0

        Circle()
            .fill(red)
            .overlay(
                Circle().stroke(Color.white.opacity(0.85), lineWidth: max(1, side * 0.012))
            )
            .frame(width: badgeSize, height: badgeSize)
            .shadow(color: red.opacity(0.6), radius: side * 0.03)
            .scaleEffect(CGFloat(breathe))
            // Spring pop on appear / collapse on disappear.
            .animation(.spring(response: 0.34, dampingFraction: 0.42), value: shown)
            .offset(x: side * 0.16, y: -side * 0.18)
            .allowsHitTesting(false)
    }
}

// MARK: - Haptic on lock (interactive only)

private struct PermissionBellView_LockHaptic: ViewModifier {
    let tick: Int
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.sensoryFeedback(.success, trigger: tick)
        } else {
            content
        }
    }
}
