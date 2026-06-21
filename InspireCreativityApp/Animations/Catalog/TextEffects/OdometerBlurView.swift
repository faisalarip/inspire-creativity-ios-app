// catalog-id: tx-odometer-blur
import SwiftUI

// Odometer Blur — a numeric value that rolls like a mechanical odometer.
// Each digit sits on a vertical drum; the fastest-moving wheels (the low-
// order digits) pick up motion blur and a slight vertical stretch, while a
// top/bottom curvature gradient fakes the cylinder shading. Everything is
// driven deterministically from elapsed time so per-wheel velocity (and thus
// blur) is analytic rather than guessed.
//
// The spec interaction is "auto": both demo states run the same self-driving
// loop, where the value auto-increments (+137 on a ~1.2s cadence) so the
// drums keep spinning and re-settling with velocity-proportional blur.
struct OdometerBlurView: View {

    var demo: Bool = false

    // How many digit wheels to show. Fixed so layout never reflows.
    private let digitCount: Int = 5

    // Auto-roll choreography.
    private let increment: Double = 137
    private let cadence: Double = 1.2      // seconds between increments
    private let rollDuration: Double = 0.7 // seconds the roll itself takes

    var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(backgroundFill)
        }
    }

    // MARK: - Layout

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        let metrics = layoutMetrics(for: size)

        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let state = autoState(at: elapsed)

            drum(state: state, metrics: metrics)
                .frame(width: metrics.totalWidth, height: metrics.windowHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func drum(state: DrumState, metrics: LayoutMetrics) -> some View {
        HStack(spacing: metrics.wheelSpacing) {
            ForEach(0..<digitCount, id: \.self) { index in
                // place value: leftmost wheel is the highest power.
                let power = digitCount - 1 - index
                let wheel = wheelInfo(value: state.value,
                                      velocity: state.velocity,
                                      power: power)
                OdometerBlurView_DigitWheel(digit: wheel.digit,
                           frac: wheel.frac,
                           blur: wheel.blur,
                           stretch: wheel.stretch,
                           digitHeight: metrics.digitHeight,
                           fontSize: metrics.fontSize,
                           color: digitColor)
                    .frame(width: metrics.wheelWidth, height: metrics.windowHeight)
                    .clipShape(RoundedRectangle(cornerRadius: metrics.wheelCorner,
                                                style: .continuous))
                    .overlay(curvatureOverlay(corner: metrics.wheelCorner))
                    .overlay(wheelBorder(corner: metrics.wheelCorner))
            }
        }
    }

    // MARK: - Engine (deterministic, time-driven)

    struct DrumState {
        var value: Double
        var velocity: Double // units per second, on the value scale
    }

    private func autoState(at elapsed: TimeInterval) -> DrumState {
        let step = floor(elapsed / cadence)
        let local = elapsed - step * cadence
        let t = min(max(local / rollDuration, 0), 1)
        let eased = easeOut(t)
        let value = increment * step + increment * eased
        // Analytic velocity: d/dt of (increment * easeOut(local/rollDuration)).
        var velocity: Double = 0
        if local < rollDuration {
            velocity = increment * easeOutDerivative(t) / rollDuration
        }
        return DrumState(value: value, velocity: velocity)
    }

    // Easing: a cubic ease-out so the roll launches fast and settles soft.
    private func easeOut(_ t: Double) -> Double {
        let inv = 1 - t
        return 1 - inv * inv * inv
    }

    private func easeOutDerivative(_ t: Double) -> Double {
        let inv = 1 - t
        return 3 * inv * inv
    }

    // MARK: - Per-wheel resolution

    struct WheelInfo {
        var digit: Int
        var frac: Double
        var blur: CGFloat
        var stretch: CGFloat
    }

    private func wheelInfo(value: Double, velocity: Double, power: Int) -> WheelInfo {
        let scale = pow(10.0, Double(power))
        let modulus = pow(10.0, Double(digitCount))
        // Keep the displayed value within the fixed digit window.
        let wrapped = positiveMod(value, modulus)
        let wheelPos = wrapped / scale
        let base = floor(wheelPos)
        let frac = wheelPos - base
        let digit = positiveModInt(Int(base), 10)

        // This wheel's spin rate in digits/sec.
        let wheelVelocity = abs(velocity) / scale
        let blur = blurAmount(forWheelVelocity: wheelVelocity)
        let stretch = stretchAmount(forWheelVelocity: wheelVelocity)
        return WheelInfo(digit: digit, frac: frac, blur: blur, stretch: stretch)
    }

    private func blurAmount(forWheelVelocity v: Double) -> CGFloat {
        // v is in digits/second. A wheel doing a few digits/sec reads as a
        // fast cylinder; cap so it never dissolves entirely.
        let normalized = min(v / 22.0, 1.0)
        return CGFloat(normalized) * 5.0
    }

    private func stretchAmount(forWheelVelocity v: Double) -> CGFloat {
        let normalized = min(v / 22.0, 1.0)
        return 1.0 + CGFloat(normalized) * 0.14
    }

    private func positiveMod(_ a: Double, _ n: Double) -> Double {
        let r = a.truncatingRemainder(dividingBy: n)
        return r < 0 ? r + n : r
    }

    private func positiveModInt(_ a: Int, _ n: Int) -> Int {
        let r = a % n
        return r < 0 ? r + n : r
    }

    // MARK: - Decoration

    private func curvatureOverlay(corner: CGFloat) -> some View {
        // Top + bottom shading fades to clear at the centre to fake the
        // cylinder's curvature, using the dark catalogue tint.
        let dark = Color(red: 0.016, green: 0.020, blue: 0.039)
        return LinearGradient(
            stops: [
                .init(color: dark.opacity(0.95), location: 0.0),
                .init(color: dark.opacity(0.30), location: 0.22),
                .init(color: .clear, location: 0.46),
                .init(color: .clear, location: 0.54),
                .init(color: dark.opacity(0.30), location: 0.78),
                .init(color: dark.opacity(0.95), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .allowsHitTesting(false)
    }

    private func wheelBorder(corner: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [Color.white.opacity(0.16), Color.white.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 0.75
            )
            .allowsHitTesting(false)
    }

    private var backgroundFill: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.06, blue: 0.10),
                Color(red: 0.02, green: 0.03, blue: 0.05)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var digitColor: Color {
        Color(red: 0.94, green: 0.96, blue: 0.99)
    }

    // MARK: - Metrics

    struct LayoutMetrics {
        var fontSize: CGFloat
        var digitHeight: CGFloat
        var windowHeight: CGFloat
        var wheelWidth: CGFloat
        var wheelSpacing: CGFloat
        var wheelCorner: CGFloat
        var totalWidth: CGFloat
    }

    private func layoutMetrics(for size: CGSize) -> LayoutMetrics {
        let minSide = min(size.width, size.height)
        // Wheel sizing scales with the smaller dimension so it works in both a
        // ~120pt tile and a large detail area.
        let spacingGuess: CGFloat = max(2, minSide * 0.03)
        let available = size.width - spacingGuess * CGFloat(digitCount - 1)
        let widthPerWheel = available / CGFloat(digitCount)
        let wheelWidth = max(8, min(widthPerWheel, minSide * 0.42))
        let fontSize = min(wheelWidth * 1.08, size.height * 0.62)
        let digitHeight = max(1, fontSize * 1.18)
        let windowHeight = digitHeight
        let corner = max(2, wheelWidth * 0.18)
        let total = wheelWidth * CGFloat(digitCount)
                    + spacingGuess * CGFloat(digitCount - 1)
        return LayoutMetrics(
            fontSize: fontSize,
            digitHeight: digitHeight,
            windowHeight: windowHeight,
            wheelWidth: wheelWidth,
            wheelSpacing: spacingGuess,
            wheelCorner: corner,
            totalWidth: total
        )
    }
}

// MARK: - OdometerBlurView_DigitWheel

// A single odometer wheel rendered as a 2-digit window: the current digit and
// the next one stacked above it, slid up by `frac` of a digit's height so 9
// wraps cleanly to 0. Velocity-driven blur + vertical stretch sell the spin.
private struct OdometerBlurView_DigitWheel: View {

    let digit: Int
    let frac: Double
    let blur: CGFloat
    let stretch: CGFloat
    let digitHeight: CGFloat
    let fontSize: CGFloat
    let color: Color

    var body: some View {
        let nextDigit = (digit + 1) % 10
        let offset = -CGFloat(frac) * digitHeight

        ZStack {
            wheelBackground
            VStack(spacing: 0) {
                glyph(digit)
                glyph(nextDigit)
            }
            .offset(y: offset)
            .scaleEffect(x: 1.0, y: stretch, anchor: .center)
            .blur(radius: blur)
        }
    }

    private func glyph(_ value: Int) -> some View {
        Text("\(value)")
            .font(.system(size: fontSize, weight: .semibold, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(color)
            .frame(height: digitHeight)
            .frame(maxWidth: .infinity)
            // A soft inner glow so the lit digit reads against the dark drum.
            .shadow(color: Color.white.opacity(0.18), radius: 0.6)
    }

    private var wheelBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.12, blue: 0.17),
                Color(red: 0.04, green: 0.05, blue: 0.08),
                Color(red: 0.10, green: 0.12, blue: 0.17)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
