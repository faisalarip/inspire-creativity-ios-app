// catalog-id: tr-origami-unfold
import SwiftUI

/// Origami Unfold — a folded paper card opens along three creased panels that
/// rotate in sequence on alternating hinge axes, revealing the destination view
/// as the paper flattens. Each panel casts a soft crease-shadow on the one
/// beneath it so it reads as real folded paper unfurling rather than a flat flip.
///
/// A single 0→1 `progress` drives all three hinge angles via STAGGERED windows
/// (`panelProgress`), so the flaps open one after another. For the stagger to
/// actually render, `progress` must flow through continuous intermediate values
/// — SwiftUI only re-evaluates a body at animation endpoints, so we never let it
/// interpolate the raw rotation angles directly:
/// - demo == true  → `TimelineView(.animation)` feeds a continuous 0→1→0 ramp.
/// - demo == false → `OrigamiUnfoldView_FoldingCard` is `Animatable` on `progress`, so
///   `withAnimation(.spring)` interpolates `progress` THROUGH the body, which
///   re-runs `panelProgress` every frame and surfaces the real staggered fold.
struct OrigamiUnfoldView: View {
    var demo: Bool = false

    @State private var isOpen: Bool = false

    var body: some View {
        GeometryReader { geo in
            content(size: geo.size)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(size: CGSize) -> some View {
        if demo {
            TimelineView(.animation) { timeline in
                let p = OrigamiUnfoldView.loopProgress(timeline.date)
                OrigamiUnfoldView_FoldingCard(progress: p, size: size)
            }
        } else {
            OrigamiUnfoldView_FoldingCard(progress: isOpen ? 1.0 : 0.0, size: size)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(duration: 0.6, bounce: 0.22)) {
                        isOpen.toggle()
                    }
                }
        }
    }

    /// Continuous, looping 0→1→0 triangle ramp (~3.2s) with a smooth ease so the
    /// demo tile breathes open and closed forever with no input. Never settles
    /// at a blank state — the base card is always legible underneath.
    private static func loopProgress(_ date: Date) -> Double {
        let period: Double = 3.2
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
        let triangle = t < 0.5 ? (t * 2.0) : (2.0 - t * 2.0)   // 0→1→0
        return triangle * triangle * (3.0 - 2.0 * triangle)     // smoothstep ease
    }
}

// MARK: - Animatable folding card

/// The folded card: a fixed base panel plus three flaps that fold over it.
/// Conforming to `Animatable` on `progress` is what makes the staggered
/// sequence visible during `withAnimation` — SwiftUI interpolates `progress`
/// and re-runs `body` (hence `panelProgress`) on every frame.
private struct OrigamiUnfoldView_FoldingCard: View, Animatable {
    var progress: Double
    var size: CGSize

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let side = min(size.width, size.height)
        // Open, the card is a cross 3·unit tall × 2·unit wide; unit = 0.30·side
        // keeps it inside both a ~120pt grid tile and a large detail area.
        let unit = side * 0.30
        let cx = size.width / 2
        let cy = size.height / 2

        return ZStack {
            backdrop
            card(unit: unit)
                .position(x: cx, y: cy)
        }
    }

    /// Soft ambient backdrop that warms slightly as the card opens, so a frame
    /// is never blank even at the folded extreme.
    private var backdrop: some View {
        let warm = 0.06 + clamp(progress, 0, 1) * 0.05
        return LinearGradient(
            colors: [
                Color(red: 0.05 + warm, green: 0.06 + warm, blue: 0.10 + warm),
                Color(red: 0.03, green: 0.035, blue: 0.06)
            ],
            startPoint: .top, endPoint: .bottom
        )
    }
}

// MARK: - Card composition

private extension OrigamiUnfoldView_FoldingCard {

    func card(unit: CGFloat) -> some View {
        // Three flaps unfold over overlapping staggered windows so only one is
        // ever near edge-on at a time and the motion reads as a sequence.
        let pAbove = panelProgress(index: 0)   // .x hinge (top)
        let pRight = panelProgress(index: 1)   // .y hinge
        let pBelow = panelProgress(index: 2)   // .x hinge (bottom)

        return ZStack {
            // Base — always face-on, the anchor the flaps fold onto. Its emblem
            // is the revealed content, so something legible shows beneath the
            // folding paper at every frame.
            basePanel(unit: unit)

            foldingPanel(unit: unit, fold: pAbove, slot: .above,
                         glyph: "leaf.fill",
                         tint: Color(red: 0.36, green: 0.72, blue: 0.62))
            foldingPanel(unit: unit, fold: pRight, slot: .right,
                         glyph: "sparkles",
                         tint: Color(red: 0.95, green: 0.78, blue: 0.42))
            foldingPanel(unit: unit, fold: pBelow, slot: .below,
                         glyph: "moon.stars.fill",
                         tint: Color(red: 0.62, green: 0.55, blue: 0.95))
        }
        .frame(width: unit, height: unit)
    }

    /// The fixed base square; the emblem fades up as the card opens.
    func basePanel(unit: CGFloat) -> some View {
        let reveal = smoothstep(progress)
        return RoundedRectangle(cornerRadius: unit * 0.07, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.97, green: 0.96, blue: 0.93),
                        Color(red: 0.90, green: 0.88, blue: 0.83)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: unit * 0.34, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.40, green: 0.66, blue: 0.95),
                                Color(red: 0.66, green: 0.46, blue: 0.92)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .opacity(0.28 + reveal * 0.62)
                    .scaleEffect(0.84 + reveal * 0.16)
            }
            .overlay(
                RoundedRectangle(cornerRadius: unit * 0.07, style: .continuous)
                    .stroke(Color(red: 0.82, green: 0.80, blue: 0.74), lineWidth: 0.8)
            )
            .frame(width: unit, height: unit)
            .shadow(color: Color.black.opacity(0.35), radius: unit * 0.06, y: unit * 0.03)
    }
}

// MARK: - Folding flap

private extension OrigamiUnfoldView_FoldingCard {

    /// Describes a flap by its OPEN position relative to the base. Its hinge is
    /// the edge SHARED with the base, so the flap anchors on its inner edge and
    /// a constant offset + a 180°→0° rotation lands it exactly on the base when
    /// closed. Alternating .x / .y / .x axes per the spec.
    enum FlapSlot {
        case above, right, below

        var axis: (x: CGFloat, y: CGFloat, z: CGFloat) {
            switch self {
            case .above, .below: return (1, 0, 0)   // .x hinge
            case .right:         return (0, 1, 0)    // .y hinge
            }
        }

        /// Anchor = the edge shared with the base (the flap's inner edge).
        var anchor: UnitPoint {
            switch self {
            case .above: return .bottom
            case .right: return .leading
            case .below: return .top
            }
        }

        /// Constant offset placing the flap at its OPEN (coplanar) location.
        func offset(unit: CGFloat) -> (CGFloat, CGFloat) {
            switch self {
            case .above: return (0, -unit)
            case .right: return (unit, 0)
            case .below: return (0, unit)
            }
        }

        /// Crease-shadow gradient: dark at the hinge (inner) edge → clear at
        /// the free (outer) edge.
        var gradientPoints: (UnitPoint, UnitPoint) {
            switch self {
            case .above: return (.bottom, .top)
            case .right: return (.leading, .trailing)
            case .below: return (.top, .bottom)
            }
        }
    }

    /// One flap. `fold` 0 = folded flat over the base (closed card), 1 = laid
    /// flat outward beside the base (open sheet). The flap sits at a CONSTANT
    /// open offset and rotates 180°→0° about its shared (hinge) edge: at 180°
    /// the flip lands it exactly on the base (covering it, fully legible); at 0°
    /// it lies coplanar, extending the sheet. The rotation does all the
    /// translation — no animated offset needed. Layer order keeps flaps
    /// composited over the base, so the sweep direction reads as a fold.
    func foldingPanel(unit: CGFloat, fold: Double, slot: FlapSlot,
                      glyph: String, tint: Color) -> some View {
        let f = smoothstep(fold)
        let angle: Double = 180.0 * (1.0 - f)   // 180° closed → 0° open
        let (dx, dy) = slot.offset(unit: unit)

        return panelFace(unit: unit, glyph: glyph, tint: tint, openness: f)
            .overlay { creaseShadow(unit: unit, slot: slot, fold: fold) }
            .frame(width: unit, height: unit)
            .rotation3DEffect(
                .degrees(angle),
                axis: slot.axis,
                anchor: slot.anchor,
                perspective: 0.45
            )
            .offset(x: dx, y: dy)
            .zIndex(2.0 - f)   // closed flaps stack on top; open they recede
    }

    /// The paper face of a flap — warm card stock with a soft tinted glyph.
    func panelFace(unit: CGFloat, glyph: String, tint: Color, openness: Double) -> some View {
        // Past 90° (openness < 0.5) the flap shows its back; SwiftUI mirrors
        // front content, so fade the glyph out while folded.
        let glyphOpacity = max(0.0, (openness - 0.5) * 2.0) * 0.9
        return RoundedRectangle(cornerRadius: unit * 0.07, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.99, green: 0.98, blue: 0.96),
                        Color(red: 0.93, green: 0.91, blue: 0.86)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: glyph)
                    .font(.system(size: unit * 0.26, weight: .regular))
                    .foregroundStyle(tint)
                    .opacity(glyphOpacity)
            }
            .overlay(
                RoundedRectangle(cornerRadius: unit * 0.07, style: .continuous)
                    .stroke(Color(red: 0.84, green: 0.81, blue: 0.75), lineWidth: 0.8)
            )
    }

    /// A gradient that darkens toward the hinge edge and deepens while the flap
    /// is still folded, so the crease reads as a real shadowed fold.
    func creaseShadow(unit: CGFloat, slot: FlapSlot, fold: Double) -> some View {
        let depth = 1.0 - smoothstep(fold)   // strong when folded, gone when flat
        let (start, end) = slot.gradientPoints
        return RoundedRectangle(cornerRadius: unit * 0.07, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.black.opacity(depth * 0.55),
                        Color.black.opacity(0.0)
                    ],
                    startPoint: start, endPoint: end
                )
            )
            .blendMode(.multiply)
    }
}

// MARK: - Progress shaping

private extension OrigamiUnfoldView_FoldingCard {

    /// Stagger the three flaps across the master progress so they open in
    /// sequence (above → right → below). Each opens over a 0.6-wide window
    /// offset by 0.2 per index; windows overlap so the motion stays fluid while
    /// only one flap is ever near edge-on at a time.
    func panelProgress(index: Int) -> Double {
        let start = Double(index) * 0.20
        let span: Double = 0.60
        let local = (progress - start) / span
        return clamp(local, 0.0, 1.0)
    }
}

// MARK: - Math helpers (file-private free functions)

private func smoothstep(_ x: Double) -> Double {
    let t = clamp(x, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)
}

private func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
    min(max(v, lo), hi)
}
