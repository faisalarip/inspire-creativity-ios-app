// catalog-id: ges-accordion-fold-list
import SwiftUI

// MARK: - Public View

/// Accordion Fold Reveal — drag the header down and the panel below unfolds in
/// accordion bellows. Each pleat hinges about its top edge with alternating
/// angles, and its gradient brightness is keyed to its signed fold angle so a
/// glint travels down the stack as it opens — reading as a 3D paper bellows
/// rather than a height animation.
struct AccordionFoldListView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            if demo {
                DemoDriver(size: geo.size)
            } else {
                InteractiveBellows(size: geo.size)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Demo (self-driving)

private struct DemoDriver: View {
    let size: CGSize

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            BellowsStack(unfold: Self.wave(at: t), size: size)
        }
    }

    /// Smooth 0 → 1 → 0 ease over a ~3.4s loop. Holds briefly open/closed so the
    /// glint can travel and the eye can read the bellows at the extremes.
    static func wave(at time: TimeInterval) -> CGFloat {
        let period: Double = 3.4
        let phase = (time.truncatingRemainder(dividingBy: period)) / period
        // Triangle wave 0→1→0 then ease for organic accel/decel.
        let tri = phase < 0.5 ? phase * 2.0 : (1.0 - phase) * 2.0
        let eased = tri * tri * (3.0 - 2.0 * tri) // smoothstep
        return CGFloat(eased)
    }
}

// MARK: - Interactive

private struct InteractiveBellows: View {
    let size: CGSize

    @State private var unfold: CGFloat = 0
    @State private var dragBase: CGFloat = 0
    @State private var snapTarget: Int = 0

    var body: some View {
        BellowsStack(unfold: unfold, size: size)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .sensoryFeedback(.impact(weight: .light), trigger: snapTarget)
    }

    private var travel: CGFloat { max(size.height * 0.9, 80) }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let delta = value.translation.height / travel
                unfold = clamp(dragBase + delta)
            }
            .onEnded { _ in
                let open = unfold > 0.5
                dragBase = open ? 1 : 0
                snapTarget = open ? 1 : 0
                withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) {
                    unfold = open ? 1 : 0
                }
            }
    }

    private func clamp(_ v: CGFloat) -> CGFloat { min(max(v, 0), 1) }
}

// MARK: - Bellows Stack (shared render path)

private struct BellowsStack: View {
    /// Global unfold progress 0 (folded) → 1 (open).
    let unfold: CGFloat
    let size: CGSize

    private let pleatCount = 6

    var body: some View {
        let layout = BellowsLayout(size: size, pleatCount: pleatCount)

        VStack(spacing: 0) {
            Header(progress: unfold, layout: layout)

            VStack(spacing: layout.pleatGap) {
                ForEach(0..<pleatCount, id: \.self) { index in
                    PleatStrip(
                        index: index,
                        localProgress: localProgress(for: index),
                        layout: layout
                    )
                }
            }
            .padding(.top, layout.pleatGap)

            Spacer(minLength: 0)
        }
        .padding(layout.outerPadding)
    }

    /// Per-pleat staggered progress: pleat `i` opens after the ones above it,
    /// so a glint travels down the stack ("fold count tied to drag distance").
    private func localProgress(for index: Int) -> CGFloat {
        let n = CGFloat(pleatCount)
        // Overlap the windows a little for a continuous wave.
        let raw = unfold * (n + 0.6) - CGFloat(index)
        return min(max(raw / 1.2, 0), 1)
    }
}

// MARK: - Pleat Strip

private struct PleatStrip: View {
    let index: Int
    /// 0 = fully folded shut, 1 = fully open & flat.
    let localProgress: CGFloat
    let layout: BellowsLayout

    var body: some View {
        // Signed fold angle: alternating sign gives the zig-zag bellows; the
        // sign is what makes neighbouring pleats catch light bright/dark.
        let signedAngle = angle * (index.isMultiple(of: 2) ? 1.0 : -1.0)

        Capsule(style: .continuous)
            .fill(gradient(for: signedAngle))
            .overlay(seam)
            .overlay(spineHighlight(for: signedAngle))
            // Crucial: interpolate the *layout* height by foreshortening so
            // folded pleats compress flush instead of leaving gaps.
            .frame(height: foreshortenedHeight)
            .rotation3DEffect(
                .degrees(signedAngle),
                axis: (x: 1, y: 0, z: 0),
                anchor: .top,
                perspective: 0.65
            )
            .shadow(
                color: .black.opacity(0.28 * Double(1 - localProgress)),
                radius: 3, x: 0, y: 2
            )
    }

    // Folded → steep hinge angle; open → flat (0°).
    private var angle: Double {
        let maxAngle: Double = 78
        return maxAngle * Double(1 - localProgress)
    }

    private var foreshortenedHeight: CGFloat {
        let full = layout.pleatHeight
        let foreshorten = CGFloat(cos(angle * .pi / 180))
        // Floor so a folded pleat still shows a legible edge — never 0.
        return max(full * foreshorten, layout.pleatFloor)
    }

    private func gradient(for signedAngle: Double) -> LinearGradient {
        // Brightness keyed to signed angle: a pleat tilting toward the light
        // (positive) brightens; one tilting away darkens. This is the glint.
        let glint = signedAngle / 78.0 // -1 ... 1
        let base: Double = 0.46
        let top = clampD(base + 0.40 * glint)
        let bottom = clampD(base - 0.22 * glint)
        return LinearGradient(
            colors: [
                paper(top + 0.10),
                paper(top),
                paper(bottom)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var seam: some View {
        // Crisp top fold line where the pleat hinges.
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.22 * Double(1 - localProgress) + 0.05))
                .frame(height: 1)
            Spacer(minLength: 0)
        }
        .clipShape(Capsule(style: .continuous))
    }

    private func spineHighlight(for signedAngle: Double) -> some View {
        // A soft sheen sweeping across the pleat, strongest as it catches light.
        let intensity = max(0, signedAngle / 78.0)
        return Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        .white.opacity(0.0),
                        .white.opacity(0.30 * Double(intensity)),
                        .white.opacity(0.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .blendMode(.screen)
    }

    private func paper(_ luma: Double) -> Color {
        // Warm-cool paper tone shifting with luminance for a tactile stock.
        let l = clampD(luma)
        return Color(
            red: 0.30 + 0.62 * l,
            green: 0.33 + 0.58 * l,
            blue: 0.42 + 0.52 * l
        )
    }

    private func clampD(_ v: Double) -> Double { min(max(v, 0), 1) }
}

// MARK: - Header

private struct Header: View {
    let progress: CGFloat
    let layout: BellowsLayout

    var body: some View {
        HStack(spacing: layout.headerFont * 0.5) {
            Image(systemName: "rectangle.expand.vertical")
                .font(.system(size: layout.headerFont * 0.9, weight: .semibold))
                .rotationEffect(.degrees(Double(progress) * 180))
                .foregroundStyle(.white.opacity(0.92))

            Text("Bellows")
                .font(.system(size: layout.headerFont, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Spacer(minLength: 0)

            Image(systemName: "chevron.down")
                .font(.system(size: layout.headerFont * 0.78, weight: .bold))
                .rotationEffect(.degrees(Double(progress) * -180))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, layout.headerFont * 0.8)
        .frame(height: layout.headerHeight)
        .background(
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hexCode: 0x3A4A86),
                            Color(hexCode: 0x222B52)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Layout

private struct BellowsLayout {
    let size: CGSize
    let pleatCount: Int

    var minSide: CGFloat { min(size.width, size.height) }
    var outerPadding: CGFloat { max(minSide * 0.06, 4) }

    private var content: CGSize {
        CGSize(width: size.width - outerPadding * 2,
               height: size.height - outerPadding * 2)
    }

    var headerHeight: CGFloat { max(content.height * 0.16, 22) }
    var headerFont: CGFloat { max(headerHeight * 0.42, 9) }

    var pleatGap: CGFloat { max(content.height * 0.012, 1.5) }

    /// Full (open) height of one pleat — fills the remaining area when open.
    var pleatHeight: CGFloat {
        let n = CGFloat(pleatCount)
        let avail = content.height - headerHeight - pleatGap * (n + 1)
        return max(avail / n, 6)
    }

    /// Minimum visible height of a folded pleat so the stack never collapses
    /// to nothing — keeps a legible compact edge.
    var pleatFloor: CGFloat { max(pleatHeight * 0.22, 3) }
}

// MARK: - Color hex helper

private extension Color {
    init(hexCode hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

// MARK: - Preview
