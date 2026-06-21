// catalog-id: btn-origami-fold
import SwiftUI

// MARK: - OrigamiFoldView
// "Paper Plane Fold" — tapping folds the rectangular button along diagonal
// creases into a paper airplane that launches, then unfolds back on reset.
// Pure SwiftUI: rotation3DEffect about diagonal axes + a phased sequence.
public struct OrigamiFoldView: View {
    public var demo: Bool = false

    // Tap trigger for the interactive phase animator.
    @State private var tapCount: Int = 0

    // Explicit phase sequence that begins AND ends on .idle, so the piece
    // rests on a legible flat button regardless of how PhaseAnimator settles
    // (rest-on-first vs rest-on-last). The idle/idle seam is a clean beat.
    private let phases: [OrigamiFoldView_FoldPhase] = [.idle, .creasing, .folded, .launched, .idle]

    public init(demo: Bool = false) {
        self.demo = demo
    }

    public var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                if demo {
                    autoDrivenPlane(side: side)
                } else {
                    interactivePlane(side: side)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    // MARK: Auto-driven (demo) — continuous loop, no touch, never blank.
    @ViewBuilder
    private func autoDrivenPlane(side: CGFloat) -> some View {
        plane(side: side, phase: .idle)
            .phaseAnimator(phases) { content, phase in
                content
                    .modifier(OrigamiFoldView_FoldEffect(phase: phase, side: side))
            } animation: { phase in
                phase.animation
            }
    }

    // MARK: Interactive — tap to fold + launch, then unfold back to idle.
    @ViewBuilder
    private func interactivePlane(side: CGFloat) -> some View {
        plane(side: side, phase: .idle)
            .phaseAnimator(phases, trigger: tapCount) { content, phase in
                content
                    .modifier(OrigamiFoldView_FoldEffect(phase: phase, side: side))
            } animation: { phase in
                phase.animation
            }
            .onTapGesture {
                tapCount += 1
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: tapCount)
    }

    // MARK: The plane itself — two triangular panels that fold about the
    // shared diagonal crease, plus a fuselage spine and a printed label.
    @ViewBuilder
    private func plane(side: CGFloat, phase: OrigamiFoldView_FoldPhase) -> some View {
        let w = side * 0.78
        let h = side * 0.48

        ZStack {
            // Base body (the "paper") — keeps the silhouette readable in idle.
            bodyPanel(width: w, height: h)

            // Left wing panel, folds up about the body's leading diagonal.
            wingPanel(width: w, height: h, isLeading: true)

            // Right wing panel, folds up about the body's trailing diagonal.
            wingPanel(width: w, height: h, isLeading: false)

            // Center spine / fuselage crease highlight.
            spine(width: w, height: h)

            // Printed glyph on the paper — fades as it folds into a plane.
            label(side: side)
        }
        .frame(width: w, height: h)
    }

    // MARK: Body panel (flat sheet base)
    @ViewBuilder
    private func bodyPanel(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height * 0.16, style: .continuous)
            .fill(paperBase)
            .overlay(
                RoundedRectangle(cornerRadius: height * 0.16, style: .continuous)
                    .stroke(creaseLine, lineWidth: 0.8)
            )
            .frame(width: width, height: height)
    }

    // MARK: One triangular wing that creases up about a diagonal axis.
    // The fold angle/perspective are applied by OrigamiFoldView_FoldEffect on the whole
    // plane; here each wing carries its own crease-shaded gradient so the
    // fold reads as 3D paper rather than a flat scale.
    @ViewBuilder
    private func wingPanel(width: CGFloat, height: CGFloat, isLeading: Bool) -> some View {
        OrigamiFoldView_WingTriangle(isLeading: isLeading)
            .fill(isLeading ? wingGradientLeading : wingGradientTrailing)
            .overlay(
                OrigamiFoldView_WingTriangle(isLeading: isLeading)
                    .stroke(creaseLine, lineWidth: 0.9)
            )
            .frame(width: width, height: height)
    }

    // MARK: Fuselage spine — the central diagonal crease the wings fold around.
    @ViewBuilder
    private func spine(width: CGFloat, height: CGFloat) -> some View {
        OrigamiFoldView_SpineShape()
            .stroke(
                LinearGradient(
                    colors: [
                        Color(red: 0.40, green: 0.36, blue: 0.30).opacity(0.0),
                        Color(red: 0.40, green: 0.36, blue: 0.30).opacity(0.55),
                        Color(red: 0.40, green: 0.36, blue: 0.30).opacity(0.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
            )
            .frame(width: width, height: height)
    }

    // MARK: Printed label glyph
    @ViewBuilder
    private func label(side: CGFloat) -> some View {
        Image(systemName: "paperplane.fill")
            .font(.system(size: side * 0.16, weight: .semibold))
            .foregroundStyle(Color(red: 0.30, green: 0.26, blue: 0.20).opacity(0.55))
            .rotationEffect(.degrees(-20))
    }

    // MARK: - Paper palette
    private var paperBase: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.97, green: 0.95, blue: 0.90),
                Color(red: 0.91, green: 0.88, blue: 0.81)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var wingGradientLeading: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.99, green: 0.97, blue: 0.93),
                Color(red: 0.86, green: 0.82, blue: 0.73)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var wingGradientTrailing: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.88, green: 0.84, blue: 0.76),
                Color(red: 0.78, green: 0.73, blue: 0.63)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var creaseLine: Color {
        Color(red: 0.55, green: 0.50, blue: 0.42).opacity(0.45)
    }
}

// MARK: - Fold phases & transforms
private enum OrigamiFoldView_FoldPhase: CaseIterable {
    case idle       // flat, legible button
    case creasing   // wings lifting along the diagonals
    case folded     // fully folded paper airplane
    case launched   // glides toward a corner (PARTIAL exit — never blank)

    // How far the wings are folded up, 0 (flat) → 1 (full).
    var foldProgress: CGFloat {
        switch self {
        case .idle:     return 0
        case .creasing: return 0.55
        case .folded:   return 1
        case .launched: return 1
        }
    }

    // Out-of-plane fold angle for the wings.
    var wingAngle: Double {
        Double(foldProgress) * 74.0
    }

    // Whole-plane pitch as it tips into a 3D paper form.
    var pitch: Double {
        switch self {
        case .idle:     return 0
        case .creasing: return 6
        case .folded:   return 14
        case .launched: return 22
        }
    }

    // Heading rotation when it flies off.
    var heading: Double {
        switch self {
        case .launched: return -28
        case .folded:   return -4
        default:        return 0
        }
    }

    // Screen offset as a FRACTION of the layout side (kept partial so the
    // tile never goes blank — the plane glides toward, not past, the corner).
    var offsetFraction: CGSize {
        switch self {
        case .launched: return CGSize(width: 0.34, height: -0.30)
        case .folded:   return CGSize(width: 0.04, height: -0.02)
        default:        return .zero
        }
    }

    var scale: CGFloat {
        switch self {
        case .idle:     return 1.0
        case .creasing: return 0.98
        case .folded:   return 0.92
        case .launched: return 0.56
        }
    }

    // Always legible — launched stays at 0.7, never disappears.
    var opacity: Double {
        switch self {
        case .launched: return 0.70
        default:        return 1.0
        }
    }

    // Per-phase pacing so a full cycle lands around ~3s with an idle dwell.
    var animation: Animation {
        switch self {
        case .idle:     return .easeInOut(duration: 0.55)
        case .creasing: return .spring(response: 0.45, dampingFraction: 0.78)
        case .folded:   return .spring(response: 0.40, dampingFraction: 0.85)
        case .launched: return .easeIn(duration: 0.75)
        }
    }
}

// MARK: - The fold + launch transform applied to the whole plane.
// Each wing is folded individually via the OrigamiFoldView_FoldEffect-aware WingFolder so the
// crease reads as true 3D paper about the diagonal axes.
private struct OrigamiFoldView_FoldEffect: ViewModifier {
    let phase: OrigamiFoldView_FoldPhase
    let side: CGFloat

    func body(content: Content) -> some View {
        content
            // Fold the two wings up about their diagonal creases. Because the
            // wing triangles share the body's diagonals, a y-axis-biased
            // diagonal rotation reads as the classic paper-plane crease.
            .modifier(OrigamiFoldView_WingFoldModifier(angle: phase.wingAngle))
            // Whole-plane pitch into a 3D paper attitude.
            .rotation3DEffect(
                .degrees(phase.pitch),
                axis: (x: CGFloat(1), y: CGFloat(0), z: CGFloat(0)),
                anchor: .center,
                perspective: 0.6
            )
            // Heading turn as it banks away.
            .rotationEffect(.degrees(phase.heading))
            .scaleEffect(phase.scale)
            .offset(
                x: phase.offsetFraction.width * side,
                y: phase.offsetFraction.height * side
            )
            .opacity(phase.opacity)
    }
}

// MARK: - Folds the symmetric wings about the central diagonal creases.
// A single y-axis rotation3DEffect with a diagonal-biased axis lifts both
// wing halves symmetrically about the spine, giving the dihedral crease.
private struct OrigamiFoldView_WingFoldModifier: ViewModifier {
    let angle: Double

    func body(content: Content) -> some View {
        content
            // Lift wings out of plane about the vertical spine (y) blended
            // toward the diagonal (small x component) for the crease feel.
            .rotation3DEffect(
                .degrees(angle),
                axis: (x: CGFloat(0.18), y: CGFloat(1), z: CGFloat(0)),
                anchor: .center,
                perspective: 0.7
            )
            // A faint counter on the orthogonal diagonal sharpens the crease.
            .rotation3DEffect(
                .degrees(angle * 0.22),
                axis: (x: CGFloat(1), y: CGFloat(0.0), z: CGFloat(0)),
                anchor: .bottom,
                perspective: 0.4
            )
    }
}

// MARK: - Geometry: one wing triangle (half the sheet, split on a diagonal)
private struct OrigamiFoldView_WingTriangle: Shape {
    let isLeading: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        // The nose is the leading mid-height tip; each wing is a triangle from
        // the nose to the trailing top/bottom corner and back along the spine.
        let nose = CGPoint(x: rect.minX, y: rect.midY)
        let tailTop = CGPoint(x: rect.maxX, y: rect.minY)
        let tailBottom = CGPoint(x: rect.maxX, y: rect.maxY)
        let tailMid = CGPoint(x: rect.maxX, y: rect.midY)

        p.move(to: nose)
        if isLeading {
            p.addLine(to: tailTop)
            p.addLine(to: tailMid)
        } else {
            p.addLine(to: tailBottom)
            p.addLine(to: tailMid)
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Geometry: the fuselage spine (nose → tail center line)
private struct OrigamiFoldView_SpineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}
