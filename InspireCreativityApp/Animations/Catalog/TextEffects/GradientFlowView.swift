// catalog-id: tx-gradient-flow
import SwiftUI

/// Liquid Gradient Flow — a flowing multi-stop gradient travels through a text
/// mask with the colors warping along a sine path, so hues appear to pour and
/// swirl inside the glyphs rather than sweeping in a flat straight line.
///
/// - `demo == true`  : self-driving TimelineView loop (never blank, always legible).
/// - `demo == false` : same continuous flow (spec interaction is "auto"), with an
///                     optional, non-gating drag that nudges flow direction/phase.
struct GradientFlowView: View {
    var demo: Bool = false

    // Optional, non-gating interactive nudge. The TimelineView animates with or
    // without touch; the drag only adds a bias to the flow phase + direction.
    @State private var dragBias: CGFloat = 0
    @State private var directionBias: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            content(in: size)
                .frame(width: size.width, height: size.height)
                .contentShape(Rectangle())
                // Keep the gesture always attached; gate recognition with a mask.
                // A bare `demo ? nil : gesture` ternary would unify to
                // `Optional<Gesture>`, which does not conform to `Gesture`.
                .gesture(flowDrag(in: size), including: demo ? .none : .all)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Content

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let phase = flowPhase(at: timeline.date)
            ZStack {
                background(in: size)
                flowText(phase: phase, size: size)
            }
        }
    }

    private func background(in size: CGSize) -> some View {
        // Near-black tint from the spec (#04050a). A faint vignette adds depth
        // without ever competing with the bright glyph flow.
        let endRadius: CGFloat = Swift.max(size.width, size.height) * 0.7 + 1
        return ZStack {
            Color(red: 0.016, green: 0.020, blue: 0.039)
            RadialGradient(
                colors: [
                    Color(red: 0.06, green: 0.07, blue: 0.12).opacity(0.9),
                    Color(red: 0.016, green: 0.020, blue: 0.039)
                ],
                center: .center,
                startRadius: 0,
                endRadius: endRadius
            )
            .opacity(0.6)
        }
        .ignoresSafeArea()
    }

    // MARK: - Flowing, sine-warped color masked by the word

    @ViewBuilder
    private func flowText(phase: Double, size: CGSize) -> some View {
        let fontSize = glyphFontSize(for: size)

        ZStack {
            // A faint constant base so even the dimmest flow frame stays legible
            // against the near-black background.
            wordText(fontSize: fontSize)
                .foregroundStyle(Color(red: 0.30, green: 0.34, blue: 0.46).opacity(0.55))

            // The warped, pouring color, clipped to the glyph shapes.
            warpedFlowCanvas(phase: phase, size: size)
                .mask {
                    wordText(fontSize: fontSize)
                }
                .overlay {
                    // A soft meniscus-like sheen riding the flow for extra liquidity.
                    sheenCanvas(phase: phase, size: size)
                        .mask { wordText(fontSize: fontSize) }
                        .blendMode(.plusLighter)
                }
        }
        .frame(width: size.width, height: size.height)
    }

    private func wordText(fontSize: CGFloat) -> some View {
        Text(Self.word)
            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
            .kerning(fontSize * 0.02)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .multilineTextAlignment(.center)
    }

    // MARK: - Canvas: per-column vertical sine displacement = literal warp

    private func warpedFlowCanvas(phase: Double, size: CGSize) -> some View {
        Canvas { context, canvasSize in
            drawFlowBands(in: &context, size: canvasSize, phase: phase)
        }
        .drawingGroup()
    }

    /// Draws several angled, phase-shifted gradient bands whose columns are
    /// pushed up/down by a traveling sine, so the superposition reads as
    /// swirling liquid currents rather than a flat linear sweep.
    private func drawFlowBands(in context: inout GraphicsContext, size: CGSize, phase: Double) {
        let columns = 56
        let safeWidth = Swift.max(size.width, 1)
        let safeHeight = Swift.max(size.height, 1)
        let columnWidth = safeWidth / CGFloat(columns)
        let amplitude = safeHeight * 0.22

        for index in 0..<columns {
            let x = CGFloat(index) * columnWidth
            let normalizedX = Double(index) / Double(columns)

            // Two superimposed sine waves at different spatial frequencies give a
            // curved, non-repeating-looking flow front.
            let waveA = sin((normalizedX * 6.2) + phase + Double(directionBias))
            let waveB = sin((normalizedX * 3.1) - (phase * 0.7))
            let yOffset = amplitude * CGFloat((waveA * 0.6) + (waveB * 0.4))

            // The color sampled for this column scrolls through the palette,
            // sine-warped so hues pour and curve along the glyphs.
            let colorPhase = normalizedX + (Double(yOffset) / Double(safeHeight)) + (phase * 0.16)
            let color = flowColor(at: colorPhase)

            let columnRect = CGRect(
                x: x - 0.5,
                y: (safeHeight * 0.5) + yOffset - (safeHeight * 0.9),
                width: columnWidth + 1.0,
                height: safeHeight * 1.8
            )
            context.fill(Path(columnRect), with: .color(color))
        }
    }

    /// A thin bright sheen band that travels across the flow, adding a liquid
    /// highlight without ever darkening any frame.
    private func sheenCanvas(phase: Double, size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let center = (sin(phase * 0.8) * 0.5 + 0.5) * Double(canvasSize.width)
            let bandWidth = canvasSize.width * 0.28
            let rect = CGRect(
                x: CGFloat(center) - bandWidth / 2,
                y: 0,
                width: bandWidth,
                height: canvasSize.height
            )
            let gradient = Gradient(stops: [
                .init(color: .white.opacity(0.0), location: 0.0),
                .init(color: .white.opacity(0.45), location: 0.5),
                .init(color: .white.opacity(0.0), location: 1.0)
            ])
            context.fill(
                Path(rect),
                with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: rect.minX, y: 0),
                    endPoint: CGPoint(x: rect.maxX, y: 0)
                )
            )
        }
        .drawingGroup()
    }

    // MARK: - Palette

    /// A wide, looping, bright multi-stop palette. Always saturated so glyphs
    /// never blend into the near-black background on any frame. The phase wraps
    /// through the stops; first and last hue match for a seamless cycle.
    private func flowColor(at rawPhase: Double) -> Color {
        let stops = Self.paletteStops
        let count = stops.count
        let safe = rawPhase.isFinite ? rawPhase : 0
        let wrapped = safe - floor(safe) // 0..<1
        let scaled = wrapped * Double(count - 1)
        let lowerIndex = Int(floor(scaled))
        let upperIndex = min(lowerIndex + 1, count - 1)
        let t = scaled - Double(lowerIndex)

        let lower = stops[lowerIndex]
        let upper = stops[upperIndex]
        return lerp(lower, upper, CGFloat(t))
    }

    private func lerp(_ a: RGB, _ b: RGB, _ t: CGFloat) -> Color {
        Color(
            red: Double(a.r + (b.r - a.r) * t),
            green: Double(a.g + (b.g - a.g) * t),
            blue: Double(a.b + (b.b - a.b) * t)
        )
    }

    // MARK: - Phase & sizing

    /// Maps wall-clock time to a continuous flow phase, biased by any drag.
    /// Targets a calm, liquid pace; the sine inside the Canvas keeps the loop seamless.
    private func flowPhase(at date: Date) -> Double {
        let t = date.timeIntervalSinceReferenceDate
        let speed = 0.95 // radians per second of base scroll
        return (t * speed) + Double(dragBias)
    }

    private func glyphFontSize(for size: CGSize) -> CGFloat {
        let basis = min(size.width, size.height)
        // Scale to fit a short heavy word in both a ~120pt tile and a large area.
        return Swift.max(18, basis * 0.42)
    }

    // MARK: - Optional non-gating interaction

    private func flowDrag(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let dx = value.translation.width / Swift.max(size.width, 1)
                let dy = value.translation.height / Swift.max(size.height, 1)
                withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.8)) {
                    dragBias = CGFloat(dx) * 3.0
                    directionBias = CGFloat(dy) * 2.2
                }
            }
            .onEnded { _ in
                withAnimation(.spring(response: 1.2, dampingFraction: 0.9)) {
                    dragBias = 0
                    directionBias = 0
                }
            }
    }

    // MARK: - Constants

    private static let word = "FLOW"

    struct RGB { let r: CGFloat; let g: CGFloat; let b: CGFloat }

    /// Bright, saturated liquid palette. Index 0 == last index for a seamless wrap.
    private static let paletteStops: [RGB] = [
        RGB(r: 0.31, g: 0.78, b: 0.98), // cyan
        RGB(r: 0.45, g: 0.55, b: 0.99), // periwinkle
        RGB(r: 0.74, g: 0.45, b: 0.98), // violet
        RGB(r: 0.99, g: 0.43, b: 0.74), // pink
        RGB(r: 0.99, g: 0.62, b: 0.40), // coral
        RGB(r: 0.98, g: 0.86, b: 0.40), // gold
        RGB(r: 0.42, g: 0.93, b: 0.74), // mint
        RGB(r: 0.31, g: 0.78, b: 0.98)  // cyan (== first, seamless)
    ]
}
