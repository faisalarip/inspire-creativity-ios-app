// catalog-id: btn-blinds-reveal
import SwiftUI

/// Blinds Reveal — a tappable button whose face is built from horizontal
/// venetian-blind slats. On tap the slats twist open one louvre at a time
/// (staggered), flipping from the idle label to the success label, then
/// twist closed again.
///
/// `demo == true`  → self-driving loop that auto-sweeps open/closed on a
///                   ~3s cadence with end-state dwell, so the tile is alive
///                   with no touch and never blank.
/// `demo == false` → real interactive button: tap toggles the reveal with a
///                   staggered ease, plus `.selection` haptic feedback.
public struct BlindsRevealView: View {
    public var demo: Bool = false

    public init(demo: Bool = false) {
        self.demo = demo
    }

    public var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if demo {
            DemoBlinds(size: size)
        } else {
            InteractiveBlinds(size: size)
        }
    }
}

// MARK: - Tunables

private enum Blinds {
    static let slatCount: Int = 9
    /// Per-slat stagger as a fraction of the global progress range.
    static let stagger: Double = 0.55
    /// rotation3DEffect perspective.
    static let perspective: CGFloat = 0.42
    /// Loop duration for the demo (seconds): dwell + sweep + dwell + sweep-back.
    static let loop: Double = 3.0
}

// MARK: - Demo (self-driving)

private struct DemoBlinds: View {
    let size: CGSize

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            BlindsFace(progress: demoProgress(at: t), size: size)
        }
    }

    /// Triangle wave with plateaus at 0 and 1 so each label sits still long
    /// enough to read before the sweep. Output stays in [0, 1] every frame.
    private func demoProgress(at time: TimeInterval) -> Double {
        let phase = (time.truncatingRemainder(dividingBy: Blinds.loop)) / Blinds.loop
        let dwell: Double = 0.18      // fraction held at each end
        let sweep: Double = 0.5 - dwell
        switch phase {
        case ..<dwell:
            return 0
        case ..<(dwell + sweep):
            let local = (phase - dwell) / sweep
            return eased(local)
        case ..<(dwell + sweep + dwell):
            return 1
        default:
            let local = (phase - (dwell + sweep + dwell)) / sweep
            return eased(1 - local)
        }
    }

    private func eased(_ x: Double) -> Double {
        // smoothstep
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }
}

// MARK: - Interactive (tap)

private struct InteractiveBlinds: View {
    let size: CGSize

    @State private var revealed: Bool = false

    private var progress: Double { revealed ? 1 : 0 }

    var body: some View {
        BlindsFace(progress: progress, size: size)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.7)) {
                    revealed.toggle()
                }
            }
            .sensoryFeedback(.selection, trigger: revealed)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(revealed ? "Done" : "Place Order")
    }
}

// MARK: - The slatted face

/// Renders the full button face as `slatCount` horizontal bands, each band a
/// clipped window onto one shared idle/success face, rotated about its x-axis
/// by a per-slat angle derived from a single global `progress`.
///
/// Conforms to `Animatable` so that in the interactive path `withAnimation`
/// interpolates `progress` itself frame-by-frame. The per-slat stagger and the
/// edge-on opacity hand-off are baked into the renderer and only emerge at
/// intermediate progress values — without this conformance a 0→1 step would
/// flip every louvre in unison and pop the success label upside-down.
private struct BlindsFace: View, Animatable {
    /// 0 = idle (slats flat, idle label), 1 = success (slats flat, success label).
    var progress: Double
    let size: CGSize

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let metrics = Metrics(size: size)
        ZStack {
            basePanel(metrics)
            slats(metrics)
        }
        .frame(width: metrics.width, height: metrics.height)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // Static panel behind the slats so the tile is never blank when a slat
    // passes edge-on through 90°.
    private func basePanel(_ m: Metrics) -> some View {
        RoundedRectangle(cornerRadius: m.corner, style: .continuous)
            .fill(Self.tint.opacity(0.55))
            .overlay(
                RoundedRectangle(cornerRadius: m.corner, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }

    private func slats(_ m: Metrics) -> some View {
        VStack(spacing: m.gap) {
            ForEach(0..<Blinds.slatCount, id: \.self) { i in
                Slat(
                    index: i,
                    angle: angle(for: i),
                    metrics: m
                )
            }
        }
        .frame(width: m.width, height: m.height)
        .clipShape(RoundedRectangle(cornerRadius: m.corner, style: .continuous))
    }

    /// Each slat's rotation angle. Stagger is baked into the math (not
    /// `.animation(delay:)`) so the demo TimelineView and the interactive
    /// withAnimation paths share one renderer.
    private func angle(for index: Int) -> Double {
        let n = Double(Blinds.slatCount)
        let span = 1.0 + Blinds.stagger * (n - 1) / n
        let raw = progress * span - Double(index) * (Blinds.stagger / n)
        let local = min(max(raw, 0), 1)
        let smooth = local * local * (3 - 2 * local) // smoothstep
        return smooth * 180.0
    }

    static let tint = Color(hexCode: 0x16120E)
}

// MARK: - One slat (one horizontal band of the face)

private struct Slat: View {
    let index: Int
    /// 0…180°. <90° shows idle band, ≥90° shows success band.
    let angle: Double
    let metrics: Metrics

    var body: some View {
        ZStack {
            faceBand(success: false)
                .opacity(angle < 90 ? 1 : 0)

            faceBand(success: true)
                // Pre-counter-rotate so the success label reads upright after
                // the slat completes its 180° flip (back face would otherwise
                // be mirrored/upside-down).
                .rotation3DEffect(.degrees(180), axis: (x: 1, y: 0, z: 0))
                .opacity(angle >= 90 ? 1 : 0)
        }
        .frame(width: metrics.width, height: metrics.slatHeight)
        .clipped()
        .overlay(shading)
        .rotation3DEffect(
            .degrees(angle),
            axis: (x: 1, y: 0, z: 0),
            anchor: .center,
            perspective: Blinds.perspective
        )
    }

    /// A horizontal band cut from the full-size face. The face is drawn at full
    /// button height, then offset up by this slat's row so the band lines up to
    /// reassemble the complete label.
    private func faceBand(success: Bool) -> some View {
        FullFace(success: success, metrics: metrics)
            .frame(width: metrics.width, height: metrics.height)
            .offset(y: -metrics.rowOffset(index))
    }

    // Directional light: bands tilt toward/away from a top light source, so the
    // sweep catches the light louvre-by-louvre instead of reading as a fade.
    private var shading: some View {
        let a = angle * .pi / 180
        let lit = max(0, cos(a))      // brightest when flat-facing
        let dark = max(0, -cos(a))    // back face darkens
        return LinearGradient(
            colors: [
                Color.white.opacity(0.16 * lit),
                Color.clear,
                Color.black.opacity(0.30 * dark + 0.10)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }
}

// MARK: - The full button face (idle or success), drawn once per band

private struct FullFace: View {
    let success: Bool
    let metrics: Metrics

    var body: some View {
        ZStack {
            background
            label
        }
    }

    private var background: some View {
        let colors: [Color] = success
            ? [Color(hexCode: 0x1FA463), Color(hexCode: 0x0E7A45)]
            : [Color(hexCode: 0x3A2E1E), Color(hexCode: 0x231B12)]
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var label: some View {
        HStack(spacing: metrics.iconGap) {
            Image(systemName: success ? "checkmark.circle.fill" : "bag.fill")
            Text(success ? "Done" : "Place Order")
        }
        .font(.system(size: metrics.fontSize, weight: .semibold, design: .rounded))
        .foregroundStyle(success ? Color.white : Color(hexCode: 0xF3E7D2))
        .lineLimit(1)
        .minimumScaleFactor(0.4)
        .padding(.horizontal, metrics.hPad)
        .frame(width: metrics.width, height: metrics.height)
    }
}

// MARK: - Layout metrics (all derived from the tile size)

private struct Metrics {
    let width: CGFloat
    let height: CGFloat
    let slatHeight: CGFloat
    let gap: CGFloat
    let corner: CGFloat
    let fontSize: CGFloat
    let hPad: CGFloat
    let iconGap: CGFloat

    init(size: CGSize) {
        // The button occupies most of the tile, centered, with a sensible
        // aspect so it reads as a button in both a ~120pt tile and a big detail.
        let availW = max(size.width, 1)
        let availH = max(size.height, 1)
        let w = min(availW * 0.86, availH * 2.6)
        let h = min(availH * 0.46, w * 0.42)
        self.width = max(w, 1)
        self.height = max(h, 1)

        let n = CGFloat(Blinds.slatCount)
        self.gap = max(self.height * 0.012, 0.5)
        let totalGap = gap * (n - 1)
        self.slatHeight = max((self.height - totalGap) / n, 1)

        self.corner = self.height * 0.22
        self.fontSize = max(self.height * 0.30, 9)
        self.hPad = self.width * 0.06
        self.iconGap = self.fontSize * 0.4
    }

    /// Top y-position of slat `index` inside the full face (accounts for gaps),
    /// used to offset the full label so each band reassembles the whole word.
    func rowOffset(_ index: Int) -> CGFloat {
        CGFloat(index) * (slatHeight + gap)
    }
}

// MARK: - Hex color helper (no app dependencies)

private extension Color {
    init(hexCode hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

// MARK: - Previews
