// catalog-id: tx-decode-matrix
import SwiftUI

/// Glyph Decode Cascade — text resolves out of a column of rapidly cycling
/// random glyphs per slot. Each character locks from left to right: the
/// still-scrambling characters dim and jitter while the locked ones brighten
/// and settle. A wave of order sweeps across the chaos.
///
/// - `demo == true`  : self-driving loop derived purely from the timeline clock.
/// - `demo == false` : real interactive component — tap to replay the cascade.
struct DecodeMatrixView: View {
    var demo: Bool = false

    // MARK: - Tunables

    /// The string that resolves out of the noise. Short so it fits a 120pt tile.
    private let target: [Character] = Array("INSPIRE")

    /// Glyph pool the unlocked slots cycle through.
    private let glyphPool: [Character] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#$%&*+=<>/\\")

    /// Quantum for the ~20fps glyph flip (0.05s == 20 flips/sec).
    private let flipQuantum: Double = 0.05

    /// Delay before the first slot may lock.
    private let baseDelay: Double = 0.35

    /// Extra delay per slot index, producing the left-to-right cascade.
    private let stagger: Double = 0.26

    /// How long to hold the fully-resolved word before the demo re-scrambles.
    private let holdDuration: Double = 1.1

    // MARK: - State (interactive only)

    /// When the current cascade began. Tapping resets this to "now".
    @State private var cascadeStart: Date = Date()

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(backgroundFill)
                .contentShape(Rectangle())
                .modifier(DecodeMatrixView_TapReplay(enabled: !demo) {
                    cascadeStart = Date()
                })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Driver

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        let dimension = min(size.width, size.height)
        let fontSize = max(13.0, dimension * 0.20)
        let slotWidth = fontSize * 0.74
        let jitter = fontSize * 0.10

        TimelineView(.animation) { timeline in
            let elapsed = elapsedTime(now: timeline.date)
            let step = Int(elapsed / flipQuantum)

            row(elapsed: elapsed,
                step: step,
                fontSize: fontSize,
                slotWidth: slotWidth,
                jitter: jitter)
        }
    }

    /// `demo` derives a looping clock; interactive measures from the last tap.
    private func elapsedTime(now: Date) -> Double {
        if demo {
            let period = loopPeriod
            let raw = now.timeIntervalSince1970.truncatingRemainder(dividingBy: period)
            return raw < 0 ? raw + period : raw
        } else {
            return now.timeIntervalSince(cascadeStart)
        }
    }

    /// Total loop length: last slot locks, then we hold the resolved word.
    private var loopPeriod: Double {
        let lastLock = lockTime(for: target.count - 1)
        return lastLock + holdDuration
    }

    // MARK: - Layout

    @ViewBuilder
    private func row(elapsed: Double,
                     step: Int,
                     fontSize: CGFloat,
                     slotWidth: CGFloat,
                     jitter: CGFloat) -> some View {
        HStack(spacing: slotWidth * 0.16) {
            ForEach(target.indices, id: \.self) { index in
                slotView(index: index,
                         elapsed: elapsed,
                         step: step,
                         fontSize: fontSize,
                         slotWidth: slotWidth,
                         jitter: jitter)
            }
        }
        .padding(.horizontal, fontSize * 0.4)
    }

    // MARK: - Per-slot rendering

    @ViewBuilder
    private func slotView(index: Int,
                          elapsed: Double,
                          step: Int,
                          fontSize: CGFloat,
                          slotWidth: CGFloat,
                          jitter: CGFloat) -> some View {
        let locked = elapsed >= lockTime(for: index)
        let character = locked ? target[index] : scrambleGlyph(slot: index, step: step)

        // Slot just before the lock front gets a brief "charging" pulse.
        let nearFront = !locked && (elapsed >= lockTime(for: index) - flipQuantum * 4)
        let yOffset = locked ? 0.0 : jitterOffset(slot: index, step: step, amount: jitter)

        Text(String(character))
            .font(.system(size: fontSize, weight: locked ? .bold : .regular, design: .monospaced))
            .foregroundStyle(slotColor(locked: locked, nearFront: nearFront))
            .brightness(locked ? 0.10 : 0.0)
            .shadow(color: lockedGlow.opacity(locked ? 0.9 : 0.0),
                    radius: locked ? fontSize * 0.28 : 0)
            .scaleEffect(lockScale(locked: locked, index: index, elapsed: elapsed))
            .offset(y: yOffset)
            .frame(width: slotWidth)
            .animation(.spring(response: 0.28, dampingFraction: 0.55), value: locked)
    }

    // MARK: - Timing

    /// When slot `index` is permitted to lock onto its target glyph.
    private func lockTime(for index: Int) -> Double {
        baseDelay + Double(index) * stagger
    }

    /// A small settle pop the instant a slot locks, decaying back to 1.0.
    private func lockScale(locked: Bool, index: Int, elapsed: Double) -> CGFloat {
        guard locked else { return 0.96 }
        let sinceLock = elapsed - lockTime(for: index)
        guard sinceLock < 0.22 else { return 1.0 }
        // Snap up then ease back to rest.
        let t = sinceLock / 0.22
        let pop = sin(t * .pi) * 0.16
        return 1.0 + CGFloat(pop)
    }

    // MARK: - Deterministic glyph selection (quantized to ~20fps)

    /// Pure function of (slot, step) so the glyph is stable within a frame
    /// quantum and flips ~20 times/sec instead of re-rolling every render frame.
    private func scrambleGlyph(slot: Int, step: Int) -> Character {
        let h = hash(slot: slot, step: step)
        return glyphPool[h % glyphPool.count]
    }

    /// Deterministic vertical jitter for unlocked slots, also quantized.
    private func jitterOffset(slot: Int, step: Int, amount: CGFloat) -> CGFloat {
        let h = hash(slot: slot &+ 101, step: step)
        let normalized = (Double(h % 1000) / 1000.0) * 2.0 - 1.0 // -1...1
        return CGFloat(normalized) * amount
    }

    /// Cheap integer hash mixing slot and step into a well-spread value.
    private func hash(slot: Int, step: Int) -> Int {
        var x = UInt64(bitPattern: Int64(slot &* 73856093 ^ step &* 19349663))
        x ^= x >> 33
        x = x &* 0xff51afd7ed558ccd
        x ^= x >> 33
        return Int(x & 0x7fff_ffff)
    }

    // MARK: - Palette

    /// Locked = bright phosphor green-white; unlocked = dim, never invisible.
    private func slotColor(locked: Bool, nearFront: Bool) -> Color {
        if locked {
            return Color(red: 0.78, green: 1.0, blue: 0.86)
        } else if nearFront {
            return Color(red: 0.42, green: 0.78, blue: 0.55)
        } else {
            return Color(red: 0.26, green: 0.46, blue: 0.36)
        }
    }

    private var lockedGlow: Color {
        Color(red: 0.30, green: 1.0, blue: 0.55)
    }

    private var backgroundFill: some View {
        LinearGradient(
            colors: [
                Color(red: 0.015, green: 0.020, blue: 0.040),
                Color(red: 0.020, green: 0.035, blue: 0.030)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Tap replay modifier

/// Adds an onTapGesture only for the real interactive component, keeping the
/// demo tile purely self-driving.
private struct DecodeMatrixView_TapReplay: ViewModifier {
    let enabled: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        if enabled {
            content.onTapGesture { action() }
        } else {
            content
        }
    }
}
