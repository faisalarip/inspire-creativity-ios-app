// catalog-id: tx-neon-flicker
import SwiftUI

// MARK: - Neon Sign Flicker
//
// A glowing neon-tube headline that buzzes to life with a realistic startup
// flicker. One stubborn letter stutters on and off a few times before it
// catches, then the whole sign settles into a steady warm-glow hum with a
// faintly pulsing halo.
//
// - demo == true:  self-driving ~3.4s loop (dark-ish → stutter → catch → hum).
// - demo == false: lit & humming at rest; a tap replays the buzz-to-life.
//
// Single always-running TimelineView(.animation) drives everything. A dim
// unlit tube of every glyph is ALWAYS visible underneath the lit layer, so no
// frame is ever blank — exactly how a real neon sign reads when "off".
//
// iOS 17. Pure SwiftUI, no shaders, no external dependencies.

struct NeonFlickerView: View {
    var demo: Bool = false

    // The headline. The character at `stutterIndex` is the misbehaving one.
    private let word: String = "NEON"
    private let stutterIndex: Int = 1   // the "E" stutters on its way to life

    // Full buzz-to-life duration before the steady hum takes over.
    private let flickerDuration: Double = 1.45
    // Total demo loop length (buzz-to-life + a stretch of steady hum).
    private let loopDuration: Double = 3.4

    // Neon tube hue — a warm bar-window magenta/pink.
    private var tubeColor: Color { Color(red: 1.0, green: 0.27, blue: 0.62) }
    private var tubeCore: Color { Color(red: 1.0, green: 0.82, blue: 0.92) }

    // Interactive replay anchor (tap date). nil → resting hum.
    @State private var tapDate: Date? = nil
    @State private var appearDate: Date = .now

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let metrics = Metrics(size: geo.size)
                content(now: timeline.date, metrics: metrics)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundWall)
        .contentShape(Rectangle())
        .onTapGesture {
            // Replay the startup flicker from "dark".
            tapDate = .now
        }
        .onAppear { appearDate = .now }
    }

    // MARK: Layout metrics derived from the tile/detail size

    struct Metrics {
        let fontSize: CGFloat
        let spacing: CGFloat
        let haloRadius: CGFloat

        init(size: CGSize) {
            let minSide = min(size.width, size.height)
            // Scale font to fit the word horizontally with comfortable margin.
            let byWidth = size.width / 4.6
            let byHeight = minSide * 0.42
            let f = max(20, min(byWidth, byHeight))
            fontSize = f
            spacing = f * 0.06
            haloRadius = f * 0.5
        }
    }

    // MARK: Background — a dark wall the tubes glow against

    private var backgroundWall: some View {
        let base = Color(red: 0.016, green: 0.020, blue: 0.039) // #04050a
        return RadialGradient(
            colors: [
                Color(red: 0.10, green: 0.04, blue: 0.10),
                base
            ],
            center: .center,
            startRadius: 0,
            endRadius: 320
        )
    }

    // MARK: Composed lit headline

    private func content(now: Date, metrics: Metrics) -> some View {
        // Elapsed time since the flicker anchor.
        let elapsed = flickerElapsed(now: now)
        // Sine phase for the steady-hum halo breathe.
        let hum = humPhase(now: now)
        // Index over the glyphs; keyed on index so duplicate letters (the two
        // N's in "NEON") stay distinct identities.
        let letters = Array(word)

        return HStack(spacing: metrics.spacing) {
            ForEach(letters.indices, id: \.self) { index in
                NeonFlickerView_NeonLetter(
                    character: String(letters[index]),
                    fontSize: metrics.fontSize,
                    haloRadius: metrics.haloRadius,
                    tubeColor: tubeColor,
                    coreColor: tubeCore,
                    litOpacity: litOpacity(for: index, elapsed: elapsed),
                    haloIntensity: haloIntensity(for: index, elapsed: elapsed, hum: hum)
                )
            }
        }
    }

    // MARK: Timing

    /// Seconds elapsed within the current buzz-to-life cycle.
    private func flickerElapsed(now: Date) -> Double {
        if demo {
            // Self-driving: loop the whole sequence forever.
            let t = now.timeIntervalSince(appearDate)
            return t.truncatingRemainder(dividingBy: loopDuration)
        } else if let tap = tapDate {
            // Interactive: count up from the tap; past flickerDuration we hold lit.
            return now.timeIntervalSince(tap)
        } else {
            // At rest before any tap: already fully lit & humming.
            return flickerDuration + 1.0
        }
    }

    /// Continuous phase for the steady hum (independent of flicker anchor).
    private func humPhase(now: Date) -> Double {
        let t = now.timeIntervalSince(appearDate)
        return t
    }

    // MARK: Per-letter lit opacity (the electrical flicker track)

    /// The lit-glow opacity for a glyph, 0 (tube dark) ... 1 (full glow).
    /// The dim unlit tube is drawn separately and never disappears.
    private func litOpacity(for index: Int, elapsed: Double) -> Double {
        // After the buzz-to-life window everything is solidly lit.
        if elapsed >= flickerDuration { return 1.0 }
        if elapsed < 0 { return 1.0 }

        if index == stutterIndex {
            return stutterTrack(elapsed: elapsed)
        } else {
            return normalCatchTrack(elapsed: elapsed)
        }
    }

    /// Well-behaved letters: a couple of quick electrical blinks, then steady.
    private func normalCatchTrack(elapsed: Double) -> Double {
        // Irregular on/off keyframes (start dim, snap on, brief drop, hold).
        // Times are within [0, flickerDuration].
        switch elapsed {
        case ..<0.08:  return 0.0   // initial dark
        case ..<0.14:  return 0.9   // first strike
        case ..<0.20:  return 0.15  // brief dropout
        case ..<0.26:  return 1.0   // catches
        case ..<0.30:  return 0.45  // tiny flutter
        default:       return 1.0   // steady on
        }
    }

    /// The stubborn stutter letter: stutters on/off several times before catching.
    private func stutterTrack(elapsed: Double) -> Double {
        switch elapsed {
        case ..<0.10:  return 0.0
        case ..<0.16:  return 0.85
        case ..<0.24:  return 0.0
        case ..<0.30:  return 0.7
        case ..<0.40:  return 0.05
        case ..<0.46:  return 0.95
        case ..<0.58:  return 0.0   // stubborn dropout
        case ..<0.66:  return 0.6
        case ..<0.78:  return 0.1
        case ..<0.86:  return 1.0   // nearly there
        case ..<0.96:  return 0.3   // final flutter
        default:       return 1.0   // finally catches & holds
        }
    }

    // MARK: Per-letter halo intensity (glow radius/strength multiplier)

    /// Combines the flicker-driven litness with the steady-hum sine pulse.
    private func haloIntensity(for index: Int, elapsed: Double, hum: Double) -> Double {
        let lit = litOpacity(for: index, elapsed: elapsed)

        // Steady-hum breathe: low-amplitude sine, slight per-letter phase offset.
        let phase = hum * 2.4 + Double(index) * 0.5
        let breathe = 0.85 + 0.15 * (sin(phase) * 0.5 + 0.5)

        // While catching, the halo follows the lit track tightly; once settled,
        // it gently hums.
        if elapsed >= flickerDuration {
            return breathe
        }
        return lit * breathe
    }
}

// MARK: - A single neon glyph

private struct NeonFlickerView_NeonLetter: View {
    let character: String
    let fontSize: CGFloat
    let haloRadius: CGFloat
    let tubeColor: Color
    let coreColor: Color
    /// 0 = lit glow off (only dim tube shows), 1 = full glow.
    let litOpacity: Double
    /// Multiplier on the halo strength/spread for the steady hum.
    let haloIntensity: Double

    var body: some View {
        ZStack {
            // 1) The ALWAYS-VISIBLE dim unlit tube. Never disappears, so the
            //    sign reads as a real (currently-off) neon shape, not blank.
            glyph
                .foregroundStyle(unlitTube)
                .opacity(0.42)

            // 2) The lit tube body with stacked shadow halos for the glow.
            glyph
                .foregroundStyle(litBody)
                .shadow(color: tubeColor.opacity(0.95 * haloIntensity),
                        radius: haloRadius * 0.30 * clampedIntensity)
                .shadow(color: tubeColor.opacity(0.70 * haloIntensity),
                        radius: haloRadius * 0.62 * clampedIntensity)
                .shadow(color: tubeColor.opacity(0.45 * haloIntensity),
                        radius: haloRadius * 1.05 * clampedIntensity)
                .shadow(color: tubeColor.opacity(0.25 * haloIntensity),
                        radius: haloRadius * 1.6 * clampedIntensity)
                .opacity(litOpacity)

            // 3) Bright hot core for the lit tube so it reads as glass + gas.
            glyph
                .foregroundStyle(coreColor)
                .blur(radius: max(0.4, fontSize * 0.012))
                .opacity(litOpacity * 0.9)
        }
        .animation(.linear(duration: 0.04), value: litOpacity)
    }

    private var clampedIntensity: CGFloat {
        CGFloat(max(0.2, min(1.4, haloIntensity)))
    }

    private var glyph: some View {
        Text(character)
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .kerning(fontSize * 0.04)
    }

    private var unlitTube: Color {
        // Desaturated dark version of the tube — the glass with the gas off.
        Color(red: 0.34, green: 0.12, blue: 0.24)
    }

    private var litBody: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.55, blue: 0.80),
                tubeColor
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
