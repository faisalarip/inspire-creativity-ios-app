// catalog-id: ld-folding-origami
import SwiftUI

/// Origami Fold — a flat square creases and folds along its diagonals through a
/// short scripted sequence into a peaked, crane-like paper form, then unfolds
/// back to flat and loops. Triangular facets are Paths; each facet rotates in 3D
/// about its shared crease edge (axis = crease direction, anchor = crease
/// midpoint, both in one shared full-square coordinate space) so facets stay
/// attached. Per-facet brightness tracks the fold angle to fake directional
/// paper lighting.
///
/// Both demo and interactive modes are self-driving (the spec is `auto`); the
/// interactive build simply breathes on a slightly slower cadence.
struct FoldingOrigamiView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let paper = side * 0.66

            TimelineView(.animation) { timeline in
                let t = phase(at: timeline.date)
                ZStack {
                    FoldingOrigamiView_OrigamiBackdrop()
                    FoldingOrigamiView_OrigamiPaper(progress: t, side: paper)
                        .frame(width: paper, height: paper)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // Normalized loop phase 0...1. Slightly slower / calmer cadence in the
    // larger interactive surface so the detail view reads as more deliberate.
    private func phase(at date: Date) -> CGFloat {
        let period: Double = demo ? 4.0 : 5.0
        let secs = date.timeIntervalSinceReferenceDate
        return CGFloat((secs.truncatingRemainder(dividingBy: period)) / period)
    }
}

// MARK: - Backdrop

private struct FoldingOrigamiView_OrigamiBackdrop: View {
    var body: some View {
        RadialGradient(
            colors: [
                Color(red: 0.10, green: 0.13, blue: 0.17),
                Color(red: 0.04, green: 0.05, blue: 0.07)
            ],
            center: .center,
            startRadius: 4,
            endRadius: 220
        )
        .ignoresSafeArea()
    }
}

// MARK: - Paper assembly

private struct FoldingOrigamiView_OrigamiPaper: View {
    let progress: CGFloat   // 0...1 loop phase
    let side: CGFloat

    var body: some View {
        // Stage envelope: 0 flat → fold in → hold → unfold → flat.
        let fold = foldEnvelope(progress)        // 0 flat ... 1 fully folded
        let lift = liftEnvelope(progress)        // secondary wing lift, lags fold

        ZStack {
            // The flat base sheet (underside of the paper). Always visible so the
            // tile is never blank; it recedes as the facets fold up over it.
            baseSheet(fold: fold)

            // Four corner facets fold inward toward the center (blintz base).
            cornerFacet(.topLeft, fold: fold)
            cornerFacet(.topRight, fold: fold)
            cornerFacet(.bottomRight, fold: fold)
            cornerFacet(.bottomLeft, fold: fold)

            // Two upper petals lift further to suggest the crane's wings/neck.
            wingFacet(leading: true, fold: fold, lift: lift)
            wingFacet(leading: false, fold: fold, lift: lift)

            // A small crisp crease highlight along the central diagonals.
            creaseLines(fold: fold)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.35 * Double(fold) + 0.08),
                radius: 10 * fold + 3, x: 0, y: 6 * fold + 2)
    }

    // MARK: Base sheet

    @ViewBuilder
    private func baseSheet(fold: CGFloat) -> some View {
        let shade = 0.52 - 0.14 * Double(fold)
        RoundedRectangle(cornerRadius: 2)
            .fill(paperColor(brightness: shade))
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
            )
            .scaleEffect(1.0 - 0.04 * fold)
    }

    // MARK: FoldingOrigamiView_Corner facets (blintz fold)

    private func cornerFacet(_ corner: FoldingOrigamiView_Corner, fold: CGFloat) -> some View {
        // Each corner triangle folds toward the viewer about its inner chord.
        let angle = Double(fold) * 168.0            // up to a steep tuck
        let bright = facetBrightness(base: 0.74, angle: angle, swing: 0.30)

        return FoldingOrigamiView_CornerTriangle(corner: corner)
            .fill(
                LinearGradient(
                    colors: [
                        paperColor(brightness: bright + 0.08),
                        paperColor(brightness: bright - 0.06)
                    ],
                    startPoint: corner.gradientStart,
                    endPoint: corner.gradientEnd
                )
            )
            .overlay(
                FoldingOrigamiView_CornerTriangle(corner: corner)
                    .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
            )
            .rotation3DEffect(
                .degrees(angle),
                axis: corner.creaseAxis,
                anchor: corner.creaseAnchor,
                anchorZ: 0,
                perspective: 0.45
            )
    }

    // MARK: Wing petals (secondary lift for crane silhouette)

    private func wingFacet(leading: Bool, fold: CGFloat, lift: CGFloat) -> some View {
        let angle = Double(lift) * 128.0
        let bright = facetBrightness(base: 0.82, angle: angle, swing: 0.34)
        let axis: (CGFloat, CGFloat, CGFloat) = leading ? (1, 1, 0) : (1, -1, 0)
        // Both petals hinge on the shared neck crease at the top-center point,
        // so they stay joined while tilting to opposite sides.
        let anchor = UnitPoint(x: 0.5, y: 0.18)

        return FoldingOrigamiView_WingTriangle(leading: leading)
            .fill(
                LinearGradient(
                    colors: [
                        paperColor(brightness: bright + 0.10),
                        paperColor(brightness: bright - 0.04)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                FoldingOrigamiView_WingTriangle(leading: leading)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
            .rotation3DEffect(
                .degrees(angle),
                axis: axis,
                anchor: anchor,
                anchorZ: 0,
                perspective: 0.5
            )
            .opacity(0.35 + 0.65 * Double(fold))   // emerge as the base folds
    }

    // MARK: Crease detailing

    @ViewBuilder
    private func creaseLines(fold: CGFloat) -> some View {
        FoldingOrigamiView_DiagonalCreases()
            .stroke(Color.white.opacity(0.10 + 0.10 * Double(fold)), lineWidth: 0.6)
            .blendMode(.screen)
    }

    // MARK: Lighting + color helpers

    // Brightness as a function of the fold angle: flat-facing (0°/180°) is
    // brightest, edge-on (90°) is darkest — mimics paper catching the light.
    private func facetBrightness(base: Double, angle: Double, swing: Double) -> Double {
        let rad = angle * .pi / 180.0
        // |cos| peaks when the facet faces the camera, dips when edge-on.
        let facing = abs(cos(rad))
        return base - swing * (1.0 - facing)
    }

    // Warm paper / cream tinted toward the catalog's cool ink at low brightness.
    private func paperColor(brightness b: Double) -> Color {
        let v = max(0.0, min(1.0, b))
        let r = 0.30 + 0.66 * v
        let g = 0.40 + 0.55 * v
        let bl = 0.52 + 0.40 * v
        return Color(red: r, green: g, blue: bl)
    }

    // MARK: Fold envelopes

    // fold-in (0→1) over first 35%, hold to 55%, unfold to 90%, flat rest.
    private func foldEnvelope(_ t: CGFloat) -> CGFloat {
        if t < 0.35 {
            return easeInOut(t / 0.35)
        } else if t < 0.55 {
            return 1.0
        } else if t < 0.90 {
            return 1.0 - easeInOut((t - 0.55) / 0.35)
        } else {
            return 0.0
        }
    }

    // Wing lift lags the base fold and resolves later, then releases first.
    private func liftEnvelope(_ t: CGFloat) -> CGFloat {
        if t < 0.18 {
            return 0.0
        } else if t < 0.45 {
            return easeInOut((t - 0.18) / 0.27)
        } else if t < 0.55 {
            return 1.0
        } else if t < 0.82 {
            return 1.0 - easeInOut((t - 0.55) / 0.27)
        } else {
            return 0.0
        }
    }

    private func easeInOut(_ x: CGFloat) -> CGFloat {
        let c = max(0, min(1, x))
        return c * c * (3 - 2 * c)
    }
}

// MARK: - FoldingOrigamiView_Corner geometry

private enum FoldingOrigamiView_Corner {
    case topLeft, topRight, bottomRight, bottomLeft

    // Triangle vertices in unit space (0...1) of the FULL square frame.
    var vertices: (CGPoint, CGPoint, CGPoint) {
        switch self {
        case .topLeft:
            return (CGPoint(x: 0, y: 0), CGPoint(x: 0.5, y: 0), CGPoint(x: 0, y: 0.5))
        case .topRight:
            return (CGPoint(x: 1, y: 0), CGPoint(x: 0.5, y: 0), CGPoint(x: 1, y: 0.5))
        case .bottomRight:
            return (CGPoint(x: 1, y: 1), CGPoint(x: 1, y: 0.5), CGPoint(x: 0.5, y: 1))
        case .bottomLeft:
            return (CGPoint(x: 0, y: 1), CGPoint(x: 0, y: 0.5), CGPoint(x: 0.5, y: 1))
        }
    }

    // Crease = the inner chord (the hypotenuse facing the center). The rotation
    // axis is the crease's direction vector; anchor is the crease midpoint —
    // both expressed in the shared full-frame unit space so facets stay joined.
    var creaseAxis: (CGFloat, CGFloat, CGFloat) {
        switch self {
        case .topLeft:     return (1, -1, 0)   // (0.5,0)→(0,0.5)
        case .topRight:    return (1, 1, 0)    // (0.5,0)→(1,0.5)
        case .bottomRight: return (1, -1, 0)   // (1,0.5)→(0.5,1)
        case .bottomLeft:  return (1, 1, 0)    // (0,0.5)→(0.5,1)
        }
    }

    var creaseAnchor: UnitPoint {
        switch self {
        case .topLeft:     return UnitPoint(x: 0.25, y: 0.25)
        case .topRight:    return UnitPoint(x: 0.75, y: 0.25)
        case .bottomRight: return UnitPoint(x: 0.75, y: 0.75)
        case .bottomLeft:  return UnitPoint(x: 0.25, y: 0.75)
        }
    }

    var gradientStart: UnitPoint {
        switch self {
        case .topLeft:     return .topLeading
        case .topRight:    return .topTrailing
        case .bottomRight: return .bottomTrailing
        case .bottomLeft:  return .bottomLeading
        }
    }

    var gradientEnd: UnitPoint {
        switch self {
        case .topLeft:     return .center
        case .topRight:    return .center
        case .bottomRight: return .center
        case .bottomLeft:  return .center
        }
    }
}

private struct FoldingOrigamiView_CornerTriangle: Shape {
    let corner: FoldingOrigamiView_Corner

    func path(in rect: CGRect) -> Path {
        let (a, b, c) = corner.vertices
        var p = Path()
        p.move(to: scale(a, rect))
        p.addLine(to: scale(b, rect))
        p.addLine(to: scale(c, rect))
        p.closeSubpath()
        return p
    }

    private func scale(_ pt: CGPoint, _ rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + pt.x * rect.width,
                y: rect.minY + pt.y * rect.height)
    }
}

// MARK: - Wing petals

// Two upper triangular petals sharing the top crease, lifting to read as the
// crane's neck/wings. Anchored on their lower crease near the top of the sheet.
private struct FoldingOrigamiView_WingTriangle: Shape {
    let leading: Bool

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        if leading {
            p.move(to: CGPoint(x: rect.minX + 0.5 * w, y: rect.minY + 0.18 * h))
            p.addLine(to: CGPoint(x: rect.minX + 0.18 * w, y: rect.minY + 0.06 * h))
            p.addLine(to: CGPoint(x: rect.minX + 0.5 * w, y: rect.minY + 0.55 * h))
        } else {
            p.move(to: CGPoint(x: rect.minX + 0.5 * w, y: rect.minY + 0.18 * h))
            p.addLine(to: CGPoint(x: rect.minX + 0.82 * w, y: rect.minY + 0.06 * h))
            p.addLine(to: CGPoint(x: rect.minX + 0.5 * w, y: rect.minY + 0.55 * h))
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Crease lines

private struct FoldingOrigamiView_DiagonalCreases: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // The inscribed diamond (corner-fold creases).
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.closeSubpath()
        // Both main diagonals.
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return p
    }
}
