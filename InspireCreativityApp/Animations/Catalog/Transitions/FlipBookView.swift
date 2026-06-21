// catalog-id: tr-flip-book
import SwiftUI

// Flip FlipBookView_Book — pages riffle past in book style with motion blur on the
// turning leaf, landing on a target page. Drag scrubs the flip-through at
// any speed; release springs to the nearest whole page. The demo flavor
// auto-riffles forward then back on a loop.
//
// Mechanism: a stack of pages with the top turning leaf using
// rotation3DEffect about the spine (.y axis, leading anchor) with
// perspective. A continuous `progress` value selects which leaf turns
// (floor) and how far (fractional part). Blur scales with turn speed for
// the riffle smear and decays to 0 at rest so the landed page stays crisp.
struct FlipBookView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            if demo {
                FlipBookView_AutoRiffleBook(size: size)
            } else {
                FlipBookView_InteractiveBook(size: size)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Shared constants

private enum FlipBookView_Book {
    static let pageCount: Int = 7          // leaves you can riffle through
    static let maxBlur: CGFloat = 9        // cap so landed pages read crisp
    static let perspective: CGFloat = 0.42 // rotation3DEffect perspective
}

// MARK: - Demo: self-driving riffle

private struct FlipBookView_AutoRiffleBook: View {
    let size: CGSize

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let driven = Self.riffle(at: t)
            FlipBookView_BookStage(size: size,
                      progress: driven.progress,
                      blur: driven.blur)
        }
    }

    // Eased triangular wave: riffle forward to the last page, then back.
    // Speed → 0 at the turnarounds so a full page is always crisp & legible,
    // and blur peaks mid-riffle for the fast-turn smear.
    private static func riffle(at time: TimeInterval) -> (progress: CGFloat, blur: CGFloat) {
        let loop: Double = 3.4
        let phase = (time.truncatingRemainder(dividingBy: loop)) / loop // 0...1
        // Triangle 0→1→0 with cosine easing for smooth turnarounds.
        let tri = phase < 0.5 ? (phase * 2) : (2 - phase * 2)           // 0..1..0
        let eased = (1 - cos(tri * .pi)) / 2                            // ease in/out
        let maxProgress = CGFloat(FlipBookView_Book.pageCount - 1)
        let progress = CGFloat(eased) * maxProgress

        // Analytic speed of `eased` → blur. Derivative magnitude of the
        // eased triangle is largest at mid-riffle, zero at the ends.
        let speed = abs(sin(tri * .pi))                                  // 0..1..0
        let blur = FlipBookView_Book.maxBlur * CGFloat(speed)
        return (progress, blur)
    }
}

// MARK: - Interactive: drag to scrub, release to spring to a page

private struct FlipBookView_InteractiveBook: View {
    let size: CGSize

    @State private var progress: CGFloat = 0          // committed page-progress
    @State private var dragProgress: CGFloat = 0      // live offset during drag
    @State private var isDragging: Bool = false
    @State private var dragSpeed: CGFloat = 0         // for blur while scrubbing
    @State private var landTick: Int = 0              // sensoryFeedback trigger

    var body: some View {
        let live = clampedProgress(progress + dragProgress)
        let blur = currentBlur()
        FlipBookView_BookStage(size: size, progress: live, blur: blur)
            .contentShape(Rectangle())
            .gesture(scrubGesture)
            .sensoryFeedback(.impact(flexibility: .soft), trigger: landTick)
    }

    private var scrubGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDragging = true
                // Map horizontal drag to leaves; the book width is the natural
                // travel for ~2 page turns, so divide by half-width per leaf.
                let perLeaf = max(size.width, 1) * 0.42
                dragProgress = -value.translation.width / perLeaf
                // Live speed from instantaneous translation → smear while fast.
                let dist = abs(value.translation.width)
                dragSpeed = min(1, dist / (perLeaf * 1.4))
            }
            .onEnded { value in
                isDragging = false
                let perLeaf = max(size.width, 1) * 0.42
                // Coast using predicted end translation, then snap to a page.
                let predicted = -value.predictedEndTranslation.width / perLeaf
                let target = clampedProgress(progress + predicted)
                let landed = (target).rounded()
                dragProgress = 0
                dragSpeed = 0
                withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                    progress = clampedProgress(landed)
                }
                landTick &+= 1
            }
    }

    private func currentBlur() -> CGFloat {
        guard isDragging else { return 0 }      // crisp at rest
        return FlipBookView_Book.maxBlur * dragSpeed
    }

    private func clampedProgress(_ p: CGFloat) -> CGFloat {
        min(max(p, 0), CGFloat(FlipBookView_Book.pageCount - 1))
    }
}

// MARK: - The book stage (shared by demo + interactive)

private struct FlipBookView_BookStage: View {
    let size: CGSize
    let progress: CGFloat   // 0 ... pageCount-1
    let blur: CGFloat       // smear on the turning leaf

    var body: some View {
        // Lay out a book centered in the available space with a small margin.
        let margin: CGFloat = min(size.width, size.height) * 0.10
        let bookW = max(size.width - margin * 2, 1)
        let bookH = max(size.height - margin * 2, 1)
        let leafW = bookW / 2          // each page is half the open spread
        let spineX = bookW / 2         // center of the spread

        ZStack {
            background

            ZStack {
                // Static base: nothing in any frame depends on the turning
                // leaf being visible, so the 90° edge-on instant is never blank.
                rightStack(leafW: leafW, leafH: bookH, spineX: spineX)
                leftStack(leafW: leafW, leafH: bookH, spineX: spineX)
                turningLeaf(leafW: leafW, leafH: bookH, spineX: spineX)
                spine(height: bookH, x: spineX)
            }
            .frame(width: bookW, height: bookH)
            .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 10)
        }
        .frame(width: size.width, height: size.height)
    }

    private var currentLeaf: Int { Int(floor(progress)) }
    private var turnFraction: CGFloat { progress - floor(progress) }

    // MARK: Layers

    // The page currently lying flat on the right (the destination once the
    // turning leaf has fully turned). Always visible — keeps frames legible.
    private func rightStack(leafW: CGFloat, leafH: CGFloat, spineX: CGFloat) -> some View {
        let nextIndex = min(currentLeaf + 1, FlipBookView_Book.pageCount - 1)
        return FlipBookView_PageFace(index: nextIndex, isFront: true, leafW: leafW, leafH: leafH)
            .overlay(stackEdges(count: FlipBookView_Book.pageCount - 1 - currentLeaf, trailing: true,
                                leafW: leafW, leafH: leafH))
            .frame(width: leafW, height: leafH, alignment: .leading)
            .position(x: spineX + leafW / 2, y: leafH / 2)
            .zIndex(1)
    }

    // The most recently turned page lying flat on the left.
    private func leftStack(leafW: CGFloat, leafH: CGFloat, spineX: CGFloat) -> some View {
        // When fully on a whole page, the back face of the current leaf is
        // showing. Use the current leaf's back tone as the resting left page.
        let leftIndex = max(currentLeaf, 0)
        return FlipBookView_PageFace(index: leftIndex, isFront: false, leafW: leafW, leafH: leafH)
            .overlay(stackEdges(count: currentLeaf, trailing: false,
                                leafW: leafW, leafH: leafH))
            .frame(width: leafW, height: leafH, alignment: .trailing)
            .position(x: spineX - leafW / 2, y: leafH / 2)
            .zIndex(2)
    }

    // The single in-flight leaf, rotating continuously about the spine
    // (.leading edge) from 0° to 180°. SwiftUI shows the back face mirrored
    // once past 90°; because page identity is hue/shape coded (never text),
    // the mirroring is harmless, so we avoid any fragile un-mirror transform.
    private func turningLeaf(leafW: CGFloat, leafH: CGFloat, spineX: CGFloat) -> some View {
        let angle = Double(turnFraction) * 180.0     // 0 → 180°
        let showingBack = angle > 90.0
        let index = currentLeaf
        let faceShade = abs(cos(Angle(degrees: angle).radians)) // dim near edge-on

        return ZStack {
            if showingBack {
                FlipBookView_PageFace(index: index, isFront: false, leafW: leafW, leafH: leafH)
            } else {
                FlipBookView_PageFace(index: index, isFront: true, leafW: leafW, leafH: leafH)
            }
        }
        .frame(width: leafW, height: leafH)
        // Page-curl shading: the leaf darkens as it approaches edge-on.
        .overlay(Color.black.opacity((1 - faceShade) * 0.28))
        .blur(radius: blur)
        .rotation3DEffect(
            .degrees(angle),
            axis: (x: 0, y: 1, z: 0),
            anchor: .leading,
            perspective: FlipBookView_Book.perspective
        )
        .frame(width: leafW, height: leafH, alignment: .leading)
        .position(x: spineX + leafW / 2, y: leafH / 2)
        .zIndex(10)
    }

    private func spine(height: CGFloat, x: CGFloat) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.07),
                        Color(red: 0.16, green: 0.16, blue: 0.20),
                        Color(red: 0.05, green: 0.05, blue: 0.07)
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .frame(width: max(height * 0.018, 2), height: height)
            .position(x: x, y: height / 2)
            .zIndex(5)
    }

    // Thin stacked page edges fanning at the cut side to suggest thickness.
    private func stackEdges(count: Int, trailing: Bool, leafW: CGFloat, leafH: CGFloat) -> some View {
        let n = min(max(count, 0), 5)
        return HStack(spacing: 0) {
            if trailing { Spacer(minLength: 0) }
            ZStack {
                ForEach(0..<n, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(red: 0.92, green: 0.90, blue: 0.84))
                        .frame(width: 1.4, height: leafH * 0.97)
                        .offset(x: CGFloat(i) * 1.6 * (trailing ? 1 : -1))
                        .opacity(0.5)
                }
            }
            if !trailing { Spacer(minLength: 0) }
        }
        .allowsHitTesting(false)
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.06, blue: 0.09),
                Color(red: 0.09, green: 0.10, blue: 0.15)
            ],
            startPoint: .top, endPoint: .bottom
        )
    }
}

// MARK: - A single page face (hue-coded so identity survives mirroring)

private struct FlipBookView_PageFace: View {
    let index: Int
    let isFront: Bool
    let leafW: CGFloat
    let leafH: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(paperGradient)
            // A simple decorative motif keyed to the page — mirror-safe shapes,
            // never text, so a flipped back face never reads as broken.
            motif
                .padding(leafW * 0.14)
            // Inner shadow toward the spine to seat the page in the gutter.
            gutterShade
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.black.opacity(0.10), lineWidth: 0.5)
        )
    }

    // Each page gets a distinct hue ramp; the back face is a slightly
    // desaturated, darker version of the same hue so a turn reads continuous.
    private var paperGradient: LinearGradient {
        let base = Self.hue(for: index)
        let top = isFront ? base.opacity(1.0) : base.opacity(0.78)
        let bottom = isFront ? base.opacity(0.82) : base.opacity(0.6)
        return LinearGradient(colors: [top, bottom],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var motif: some View {
        let accent = Self.accent(for: index)
        return GeometryReader { g in
            let s = min(g.size.width, g.size.height)
            ZStack {
                Circle()
                    .fill(accent.opacity(0.16))
                    .frame(width: s * 0.9, height: s * 0.9)
                Capsule()
                    .fill(accent.opacity(0.55))
                    .frame(width: s * 0.62, height: s * 0.10)
                Capsule()
                    .fill(accent.opacity(0.35))
                    .frame(width: s * 0.42, height: s * 0.08)
                    .offset(y: s * 0.20)
                Capsule()
                    .fill(accent.opacity(0.35))
                    .frame(width: s * 0.42, height: s * 0.08)
                    .offset(y: -s * 0.20)
            }
            .frame(width: g.size.width, height: g.size.height)
        }
    }

    private var gutterShade: some View {
        LinearGradient(
            colors: [Color.black.opacity(0.22), .clear],
            startPoint: isFront ? .leading : .trailing,
            endPoint: isFront ? .trailing : .leading
        )
        .blendMode(.multiply)
        .allowsHitTesting(false)
    }

    // Warm paper tones cycling through a pleasant book palette.
    static func hue(for index: Int) -> Color {
        let palette: [Color] = [
            Color(red: 0.97, green: 0.95, blue: 0.90),
            Color(red: 0.96, green: 0.92, blue: 0.86),
            Color(red: 0.93, green: 0.94, blue: 0.97),
            Color(red: 0.95, green: 0.90, blue: 0.92),
            Color(red: 0.90, green: 0.95, blue: 0.93),
            Color(red: 0.97, green: 0.93, blue: 0.85),
            Color(red: 0.91, green: 0.93, blue: 0.96)
        ]
        let i = ((index % palette.count) + palette.count) % palette.count
        return palette[i]
    }

    static func accent(for index: Int) -> Color {
        let palette: [Color] = [
            Color(red: 0.83, green: 0.42, blue: 0.30),
            Color(red: 0.86, green: 0.62, blue: 0.24),
            Color(red: 0.30, green: 0.52, blue: 0.80),
            Color(red: 0.74, green: 0.34, blue: 0.55),
            Color(red: 0.26, green: 0.62, blue: 0.52),
            Color(red: 0.78, green: 0.50, blue: 0.22),
            Color(red: 0.38, green: 0.46, blue: 0.78)
        ]
        let i = ((index % palette.count) + palette.count) % palette.count
        return palette[i]
    }
}
