// catalog-id: mi-favorite-fold
import SwiftUI

// MARK: - FavoriteFoldView
/// A star favorite that folds origami-style: its five points fold inward to a
/// flat disc when off and unfold with a springy snap when favorited.
struct FavoriteFoldView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                backdrop
                content(side: side)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Backdrop

    private var backdrop: some View {
        RadialGradient(
            colors: [
                Color(red: 0.13, green: 0.10, blue: 0.17),
                Color(red: 0.08, green: 0.06, blue: 0.11)
            ],
            center: .center,
            startRadius: 0,
            endRadius: 220
        )
        .ignoresSafeArea()
    }

    // MARK: Content router

    @ViewBuilder
    private func content(side: CGFloat) -> some View {
        if demo {
            FavoriteFoldView_DemoDriver(side: side)
        } else {
            FavoriteFoldView_InteractiveStar(side: side)
        }
    }
}

// MARK: - Demo (self-driving, no touch)

private struct FavoriteFoldView_DemoDriver: View {
    let side: CGFloat

    var body: some View {
        // Auto-looping PhaseAnimator (no trigger) so the tile is always alive.
        // Three phases give a dwell on the open star, then fold shut, then a
        // brief over-folded settle before springing back open. Never blank.
        PhaseAnimator([0, 1, 2]) { phase in
            FavoriteFoldView_FoldingStar(favorited: phase == 0, side: side)
        } animation: { phase in
            switch phase {
            case 0:
                return .spring(response: 0.55, dampingFraction: 0.52)
                    .delay(0.2)
            case 1:
                return .spring(response: 0.5, dampingFraction: 0.7)
            default:
                return .easeInOut(duration: 0.9)
            }
        }
    }
}

// MARK: - Interactive (tap to toggle)

private struct FavoriteFoldView_InteractiveStar: View {
    let side: CGFloat
    @State private var favorited: Bool = true

    var body: some View {
        FavoriteFoldView_FoldingStar(favorited: favorited, side: side)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                    favorited.toggle()
                }
            }
            .sensoryFeedback(.impact(flexibility: .soft), trigger: favorited)
    }
}

// MARK: - The folding star assembly

private struct FavoriteFoldView_FoldingStar: View {
    var favorited: Bool
    let side: CGFloat

    /// Drives all geometry. 0 == fully open sharp star, 1 == flat disc.
    private var fold: CGFloat { favorited ? 0 : 1 }

    private var dim: CGFloat { side * 0.62 }
    private var outerR: CGFloat { dim * 0.5 }
    private var innerR: CGFloat { dim * 0.5 * 0.40 }

    var body: some View {
        ZStack {
            haloGlow
            baseDisc
            starFill
            facetShading
            outlineStroke
            centerSheen
        }
        .frame(width: dim, height: dim)
        .scaleEffect(favorited ? 1.0 : 0.96)
    }

    // Soft warm glow that strengthens when favorited.
    private var haloGlow: some View {
        FavoriteFoldView_FoldingStarShape(fold: fold, outerR: outerR, innerR: innerR)
            .fill(Color(red: 1.0, green: 0.78, blue: 0.30))
            .blur(radius: dim * 0.16)
            .opacity(0.55 - Double(fold) * 0.4)
    }

    // A constant disc underneath so the shape never reads as empty mid-fold.
    private var baseDisc: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.30, green: 0.26, blue: 0.34),
                        Color(red: 0.20, green: 0.17, blue: 0.24)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: innerR * 2.06, height: innerR * 2.06)
            .opacity(Double(fold))
    }

    private var starFill: some View {
        FavoriteFoldView_FoldingStarShape(fold: fold, outerR: outerR, innerR: innerR)
            .fill(bodyGradient)
            .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 4)
    }

    private var bodyGradient: LinearGradient {
        // Lerp known literal stops as plain (r,g,b) tuples — no UIColor.
        let openTop: (Double, Double, Double) = (1.0, 0.86, 0.34)
        let openBot: (Double, Double, Double) = (0.98, 0.62, 0.16)
        let foldTop: (Double, Double, Double) = (0.42, 0.37, 0.46)
        let foldBot: (Double, Double, Double) = (0.28, 0.24, 0.32)
        let f = Double(fold)
        return LinearGradient(
            colors: [
                lerpColor(openTop, foldTop, f),
                lerpColor(openBot, foldBot, f)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Per-point directional fold shadows registered to the same vertices.
    private var facetShading: some View {
        FavoriteFoldView_FacetShadeShape(fold: fold, outerR: outerR, innerR: innerR)
            .fill(Color.black)
            .opacity(0.04 + Double(fold) * 0.30)
            .blendMode(.multiply)
    }

    private var outlineStroke: some View {
        FavoriteFoldView_FoldingStarShape(fold: fold, outerR: outerR, innerR: innerR)
            .stroke(
                Color.white.opacity(0.18 + (1 - Double(fold)) * 0.22),
                lineWidth: max(1, dim * 0.012)
            )
    }

    // A small bright crease highlight in the middle that fades when folded.
    private var centerSheen: some View {
        Circle()
            .fill(Color.white)
            .frame(width: innerR * 0.5, height: innerR * 0.5)
            .blur(radius: innerR * 0.28)
            .opacity(0.5 * (1 - Double(fold)))
            .offset(x: -innerR * 0.18, y: -innerR * 0.22)
    }

    private func lerpColor(
        _ a: (Double, Double, Double),
        _ b: (Double, Double, Double),
        _ t: Double
    ) -> Color {
        let ct = min(max(t, 0), 1)
        return Color(
            red: a.0 + (b.0 - a.0) * ct,
            green: a.1 + (b.1 - a.1) * ct,
            blue: a.2 + (b.2 - a.2) * ct
        )
    }
}

// MARK: - Star geometry helpers (shared formula keeps facets registered)

private func starVertices(
    fold: CGFloat,
    outerR: CGFloat,
    innerR: CGFloat,
    center: CGPoint
) -> [CGPoint] {
    // Always 10 vertices: 5 outer tips + 5 inner valleys, constant count so
    // interpolation is clean. The outer radius lerps from a sharp star toward
    // the inner radius (a near-regular decagon ~ flat disc) as fold -> 1.
    let clamped = max(min(fold, 1.05), -0.25)
    // On the folding-shut side, floor the outer radius at the inner radius so a
    // spring overshoot past fold=1 cannot invert the shape. Overshoot below 0
    // is allowed (tips pop out past the full star = the satisfying snap).
    let rawOuter = outerR + (innerR - outerR) * clamped
    let liveOuter = max(rawOuter, innerR)

    var pts: [CGPoint] = []
    pts.reserveCapacity(10)
    let startAngle = -CGFloat.pi / 2
    for i in 0..<5 {
        let outerAngle = startAngle + CGFloat(i) * (.pi * 2 / 5)
        let innerAngle = outerAngle + (.pi / 5)
        pts.append(CGPoint(
            x: center.x + liveOuter * cos(outerAngle),
            y: center.y + liveOuter * sin(outerAngle)
        ))
        pts.append(CGPoint(
            x: center.x + innerR * cos(innerAngle),
            y: center.y + innerR * sin(innerAngle)
        ))
    }
    return pts
}

// MARK: - Animatable star shape

private struct FavoriteFoldView_FoldingStarShape: Shape {
    var fold: CGFloat
    var outerR: CGFloat
    var innerR: CGFloat

    var animatableData: CGFloat {
        get { fold }
        set { fold = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let pts = starVertices(
            fold: fold, outerR: outerR, innerR: innerR, center: center
        )
        var path = Path()
        guard let first = pts.first else { return path }
        path.move(to: first)
        for p in pts.dropFirst() { path.addLine(to: p) }
        path.closeSubpath()
        return path
    }
}

// MARK: - Facet shade shape (alternating triangles darken as fold increases)

private struct FavoriteFoldView_FacetShadeShape: Shape {
    var fold: CGFloat
    var outerR: CGFloat
    var innerR: CGFloat

    var animatableData: CGFloat {
        get { fold }
        set { fold = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let pts = starVertices(
            fold: fold, outerR: outerR, innerR: innerR, center: center
        )
        var path = Path()
        guard pts.count == 10 else { return path }
        // Shade one flank of each point (a triangle from center to the tip and
        // its trailing valley) to read as a folded crease side.
        for i in 0..<5 {
            let tip = pts[i * 2]
            let valley = pts[(i * 2 + 1) % 10]
            path.move(to: center)
            path.addLine(to: tip)
            path.addLine(to: valley)
            path.closeSubpath()
        }
        return path
    }
}
