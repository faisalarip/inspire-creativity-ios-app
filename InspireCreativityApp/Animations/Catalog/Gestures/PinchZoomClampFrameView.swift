// catalog-id: ges-pinch-zoom-clamp-frame
import SwiftUI

/// Pinch-Clamp Crop Frame
/// Pinch within an image and a crop frame resists past content edges with
/// rubber-band overscroll; the dimmed outside region springs taut when you
/// release beyond bounds. A fixed centered crop window sits over a synthesized
/// photo that scales/pans behind it; the image must always cover the window,
/// and any overshoot is rubber-banded then sprung back into legal range.
struct PinchZoomClampFrameView: View {
    var demo: Bool = false

    // Committed transform (the source of truth between gestures).
    @State private var baseScale: CGFloat = 1.0
    @State private var baseOffset: CGSize = .zero

    // Live transform while a gesture is in flight.
    @State private var liveScale: CGFloat = 1.0
    @State private var liveOffset: CGSize = .zero
    @State private var isGesturing: Bool = false

    // Gesture-start snapshot for focal-anchor math.
    @State private var gestureStartScale: CGFloat = 1.0
    @State private var gestureStartOffset: CGSize = .zero
    @State private var panStartOffset: CGSize = .zero

    // Haptic trigger: bumped on each snap-back so feedback fires on the clamp.
    @State private var snapTick: Int = 0

    // Tuning constants.
    private let minScale: CGFloat = 1.0      // cover threshold (image must fill window)
    private let maxScale: CGFloat = 3.2
    private let cropInset: CGFloat = 0.16     // fraction of min dimension used as margin

    var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(red: 0.05, green: 0.055, blue: 0.086))
    }

    // MARK: - Routing

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if demo {
            demoContent(in: size)
        } else {
            interactiveContent(in: size)
        }
    }

    // MARK: - Demo (self-driving)

    @ViewBuilder
    private func demoContent(in size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let driven = demoTransform(at: t, size: size)
            cropStage(scale: driven.scale,
                      offset: driven.offset,
                      overshoot: driven.overshoot,
                      size: size)
        }
    }

    /// A ~3.6s loop that zooms in, then deliberately over-pans to an edge so the
    /// rubber-band give and dim are demonstrated, then snaps taut to bounds.
    private func demoTransform(at time: TimeInterval, size: CGSize)
        -> (scale: CGFloat, offset: CGSize, overshoot: CGFloat) {
        let period: Double = 3.6
        let phase = (time.truncatingRemainder(dividingBy: period)) / period // 0..1

        // Scale eases 1 -> 2.0 -> 1 over the loop.
        let zoom = (1.0 - cos(phase * 2.0 * .pi)) * 0.5            // 0..1..0
        let scale = 1.0 + CGFloat(zoom) * 1.0                      // 1.0..2.0

        let window = cropRect(in: size)
        let limits = panLimits(forScale: scale, window: window, size: size)

        // Push the pan toward an edge and beyond it during the middle of the loop.
        let pushPhase = sin(phase * 2.0 * .pi)                     // -1..1
        let targetX = CGFloat(pushPhase) * (limits.width + 46)     // intentionally past the limit
        let targetY = CGFloat(sin(phase * 4.0 * .pi)) * (limits.height + 26)

        let resistedX = rubberClamped(targetX, limit: limits.width, dimension: window.width)
        let resistedY = rubberClamped(targetY, limit: limits.height, dimension: window.height)

        let overX = max(0, abs(targetX) - limits.width)
        let overY = max(0, abs(targetY) - limits.height)
        let overshoot = min(1.0, (overX + overY) / 70.0)

        return (scale, CGSize(width: resistedX, height: resistedY), overshoot)
    }

    // MARK: - Interactive

    @ViewBuilder
    private func interactiveContent(in size: CGSize) -> some View {
        let scale = isGesturing ? liveScale : baseScale
        let offset = isGesturing ? liveOffset : baseOffset
        let overshoot = currentOvershoot(scale: scale, offset: offset, size: size)

        cropStage(scale: scale, offset: offset, overshoot: overshoot, size: size)
            .contentShape(Rectangle())
            .gesture(combinedGesture(size: size))
            .sensoryFeedback(.impact(weight: .light), trigger: snapTick)
    }

    private func combinedGesture(size: CGSize) -> some Gesture {
        let magnify = MagnifyGesture(minimumScaleDelta: 0)
            .onChanged { value in
                beginIfNeeded()
                applyMagnify(value, size: size)
            }
            .onEnded { _ in
                commitAndSpring(size: size)
            }

        let pan = DragGesture(minimumDistance: 0)
            .onChanged { value in
                beginIfNeeded()
                applyPan(value, size: size)
            }
            .onEnded { _ in
                commitAndSpring(size: size)
            }

        return magnify.simultaneously(with: pan)
    }

    private func beginIfNeeded() {
        guard !isGesturing else { return }
        isGesturing = true
        gestureStartScale = baseScale
        gestureStartOffset = baseOffset
        panStartOffset = baseOffset
        liveScale = baseScale
        liveOffset = baseOffset
    }

    /// Focal-anchor zoom: keep the pinch point fixed in window space.
    /// offset = (focal - center) * (1 - m) + baseOffset * m,  scale = baseScale * m
    private func applyMagnify(_ value: MagnifyGesture.Value, size: CGSize) {
        let m = value.magnification
        let rawScale = gestureStartScale * m
        let clampedScale = clampScale(rawScale, allowOvershoot: true)

        let window = cropRect(in: size)
        let center = CGPoint(x: window.midX, y: window.midY)
        let focal = CGPoint(x: window.minX + value.startAnchor.x * window.width,
                            y: window.minY + value.startAnchor.y * window.height)

        let fx = (focal.x - center.x) * (1 - m) + gestureStartOffset.width * m
        let fy = (focal.y - center.y) * (1 - m) + gestureStartOffset.height * m

        let limits = panLimits(forScale: clampedScale, window: window, size: size)
        liveScale = clampedScale
        liveOffset = CGSize(
            width: rubberClamped(fx, limit: limits.width, dimension: window.width),
            height: rubberClamped(fy, limit: limits.height, dimension: window.height)
        )
    }

    private func applyPan(_ value: DragGesture.Value, size: CGSize) {
        let window = cropRect(in: size)
        let proposedX = panStartOffset.width + value.translation.width
        let proposedY = panStartOffset.height + value.translation.height
        let limits = panLimits(forScale: liveScale, window: window, size: size)
        liveOffset = CGSize(
            width: rubberClamped(proposedX, limit: limits.width, dimension: window.width),
            height: rubberClamped(proposedY, limit: limits.height, dimension: window.height)
        )
    }

    private func commitAndSpring(size: CGSize) {
        let window = cropRect(in: size)
        let targetScale = clampScale(liveScale, allowOvershoot: false)
        let limits = panLimits(forScale: targetScale, window: window, size: size)
        let targetOffset = CGSize(
            width: hardClamp(liveOffset.width, limit: limits.width),
            height: hardClamp(liveOffset.height, limit: limits.height)
        )

        let wasOut = abs(liveScale - targetScale) > 0.001
            || abs(liveOffset.width - targetOffset.width) > 0.5
            || abs(liveOffset.height - targetOffset.height) > 0.5

        baseScale = liveScale
        baseOffset = liveOffset
        isGesturing = false

        withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
            baseScale = targetScale
            baseOffset = targetOffset
        }
        if wasOut { snapTick &+= 1 }
    }

    private func currentOvershoot(scale: CGFloat, offset: CGSize, size: CGSize) -> CGFloat {
        let window = cropRect(in: size)
        let limits = panLimits(forScale: scale, window: window, size: size)
        let overX = max(0, abs(offset.width) - limits.width)
        let overY = max(0, abs(offset.height) - limits.height)
        let scaleOver = max(0, scale - maxScale) * 60 + max(0, minScale - scale) * 60
        return min(1.0, (overX + overY + scaleOver) / 70.0)
    }

    // MARK: - Shared renderer

    @ViewBuilder
    private func cropStage(scale: CGFloat, offset: CGSize, overshoot: CGFloat, size: CGSize) -> some View {
        let window = cropRect(in: size)
        let corner = min(window.width, window.height) * 0.06

        ZStack {
            // The photo, scaled + panned behind everything.
            photo(in: size)
                .scaleEffect(scale)        // center anchor (default) — required by focal math
                .offset(offset)
                .clipped()

            // Dim everything outside the crop window. Brighten the dim slightly
            // while overscrolling so the boundary tension reads.
            dimMask(window: window, corner: corner, size: size, overshoot: overshoot)

            // The crop frame chrome: border, rule-of-thirds grid, corner handles.
            cropChrome(window: window, corner: corner, overshoot: overshoot)
        }
        .compositingGroup()
    }

    private func dimMask(window: CGRect, corner: CGFloat, size: CGSize, overshoot: CGFloat) -> some View {
        let dim = 0.46 + overshoot * 0.18
        return Rectangle()
            .fill(Color.black.opacity(dim))
            .reverseMask {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .frame(width: window.width, height: window.height)
                    .position(x: window.midX, y: window.midY)
            }
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func cropChrome(window: CGRect, corner: CGFloat, overshoot: CGFloat) -> some View {
        let borderTint = Color(red: 1, green: 1, blue: 1)
            .opacity(0.85 + overshoot * 0.15)

        ZStack {
            // Rule-of-thirds grid.
            thirdsGrid(window: window)
                .stroke(Color.white.opacity(0.28), lineWidth: 0.75)

            // Main frame border. Tints warm when rubber-banding past bounds.
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(
                    overshoot > 0.02
                        ? AnyShapeStyle(Color(red: 1.0, green: 0.62, blue: 0.32).opacity(0.95))
                        : AnyShapeStyle(borderTint),
                    lineWidth: 1.6 + overshoot * 1.2
                )
                .frame(width: window.width, height: window.height)
                .position(x: window.midX, y: window.midY)

            cornerHandles(window: window, overshoot: overshoot)
        }
        .allowsHitTesting(false)
    }

    private func cornerHandles(window: CGRect, overshoot: CGFloat) -> some View {
        let len = min(window.width, window.height) * 0.13
        let tint = overshoot > 0.02
            ? Color(red: 1.0, green: 0.62, blue: 0.32)
            : Color(red: 1, green: 1, blue: 1)
        return ForEach(0..<4, id: \.self) { i in
            CornerBracket(corner: i, length: len)
                .stroke(tint.opacity(0.95), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                .frame(width: window.width, height: window.height)
                .position(x: window.midX, y: window.midY)
        }
    }

    // MARK: - Synthesized photo (no assets)

    @ViewBuilder
    private func photo(in size: CGSize) -> some View {
        ZStack {
            // Sky gradient.
            LinearGradient(
                colors: [
                    Color(red: 0.20, green: 0.30, blue: 0.55),
                    Color(red: 0.55, green: 0.52, blue: 0.70),
                    Color(red: 0.96, green: 0.74, blue: 0.52)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Sun.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.96, blue: 0.82),
                            Color(red: 1.0, green: 0.82, blue: 0.5).opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size.width * 0.22
                    )
                )
                .frame(width: size.width * 0.42, height: size.width * 0.42)
                .position(x: size.width * 0.68, y: size.height * 0.34)

            // Distant hill.
            HillShape(baseY: 0.66, peakY: 0.5, skew: 0.35)
                .fill(Color(red: 0.42, green: 0.46, blue: 0.55))

            // Mid hill.
            HillShape(baseY: 0.74, peakY: 0.58, skew: -0.4)
                .fill(Color(red: 0.32, green: 0.40, blue: 0.40))

            // Foreground hill.
            HillShape(baseY: 0.82, peakY: 0.68, skew: 0.15)
                .fill(Color(red: 0.16, green: 0.30, blue: 0.26))
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Geometry helpers

    /// The fixed, centered crop window in the view's coordinate space.
    private func cropRect(in size: CGSize) -> CGRect {
        let minDim = min(size.width, size.height)
        let side = minDim * (1 - cropInset * 2)
        // Slight landscape aspect so the photo reads as a photo.
        let w = min(size.width * (1 - cropInset * 1.4), side * 1.28)
        let h = side
        return CGRect(x: (size.width - w) / 2,
                      y: (size.height - h) / 2,
                      width: w, height: h)
    }

    /// How far (in points) the photo may pan in each axis before the crop window
    /// would expose an uncovered edge, for a given scale.
    private func panLimits(forScale scale: CGFloat, window: CGRect, size: CGSize) -> CGSize {
        // The photo fills the full view; at scale s its visible half-extent grows.
        let photoHalfW = size.width * scale / 2
        let photoHalfH = size.height * scale / 2
        let windowHalfW = window.width / 2
        let windowHalfH = window.height / 2
        // Window is centered; available slack is photo half minus window half,
        // minus the window's own centered offset within the view.
        let slackW = max(0, photoHalfW - windowHalfW)
        let slackH = max(0, photoHalfH - windowHalfH)
        return CGSize(width: slackW, height: slackH)
    }

    private func clampScale(_ s: CGFloat, allowOvershoot: Bool) -> CGFloat {
        if allowOvershoot {
            // Soft resistance past hard limits but never wildly off.
            if s < minScale {
                return minScale - rubber(minScale - s, dimension: 0.6)
            } else if s > maxScale {
                return maxScale + rubber(s - maxScale, dimension: 1.2)
            }
            return s
        }
        return min(max(s, minScale), maxScale)
    }

    private func rubber(_ x: CGFloat, dimension: CGFloat) -> CGFloat {
        // Asymptotic give for scale overshoot.
        (1 - 1 / (x / dimension + 1)) * dimension * 0.5
    }

    /// Classic iOS rubber-band: within [-limit, limit] pass through; beyond,
    /// apply asymptotic resistance scaled by the dimension.
    private func rubberClamped(_ value: CGFloat, limit: CGFloat, dimension: CGFloat) -> CGFloat {
        if value > limit {
            return limit + rubberBand(value - limit, dimension: dimension)
        } else if value < -limit {
            return -limit - rubberBand(-value - limit, dimension: dimension)
        }
        return value
    }

    private func rubberBand(_ overshoot: CGFloat, dimension: CGFloat) -> CGFloat {
        let d = max(dimension, 1)
        return (1 - 1 / (overshoot * 0.55 / d + 1)) * d
    }

    private func hardClamp(_ value: CGFloat, limit: CGFloat) -> CGFloat {
        min(max(value, -limit), limit)
    }
}

// MARK: - Shapes

private struct HillShape: Shape {
    var baseY: CGFloat   // fraction of height where the hill base sits
    var peakY: CGFloat   // fraction of height of the peak
    var skew: CGFloat    // -1..1, shifts the peak horizontally

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let base = h * baseY
        let peak = h * peakY
        let peakX = w * (0.5 + skew * 0.3)
        p.move(to: CGPoint(x: 0, y: base))
        p.addQuadCurve(
            to: CGPoint(x: w, y: base),
            control: CGPoint(x: peakX, y: peak)
        )
        p.addLine(to: CGPoint(x: w, y: h))
        p.addLine(to: CGPoint(x: 0, y: h))
        p.closeSubpath()
        return p
    }
}

private struct CornerBracket: Shape {
    var corner: Int       // 0 TL, 1 TR, 2 BR, 3 BL
    var length: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let l = length
        switch corner {
        case 0:
            p.move(to: CGPoint(x: rect.minX, y: rect.minY + l))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX + l, y: rect.minY))
        case 1:
            p.move(to: CGPoint(x: rect.maxX - l, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + l))
        case 2:
            p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - l))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX - l, y: rect.maxY))
        default:
            p.move(to: CGPoint(x: rect.minX + l, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - l))
        }
        return p
    }
}

private struct ThirdsGridPlaceholder { }

private extension PinchZoomClampFrameView {
    func thirdsGrid(window: CGRect) -> Path {
        var p = Path()
        let oneThirdW = window.width / 3
        let oneThirdH = window.height / 3
        // Vertical lines.
        for i in 1...2 {
            let x = window.minX + oneThirdW * CGFloat(i)
            p.move(to: CGPoint(x: x, y: window.minY))
            p.addLine(to: CGPoint(x: x, y: window.maxY))
        }
        // Horizontal lines.
        for i in 1...2 {
            let y = window.minY + oneThirdH * CGFloat(i)
            p.move(to: CGPoint(x: window.minX, y: y))
            p.addLine(to: CGPoint(x: window.maxX, y: y))
        }
        return p
    }
}

// MARK: - Reverse mask helper

private extension View {
    @ViewBuilder
    func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask {
            ZStack {
                Rectangle()
                mask()
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
        }
    }
}
