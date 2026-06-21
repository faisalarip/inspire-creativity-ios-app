// catalog-id: btn-ink-bleed-toggle
import SwiftUI

// MARK: - Ink Bleed Toggle
// Toggling drops ink that bleeds outward through irregular feathered edges to
// flood the button in the new color, like dye spreading on wet paper.
// Pure SwiftUI: an opaque base color underneath, a top color revealed through a
// blurred, angularly-irregular blob mask grown from the touch point. No shader.

struct InkBleedToggleView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            InkBleedToggleView_InkBleedContent(demo: demo, size: geo.size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Button layout (relative to the available size)

private struct InkBleedToggleView_ButtonLayout {
    let rect: CGRect
    let cornerRadius: CGFloat

    init(size: CGSize) {
        let w = max(size.width, 1)
        let h = max(size.height, 1)
        // Inset a little so the drop shadow + bezel breathe inside the tile.
        let bw = w * 0.82
        let bh = min(h * 0.62, bw * 0.46)
        let boxW = min(bw, w - 8)
        let boxH = min(max(bh, 28), h - 8)
        // 0-based, button-local rect. The button is centered in the available
        // size by body's .frame + .position, so all ink math stays in this
        // local space (origin, blob center, clamping, corner distance).
        rect = CGRect(
            x: 0,
            y: 0,
            width: boxW,
            height: boxH
        )
        cornerRadius = min(boxW, boxH) * 0.28
    }

    var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}

// MARK: - Content

private struct InkBleedToggleView_InkBleedContent: View {
    let demo: Bool
    let size: CGSize

    // Toggle state: false = "off" color showing, true = "on" color showing.
    @State private var isOn: Bool = false
    // Normalized bleed progress 0...1 (0 = blob fully receded, 1 = fully flooded).
    @State private var progress: CGFloat = 0
    // Where the ink drops from, in this view's coordinate space.
    @State private var origin: CGPoint = .zero
    // Stable per-instance seed so the irregular rim never boils between frames.
    @State private var seed: CGFloat = CGFloat.random(in: 0..<1000)
    // Drives the .selection haptic on interactive taps.
    @State private var feedbackTick: Int = 0
    // Tracks whether the interactive origin has been seeded yet.
    @State private var didSeedOrigin: Bool = false

    var body: some View {
        let layout = InkBleedToggleView_ButtonLayout(size: size)

        ZStack {
            if demo {
                demoButton(layout)
            } else {
                interactiveButton(layout)
            }
        }
        .frame(width: layout.rect.width, height: layout.rect.height)
        .position(x: size.width / 2, y: size.height / 2)
        .onAppear {
            // Default the interactive origin to the button center (local space).
            if !didSeedOrigin {
                origin = CGPoint(x: layout.rect.midX, y: layout.rect.midY)
                didSeedOrigin = true
            }
        }
    }

    // MARK: Interactive (demo == false)

    private func interactiveButton(_ layout: InkBleedToggleView_ButtonLayout) -> some View {
        inkSurface(layout: layout, origin: origin, progress: progress, isOn: isOn)
            .contentShape(layout.shape)
            .gesture(
                SpatialTapGesture(coordinateSpace: .local)
                    .onEnded { value in
                        origin = clampedOrigin(value.location, in: layout.rect)
                        isOn.toggle()
                        feedbackTick &+= 1
                        withAnimation(.easeOut(duration: 0.6)) {
                            progress = isOn ? 1 : 0
                        }
                    }
            )
            .sensoryFeedbackCompat(trigger: feedbackTick)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Ink bleed toggle")
            .accessibilityValue(isOn ? "On" : "Off")
            .accessibilityAddTraits(.isButton)
    }

    // MARK: Demo (demo == true) — self-driving, never blank

    private func demoButton(_ layout: InkBleedToggleView_ButtonLayout) -> some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = demoPhase(at: t, rect: layout.rect)
            inkSurface(
                layout: layout,
                origin: phase.origin,
                progress: phase.progress,
                isOn: phase.isOn
            )
        }
    }

    // A ~3s loop: bloom in (flood new color), hold, bleed back, hold.
    // The drop point shifts each half-cycle so the irregular feathering shows.
    private func demoPhase(at time: TimeInterval, rect: CGRect) -> (origin: CGPoint, progress: CGFloat, isOn: Bool) {
        let period: TimeInterval = 3.0
        let local = time.truncatingRemainder(dividingBy: period) / period // 0..1

        // Two drop points that alternate so the bloom reads as "from a point".
        let dropA = CGPoint(x: rect.minX + rect.width * 0.30, y: rect.midY)
        let dropB = CGPoint(x: rect.minX + rect.width * 0.72, y: rect.midY)

        var p: CGFloat
        var on: Bool
        var pt: CGPoint

        if local < 0.4 {
            // Bloom in from dropA -> flooded "on".
            p = easeOut(CGFloat(local / 0.4))
            on = true
            pt = dropA
        } else if local < 0.5 {
            // Hold flooded.
            p = 1
            on = true
            pt = dropA
        } else if local < 0.9 {
            // Bleed back from dropB -> "off".
            p = easeOut(CGFloat((local - 0.5) / 0.4))
            on = false
            pt = dropB
        } else {
            // Hold receded.
            p = 1
            on = false
            pt = dropB
        }
        return (pt, p, on)
    }

    private func easeOut(_ x: CGFloat) -> CGFloat {
        let c = min(max(x, 0), 1)
        return 1 - (1 - c) * (1 - c)
    }

    // MARK: Shared ink surface

    // Base = the color the button settles toward as progress recedes.
    // Top  = the color flooding in via the blob mask.
    // When isOn: top = onColor over base offColor (blob reveals onColor).
    // When !isOn: top = offColor over base onColor (blob reveals offColor).
    private func inkSurface(layout: InkBleedToggleView_ButtonLayout, origin: CGPoint, progress: CGFloat, isOn: Bool) -> some View {
        let baseColor = isOn ? Self.offColor : Self.onColor
        let topColor = isOn ? Self.onColor : Self.offColor
        let baseLabel = isOn ? Self.offLabel : Self.onLabel
        let topLabel = isOn ? Self.onLabel : Self.offLabel

        // Coverage radius must reach the farthest corner from the origin so an
        // off-center / corner drop still floods the entire button.
        let full = maxCornerDistance(from: origin, in: layout.rect)
        let radius = progress * full
        // Constant feather (not scaled with radius) keeps the blob center opaque.
        let feather: CGFloat = min(layout.rect.width, layout.rect.height) * 0.07 + 3
        let rimVisible = progress > 0.02 && progress < 0.98

        return ZStack {
            // 1. Opaque base — never blank on any frame.
            layout.shape.fill(paper(baseColor))
            label(baseLabel, color: baseColor)

            // 2. Top color revealed through the blurred irregular blob mask.
            ZStack {
                layout.shape.fill(paper(topColor))
                label(topLabel, color: topColor)
            }
            .mask(
                InkBleedToggleView_InkBlobShape(radius: radius, center: origin, seed: seed)
                    .blur(radius: feather)
            )

            // 3. Wet-paper rim sheen on the advancing front for organic feel.
            InkBleedToggleView_InkBlobShape(radius: radius, center: origin, seed: seed)
                .stroke(Color.white.opacity(rimVisible ? 0.10 : 0), lineWidth: 2)
                .blur(radius: feather * 0.8)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        }
        .clipShape(layout.shape) // ink must not bleed past the bezel
        .overlay(
            layout.shape.strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.28), radius: 10, x: 0, y: 6)
        .compositingGroup()
    }

    private func label(_ text: String, color: Color) -> some View {
        let fontSize: CGFloat = max(11, min(size.width, size.height) * 0.085)
        return Text(text)
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .foregroundColor(readableText(on: color))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 8)
    }

    // MARK: Geometry helpers

    private func clampedOrigin(_ p: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(p.x, rect.minX), rect.maxX),
            y: min(max(p.y, rect.minY), rect.maxY)
        )
    }

    private func maxCornerDistance(from p: CGPoint, in rect: CGRect) -> CGFloat {
        let corners: [CGPoint] = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY)
        ]
        var maxD: CGFloat = 0
        for c in corners {
            let dx: CGFloat = c.x - p.x
            let dy: CGFloat = c.y - p.y
            let d: CGFloat = (dx * dx + dy * dy).squareRoot()
            if d > maxD { maxD = d }
        }
        // Pad slightly so the blurred edge fully clears the corner.
        return maxD + 12
    }

    // MARK: Color helpers

    private func paper(_ base: Color) -> LinearGradient {
        LinearGradient(
            colors: [base.opacity(1.0), base.opacity(0.88)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func readableText(on color: Color) -> Color {
        // Both palette colors are mid/dark dye tones, so light text reads on both.
        Color(red: 0.97, green: 0.96, blue: 0.93)
    }

    // MARK: Palette (literals only)

    // "Off" — desaturated slate ink on paper.
    static let offColor = Color(red: 0.20, green: 0.26, blue: 0.34)
    // "On" — a rich indigo/violet dye it bleeds into.
    static let onColor = Color(red: 0.42, green: 0.24, blue: 0.62)

    static let offLabel = "Draft"
    static let onLabel = "Saved"
}

// MARK: - Ink Blob Shape
// An irregular, angularly-modulated blob whose rim lobes are seeded ONCE per
// instance (passed in via `seed`) — no per-frame randomness, so the edge never
// boils. `animatableData` maps to radius for smooth interactive growth.

private struct InkBleedToggleView_InkBlobShape: Shape {
    var radius: CGFloat
    var center: CGPoint
    var seed: CGFloat

    var animatableData: CGFloat {
        get { radius }
        set { radius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard radius > 0.5 else { return path }

        let steps = 72
        // Three sine harmonics with seed-derived phases create capillary lobes.
        let ph1: CGFloat = seed.truncatingRemainder(dividingBy: 6.283)
        let ph2: CGFloat = (seed * 1.7).truncatingRemainder(dividingBy: 6.283)
        let ph3: CGFloat = (seed * 2.9).truncatingRemainder(dividingBy: 6.283)

        for i in 0...steps {
            let frac = CGFloat(i) / CGFloat(steps)
            let angle = frac * 2 * .pi

            // Angular radius modulation — magnitude eases off as the blob grows
            // large so the final flood reads as full coverage, not a lumpy edge.
            let growth: CGFloat = min(radius / 60.0, 1.0)
            let wobbleScale: CGFloat = 0.16 - 0.10 * growth // 0.16 small -> 0.06 large
            let lobes: CGFloat =
                sin(angle * 3 + ph1) * 0.55 +
                sin(angle * 5 + ph2) * 0.30 +
                sin(angle * 8 + ph3) * 0.15
            let r: CGFloat = radius * (1 + wobbleScale * lobes)

            let x = center.x + cos(angle) * r
            let y = center.y + sin(angle) * r
            let pt = CGPoint(x: x, y: y)
            if i == 0 {
                path.move(to: pt)
            } else {
                path.addLine(to: pt)
            }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Sensory feedback compatibility shim
// sensoryFeedback(_:trigger:) is iOS 17+, which matches the deployment target,
// but we guard defensively so the view also compiles on earlier toolchains.

private extension View {
    @ViewBuilder
    func sensoryFeedbackCompat(trigger: Int) -> some View {
        if #available(iOS 17.0, *) {
            self.sensoryFeedback(.selection, trigger: trigger)
        } else {
            self
        }
    }
}
