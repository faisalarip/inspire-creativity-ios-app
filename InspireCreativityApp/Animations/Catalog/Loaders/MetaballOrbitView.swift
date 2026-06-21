// catalog-id: ld-metaball-orbit
import SwiftUI

/// Metaball Orbit — two gooey blobs chase each other around a ring; when they
/// meet they fuse into a single liquid mass with a bridging neck, then split
/// apart with surface tension as the loop repeats.
///
/// The goo is pure `Canvas`: every blob is filled into ONE `drawLayer`, and the
/// layer is wrapped in `.alphaThreshold` + `.blur` so overlapping blurred edges
/// snap into a single solid metaball with a connecting neck — zero Metal.
///
/// - `demo == true`  → fully self-driving auto-orbit (the spec's previewLoop).
/// - `demo == false` → the same auto-orbit, plus a `DragGesture` that spawns a
///   third blob following your finger so you can manually fuse/split the goo;
///   on release it dissolves and the idle orbit resumes.
struct MetaballOrbitView: View {
    var demo: Bool = false

    // Finger-driven blob (interactive mode only).
    @State private var touchPoint: CGPoint? = nil
    @State private var touchStrength: CGFloat = 0   // 0…1 fade-in / fade-out

    // MARK: Palette (literal colors — no app dependencies)

    private let background = Color(red: 0.039, green: 0.063, blue: 0.078)   // ~#0a1014
    private let gooCore    = Color(red: 0.40,  green: 0.85,  blue: 1.00)
    private let gooEdge    = Color(red: 0.10,  green: 0.45,  blue: 0.95)
    private let gooHot     = Color(red: 0.85,  green: 0.97,  blue: 1.00)

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                metaballCanvas(time: t, size: size)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(in: size), including: demo ? .none : .all)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
    }

    // MARK: - Gesture (interactive mode)

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                touchPoint = clampPoint(value.location, in: size)
                withAnimation(.easeOut(duration: 0.18)) { touchStrength = 1 }
            }
            .onEnded { _ in
                withAnimation(.easeIn(duration: 0.32)) { touchStrength = 0 }
                // Leave touchPoint in place so the blob shrinks where it was.
                touchPoint = nil
            }
    }

    private func clampPoint(_ p: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: min(max(p.x, 0), size.width),
                y: min(max(p.y, 0), size.height))
    }

    // MARK: - Canvas

    private func metaballCanvas(time: Double, size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let blobs = blobLayout(time: time, size: canvasSize)
            drawMetaballs(blobs, in: &context, size: canvasSize)
            drawHighlights(blobs, in: &context)
        }
    }

    /// Composite all blobs into a single layer, then threshold + blur the layer
    /// as a group so neighbouring blobs grow a connecting neck. Filters apply
    /// innermost-first (last added runs first): the blur softens the raw circles,
    /// then alphaThreshold snaps the blurred union back to a hard liquid
    /// silhouette so overlapping blobs fuse with a neck.
    private func drawMetaballs(_ blobs: [Blob],
                               in context: inout GraphicsContext,
                               size: CGSize) {
        let minDim = min(size.width, size.height)
        let blurRadius = minDim * 0.055

        var layer = context
        layer.addFilter(.alphaThreshold(min: 0.5, color: gooEdge))
        layer.addFilter(.blur(radius: blurRadius))
        layer.drawLayer { inner in
            for blob in blobs {
                let rect = CGRect(x: blob.center.x - blob.radius,
                                  y: blob.center.y - blob.radius,
                                  width: blob.radius * 2,
                                  height: blob.radius * 2)
                inner.fill(Circle().path(in: rect), with: .color(gooCore))
            }
        }
    }

    /// Tiny specular dots sit on top of the goo (outside the filtered layer) for
    /// a wet, liquid sheen. These are NOT thresholded.
    private func drawHighlights(_ blobs: [Blob],
                                in context: inout GraphicsContext) {
        for blob in blobs {
            let r = blob.radius * 0.26
            let c = CGPoint(x: blob.center.x - blob.radius * 0.32,
                            y: blob.center.y - blob.radius * 0.34)
            let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
            let shading = GraphicsContext.Shading.radialGradient(
                Gradient(colors: [gooHot.opacity(0.9), gooHot.opacity(0)]),
                center: c, startRadius: 0, endRadius: r
            )
            context.fill(Circle().path(in: rect), with: shading)
        }
    }

    // MARK: - Layout / motion

    struct Blob {
        var center: CGPoint
        var radius: CGFloat
    }

    /// Positions the two orbiting blobs (plus the optional finger blob).
    /// The pair orbits at a constant base angle, but their *angular separation*
    /// oscillates so they sweep together (fuse → neck) and apart (split) every
    /// loop instead of just spinning rigidly.
    private func blobLayout(time: Double, size: CGSize) -> [Blob] {
        let minDim = min(size.width, size.height)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let orbitRadius = minDim * 0.20
        let baseBlobRadius = minDim * 0.155

        let loop: Double = 3.2
        let phase = time.truncatingRemainder(dividingBy: loop) / loop  // 0…1

        // Steady revolution of the whole pair.
        let revolution = (time / loop) * 2 * Double.pi

        // Separation breathes from wide-apart (~π) toward together (~0) and back.
        // sep ∈ [minSep, π]; near minSep the blobs overlap → fuse with a neck.
        let minSep: Double = 0.18
        let breathe = (1 - cos(phase * 2 * Double.pi)) / 2   // 0→1→0 over loop
        let separation = minSep + (Double.pi - minSep) * (1 - breathe)

        let angleA = revolution + separation / 2
        let angleB = revolution - separation / 2

        // Squash radius slightly as they merge so the mass conserves volume.
        let mergeAmount = breathe                              // 1 when fused
        let radius = baseBlobRadius * (1 + 0.10 * CGFloat(mergeAmount))

        let blobA = Blob(center: orbitPoint(center, orbitRadius, angleA),
                         radius: radius)
        let blobB = Blob(center: orbitPoint(center, orbitRadius, angleB),
                         radius: radius)

        var blobs = [blobA, blobB]

        if touchStrength > 0.001, let touch = touchPoint {
            blobs.append(Blob(center: touch,
                              radius: baseBlobRadius * (0.55 + 0.55 * touchStrength)))
        }
        return blobs
    }

    private func orbitPoint(_ center: CGPoint,
                            _ radius: CGFloat,
                            _ angle: Double) -> CGPoint {
        CGPoint(x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle)))
    }
}
