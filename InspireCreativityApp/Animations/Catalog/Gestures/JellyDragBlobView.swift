// catalog-id: ges-jelly-drag-blob
import SwiftUI

// MARK: - Jelly Drag Blob
// Drag a soft blob: its trailing edge lags into a teardrop tip while the
// leading edge bulges; release lets it wobble back round like gelatin.
// The deformation lives in the Shape's animatableData so the release spring
// actually re-evaluates the silhouette each frame (that IS the jiggle).

struct JellyDragBlobView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let size: CGSize = proxy.size
            ZStack {
                JellyBackground()
                if demo {
                    DemoBlob(size: size)
                } else {
                    InteractiveBlob(size: size)
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Shared stretch clamp helper

// Caps the stretch vector magnitude so fast drags can't blow up the silhouette.
private func clampStretch(_ v: CGVector, baseRadius: CGFloat) -> CGVector {
    let mag: CGFloat = hypot(v.dx, v.dy)
    let cap: CGFloat = baseRadius * 1.2
    guard mag > cap, mag > 0 else { return v }
    let scale: CGFloat = cap / mag
    return CGVector(dx: v.dx * scale, dy: v.dy * scale)
}

// MARK: - Background

private struct JellyBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.09),
                Color(red: 0.10, green: 0.09, blue: 0.16)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Demo (self-driving) variant

private struct DemoBlob: View {
    let size: CGSize

    // ~3.2s loop. Speed eases via sin^2 so the blob stretches while moving
    // and rounds out at the slow points of the orbit — "wobbles round when it pauses".
    private let period: Double = 3.2

    var body: some View {
        TimelineView(.animation) { context in
            let t: Double = context.date.timeIntervalSinceReferenceDate
            let phase: Double = (t.truncatingRemainder(dividingBy: period)) / period
            let state = orbitState(phase: phase)
            BlobBody(
                center: state.center,
                stretch: state.stretch,
                baseRadius: baseRadius
            )
        }
    }

    private var baseRadius: CGFloat {
        min(size.width, size.height) * 0.26
    }

    private var orbitCenter: CGPoint {
        CGPoint(x: size.width / 2, y: size.height / 2)
    }

    private func orbitState(phase: Double) -> (center: CGPoint, stretch: CGVector) {
        // Eased angular progress: fast through the middle, slow at the ends.
        let eased: Double = phase - (sin(2 * .pi * phase) / (2 * .pi))
        let angle: Double = eased * 2 * .pi

        let orbitR: CGFloat = baseRadius * 0.55
        let cx: CGFloat = orbitCenter.x + orbitR * CGFloat(cos(angle))
        let cy: CGFloat = orbitCenter.y + orbitR * CGFloat(sin(angle) * 0.7)
        let center = CGPoint(x: cx, y: cy)

        // Analytic tangential velocity of the eased orbit drives the stretch.
        let speed: Double = pow(sin(.pi * phase), 2) // 0 at ends, 1 mid-loop
        let vScale: CGFloat = baseRadius * 1.1
        let dx: CGFloat = -CGFloat(sin(angle)) * vScale * CGFloat(speed)
        let dy: CGFloat = CGFloat(cos(angle)) * 0.7 * vScale * CGFloat(speed)

        return (center, clampStretch(CGVector(dx: dx, dy: dy), baseRadius: baseRadius))
    }
}

// MARK: - Interactive variant

private struct InteractiveBlob: View {
    let size: CGSize

    @State private var center: CGPoint = .zero
    @State private var stretch: CGVector = .zero
    @State private var didPlace: Bool = false

    var body: some View {
        BlobBody(center: resolvedCenter, stretch: stretch, baseRadius: baseRadius)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .onAppear { placeIfNeeded() }
    }

    private var baseRadius: CGFloat {
        min(size.width, size.height) * 0.26
    }

    private var home: CGPoint {
        CGPoint(x: size.width / 2, y: size.height / 2)
    }

    private var resolvedCenter: CGPoint {
        didPlace ? center : home
    }

    private func placeIfNeeded() {
        guard !didPlace else { return }
        center = home
        didPlace = true
    }

    private var dragGesture: some Gesture {
        // minimumDistance: 0 so the blob wins inside a ScrollView.
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                placeIfNeeded()
                // Track the finger 1:1 (no animation) for a live, tactile feel.
                center = CGPoint(
                    x: home.x + value.translation.width,
                    y: home.y + value.translation.height
                )
                // Derive a velocity-like vector from predictedEndTranslation
                // (iOS 17 safe) and feed it into the live stretch.
                let raw: CGVector = predictedVelocity(value)
                stretch = clampStretch(scaledVelocity(raw), baseRadius: baseRadius)
            }
            .onEnded { _ in
                // One spring drives BOTH the silhouette wobble (animatableData)
                // and the glide home — overshooting through round.
                withAnimation(.interpolatingSpring(stiffness: 170, damping: 12)) {
                    stretch = .zero
                    center = home
                }
            }
    }

    // predictedEndTranslation - translation approximates the throw direction
    // and magnitude using only APIs guaranteed on iOS 17.
    private func predictedVelocity(_ value: DragGesture.Value) -> CGVector {
        let pred: CGSize = value.predictedEndTranslation
        return CGVector(
            dx: pred.width - value.translation.width,
            dy: pred.height - value.translation.height
        )
    }

    private func scaledVelocity(_ v: CGVector) -> CGVector {
        // Compress the predicted delta into a stretch-sized vector.
        let k: CGFloat = 2.0
        return CGVector(dx: v.dx * k, dy: v.dy * k)
    }
}

// MARK: - Shared blob body (fill + specular highlight)

private struct BlobBody: View {
    let center: CGPoint
    let stretch: CGVector
    let baseRadius: CGFloat

    var body: some View {
        ZStack {
            shape
                .fill(bodyGradient)
                .overlay(rim)
                .overlay(specular)
                .shadow(color: Color(red: 0.30, green: 0.55, blue: 0.95).opacity(0.35),
                        radius: 14, x: 0, y: 8)
        }
    }

    private var shape: JellyDragBlobView_BlobShape {
        JellyDragBlobView_BlobShape(center: center, stretch: stretch, baseRadius: baseRadius)
    }

    private var bodyGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.45, green: 0.78, blue: 1.00),
                Color(red: 0.30, green: 0.50, blue: 0.96),
                Color(red: 0.42, green: 0.30, blue: 0.92)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var rim: some View {
        shape.stroke(Color.white.opacity(0.18), lineWidth: 1.0)
    }

    // A small clipped specular highlight sells the gelatin sheen.
    private var specular: some View {
        let r: CGFloat = baseRadius
        return Ellipse()
            .fill(
                RadialGradient(
                    colors: [Color.white.opacity(0.55), Color.white.opacity(0.0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: r * 0.6
                )
            )
            .frame(width: r * 0.9, height: r * 0.6)
            .position(x: center.x - r * 0.28, y: center.y - r * 0.34)
            .clipShape(shape)
            .allowsHitTesting(false)
    }
}

// MARK: - Animatable teardrop shape

private struct JellyDragBlobView_BlobShape: Shape {
    var center: CGPoint
    var stretch: CGVector
    var baseRadius: CGFloat

    // Expose the stretch (and center) through animatableData so the release
    // spring re-evaluates path(in:) every frame — without this the wobble dies.
    var animatableData: AnimatablePair<
        AnimatablePair<CGFloat, CGFloat>,
        AnimatablePair<CGFloat, CGFloat>
    > {
        get {
            AnimatablePair(
                AnimatablePair(stretch.dx, stretch.dy),
                AnimatablePair(center.x, center.y)
            )
        }
        set {
            stretch = CGVector(dx: newValue.first.first, dy: newValue.first.second)
            center = CGPoint(x: newValue.second.first, y: newValue.second.second)
        }
    }

    func path(in rect: CGRect) -> Path {
        let mag: CGFloat = hypot(stretch.dx, stretch.dy)

        // Near-rest: clean circle (avoids divide-by-zero on direction).
        guard mag > 0.5 else {
            let d: CGFloat = baseRadius * 2
            let origin = CGPoint(x: center.x - baseRadius, y: center.y - baseRadius)
            return Path(ellipseIn: CGRect(origin: origin, size: CGSize(width: d, height: d)))
        }

        let dirX: CGFloat = stretch.dx / mag
        let dirY: CGFloat = stretch.dy / mag
        let motionAngle: Double = atan2(Double(dirY), Double(dirX))

        // Deform amount in [0, 0.85] of baseRadius.
        let cap: CGFloat = baseRadius * 0.85
        let deform: CGFloat = min(mag, cap) / baseRadius

        return teardropPath(motionAngle: motionAngle, deform: deform)
    }

    private func teardropPath(motionAngle: Double, deform: CGFloat) -> Path {
        var path = Path()
        let samples: Int = 60
        let twoPi: Double = 2 * .pi

        for i in 0...samples {
            let theta: Double = (Double(i) / Double(samples)) * twoPi
            let radius: CGFloat = radiusAt(theta: theta, motionAngle: motionAngle, deform: deform)
            let px: CGFloat = center.x + radius * CGFloat(cos(theta))
            let py: CGFloat = center.y + radius * CGFloat(sin(theta))
            let point = CGPoint(x: px, y: py)
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    // Asymmetric radial profile: leading pole bulges, trailing pole pulls into a tip.
    private func radiusAt(theta: Double, motionAngle: Double, deform: CGFloat) -> CGFloat {
        // cos(theta - motionAngle): +1 at leading pole, -1 at trailing pole.
        let lead: CGFloat = CGFloat(cos(theta - motionAngle))

        // Leading side bulges outward (positive lead), trailing side flattens then
        // spikes into a teardrop tip. Cubic term sharpens the trailing tip.
        let bulge: CGFloat = lead * deform * 0.55
        let trailingTip: CGFloat = max(0, -lead) // 0..1 on the trailing half
        let tip: CGFloat = pow(trailingTip, 2.0) * deform * 0.95

        // Slight lateral squash keeps volume believable on fast drags.
        let squash: CGFloat = (1 - abs(lead)) * deform * 0.18

        let factor: CGFloat = 1.0 + bulge + tip - squash
        return baseRadius * max(0.35, factor)
    }
}
