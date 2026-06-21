// catalog-id: nav-pagecurl-drawer
import SwiftUI

// MARK: - Page Curl Drawer
// Dragging from the screen edge peels the top surface back like a turning page,
// revealing a navigation panel underneath. A lit, curved highlight rides the
// lifting edge with a shadow cast onto the panel; rubber-band resistance on
// drag and a velocity-aware spring snap to open/closed on release.

struct PagecurlDrawerView: View {
    var demo: Bool = false

    // Interactive state (demo == false)
    @State private var progress: CGFloat = 0      // 0 = closed (flat page), 1 = open (curled away)
    @State private var isOpen: Bool = false

    // Geometry constants
    private let maxAngle: Double = 82             // cap below 90 to avoid backface / z-fight
    private let loopDuration: Double = 3.0

    var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Root content

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if demo {
            TimelineView(.animation) { timeline in
                let p = autoProgress(timeline.date)
                stack(size: size, progress: p)
            }
        } else {
            stack(size: size, progress: progress)
                .contentShape(Rectangle())
                .gesture(dragGesture(width: size.width))
        }
    }

    // MARK: Composition

    private func stack(size: CGSize, progress p: CGFloat) -> some View {
        let clamped = max(0, min(1, p))
        return ZStack {
            // Panel sits BEHIND, full size, always legible.
            PagecurlDrawerView_NavPanel(reveal: clamped)

            // The curling top page, hinged on the trailing (right) edge.
            PagecurlDrawerView_CurlingPage(progress: clamped, maxAngle: maxAngle, size: size)
        }
    }

    // MARK: Auto-drive loop (demo)

    private func autoProgress(_ date: Date) -> CGFloat {
        let t = date.timeIntervalSinceReferenceDate
        let phase = (t.truncatingRemainder(dividingBy: loopDuration)) / loopDuration // 0..1
        // Smooth triangle: rise then fall, eased, with a hold near open.
        let tri: Double
        if phase < 0.45 {
            tri = ease(phase / 0.45)
        } else if phase < 0.60 {
            tri = 1.0                                  // brief hold open
        } else {
            tri = ease(1.0 - (phase - 0.60) / 0.40)
        }
        return CGFloat(tri)
    }

    private func ease(_ x: Double) -> Double {
        let c = min(1, max(0, x))
        return c * c * (3 - 2 * c)                     // smoothstep
    }

    // MARK: Drag wiring (interactive)

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let raw = value.translation.width / max(width, 1)
                let base: CGFloat = isOpen ? 1 : 0
                let target = base + raw
                progress = rubberBand(target)
            }
            .onEnded { value in
                let predicted = (isOpen ? 1 : 0) + value.predictedEndTranslation.width / max(width, 1)
                let shouldOpen = predicted > 0.5
                isOpen = shouldOpen
                withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                    progress = shouldOpen ? 1 : 0
                }
            }
    }

    // Dampened overshoot beyond [0,1].
    private func rubberBand(_ x: CGFloat) -> CGFloat {
        if x < 0 { return x * 0.3 }
        if x > 1 { return 1 + (x - 1) * 0.3 }
        return x
    }
}

// MARK: - Navigation Panel (revealed underneath)

private struct PagecurlDrawerView_NavPanel: View {
    var reveal: CGFloat

    private let items: [(String, Color)] = [
        ("square.grid.2x2.fill", Color(red: 0.45, green: 0.78, blue: 0.95)),
        ("sparkles",             Color(red: 0.95, green: 0.78, blue: 0.42)),
        ("heart.fill",           Color(red: 0.96, green: 0.50, blue: 0.55)),
        ("bell.fill",            Color(red: 0.62, green: 0.86, blue: 0.62)),
        ("gearshape.fill",       Color(red: 0.74, green: 0.70, blue: 0.95))
    ]

    var body: some View {
        GeometryReader { geo in
            let s = geo.size
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.13, blue: 0.20),
                        Color(red: 0.06, green: 0.08, blue: 0.13)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                rows(in: s)
            }
            .frame(width: s.width, height: s.height)
        }
    }

    private func rows(in s: CGSize) -> some View {
        let count = items.count
        let pad = s.height * 0.10
        let usable = s.height - pad * 2
        let spacing = usable / CGFloat(count)
        let dot = min(spacing * 0.52, s.width * 0.30)
        return ZStack(alignment: .topLeading) {
            ForEach(0..<count, id: \.self) { i in
                row(index: i, dot: dot, s: s)
                    .offset(
                        x: s.width * 0.12,
                        y: pad + spacing * CGFloat(i) + (spacing - dot) / 2
                    )
            }
        }
    }

    private func row(index i: Int, dot: CGFloat, s: CGSize) -> some View {
        let (symbol, tint) = items[i]
        // Stagger the entrance with reveal progress.
        let appear = max(0, min(1, (reveal - CGFloat(i) * 0.06) / 0.6))
        return HStack(spacing: dot * 0.5) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.20))
                Image(systemName: symbol)
                    .font(.system(size: dot * 0.5, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: dot, height: dot)

            Capsule()
                .fill(Color.white.opacity(0.12))
                .frame(width: s.width * 0.38 * appear, height: dot * 0.34)
        }
        .opacity(Double(appear))
        .offset(x: (1 - appear) * -s.width * 0.08)
    }
}

// MARK: - Curling Page (the peeling top surface)

private struct PagecurlDrawerView_CurlingPage: View {
    var progress: CGFloat            // 0..1 (rubber-banded values handled by caller clamp)
    var maxAngle: Double
    var size: CGSize

    var body: some View {
        let angle = Double(max(0, min(1, progress))) * maxAngle
        ZStack {
            pageFace
            // Lit fold highlight riding the lifting (leading / left) edge.
            PagecurlDrawerView_FoldLight(progress: progress)
            // Soft contact shadow near the hinge as the page lifts.
            hingeShade
        }
        // Cast a moving drop shadow onto the panel to sell the lift.
        .shadow(
            color: Color.black.opacity(0.35 * Double(min(1, progress))),
            radius: 14 * min(1, progress),
            x: -10 * min(1, progress),
            y: 4
        )
        // Hinge on the trailing (right) edge: the LEFT edge lifts toward viewer.
        .rotation3DEffect(
            .degrees(angle),
            axis: (x: 0, y: 1, z: 0),
            anchor: .trailing,
            anchorZ: 0,
            perspective: 0.55
        )
    }

    private var pageFace: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.96, blue: 0.93),
                    Color(red: 0.90, green: 0.89, blue: 0.85)
                ],
                startPoint: .leading, endPoint: .trailing
            )
            pageContent
        }
    }

    // Faux page content so the lifting face stays legible (never blank).
    private var pageContent: some View {
        VStack(alignment: .leading, spacing: size.height * 0.045) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 0.20, green: 0.24, blue: 0.32))
                .frame(width: size.width * 0.42, height: size.height * 0.07)
            ForEach(0..<5, id: \.self) { i in
                Capsule()
                    .fill(Color(red: 0.55, green: 0.57, blue: 0.62).opacity(0.55))
                    .frame(width: size.width * (0.66 - CGFloat(i) * 0.07),
                           height: size.height * 0.035)
            }
        }
        .padding(.horizontal, size.width * 0.10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, size.height * 0.12)
    }

    private var hingeShade: some View {
        LinearGradient(
            colors: [
                Color.black.opacity(0.0),
                Color.black.opacity(0.22 * Double(min(1, progress)))
            ],
            startPoint: .leading, endPoint: .trailing
        )
        .allowsHitTesting(false)
    }
}

// MARK: - Fold Light (lit cylindrical highlight on the lifting edge)

private struct PagecurlDrawerView_FoldLight: View {
    var progress: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let p = Double(max(0, min(1, progress)))
            // Highlight band rides from the leading (left) edge inward as it lifts.
            let bandW = w * 0.30
            ZStack(alignment: .leading) {
                // Bright specular streak on the curling edge.
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.0),
                        Color.white.opacity(0.55 * p),
                        Color.white.opacity(0.85 * p),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: bandW)
                .blur(radius: 2)

                // A thin crisp lit line at the very fold edge.
                Rectangle()
                    .fill(Color.white.opacity(0.7 * p))
                    .frame(width: 1.5)
                    .blur(radius: 0.5)
            }
            .frame(width: w, alignment: .leading)
            .blendMode(.screen)
            .allowsHitTesting(false)
        }
    }
}
