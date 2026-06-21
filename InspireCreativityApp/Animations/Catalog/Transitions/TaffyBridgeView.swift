// catalog-id: tr-taffy-bridge
import SwiftUI

// MARK: - Taffy Bridge Morph
//
// A source blob stretches a thinning 1D liquid bridge toward a destination
// position. The connecting strand necks and snaps with surface-tension recoil
// as the shape arrives and re-rounds. Pure-SwiftUI metaball via Canvas
// blur + alphaThreshold filters (blur is the inner filter so shapes are
// blurred THEN thresholded into a hard gooey edge — that ordering is what
// produces the neck-snap rather than a soft fuzzy fade).
//
// Spec interaction == "auto": both demo and non-demo run the same continuous
// TimelineView(.animation) loop. The non-demo branch additionally lets a tap
// re-launch the pull early. Both blobs are on screen every frame, so the tile
// is never blank or zero-opacity.

struct TaffyBridgeView: View {
    var demo: Bool = false

    // Re-launch token: bumping it restarts the pull on tap (non-demo only).
    @State private var launchDate: Date = .now

    private let loopDuration: Double = 3.2

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let t = phase(now: timeline.date, size: geo.size)
                TaffyBridgeView_MetaballCanvas(progress: t, size: geo.size)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard !demo else { return }
                launchDate = .now
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.051, green: 0.063, blue: 0.086))
    }

    // 0 → 1 → (reset) loop phase. Demo loops freely from a fixed epoch;
    // interactive resets the clock origin to the most recent tap/launch.
    private func phase(now: Date, size: CGSize) -> CGFloat {
        let origin = demo ? referenceEpoch : launchDate
        let elapsed = now.timeIntervalSince(origin)
        let frac = (elapsed.truncatingRemainder(dividingBy: loopDuration)) / loopDuration
        return CGFloat(max(0.0, min(1.0, frac)))
    }
}

// Stable epoch so the demo loop is deterministic across instances/frames.
private let referenceEpoch = Date(timeIntervalSince1970: 0)

// MARK: - Metaball Canvas

private struct TaffyBridgeView_MetaballCanvas: View {
    let progress: CGFloat   // 0 → 1 loop position
    let size: CGSize

    var body: some View {
        let geo = TaffyBridgeView_BridgeGeometry(progress: progress, size: size)
        ZStack {
            // The thresholded metaball field, rendered white, then masked
            // over a candy gradient so the taffy reads as a glossy material
            // rather than a flat fill.
            taffyGradient
                .mask(metaballField(geo: geo))
            // A soft inner glow re-rounds visually at the ends.
            metaballField(geo: geo)
                .blur(radius: max(1.0, minSide * 0.012))
                .blendMode(.plusLighter)
                .opacity(0.35)
        }
        .drawingGroup()
    }

    private var minSide: CGFloat { min(size.width, size.height) }

    private var taffyGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 1.00, green: 0.55, blue: 0.78),
                Color(red: 0.99, green: 0.36, blue: 0.62),
                Color(red: 0.62, green: 0.40, blue: 0.98)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private func metaballField(geo: TaffyBridgeView_BridgeGeometry) -> some View {
        Canvas { ctx, _ in
            // Filter order matters: alphaThreshold added first (outermost),
            // blur added second (innermost). Result: contents are blurred,
            // then the blurred alpha is hard-thresholded → gooey hard edge.
            ctx.addFilter(.alphaThreshold(min: 0.42, color: .white))
            ctx.addFilter(.blur(radius: geo.blurRadius))
            ctx.drawLayer { layer in
                drawSourceAndDest(in: &layer, geo: geo)
                drawStrand(in: &layer, geo: geo)
            }
        }
    }

    private func drawSourceAndDest(in layer: inout GraphicsContext,
                                   geo: TaffyBridgeView_BridgeGeometry) {
        layer.fill(circlePath(center: geo.sourceCenter, radius: geo.sourceRadius),
                   with: .color(.white))
        layer.fill(circlePath(center: geo.destCenter, radius: geo.destRadius),
                   with: .color(.white))
    }

    // The taffy strand: a chain of overlapping circles sampled along the
    // line from source → dest, whose radius dips at the waist. As travel
    // progresses the waist thins until neighbouring circles no longer
    // overlap; the threshold then severs the connection — the snap.
    private func drawStrand(in layer: inout GraphicsContext,
                            geo: TaffyBridgeView_BridgeGeometry) {
        guard geo.strandOpacity > 0.001 else { return }
        let samples = geo.strandSamples
        guard samples > 1 else { return }
        for i in 0...samples {
            let u = CGFloat(i) / CGFloat(samples)           // 0..1 along strand
            let p = lerpPoint(geo.sourceCenter, geo.destCenter, u)
            let r = geo.strandRadius(atU: u)
            guard r > 0.2 else { continue }
            layer.fill(circlePath(center: p, radius: r),
                       with: .color(.white.opacity(geo.strandOpacity)))
        }
    }

    private func circlePath(center: CGPoint, radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius,
                               y: center.y - radius,
                               width: radius * 2,
                               height: radius * 2))
    }

    private func lerpPoint(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t,
                y: a.y + (b.y - a.y) * t)
    }
}

// MARK: - Bridge Geometry (all size-relative)

private struct TaffyBridgeView_BridgeGeometry {
    let progress: CGFloat
    let size: CGSize

    var minSide: CGFloat { min(size.width, size.height) }

    // Blur scales with geometry so the gooey edge looks identical in a 120pt
    // tile and a large detail area.
    var blurRadius: CGFloat { max(2.0, minSide * 0.045) }

    var strandSamples: Int {
        // A few more samples on larger canvases for a smoother strand.
        Int(max(10.0, min(22.0, minSide * 0.12)))
    }

    // Endpoints sit on a gentle diagonal, inset from the edges.
    private var anchorSource: CGPoint {
        CGPoint(x: size.width * 0.26, y: size.height * 0.62)
    }
    private var anchorDest: CGPoint {
        CGPoint(x: size.width * 0.74, y: size.height * 0.38)
    }

    private var baseRadius: CGFloat { minSide * 0.16 }

    // --- Phase shaping over the loop ----------------------------------------
    // travel : how far the source has moved toward the destination (0..1)
    // strand : how present/thick the connecting bridge is (1 → 0 as it snaps)
    // arrive : re-round / settle pop at the destination

    private var travel: CGFloat {
        // Ease the source across during the first ~62% of the loop, then hold.
        let raw = clamp(progress / 0.62)
        return easeInOut(raw)
    }

    // The strand is fully present early, thins through the middle, snaps near
    // arrival, then is absent while the shape re-rounds and resets.
    private var strandLife: CGFloat {
        // Present 0..0.58, thinning, gone by ~0.6 (the snap moment).
        if progress < 0.58 {
            return easeOut(1.0 - clamp(progress / 0.58))
        }
        return 0
    }

    var strandOpacity: CGFloat { strandLife }

    var sourceCenter: CGPoint {
        lerp(anchorSource, anchorDest, travel)
    }

    var destCenter: CGPoint { anchorDest }

    // Source loses a touch of mass as it pays it into the strand, then the
    // destination gains a recoil pop the instant the neck snaps.
    var sourceRadius: CGFloat {
        let drain = 0.10 * strandLife
        return baseRadius * (1.0 - drain)
    }

    var destRadius: CGFloat {
        // Surface-tension recoil: a quick overshoot just after the snap.
        let recoil = recoilPop(progress)
        return baseRadius * (0.88 + 0.22 * recoil)
    }

    // Strand radius profile along u (0 at source, 1 at dest). A catenary-like
    // waist that dips in the middle; overall thickness collapses with progress.
    func strandRadius(atU u: CGFloat) -> CGFloat {
        // Waist factor: ~1 at the ends, dips toward the middle.
        let waistDip = 0.55 + 0.45 * abs(cos(u * .pi))   // 0.55..1.0
        // Global thinning as the pull stretches (and travel lengthens it).
        let stretch = 1.0 - 0.35 * travel
        let thickness = baseRadius * 0.42 * waistDip * stretch * strandLife
        return max(0, thickness)
    }

    // MARK: helpers
    private func recoilPop(_ p: CGFloat) -> CGFloat {
        // Bell centred just after the snap (~0.62) so the dest blob pulses.
        let center: CGFloat = 0.66
        let width: CGFloat = 0.14
        let x = (p - center) / width
        return exp(-x * x)
    }

    private func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }
    private func clamp(_ v: CGFloat) -> CGFloat { max(0, min(1, v)) }
    private func easeInOut(_ t: CGFloat) -> CGFloat {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }
    private func easeOut(_ t: CGFloat) -> CGFloat { 1 - pow(1 - t, 2) }
}
