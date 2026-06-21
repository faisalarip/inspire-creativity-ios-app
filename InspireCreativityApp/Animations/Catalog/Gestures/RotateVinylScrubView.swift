// catalog-id: ges-rotate-vinyl-scrub
import SwiftUI

// MARK: - Vinyl Scrub Platter
// Spin a record platter with a one-finger rotate (atan2) gesture; it keeps
// momentum and slows by friction. Dragging against the spin scrubs it back
// with a pitch-bent scale/opacity/blur wobble of the label art.
// iOS 17. No Metal.

struct RotateVinylScrubView: View {
    var demo: Bool = false

    // Physics state ----------------------------------------------------------
    @State private var angle: Double = 0            // radians, accumulated
    @State private var velocity: Double = 0         // radians / second
    @State private var wobble: Double = 0           // 0...1 transient back-cue
    @State private var lastDate: Date? = nil

    // Gesture tracking -------------------------------------------------------
    @State private var isDragging: Bool = false
    @State private var lastTouchAngle: Double = 0   // radians
    @State private var smoothedDelta: Double = 0    // EMA of per-frame delta
    @State private var lastDragDelta: Double = 0     // last raw drag delta sign

    // Demo scripting ---------------------------------------------------------
    @State private var demoStart: Date? = nil

    // Tuning -----------------------------------------------------------------
    private let decay: Double = 1.15                 // friction (per second, exp)
    private let maxVelocity: Double = 34.0           // clamp flick
    private let tau: Double = 2.0 * .pi

    // Per-revolution tick for haptics (interactive only)
    private var revolutionTick: Int { Int(angle / tau) }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            TimelineView(.animation) { timeline in
                platter(side: side)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .contentShape(Rectangle())
                    .gesture(scrubGesture(center: center), including: demo ? .none : .all)
                    .onChange(of: timeline.date) { _, now in
                        step(now: now)
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(RotateVinylScrubView_RevolutionHaptic(tick: revolutionTick, enabled: !demo))
    }

    // MARK: - Visual

    @ViewBuilder
    private func platter(side: CGFloat) -> some View {
        let discSize = side * 0.86
        let labelSize = discSize * 0.40
        let spindle = discSize * 0.045

        ZStack {
            // Backing / turntable felt glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.10, green: 0.10, blue: 0.13),
                            Color(red: 0.04, green: 0.04, blue: 0.06)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: side * 0.6
                    )
                )
                .frame(width: side, height: side)

            // The rotating disc (grooves + asymmetric label) — everything that
            // visibly moves lives in here under one rotationEffect.
            ZStack {
                vinylBody(size: discSize)
                grooveSheen(size: discSize)
                label(size: labelSize)
            }
            .rotationEffect(.radians(angle))

            // Fixed tonearm-style sheen sweep across the platter so even the
            // grooves catch a moving glint as the disc spins under it.
            staticSheen(size: discSize)
                .allowsHitTesting(false)

            // Spindle (fixed, centered)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.85, green: 0.86, blue: 0.90),
                                 Color(red: 0.55, green: 0.56, blue: 0.62)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: spindle, height: spindle)
                .shadow(color: .black.opacity(0.4), radius: 1, y: 0.5)
        }
    }

    @ViewBuilder
    private func vinylBody(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.07, green: 0.07, blue: 0.09))
            // Concentric grooves
            ForEach(0..<14, id: \.self) { i in
                let t = Double(i) / 13.0
                Circle()
                    .stroke(
                        Color.white.opacity(0.04 + 0.03 * (1 - t)),
                        lineWidth: max(0.5, size * 0.004)
                    )
                    .frame(width: size * (0.46 + 0.52 * t),
                           height: size * (0.46 + 0.52 * t))
            }
            // Asymmetric colored groove sector so rotation is always legible
            grooveSector(size: size)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.55), radius: size * 0.03, y: size * 0.012)
    }

    @ViewBuilder
    private func grooveSector(size: CGFloat) -> some View {
        // A faint warm wedge sweeping a slice of the grooves — an asymmetric
        // mark that makes the spin readable on every frame.
        Path { p in
            let c = CGPoint(x: size / 2, y: size / 2)
            let r = size * 0.49
            p.move(to: c)
            p.addArc(center: c, radius: r,
                     startAngle: .degrees(-14), endAngle: .degrees(14),
                     clockwise: false)
            p.closeSubpath()
        }
        .fill(
            AngularGradient(
                colors: [Color(red: 1.0, green: 0.62, blue: 0.25).opacity(0.0),
                         Color(red: 1.0, green: 0.62, blue: 0.25).opacity(0.22),
                         Color(red: 1.0, green: 0.62, blue: 0.25).opacity(0.0)],
                center: .center
            )
        )
        .blendMode(.screen)
    }

    @ViewBuilder
    private func grooveSheen(size: CGFloat) -> some View {
        // A subtle rotating highlight ring giving the vinyl its plastic gleam.
        Circle()
            .trim(from: 0.0, to: 0.5)
            .stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.0),
                             Color.white.opacity(0.10),
                             Color.white.opacity(0.0)],
                    startPoint: .leading, endPoint: .trailing
                ),
                lineWidth: size * 0.5
            )
            .frame(width: size * 0.74, height: size * 0.74)
            .blendMode(.screen)
            .opacity(0.5)
    }

    @ViewBuilder
    private func label(size: CGFloat) -> some View {
        // The pitch-bend wobble: opposing the spin transiently squashes,
        // fades and blurs the label art.
        let squash = 1.0 - 0.16 * wobble
        let blurAmt = CGFloat(2.5 * wobble)
        let fade = 1.0 - 0.30 * wobble

        ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            Color(red: 0.94, green: 0.27, blue: 0.36),
                            Color(red: 0.99, green: 0.55, blue: 0.30),
                            Color(red: 0.96, green: 0.80, blue: 0.32),
                            Color(red: 0.94, green: 0.27, blue: 0.36)
                        ],
                        center: .center
                    )
                )
            // Concentric label rings
            Circle().stroke(Color.black.opacity(0.18), lineWidth: size * 0.02)
                .frame(width: size * 0.78, height: size * 0.78)
            // Asymmetric label mark — a notch + text arc that read the spin.
            labelMark(size: size)
            // Center hole
            Circle()
                .fill(Color(red: 0.05, green: 0.05, blue: 0.07))
                .frame(width: size * 0.16, height: size * 0.16)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .scaleEffect(x: squash, y: 2.0 - squash, anchor: .center)
        .opacity(fade)
        .blur(radius: blurAmt)
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func labelMark(size: CGFloat) -> some View {
        ZStack {
            // A bold notch at "12 o'clock" of the label.
            Capsule()
                .fill(Color.white.opacity(0.92))
                .frame(width: size * 0.05, height: size * 0.20)
                .offset(y: -size * 0.26)
            Text("33⅓")
                .font(.system(size: size * 0.13, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.55))
                .offset(y: size * 0.24)
        }
    }

    @ViewBuilder
    private func staticSheen(size: CGFloat) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.12),
                             Color.white.opacity(0.0),
                             Color.white.opacity(0.0),
                             Color.white.opacity(0.05)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .blendMode(.screen)
    }

    // MARK: - Gesture (one-finger atan2 scrub)

    private func scrubGesture(center: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let touchAngle = atan2(value.location.y - center.y,
                                       value.location.x - center.x)
                if !isDragging {
                    isDragging = true
                    lastTouchAngle = touchAngle
                    smoothedDelta = 0
                    return
                }
                var delta = touchAngle - lastTouchAngle
                // Unwrap across the -pi/pi boundary
                if delta > .pi { delta -= tau }
                if delta < -.pi { delta += tau }

                // Back-cue detection: finger opposes current spin direction.
                if velocity != 0, sign(delta) != sign(velocity), abs(delta) > 0.001 {
                    let intensity = min(1.0, abs(delta) * 6.0)
                    wobble = max(wobble, intensity)
                }

                angle += delta
                lastDragDelta = delta
                // EMA of delta to estimate release velocity smoothly.
                smoothedDelta = smoothedDelta * 0.7 + delta * 0.3
                lastTouchAngle = touchAngle
            }
            .onEnded { _ in
                isDragging = false
                // Convert smoothed per-frame delta into angular velocity.
                // At ~60fps a frame is ~1/60s; scale up to per-second.
                let v = smoothedDelta * 60.0
                velocity = clampVelocity(velocity * 0.2 + v)
            }
    }

    // MARK: - Physics integrator (runs every frame for demo & interactive)

    private func step(now: Date) {
        guard let last = lastDate else {
            lastDate = now
            if demo { demoStart = now }
            return
        }
        var dt = now.timeIntervalSince(last)
        lastDate = now
        if dt <= 0 { return }
        dt = min(dt, 1.0 / 20.0) // guard against long stalls

        if demo {
            driveDemo(now: now, dt: dt)
        }

        if !isDragging {
            // Framerate-independent friction.
            velocity *= exp(-decay * dt)
            if abs(velocity) < 0.02 { velocity = 0 }
            angle += velocity * dt
        }

        // Wobble eases out on its own.
        if wobble > 0 {
            wobble = max(0, wobble - dt * 2.2)
        }
    }

    // MARK: - Demo loop (scripted impulses on a ~3.2s cycle)

    private func driveDemo(now: Date, dt: Double) {
        guard let start = demoStart else { demoStart = now; return }
        let period = 3.2
        let t = now.timeIntervalSince(start).truncatingRemainder(dividingBy: period)

        switch t {
        case 0.0..<0.10:
            // Kick: spin up forward.
            velocity = 16.0
        case 1.85..<1.95:
            // Back-cue nudge: shove against the spin, trip the wobble.
            velocity = -7.0
            wobble = 1.0
        case 2.55..<2.62:
            // Tiny forward re-nudge so it never sits dead-still.
            if abs(velocity) < 0.5 { velocity = 3.0 }
        default:
            break
        }
        // Even at rest, keep a faint idle drift so the tile is never frozen.
        if abs(velocity) < 0.15 {
            velocity = 0.6
        }
    }

    // MARK: - Helpers

    private func clampVelocity(_ v: Double) -> Double {
        max(-maxVelocity, min(maxVelocity, v))
    }

    private func sign(_ x: Double) -> Double {
        x > 0 ? 1 : (x < 0 ? -1 : 0)
    }
}

// MARK: - Per-revolution haptic (interactive only)

private struct RotateVinylScrubView_RevolutionHaptic: ViewModifier {
    let tick: Int
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.sensoryFeedback(.selection, trigger: tick)
        } else {
            content
        }
    }
}
