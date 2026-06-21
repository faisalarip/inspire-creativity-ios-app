// catalog-id: tr-liquid-drip
import SwiftUI

/// Liquid Drip Reveal
///
/// The top view's lower edge develops droplets that bulge, neck, and detach,
/// the surface melting downward to expose the view beneath. The melt is drawn
/// into a `Canvas` whose `.blur` + `.alphaThreshold` filters fuse overlapping
/// shapes into a single gooey surface (metaball necking), and that Canvas is
/// used as a `.mask` over the top view so material disappears as it drips away.
///
/// Interaction is `auto`: both the demo tile and the interactive component run
/// the same self-driving `TimelineView(.animation)` melt loop. Tapping in the
/// interactive mode re-syncs the melt to the start for a tactile restart.
struct LiquidDripView: View {
    var demo: Bool = false

    // Re-sync point for the interactive restart tap. The looped progress is
    // measured relative to this so a tap snaps the melt back to its dry state.
    @State private var loopStart: Date = .init()

    private let loopDuration: Double = 3.4

    var body: some View {
        GeometryReader { geo in
            content(size: geo.size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            guard !demo else { return }
            loopStart = .init()
        }
    }

    @ViewBuilder
    private func content(size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let phase = loopPhase(now: timeline.date)
            let progress = meltProgress(phase: phase)
            ZStack {
                // The view revealed beneath the melting surface — always legible.
                bottomView(size: size)

                // The melting surface. Masked by the metaball Canvas so it
                // recedes and drips away, exposing the bottom view. During the
                // tail of the loop it crossfades back in for a seamless reset.
                topView(size: size)
                    .mask {
                        meltCanvas(progress: progress, size: size)
                    }
                    .opacity(surfaceOpacity(phase: phase))
            }
            .frame(width: size.width, height: size.height)
        }
    }

    // MARK: - Looped phase / progress

    /// 0 → 1 wall-clock loop phase derived from time so the tile animates with
    /// no touch.
    private func loopPhase(now: Date) -> CGFloat {
        let elapsed = now.timeIntervalSince(loopStart)
        let t = elapsed.truncatingRemainder(dividingBy: loopDuration) / loopDuration
        return CGFloat(t)
    }

    /// The melt itself runs over the first 82% of the loop; the final 18% holds
    /// the revealed view, then a short crossfade restores the dry surface.
    private func meltProgress(phase: CGFloat) -> CGFloat {
        let meltSpan: CGFloat = 0.82
        let raw = min(phase / meltSpan, 1.0)
        return easeInOut(raw)
    }

    /// Keeps the top surface fully opaque during the melt, then fades it back
    /// in over the last sliver of the loop so the reset reads as a soft
    /// re-forming of the surface rather than a hard snap/flash.
    private func surfaceOpacity(phase: CGFloat) -> Double {
        let fadeStart: CGFloat = 0.94
        guard phase >= fadeStart else { return 1 }
        let f = (phase - fadeStart) / (1 - fadeStart)
        return Double(easeInOut(f))
    }

    private func easeInOut(_ x: CGFloat) -> CGFloat {
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }

    // MARK: - Metaball melt mask

    /// White = remaining top material. A receding rect (the surface body) is
    /// unioned via the metaball filters with a row of droplet circles that
    /// travel downward and detach. The blur is applied to the raw shapes and
    /// the alphaThreshold then sharpens the blurred union into crisp necking
    /// edges (the canonical gooey-metaball recipe).
    private func meltCanvas(progress: CGFloat, size: CGSize) -> some View {
        let blur = blurRadius(for: size)
        let waterline = waterlineY(progress: progress, size: size)
        let drops = droplets(at: progress, size: size, waterline: waterline)

        return Canvas { context, _ in
            context.addFilter(.alphaThreshold(min: 0.5, color: .white))
            context.addFilter(.blur(radius: blur))
            context.drawLayer { layer in
                // The body of the surface above the waterline stays solid.
                if waterline > 0 {
                    let body = CGRect(x: -blur, y: -blur,
                                      width: size.width + blur * 2,
                                      height: waterline + blur)
                    layer.fill(Path(body), with: .color(.white))
                }
                // Droplets — circles fused to the body until their neck thins
                // past the blur threshold, then detaching and falling away.
                for drop in drops {
                    let rect = CGRect(x: drop.x - drop.radius,
                                      y: drop.y - drop.radius,
                                      width: drop.radius * 2,
                                      height: drop.radius * 2)
                    layer.fill(Path(ellipseIn: rect), with: .color(.white))
                }
            }
        }
    }

    /// Blur radius scaled to the smaller dimension so the surface-tension
    /// threshold reads identically in a 120pt tile and a large detail area.
    private func blurRadius(for size: CGSize) -> CGFloat {
        max(min(size.width, size.height) * 0.05, 3)
    }

    /// The flat surface recedes upward as the melt advances, eventually
    /// clearing the frame entirely so the bottom view is fully exposed.
    private func waterlineY(progress: CGFloat, size: CGSize) -> CGFloat {
        // Hold a thin lip early so the first droplets read as forming on a
        // surface, then sweep the waterline off the top edge.
        let receded = max(progress - 0.18, 0) / 0.82
        return size.height * (1 - easeInOut(receded))
    }

    // MARK: - Droplet model

    struct Droplet {
        var x: CGFloat
        var y: CGFloat
        var radius: CGFloat
    }

    /// Pure function: places a row of droplets along the waterline. Each has a
    /// staggered phase so they bulge, neck, and detach at different moments,
    /// giving the row a surface-tension cadence rather than marching in unison.
    private func droplets(at progress: CGFloat, size: CGSize, waterline: CGFloat) -> [Droplet] {
        let count = dropletCount(for: size)
        guard count > 0 else { return [] }

        let spacing = size.width / CGFloat(count)
        let baseRadius = spacing * 0.42
        let fallSpan = size.height + baseRadius * 2

        var result: [Droplet] = []
        result.reserveCapacity(count)

        for i in 0..<count {
            // Deterministic per-drop variation without RNG noise.
            let seed = CGFloat((i * 1664525 + 1013904223) % 997) / 997
            let phase = seed * 0.45
            let xJitter = (seed - 0.5) * spacing * 0.3
            let x = spacing * (CGFloat(i) + 0.5) + xJitter

            // Local melt for this drop: ramps after its phase delay.
            let local = clamp((progress - phase) / max(1 - phase, 0.001))

            // Bulge: radius swells from a nub to full size as it forms.
            let radius = baseRadius * (0.45 + 0.55 * easeInOut(min(local * 2, 1)))

            // Travel: the drop slides down from the waterline, accelerating
            // like gravity once it has necked off.
            let travel = easeIn(local) * fallSpan
            let y = waterline + radius * 0.4 + travel

            result.append(Droplet(x: x, y: y, radius: radius))
        }
        return result
    }

    private func dropletCount(for size: CGSize) -> Int {
        // Cap the count for Canvas redraw cost; scale gently with width.
        let n = Int((size.width / 46).rounded())
        return min(max(n, 4), 11)
    }

    private func easeIn(_ x: CGFloat) -> CGFloat {
        let c = clamp(x)
        return c * c
    }

    private func clamp(_ x: CGFloat) -> CGFloat {
        min(max(x, 0), 1)
    }

    // MARK: - Content layers

    /// The melting top surface: a warm molten gradient with a label, kept
    /// full-bleed (no inset/clip) so the mask aligns to its content.
    private func topView(size: CGSize) -> some View {
        let glyphSize = min(size.width, size.height) * 0.26
        return ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.42, blue: 0.20),
                    Color(red: 0.92, green: 0.20, blue: 0.36),
                    Color(red: 0.62, green: 0.10, blue: 0.42)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // A soft top sheen so the molten surface catches light.
            LinearGradient(
                colors: [Color.white.opacity(0.35), .clear],
                startPoint: .top,
                endPoint: .center
            )
            .blendMode(.softLight)

            Image(systemName: "drop.fill")
                .font(.system(size: glyphSize, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.92))
                .shadow(color: Color(red: 0.55, green: 0.05, blue: 0.30).opacity(0.5),
                        radius: glyphSize * 0.08, y: glyphSize * 0.04)
        }
        .frame(width: size.width, height: size.height)
    }

    /// The view revealed beneath: a cool teal gradient with its own glyph, so
    /// the fully-melted frame is always legible content, never blank.
    private func bottomView(size: CGSize) -> some View {
        let glyphSize = min(size.width, size.height) * 0.26
        return ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.22, blue: 0.34),
                    Color(red: 0.10, green: 0.42, blue: 0.52),
                    Color(red: 0.20, green: 0.62, blue: 0.60)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            // Faint vertical streaks evoke the wet surface left behind.
            LinearGradient(
                colors: [Color.white.opacity(0.10), .clear, Color.white.opacity(0.06)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .blendMode(.screen)

            Image(systemName: "sparkles")
                .font(.system(size: glyphSize, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.9))
        }
        .frame(width: size.width, height: size.height)
    }
}
