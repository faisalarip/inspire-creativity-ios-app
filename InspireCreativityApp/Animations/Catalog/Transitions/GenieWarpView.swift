// catalog-id: tr-genie-warp
import SwiftUI

/// Genie Warp — the outgoing card squeezes and stretches into a narrowing
/// tapered neck that sucks down toward a dock point, like the macOS
/// minimize-to-Dock genie effect. Built with pure SwiftUI by slicing the
/// content into horizontal strips and giving each strip its own horizontal
/// scale (anchored at the dock column) plus a downward descent, so the
/// content genuinely bends along the warp curve instead of merely being
/// clipped by a genie-shaped hole.
///
/// - `demo == true`  → a self-driving loop that sucks the card down to a
///   tapering neck and springs it back out forever, never going blank.
/// - `demo == false` → tap the card to minimize it toward the dock, tap
///   again (or tap the dock) to restore it.
struct GenieWarpView: View {
    var demo: Bool = false

    // Interactive state.
    @State private var minimized: Bool = false

    var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if demo {
            demoBody(size: size)
        } else {
            interactiveBody(size: size)
        }
    }

    // MARK: - Demo (self-driving)

    @ViewBuilder
    private func demoBody(size: CGSize) -> some View {
        // PhaseAnimator (no trigger) auto-loops through the phases forever; the
        // spring between phases gives the suck-down and spring-back its tactile
        // feel. We clamp the peak below 1 so the neck never fully vanishes
        // (always legible) and dwell at each end so the loop breathes.
        PhaseAnimator(GenieWarpView_GeniePhase.allCases) { phase in
            GenieWarpView_GenieStage(progress: phase.progress, dockPoint: dockPoint(in: size), size: size)
        } animation: { phase in
            switch phase {
            case .rest:        return .spring(response: 0.6, dampingFraction: 0.82)
            case .restHold:    return .easeInOut(duration: 0.7)
            case .minimized:   return .spring(response: 0.7, dampingFraction: 0.85)
            case .minimizedHold: return .easeInOut(duration: 0.7)
            }
        }
    }

    // MARK: - Interactive

    @ViewBuilder
    private func interactiveBody(size: CGSize) -> some View {
        GenieWarpView_GenieStage(progress: minimized ? 0.92 : 0.0,
                   dockPoint: dockPoint(in: size),
                   size: size)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    minimized.toggle()
                }
            }
    }

    // MARK: - Geometry

    /// The dock point lives at bottom-centre, derived from the live size so it
    /// works in a 120pt tile and a large detail area alike.
    private func dockPoint(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * 0.5, y: size.height * 0.93)
    }
}

// MARK: - Phases

private enum GenieWarpView_GeniePhase: CaseIterable {
    case rest          // full card at rest
    case minimized     // sucked down into the dock neck
    case minimizedHold // dwell at the dock
    case restHold      // dwell back at rest before repeating

    var progress: Double {
        switch self {
        case .rest, .restHold:           return 0.0
        case .minimized, .minimizedHold: return 0.92  // clamped < 1 so the neck never vanishes
        }
    }
}

// MARK: - Stage (animatable container)

/// Renders the warped card for a given `progress`. `progress` is the single
/// animatable value (0 = full card at rest, 1 = fully sucked into the dock).
/// Animating it produces smooth, continuous interpolation of every strip.
private struct GenieWarpView_GenieStage: View, Animatable {
    var progress: Double
    var dockPoint: CGPoint
    var size: CGSize

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        ZStack {
            backdrop
            dockGlow
            GenieWarpView_GenieWarpedCard(progress: clampedProgress,
                            dockPoint: dockPoint,
                            size: size)
        }
        .frame(width: size.width, height: size.height)
    }

    private var clampedProgress: Double {
        min(max(progress, 0.0), 1.0)
    }

    // Soft dark stage so the warped card and dock read clearly.
    private var backdrop: some View {
        RoundedRectangle(cornerRadius: 0, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.06, blue: 0.10),
                        Color(red: 0.02, green: 0.02, blue: 0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    // Persistent glowing dock dot — always visible so the tile never reads as
    // blank, and it brightens as the card arrives.
    private var dockGlow: some View {
        let dim: CGFloat = max(6, min(size.width, size.height) * 0.06)
        let intensity: Double = 0.35 + 0.65 * clampedProgress
        return ZStack {
            Circle()
                .fill(Color(red: 0.45, green: 0.75, blue: 1.0))
                .frame(width: dim * 2.4, height: dim * 2.4)
                .blur(radius: dim)
                .opacity(0.28 * intensity)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.78, green: 0.90, blue: 1.0),
                            Color(red: 0.30, green: 0.62, blue: 0.98)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: dim * 0.6
                    )
                )
                .frame(width: dim, height: dim)
                .opacity(0.55 + 0.45 * clampedProgress)
        }
        .position(dockPoint)
    }
}

// MARK: - Warped card

/// Slices a card into horizontal strips and warps each one. The taper is a
/// smoothstep over the strip's normalized y, and the descent is a second
/// smoothstep — both continuous functions of `progress`, so there is no
/// velocity discontinuity (no mid-warp kink).
private struct GenieWarpView_GenieWarpedCard: View {
    var progress: Double
    var dockPoint: CGPoint
    var size: CGSize

    var body: some View {
        let metrics = GenieWarpView_CardMetrics(size: size)
        let stripCount = stripCount(for: size)

        ZStack {
            ForEach(0..<stripCount, id: \.self) { index in
                stripView(index: index, count: stripCount, metrics: metrics)
            }
        }
        // Fade the whole warped body slightly as it bottoms out so the dock
        // dot becomes the focal point, but never to zero (stays legible).
        .opacity(0.55 + 0.45 * (1.0 - smoothstep(0.78, 1.0, progress)))
    }

    // MARK: Strip

    @ViewBuilder
    private func stripView(index: Int, count: Int, metrics: GenieWarpView_CardMetrics) -> some View {
        // Normalized vertical centre of this strip within the card (0 = top).
        let yNorm: CGFloat = (CGFloat(index) + 0.5) / CGFloat(count)

        // A tiny overlap removes hairline seams between adjacent strips.
        let bandHeight: CGFloat = metrics.height / CGFloat(count)
        let overlap: CGFloat = min(1.0, bandHeight * 0.18)
        let drawHeight: CGFloat = bandHeight + overlap

        // Where this strip's centre sits before warping (card-local space).
        let restCenterY: CGFloat = metrics.minY + bandHeight * (CGFloat(index) + 0.5)

        // --- Warp factors (all smooth functions of progress) ---

        // Horizontal narrowing: lower strips (closer to the dock) narrow more,
        // and the whole thing narrows as progress rises. smoothstep avoids the
        // piecewise-linear kink.
        let neckLead: Double = smoothstep(0.0, 0.85, progress)
        let depthBias: Double = Double(smoothstep(0.0, 1.0, yNorm)) // bottom narrows first
        let widthFactor: CGFloat = widthFactor(neckLead: neckLead, depthBias: depthBias)

        // Vertical descent: strips slide toward the dock; the bottom leads so
        // the card bunches as it pours in. Second smoothstep, phase-shifted but
        // still continuous, so neck-leads-descent reads without a kink.
        let descentP: Double = smoothstep(0.06, 1.0, progress)
        let targetY: CGFloat = dockPoint.y
        let pull: CGFloat = CGFloat(descentP) * (0.55 + 0.45 * CGFloat(depthBias))
        let centerY: CGFloat = restCenterY + (targetY - restCenterY) * pull

        // Horizontal slide of the strip's centre toward the dock column.
        let restCenterX: CGFloat = size.width * 0.5
        let centerX: CGFloat = restCenterX + (dockPoint.x - restCenterX) * CGFloat(descentP)

        // Slight vertical squash on lower strips as they bunch into the dock.
        let vSquash: CGFloat = 1.0 - CGFloat(descentP) * 0.35 * CGFloat(depthBias)

        cardBand(metrics: metrics, drawHeight: drawHeight, bandTop: restCenterY - drawHeight / 2)
            .frame(width: metrics.width, height: drawHeight)
            // Narrow horizontally toward the dock x-column, anchored so the
            // silhouette converges into a neck at the dock point.
            .scaleEffect(x: widthFactor, y: vSquash, anchor: .center)
            .position(x: centerX, y: centerY)
    }

    /// One horizontal band of the card content, clipped to its band so the
    /// strip shows the correct slice of the same artwork.
    @ViewBuilder
    private func cardBand(metrics: GenieWarpView_CardMetrics, drawHeight: CGFloat, bandTop: CGFloat) -> some View {
        GenieWarpView_CardArtwork(metrics: metrics)
            .frame(width: metrics.width, height: metrics.height)
            // Shift the full artwork up so this band's slice sits in view, then
            // clip to the band height. This keeps every strip a faithful slice
            // of one continuous image.
            .offset(y: -(bandTop - metrics.minY))
            .frame(width: metrics.width, height: drawHeight, alignment: .top)
            .clipped()
    }

    // MARK: Factors

    private func widthFactor(neckLead: Double, depthBias: Double) -> CGFloat {
        // Minimum width is clamped so the neck stays a thin ribbon rather than
        // collapsing to literally zero (never fully blank).
        let minWidth: CGFloat = 0.10
        let narrowing: CGFloat = CGFloat(neckLead) * (0.55 + 0.45 * CGFloat(depthBias))
        return max(minWidth, 1.0 - narrowing)
    }

    private func stripCount(for size: CGSize) -> Int {
        // Adapt density to size: fewer strips keep a tiny tile clean, more
        // strips keep a large detail view smooth.
        let h = size.height
        if h < 160 { return 14 }
        if h < 320 { return 20 }
        return 28
    }
}

// MARK: - Card metrics

private struct GenieWarpView_CardMetrics {
    let size: CGSize
    let width: CGFloat
    let height: CGFloat
    let minX: CGFloat
    let minY: CGFloat

    init(size: CGSize) {
        self.size = size
        // Card occupies the upper portion of the stage, leaving room for the
        // dock at the bottom. Padded so it never touches the edges.
        let pad: CGFloat = min(size.width, size.height) * 0.12
        self.width = max(1, size.width - pad * 2)
        self.height = max(1, size.height * 0.62)
        self.minX = pad
        self.minY = pad * 0.7
    }
}

// MARK: - Card artwork

/// A self-contained, attractive card face. Pure SwiftUI, no assets.
private struct GenieWarpView_CardArtwork: View {
    var metrics: GenieWarpView_CardMetrics

    var body: some View {
        let corner: CGFloat = min(metrics.width, metrics.height) * 0.10

        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.35, green: 0.42, blue: 0.95),
                        Color(red: 0.62, green: 0.30, blue: 0.92),
                        Color(red: 0.95, green: 0.42, blue: 0.62)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(face(corner: corner))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Color(red: 1.0, green: 1.0, blue: 1.0).opacity(0.25), lineWidth: 1)
            )
            .shadow(color: Color(red: 0.0, green: 0.0, blue: 0.0).opacity(0.35),
                    radius: corner * 0.4, x: 0, y: corner * 0.18)
    }

    @ViewBuilder
    private func face(corner: CGFloat) -> some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let unit = min(w, h)

            ZStack {
                // Soft sheen sweep.
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 1.0, blue: 1.0).opacity(0.22),
                        Color(red: 1.0, green: 1.0, blue: 1.0).opacity(0.0)
                    ],
                    startPoint: .top,
                    endPoint: .center
                )

                // Decorative orbiting rings.
                Circle()
                    .strokeBorder(Color(red: 1.0, green: 1.0, blue: 1.0).opacity(0.35),
                                  lineWidth: unit * 0.012)
                    .frame(width: unit * 0.62, height: unit * 0.62)
                    .position(x: w * 0.30, y: h * 0.34)

                Circle()
                    .fill(Color(red: 1.0, green: 0.86, blue: 0.45).opacity(0.9))
                    .frame(width: unit * 0.20, height: unit * 0.20)
                    .position(x: w * 0.70, y: h * 0.30)

                // Header / body bars to read as "content".
                VStack(alignment: .leading, spacing: unit * 0.07) {
                    RoundedRectangle(cornerRadius: unit * 0.03)
                        .fill(Color(red: 1.0, green: 1.0, blue: 1.0).opacity(0.85))
                        .frame(width: w * 0.5, height: unit * 0.07)
                    RoundedRectangle(cornerRadius: unit * 0.025)
                        .fill(Color(red: 1.0, green: 1.0, blue: 1.0).opacity(0.45))
                        .frame(width: w * 0.66, height: unit * 0.05)
                    RoundedRectangle(cornerRadius: unit * 0.025)
                        .fill(Color(red: 1.0, green: 1.0, blue: 1.0).opacity(0.30))
                        .frame(width: w * 0.4, height: unit * 0.05)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(unit * 0.10)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}

// MARK: - Math helpers

/// Classic Hermite smoothstep — C1-continuous, so chaining it through the
/// warp factors never introduces a velocity discontinuity (no kink).
private func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
    guard edge1 > edge0 else { return x < edge0 ? 0 : 1 }
    let t = min(max((x - edge0) / (edge1 - edge0), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)
}

private func smoothstep(_ edge0: CGFloat, _ edge1: CGFloat, _ x: CGFloat) -> CGFloat {
    guard edge1 > edge0 else { return x < edge0 ? 0 : 1 }
    let t = min(max((x - edge0) / (edge1 - edge0), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)
}
