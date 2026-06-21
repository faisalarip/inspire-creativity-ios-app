// catalog-id: tr-metaball-merge
import SwiftUI

/// Metaball Merge Reveal — two rounded pill blobs slide toward each other inside a
/// Canvas whose layer is blurred then alpha-thresholded, so the overlapping blurred
/// fields snap into a gooey liquid neck that pinches and separates. The thresholded
/// Canvas is used as a `.mask` over a gradient-filled container, so the merge resolves
/// into a clean destination shape rather than a flat fill.
///
/// - demo == true  → a self-driving TimelineView loop scrubs the blob separation on a
///                   ~3s cycle: blobs fuse into one, stretch a neck, pinch, separate.
/// - demo == false → still TimelineView-driven, but a DragGesture lets you scrub the
///                   separation by hand (drag to pull the blobs together / apart and
///                   watch the neck form and snap); release resumes the auto loop.
///
/// Pure SwiftUI Canvas filters (`.blur` + `.alphaThreshold`, both iOS 15+), iOS 17 clean.
struct MetaballMergeView: View {
    var demo: Bool = false

    // Live hand-scrub state (only used when demo == false).
    @State private var isDragging: Bool = false
    @State private var dragProgress: CGFloat = 0.5

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            content(size: size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                // Attach the scrub gesture always, but mask it off in demo mode so
                // demo == true stays a pure auto-loop. (`Optional<Gesture>` is not a
                // Gesture, so a `demo ? nil : gesture` ternary would not type-check.)
                .gesture(scrubGesture(size: size), including: demo ? .subviews : .all)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.051, green: 0.063, blue: 0.086)) // #0d1016 tint
    }

    // MARK: - Composition

    @ViewBuilder
    private func content(size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let progress = currentProgress(time: t)
            ZStack {
                backdrop(size: size)
                MetaballMergeView_MetaballField(progress: progress, gradient: blobGradient)
                    .allowsHitTesting(false)
                glints(size: size, progress: progress)
                    .allowsHitTesting(false)
            }
        }
    }

    /// The resolved progress (0…1) that drives blob separation.
    /// 0   → fully merged (one blob)
    /// ~0.5 → necked gooey bridge
    /// 1   → separated (two distinct capsules)
    private func currentProgress(time t: TimeInterval) -> CGFloat {
        if !demo && isDragging {
            return dragProgress
        }
        // Smooth, eased back-and-forth: merge → neck → separate → neck → merge.
        let period: Double = 3.2
        let phase = (t.truncatingRemainder(dividingBy: period)) / period // 0..1
        let triangle = phase < 0.5 ? phase * 2.0 : (1.0 - phase) * 2.0    // 0..1..0
        let eased = easeInOut(CGFloat(triangle))
        return eased
    }

    private func easeInOut(_ x: CGFloat) -> CGFloat {
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }

    // MARK: - Subviews

    private func backdrop(size: CGSize) -> some View {
        let m = min(size.width, size.height)
        return RoundedRectangle(cornerRadius: m * 0.16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.078, green: 0.094, blue: 0.137),
                        Color(red: 0.043, green: 0.051, blue: 0.078)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: m * 0.16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
            )
            .padding(m * 0.07)
    }

    /// Specular glints anchored to the two blob centers so the goo reads as glossy.
    private func glints(size: CGSize, progress: CGFloat) -> some View {
        let layout = MetaballMergeView_MetaballField.layout(for: size)
        let sep = MetaballMergeView_MetaballField.separation(progress: progress, blobR: layout.blobR)
        let left = CGPoint(x: layout.center.x - sep, y: layout.center.y)
        let right = CGPoint(x: layout.center.x + sep, y: layout.center.y)
        let glintR = layout.blobR * 0.42
        return ZStack {
            glintDot(at: left, radius: glintR)
            glintDot(at: right, radius: glintR)
        }
    }

    private func glintDot(at p: CGPoint, radius: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color.white.opacity(0.55), Color.white.opacity(0.0)],
                    center: .center, startRadius: 0, endRadius: radius
                )
            )
            .frame(width: radius * 2, height: radius * 2)
            .position(x: p.x - radius * 0.45, y: p.y - radius * 0.5)
            .blendMode(.screen)
    }

    private var blobGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.404, green: 0.522, blue: 1.0),   // periwinkle
                Color(red: 0.706, green: 0.420, blue: 0.973),  // violet
                Color(red: 0.984, green: 0.451, blue: 0.643)   // pink
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    // MARK: - Gesture (demo == false)

    private func scrubGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDragging = true
                // Map horizontal drag position across the view to separation 0…1.
                let w = max(size.width, 1)
                let p = value.location.x / w
                dragProgress = min(max(p, 0), 1)
            }
            .onEnded { _ in
                isDragging = false
            }
    }
}

// MARK: - Metaball Canvas (blur → alphaThreshold) used as a gradient mask

private struct MetaballMergeView_MetaballField: View {
    var progress: CGFloat
    var gradient: LinearGradient

    struct Layout {
        var center: CGPoint
        var blobR: CGFloat
        var blurR: CGFloat
    }

    /// Proportional geometry so the neck-pinch holds at BOTH a 120pt tile and a large detail view.
    static func layout(for size: CGSize) -> Layout {
        let m = min(size.width, size.height)
        let blobR = m * 0.17
        let blurR = blobR * 0.62
        return Layout(
            center: CGPoint(x: size.width / 2, y: size.height / 2),
            blobR: blobR,
            blurR: blurR
        )
    }

    /// Half the center-to-center distance. The travel range is a multiple of blobR,
    /// which is what makes the gooey neck form mid-range and snap past the threshold.
    /// progress 0 → centers coincident (merged); progress 1 → ~2.2×blobR apart (separated).
    static func separation(progress: CGFloat, blobR: CGFloat) -> CGFloat {
        let p = min(max(progress, 0), 1)
        let maxHalfGap = blobR * 1.12          // full center gap ≈ 2.24×blobR at p=1
        return maxHalfGap * p
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let l = MetaballMergeView_MetaballField.layout(for: size)
            gradient
                .mask(maskCanvas(size: size, layout: l))
        }
    }

    private func maskCanvas(size: CGSize, layout l: Layout) -> some View {
        Canvas { ctx, canvasSize in
            // Filter order matters: a filter added LATER applies INNERMOST.
            // We want draw → blur → threshold, so add threshold first, blur second.
            ctx.addFilter(.alphaThreshold(min: 0.5, color: .white))
            ctx.addFilter(.blur(radius: l.blurR))
            ctx.drawLayer { layer in
                let sep = MetaballMergeView_MetaballField.separation(progress: progress, blobR: l.blobR)
                let left = CGPoint(x: l.center.x - sep, y: l.center.y)
                let right = CGPoint(x: l.center.x + sep, y: l.center.y)
                drawCapsule(in: layer, center: left, blobR: l.blobR)
                drawCapsule(in: layer, center: right, blobR: l.blobR)
            }
        }
    }

    private func drawCapsule(in layer: GraphicsContext, center: CGPoint, blobR: CGFloat) {
        // A vertically-oriented rounded pill blob. Opaque white so the threshold reads cleanly.
        let w = blobR * 1.7
        let h = blobR * 2.2
        let rect = CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)
        let path = Capsule(style: .continuous).path(in: rect)
        layer.fill(path, with: .color(.white))
    }
}
