// catalog-id: ob-ferrofluid-dots
import SwiftUI

// MARK: - Ferrofluid Dots
//
// Page dots behave like magnetized ferrofluid: as a magnet (your finger, or
// an auto-swept virtual one) passes between them, the nearest dots stretch
// toward it and fuse into a gooey metaball bridge, then release and snap back
// round.
//
// The gooey fusion is pure SwiftUI Canvas. GraphicsContext applies stacked
// filters in REVERSE of the order they are added: the last-added filter hits
// the content first. So adding `.alphaThreshold` first and `.blur` second
// means the circles are blurred first, then alpha-thresholded — overlapping
// blurred circles raise the local alpha above the threshold and weld into a
// single crisp-edged blob. Classic metaball compositing, no Metal shader.
// Canvas filters ship since iOS 15, so iOS 17 needs no availability guard.

struct FerrofluidDotsView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { proxy in
            FerrofluidDotsView_FerrofluidStage(demo: demo, size: proxy.size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Stage

private struct FerrofluidDotsView_FerrofluidStage: View {
    let demo: Bool
    let size: CGSize

    // Far-off-rail rest position so every dot relaxes fully round when the
    // magnet is released (a finite on-rail value would leave the nearest dot
    // permanently swollen). Distance is huge → Gaussian influence ~0.
    private static let restX: CGFloat = -100_000

    // Interactive magnet position. `nil` == magnet released → relax to rest.
    @State private var dragMagnetX: CGFloat? = nil
    // Eased magnet used while interactive so release springs smoothly.
    @State private var relaxedMagnetX: CGFloat = FerrofluidDotsView_FerrofluidStage.restX

    private var dotCount: Int { 5 }

    var body: some View {
        ZStack {
            background
            content
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var background: some View {
        // Tint #120e18 — the tile backdrop the liquid sits on.
        let bg = Color(red: 0.071, green: 0.055, blue: 0.094)
        RadialGradient(
            colors: [
                Color(red: 0.12, green: 0.10, blue: 0.17),
                bg
            ],
            center: .center,
            startRadius: 0,
            endRadius: max(size.width, size.height) * 0.75
        )
    }

    @ViewBuilder
    private var content: some View {
        if demo {
            demoCanvas
        } else {
            interactiveCanvas
        }
    }

    // MARK: Demo — self-driving sine sweep of a virtual magnet

    private var demoCanvas: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let magnetX = sweptMagnetX(time: t)
            let pulse = demoPulse(time: t)
            metaballCanvas(magnetX: magnetX, pull: pulse)
        }
        // Demo tile must not eat ScrollView pans — it never needs touches.
        .allowsHitTesting(false)
    }

    /// Magnet x oscillating across the full dot rail on a ~2.4s loop.
    private func sweptMagnetX(time: Double) -> CGFloat {
        let inset = railInset(for: size)
        let lo = inset
        let hi = size.width - inset
        let period: Double = 2.4
        let phase = (time.truncatingRemainder(dividingBy: period)) / period
        // Smooth ease-in-out triangle so it dwells at the ends.
        let angle = phase * 2 * Double.pi - Double.pi / 2
        let s = (sin(angle) + 1) / 2
        return lo + (hi - lo) * CGFloat(s)
    }

    /// Breathe the pull strength a touch so merges feel alive, never frozen.
    private func demoPulse(time: Double) -> CGFloat {
        let v = (sin(time * 2.7) + 1) / 2
        return 0.82 + 0.18 * CGFloat(v)
    }

    // MARK: Interactive — drag a real magnet, release springs home

    private var interactiveCanvas: some View {
        metaballCanvas(magnetX: activeMagnetX, pull: 1.0)
            // Make the whole tile hittable so the drag wins inside a ScrollView.
            .contentShape(Rectangle())
            .gesture(dragGesture)
    }

    private var activeMagnetX: CGFloat {
        dragMagnetX ?? relaxedMagnetX
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let clamped = clampToRail(value.location.x)
                dragMagnetX = clamped
                relaxedMagnetX = clamped
            }
            .onEnded { _ in
                // Release: spring the magnet back to rest (off-rail), letting
                // the bridged dots un-fuse and snap round.
                dragMagnetX = nil
                withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                    relaxedMagnetX = restMagnetX
                }
            }
    }

    private func clampToRail(_ x: CGFloat) -> CGFloat {
        let inset = railInset(for: size)
        return min(max(x, inset), size.width - inset)
    }

    /// Rest position parks the magnet far off-rail so every dot sits round.
    private var restMagnetX: CGFloat { FerrofluidDotsView_FerrofluidStage.restX }

    // MARK: Canvas

    private func metaballCanvas(magnetX: CGFloat, pull: CGFloat) -> some View {
        let metrics = FerrofluidDotsView_FerroMetrics(size: size, dotCount: dotCount)
        let pts = centers(magnetX: magnetX, metrics: metrics, pull: pull)
        let rs = radii(magnetX: magnetX, metrics: metrics, pull: pull)
        return Canvas { context, _ in
            drawMetaball(in: context, centers: pts, radii: rs, metrics: metrics)
        }
    }

    private func drawMetaball(
        in context: GraphicsContext,
        centers: [CGPoint],
        radii: [CGFloat],
        metrics: FerrofluidDotsView_FerroMetrics
    ) {
        var ctx = context
        let liquid = Color(red: 0.45, green: 0.62, blue: 1.0)

        // Filter ADD order is reverse of APPLY order. Adding alphaThreshold
        // first and blur second means circles get blurred FIRST, then hard-cut
        // by the threshold — so overlapping soft edges weld into one crisp
        // blob. drawLayer is mandatory — the per-circle alphas must composite
        // inside an isolated layer to fuse.
        ctx.addFilter(.alphaThreshold(min: 0.5, color: liquid))
        ctx.addFilter(.blur(radius: metrics.blurRadius))

        ctx.drawLayer { layer in
            for (i, center) in centers.enumerated() where i < radii.count {
                let r = radii[i]
                let rect = CGRect(
                    x: center.x - r,
                    y: center.y - r,
                    width: r * 2,
                    height: r * 2
                )
                layer.fill(Path(ellipseIn: rect), with: .color(.white))
            }
        }

        drawSpecular(in: context, centers: centers, radii: radii)
    }

    /// A tiny bright highlight on each dot for the wet, mercury sheen. Drawn
    /// outside the threshold layer so it always reads, never disappears.
    private func drawSpecular(
        in context: GraphicsContext,
        centers: [CGPoint],
        radii: [CGFloat]
    ) {
        let sheen = Color(red: 0.85, green: 0.92, blue: 1.0)
        for (i, center) in centers.enumerated() where i < radii.count {
            let r = radii[i]
            let hr = r * 0.34
            let hx = center.x - r * 0.28
            let hy = center.y - r * 0.30
            let rect = CGRect(x: hx - hr, y: hy - hr, width: hr * 2, height: hr * 2)
            context.fill(
                Path(ellipseIn: rect),
                with: .color(sheen.opacity(0.5))
            )
        }
    }

    // MARK: Physics (pure)

    /// Dot centers eased toward the magnet by a distance falloff so the two
    /// nearest dots lunge together and bridge.
    private func centers(
        magnetX: CGFloat,
        metrics: FerrofluidDotsView_FerroMetrics,
        pull: CGFloat
    ) -> [CGPoint] {
        let cy = size.height / 2
        return (0..<metrics.dotCount).map { i in
            let restX = metrics.slotX(i)
            let dx = magnetX - restX
            // Gaussian-ish falloff: dots near the magnet pull hard, far ones
            // barely move.
            let influence = gaussian(distance: dx, sigma: metrics.sigma)
            let maxReach = metrics.spacing * 0.62
            let shift = clampSign(dx) * min(abs(dx), maxReach) * influence * pull
            return CGPoint(x: restX + shift, y: cy)
        }
    }

    /// A dot swells slightly as it nears the magnet (gathered liquid).
    private func radii(
        magnetX: CGFloat,
        metrics: FerrofluidDotsView_FerroMetrics,
        pull: CGFloat
    ) -> [CGFloat] {
        return (0..<metrics.dotCount).map { i in
            let restX = metrics.slotX(i)
            let dx = magnetX - restX
            let influence = gaussian(distance: dx, sigma: metrics.sigma)
            let swell = metrics.dotRadius * 0.32 * influence * pull
            return metrics.dotRadius + swell
        }
    }

    private func gaussian(distance: CGFloat, sigma: CGFloat) -> CGFloat {
        let denom = 2 * sigma * sigma
        guard denom > 0 else { return 0 }
        let exponent = -(distance * distance) / denom
        return CGFloat(exp(Double(exponent)))
    }

    private func clampSign(_ v: CGFloat) -> CGFloat {
        v == 0 ? 0 : (v > 0 ? 1 : -1)
    }

    private func railInset(for size: CGSize) -> CGFloat {
        FerrofluidDotsView_FerroMetrics(size: size, dotCount: dotCount).railInset
    }
}

// MARK: - Metrics

/// All size-relative geometry in one place so the dots, blur and rail scale
/// identically at a 120pt tile and a large detail area. Crucially the blur
/// radius is tied to dot radius so an *isolated* (un-merged) dot's peak alpha
/// stays above the threshold and never silently vanishes.
private struct FerrofluidDotsView_FerroMetrics {
    let size: CGSize
    let dotCount: Int

    /// Base dot radius, clamped so very small tiles stay legible.
    var dotRadius: CGFloat {
        let r = size.width * 0.045
        return min(max(r, 4.0), 22.0)
    }

    /// Blur kept modest relative to the dot so a lone dot still composites
    /// solidly past the 0.5 threshold. ~0.7× dotRadius is the sweet spot.
    var blurRadius: CGFloat {
        dotRadius * 0.7
    }

    /// Horizontal spacing between rail slots.
    var spacing: CGFloat {
        let usable = size.width - railInset * 2
        return dotCount > 1 ? usable / CGFloat(dotCount - 1) : 0
    }

    /// Falloff width of the magnet's influence.
    var sigma: CGFloat {
        max(spacing * 0.62, 1)
    }

    var railInset: CGFloat {
        max(size.width * 0.14, dotRadius * 1.6)
    }

    func slotX(_ i: Int) -> CGFloat {
        railInset + spacing * CGFloat(i)
    }
}
