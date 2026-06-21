// catalog-id: bg-conic-prism
import SwiftUI

// MARK: - Conic Prism
// A full-bleed conic (angular) gradient with HARD discrete color stops spins
// slowly like a color wheel, while a second counter-rotating banded conic with
// a different band count and palette is composited via a blend mode to throw off
// shifting moire pinwheel spokes. Pure SwiftUI gradients + a TimelineView clock.
//
// Interaction == "auto": both `demo == true` and `demo == false` resolve to the
// same self-driving loop. There is no touch wiring for this background.
//
// Design notes (corner-gap & blank-frame safe):
//  * The wheels spin by advancing each AngularGradient's *angle* (startAngle /
//    endAngle), NOT via rotationEffect on the rectangle — so corners are never
//    swept into black triangular gaps.
//  * The two layers are deliberately DIFFERENT (band counts 6 vs 8, distinct
//    palettes, counter-rotation) so a `.difference` blend can never make the two
//    globally coincide into a flat black frame.
//  * An opaque base fill sits behind the pair and the pair is isolated with
//    `.compositingGroup()`, so the darkest possible frame still reads as legible
//    crisp spokes — never fully blank or zero-opacity.

struct ConicPrismView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                content(in: geo.size, time: t)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    // MARK: Composition

    private func content(in size: CGSize, time t: TimeInterval) -> some View {
        // Counter-rotating angles. The wheels spin at slightly different rates so
        // the moire beat between them is itself in slow motion.
        let theta: Double = (t * 14.0).truncatingRemainder(dividingBy: 360.0)
        let counter: Double = (-t * 9.0).truncatingRemainder(dividingBy: 360.0)

        // A gentle breathing on the blend layer's opacity keeps the spokes alive
        // and shimmering, and guarantees the top layer never collapses to nothing.
        let breathe: Double = 0.78 + 0.18 * sin(t * 0.9)

        return ZStack {
            // Opaque base so the difference blend always has a floor to read against.
            baseFill

            ZStack {
                ConicPrismView_PrismWheel(
                    stops: Self.primaryStops,
                    angle: theta,
                    center: Self.lowerCenter
                )

                ConicPrismView_PrismWheel(
                    stops: Self.secondaryStops,
                    angle: counter,
                    center: Self.upperCenter
                )
                .blendMode(.difference)
                .opacity(breathe)
            }
            .compositingGroup()

            // A faint third banded ring, additively screened, sharpens the
            // pinwheel "vinyl record" identity and adds a moving highlight.
            ConicPrismView_PrismWheel(
                stops: Self.accentStops,
                angle: theta * 0.6 + 45.0,
                center: Self.center
            )
            .blendMode(.screen)
            .opacity(0.22)

            // Subtle vignette to seat the wheel and lift the center spokes.
            vignette(in: size)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: Static pieces

    private var baseFill: some View {
        Color(red: 0.039, green: 0.039, blue: 0.047)
    }

    // Size-relative vignette so it reads the same in a 120pt tile and a large
    // detail view (a fixed pixel radius would vanish small / overwhelm large).
    private func vignette(in size: CGSize) -> some View {
        let radius: CGFloat = max(size.width, size.height) * 0.75
        return RadialGradient(
            gradient: Gradient(colors: [
                Color(red: 0, green: 0, blue: 0).opacity(0.0),
                Color(red: 0, green: 0, blue: 0).opacity(0.45)
            ]),
            center: .center,
            startRadius: 0,
            endRadius: radius
        )
        .blendMode(.multiply)
        .allowsHitTesting(false)
    }

    // Centers offset a touch so the two wheels' spoke patterns interfere off-axis
    // (a single shared center reads more like simple rotation than moire).
    private static let center = UnitPoint(x: 0.5, y: 0.5)
    private static let lowerCenter = UnitPoint(x: 0.42, y: 0.56)
    private static let upperCenter = UnitPoint(x: 0.58, y: 0.44)

    // MARK: Hard-stop palettes
    // Crisp bands come from DUPLICATING each stop's color at the band boundary
    // (two stops sharing the same location) so the gradient has zero blend ramp.

    /// 6 bands — saturated prism spokes.
    static let primaryStops: [Gradient.Stop] = hardStops([
        Color(red: 0.98, green: 0.27, blue: 0.45),
        Color(red: 0.99, green: 0.66, blue: 0.20),
        Color(red: 0.96, green: 0.92, blue: 0.30),
        Color(red: 0.24, green: 0.82, blue: 0.55),
        Color(red: 0.22, green: 0.55, blue: 0.98),
        Color(red: 0.62, green: 0.34, blue: 0.95)
    ])

    /// 8 bands — a different count & palette so the layers can never coincide.
    static let secondaryStops: [Gradient.Stop] = hardStops([
        Color(red: 0.10, green: 0.78, blue: 0.86),
        Color(red: 0.14, green: 0.30, blue: 0.70),
        Color(red: 0.86, green: 0.20, blue: 0.62),
        Color(red: 0.97, green: 0.45, blue: 0.18),
        Color(red: 0.20, green: 0.84, blue: 0.46),
        Color(red: 0.55, green: 0.18, blue: 0.88),
        Color(red: 0.93, green: 0.84, blue: 0.22),
        Color(red: 0.18, green: 0.62, blue: 0.92)
    ])

    /// 5 narrow accent bands for the screened highlight ring.
    static let accentStops: [Gradient.Stop] = hardStops([
        Color(red: 1.00, green: 1.00, blue: 1.00),
        Color(red: 0.10, green: 0.10, blue: 0.14),
        Color(red: 0.85, green: 0.90, blue: 1.00),
        Color(red: 0.08, green: 0.08, blue: 0.10),
        Color(red: 0.70, green: 0.95, blue: 0.90)
    ])

    /// Builds crisp, equal-width bands by emitting two stops per color at the
    /// band's leading and trailing location (no soft blend between bands).
    private static func hardStops(_ colors: [Color]) -> [Gradient.Stop] {
        guard !colors.isEmpty else { return [] }
        let n = colors.count
        var stops: [Gradient.Stop] = []
        stops.reserveCapacity(n * 2)
        for (i, color) in colors.enumerated() {
            let start = Double(i) / Double(n)
            let end = Double(i + 1) / Double(n)
            stops.append(.init(color: color, location: start))
            stops.append(.init(color: color, location: end))
        }
        return stops
    }
}

// MARK: - ConicPrismView_PrismWheel
// A single full-bleed banded conic gradient that "spins" purely by advancing its
// start/end angle. Because the gradient fills the whole rect (no geometry
// rotation), corners are always covered — no black gaps as it turns.

private struct ConicPrismView_PrismWheel: View {
    let stops: [Gradient.Stop]
    let angle: Double
    let center: UnitPoint

    var body: some View {
        Rectangle()
            .fill(
                AngularGradient(
                    gradient: Gradient(stops: stops),
                    center: center,
                    startAngle: .degrees(angle),
                    endAngle: .degrees(angle + 360.0)
                )
            )
            // Overscale slightly so the off-center conic still fully bleeds the
            // rect from its shifted pivot.
            .scaleEffect(1.35)
    }
}
