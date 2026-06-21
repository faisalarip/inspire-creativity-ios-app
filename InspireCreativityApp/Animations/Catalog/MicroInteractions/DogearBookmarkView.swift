// catalog-id: mi-dogear-bookmark
import SwiftUI

// MARK: - Dog-Ear Bookmark
// Tapping a card folds its top-trailing corner down into a triangular
// dog-ear with a progress-driven lifted-flap shadow and a darker page
// underside, revealing a warm bookmark accent pocket beneath.
// demo == true  -> PhaseAnimator self-drives the fold/unfold on a ~3.2s loop.
// demo == false -> a tap toggles the saved state and folds the corner.

public struct DogearBookmarkView: View {
    public var demo: Bool = false

    public init(demo: Bool = false) {
        self.demo = demo
    }

    @State private var isSaved: Bool = false

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            content(in: size)
                .frame(width: size.width, height: size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if demo {
            demoContent(in: size)
        } else {
            interactiveContent(in: size)
        }
    }

    // MARK: Demo (self-driving)

    private func demoContent(in size: CGSize) -> some View {
        PhaseAnimator(DogearBookmarkView_DogEarPhase.allCases) { phase in
            cardView(in: size, foldProgress: phase.progress)
        } animation: { phase in
            switch phase {
            case .flat, .folded:
                return .spring(duration: 0.62, bounce: 0.30)
            case .flatHold, .foldedHold:
                return .linear(duration: 0.95)
            }
        }
    }

    // MARK: Interactive (tap)

    private func interactiveContent(in size: CGSize) -> some View {
        cardView(in: size, foldProgress: isSaved ? 1 : 0)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(duration: 0.55, bounce: 0.30)) {
                    isSaved.toggle()
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: isSaved)
    }

    // MARK: Card composition

    private func cardView(in size: CGSize, foldProgress p: CGFloat) -> some View {
        let dim = min(size.width, size.height)
        let ear: CGFloat = dim * 0.30
        let inset: CGFloat = dim * 0.085
        let cardW = size.width - inset * 2
        let cardH = size.height - inset * 2
        let corner: CGFloat = max(8, dim * 0.10)

        return ZStack {
            DogearBookmarkView_CardFace(cornerRadius: corner, ear: ear)
                .fill(cardFaceColor)
                .overlay(
                    cardContent(width: cardW, height: cardH, ear: ear, progress: p)
                )
                .overlay(
                    DogearBookmarkView_CardFace(cornerRadius: corner, ear: ear)
                        .stroke(strokeColor, lineWidth: max(0.75, dim * 0.006))
                )
                .frame(width: cardW, height: cardH)
                .background(
                    DogearBookmarkView_CardFace(cornerRadius: corner, ear: ear)
                        .fill(cardFaceColor)
                        .frame(width: cardW, height: cardH)
                        .shadow(color: ambientShadow, radius: dim * 0.05,
                                x: 0, y: dim * 0.025)
                )
                .compositingGroup()

            dogEarLayer(width: cardW, height: cardH, ear: ear, progress: p)
                .frame(width: cardW, height: cardH)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: Dog-ear layers

    private func dogEarLayer(width: CGFloat, height: CGFloat,
                             ear: CGFloat, progress p: CGFloat) -> some View {
        // Local card space origin is the layer's top-left.
        let halfW = width / 2
        let halfH = height / 2

        return ZStack {
            // Reveal pocket — the warm bookmark accent exposed as the page lifts.
            DogearBookmarkView_RevealPocket(ear: ear, progress: p)
                .fill(pocketGradient)
                .opacity(Double(min(1, p * 1.4)))

            // Folded flap (the page's back, darker underside) with lifted shadow.
            DogearBookmarkView_FoldFlap(ear: ear, foldProgress: p)
                .fill(undersideGradient(progress: p))
                .overlay(
                    DogearBookmarkView_FoldFlap(ear: ear, foldProgress: p)
                        .fill(flapSheen(progress: p))
                )
                .shadow(color: flapShadowColor(progress: p),
                        radius: ear * 0.22 * p,
                        x: -ear * 0.18 * p,
                        y: ear * 0.20 * p)
        }
        // Position the (0,0)…(width,height) shape space within the layer frame.
        .offset(x: -halfW, y: -halfH)
        .frame(width: width, height: height, alignment: .topLeading)
        .offset(x: halfW, y: halfH)
        .allowsHitTesting(false)
    }

    // MARK: Card inner content (title / bookmark hint)

    private func cardContent(width: CGFloat, height: CGFloat,
                             ear: CGFloat, progress p: CGFloat) -> some View {
        let pad: CGFloat = max(6, width * 0.10)
        let lineColor = textColor.opacity(0.9)
        let barH: CGFloat = max(3, height * 0.045)

        return VStack(alignment: .leading, spacing: barH * 0.9) {
            HStack(spacing: barH * 0.7) {
                Circle()
                    .fill(accentColor.opacity(0.9))
                    .frame(width: barH * 2.0, height: barH * 2.0)
                    .overlay(
                        Image(systemName: p > 0.5 ? "bookmark.fill" : "bookmark")
                            .font(.system(size: barH * 1.05, weight: .bold))
                            .foregroundStyle(Color(red: 1, green: 1, blue: 1))
                    )
                    .scaleEffect(1 + 0.10 * p)
                Spacer(minLength: 0)
            }
            RoundedRectangle(cornerRadius: barH / 2)
                .fill(lineColor)
                .frame(width: width * 0.55, height: barH)
            RoundedRectangle(cornerRadius: barH / 2)
                .fill(lineColor.opacity(0.55))
                .frame(width: width * 0.72, height: barH * 0.8)
            RoundedRectangle(cornerRadius: barH / 2)
                .fill(lineColor.opacity(0.45))
                .frame(width: width * 0.40, height: barH * 0.8)
            Spacer(minLength: 0)
        }
        .padding(pad)
        .frame(width: width, height: height, alignment: .topLeading)
        .clipShape(Rectangle())
    }

    // MARK: Palette (literal colors — no app dependencies)

    private var cardFaceColor: Color {
        Color(red: 0.97, green: 0.96, blue: 0.93)
    }

    private var strokeColor: Color {
        Color(red: 0.0, green: 0.0, blue: 0.0).opacity(0.06)
    }

    private var ambientShadow: Color {
        Color(red: 0.05, green: 0.04, blue: 0.10).opacity(0.30)
    }

    private var textColor: Color {
        Color(red: 0.20, green: 0.18, blue: 0.16)
    }

    private var accentColor: Color {
        Color(red: 0.93, green: 0.46, blue: 0.30)
    }

    private var pocketGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.96, green: 0.55, blue: 0.32),
                Color(red: 0.89, green: 0.36, blue: 0.28)
            ],
            startPoint: .topTrailing,
            endPoint: .bottomLeading
        )
    }

    private func undersideGradient(progress p: CGFloat) -> LinearGradient {
        // Card color at rest -> darker page back as it folds, so the
        // flap is invisible (matches the card) at p == 0.
        let t = Double(p)
        let face = (r: 0.97, g: 0.96, b: 0.93)
        let topTint = (r: 0.80, g: 0.77, b: 0.71)
        let botTint = (r: 0.64, g: 0.61, b: 0.55)
        let top = Color(red: lerp(face.r, topTint.r, t),
                        green: lerp(face.g, topTint.g, t),
                        blue: lerp(face.b, topTint.b, t))
        let bottom = Color(red: lerp(face.r, botTint.r, t),
                           green: lerp(face.g, botTint.g, t),
                           blue: lerp(face.b, botTint.b, t))
        return LinearGradient(colors: [top, bottom],
                              startPoint: .top, endPoint: .bottomLeading)
    }

    private func flapSheen(progress p: CGFloat) -> LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1, green: 1, blue: 1).opacity(0.18 * Double(p)),
                Color(red: 0, green: 0, blue: 0).opacity(0.0)
            ],
            startPoint: .topTrailing,
            endPoint: .bottomLeading
        )
    }

    private func flapShadowColor(progress p: CGFloat) -> Color {
        Color(red: 0.10, green: 0.08, blue: 0.06).opacity(0.42 * Double(p))
    }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        let clamped = min(max(t, 0), 1)
        return a + (b - a) * clamped
    }
}

// MARK: - Demo phases

private enum DogearBookmarkView_DogEarPhase: CaseIterable {
    case flat, flatHold, folded, foldedHold

    var progress: CGFloat {
        switch self {
        case .flat, .flatHold: return 0
        case .folded, .foldedHold: return 1
        }
    }
}

// MARK: - Card silhouette with the corner notch

/// The card outline, with its top-trailing corner cut along the fold line so
/// the lifted flap reads as a real removed corner rather than an overlay.
private struct DogearBookmarkView_CardFace: Shape {
    var cornerRadius: CGFloat
    var ear: CGFloat

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let r = min(cornerRadius, min(w, h) / 2)
        let s = min(ear, min(w, h))

        var p = Path()
        // Start just after the top-leading rounded corner.
        p.move(to: CGPoint(x: r, y: 0))
        // Top edge to the fold-line start A = (w - s, 0).
        p.addLine(to: CGPoint(x: w - s, y: 0))
        // Fold line down to B = (w, s).
        p.addLine(to: CGPoint(x: w, y: s))
        // Right edge down to bottom-right rounded corner.
        p.addLine(to: CGPoint(x: w, y: h - r))
        p.addQuadCurve(to: CGPoint(x: w - r, y: h),
                       control: CGPoint(x: w, y: h))
        // Bottom edge.
        p.addLine(to: CGPoint(x: r, y: h))
        p.addQuadCurve(to: CGPoint(x: 0, y: h - r),
                       control: CGPoint(x: 0, y: h))
        // Left edge.
        p.addLine(to: CGPoint(x: 0, y: r))
        p.addQuadCurve(to: CGPoint(x: r, y: 0),
                       control: CGPoint(x: 0, y: 0))
        p.closeSubpath()
        return p
    }
}

// MARK: - The reveal pocket (accent behind the lifted corner)

private struct DogearBookmarkView_RevealPocket: Shape {
    var ear: CGFloat
    var progress: CGFloat

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let s = min(ear, min(w, rect.height))
        // Triangle A, B, C0 — the area exposed when the corner folds away.
        let a = CGPoint(x: w - s, y: 0)
        let b = CGPoint(x: w, y: s)
        let c0 = CGPoint(x: w, y: 0)

        var p = Path()
        p.move(to: a)
        p.addLine(to: c0)
        p.addLine(to: b)
        p.closeSubpath()
        return p
    }
}

// MARK: - The folding flap (Animatable on foldProgress)

/// Triangle [A, B, C] where C lerps from the unfolded corner C0 = (W, 0)
/// to the fully-folded corner C1 = (W - s, s) — the reflection of C0 across
/// the fold line A->B. At foldProgress == 0 the triangle is the normal corner
/// (filled with the card color, so invisible); at 1 it lies fully folded in.
private struct DogearBookmarkView_FoldFlap: Shape {
    var ear: CGFloat
    var foldProgress: CGFloat

    var animatableData: CGFloat {
        get { foldProgress }
        set { foldProgress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let s = min(ear, min(w, rect.height))
        let p = min(max(foldProgress, 0), 1)

        let a = CGPoint(x: w - s, y: 0)
        let b = CGPoint(x: w, y: s)
        let c0 = CGPoint(x: w, y: 0)
        let c1 = CGPoint(x: w - s, y: s)
        let c = CGPoint(x: c0.x + (c1.x - c0.x) * p,
                        y: c0.y + (c1.y - c0.y) * p)

        var path = Path()
        path.move(to: a)
        path.addLine(to: c)
        path.addLine(to: b)
        path.closeSubpath()
        return path
    }
}
