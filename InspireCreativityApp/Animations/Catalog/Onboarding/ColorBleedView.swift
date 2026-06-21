// catalog-id: ob-color-bleed
import SwiftUI

// MARK: - Ink Bleed Wipe
// Advancing a page releases a blot of ink that organically blooms and bleeds
// outward in irregular wobbling lobes to flood the screen with the next page's
// color, carrying the new content in behind the wavefront. The idle demo blooms
// a fresh ink wipe from a corner on a loop.
//
// Mechanism: an animatable closed `ColorBleedView_BlobShape` whose vertex radius is
// baseRadius(progress) + sine lobe wobble. It is used as a `.mask` on the
// incoming page layer so the wavefront reveals the next color + glyph.
// Pure Shape (no Metal, no Canvas-for-the-grow). iOS 17.

struct ColorBleedView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            if demo {
                ColorBleedView_DemoBleed(size: size)
            } else {
                ColorBleedView_InteractiveBleed(size: size)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - Palette of "pages"

private struct ColorBleedView_InkPage {
    let top: Color
    let bottom: Color
    let symbol: String
    let accent: Color
}

private let inkPages: [ColorBleedView_InkPage] = [
    ColorBleedView_InkPage(top: Color(red: 0.36, green: 0.20, blue: 0.62),
            bottom: Color(red: 0.18, green: 0.09, blue: 0.34),
            symbol: "sparkles", accent: Color(red: 0.92, green: 0.86, blue: 1.00)),
    ColorBleedView_InkPage(top: Color(red: 0.05, green: 0.50, blue: 0.60),
            bottom: Color(red: 0.02, green: 0.24, blue: 0.34),
            symbol: "paintbrush.pointed.fill", accent: Color(red: 0.82, green: 0.98, blue: 0.98)),
    ColorBleedView_InkPage(top: Color(red: 0.86, green: 0.34, blue: 0.36),
            bottom: Color(red: 0.50, green: 0.12, blue: 0.24),
            symbol: "flame.fill", accent: Color(red: 1.00, green: 0.92, blue: 0.84)),
    ColorBleedView_InkPage(top: Color(red: 0.18, green: 0.55, blue: 0.34),
            bottom: Color(red: 0.07, green: 0.28, blue: 0.20),
            symbol: "leaf.fill", accent: Color(red: 0.90, green: 1.00, blue: 0.90))
]

// MARK: - The animatable ink blob

/// A closed organic blob. Its radius at angle a is:
///   r(a) = baseRadius * progress  +  lobeAmplitude * sin(a * lobeCount + phase)
/// Both `progress` (bloom) and `phase` (lobe wobble) are animatable so the rim
/// keeps breathing smoothly while the blob grows. We never re-seed noise per
/// frame — the wobble is a deterministic function of the animated `phase`.
private struct ColorBleedView_BlobShape: Shape {
    var progress: CGFloat
    var phase: CGFloat
    let origin: CGPoint
    let maxRadius: CGFloat
    let lobeCount: Int
    let lobeAmplitude: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(progress, phase) }
        set {
            progress = newValue.first
            phase = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let clamped = max(0, min(1, progress))
        // Eased base radius so the bloom decelerates as it floods.
        let base = maxRadius * easeOut(clamped)
        if base <= 0.0001 {
            return path
        }
        // Wobble amplitude grows in then relaxes near full coverage so the edge
        // settles flat once the screen is flooded.
        let wobbleEnv = sin(clamped * .pi)               // 0 -> 1 -> 0
        let amp = lobeAmplitude * (0.35 + 0.65 * wobbleEnv) * min(1, base / 40)

        let steps = 64
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let angle = t * 2 * .pi
            // Two superimposed lobe sets for a less regular, more organic rim.
            let w1 = sin(angle * CGFloat(lobeCount) + phase)
            let w2 = sin(angle * CGFloat(lobeCount + 3) - phase * 0.7)
            let r = base + amp * (0.7 * w1 + 0.3 * w2)
            let x = origin.x + cos(angle) * r
            let y = origin.y + sin(angle) * r
            let point = CGPoint(x: x, y: y)
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    private func easeOut(_ x: CGFloat) -> CGFloat {
        1 - pow(1 - x, 2.4)
    }
}

// MARK: - Shared "page" content

private struct ColorBleedView_PageContent: View {
    let page: ColorBleedView_InkPage
    let size: CGSize

    var body: some View {
        let dim = min(size.width, size.height)
        ZStack {
            LinearGradient(colors: [page.top, page.bottom],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
            // Carried content behind the wavefront.
            VStack(spacing: dim * 0.06) {
                Image(systemName: page.symbol)
                    .font(.system(size: dim * 0.28, weight: .semibold))
                    .foregroundStyle(page.accent)
                    .shadow(color: .black.opacity(0.25), radius: dim * 0.02, y: dim * 0.01)
                Capsule()
                    .fill(page.accent.opacity(0.85))
                    .frame(width: dim * 0.34, height: max(3, dim * 0.022))
            }
        }
    }
}

// MARK: - Interactive (demo == false)

private struct ColorBleedView_InteractiveBleed: View {
    let size: CGSize

    @State private var baseIndex: Int = 0
    @State private var progress: CGFloat = 0
    @State private var phase: CGFloat = 0
    @State private var origin: CGPoint = .zero

    private var incomingIndex: Int { (baseIndex + 1) % inkPages.count }

    var body: some View {
        let maxR = floodRadius(from: origin, in: size)
        ZStack {
            // Base layer: the currently-settled page, always full-screen.
            ColorBleedView_PageContent(page: inkPages[baseIndex], size: size)

            // Incoming layer revealed by the growing ink blob.
            ColorBleedView_PageContent(page: inkPages[incomingIndex], size: size)
                .mask {
                    ColorBleedView_BlobShape(progress: progress,
                              phase: phase,
                              origin: origin,
                              maxRadius: maxR,
                              lobeCount: 5,
                              lobeAmplitude: min(size.width, size.height) * 0.085)
                }

            hint
        }
        .contentShape(Rectangle())
        .gesture(
            SpatialTapGesture(coordinateSpace: .local)
                .onEnded { value in
                    advance(from: value.location)
                }
        )
    }

    private var hint: some View {
        VStack {
            Spacer()
            Text("tap to bleed")
                .font(.system(size: max(9, min(size.width, size.height) * 0.07),
                              weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(progress > 0.05 ? 0 : 0.55))
                .padding(.bottom, min(size.width, size.height) * 0.06)
                .animation(.easeInOut(duration: 0.25), value: progress)
        }
        .allowsHitTesting(false)
    }

    private func advance(from point: CGPoint) {
        guard progress < 0.001 else { return }
        origin = point
        // Drive bloom AND wobble phase inside the same withAnimation block so the
        // rim keeps breathing as it grows (no TimelineView here — that would make
        // the shape re-read the jumped model value and snap instead of grow).
        withAnimation(.easeOut(duration: 0.55)) {
            progress = 1
            phase += .pi * 1.6
        }
        // After the flood fully covers, promote the incoming page to the base and
        // reset progress to 0 with no visible change (full incoming == new base).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.58) {
            baseIndex = incomingIndex
            progress = 0
        }
    }
}

// MARK: - Demo (demo == true)

private struct ColorBleedView_DemoBleed: View {
    let size: CGSize

    // ~3.2s per bleed cycle.
    private let period: Double = 3.2

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            content(time: t)
        }
    }

    @ViewBuilder
    private func content(time: Double) -> some View {
        // Compute all animation state up front so the ViewBuilder body holds only
        // view content (avoids any "() cannot conform to View" pitfalls).
        let cycle = (time / period).truncatingRemainder(dividingBy: 1)   // 0..<1
        // Which page is settled vs. blooming in. Each completed cycle advances one.
        let step = Int(time / period)
        let baseIndex = ((step % inkPages.count) + inkPages.count) % inkPages.count
        let incomingIndex = (baseIndex + 1) % inkPages.count

        // Bloom progress: grow over the first ~75% of the cycle, then hold full so
        // the wrap (full incoming -> new base) has no blank/flash frame.
        let raw = min(1, CGFloat(cycle) / 0.75)
        let progress = easeInOut(raw)

        // Origin rotates among the four corners each cycle so it blooms from a
        // fresh corner on the loop.
        let origin = corner(for: step, in: size)
        let maxR = floodRadius(from: origin, in: size)
        // Phase advances continuously with real time so the rim wobbles smoothly.
        let phase = CGFloat(time) * 1.4

        ZStack {
            ColorBleedView_PageContent(page: inkPages[baseIndex], size: size)

            ColorBleedView_PageContent(page: inkPages[incomingIndex], size: size)
                .mask {
                    ColorBleedView_BlobShape(progress: progress,
                              phase: phase,
                              origin: origin,
                              maxRadius: maxR,
                              lobeCount: 5,
                              lobeAmplitude: min(size.width, size.height) * 0.085)
                }
        }
    }

    private func corner(for step: Int, in size: CGSize) -> CGPoint {
        switch ((step % 4) + 4) % 4 {
        case 0: return CGPoint(x: size.width * 0.16, y: size.height * 0.82)
        case 1: return CGPoint(x: size.width * 0.84, y: size.height * 0.82)
        case 2: return CGPoint(x: size.width * 0.84, y: size.height * 0.18)
        default: return CGPoint(x: size.width * 0.16, y: size.height * 0.18)
        }
    }

    private func easeInOut(_ x: CGFloat) -> CGFloat {
        let c = max(0, min(1, x))
        return c * c * (3 - 2 * c)
    }
}

// MARK: - Shared geometry

/// Distance from the bloom origin to the farthest corner, plus a margin for the
/// lobe wobble amplitude so the blob fully floods with no surviving corner sliver.
private func floodRadius(from origin: CGPoint, in size: CGSize) -> CGFloat {
    let corners = [
        CGPoint(x: 0, y: 0),
        CGPoint(x: size.width, y: 0),
        CGPoint(x: 0, y: size.height),
        CGPoint(x: size.width, y: size.height)
    ]
    var maxDist: CGFloat = 0
    for c in corners {
        let dx = c.x - origin.x
        let dy = c.y - origin.y
        let d = sqrt(dx * dx + dy * dy)
        if d > maxDist { maxDist = d }
    }
    let wobbleMargin = min(size.width, size.height) * 0.10
    return maxDist + wobbleMargin
}
