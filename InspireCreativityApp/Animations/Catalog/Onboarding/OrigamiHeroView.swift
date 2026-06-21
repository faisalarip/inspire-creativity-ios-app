// catalog-id: ob-origami-hero
import SwiftUI

/// Origami Hero Unfold
///
/// A folded paper hero that unfolds crease-by-crease. A ring of triangular
/// petals all hinge around one shared center point (so creases never separate),
/// rotating from a collapsed, viewer-facing folded triangle (`fold == 1`) into a
/// fully spread, flat figure (`fold == 0`). Each petal carries a LinearGradient
/// fold-shadow whose opacity tracks its crease angle.
///
/// - `demo == true`  : self-driving breathing loop that gently folds / unfolds
///                     with a per-petal stagger so creases open in sequence.
/// - `demo == false` : a horizontal drag scrubs the master fold parameter; on
///                     release it snaps folded / unfolded and, when unfolded,
///                     swaps in the next figure (different petal count + palette).
struct OrigamiHeroView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            let side: CGFloat = min(geo.size.width, geo.size.height)
            ZStack {
                paperBackground
                if demo {
                    demoContent(side: side)
                } else {
                    OrigamiHeroView_InteractiveOrigami(side: side)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Background

    private var paperBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.07, green: 0.055, blue: 0.10),
                Color(red: 0.12, green: 0.10, blue: 0.16)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: Demo (self-driving)

    private func demoContent(side: CGFloat) -> some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            // ~3.4s breathing loop, eased so the holds at each extreme feel paper-like.
            let phase = (sin(t * (2.0 * .pi / 3.4)) + 1.0) / 2.0
            let eased = OrigamiHeroView_OrigamiMath.easeInOut(phase)
            // Demo also drifts the figure slowly so the hero looks varied over time.
            let figure = Int((t / 6.8).truncatingRemainder(dividingBy: 3.0))
            OrigamiHeroView_OrigamiFigure(fold: eased, figureIndex: figure, side: side, staggered: true)
        }
    }
}

// MARK: - Interactive wrapper

private struct OrigamiHeroView_InteractiveOrigami: View {
    let side: CGFloat

    @State private var fold: Double = 1.0          // start folded (triangle)
    @State private var dragStart: Double? = nil
    @State private var figureIndex: Int = 0

    var body: some View {
        OrigamiHeroView_OrigamiFigure(fold: fold, figureIndex: figureIndex, side: side, staggered: false)
            .contentShape(Rectangle())
            .gesture(dragGesture)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStart == nil { dragStart = fold }
                let base = dragStart ?? fold
                // Drag right → unfold (toward 0); drag left → fold (toward 1).
                let delta = -value.translation.width / max(side, 1.0)
                fold = OrigamiHeroView_OrigamiMath.clamp(base + delta, 0.0, 1.0)
            }
            .onEnded { value in
                let predicted = -value.predictedEndTranslation.width / max(side, 1.0)
                let base = dragStart ?? fold
                let projected = OrigamiHeroView_OrigamiMath.clamp(base + predicted, 0.0, 1.0)
                dragStart = nil
                let target: Double = projected < 0.5 ? 0.0 : 1.0
                // Key the swap on the fold value where this gesture *began*, so a
                // slow, deliberate unfold still advances to the next figure.
                let wasFolded = base > 0.5
                withAnimation(.spring(response: 0.55, dampingFraction: 0.74)) {
                    fold = target
                    // Committing to fully unfolded reveals the next figure.
                    if target == 0.0 && wasFolded {
                        figureIndex = (figureIndex + 1) % 3
                    }
                }
            }
    }
}

// MARK: - The figure (a ring of hinged petals + center medallion)

private struct OrigamiHeroView_OrigamiFigure: View {
    let fold: Double            // 1 = folded triangle, 0 = flat spread
    let figureIndex: Int
    let side: CGFloat
    let staggered: Bool

    private var config: OrigamiHeroView_FigureConfig { OrigamiHeroView_FigureConfig.all[figureIndex % OrigamiHeroView_FigureConfig.all.count] }

    var body: some View {
        let petalCount = config.petalCount
        ZStack {
            // Soft contact shadow on the "paper" beneath the spread figure.
            groundShadow

            ForEach(0..<petalCount, id: \.self) { index in
                petal(index: index, count: petalCount)
            }

            centerMedallion
        }
        .frame(width: side, height: side)
        // Slight overall lift toward the viewer when folded, like paper held up.
        .scaleEffect(1.0 - 0.06 * fold)
    }

    // MARK: Ground shadow

    private var groundShadow: some View {
        // Fades in as the figure spreads flat onto the page.
        Ellipse()
            .fill(Color.black.opacity(0.28 * (1.0 - fold)))
            .frame(width: side * 0.78, height: side * 0.30)
            .blur(radius: 18)
            .offset(y: side * 0.30)
    }

    // MARK: A single hinged petal

    @ViewBuilder
    private func petal(index: Int, count: Int) -> some View {
        let localFold = staggeredFold(index: index, count: count)
        // When spread, each petal points outward at its own angle (the flat figure).
        let spreadAngle: Double = (Double(index) / Double(count)) * 360.0 + config.spreadRotation
        // When folded, all petals collapse onto a single direction → triangle stack.
        let foldedAngle: Double = config.foldedRotation
        let planarAngle: Double = OrigamiHeroView_OrigamiMath.lerp(spreadAngle, foldedAngle, localFold)

        // The crease lift: petals tip up out of the page toward the viewer as they fold.
        let creaseAngle: Double = localFold * 74.0

        OrigamiHeroView_PetalShape()
            .fill(petalGradient(index: index, count: count))
            .overlay(foldShadowOverlay(localFold: localFold))
            .overlay(creaseHighlight(localFold: localFold))
            .frame(width: side * 0.5, height: side * 0.5)
            // Anchor the petal base at the shared center of the frame.
            .offset(x: 0, y: -side * 0.25)
            // Hinge the crease lift around the petal base (its bottom edge = center).
            .rotation3DEffect(
                .degrees(creaseAngle),
                axis: (x: 1.0, y: 0.0, z: 0.0),
                anchor: .bottom,
                perspective: 0.6
            )
            // Rotate the whole petal around the shared center so creases stay joined.
            .rotationEffect(.degrees(planarAngle), anchor: .center)
            .zIndex(localFold)   // folded petals sit forward
    }

    // Per-petal staggered unfolding for the demo's sequential crease feel.
    private func staggeredFold(index: Int, count: Int) -> Double {
        guard staggered else { return fold }
        let spread = 0.22
        let center = Double(index) / Double(max(count - 1, 1))
        // Shift each petal's effective fold slightly so creases open in order.
        let shifted = fold + (center - 0.5) * spread
        return OrigamiHeroView_OrigamiMath.clamp(shifted, 0.0, 1.0)
    }

    // MARK: Petal fills & shading

    private func petalGradient(index: Int, count: Int) -> LinearGradient {
        let pair = config.palette[index % config.palette.count]
        return LinearGradient(
            colors: [pair.0, pair.1],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // Darkening fold-shadow that deepens as the crease lifts (tracks localFold).
    private func foldShadowOverlay(localFold: Double) -> some View {
        OrigamiHeroView_PetalShape()
            .fill(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.0),
                        Color.black.opacity(0.45)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .opacity(localFold)
    }

    // A thin lit edge along the crease to sell the paper fold.
    private func creaseHighlight(localFold: Double) -> some View {
        OrigamiHeroView_PetalShape()
            .stroke(
                Color(red: 1.0, green: 0.97, blue: 0.90).opacity(0.35 * localFold),
                lineWidth: 1.0
            )
    }

    // MARK: Center medallion

    private var centerMedallion: some View {
        let size = side * 0.16
        return Circle()
            .fill(
                RadialGradient(
                    colors: [config.coreInner, config.coreOuter],
                    center: .center,
                    startRadius: 0,
                    endRadius: size
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Circle().stroke(Color.white.opacity(0.18), lineWidth: 1.0)
            )
            // Shrinks a touch when folded so the triangle silhouette reads cleanly.
            .scaleEffect(0.7 + 0.3 * (1.0 - fold))
            .shadow(color: .black.opacity(0.35 * (1.0 - fold)), radius: 6, y: 3)
    }
}

// MARK: - Petal shape (an isosceles triangle hinging on its base)

private struct OrigamiHeroView_PetalShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let tip = CGPoint(x: rect.midX, y: rect.minY)
        let baseLeft = CGPoint(x: rect.midX - rect.width * 0.32, y: rect.maxY)
        let baseRight = CGPoint(x: rect.midX + rect.width * 0.32, y: rect.maxY)
        p.move(to: tip)
        p.addLine(to: baseRight)
        p.addLine(to: baseLeft)
        p.closeSubpath()
        return p
    }
}

// MARK: - Figure configuration (cheap variants for "next shape")

private struct OrigamiHeroView_FigureConfig {
    let petalCount: Int
    let palette: [(Color, Color)]
    let coreInner: Color
    let coreOuter: Color
    let spreadRotation: Double
    let foldedRotation: Double

    static let all: [OrigamiHeroView_FigureConfig] = [
        // Figure 0 — warm lotus
        OrigamiHeroView_FigureConfig(
            petalCount: 6,
            palette: [
                (Color(red: 0.98, green: 0.55, blue: 0.42), Color(red: 0.85, green: 0.30, blue: 0.42)),
                (Color(red: 0.99, green: 0.72, blue: 0.46), Color(red: 0.90, green: 0.42, blue: 0.40))
            ],
            coreInner: Color(red: 1.0, green: 0.90, blue: 0.66),
            coreOuter: Color(red: 0.92, green: 0.50, blue: 0.36),
            spreadRotation: 0.0,
            foldedRotation: 18.0
        ),
        // Figure 1 — cool star
        OrigamiHeroView_FigureConfig(
            petalCount: 5,
            palette: [
                (Color(red: 0.52, green: 0.78, blue: 0.98), Color(red: 0.32, green: 0.46, blue: 0.86)),
                (Color(red: 0.66, green: 0.86, blue: 0.99), Color(red: 0.40, green: 0.58, blue: 0.92))
            ],
            coreInner: Color(red: 0.86, green: 0.95, blue: 1.0),
            coreOuter: Color(red: 0.40, green: 0.56, blue: 0.92),
            spreadRotation: -90.0,
            foldedRotation: -30.0
        ),
        // Figure 2 — verdant bloom
        OrigamiHeroView_FigureConfig(
            petalCount: 8,
            palette: [
                (Color(red: 0.62, green: 0.90, blue: 0.62), Color(red: 0.26, green: 0.66, blue: 0.50)),
                (Color(red: 0.78, green: 0.94, blue: 0.58), Color(red: 0.40, green: 0.74, blue: 0.46))
            ],
            coreInner: Color(red: 0.96, green: 1.0, blue: 0.82),
            coreOuter: Color(red: 0.34, green: 0.68, blue: 0.46),
            spreadRotation: 22.5,
            foldedRotation: 12.0
        )
    ]
}

// MARK: - Math helpers

private enum OrigamiHeroView_OrigamiMath {
    static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        min(max(v, lo), hi)
    }

    static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }

    static func easeInOut(_ t: Double) -> Double {
        // smootherstep, gives gentle holds at the extremes
        let x = clamp(t, 0.0, 1.0)
        return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)
    }
}
