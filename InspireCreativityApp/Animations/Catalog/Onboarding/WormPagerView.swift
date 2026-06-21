// catalog-id: ob-worm-pager
import SwiftUI

// MARK: - WormPagerView
// "Worm Page Dots" — the active indicator stretches into a connecting pill that
// elongates toward the destination dot then snaps closed around it, like an
// inchworm crawling along the track. demo == true auto-crawls forever; demo ==
// false is a draggable dot-row page control.
struct WormPagerView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        let layout = WormPagerView_WormLayout(size: size, pageCount: Self.pageCount)
        ZStack {
            backdrop
            if demo {
                demoStage(layout: layout)
            } else {
                WormPagerView_InteractiveWormPager(layout: layout, pageCount: Self.pageCount)
            }
        }
    }

    // MARK: Demo (self-driving)

    @ViewBuilder
    private func demoStage(layout: WormPagerView_WormLayout) -> some View {
        // Ping-pong through the dots so the worm never teleports across a wrap.
        let phases: [CGFloat] = [0, 1, 2, 3, 2, 1]
        PhaseAnimator(phases, content: { progress in
            WormPagerView_WormTrack(layout: layout, progress: progress)
        }, animation: { _ in
            .spring(response: 0.62, dampingFraction: 0.58)
        })
    }

    @ViewBuilder
    private var backdrop: some View {
        // Soft tinted plate (#120e18 family) so the row reads on any host.
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.075, green: 0.055, blue: 0.105),
                        Color(red: 0.045, green: 0.035, blue: 0.070)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .ignoresSafeArea()
    }

    static let pageCount: Int = 4
}

// MARK: - Shared layout math

private struct WormPagerView_WormLayout {
    let size: CGSize
    let pageCount: Int

    // Dot radius scales with the tile so it works at 120pt and full screen.
    var dotRadius: CGFloat {
        let base = min(size.width, size.height) * 0.045
        return min(max(base, 5), 13)
    }

    var rowY: CGFloat { size.height / 2 }

    // Even spacing of dot centers across the available width with side inset.
    var dotCenters: [CGFloat] {
        guard pageCount > 1 else { return [size.width / 2] }
        let r = dotRadius
        let inset = max(r * 2.4, size.width * 0.12)
        let usable = max(size.width - inset * 2, 1)
        let step = usable / CGFloat(pageCount - 1)
        return (0..<pageCount).map { inset + step * CGFloat($0) }
    }

    var segmentWidth: CGFloat {
        let c = dotCenters
        guard c.count > 1 else { return size.width }
        return max(c[1] - c[0], 1)
    }
}

// MARK: - Worm track (static dots + animating pill)

private struct WormPagerView_WormTrack: View {
    let layout: WormPagerView_WormLayout
    let progress: CGFloat

    var body: some View {
        ZStack {
            staticDots
            WormPagerView_WormPill(progress: progress, layout: layout)
                .fill(wormGradient)
                .shadow(color: Color(red: 0.62, green: 0.40, blue: 0.95).opacity(0.55),
                        radius: layout.dotRadius * 0.9)
        }
    }

    private var staticDots: some View {
        let centers = layout.dotCenters
        let r = layout.dotRadius
        return ZStack {
            ForEach(centers.indices, id: \.self) { i in
                Circle()
                    .fill(Color(red: 0.42, green: 0.40, blue: 0.52).opacity(0.42))
                    .frame(width: r * 2, height: r * 2)
                    .position(x: centers[i], y: layout.rowY)
            }
        }
    }

    private var wormGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.55, green: 0.34, blue: 0.96),
                Color(red: 0.86, green: 0.52, blue: 0.99)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - The worm pill Shape
// CRUCIAL: progress is animatableData, so withAnimation / PhaseAnimator re-runs
// path(in:) at every interpolated value — the lead edge races ahead and the
// trail edge catches up, producing the inchworm stretch instead of a sliding
// dot. Endpoints are one-dot-wide; the spring overshoot reads as the snap-close.
private struct WormPagerView_WormPill: Shape {
    var progress: CGFloat
    let layout: WormPagerView_WormLayout

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let centers = layout.dotCenters
        let r = layout.dotRadius
        let y = layout.rowY
        guard centers.count > 1 else {
            return Path(ellipseIn: CGRect(x: centers.first ?? rect.midX - r,
                                          y: y - r, width: r * 2, height: r * 2))
        }

        let maxIndex = centers.count - 1
        let clamped = min(max(progress, 0), CGFloat(maxIndex))
        // Clamp the SEGMENT index, not progress, so overshoot past an integer
        // still draws as bounce around the destination dot.
        let i = min(max(Int(floor(clamped)), 0), maxIndex - 1)
        let frac = clamped - CGFloat(i)

        let x0 = centers[i]
        let gap = centers[i + 1] - x0

        // Front races during the first half, back catches up in the second half.
        let leadFrac = min(frac * 2, 1)
        let trailFrac = max(frac * 2 - 1, 0)

        let rightCenter = x0 + gap * leadFrac
        let leftCenter = x0 + gap * trailFrac

        let left = leftCenter - r
        let right = rightCenter + r
        let width = max(right - left, r * 2)

        let pill = CGRect(x: left, y: y - r, width: width, height: r * 2)
        return Path(roundedRect: pill, cornerRadius: r, style: .continuous)
    }
}

// MARK: - Interactive (drag the dot row)

private struct WormPagerView_InteractiveWormPager: View {
    let layout: WormPagerView_WormLayout
    let pageCount: Int

    @State private var progress: CGFloat = 0
    @State private var dragStart: CGFloat? = nil

    var body: some View {
        WormPagerView_WormTrack(layout: layout, progress: progress)
            .contentShape(Rectangle())
            .gesture(dragGesture)
    }

    private var maxProgress: CGFloat { CGFloat(pageCount - 1) }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let start = dragStart ?? progress
                if dragStart == nil { dragStart = start }
                // Lead edge tracks the finger directly (body re-runs each frame).
                let delta = value.translation.width / layout.segmentWidth
                progress = clamp(start + delta, 0, maxProgress)
            }
            .onEnded { value in
                let start = dragStart ?? progress
                let predicted = value.predictedEndTranslation.width / layout.segmentWidth
                let raw = clamp(start + predicted, 0, maxProgress)
                let target = clamp(raw.rounded(), 0, maxProgress)
                dragStart = nil
                // Trail edge lags then reels in with a spring snap-close.
                withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                    progress = target
                }
            }
    }

    private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        min(max(v, lo), hi)
    }
}
