// catalog-id: nav-orbital-satellite-menu
import SwiftUI

// MARK: - Orbital OrbitalSatelliteMenuView_Satellite Menu
//
// Action icons orbit a central hub. Drag the ring to rotate it; whichever
// satellite reaches the top "focus" slot enlarges. A flick coasts with
// momentum and snaps to the nearest detent.
//
//  • demo == true  -> closed-form auto-orbit (pure function of time, no
//                     stored integrator state) that eases between detents
//                     on a loop so the tile is always alive and legible.
//  • demo == false -> real RotationGesture-style DragGesture wiring: atan2
//                     deltas accumulate into an unwrapped ring angle, and
//                     release projects a resting angle from the measured
//                     angular velocity, snaps it to the nearest detent, and
//                     settles with a plain spring (no terminal jitter).

struct OrbitalSatelliteMenuView: View {
    var demo: Bool = false

    // The current ring rotation, kept UNWRAPPED (never folded into
    // (-pi, pi]) so the spring can animate smoothly across the atan2 seam.
    @State private var ringAngle: Double = 0

    // Drag bookkeeping for measuring angular velocity at release.
    @State private var lastTouchAngle: Double = 0
    @State private var lastAngle: Double = 0          // ring angle snapshot
    @State private var lastDate: Date = .distantPast
    @State private var angularVelocity: Double = 0    // rad / s
    @State private var isDragging: Bool = false

    // The item currently sitting in the focus slot (drives haptic ticks).
    @State private var focusedIndex: Int = 0

    private let items: [OrbitalSatelliteMenuView_Satellite] = OrbitalSatelliteMenuView_Satellite.demoSet

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let metrics = OrbitalSatelliteMenuView_Metrics(side: side)

            ZStack {
                backdrop(side: side)
                orbitRing(radius: metrics.orbitRadius, lineWidth: metrics.ringWidth)
                focusHalo(center: center, metrics: metrics)

                if demo {
                    demoContent(center: center, metrics: metrics)
                } else {
                    interactiveContent(center: center, metrics: metrics)
                }

                hub(metrics: metrics)
                    .position(center)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .gesture(rotationDrag(center: center), including: demo ? .none : .all)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.selection, trigger: demo ? -1 : focusedIndex)
    }

    // MARK: Demo (self-driving, closed form)

    @ViewBuilder
    private func demoContent(center: CGPoint, metrics: OrbitalSatelliteMenuView_Metrics) -> some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let angle = Self.demoAngle(at: t, step: step)
            satelliteField(ringAngle: angle, center: center, metrics: metrics)
                .onChange(of: nearestIndex(for: angle)) { _, newValue in
                    focusedIndex = newValue
                }
        }
    }

    // MARK: Interactive

    @ViewBuilder
    private func interactiveContent(center: CGPoint, metrics: OrbitalSatelliteMenuView_Metrics) -> some View {
        satelliteField(ringAngle: ringAngle, center: center, metrics: metrics)
            .onChange(of: nearestIndex(for: ringAngle)) { _, newValue in
                focusedIndex = newValue
            }
    }

    // MARK: OrbitalSatelliteMenuView_Satellite layout

    /// Lays out every satellite at its polar angle around the hub and
    /// applies a smooth focus falloff so the item nearest the top slot grows.
    @ViewBuilder
    private func satelliteField(ringAngle: Double, center: CGPoint, metrics: OrbitalSatelliteMenuView_Metrics) -> some View {
        ZStack {
            ForEach(items.indices, id: \.self) { index in
                let placement = placement(for: index, ringAngle: ringAngle, metrics: metrics)
                satelliteView(items[index], emphasis: placement.emphasis, metrics: metrics)
                    .position(x: center.x + placement.offset.width,
                              y: center.y + placement.offset.height)
                    .zIndex(placement.emphasis)
            }
        }
    }

    private func satelliteView(_ item: OrbitalSatelliteMenuView_Satellite, emphasis: Double, metrics: OrbitalSatelliteMenuView_Metrics) -> some View {
        let scale = 0.82 + emphasis * 0.62
        let dotSize = metrics.satelliteSize
        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            item.tint.opacity(0.95),
                            item.tint.opacity(0.45 + emphasis * 0.4)
                        ],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: dotSize
                    )
                )
                .overlay(
                    Circle().strokeBorder(Color(red: 1, green: 1, blue: 1).opacity(0.18 + emphasis * 0.3), lineWidth: 1)
                )
                .shadow(color: item.tint.opacity(0.5 * emphasis),
                        radius: 8 * emphasis, x: 0, y: 0)
            Image(systemName: item.symbol)
                .font(.system(size: dotSize * 0.42, weight: .semibold))
                .foregroundStyle(Color(red: 1, green: 1, blue: 1).opacity(0.6 + emphasis * 0.4))
        }
        .frame(width: dotSize, height: dotSize)
        .scaleEffect(scale)
        .opacity(0.55 + emphasis * 0.45)
    }

    // MARK: Hub & decoration

    private func hub(metrics: OrbitalSatelliteMenuView_Metrics) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.28, green: 0.32, blue: 0.42),
                            Color(red: 0.10, green: 0.12, blue: 0.18)
                        ],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: metrics.hubSize
                    )
                )
            Circle()
                .strokeBorder(Color(red: 1, green: 1, blue: 1).opacity(0.22), lineWidth: 1)
            Image(systemName: "circle.grid.cross.fill")
                .font(.system(size: metrics.hubSize * 0.4, weight: .medium))
                .foregroundStyle(Color(red: 0.62, green: 0.78, blue: 1.0))
        }
        .frame(width: metrics.hubSize, height: metrics.hubSize)
        .shadow(color: Color(red: 0.0, green: 0.0, blue: 0.0).opacity(0.4), radius: 6, x: 0, y: 3)
    }

    private func orbitRing(radius: CGFloat, lineWidth: CGFloat) -> some View {
        Circle()
            .strokeBorder(
                Color(red: 1, green: 1, blue: 1).opacity(0.10),
                style: StrokeStyle(lineWidth: lineWidth, dash: [2, 6])
            )
            .frame(width: radius * 2, height: radius * 2)
    }

    /// A soft glow marking the top-of-ring focus slot.
    private func focusHalo(center: CGPoint, metrics: OrbitalSatelliteMenuView_Metrics) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 0.55, green: 0.74, blue: 1.0).opacity(0.35),
                        Color(red: 0.55, green: 0.74, blue: 1.0).opacity(0.0)
                    ],
                    center: .center,
                    startRadius: 1,
                    endRadius: metrics.satelliteSize * 1.3
                )
            )
            .frame(width: metrics.satelliteSize * 2.6, height: metrics.satelliteSize * 2.6)
            .position(x: center.x, y: center.y - metrics.orbitRadius)
    }

    private func backdrop(side: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: side * 0.10, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.08, blue: 0.12),
                        Color(red: 0.04, green: 0.05, blue: 0.08)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    // MARK: Gesture

    private func rotationDrag(center: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let now = Date()
                let touchAngle = atan2(Double(value.location.y - center.y),
                                       Double(value.location.x - center.x))
                if !isDragging {
                    // First sample of this drag — seed, don't rotate.
                    isDragging = true
                    lastTouchAngle = touchAngle
                    lastAngle = ringAngle
                    lastDate = now
                    angularVelocity = 0
                    return
                }

                // Normalize the DELTA into (-pi, pi] (never wrap ringAngle).
                var delta = touchAngle - lastTouchAngle
                delta = Self.normalizeDelta(delta)
                ringAngle += delta
                lastTouchAngle = touchAngle

                // Measure instantaneous angular velocity (rad/s).
                let dt = now.timeIntervalSince(lastDate)
                if dt > 0.0001 {
                    let measured = (ringAngle - lastAngle) / dt
                    // Light smoothing keeps the release reading stable.
                    angularVelocity = angularVelocity * 0.4 + measured * 0.6
                    lastAngle = ringAngle
                    lastDate = now
                }
            }
            .onEnded { _ in
                isDragging = false
                // Project a resting angle from momentum, then snap to the
                // nearest detent and settle with a plain spring (no jitter).
                let friction: Double = 3.2
                let projected = ringAngle + angularVelocity / friction
                let target = Self.snappedAngle(projected, step: step)
                angularVelocity = 0
                withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                    ringAngle = target
                }
            }
    }

    // MARK: Placement maths

    private var step: Double { (2 * Double.pi) / Double(items.count) }

    struct Placement {
        var offset: CGSize
        var emphasis: Double   // 0…1, 1 == perfectly in the focus slot
    }

    /// Item `i` is anchored at `-pi/2 + i*step` (top of ring = focus slot)
    /// and then rotated by the live `ringAngle`.
    private func placement(for index: Int, ringAngle: Double, metrics: OrbitalSatelliteMenuView_Metrics) -> Placement {
        let base = -Double.pi / 2 + Double(index) * step
        let angle = base + ringAngle
        let x = cos(angle) * Double(metrics.orbitRadius)
        let y = sin(angle) * Double(metrics.orbitRadius)

        // Angular distance from the focus slot (top, -pi/2).
        let toFocus = Self.normalizeDelta(angle - (-Double.pi / 2))
        let dist = abs(toFocus)
        // Smooth falloff: 1 at the slot, easing to 0 within ~one step.
        let span = step
        let raw = max(0, 1 - dist / span)
        let emphasis = raw * raw * (3 - 2 * raw) // smoothstep

        return Placement(offset: CGSize(width: x, height: y), emphasis: emphasis)
    }

    private func nearestIndex(for ringAngle: Double) -> Int {
        // Which item is closest to the focus slot for the given rotation.
        var best = 0
        var bestDist = Double.greatestFiniteMagnitude
        for index in items.indices {
            let base = -Double.pi / 2 + Double(index) * step
            let angle = base + ringAngle
            let d = abs(Self.normalizeDelta(angle - (-Double.pi / 2)))
            if d < bestDist {
                bestDist = d
                best = index
            }
        }
        return best
    }

    // MARK: Static helpers (pure, no state — safe to call from anywhere)

    /// Closed-form demo angle: eases between detents with a decelerating
    /// curve on a loop, mimicking flick-coast-snap with no integrator state.
    static func demoAngle(at time: TimeInterval, step: Double) -> Double {
        let period: Double = 3.4
        let phase = time.truncatingRemainder(dividingBy: period) / period // 0…1
        // Cycle index advances each period so the ring keeps progressing.
        let cycle = floor(time / period)
        // Move 2 detents per period for a lively spin.
        let perCycle = step * 2
        let startAngle = -cycle * perCycle
        // easeOut: fast start, decelerating into the detent (coast feel).
        let eased = 1 - pow(1 - phase, 3)
        return startAngle - eased * perCycle
    }

    /// Normalize an angle delta into (-pi, pi].
    static func normalizeDelta(_ value: Double) -> Double {
        var d = value.truncatingRemainder(dividingBy: 2 * Double.pi)
        if d > Double.pi { d -= 2 * Double.pi }
        if d <= -Double.pi { d += 2 * Double.pi }
        return d
    }

    /// Snap an (unwrapped) ring angle to the nearest detent, preserving the
    /// unwrapped magnitude so the spring animates over the shortest path.
    static func snappedAngle(_ angle: Double, step: Double) -> Double {
        (angle / step).rounded() * step
    }
}

// MARK: - Model

private struct OrbitalSatelliteMenuView_Satellite: Identifiable {
    let id = UUID()
    let symbol: String
    let tint: Color

    static let demoSet: [OrbitalSatelliteMenuView_Satellite] = [
        OrbitalSatelliteMenuView_Satellite(symbol: "house.fill",        tint: Color(red: 0.36, green: 0.70, blue: 1.00)),
        OrbitalSatelliteMenuView_Satellite(symbol: "magnifyingglass",   tint: Color(red: 0.55, green: 0.84, blue: 0.62)),
        OrbitalSatelliteMenuView_Satellite(symbol: "heart.fill",        tint: Color(red: 1.00, green: 0.46, blue: 0.55)),
        OrbitalSatelliteMenuView_Satellite(symbol: "bell.fill",         tint: Color(red: 1.00, green: 0.78, blue: 0.38)),
        OrbitalSatelliteMenuView_Satellite(symbol: "bookmark.fill",     tint: Color(red: 0.74, green: 0.58, blue: 1.00)),
        OrbitalSatelliteMenuView_Satellite(symbol: "gearshape.fill",    tint: Color(red: 0.55, green: 0.82, blue: 0.95))
    ]
}

// MARK: - OrbitalSatelliteMenuView_Metrics

private struct OrbitalSatelliteMenuView_Metrics {
    let side: CGFloat
    var orbitRadius: CGFloat { side * 0.34 }
    var satelliteSize: CGFloat { side * 0.18 }
    var hubSize: CGFloat { side * 0.22 }
    var ringWidth: CGFloat { max(1, side * 0.006) }
}
