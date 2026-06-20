// catalog-id: ges-edge-swipe-page-curl
import SwiftUI

/// Edge-Swipe Page Curl
///
/// Swipe from the trailing edge and the page lifts and curls back like turning a
/// leaf. The crease line tracks the finger; the folded strip rotates about its own
/// leading edge (single-axis `rotation3DEffect` cylinder approximation) and shows a
/// shaded paper backside, while the next page is revealed underneath with a soft
/// shadow gradient hugging the crease.
///
/// - `demo == true`  : self-driving TimelineView loop that eases the curl 0→1→0.
/// - `demo == false` : interactive trailing-edge `DragGesture(minimumDistance: 0)`.
struct EdgeSwipePageCurlView: View {

    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if demo {
            DemoCurl(size: size)
        } else {
            InteractiveCurl(size: size)
        }
    }
}

// MARK: - Demo (self-driving loop)

private struct DemoCurl: View {
    let size: CGSize

    var body: some View {
        TimelineView(.animation) { timeline in
            let p = Self.loopProgress(timeline.date)
            PageCurlStage(size: size, progress: p, pageIndex: Self.pageIndex(timeline.date))
        }
    }

    /// 0 → 1 → 0 ease over a ~3.4s cycle (a peek-and-return turn, never committed).
    private static func loopProgress(_ date: Date) -> CGFloat {
        let period: Double = 3.4
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
        // Hold flat briefly, then a smooth out-and-back.
        let phase = (t - 0.08) / 0.84
        guard phase > 0, phase < 1 else { return 0 }
        let tri = phase < 0.5 ? phase * 2 : (1 - phase) * 2          // 0→1→0 triangle
        return CGFloat(smoothstep(tri))
    }

    /// Advance the "current page" content each completed cycle so the loop feels like
    /// real turning rather than the same leaf flapping.
    private static func pageIndex(_ date: Date) -> Int {
        let period: Double = 3.4
        let cycles = date.timeIntervalSinceReferenceDate / period
        return Int(cycles)
    }

    private static func smoothstep(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }
}

// MARK: - Interactive (real edge swipe)

private struct InteractiveCurl: View {
    let size: CGSize

    @State private var progress: CGFloat = 0
    @State private var pageIndex: Int = 0
    @GestureState private var dragging: Bool = false

    var body: some View {
        // Trailing-edge gate: only swipes starting in the trailing ~28% begin a turn.
        let edgeGate = max(size.width * 0.28, 36)

        PageCurlStage(size: size, progress: progress, pageIndex: pageIndex)
            .contentShape(Rectangle())
            .gesture(curlGesture(edgeGate: edgeGate))
            .sensoryFeedback(.selection, trigger: pageIndex)
    }

    private func curlGesture(edgeGate: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($dragging) { _, state, _ in state = true }
            .onChanged { value in
                guard size.width > 0 else { return }
                let startX = value.startLocation.x
                // Only react if the gesture began near the trailing edge.
                guard startX >= size.width - edgeGate else { return }
                // location.x sweeps right → left; map to crease position → progress.
                let creaseX = min(max(value.location.x, 0), size.width)
                progress = 1 - (creaseX / size.width)
            }
            .onEnded { value in
                let startX = value.startLocation.x
                guard startX >= size.width - edgeGate else { return }
                commit(velocity: value.predictedEndLocation.x - value.location.x)
            }
    }

    private func commit(velocity: CGFloat) {
        // Fast leftward fling, or already past halfway → complete the turn.
        let shouldTurn = progress > 0.5 || velocity < -size.width * 0.18
        if shouldTurn {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                progress = 1
            }
            // Snap to the next page once the leaf has laid over, then reset flat.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                pageIndex += 1
                progress = 0
            }
        } else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                progress = 0
            }
        }
    }
}

// MARK: - The three-layer stage

private struct PageCurlStage: View {
    let size: CGSize
    let progress: CGFloat
    let pageIndex: Int

    var body: some View {
        let p = min(max(progress, 0), 1)
        let width = size.width
        let creaseX = width * (1 - p)        // crease sweeps from right edge leftward
        let curlWidth = width * p            // width of the folded-back strip

        ZStack(alignment: .topLeading) {
            // 1 — desk / book backdrop so edges never read as blank.
            Backdrop()

            // 2 — the next page, revealed beneath, with a shadow hugging the crease.
            PageFace(seed: pageIndex + 1, size: size)
                .overlay(alignment: .leading) {
                    creaseShadow(creaseX: creaseX, width: width)
                }
                .clipped()

            // 3 — the flat remainder of the current page (left of the crease).
            PageFace(seed: pageIndex, size: size)
                .frame(width: max(creaseX, 0), height: size.height, alignment: .leading)
                .clipped()

            // 4 — the curled strip: the back of the leaf, folding about its leading edge.
            CurledStrip(progress: p, curlWidth: curlWidth, size: size)
                .frame(width: max(curlWidth, 0.5), height: size.height, alignment: .leading)
                .rotation3DEffect(
                    .degrees(Double(foldAngle(p))),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .leading,
                    perspective: 0.55
                )
                .offset(x: creaseX)
                .opacity(p > 0.001 ? 1 : 0)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    /// 0° flat → ~168° fully turned. The rotation itself mirrors the strip, so we never
    /// flip it manually (that would double-count the mirror).
    private func foldAngle(_ p: CGFloat) -> CGFloat {
        168 * p
    }

    private func creaseShadow(creaseX: CGFloat, width: CGFloat) -> some View {
        // Darkest at the crease, fading right across the revealed next page.
        let span = max(width * 0.32, 1)
        return LinearGradient(
            stops: [
                .init(color: .black.opacity(0.34), location: 0.0),
                .init(color: .black.opacity(0.12), location: 0.5),
                .init(color: .clear, location: 1.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: span)
        .offset(x: creaseX)
        .allowsHitTesting(false)
        .opacity(creaseX < width ? 1 : 0)
    }
}

// MARK: - The folded strip (paper backside)

private struct CurledStrip: View {
    let progress: CGFloat
    let curlWidth: CGFloat
    let size: CGSize

    var body: some View {
        ZStack {
            // Paper backside base.
            Rectangle()
                .fill(Self.paperBack)

            // Cylinder shading: crease (leading) is lit, far edge falls into shadow.
            LinearGradient(
                stops: [
                    .init(color: glint, location: 0.0),
                    .init(color: .white.opacity(0.04), location: 0.16),
                    .init(color: .black.opacity(0.10), location: 0.55),
                    .init(color: .black.opacity(0.30 + 0.16 * progress), location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            // Faint ruled ghost of the paper backside for texture.
            backRuling
        }
        .overlay(
            // Crisp lit highlight riding the crease edge — the "lift" off the page.
            Rectangle()
                .fill(.white.opacity(0.5 * progress))
                .frame(width: max(curlWidth * 0.06, 1))
                .blur(radius: 1.5),
            alignment: .leading
        )
        .compositingGroup()
        .clipped()
    }

    /// Brightness of the leading glint rises as the leaf lifts.
    private var glint: Color {
        .white.opacity(0.18 + 0.34 * Double(progress))
    }

    private var backRuling: some View {
        GeometryReader { g in
            let h = g.size.height
            let rows = 6
            ZStack {
                ForEach(0..<rows, id: \.self) { i in
                    let y = h * (0.2 + 0.6 * (CGFloat(i) / CGFloat(rows - 1)))
                    Rectangle()
                        .fill(.black.opacity(0.05))
                        .frame(height: 1)
                        .offset(y: y - h / 2)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private static let paperBack = LinearGradient(
        colors: [Color(hexCode: "#ece7df"), Color(hexCode: "#ddd6ca")],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - A legible page

private struct PageFace: View {
    let seed: Int
    let size: CGSize

    var body: some View {
        let pad = size.width * 0.1
        let accent = Self.accents[((seed % Self.accents.count) + Self.accents.count) % Self.accents.count]

        ZStack(alignment: .topLeading) {
            Rectangle().fill(Self.paper)

            VStack(alignment: .leading, spacing: size.height * 0.055) {
                header(accent: accent, width: size.width)
                textBars(width: size.width)
                Spacer(minLength: 0)
                footer(accent: accent, width: size.width)
            }
            .padding(pad)
            .frame(width: size.width, height: size.height, alignment: .topLeading)

            // Page number, lower trailing — sells "leaf in a book".
            Text("\(((seed % 99) + 99) % 99 + 1)")
                .font(.system(size: max(size.width * 0.07, 8), weight: .semibold, design: .serif))
                .foregroundStyle(.black.opacity(0.32))
                .padding(pad * 0.7)
                .frame(width: size.width, height: size.height, alignment: .bottomTrailing)
        }
        .overlay(
            // Subtle spine shading on the left edge.
            LinearGradient(
                colors: [.black.opacity(0.10), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: size.width * 0.16),
            alignment: .leading
        )
    }

    private func header(accent: Color, width: CGFloat) -> some View {
        HStack(spacing: width * 0.04) {
            RoundedRectangle(cornerRadius: 3)
                .fill(accent)
                .frame(width: width * 0.14, height: width * 0.14)
            VStack(alignment: .leading, spacing: width * 0.03) {
                Capsule().fill(.black.opacity(0.7)).frame(width: width * 0.42, height: width * 0.055)
                Capsule().fill(.black.opacity(0.28)).frame(width: width * 0.3, height: width * 0.04)
            }
        }
    }

    private func textBars(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: width * 0.045) {
            ForEach(barWidths, id: \.self) { w in
                Capsule()
                    .fill(.black.opacity(0.18))
                    .frame(width: width * w, height: width * 0.035)
            }
        }
    }

    private func footer(accent: Color, width: CGFloat) -> some View {
        HStack(spacing: width * 0.03) {
            Capsule().fill(accent.opacity(0.85)).frame(width: width * 0.26, height: width * 0.08)
            Capsule().fill(.black.opacity(0.12)).frame(width: width * 0.16, height: width * 0.08)
        }
    }

    /// Deterministic per-page line lengths so content varies but never shimmers.
    private var barWidths: [CGFloat] {
        let base: [CGFloat] = [0.78, 0.66, 0.8, 0.54, 0.72, 0.6]
        let shift = ((seed % base.count) + base.count) % base.count
        return Array(base[shift...] + base[..<shift])
    }

    private static let paper = LinearGradient(
        colors: [Color(hexCode: "#fbf9f4"), Color(hexCode: "#f1ece2")],
        startPoint: .top,
        endPoint: .bottom
    )

    private static let accents: [Color] = [
        Color(hexCode: "#e8743b"), Color(hexCode: "#3b8de8"),
        Color(hexCode: "#34a06b"), Color(hexCode: "#b5519a")
    ]
}

// MARK: - Backdrop

private struct Backdrop: View {
    var body: some View {
        Color(hexCode: "#0d0e16")
            .overlay(
                RadialGradient(
                    colors: [Color(hexCode: "#1b1d2b"), Color(hexCode: "#0d0e16")],
                    center: .center,
                    startRadius: 2,
                    endRadius: 240
                )
            )
            .ignoresSafeArea()
    }
}

// MARK: - Color hex helper

private extension Color {
    init(hexCode hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b, a: Double
        switch s.count {
        case 8:
            r = Double((v >> 24) & 0xFF) / 255
            g = Double((v >> 16) & 0xFF) / 255
            b = Double((v >> 8) & 0xFF) / 255
            a = Double(v & 0xFF) / 255
        case 6:
            r = Double((v >> 16) & 0xFF) / 255
            g = Double((v >> 8) & 0xFF) / 255
            b = Double(v & 0xFF) / 255
            a = 1
        default:
            r = 1; g = 1; b = 1; a = 1
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
