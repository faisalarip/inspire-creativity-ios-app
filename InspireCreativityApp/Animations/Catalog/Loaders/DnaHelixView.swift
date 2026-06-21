// catalog-id: ld-dna-helix
import SwiftUI

/// DNA Helix — two phosphate strands corkscrew as a double helix with base-pair
/// rungs. Each strand node's horizontal position is a sine of its vertical phase,
/// and each rung's width/opacity scales by the cosine of that phase to fake 3D
/// depth, with nearer rungs drawn on top.
///
/// - `demo == true`: a self-driving `TimelineView(.animation)` corkscrews the
///   helix continuously, the depth scaling pulsing the rungs.
/// - `demo == false`: the same idle spin runs, but a horizontal `DragGesture`
///   scrubs the twist phase (move faster to scrub faster, direction sets sign);
///   releasing hands control back to the idle spin with no visible jump.
struct DnaHelixView: View {
    var demo: Bool = false

    // Committed twist accumulated from prior auto segments + finished drags.
    @State private var committedPhase: Double = 0
    // Wall-clock anchor for the current auto-spin segment.
    @State private var segmentStart: Date = .init()
    // Live horizontal drag translation (points) while a finger is down.
    @State private var dragWidth: CGFloat = 0
    // True while a finger is actively scrubbing.
    @State private var dragging: Bool = false

    // Visual constants.
    private let rungCount: Int = 18
    private let autoSpeed: Double = 1.05          // radians / second idle spin
    private let twists: Double = 2.4              // full turns across the height
    private let scrubSensitivity: Double = 0.012  // radians per drag point

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            TimelineView(.animation) { context in
                let phase = currentPhase(now: context.date)
                helixCanvas(size: size, phase: phase)
            }
            .contentShape(Rectangle())
            .modifier(
                DnaHelixView_ScrubGesture(
                    enabled: !demo,
                    onChanged: { translation in handleDragChanged(translation) },
                    onEnded: { handleDragEnded() }
                )
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Phase bookkeeping (seamless auto <-> drag hand-off)

    private func currentPhase(now: Date) -> Double {
        let auto = dragging ? 0 : now.timeIntervalSince(segmentStart) * autoSpeed
        let scrub = Double(dragWidth) * scrubSensitivity
        return committedPhase + auto + scrub
    }

    private func handleDragChanged(_ translation: CGSize) {
        if !dragging {
            // Lock in the auto-spin accrued up to this instant, then freeze it.
            let elapsed = Date().timeIntervalSince(segmentStart) * autoSpeed
            committedPhase += elapsed
            dragging = true
        }
        dragWidth = translation.width
    }

    private func handleDragEnded() {
        committedPhase += Double(dragWidth) * scrubSensitivity
        dragWidth = 0
        dragging = false
        segmentStart = Date()
    }

    // MARK: - Rendering

    private func helixCanvas(size: CGSize, phase: Double) -> some View {
        Canvas { ctx, canvasSize in
            drawHelix(into: &ctx, size: canvasSize, phase: phase)
        }
    }

    private func drawHelix(into ctx: inout GraphicsContext, size: CGSize, phase: Double) {
        let w: CGFloat = size.width
        let h: CGFloat = size.height
        guard w > 1, h > 1 else { return }

        let centerX: CGFloat = w / 2
        let inset: CGFloat = max(8, min(w, h) * 0.10)
        let amplitude: CGFloat = max(6, (w / 2) - inset)
        let topY: CGFloat = inset
        let usableHeight: CGFloat = max(1, h - inset * 2)
        let freq: Double = twists * 2 * .pi  // radians across normalized [0,1]

        // Build rung descriptors, then sort so the back-facing ones draw first.
        var rungs: [Rung] = []
        rungs.reserveCapacity(rungCount)
        let count = rungCount
        for i in 0..<count {
            let t: Double = count > 1 ? Double(i) / Double(count - 1) : 0.5
            let y: CGFloat = topY + CGFloat(t) * usableHeight
            let angle: Double = t * freq + phase

            // Strand A and B are half a turn apart.
            let offsetA: CGFloat = CGFloat(sin(angle)) * amplitude
            let offsetB: CGFloat = CGFloat(sin(angle + .pi)) * amplitude
            // Depth term from cosine: +1 = front, -1 = back.
            let depth: Double = cos(angle)

            rungs.append(
                Rung(
                    y: y,
                    xA: centerX + offsetA,
                    xB: centerX + offsetB,
                    depth: depth,
                    nodeRadius: nodeRadius(forHeight: h),
                    hue: t
                )
            )
        }

        // Painter's algorithm: smallest depth (furthest back) first.
        rungs.sort { $0.depth < $1.depth }

        for rung in rungs {
            drawRung(rung, into: &ctx, height: h)
        }
    }

    private func drawRung(_ rung: Rung, into ctx: inout GraphicsContext, height: CGFloat) {
        // Map depth (-1...1) to legible, clamped scale & opacity (never blank).
        let norm: Double = (rung.depth + 1) / 2                 // 0 (back) ... 1 (front)
        let scale: CGFloat = CGFloat(0.5 + norm * 0.5)          // 0.5 ... 1.0
        let lineOpacity: Double = 0.22 + norm * 0.55            // 0.22 ... 0.77
        let nodeOpacity: Double = 0.45 + norm * 0.55            // 0.45 ... 1.0

        let nodeR: CGFloat = max(1.5, rung.nodeRadius * scale)
        let lineW: CGFloat = max(1.0, (height * 0.010) * scale)

        // Base-pair rung connecting the two strands.
        var rungPath = Path()
        rungPath.move(to: CGPoint(x: rung.xA, y: rung.y))
        rungPath.addLine(to: CGPoint(x: rung.xB, y: rung.y))
        let strokeColor = rungColor(forHue: rung.hue).opacity(lineOpacity)
        ctx.stroke(rungPath, with: .color(strokeColor), lineWidth: lineW)

        // Strand nodes (phosphate backbone beads). Glow halo + core.
        drawNode(at: CGPoint(x: rung.xA, y: rung.y),
                 radius: nodeR, opacity: nodeOpacity,
                 color: strandColorA, into: &ctx)
        drawNode(at: CGPoint(x: rung.xB, y: rung.y),
                 radius: nodeR, opacity: nodeOpacity,
                 color: strandColorB, into: &ctx)
    }

    private func drawNode(at point: CGPoint,
                          radius: CGFloat,
                          opacity: Double,
                          color: Color,
                          into ctx: inout GraphicsContext) {
        // Soft halo.
        let haloRect = CGRect(
            x: point.x - radius * 1.9,
            y: point.y - radius * 1.9,
            width: radius * 3.8,
            height: radius * 3.8
        )
        let halo = Path(ellipseIn: haloRect)
        ctx.fill(halo, with: .color(color.opacity(opacity * 0.22)))

        // Solid core.
        let coreRect = CGRect(
            x: point.x - radius,
            y: point.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        let core = Path(ellipseIn: coreRect)
        ctx.fill(core, with: .color(color.opacity(opacity)))

        // Tiny specular highlight for a beaded sheen.
        let hiR: CGFloat = radius * 0.42
        let hiRect = CGRect(
            x: point.x - radius * 0.32 - hiR,
            y: point.y - radius * 0.32 - hiR,
            width: hiR * 2,
            height: hiR * 2
        )
        let highlight = Path(ellipseIn: hiRect)
        ctx.fill(highlight, with: .color(Color(red: 1, green: 1, blue: 1).opacity(opacity * 0.55)))
    }

    private func nodeRadius(forHeight h: CGFloat) -> CGFloat {
        max(3, h * 0.028)
    }

    // MARK: - Palette (literals only, no design-system deps)

    private var strandColorA: Color {
        Color(red: 0.30, green: 0.78, blue: 1.00)   // cyan-blue
    }
    private var strandColorB: Color {
        Color(red: 1.00, green: 0.42, blue: 0.62)   // warm pink
    }

    private func rungColor(forHue t: Double) -> Color {
        // Blend the two strand colors so base pairs read as bridges between them.
        let mix = (sin(t * .pi) + 1) / 2
        return Color(
            red: 0.30 + (1.00 - 0.30) * mix,
            green: 0.78 + (0.42 - 0.78) * mix,
            blue: 1.00 + (0.62 - 1.00) * mix
        )
    }

    // MARK: - Rung model

    struct Rung {
        let y: CGFloat
        let xA: CGFloat
        let xB: CGFloat
        let depth: Double
        let nodeRadius: CGFloat
        let hue: Double
    }
}

// MARK: - Conditional drag gesture

/// Attaches a horizontal scrub `DragGesture` only when `enabled`, keeping the
/// rendering path identical in both demo and interactive modes.
private struct DnaHelixView_ScrubGesture: ViewModifier {
    let enabled: Bool
    let onChanged: (CGSize) -> Void
    let onEnded: () -> Void

    func body(content: Content) -> some View {
        if enabled {
            content.gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in onChanged(value.translation) }
                    .onEnded { _ in onEnded() }
            )
        } else {
            content
        }
    }
}
