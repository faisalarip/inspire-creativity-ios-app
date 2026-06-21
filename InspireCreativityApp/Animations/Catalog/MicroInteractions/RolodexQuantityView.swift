// catalog-id: mi-rolodex-quantity
import SwiftUI

// Rolodex Quantity — a vertical cylinder of numbers you can fling.
// Each row is offset + rotated about the X axis and faded by its angular
// distance from center to fake a curved 3D drum. A flick seeds a
// friction-decayed offset (a dt-based integrator stepped inside
// .onChange(of: context.date)) that coasts and springs to a snapped value.
struct RolodexQuantityView: View {
    var demo: Bool = false

    // Inclusive value range shown on the drum.
    private let minValue: Int = 0
    private let maxValue: Int = 99

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                background(size: size)
                if demo {
                    RolodexQuantityView_DemoDrum(size: size,
                             minValue: minValue,
                             maxValue: maxValue,
                             render: { offset in
                                 drum(offset: offset, size: size)
                             })
                } else {
                    RolodexQuantityView_InteractiveDrum(size: size,
                                    minValue: minValue,
                                    maxValue: maxValue,
                                    render: { offset in
                                        drum(offset: offset, size: size)
                                    })
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Derived metrics (all relative to the tile size)

    private func metrics(_ size: CGSize) -> (rowPitch: CGFloat, font: CGFloat, radius: CGFloat) {
        let dim = min(size.width, size.height)
        let pitch = max(dim * 0.26, 16)
        let font = max(dim * 0.30, 17)
        let radius = max(dim * 0.42, 22)
        return (pitch, font, radius)
    }

    // MARK: - Pure renderer: continuous offset -> 3D number column

    @ViewBuilder
    private func drum(offset: Double, size: CGSize) -> some View {
        let m = metrics(size)
        let center = Int(offset.rounded())
        // How many rows above/below center to draw (cull past ~90°).
        let span = 4
        ZStack {
            ForEach(-span...span, id: \.self) { delta in
                let value = center + delta
                if value >= minValue && value <= maxValue {
                    numberRow(value: value,
                              offset: offset,
                              metrics: m,
                              size: size)
                }
            }
            sheen(size: size, metrics: m)
            selectionFrame(size: size, metrics: m)
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func numberRow(value: Int,
                           offset: Double,
                           metrics m: (rowPitch: CGFloat, font: CGFloat, radius: CGFloat),
                           size: CGSize) -> some View {
        // Distance (in row units) of this value from the centered offset.
        let rel: CGFloat = CGFloat(Double(value) - offset)
        // Angle on the cylinder; clamp so projection never folds past the rim.
        let rawAngle: CGFloat = rel * 40.0
        let angle: CGFloat = max(-92, min(92, rawAngle))
        let rad = angle * .pi / 180
        // Project onto the drum: vertical position follows sin, depth follows cos.
        let yPos = sin(rad) * m.radius
        let depth = cos(rad)
        let opacity = max(0.0, Double(depth)) * 0.9 + 0.1
        let scale = 0.55 + 0.45 * max(0.0, depth)

        Text("\(value)")
            .font(.system(size: m.font, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(numberColor(depth: depth))
            .scaleEffect(scale)
            .rotation3DEffect(.degrees(Double(angle)),
                              axis: (x: 1, y: 0, z: 0),
                              anchor: .center,
                              perspective: 0.6)
            .opacity(opacity)
            .offset(y: yPos)
    }

    private func numberColor(depth: CGFloat) -> Color {
        // Center reads brightest; rim rows fade toward a dim slate.
        let t = max(0.0, min(1.0, Double(depth)))
        let r = 0.55 + 0.40 * t
        let g = 0.58 + 0.40 * t
        let b = 0.66 + 0.32 * t
        return Color(red: r, green: g, blue: b)
    }

    // MARK: - Chrome

    private func background(size: CGSize) -> some View {
        let dim = min(size.width, size.height)
        return RoundedRectangle(cornerRadius: dim * 0.16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.09, green: 0.10, blue: 0.14),
                        Color(red: 0.05, green: 0.06, blue: 0.09)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: dim * 0.16, style: .continuous)
                    .strokeBorder(Color(red: 1, green: 1, blue: 1).opacity(0.05),
                                  lineWidth: 1)
            )
            .padding(dim * 0.04)
    }

    // Top + bottom fade so numbers dissolve into the drum edges.
    private func sheen(size: CGSize, metrics m: (rowPitch: CGFloat, font: CGFloat, radius: CGFloat)) -> some View {
        let dim = min(size.width, size.height)
        return RoundedRectangle(cornerRadius: dim * 0.16, style: .continuous)
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.05, green: 0.06, blue: 0.09).opacity(0.9), location: 0.0),
                        .init(color: .clear, location: 0.30),
                        .init(color: .clear, location: 0.70),
                        .init(color: Color(red: 0.05, green: 0.06, blue: 0.09).opacity(0.9), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .padding(dim * 0.04)
            .allowsHitTesting(false)
    }

    // Center selection band that frames the snapped value.
    private func selectionFrame(size: CGSize, metrics m: (rowPitch: CGFloat, font: CGFloat, radius: CGFloat)) -> some View {
        let bandHeight = m.font * 1.25
        let bandWidth = min(size.width, size.height) * 0.66
        return RoundedRectangle(cornerRadius: bandHeight * 0.28, style: .continuous)
            .fill(Color(red: 0.40, green: 0.52, blue: 1.0).opacity(0.10))
            .overlay(
                RoundedRectangle(cornerRadius: bandHeight * 0.28, style: .continuous)
                    .strokeBorder(Color(red: 0.45, green: 0.58, blue: 1.0).opacity(0.35),
                                  lineWidth: 1.5)
            )
            .frame(width: bandWidth, height: bandHeight)
            .allowsHitTesting(false)
    }
}

// MARK: - Demo driver (self-driving, no @State physics)

private struct RolodexQuantityView_DemoDrum<Content: View>: View {
    let size: CGSize
    let minValue: Int
    let maxValue: Int
    let render: (Double) -> Content

    var body: some View {
        TimelineView(.animation) { context in
            render(offset(at: context.date))
        }
    }

    // Pure function of time: a ~3.4s loop that flings, coasts, eases to a
    // snapped value, holds, then flings again. Never leaves the value range.
    private func offset(at date: Date) -> Double {
        let period: Double = 3.4
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
        let span = Double(maxValue - minValue)

        // Phase 1 (0..0.55): a decelerating fling that sweeps ~14 values.
        // Phase 2 (0.55..1): hold on the snapped value with a tiny settle.
        let base: Double = 6
        let sweep: Double = 14
        let value: Double
        if t < 0.55 {
            let p = t / 0.55
            let eased = 1 - pow(1 - p, 3) // easeOutCubic = coasting feel
            value = base + sweep * eased
        } else {
            let p = (t - 0.55) / 0.45
            // Small spring-like overshoot then settle onto the integer target.
            let target = base + sweep
            let snapped = (base + sweep).rounded()
            let settle = sin(p * .pi * 2) * 0.35 * (1 - p)
            value = target * (1 - p) + snapped * p + settle
        }
        return min(Double(maxValue), max(Double(minValue), value))
    }
}

// MARK: - Interactive driver (drag + friction integrator)

private struct RolodexQuantityView_InteractiveDrum<Content: View>: View {
    let size: CGSize
    let minValue: Int
    let maxValue: Int
    let render: (Double) -> Content

    // Continuous drum position (in value units). offset == value at center.
    @State private var offset: Double = 6
    @State private var dragStartOffset: Double = 6
    @State private var velocity: Double = 0          // value-units / sec
    @State private var coasting: Bool = false
    @State private var lastTick: Date? = nil
    @State private var lastIndex: Int = 6
    @State private var hapticTrigger: Int = 0
    @State private var isDragging: Bool = false

    var body: some View {
        // Paused timeline keeps the integrator idle at rest.
        TimelineView(.animation(paused: !coasting)) { context in
            render(offset)
                .onChange(of: context.date) { _, newDate in
                    step(to: newDate)
                }
        }
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .sensoryFeedback(.selection, trigger: hapticTrigger)
        .onAppear { lastIndex = Int(offset.rounded()) }
    }

    private var pitch: CGFloat {
        max(min(size.width, size.height) * 0.26, 16)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // First event of a fresh touch: grab the drum wherever it
                // actually is (mid-coast or mid-spring-snap) so translation==0
                // maps to the current position and there is no jump.
                if !isDragging {
                    isDragging = true
                    coasting = false
                    lastTick = nil
                    velocity = 0
                    dragStartOffset = offset
                }
                // Dragging down moves to lower values; map points -> value units.
                let deltaValues = Double(-value.translation.height / pitch)
                offset = clampOffset(dragStartOffset + deltaValues)
                fireHapticIfCrossed()
            }
            .onEnded { value in
                isDragging = false
                // Predicted end gives a velocity-like fling without relying on
                // DragGesture.Value.velocity (predictedEndTranslation is iOS 13+).
                let predicted = Double(-value.predictedEndTranslation.height / pitch)
                let actual = Double(-value.translation.height / pitch)
                let fling = predicted - actual // extra distance the flick implies
                // Convert remaining fling into an initial velocity (per second).
                let v0 = fling * 3.5
                if abs(v0) < 0.6 {
                    // Degenerate / tap: snap to nearest with a spring.
                    snapToNearest()
                } else {
                    velocity = v0
                    lastTick = nil
                    coasting = true
                }
            }
    }

    // dt-based friction integrator. Framerate-independent.
    private func step(to date: Date) {
        guard coasting else { return }
        guard let last = lastTick else { lastTick = date; return }
        let dt = date.timeIntervalSince(last)
        lastTick = date
        guard dt > 0, dt < 0.25 else { return }

        let frictionPerSec: Double = 0.10 // velocity retained per second
        velocity *= pow(frictionPerSec, dt)
        offset = clampOffset(offset + velocity * dt)
        fireHapticIfCrossed()

        // Clamp at the rails: kill momentum so it can't grind the edge.
        if offset <= Double(minValue) || offset >= Double(maxValue) {
            velocity = 0
        }

        if abs(velocity) < 0.4 {
            coasting = false
            lastTick = nil
            snapToNearest()
        }
    }

    private func snapToNearest() {
        let target = Double(min(maxValue, max(minValue, Int(offset.rounded()))))
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            offset = target
        }
        dragStartOffset = target
        fireHapticIfCrossed()
    }

    private func clampOffset(_ v: Double) -> Double {
        min(Double(maxValue), max(Double(minValue), v))
    }

    private func fireHapticIfCrossed() {
        let idx = Int(offset.rounded())
        if idx != lastIndex {
            lastIndex = idx
            hapticTrigger &+= 1
        }
    }
}
