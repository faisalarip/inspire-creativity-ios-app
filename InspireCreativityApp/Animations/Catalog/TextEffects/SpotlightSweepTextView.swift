// catalog-id: tx-spotlight-sweep
import SwiftUI

/// Spotlight Reveal — a soft radial spotlight glides across a dim embossed
/// headline, brightening and lifting only the characters it currently
/// illuminates, leaving a warm candlelight afterglow trail behind it.
///
/// - `demo == true`  → a self-driving TimelineView sweeps the spotlight
///   left → right → back on a ~3s loop, so the tile is always alive.
/// - `demo == false` → an idle auto-sweep that a `DragGesture` can grab:
///   your finger's x sets the spotlight center; releasing hands control
///   back to the gentle sweep, resuming from where you let go.
struct SpotlightSweepTextView: View {
    var demo: Bool = false

    private let phrase: String = "INSPIRE"

    // Interactive state (demo == false)
    @State private var dragX: CGFloat? = nil          // live finger x while dragging
    @State private var idlePhase: Double = 0           // 0...1 sweep position used at rest
    @State private var trailX: CGFloat = 0             // eased, lagged spotlight x for the wake
    @State private var lastSpotX: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                background
                if demo {
                    demoDriver(size: size)
                } else {
                    interactiveDriver(size: size)
                }
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Backdrop

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.05, blue: 0.10),
                Color(red: 0.02, green: 0.03, blue: 0.06)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Drivers

    /// Self-driving loop for the grid tile.
    private func demoDriver(size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let metrics = layout(for: size)
            // Smooth left↔right↔left sweep on a ~3s period.
            let phase = sweepPhase(time: t, period: 3.0)
            let spotX = spotlightX(phase: phase, metrics: metrics)
            // Trail = where the light was a small time-delta earlier, so the
            // wake flips direction correctly on the return pass.
            let trailPhase = sweepPhase(time: t - 0.28, period: 3.0)
            let trail = spotlightX(phase: trailPhase, metrics: metrics)
            headline(spotX: spotX, trailX: trail, metrics: metrics)
        }
    }

    /// Idle auto-sweep that a drag can grab and override.
    private func interactiveDriver(size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let metrics = layout(for: size)
            let idleSpot = spotlightX(phase: sweepPhase(time: t, period: 3.0),
                                      metrics: metrics)
            // Finger wins when present; otherwise drift with the idle sweep.
            let spotX = dragX ?? idleSpot
            renderInteractive(spotX: spotX, metrics: metrics)
        }
        .gesture(dragGesture(size: size))
    }

    private func renderInteractive(spotX: CGFloat, metrics: Metrics) -> some View {
        // Ease the trailing afterglow toward the live spotlight so the wake
        // lags behind motion in either direction.
        let eased = trailX + (spotX - trailX) * 0.16
        DispatchQueue.main.async {
            trailX = eased
            lastSpotX = spotX
        }
        return headline(spotX: spotX, trailX: trailX, metrics: metrics)
    }

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                dragX = clampX(value.location.x, width: size.width)
            }
            .onEnded { _ in
                dragX = nil
            }
    }

    // MARK: - The single shared renderer

    private func headline(spotX: CGFloat, trailX: CGFloat, metrics: Metrics) -> some View {
        let chars = Array(phrase)
        return ZStack {
            // Dim embossed base — ALWAYS legible, never blank.
            embossedBase(chars: chars, metrics: metrics, spotX: spotX, trailX: trailX)

            // Warm afterglow blob trailing the light.
            afterglow(x: trailX, metrics: metrics)

            // Bright lit copy, additively layered, masked by the moving light.
            litWord(chars: chars, metrics: metrics, spotX: spotX)
                .mask(spotlightMask(x: spotX, metrics: metrics))
        }
        .frame(width: metrics.size.width, height: metrics.size.height)
    }

    // MARK: - Layers

    private func embossedBase(chars: [Character], metrics: Metrics,
                              spotX: CGFloat, trailX: CGFloat) -> some View {
        HStack(spacing: metrics.spacing) {
            ForEach(Array(chars.enumerated()), id: \.offset) { idx, ch in
                let cx = charCenterX(index: idx, metrics: metrics)
                let intensity = intensityFor(charX: cx, spotX: spotX, sigma: metrics.sigma)
                SpotlightSweepTextView_CharCell(character: ch,
                         fontSize: metrics.fontSize,
                         intensity: intensity)
            }
        }
        .frame(width: metrics.size.width, height: metrics.size.height)
    }

    private func litWord(chars: [Character], metrics: Metrics, spotX: CGFloat) -> some View {
        HStack(spacing: metrics.spacing) {
            ForEach(Array(chars.enumerated()), id: \.offset) { idx, ch in
                let cx = charCenterX(index: idx, metrics: metrics)
                let intensity = intensityFor(charX: cx, spotX: spotX, sigma: metrics.sigma)
                SpotlightSweepTextView_LitCharCell(character: ch,
                            fontSize: metrics.fontSize,
                            intensity: intensity)
            }
        }
        .frame(width: metrics.size.width, height: metrics.size.height)
    }

    private func spotlightMask(x: CGFloat, metrics: Metrics) -> some View {
        let r: CGFloat = metrics.spotRadius
        return RadialGradient(
            gradient: Gradient(stops: [
                .init(color: .white, location: 0.0),
                .init(color: .white.opacity(0.9), location: 0.45),
                .init(color: .white.opacity(0.25), location: 0.78),
                .init(color: .clear, location: 1.0)
            ]),
            center: .center,
            startRadius: 0,
            endRadius: r
        )
        .frame(width: r * 2, height: r * 2)
        .position(x: x, y: metrics.size.height / 2)
        .frame(width: metrics.size.width, height: metrics.size.height)
    }

    private func afterglow(x: CGFloat, metrics: Metrics) -> some View {
        let r: CGFloat = metrics.spotRadius * 1.15
        return RadialGradient(
            gradient: Gradient(colors: [
                Color(red: 1.0, green: 0.66, blue: 0.30).opacity(0.34),
                Color(red: 0.95, green: 0.50, blue: 0.18).opacity(0.10),
                Color.clear
            ]),
            center: .center,
            startRadius: 0,
            endRadius: r
        )
        .frame(width: r * 2, height: r * 2)
        .position(x: x, y: metrics.size.height / 2)
        .frame(width: metrics.size.width, height: metrics.size.height)
        .blendMode(.screen)
        .allowsHitTesting(false)
    }

    // MARK: - Math helpers

    /// Triangle/sine sweep position in 0...1 (eased), ping-ponging.
    private func sweepPhase(time: Double, period: Double) -> Double {
        let p = (time.truncatingRemainder(dividingBy: period)) / period
        // 0→1→0 via cosine for soft turnarounds.
        return (1 - cos(p * 2 * .pi)) / 2
    }

    private func spotlightX(phase: Double, metrics: Metrics) -> CGFloat {
        let pad = metrics.fontSize * 0.4
        let lo = pad
        let hi = metrics.size.width - pad
        return lo + (hi - lo) * CGFloat(phase)
    }

    private func charCenterX(index: Int, metrics: Metrics) -> CGFloat {
        let n = max(metrics.count, 1)
        let usable = metrics.size.width
        let step = usable / CGFloat(n)
        return step * (CGFloat(index) + 0.5)
    }

    /// Gaussian falloff of brightness vs. distance to the spotlight x.
    private func intensityFor(charX: CGFloat, spotX: CGFloat, sigma: CGFloat) -> Double {
        let dx = Double(charX - spotX)
        let s = Double(sigma)
        let v = exp(-(dx * dx) / (2 * s * s))
        return min(max(v, 0), 1)
    }

    private func clampX(_ x: CGFloat, width: CGFloat) -> CGFloat {
        min(max(x, 0), width)
    }

    // MARK: - Layout metrics

    struct Metrics {
        var size: CGSize
        var count: Int
        var fontSize: CGFloat
        var spacing: CGFloat
        var sigma: CGFloat
        var spotRadius: CGFloat
    }

    private func layout(for size: CGSize) -> Metrics {
        let count = max(phrase.count, 1)
        // Size the type to the geometry so it fits a 120pt tile and a big detail.
        let byWidth = size.width / CGFloat(count) * 1.18
        let byHeight = size.height * 0.42
        let fontSize = min(byWidth, byHeight)
        let sigma = max(size.width * 0.16, fontSize * 1.1)
        let spotRadius = max(size.width * 0.30, fontSize * 1.8)
        return Metrics(
            size: size,
            count: count,
            fontSize: fontSize,
            spacing: fontSize * 0.04,
            sigma: sigma,
            spotRadius: spotRadius
        )
    }
}

// MARK: - Character cells

/// The dim, embossed resting glyph. Stays legible on every frame; the
/// spotlight only nudges its scale/shadow so it lifts subtly into the light.
private struct SpotlightSweepTextView_CharCell: View {
    let character: Character
    let fontSize: CGFloat
    let intensity: Double

    var body: some View {
        let lift = CGFloat(intensity) * 6
        let scale = 1 + 0.16 * intensity
        Text(String(character))
            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
            .kerning(fontSize * 0.02)
            // Cool dim base — readable floor, brightened a touch by the light.
            .foregroundStyle(baseColor)
            // Embossed feel: dark drop below, faint light above.
            .shadow(color: .black.opacity(0.55),
                    radius: 1, x: 0, y: 1.5)
            .shadow(color: .white.opacity(0.06 + 0.10 * intensity),
                    radius: 0.5, x: 0, y: -0.5)
            // Warm cast + lift only where illuminated.
            .shadow(color: Color(red: 1.0, green: 0.62, blue: 0.28)
                        .opacity(0.55 * intensity),
                    radius: 8 * CGFloat(intensity), x: 0, y: 0)
            .scaleEffect(scale)
            .offset(y: -lift)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
    }

    private var baseColor: Color {
        // Dim slate at rest, easing toward a paler tone under the light.
        let lo = 0.30, hi = 0.55
        let v = lo + (hi - lo) * intensity
        return Color(red: v * 0.92, green: v * 0.96, blue: v)
    }
}

/// The bright "lit" copy. This whole layer is masked by the radial spotlight,
/// so it only shows through where the light is. Per-char intensity boosts the
/// warmth and glow of the letter currently under the beam.
private struct SpotlightSweepTextView_LitCharCell: View {
    let character: Character
    let fontSize: CGFloat
    let intensity: Double

    var body: some View {
        let scale = 1 + 0.16 * intensity
        let lift = CGFloat(intensity) * 6
        Text(String(character))
            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
            .kerning(fontSize * 0.02)
            .foregroundStyle(warm)
            .shadow(color: Color(red: 1.0, green: 0.72, blue: 0.36)
                        .opacity(0.9), radius: 6, x: 0, y: 0)
            .shadow(color: Color(red: 1.0, green: 0.55, blue: 0.18)
                        .opacity(0.7), radius: 14, x: 0, y: 0)
            .scaleEffect(scale)
            .offset(y: -lift)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
    }

    private var warm: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.96, blue: 0.86),
                Color(red: 1.0, green: 0.82, blue: 0.50)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
