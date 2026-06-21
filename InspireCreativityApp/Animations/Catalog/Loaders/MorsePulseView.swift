// catalog-id: ld-morse-pulse
import SwiftUI

// MorsePulseView
// A single bar emits a looping Morse transmission: long dashes and short dots,
// the bar glowing and stretching for each pulse with crisp gaps between symbols.
// The word "INSPIRE" is encoded so the wait hides a real message.
//
// interaction: auto — the self-driving TimelineView loop IS the real component
// in both demo modes. iOS 17. No Metal.

public struct MorsePulseView: View {
    public var demo: Bool = false

    public init(demo: Bool = false) {
        self.demo = demo
    }

    public var body: some View {
        GeometryReader { geo in
            MorsePulseView_MorseStage(size: geo.size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Morse symbol model

private enum MorsePulseView_MorseSignal {
    case dot
    case dash
    case symbolGap   // gap between dots/dashes inside one letter (1 unit)
    case letterGap   // gap between letters (3 units)
    case wordGap     // gap between words / loop reset (7 units)
}

private struct MorsePulseView_MorseSlot {
    let on: Bool
    let units: CGFloat
    let isDash: Bool   // only meaningful when on == true
}

private enum MorsePulseView_MorseSchedule {
    // International Morse for the letters in INSPIRE.
    // . = dot, - = dash
    static let letters: [String] = [
        "..",     // I
        "-.",     // N
        "...",    // S
        ".--.",   // P
        "..",     // I
        ".-.",    // R
        "."       // E
    ]

    // Expand the word into a flat on/off slot timeline measured in Morse "units".
    static let slots: [MorsePulseView_MorseSlot] = build()

    static let totalUnits: CGFloat = slots.reduce(0) { $0 + $1.units }

    private static func build() -> [MorsePulseView_MorseSlot] {
        var out: [MorsePulseView_MorseSlot] = []
        for (li, letter) in letters.enumerated() {
            let chars = Array(letter)
            for (ci, ch) in chars.enumerated() {
                let isDash = (ch == "-")
                out.append(MorsePulseView_MorseSlot(on: true,
                                     units: isDash ? 3 : 1,
                                     isDash: isDash))
                // symbol gap (1 unit) between elements within the same letter
                if ci < chars.count - 1 {
                    out.append(MorsePulseView_MorseSlot(on: false, units: 1, isDash: false))
                }
            }
            // letter gap (3 units) between letters
            if li < letters.count - 1 {
                out.append(MorsePulseView_MorseSlot(on: false, units: 3, isDash: false))
            }
        }
        // word gap (7 units) before the loop repeats
        out.append(MorsePulseView_MorseSlot(on: false, units: 7, isDash: false))
        return out
    }
}

// MARK: - Current state derived statelessly from elapsed time

private struct MorsePulseView_MorseState {
    var lit: Bool          // is a pulse currently transmitting
    var isDash: Bool       // dash vs dot for the active pulse
    var slotProgress: CGFloat   // 0...1 progress through the current slot
    var activeIndex: Int        // index of currently transmitting symbol (-1 if gap)
}

private enum MorsePulseView_MorseClock {
    // Seconds per Morse unit. Tuned so the whole "INSPIRE" cycle stays lively
    // (~3.5s) rather than dragging.
    static let unitSeconds: Double = 0.066

    static var cycleSeconds: Double {
        Double(MorsePulseView_MorseSchedule.totalUnits) * unitSeconds
    }

    static func state(at date: Date) -> MorsePulseView_MorseState {
        let cycle = cycleSeconds
        guard cycle > 0 else {
            return MorsePulseView_MorseState(lit: false, isDash: false, slotProgress: 0, activeIndex: -1)
        }
        let elapsed = date.timeIntervalSinceReferenceDate
        var t = CGFloat(elapsed.truncatingRemainder(dividingBy: cycle) / unitSeconds)
        if t < 0 { t += MorsePulseView_MorseSchedule.totalUnits }

        var symbolIndex = 0
        var cursor: CGFloat = 0
        for slot in MorsePulseView_MorseSchedule.slots {
            let end = cursor + slot.units
            if t < end {
                let within = (t - cursor) / max(slot.units, 0.0001)
                return MorsePulseView_MorseState(lit: slot.on,
                                  isDash: slot.isDash,
                                  slotProgress: min(max(within, 0), 1),
                                  activeIndex: slot.on ? symbolIndex : -1)
            }
            cursor = end
            if slot.on { symbolIndex += 1 }
        }
        return MorsePulseView_MorseState(lit: false, isDash: false, slotProgress: 1, activeIndex: -1)
    }
}

// MARK: - Stage

private struct MorsePulseView_MorseStage: View {
    let size: CGSize

    private var unit: CGFloat { min(size.width, size.height) }

    // Layout metrics relative to the tile.
    private var trackWidth: CGFloat { size.width * 0.62 }
    private var barHeight: CGFloat { max(unit * 0.085, 4) }
    private var dotWidth: CGFloat { trackWidth * 0.18 }
    private var dashWidth: CGFloat { trackWidth * 0.52 }
    private var glyphSize: CGFloat { max(unit * 0.05, 3) }

    var body: some View {
        TimelineView(.animation) { timeline in
            let st = MorsePulseView_MorseClock.state(at: timeline.date)
            ZStack {
                background
                VStack(spacing: unit * 0.14) {
                    pulseBar(state: st)
                    glyphTicker(activeIndex: st.activeIndex)
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }

    // MARK: Background

    private var background: some View {
        let top = Color(red: 0.04, green: 0.06, blue: 0.08)
        let bottom = Color(red: 0.02, green: 0.03, blue: 0.05)
        return LinearGradient(colors: [top, bottom],
                              startPoint: .top,
                              endPoint: .bottom)
    }

    // MARK: Pulse bar

    @ViewBuilder
    private func pulseBar(state: MorsePulseView_MorseState) -> some View {
        let live = liveWidth(state: state)
        let glow = glowStrength(state: state)
        ZStack {
            // Persistent dim baseline track — always legible, never blank.
            Capsule(style: .continuous)
                .fill(Color(red: 0.10, green: 0.16, blue: 0.20))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color(red: 0.16, green: 0.24, blue: 0.30),
                                      lineWidth: 1)
                )
                .frame(width: trackWidth, height: barHeight)

            // The glowing transmitting pulse, stretching from the left.
            Capsule(style: .continuous)
                .fill(pulseGradient)
                .frame(width: live, height: barHeight)
                .shadow(color: pulseGlowColor.opacity(0.85 * glow),
                        radius: barHeight * (1.4 + 2.6 * glow))
                .shadow(color: pulseGlowColor.opacity(0.55 * glow),
                        radius: barHeight * (0.6 + 1.0 * glow))
                .frame(width: trackWidth, alignment: .leading)
                .animation(.easeOut(duration: 0.05), value: state.lit)
        }
        .frame(width: trackWidth, height: barHeight)
    }

    private var pulseGradient: LinearGradient {
        let a = Color(red: 0.30, green: 0.95, blue: 0.78)
        let b = Color(red: 0.16, green: 0.80, blue: 0.95)
        return LinearGradient(colors: [a, b],
                              startPoint: .leading,
                              endPoint: .trailing)
    }

    private var pulseGlowColor: Color {
        Color(red: 0.24, green: 0.92, blue: 0.86)
    }

    // Width of the lit pulse. During a gap it collapses to a tiny lit nub at the
    // left so the track origin stays anchored and the transition reads crisply.
    private func liveWidth(state: MorsePulseView_MorseState) -> CGFloat {
        let nub = barHeight * 0.9   // minimum lit dot during gaps (still legible)
        guard state.lit else { return nub }
        let target = state.isDash ? dashWidth : dotWidth
        // Quick attack on the leading edge of a symbol so it "snaps" open.
        let attack = min(state.slotProgress / 0.22, 1)
        let eased = 1 - pow(1 - attack, 3)   // easeOutCubic
        return nub + (target - nub) * eased
    }

    // 0 during gaps, ~1 while transmitting (with a soft breathing pulse).
    private func glowStrength(state: MorsePulseView_MorseState) -> CGFloat {
        guard state.lit else { return 0 }
        let attack = min(state.slotProgress / 0.18, 1)
        let breathe = 0.85 + 0.15 * sin(state.slotProgress * .pi)
        return min(attack * breathe, 1)
    }

    // MARK: Glyph ticker (the hidden-message readout)

    @ViewBuilder
    private func glyphTicker(activeIndex: Int) -> some View {
        let glyphs = MorsePulseView_MorseGlyphs.flat
        HStack(spacing: glyphSize * 1.1) {
            ForEach(glyphs.indices, id: \.self) { i in
                glyphDot(symbol: glyphs[i], active: i == activeIndex)
            }
        }
        // Clamp the full readout to the track width so the 17 symbols stay
        // legible in a tiny ~120pt tile as well as the larger detail area.
        .frame(maxWidth: trackWidth)
        .fixedSize()
        .scaleEffect(tickerScale(count: glyphs.count), anchor: .center)
        .frame(maxWidth: trackWidth)
    }

    // Estimate the intrinsic ticker width and scale it down to fit the track.
    private func tickerScale(count: Int) -> CGFloat {
        guard count > 0 else { return 1 }
        let dashes = MorsePulseView_MorseGlyphs.flat.filter { $0 == .dash }.count
        let dots = count - dashes
        let symbolsWidth = CGFloat(dots) * glyphSize + CGFloat(dashes) * glyphSize * 3
        let spacing = CGFloat(max(count - 1, 0)) * glyphSize * 1.1
        let intrinsic = symbolsWidth + spacing
        guard intrinsic > 0 else { return 1 }
        return min(1, trackWidth / intrinsic)
    }

    @ViewBuilder
    private func glyphDot(symbol: MorsePulseView_MorseGlyphs.Glyph, active: Bool) -> some View {
        let w: CGFloat = symbol == .dash ? glyphSize * 3 : glyphSize
        let dim = Color(red: 0.18, green: 0.26, blue: 0.31)
        let hot = Color(red: 0.30, green: 0.95, blue: 0.82)
        Capsule(style: .continuous)
            .fill(active ? hot : dim)
            .frame(width: w, height: glyphSize)
            .shadow(color: hot.opacity(active ? 0.8 : 0),
                    radius: active ? glyphSize * 1.6 : 0)
            .scaleEffect(active ? 1.25 : 1.0)
            .animation(.easeOut(duration: 0.12), value: active)
    }
}

// MARK: - Glyph list (mirrors the transmitting on-symbols in order)

private enum MorsePulseView_MorseGlyphs {
    enum Glyph: Equatable { case dot, dash }

    // Flat ordered list of just the ON symbols across the whole word, so the
    // ticker index lines up with MorsePulseView_MorseState.activeIndex.
    static let flat: [Glyph] = build()

    private static func build() -> [Glyph] {
        var out: [Glyph] = []
        for slot in MorsePulseView_MorseSchedule.slots where slot.on {
            out.append(slot.isDash ? .dash : .dot)
        }
        return out
    }
}
