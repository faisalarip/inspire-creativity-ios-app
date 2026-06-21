// catalog-id: ges-pull-to-trigger-bow
import SwiftUI

// MARK: - Slingshot Launcher
// Pull a projectile back against a stretching elastic band that thins and tints
// under tension, then release to fling it forward along the loaded vector while
// the band recoils with a twang wobble.
struct PullToTriggerBowView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                PullToTriggerBowView_SlingBackground()
                if demo {
                    PullToTriggerBowView_DemoDriver(size: size)
                } else {
                    PullToTriggerBowView_InteractiveDriver(size: size)
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Geometry helpers (all fractions of the rendered size)

private struct PullToTriggerBowView_SlingGeometry {
    let size: CGSize

    // The Y-frame: a base post rising to two splayed fork tips.
    var basePost: CGPoint { CGPoint(x: size.width * 0.5, y: size.height * 0.92) }
    var forkJoint: CGPoint { CGPoint(x: size.width * 0.5, y: size.height * 0.56) }
    var forkLeft: CGPoint { CGPoint(x: size.width * 0.5 - tineSpread, y: size.height * 0.30) }
    var forkRight: CGPoint { CGPoint(x: size.width * 0.5 + tineSpread, y: size.height * 0.30) }

    // Resting nock sits between the two tines.
    var nock: CGPoint {
        CGPoint(x: (forkLeft.x + forkRight.x) / 2, y: (forkLeft.y + forkRight.y) / 2)
    }

    var tineSpread: CGFloat { min(size.width, size.height) * 0.26 }
    var maxPull: CGFloat { min(size.width, size.height) * 0.34 }
    var projectileRadius: CGFloat { min(size.width, size.height) * 0.075 }
    var slingStroke: CGFloat { min(size.width, size.height) * 0.018 }
}

// MARK: - Shared math

private func clampLength(_ v: CGSize, max maxLen: CGFloat) -> CGSize {
    let len = hypot(v.width, v.height)
    if len <= maxLen || len == 0 { return v }
    // Rubber-band past the cap so over-drag still resists but never runs away.
    let over = len - maxLen
    let damped = maxLen + over * 0.18
    let scale = damped / len
    return CGSize(width: v.width * scale, height: v.height * scale)
}

private func tensionValue(pull: CGSize, maxPull: CGFloat) -> CGFloat {
    guard maxPull > 0 else { return 0 }
    let t = hypot(pull.width, pull.height) / maxPull
    return min(max(t, 0), 1)
}

private func bandWidth(tension t: CGFloat, base: CGFloat) -> CGFloat {
    // Thins as it stretches: 1.0x slack -> 0.45x taut.
    let factor: CGFloat = 1.0 - 0.55 * t
    return base * factor
}

private func bandColor(tension t: CGFloat) -> Color {
    // Cool amber slack -> hot red-orange taut (hue interpolation).
    let hue = 0.11 - 0.11 * Double(t)            // ~0.11 (amber) -> 0.0 (red)
    let sat = 0.55 + 0.40 * Double(t)
    let bri = 0.95 - 0.10 * Double(t)
    return Color(hue: max(hue, 0.0), saturation: min(sat, 1.0), brightness: bri)
}

// MARK: - Background

private struct PullToTriggerBowView_SlingBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.09),
                Color(red: 0.09, green: 0.08, blue: 0.14)
            ],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Static frame (the Y posts + tines)

private struct PullToTriggerBowView_SlingFrame: View {
    let geo: PullToTriggerBowView_SlingGeometry

    var body: some View {
        let woodLight = Color(red: 0.42, green: 0.30, blue: 0.20)
        let woodDark = Color(red: 0.24, green: 0.16, blue: 0.10)
        Path { p in
            p.move(to: geo.basePost)
            p.addLine(to: geo.forkJoint)
            p.move(to: geo.forkJoint)
            p.addLine(to: geo.forkLeft)
            p.move(to: geo.forkJoint)
            p.addLine(to: geo.forkRight)
        }
        .stroke(
            LinearGradient(colors: [woodLight, woodDark], startPoint: .top, endPoint: .bottom),
            style: StrokeStyle(lineWidth: geo.slingStroke * 2.6, lineCap: .round, lineJoin: .round)
        )
        .overlay {
            // Tine cap knobs where the band ties on.
            ForEach([geo.forkLeft, geo.forkRight], id: \.self) { pt in
                Circle()
                    .fill(woodDark)
                    .frame(width: geo.slingStroke * 3.2, height: geo.slingStroke * 3.2)
                    .position(pt)
            }
        }
    }
}

// MARK: - The elastic band + projectile (the shared, parameterized render)

private struct PullToTriggerBowView_SlingBand: View {
    let geo: PullToTriggerBowView_SlingGeometry
    /// Live position of the projectile / nock pocket.
    let projectile: CGPoint
    /// Tension 0...1 used for thinning + tinting.
    let tension: CGFloat
    /// 0 = projectile present, 1 = launched (fades the ball, slack band only).
    var launchFade: CGFloat = 0

    var body: some View {
        let width = bandWidth(tension: tension, base: geo.slingStroke * 2.4)
        let color = bandColor(tension: tension)
        ZStack {
            // Two band lines from each fork tip to the projectile pocket.
            bandLine(from: geo.forkLeft, to: projectile)
                .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
            bandLine(from: geo.forkRight, to: projectile)
                .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))

            // Leather pocket cradling the projectile.
            pocketView(color: color)
                .opacity(1 - launchFade)

            PullToTriggerBowView_ProjectileView(radius: geo.projectileRadius, glow: tension)
                .position(projectile)
                .opacity(1 - launchFade)
                .scaleEffect(1 - 0.25 * launchFade)
        }
    }

    private func bandLine(from a: CGPoint, to b: CGPoint) -> Path {
        Path { p in
            p.move(to: a)
            p.addLine(to: b)
        }
    }

    private func pocketView(color: Color) -> some View {
        let w = geo.projectileRadius * 1.5
        return Capsule()
            .fill(Color(red: 0.30, green: 0.20, blue: 0.14))
            .frame(width: w * 0.5, height: w * 1.4)
            .overlay(Capsule().stroke(color.opacity(0.7), lineWidth: geo.slingStroke))
            .rotationEffect(pocketAngle)
            .position(projectile)
    }

    private var pocketAngle: Angle {
        let dx = projectile.x - geo.nock.x
        let dy = projectile.y - geo.nock.y
        if abs(dx) < 0.001 && abs(dy) < 0.001 { return .degrees(0) }
        return .radians(atan2(dy, dx) - .pi / 2)
    }
}

private struct PullToTriggerBowView_ProjectileView: View {
    let radius: CGFloat
    let glow: CGFloat

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 0.95, green: 0.95, blue: 1.0),
                        Color(red: 0.55, green: 0.60, blue: 0.78),
                        Color(red: 0.30, green: 0.34, blue: 0.52)
                    ],
                    center: .init(x: 0.35, y: 0.30),
                    startRadius: 0,
                    endRadius: radius * 1.4
                )
            )
            .frame(width: radius * 2, height: radius * 2)
            .shadow(color: bandColor(tension: glow).opacity(0.55 + 0.4 * glow),
                    radius: 4 + 8 * glow)
    }
}

// MARK: - Interactive driver (real DragGesture)

private struct PullToTriggerBowView_InteractiveDriver: View {
    let size: CGSize

    @State private var pull: CGSize = .zero      // current drag offset from nock
    @State private var isDragging = false
    @State private var launchCount = 0
    @State private var launchFade: CGFloat = 0    // projectile vanish on flight
    @State private var flightOffset: CGSize = .zero

    private var geo: PullToTriggerBowView_SlingGeometry { PullToTriggerBowView_SlingGeometry(size: size) }

    private var projectilePoint: CGPoint {
        CGPoint(x: geo.nock.x + pull.width + flightOffset.width,
                y: geo.nock.y + pull.height + flightOffset.height)
    }

    private var tension: CGFloat {
        tensionValue(pull: pull, maxPull: geo.maxPull)
    }

    var body: some View {
        ZStack {
            PullToTriggerBowView_SlingFrame(geo: geo)
            PullToTriggerBowView_SlingBand(geo: geo,
                      projectile: projectilePoint,
                      tension: isDragging ? tension : (flightOffset == .zero ? tension : 0),
                      launchFade: launchFade)
            PullToTriggerBowView_HintLabel(text: isDragging ? "release to fire" : "drag & release")
                .position(x: size.width / 2, y: size.height * 0.05)
                .opacity(launchFade > 0.2 ? 0 : 0.85)
        }
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.9), trigger: launchCount)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard launchFade == 0 else { return }
                isDragging = true
                pull = clampLength(value.translation, max: geo.maxPull)
            }
            .onEnded { _ in
                isDragging = false
                fire()
            }
    }

    private func fire() {
        let firedTension = tension
        // Fire forward along the negative of the pull vector.
        guard firedTension > 0.05 else {
            withAnimation(.interpolatingSpring(stiffness: 170, damping: 9)) { pull = .zero }
            return
        }
        launchCount += 1

        // Flight: project the ball outward opposite to the pull, off-screen.
        let dir = CGSize(width: -pull.width, height: -pull.height)
        let len = max(hypot(dir.width, dir.height), 0.001)
        let travel = max(size.width, size.height) * (1.1 + Double(firedTension))
        let flight = CGSize(width: dir.width / len * travel,
                            height: dir.height / len * travel)

        // Band twangs back to slack with a low-damping spring while ball coasts away.
        withAnimation(.interpolatingSpring(stiffness: 130, damping: 6)) {
            pull = .zero
        }
        withAnimation(.easeOut(duration: 0.55)) {
            flightOffset = flight
            launchFade = 1
        }
        // Respawn the projectile in the nock so it is re-draggable.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
            flightOffset = .zero
            withAnimation(.easeIn(duration: 0.25)) { launchFade = 0 }
        }
    }
}

// MARK: - Demo driver (self-driving PhaseAnimator loop)

private enum PullToTriggerBowView_SlingPhase: CaseIterable {
    case idle, drawn, fired
}

private struct PullToTriggerBowView_DemoDriver: View {
    let size: CGSize

    private var geo: PullToTriggerBowView_SlingGeometry { PullToTriggerBowView_SlingGeometry(size: size) }

    var body: some View {
        // Drive the loop with a timeline that flips phase on a ~3.2s cadence,
        // and let PhaseAnimator's spring give the twang for free.
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let trigger = Int(t / 1.07)   // advances the phase animator periodically
            PhaseAnimator(PullToTriggerBowView_SlingPhase.allCases, trigger: trigger) { phase in
                content(for: phase)
            } animation: { phase in
                animation(into: phase)
            }
        }
    }

    @ViewBuilder
    private func content(for phase: PullToTriggerBowView_SlingPhase) -> some View {
        let pull = pullVector(for: phase)
        let tension = tensionValue(pull: pull, maxPull: geo.maxPull)
        let projectile = CGPoint(x: geo.nock.x + pull.width,
                                 y: geo.nock.y + pull.height)
        ZStack {
            PullToTriggerBowView_SlingFrame(geo: geo)
            PullToTriggerBowView_SlingBand(geo: geo,
                      projectile: projectile,
                      tension: phase == .fired ? 0 : tension,
                      launchFade: phase == .fired ? firedFade : 0)
            // A second "in-flight" tracer ball on the fired phase keeps the tile
            // alive and shows the launch direction, never fully blank.
            if phase == .fired {
                PullToTriggerBowView_ProjectileView(radius: geo.projectileRadius, glow: 0.0)
                    .position(flightTarget)
                    .opacity(0.9)
            }
        }
    }

    // Demo states: idle slack, drawn-back taut, fired (slack + tracer in flight).
    private func pullVector(for phase: PullToTriggerBowView_SlingPhase) -> CGSize {
        switch phase {
        case .idle:  return .zero
        case .drawn: return CGSize(width: geo.maxPull * 0.30, height: geo.maxPull * 0.92)
        case .fired: return .zero
        }
    }

    private var firedFade: CGFloat { 1 }

    // Forward (up + slightly left) launch target, opposite the drawn vector.
    private var flightTarget: CGPoint {
        CGPoint(x: geo.nock.x - geo.maxPull * 0.30 * 2.4,
                y: geo.nock.y - geo.maxPull * 0.92 * 2.2)
    }

    private func animation(into phase: PullToTriggerBowView_SlingPhase) -> Animation {
        switch phase {
        case .idle:  return .interpolatingSpring(stiffness: 120, damping: 7)  // twang back to rest
        case .drawn: return .easeInOut(duration: 0.7)                          // smooth pull-back
        case .fired: return .easeOut(duration: 0.22)                           // snap release
        }
    }
}

// MARK: - Hint label

private struct PullToTriggerBowView_HintLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.white.opacity(0.08), in: Capsule())
    }
}
