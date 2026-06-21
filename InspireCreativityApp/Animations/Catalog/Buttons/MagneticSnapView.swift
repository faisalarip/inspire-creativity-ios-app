// catalog-id: btn-magnetic-snap
import SwiftUI

// MARK: - Magnetic Snap
// As the finger nears the button, the label and a small metal nub lean toward
// the touch point with an inverse-falloff attraction, then snap-lock with a
// recoil wobble when pressed. `demo == true` self-drives via TimelineView;
// `demo == false` is the real interactive DragGesture component.

struct MagneticSnapView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            let metrics = MagneticSnapView_Metrics(size: geo.size)
            if demo {
                MagneticSnapView_DemoDriver(metrics: metrics)
            } else {
                MagneticSnapView_InteractiveDriver(metrics: metrics)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Layout metrics derived from the tile size

private struct MagneticSnapView_Metrics {
    let size: CGSize
    let minSide: CGFloat
    let center: CGPoint
    let buttonWidth: CGFloat
    let buttonHeight: CGFloat
    let cornerRadius: CGFloat
    let nubSize: CGFloat
    let maxLean: CGFloat
    let maxRotation: Double
    let fontSize: CGFloat

    init(size: CGSize) {
        self.size = size
        let minS: CGFloat = max(min(size.width, size.height), 1)
        self.minSide = minS
        self.center = CGPoint(x: size.width / 2, y: size.height / 2)
        self.buttonWidth = min(size.width * 0.74, minS * 1.35)
        self.buttonHeight = minS * 0.42
        self.cornerRadius = minS * 0.10
        self.nubSize = minS * 0.13
        self.maxLean = minS * 0.16
        self.maxRotation = 14
        self.fontSize = minS * 0.16
    }
}

// MARK: - MagneticSnapView_Attraction model (correct-by-inspection, all numerics annotated)

private enum MagneticSnapView_Attraction {
    /// Maps a finger location to a clamped lean vector + rotation. Uses an
    /// inverse falloff with a floored denominator so it can never blow up.
    static func lean(from point: CGPoint, metrics m: MagneticSnapView_Metrics) -> (offset: CGSize, rotation: Double, pull: CGFloat) {
        let dx: CGFloat = point.x - m.center.x
        let dy: CGFloat = point.y - m.center.y
        let distance: CGFloat = sqrt(dx * dx + dy * dy)

        // Influence radius: how far away the finger still affects the nub.
        let radius: CGFloat = max(m.minSide * 0.9, 1)
        // Floored denominator — never divides by ~0.
        let floored: CGFloat = max(distance, m.minSide * 0.18)
        // Inverse falloff in 0...1, strongest when close.
        let raw: CGFloat = radius / (floored + radius)
        let pull: CGFloat = min(max(raw * 1.3, 0), 1)

        // Unit direction toward the finger (guarded).
        let safeDist: CGFloat = max(distance, 0.0001)
        let ux: CGFloat = dx / safeDist
        let uy: CGFloat = dy / safeDist

        let leanX: CGFloat = clampLean(ux * pull * m.maxLean, limit: m.maxLean)
        let leanY: CGFloat = clampLean(uy * pull * m.maxLean, limit: m.maxLean)

        // Tilt toward the horizontal direction of pull.
        let rot: Double = Double(ux * pull) * m.maxRotation

        return (CGSize(width: leanX, height: leanY), rot, pull)
    }

    private static func clampLean(_ value: CGFloat, limit: CGFloat) -> CGFloat {
        min(max(value, -limit), limit)
    }
}

// MARK: - Presentational core (single source of truth for both modes)

private struct MagneticSnapView_MagneticButton: View {
    let metrics: MagneticSnapView_Metrics
    let lean: CGSize          // current attraction lean
    let rotation: Double      // current tilt in degrees
    let pull: CGFloat         // 0...1 proximity strength
    let recoil: CGFloat       // 0...1 snap-recoil envelope (1 = freshly snapped)
    let pressed: Bool

    private var plateColor: Color { Color(red: 0.16, green: 0.18, blue: 0.22) }
    private var plateHi: Color { Color(red: 0.28, green: 0.31, blue: 0.37) }
    private var accent: Color { Color(red: 0.96, green: 0.78, blue: 0.36) }

    // Recoil overshoot: a small extra scale/offset kick that decays with `recoil`.
    private var recoilScale: CGFloat {
        let kick: CGFloat = 0.06 * recoil
        return pressed ? (1 - kick) : (1 + kick * 0.5)
    }

    var body: some View {
        ZStack {
            plate
            nub
            label
        }
        .frame(width: metrics.buttonWidth, height: metrics.buttonHeight)
        .position(metrics.center)
    }

    private var plate: some View {
        let shape = RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
        let borderOpacity: Double = 0.30 + Double(pull) * 0.45
        let glowOpacity: Double = 0.25 + Double(pull) * 0.35
        let glowRadius: CGFloat = metrics.minSide * (0.04 + pull * 0.10)
        let borderWidth: CGFloat = max(metrics.minSide * 0.012, 1)
        return shape
            .fill(
                LinearGradient(
                    colors: [plateHi, plateColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                shape.strokeBorder(
                    accent.opacity(borderOpacity),
                    lineWidth: borderWidth
                )
            )
            .shadow(
                color: accent.opacity(glowOpacity),
                radius: glowRadius,
                x: 0,
                y: metrics.minSide * 0.02
            )
            .scaleEffect(recoilScale)
            .rotation3DEffect(
                .degrees(rotation * 0.35),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.45), value: pressed)
    }

    private var nub: some View {
        // The little metal nub that leans hardest toward the finger.
        let nubLean = CGSize(
            width: lean.width * 1.35,
            height: lean.height * 1.35
        )
        let nubShadowRadius: CGFloat = metrics.nubSize * 0.5 * (0.5 + pull)
        return Circle()
            .fill(
                RadialGradient(
                    colors: [Color(red: 0.98, green: 0.85, blue: 0.55), accent, Color(red: 0.62, green: 0.46, blue: 0.16)],
                    center: .init(x: 0.35, y: 0.30),
                    startRadius: 0,
                    endRadius: metrics.nubSize * 0.7
                )
            )
            .overlay(
                Circle().strokeBorder(Color.white.opacity(0.5), lineWidth: max(metrics.nubSize * 0.06, 0.5))
            )
            .frame(width: metrics.nubSize, height: metrics.nubSize)
            .shadow(color: accent.opacity(0.6), radius: nubShadowRadius)
            .offset(nubLean)
            .rotationEffect(.degrees(rotation))
            .scaleEffect(1 + recoil * 0.18)
    }

    private var label: some View {
        Text("SNAP")
            .font(.system(size: metrics.fontSize, weight: .heavy, design: .rounded))
            .kerning(metrics.fontSize * 0.08)
            .foregroundStyle(Color.white.opacity(0.92))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .offset(x: lean.width * 0.5, y: lean.height * 0.5)
            .rotationEffect(.degrees(rotation * 0.5))
            .shadow(color: accent.opacity(Double(pull) * 0.8), radius: metrics.minSide * 0.03)
    }
}

// MARK: - Demo driver — self-driving phantom touch, NO haptics

private struct MagneticSnapView_DemoDriver: View {
    let metrics: MagneticSnapView_Metrics

    var body: some View {
        // TimelineView gives a continuous clock; we synthesize a phantom finger
        // sweeping in from the edge to center and back, plus a recoil envelope.
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = MagneticSnapView_PhantomPhase(time: t, metrics: metrics)
            MagneticSnapView_MagneticButton(
                metrics: metrics,
                lean: phase.lean,
                rotation: phase.rotation,
                pull: phase.pull,
                recoil: phase.recoil,
                pressed: phase.pressed
            )
        }
    }
}

/// Pure function of time → presentational inputs. Keeps body tiny.
private struct MagneticSnapView_PhantomPhase {
    let lean: CGSize
    let rotation: Double
    let pull: CGFloat
    let recoil: CGFloat
    let pressed: Bool

    init(time t: TimeInterval, metrics m: MagneticSnapView_Metrics) {
        let period: Double = 3.2
        let local: Double = t.truncatingRemainder(dividingBy: period) / period // 0...1

        // Snap moment near the end of the approach.
        let snapAt: Double = 0.55
        let pressed: Bool = local >= snapAt && local < (snapAt + 0.32)

        // Phantom finger sweeps from far edge (local 0) to center (snap) and out.
        let phantom: CGPoint = MagneticSnapView_PhantomPhase.phantomPoint(local: local, snapAt: snapAt, metrics: m)
        let model = MagneticSnapView_Attraction.lean(from: phantom, metrics: m)

        // Recoil envelope: damped sine starting at the snap, so the overshoot
        // and settle are visibly bouncy (signature moment) without haptics.
        let recoil: CGFloat = MagneticSnapView_PhantomPhase.recoilEnvelope(local: local, snapAt: snapAt)

        self.lean = model.offset
        self.rotation = model.rotation
        self.pull = model.pull
        self.recoil = recoil
        self.pressed = pressed
    }

    private static func phantomPoint(local: Double, snapAt: Double, metrics m: MagneticSnapView_Metrics) -> CGPoint {
        if local < snapAt {
            // Ease the finger in from the left edge toward the center.
            let p: Double = local / snapAt
            let eased: Double = p * p * (3 - 2 * p) // smoothstep
            let startX: CGFloat = m.size.width * 0.04
            let x: CGFloat = startX + (m.center.x - startX) * CGFloat(eased)
            let y: CGFloat = m.center.y + sin(CGFloat(local) * 6) * m.size.height * 0.10
            return CGPoint(x: x, y: y)
        } else {
            // After snap, glide back out to the edge.
            let p: Double = min((local - snapAt) / (1 - snapAt), 1)
            let eased: Double = p * p
            let endX: CGFloat = m.size.width * 0.96
            let x: CGFloat = m.center.x + (endX - m.center.x) * CGFloat(eased)
            let y: CGFloat = m.center.y - sin(CGFloat(local) * 5) * m.size.height * 0.08
            return CGPoint(x: x, y: y)
        }
    }

    private static func recoilEnvelope(local: Double, snapAt: Double) -> CGFloat {
        guard local >= snapAt else { return 0 }
        let dt: Double = local - snapAt
        let decay: Double = exp(-dt * 9.0)
        let wobble: Double = cos(dt * 38.0)
        let value: Double = decay * wobble
        return CGFloat(max(value, 0))
    }
}

// MARK: - Interactive driver — real DragGesture over the whole tile

private struct MagneticSnapView_InteractiveDriver: View {
    let metrics: MagneticSnapView_Metrics

    @State private var location: CGPoint? = nil
    @State private var pressed: Bool = false
    @State private var recoil: CGFloat = 0
    @State private var snapCount: Int = 0

    var body: some View {
        let model = currentModel()
        return MagneticSnapView_MagneticButton(
            metrics: metrics,
            lean: model.offset,
            rotation: model.rotation,
            pull: model.pull,
            recoil: recoil,
            pressed: pressed
        )
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .gesture(dragGesture)
        // Haptic ONLY in interactive mode, fired on snap.
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.9), trigger: snapCount)
    }

    private func currentModel() -> (offset: CGSize, rotation: Double, pull: CGFloat) {
        guard let loc = location else {
            return (.zero, 0, 0)
        }
        return MagneticSnapView_Attraction.lean(from: loc, metrics: metrics)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                location = value.location
                if pressed == false { pressed = true }
            }
            .onEnded { _ in
                // Snap-lock recoil on release.
                snapCount += 1
                location = nil
                withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) {
                    pressed = false
                }
                fireRecoil()
            }
    }

    private func fireRecoil() {
        // Seed the recoil at full amplitude, then defer the spring-to-rest to the
        // next runloop tick. Without the defer, SwiftUI coalesces both writes
        // before the next body eval (1 → 0) and the wobble never renders.
        recoil = 1
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.42)) {
                recoil = 0
            }
        }
    }
}
