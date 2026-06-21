// catalog-id: mi-scrubber-wave
import SwiftUI

/// Waveform Scrubber — dragging across an audio waveform parts the bars around the
/// playhead and ripples a height-wave outward from the touch point.
///
/// - `demo == true`  → a self-driving TimelineView sweeps the playhead 0→1→0 on a
///   loop so the tile is always alive (bars are always rendered at their baseline).
/// - `demo == false` → a real DragGesture sets the playhead; per-bar parting +
///   height bulge are computed from distance to the playhead with a falloff, with
///   `sensoryFeedback(.selection)` ticking as the bar under the finger changes.
///   The playhead is left wherever the finger releases (no spring back).
struct ScrubberWaveView: View {
    var demo: Bool = false

    // Persistent interactive playhead (normalized 0...1). Release leaves it in place.
    @State private var playhead: CGFloat = 0.5
    @State private var isDragging: Bool = false
    // Touch-down moment, used for a short bounded amplitude "kick" on grab.
    @State private var touchStart: Date = .distantPast
    // Integer bar index under the playhead — drives selection haptics on change.
    @State private var activeBar: Int = -1

    private let barCount: Int = 42

    var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Content router

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if demo {
            demoContent(in: size)
        } else {
            interactiveContent(in: size)
        }
    }

    // MARK: - Demo (self-driving)

    private func demoContent(in size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let head = Self.sweep(t)
            waveformCanvas(size: size, head: head, boost: 0.0)
        }
    }

    // MARK: - Interactive

    private func interactiveContent(in size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let boost = touchBoost(now: timeline.date)
            waveformCanvas(size: size, head: playhead, boost: boost)
        }
        .contentShape(Rectangle())
        .gesture(dragGesture(in: size))
        .sensoryFeedback(.selection, trigger: activeBar)
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    touchStart = Date()
                }
                let w = max(size.width, 1)
                let x = min(max(value.location.x, 0), w)
                playhead = x / w
                let idx = Int((playhead * CGFloat(barCount - 1)).rounded())
                if idx != activeBar { activeBar = idx }
            }
            .onEnded { _ in
                // Release leaves the playhead — no spring back to zero.
                isDragging = false
            }
    }

    /// A short, bounded amplitude boost right after touch-down so the wave "kicks"
    /// when you grab it, then decays. Returns 0 in steady state.
    private func touchBoost(now: Date) -> CGFloat {
        guard isDragging else { return 0 }
        let elapsed = now.timeIntervalSince(touchStart)
        guard elapsed >= 0, elapsed < 0.6 else { return 0 }
        let decay = 1.0 - (elapsed / 0.6)
        return CGFloat(decay) * 0.35
    }

    // MARK: - Shared waveform draw path

    /// Single Canvas that draws every bar. `head` is the normalized playhead,
    /// `boost` is an optional transient extra amplitude near the playhead.
    private func waveformCanvas(size: CGSize, head: CGFloat, boost: CGFloat) -> some View {
        Canvas { context, canvasSize in
            drawWaveform(into: context, size: canvasSize, head: head, boost: boost)
        }
    }

    private func drawWaveform(into context: GraphicsContext, size: CGSize, head: CGFloat, boost: CGFloat) {
        let w = size.width
        let h = size.height
        guard w > 1, h > 1 else { return }

        let inset: CGFloat = w * 0.06
        let usableW = w - inset * 2
        let midY = h * 0.5
        let maxBarH = h * 0.72
        let minBarH = h * 0.12
        let slotW = usableW / CGFloat(barCount)
        let barW = min(slotW * 0.5, 6)

        let headX = inset + head * usableW

        // Parting + bulge influence radius in slot-units.
        let radius: CGFloat = 4.0

        for i in 0..<barCount {
            let baseX = inset + (CGFloat(i) + 0.5) * slotW
            // Distance from this bar to the playhead, in slot units.
            let dxSlots = (baseX - headX) / slotW
            let absD = abs(dxSlots)

            // Cosine bell centered on the playhead → height bulge that rides along.
            let bell = bellFalloff(distance: absD, radius: radius)

            // Horizontal parting: bars near the head push away from it.
            let partStrength = bell * slotW * 0.85
            let dir: CGFloat = dxSlots == 0 ? 0 : (dxSlots > 0 ? 1 : -1)
            let partOffset = dir * partStrength

            // Base amplitude is deterministic (precomputed once) — never per-frame random.
            let amp = Self.amplitudes[i]
            let bulge = 1.0 + bell * (1.35 + boost)
            var barH = (minBarH + (maxBarH - minBarH) * amp) * bulge
            barH = min(barH, h * 0.94)

            let x = baseX + partOffset
            let rect = CGRect(
                x: x - barW / 2,
                y: midY - barH / 2,
                width: barW,
                height: barH
            )
            let path = Path(roundedRect: rect, cornerRadius: barW / 2)

            // Bars at/behind the playhead read as "played" (warm), ahead are cool.
            let played = baseX <= headX
            let color = barColor(played: played, bell: bell)
            context.fill(path, with: .color(color))
        }

        drawPlayhead(into: context, x: headX, height: h)
    }

    private func drawPlayhead(into context: GraphicsContext, x: CGFloat, height: CGFloat) {
        let topPad = height * 0.08
        let lineRect = CGRect(x: x - 1.25, y: topPad, width: 2.5, height: height - topPad * 2)
        let line = Path(roundedRect: lineRect, cornerRadius: 1.25)
        context.fill(line, with: .color(playheadColor))

        // Soft glow halo so the playhead reads on any background.
        let haloR = height * 0.07
        let haloRect = CGRect(x: x - haloR, y: height * 0.5 - haloR, width: haloR * 2, height: haloR * 2)
        context.fill(Path(ellipseIn: haloRect), with: .color(playheadColor.opacity(0.18)))

        // Knob at top of the playhead line.
        let knobR = max(height * 0.045, 3)
        let knobRect = CGRect(x: x - knobR, y: topPad - knobR, width: knobR * 2, height: knobR * 2)
        context.fill(Path(ellipseIn: knobRect), with: .color(playheadColor))
    }

    // MARK: - Color helpers (RGB literals only — no design-system / UIKit deps)

    private typealias RGB = (r: CGFloat, g: CGFloat, b: CGFloat)

    private var playheadColor: Color {
        Color(red: 0.99, green: 0.86, blue: 0.42)
    }

    private func barColor(played: Bool, bell: CGFloat) -> Color {
        let warm: RGB = (0.98, 0.74, 0.36)
        let cool: RGB = (0.40, 0.44, 0.58)
        let bright: RGB = (1.0, 0.97, 0.85)
        let base = played ? warm : cool
        let amount = min(bell, 1.0) * 0.45
        let m = mix(base, bright, amount)
        return Color(red: Double(m.r), green: Double(m.g), blue: Double(m.b))
    }

    private func mix(_ a: RGB, _ b: RGB, _ amount: CGFloat) -> RGB {
        let t = min(max(amount, 0), 1)
        return (
            a.r + (b.r - a.r) * t,
            a.g + (b.g - a.g) * t,
            a.b + (b.b - a.b) * t
        )
    }

    // MARK: - Falloff math

    /// Smooth bell-shaped falloff: peak 1 at distance 0, ~0 beyond `radius`.
    private func bellFalloff(distance: CGFloat, radius: CGFloat) -> CGFloat {
        guard radius > 0 else { return 0 }
        let x = distance / radius
        if x >= 1 { return 0 }
        let c = (cos(.pi * x) + 1) * 0.5 // cosine bell, no exp() needed
        return c * c
    }

    // MARK: - Static, precomputed data

    /// Triangle sweep 0→1→0 over a ~3.2s loop for demo mode.
    private static func sweep(_ t: TimeInterval) -> CGFloat {
        let period: TimeInterval = 3.2
        let phase = (t.truncatingRemainder(dividingBy: period)) / period // 0...1
        let tri = phase < 0.5 ? (phase * 2) : (2 - phase * 2) // 0→1→0
        let eased = tri * tri * (3 - 2 * tri) // smoothstep — lingers at the ends
        return CGFloat(eased)
    }

    /// Deterministic per-bar base amplitudes (0...1), computed ONCE. Stable across
    /// every frame — only position/height *modulation* is animated, never the source.
    private static let amplitudes: [CGFloat] = {
        var out: [CGFloat] = []
        out.reserveCapacity(42)
        for i in 0..<42 {
            let f = Double(i)
            // Layered sinusoids → an organic, audio-like envelope. Fully deterministic.
            let a = sin(f * 0.55) * 0.5 + 0.5
            let b = sin(f * 1.30 + 1.7) * 0.5 + 0.5
            let c = sin(f * 0.21 + 0.4) * 0.5 + 0.5
            var v = a * 0.45 + b * 0.30 + c * 0.25
            // Gentle overall arc so the middle reads a touch louder.
            let arc = sin(f / 41.0 * .pi)
            v = v * (0.55 + 0.45 * arc)
            out.append(CGFloat(min(max(v, 0.08), 1.0)))
        }
        return out
    }()
}
