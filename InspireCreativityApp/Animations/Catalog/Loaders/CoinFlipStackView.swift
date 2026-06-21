// catalog-id: ld-coin-flip-stack
import SwiftUI

// MARK: - CoinFlipStackView_Coin Flip Stack
// A single coin flips on its horizontal (X) axis with 3D perspective.
// The heads/tails face swaps at the 90 degree crossing; a foreshortened
// ground shadow stretches and shrinks with cos(angle). In demo mode it
// auto-flips forever; the real component idle-spins AND accepts a vertical
// fling whose release velocity seeds a friction-decayed spin that eases to
// a face-up rest before resuming the idle spin.
struct CoinFlipStackView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            CoinFlipStackView_CoinFlipStage(demo: demo, size: geo.size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Motion model

private enum CoinFlipStackView_FlipPhase {
    /// Continuous self-driving spin. `velocity` in degrees/sec.
    case idle(startAngle: Double, startTime: TimeInterval, velocity: Double)
    /// Finger is down; angle is held externally via drag translation.
    case dragging(heldAngle: Double)
    /// Friction-decayed fling easing to a face-up target.
    case settling(startAngle: Double, target: Double, startTime: TimeInterval)
}

private struct CoinFlipStackView_CoinMotion {
    var phase: CoinFlipStackView_FlipPhase
    /// Angle captured when a drag begins, so translation is additive.
    var dragAnchor: Double = 0

    /// Closed-form angle as a pure function of the current clock — no
    /// state mutation happens during the view update.
    func angle(at now: TimeInterval) -> Double {
        switch phase {
        case let .idle(startAngle, startTime, velocity):
            return startAngle + velocity * (now - startTime)
        case let .dragging(heldAngle):
            return heldAngle
        case let .settling(startAngle, target, startTime):
            let k: Double = 2.6                 // friction coefficient
            let travel = target - startAngle
            let t = max(0, now - startTime)
            return startAngle + travel * (1 - exp(-k * t))
        }
    }

    /// Once settling has effectively asymptoted, hand back to idle so the
    /// coin keeps gently flipping and never freezes edge-on.
    func advanced(at now: TimeInterval) -> CoinFlipStackView_CoinMotion {
        guard case let .settling(_, target, startTime) = phase else { return self }
        if now - startTime > 2.4 {
            var copy = self
            copy.phase = .idle(startAngle: target, startTime: now, velocity: CoinFlipStackView_CoinMotion.idleVelocity)
            return copy
        }
        return self
    }

    static let idleVelocity: Double = 150   // degrees/sec resting spin
}

// MARK: - Stage (drives angle for both modes)

private struct CoinFlipStackView_CoinFlipStage: View {
    let demo: Bool
    let size: CGSize

    @State private var motion = CoinFlipStackView_CoinMotion(
        phase: .idle(startAngle: 0, startTime: 0, velocity: CoinFlipStackView_CoinMotion.idleVelocity)
    )
    @State private var didSeedIdle = false

    private var coinDiameter: CGFloat {
        min(size.width, size.height) * 0.56
    }

    var body: some View {
        TimelineView(.animation) { context in
            let now = context.date.timeIntervalSinceReferenceDate
            let angle = currentAngle(now: now)
            content(angle: angle, now: now)
        }
        .contentShape(Rectangle())
        .gesture(flingGesture, including: demo ? .none : .all)
        .onAppear {
            guard !didSeedIdle else { return }
            didSeedIdle = true
            let now = Date().timeIntervalSinceReferenceDate
            motion.phase = .idle(startAngle: 0, startTime: now, velocity: CoinFlipStackView_CoinMotion.idleVelocity)
        }
    }

    // MARK: angle source

    private func currentAngle(now: TimeInterval) -> Double {
        if demo {
            // Self-driving: a gentle ease so the flip has a little life,
            // never zero and never blank.
            let speed: Double = 200
            let base = now * speed
            let wobble = sin(now * 0.9) * 14
            return base + wobble
        } else {
            // Promote a finished settle back to idle without mutating
            // state inside the body update.
            let promoted = motion.advanced(at: now)
            if case .idle = promoted.phase, case .settling = motion.phase {
                DispatchQueue.main.async { motion = promoted }
            }
            return motion.angle(at: now)
        }
    }

    // MARK: layout

    @ViewBuilder
    private func content(angle: Double, now: TimeInterval) -> some View {
        let radians = angle * .pi / 180
        let faceFactor = cos(radians)               // +1 heads-flat ... -1 tails-flat
        let edgeFactor = abs(faceFactor)            // 1 flat, 0 edge-on
        let d = coinDiameter

        ZStack {
            CoinFlipStackView_GroundShadow(diameter: d, edgeFactor: edgeFactor)
                .offset(y: d * 0.52)

            CoinFlipStackView_LandingStack(diameter: d)
                .offset(y: d * 0.50)
                .opacity(0.9)

            CoinFlipStackView_Coin(angle: angle, faceFactor: faceFactor, edgeFactor: edgeFactor, diameter: d)
                .offset(y: liftOffset(edgeFactor: edgeFactor, d: d))
        }
        .frame(width: size.width, height: size.height)
    }

    /// A tiny vertical lift while edge-on sells the toss arc.
    private func liftOffset(edgeFactor: CGFloat, d: CGFloat) -> CGFloat {
        -(1 - edgeFactor) * d * 0.06
    }

    // MARK: gesture

    private var flingGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if case .dragging = motion.phase {
                    let delta = Double(value.translation.height) * -0.9
                    motion.phase = .dragging(heldAngle: motion.dragAnchor + delta)
                } else {
                    let now = Date().timeIntervalSinceReferenceDate
                    let held = motion.angle(at: now)
                    motion.dragAnchor = held
                    motion.phase = .dragging(heldAngle: held)
                }
            }
            .onEnded { value in
                let now = Date().timeIntervalSinceReferenceDate
                let held: Double
                if case let .dragging(h) = motion.phase { held = h } else { held = motion.angle(at: now) }
                // Upward flick (negative height velocity) spins forward.
                let v0 = Double(value.velocity.height) * -0.9   // deg/sec
                let k: Double = 2.6
                let naturalRest = held + v0 / k
                let target = (naturalRest / 180).rounded() * 180   // nearest face-up
                motion.phase = .settling(startAngle: held, target: target, startTime: now)
            }
    }
}

// MARK: - The coin

private struct CoinFlipStackView_Coin: View {
    let angle: Double
    let faceFactor: Double      // cos(angle)
    let edgeFactor: CGFloat     // abs(cos(angle))
    let diameter: CGFloat

    private var headsVisible: Bool { faceFactor >= 0 }

    var body: some View {
        ZStack {
            // Metallic edge / rim — always present so the coin never reads
            // as a blank line when edge-on.
            CoinFlipStackView_CoinRim(diameter: diameter, edgeFactor: edgeFactor)

            // Heads
            CoinFlipStackView_CoinFace(
                diameter: diameter,
                emblem: "crown.fill",
                base: Color(red: 0.95, green: 0.80, blue: 0.40),
                rim: Color(red: 0.70, green: 0.52, blue: 0.18)
            )
            .opacity(headsVisible ? 1 : 0)

            // Tails — pre-rotated 180 about X so the back face is not mirrored.
            CoinFlipStackView_CoinFace(
                diameter: diameter,
                emblem: "star.fill",
                base: Color(red: 0.82, green: 0.84, blue: 0.90),
                rim: Color(red: 0.45, green: 0.50, blue: 0.60)
            )
            .rotation3DEffect(.degrees(180), axis: (x: 1, y: 0, z: 0))
            .opacity(headsVisible ? 0 : 1)
        }
        .frame(width: diameter, height: diameter)
        .rotation3DEffect(
            .degrees(angle),
            axis: (x: 1, y: 0, z: 0),
            anchor: .center,
            anchorZ: 0,
            perspective: 0.55
        )
        // Top-light specular sweep tied to the face tilt.
        .overlay(specular)
    }

    private var specular: some View {
        Ellipse()
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.32 * Double(edgeFactor)), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
            )
            .frame(width: diameter * 0.7, height: diameter * 0.5)
            .offset(y: -diameter * 0.18)
            .scaleEffect(y: edgeFactor, anchor: .center)
            .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0), perspective: 0.55)
            .allowsHitTesting(false)
            .blendMode(.screen)
    }
}

// MARK: - CoinFlipStackView_Coin face

private struct CoinFlipStackView_CoinFace: View {
    let diameter: CGFloat
    let emblem: String
    let base: Color
    let rim: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [base, base.opacity(0.92), rim],
                        center: .init(x: 0.38, y: 0.30),
                        startRadius: diameter * 0.04,
                        endRadius: diameter * 0.62
                    )
                )

            // Angular metallic glint around the disc.
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            Color.white.opacity(0.55), rim.opacity(0.0),
                            Color.white.opacity(0.35), rim.opacity(0.0),
                            Color.white.opacity(0.55)
                        ],
                        center: .center
                    ),
                    lineWidth: diameter * 0.06
                )

            // Inner ring detail.
            Circle()
                .strokeBorder(rim.opacity(0.55), lineWidth: diameter * 0.018)
                .padding(diameter * 0.11)

            Image(systemName: emblem)
                .font(.system(size: diameter * 0.34, weight: .black))
                .foregroundStyle(rim.opacity(0.85))
                .shadow(color: .white.opacity(0.4), radius: 0.5, y: -0.5)
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
    }
}

// MARK: - Metallic rim (visible edge-on)

private struct CoinFlipStackView_CoinRim: View {
    let diameter: CGFloat
    let edgeFactor: CGFloat   // 1 flat, 0 edge-on

    var body: some View {
        // Thickness reads when the coin turns toward its edge.
        let thickness = diameter * 0.10 * (1 - edgeFactor) + diameter * 0.014
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.55, green: 0.50, blue: 0.42),
                        Color(red: 0.92, green: 0.88, blue: 0.78),
                        Color(red: 0.50, green: 0.46, blue: 0.40)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: diameter, height: max(thickness, diameter * 0.02))
    }
}

// MARK: - Ground shadow

private struct CoinFlipStackView_GroundShadow: View {
    let diameter: CGFloat
    let edgeFactor: CGFloat   // wide when flat, thin when edge-on

    var body: some View {
        let w = diameter * (0.42 + 0.46 * edgeFactor)
        let h = diameter * 0.16
        Ellipse()
            .fill(Color.black.opacity(0.30 + 0.18 * Double(edgeFactor)))
            .frame(width: max(w, diameter * 0.18), height: h)
            .blur(radius: diameter * 0.05)
    }
}

// MARK: - Optional static landing stack (flavor)

private struct CoinFlipStackView_LandingStack: View {
    let diameter: CGFloat

    var body: some View {
        let w = diameter * 0.78
        let t = diameter * 0.07
        VStack(spacing: -t * 0.45) {
            stackCoin(width: w * 0.96, thickness: t, shade: 0.78)
            stackCoin(width: w, thickness: t, shade: 0.86)
            stackCoin(width: w * 0.94, thickness: t, shade: 0.74)
        }
        .opacity(0.85)
    }

    private func stackCoin(width: CGFloat, thickness: CGFloat, shade: Double) -> some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.62 * shade, green: 0.58 * shade, blue: 0.46 * shade),
                        Color(red: 0.90 * shade, green: 0.84 * shade, blue: 0.62 * shade),
                        Color(red: 0.55 * shade, green: 0.50 * shade, blue: 0.40 * shade)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: width, height: thickness)
    }
}
