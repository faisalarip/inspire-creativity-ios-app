// catalog-id: mtl-mercury-pour
// catalog-metal: MercuryPourView.metal
import SwiftUI

/// Mercury Pour — a metaball threshold turns the bright "beads" into liquid metal
/// that merges and splits with a chrome specular rim as gravity is tilted.
///
/// Architecture (the part that defeats the HIGH risk note):
///   ZStack { dark backdrop; bright radial-gradient blobs }
///       .blur(radius:)            ← the gooey merge happens HERE, in SwiftUI
///       .layerEffect(mercuryPour) ← shader only does threshold + a few neighbor
///                                    samples for the chrome rim → cheap.
///
/// The blobs physically move under gravity in SwiftUI space, so when they overlap
/// the blur+threshold merges them and when they separate they pull apart — that
/// emergent surface-tension merge/split IS the effect, not a relit static image.
struct MercuryPourView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            MercuryPourView_MercuryStage(demo: demo, size: geo.size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

// MARK: - Stage (owns gesture + time, drives the gravity uniform)

private struct MercuryPourView_MercuryStage: View {
    let demo: Bool
    let size: CGSize

    @State private var startDate = Date()

    // Drag → gravity direction.
    @State private var isDragging = false
    @State private var dragGravity: CGVector = .zero
    // Blend weight that eases gravity back to the auto circular sweep on release.
    @State private var autoBlend: CGFloat = 1

    private let beads: [MercuryPourView_Bead] = MercuryPourView_Bead.makeField()

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(startDate)
            let gravity = currentGravity(time: t)

            MercuryPourView_MercuryContent(
                beads: beads,
                size: size,
                time: t,
                gravity: gravity
            )
        }
        .contentShape(Rectangle())
        // No `.gesture(nil)` overload exists; mask the gesture off in demo instead.
        .gesture(dragGesture, including: demo ? .subviews : .all)
    }

    // MARK: Gravity blend

    private func currentGravity(time t: TimeInterval) -> CGVector {
        let auto = autoGravity(time: t)
        if demo { return auto }
        // Lerp drag → auto using the eased blend weight (0 = full drag, 1 = full auto).
        let w = autoBlend
        let x = dragGravity.dx * (1 - w) + auto.dx * w
        let y = dragGravity.dy * (1 - w) + auto.dy * w
        return CGVector(dx: x, dy: y)
    }

    /// Circular sweep — full orbit ≈ 3.9s so the gesture progress auto-cycles in
    /// range; never points "nowhere", so beads always pour somewhere.
    private func autoGravity(time t: TimeInterval) -> CGVector {
        let speed: Double = 1.6
        let a: Double = t * speed
        return CGVector(dx: CGFloat(cos(a)), dy: CGFloat(sin(a)))
    }

    // MARK: Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDragging = true
                autoBlend = 0
                let maxLen: CGFloat = max(size.width, size.height) * 0.45
                let dx = value.translation.width / maxLen
                let dy = value.translation.height / maxLen
                dragGravity = clampedUnit(dx: dx, dy: dy)
            }
            .onEnded { _ in
                isDragging = false
                // Ease gravity back to the auto sweep.
                withAnimation(.easeInOut(duration: 1.1)) {
                    autoBlend = 1
                }
            }
    }

    private func clampedUnit(dx: CGFloat, dy: CGFloat) -> CGVector {
        let len = sqrt(dx * dx + dy * dy)
        if len <= 1 { return CGVector(dx: dx, dy: dy) }
        return CGVector(dx: dx / len, dy: dy / len)
    }
}

// MARK: - Content: moving blobs → blur → metaball shader

private struct MercuryPourView_MercuryContent: View {
    let beads: [MercuryPourView_Bead]
    let size: CGSize
    let time: TimeInterval
    let gravity: CGVector

    var body: some View {
        let dim = min(size.width, size.height)
        let blur = blurRadius(for: dim)

        ZStack {
            backdrop
            blobLayer
        }
        .frame(width: size.width, height: size.height)
        .blur(radius: blur)
        .modifier(
            MercuryPourView_MercuryShaderModifier(
                size: size,
                time: time,
                gravity: gravity
            )
        )
    }

    private var backdrop: some View {
        // Faint cool backdrop so the tile is never fully blank between beads.
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.06, blue: 0.09),
                Color(red: 0.02, green: 0.02, blue: 0.04)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Bright soft circles whose centres slide under gravity + a small time-bob.
    /// Overlap → blur merges them → threshold reads as one bead. Separate → split.
    private var blobLayer: some View {
        Canvas { ctx, canvasSize in
            for bead in beads {
                let p = position(for: bead, in: canvasSize)
                let r = bead.radius * min(canvasSize.width, canvasSize.height)
                let rect = CGRect(
                    x: p.x - r, y: p.y - r,
                    width: r * 2, height: r * 2
                )
                let grad = Gradient(stops: [
                    .init(color: .white, location: 0.0),
                    .init(color: Color(white: 1.0, opacity: 0.95), location: 0.45),
                    .init(color: Color(white: 1.0, opacity: 0.0), location: 1.0)
                ])
                let shading = GraphicsContext.Shading.radialGradient(
                    grad,
                    center: p,
                    startRadius: 0,
                    endRadius: r
                )
                ctx.fill(Path(ellipseIn: rect), with: shading)
            }
        }
    }

    private func position(for bead: MercuryPourView_Bead, in s: CGSize) -> CGPoint {
        let dim = min(s.width, s.height)
        // Gravity displacement: beads pour toward the gravity direction.
        let pour = dim * 0.18
        let gx = gravity.dx * pour
        let gy = gravity.dy * pour
        // Per-bead time bob so beads continually drift in/out of contact.
        let bob = dim * 0.05
        let bx = CGFloat(cos(time * bead.bobSpeed + bead.phase)) * bob
        let by = CGFloat(sin(time * bead.bobSpeed * 1.3 + bead.phase)) * bob

        let baseX = bead.base.x * s.width
        let baseY = bead.base.y * s.height
        return CGPoint(x: baseX + gx + bx, y: baseY + gy + by)
    }

    /// Blur scales with tile size: capped so it never explodes on a large detail view.
    private func blurRadius(for dim: CGFloat) -> CGFloat {
        min(max(dim * 0.06, 6), 26)
    }
}

// MARK: - Shader application

private struct MercuryPourView_MercuryShaderModifier: ViewModifier {
    let size: CGSize
    let time: TimeInterval
    let gravity: CGVector

    func body(content: Content) -> some View {
        let shader = ShaderLibrary.mercuryPour(
            .float2(Float(size.width), Float(size.height)),
            .float(Float(time)),
            .float2(Float(gravity.dx), Float(gravity.dy))
        )
        content.layerEffect(shader, maxSampleOffset: CGSize(width: 8, height: 8))
    }
}

// MARK: - MercuryPourView_Bead model

private struct MercuryPourView_Bead {
    var base: CGPoint   // normalised 0…1 rest position
    var radius: CGFloat // normalised radius (× min dimension)
    var phase: Double
    var bobSpeed: Double

    /// A modest field of beads (capped per the HIGH-risk note) arranged so they
    /// sit close enough to merge as gravity pours them together.
    static func makeField() -> [MercuryPourView_Bead] {
        let positions: [(CGFloat, CGFloat, CGFloat)] = [
            (0.30, 0.34, 0.16),
            (0.52, 0.28, 0.13),
            (0.70, 0.40, 0.15),
            (0.40, 0.55, 0.14),
            (0.60, 0.60, 0.12),
            (0.48, 0.45, 0.17),
            (0.28, 0.62, 0.11),
            (0.72, 0.66, 0.12)
        ]
        var out: [MercuryPourView_Bead] = []
        for (i, p) in positions.enumerated() {
            out.append(
                MercuryPourView_Bead(
                    base: CGPoint(x: p.0, y: p.1),
                    radius: p.2,
                    phase: Double(i) * 0.9,
                    bobSpeed: 0.7 + Double(i) * 0.08
                )
            )
        }
        return out
    }
}
