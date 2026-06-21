// catalog-id: mi-staggered-star-rating
import SwiftUI

/// Staggered Star Rating
///
/// Drag across the row to fill stars left-to-right. Each newly filled star
/// pops with a staggered spring that ripples behind your finger, and the
/// whole row tints warmer as the score rises.
///
/// - `demo == true`  : self-driving PhaseAnimator loop that ramps the rating
///                     up and back down so the tile looks alive untouched.
/// - `demo == false` : a real interactive rating control driven by a single
///                     DragGesture (which also covers taps).
struct StaggeredStarRatingView: View {
    var demo: Bool = false

    private let starCount: Int = 5

    // The live rating. During interaction this tracks the finger continuously;
    // in demo mode it is driven by the PhaseAnimator phase.
    @State private var rating: Double = 0

    var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // .frame here keeps the GeometryReader from collapsing in a tile.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if demo {
            demoBody(in: size)
        } else {
            interactiveBody(in: size)
        }
    }

    // MARK: - Demo (self-driving)

    @ViewBuilder
    private func demoBody(in size: CGSize) -> some View {
        // Integer phases give a crisp per-star pop at each step; a continuous
        // ramp would smear the left-to-right stagger. Using the auto-looping
        // PhaseAnimator initializer (no trigger) so the tile cycles forever.
        let phases: [Double] = [0, 1, 2, 3, 4, 5, 4, 3, 2, 1]
        PhaseAnimator(phases) { phase in
            row(rating: phase, in: size)
        } animation: { _ in
            .spring(response: 0.45, dampingFraction: 0.65)
        }
    }

    // MARK: - Interactive

    @ViewBuilder
    private func interactiveBody(in size: CGSize) -> some View {
        let metrics = StaggeredStarRatingView_StarMetrics(size: size, count: starCount)
        row(rating: rating, in: size)
            .contentShape(Rectangle())
            .gesture(dragGesture(metrics: metrics))
            // Gate haptics to interactive use so a grid of demo tiles
            // doesn't buzz the device continuously.
            .sensoryFeedback(.selection, trigger: Int(rating.rounded()))
    }

    private func dragGesture(metrics: StaggeredStarRatingView_StarMetrics) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                rating = rating(forX: value.location.x, metrics: metrics)
            }
            .onEnded { value in
                let raw = rating(forX: value.location.x, metrics: metrics)
                // Snap to nearest half-star with a settling spring.
                let snapped = (raw * 2).rounded() / 2
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                    rating = snapped
                }
            }
    }

    /// Maps an x position within the row to a 0...count rating.
    private func rating(forX x: CGFloat, metrics: StaggeredStarRatingView_StarMetrics) -> Double {
        let local = x - metrics.leadingInset
        guard metrics.rowWidth > 0 else { return 0 }
        let frac = Double(local / metrics.rowWidth)
        let clamped = min(max(frac, 0), 1)
        return clamped * Double(starCount)
    }

    // MARK: - Row

    @ViewBuilder
    private func row(rating: Double, in size: CGSize) -> some View {
        let metrics = StaggeredStarRatingView_StarMetrics(size: size, count: starCount)
        HStack(spacing: metrics.spacing) {
            ForEach(0..<starCount, id: \.self) { index in
                StaggeredStarRatingView_StarCell(
                    fill: fillFraction(rating: rating, index: index),
                    isFilled: isFilled(rating: rating, index: index),
                    fillColor: warmthColor(rating: rating),
                    side: metrics.starSide,
                    delay: Double(index) * 0.05
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Derived values

    /// Continuous 0...1 fill for a star — tracks the finger live.
    private func fillFraction(rating: Double, index: Int) -> CGFloat {
        let raw = rating - Double(index)
        return CGFloat(min(max(raw, 0), 1))
    }

    /// Discrete "this star counts as lit" — the spring/pop is keyed to this so
    /// the ripple lags behind the live fill instead of fighting the finger.
    private func isFilled(rating: Double, index: Int) -> Bool {
        rating - Double(index) >= 0.5
    }

    /// Pale gold -> warm amber as the score climbs. Interpolates the raw RGB
    /// components directly so there is no UIKit/UIColor dependency.
    private func warmthColor(rating: Double) -> Color {
        let t = min(max(rating / Double(starCount), 0), 1)
        // soft gold
        let cr: Double = 1.00, cg: Double = 0.82, cb: Double = 0.36
        // warm amber-red
        let wr: Double = 1.00, wg: Double = 0.42, wb: Double = 0.27
        return Color(
            red: cr + (wr - cr) * t,
            green: cg + (wg - cg) * t,
            blue: cb + (wb - cb) * t
        )
    }
}

// MARK: - Layout metrics

private struct StaggeredStarRatingView_StarMetrics {
    let starSide: CGFloat
    let spacing: CGFloat
    let leadingInset: CGFloat
    let rowWidth: CGFloat

    init(size: CGSize, count: Int) {
        let n = CGFloat(max(count, 1))
        // Size a star so the full row fits a tiny tile and a large detail area.
        let byWidth = size.width / (n + 1.5)
        let byHeight = size.height * 0.62
        let side = max(min(byWidth, byHeight), 8)
        self.starSide = side
        self.spacing = side * 0.22
        let totalRow = side * n + spacing * (n - 1)
        self.rowWidth = totalRow
        self.leadingInset = max((size.width - totalRow) / 2, 0)
    }
}

// MARK: - Single star

private struct StaggeredStarRatingView_StarCell: View {
    var fill: CGFloat        // 0...1 continuous fill (tracks finger)
    var isFilled: Bool       // discrete lit state (drives the pop)
    var fillColor: Color
    var side: CGFloat
    var delay: Double

    var body: some View {
        ZStack {
            // Empty outline — always legible, never blank.
            StaggeredStarRatingView_StarShape()
                .stroke(
                    Color(red: 0.42, green: 0.40, blue: 0.50),
                    style: StrokeStyle(lineWidth: max(side * 0.05, 1), lineJoin: .round)
                )
                .background(
                    StaggeredStarRatingView_StarShape().fill(Color(red: 0.16, green: 0.16, blue: 0.22))
                )

            // Filled portion, masked to a leading rectangle whose width
            // tracks the live fill fraction.
            StaggeredStarRatingView_StarShape()
                .fill(fillGradient)
                .overlay(glint)
                .mask(alignment: .leading) {
                    Rectangle()
                        .frame(width: side * fill)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
        }
        .frame(width: side, height: side)
        // The spring overshoot IS the pop; the per-index delay makes it ripple
        // left-to-right. Keyed to the discrete bool so it never lags the finger.
        .scaleEffect(isFilled ? 1.0 : 0.86, anchor: .center)
        .shadow(
            color: fillColor.opacity(isFilled ? 0.55 : 0),
            radius: side * 0.12, x: 0, y: 0
        )
        .animation(
            .spring(response: 0.34, dampingFraction: 0.5).delay(delay),
            value: isFilled
        )
        // Fill width itself follows the finger near-instantly.
        .animation(.linear(duration: 0.06), value: fill)
    }

    private var fillGradient: LinearGradient {
        LinearGradient(
            colors: [
                fillColor.opacity(0.95),
                fillColor
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var glint: some View {
        StaggeredStarRatingView_StarShape()
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.55), Color.white.opacity(0.0)],
                    startPoint: .topLeading,
                    endPoint: .center
                )
            )
            .blendMode(.screen)
            .opacity(0.7)
    }
}

// MARK: - Star geometry

private struct StaggeredStarRatingView_StarShape: Shape {
    var points: Int = 5
    var innerRatio: CGFloat = 0.42

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * innerRatio
        let step = CGFloat.pi / CGFloat(max(points, 1))
        // Start at the top tip.
        var angle = -CGFloat.pi / 2
        for i in 0..<(max(points, 1) * 2) {
            let radius = (i % 2 == 0) ? outer : inner
            let pt = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if i == 0 {
                path.move(to: pt)
            } else {
                path.addLine(to: pt)
            }
            angle += step
        }
        path.closeSubpath()
        return path
    }
}
