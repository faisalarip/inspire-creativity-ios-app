// catalog-id: mi-orbit-badge
import SwiftUI

// MARK: - OrbitBadgeView
//
// Micro-interaction: when a count crosses a milestone threshold, the badge
// spawns a tiny satellite dot that orbits it once trailing a comet streak,
// then merges back in via scale + opacity.
//
// demo == true  -> self-driving loop: count ticks up on a clock, milestone
//                  crossings fire the orbit automatically (~3.4s cycle).
// demo == false -> auto loop runs out of the box (spec interaction is "auto");
//                  additionally, tapping the badge increments the count and a
//                  milestone crossing fires the orbit, a non-milestone tap gives
//                  a small reactive bump. The badge + number stay legible always.
//
// The comet trail is derived analytically from the current orbit angle inside
// a Canvas (no mutated point buffer), so it streaks correctly per frame and
// never warns about modifying state during view update.

struct OrbitBadgeView: View {
    var demo: Bool = false

    // Interactive state. Only ever written from the tap handler — never from
    // inside the TimelineView closure.
    @State private var count: Int = 11
    @State private var triggerDate: Date? = nil
    @State private var bumpDate: Date? = nil

    // Timing.
    private let cycleDuration: Double = 3.4   // demo loop length
    private let orbitDuration: Double = 1.45  // one full orbit
    private let mergeDuration: Double = 0.42   // satellite merge tail
    private let milestoneStep: Int = 5

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let phase = currentPhase(now: now)
                content(geo: geo, phase: phase, now: now)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { handleTap() }
        .sensoryFeedback(.impact(weight: .medium), trigger: triggerDate)
        .sensoryFeedback(.selection, trigger: bumpDate)
    }

    // MARK: - Composition

    @ViewBuilder
    private func content(geo: GeometryProxy, phase: OrbitBadgeView_OrbitPhase, now: Double) -> some View {
        let side = min(geo.size.width, geo.size.height)
        let badgeRadius = side * 0.20
        let orbitRadius = badgeRadius + side * 0.16
        let displayedCount = currentCount(now: now)

        ZStack {
            backdrop(side: side)

            // Comet trail + satellite live behind/around the badge.
            OrbitBadgeView_CometCanvas(
                phase: phase,
                orbitRadius: orbitRadius,
                dotRadius: side * 0.045
            )
            .frame(width: side, height: side)

            OrbitBadgeView_BadgeGlyph(
                count: displayedCount,
                radius: badgeRadius,
                pulse: phase.badgePulse
            )
        }
        .frame(width: geo.size.width, height: geo.size.height)
    }

    private func backdrop(side: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 0.16, green: 0.13, blue: 0.24),
                        Color(red: 0.078, green: 0.063, blue: 0.098)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: side * 0.62
                )
            )
            .frame(width: side * 1.15, height: side * 1.15)
            .opacity(0.9)
    }

    // MARK: - Phase computation (pure — never writes state)

    private func currentPhase(now: Double) -> OrbitBadgeView_OrbitPhase {
        if demo {
            let t = now.truncatingRemainder(dividingBy: cycleDuration)
            // Orbit fires near the start of each cycle; the rest of the cycle is "rest".
            return phase(forElapsed: t)
        } else {
            guard let start = triggerDate?.timeIntervalSinceReferenceDate else {
                // No milestone tapped yet: keep the tile alive with the auto
                // loop so an "auto" spec is never static between renders.
                let t = now.truncatingRemainder(dividingBy: cycleDuration)
                return phase(forElapsed: t)
            }
            let elapsed = now - start
            if elapsed < 0 || elapsed > orbitDuration + mergeDuration {
                return restPhase(now: now)
            }
            return phase(forElapsed: elapsed)
        }
    }

    /// A satellite phase derived from elapsed seconds since the trigger.
    private func phase(forElapsed elapsed: Double) -> OrbitBadgeView_OrbitPhase {
        if elapsed < 0 || elapsed > orbitDuration + mergeDuration {
            return OrbitBadgeView_OrbitPhase.rest
        }

        if elapsed <= orbitDuration {
            // Orbiting: ease the angle so it accelerates out and decelerates in.
            let raw = elapsed / orbitDuration
            let eased = easeInOut(raw)
            let angle = eased * (.pi * 2.0) - (.pi / 2.0) // start at top
            // Satellite springs in at launch, full size while orbiting.
            let appear = min(1.0, raw / 0.12)
            return OrbitBadgeView_OrbitPhase(
                visible: true,
                angle: angle,
                trailSpan: 1.0,
                scale: 0.55 + 0.45 * appear,
                opacity: appear,
                badgePulse: badgePulse(raw: raw)
            )
        } else {
            // Merge tail: dot pulls into the badge center, scaling + fading.
            let mt = (elapsed - orbitDuration) / mergeDuration
            let mEased = easeOut(min(1.0, mt))
            let angle = -(.pi / 2.0) + (.pi * 2.0) * 0.0 // back at top
            return OrbitBadgeView_OrbitPhase(
                visible: true,
                angle: angle,
                trailSpan: 1.0 - mEased,           // trail shrinks as it merges
                mergeProgress: mEased,
                scale: 1.0 - 0.7 * mEased,
                opacity: 1.0 - mEased,
                badgePulse: 1.0 + 0.18 * (1.0 - mEased)
            )
        }
    }

    private func restPhase(now: Double) -> OrbitBadgeView_OrbitPhase {
        // At rest, optionally apply a small badge bump from a non-milestone tap.
        guard !demo, let b = bumpDate?.timeIntervalSinceReferenceDate else {
            return OrbitBadgeView_OrbitPhase.rest
        }
        let dt = now - b
        let bumpLen = 0.4
        if dt < 0 || dt > bumpLen { return OrbitBadgeView_OrbitPhase.rest }
        let p = dt / bumpLen
        let pulse = 1.0 + 0.14 * sin(p * .pi)
        return OrbitBadgeView_OrbitPhase(visible: false, angle: 0, trailSpan: 0,
                          scale: 0, opacity: 0, badgePulse: pulse)
    }

    private func badgePulse(raw: Double) -> Double {
        // Subtle anticipation as the satellite launches.
        1.0 + 0.10 * exp(-pow((raw - 0.04) * 14.0, 2.0))
    }

    // MARK: - Count (pure — derived, never mutated in closure)

    private func currentCount(now: Double) -> Int {
        if demo {
            // Cycle a small, always-legible count that lands on a milestone each
            // cycle so the viewer actually sees it cross a threshold (the orbit
            // is driven off the time cycle, so this value is cosmetic).
            let cycles = Int(now / cycleDuration)
            return ((cycles % 6) + 1) * milestoneStep // 5,10,...,30 then wraps
        } else {
            return count
        }
    }

    // MARK: - Interaction

    private func handleTap() {
        guard !demo else { return }
        let newCount = count + 1
        count = newCount
        if newCount % milestoneStep == 0 {
            triggerDate = Date()
        } else {
            bumpDate = Date()
        }
    }

    // MARK: - Easing helpers

    private func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 2.0 * t * t : 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0
    }

    private func easeOut(_ t: Double) -> Double {
        1.0 - pow(1.0 - t, 3.0)
    }
}

// MARK: - Phase model

private struct OrbitBadgeView_OrbitPhase {
    var visible: Bool
    var angle: Double          // radians around the badge center
    var trailSpan: Double      // 0...1 length multiplier for the comet streak
    var mergeProgress: Double = 0
    var scale: Double
    var opacity: Double
    var badgePulse: Double

    static let rest = OrbitBadgeView_OrbitPhase(
        visible: false, angle: 0, trailSpan: 0,
        scale: 0, opacity: 0, badgePulse: 1.0
    )
}

// MARK: - Comet Canvas (analytic trail — no mutated buffer)

private struct OrbitBadgeView_CometCanvas: View {
    let phase: OrbitBadgeView_OrbitPhase
    let orbitRadius: CGFloat
    let dotRadius: CGFloat

    private let trailSamples: Int = 14
    private let trailArc: Double = 1.05 // radians of trail behind the dot

    var body: some View {
        Canvas { context, size in
            guard phase.visible, phase.opacity > 0.001 else { return }
            let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
            // Pull radius in as the dot merges toward the badge center.
            let radius = orbitRadius * (1.0 - 0.85 * phase.mergeProgress)

            drawTrail(context: context, center: center, radius: radius)
            drawHead(context: context, center: center, radius: radius)
        }
    }

    private func point(center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        CGPoint(
            x: center.x + radius * CGFloat(cos(angle)),
            y: center.y + radius * CGFloat(sin(angle))
        )
    }

    private func drawTrail(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let span = max(0.0, phase.trailSpan)
        guard span > 0.01 else { return }
        let baseColor = Color(red: 1.0, green: 0.78, blue: 0.35)

        for i in 1...trailSamples {
            let frac = Double(i) / Double(trailSamples) // 0..1 back along trail
            let back = frac * trailArc * span
            let a = phase.angle - back
            let p = point(center: center, radius: radius, angle: a)
            let fade = (1.0 - frac)
            let r = dotRadius * (0.78 * fade + 0.12)
            let alpha = phase.opacity * fade * fade * 0.85
            guard alpha > 0.004 else { continue }

            let rect = CGRect(
                x: p.x - r, y: p.y - r,
                width: r * 2.0, height: r * 2.0
            )
            var ctx = context
            ctx.addFilter(.blur(radius: r * 0.45))
            ctx.fill(Path(ellipseIn: rect), with: .color(baseColor.opacity(alpha)))
        }
    }

    private func drawHead(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let p = point(center: center, radius: radius, angle: phase.angle)
        let r = dotRadius * CGFloat(max(0.05, phase.scale))
        let headRect = CGRect(x: p.x - r, y: p.y - r, width: r * 2.0, height: r * 2.0)

        // Soft glow halo.
        var glow = context
        glow.addFilter(.blur(radius: r * 1.1))
        let glowRect = headRect.insetBy(dx: -r * 0.6, dy: -r * 0.6)
        glow.fill(
            Path(ellipseIn: glowRect),
            with: .color(Color(red: 1.0, green: 0.7, blue: 0.3).opacity(phase.opacity * 0.5))
        )

        // Bright core.
        context.fill(
            Path(ellipseIn: headRect),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 1.0, green: 0.97, blue: 0.88).opacity(phase.opacity),
                    Color(red: 1.0, green: 0.74, blue: 0.30).opacity(phase.opacity)
                ]),
                center: p,
                startRadius: 0,
                endRadius: r
            )
        )
    }
}

// MARK: - Badge glyph (always legible)

private struct OrbitBadgeView_BadgeGlyph: View {
    let count: Int
    let radius: CGFloat
    let pulse: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.36, blue: 0.42),
                            Color(red: 0.93, green: 0.22, blue: 0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            Color(red: 1.0, green: 1.0, blue: 1.0).opacity(0.35),
                            lineWidth: max(1.0, radius * 0.06)
                        )
                )
                .shadow(
                    color: Color(red: 0.93, green: 0.22, blue: 0.55).opacity(0.6),
                    radius: radius * 0.5
                )

            Text(label)
                .font(.system(size: radius * 0.9, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .foregroundStyle(Color(red: 1.0, green: 1.0, blue: 1.0))
                .padding(.horizontal, radius * 0.18)
        }
        .frame(width: radius * 2.0, height: radius * 2.0)
        .scaleEffect(pulse)
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: count)
    }

    private var label: String {
        count > 99 ? "99+" : "\(count)"
    }
}
