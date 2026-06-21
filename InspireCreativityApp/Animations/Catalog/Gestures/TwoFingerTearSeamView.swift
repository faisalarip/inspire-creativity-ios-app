// catalog-id: ges-two-finger-tear-seam
import SwiftUI

// MARK: - Two-Finger Rip Seam
//
// Place two fingers and spread (pinch-out) to rip a panel along a stretching
// vertical seam that stress-whitens under tension, then splits into two ragged
// halves that recoil apart and re-seal.
//
// demo == true  -> self-driving PhaseAnimator loop over [.sealed, .stressed, .torn]
// demo == false -> real MagnifyGesture (a pinch-out IS two fingers pulling apart)
//
// The ragged seam offsets are seeded ONCE and never re-rolled per frame, so the
// jag is rock-stable; only the separation/cut position animates. iOS 17.

struct TwoFingerTearSeamView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            content(size: geo.size)
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(size: CGSize) -> some View {
        if demo {
            TwoFingerTearSeamView_DemoRig(size: size)
        } else {
            TwoFingerTearSeamView_InteractiveRig(size: size)
        }
    }
}

// MARK: - Phases

private enum TwoFingerTearSeamView_TearPhase: CaseIterable {
    case sealed, stressed, torn

    /// 0 = sealed, 1 = fully torn.
    var progress: CGFloat {
        switch self {
        case .sealed:   return 0.0
        case .stressed: return 0.42
        case .torn:     return 1.0
        }
    }
}

// MARK: - Demo rig (self-driving, never blank)

private struct TwoFingerTearSeamView_DemoRig: View {
    let size: CGSize
    // One stable seed for the whole lifetime of the tile.
    private let jag = TwoFingerTearSeamView_SeamJag(seed: 0xA17C_5EED, count: 16)

    var body: some View {
        PhaseAnimator(TwoFingerTearSeamView_TearPhase.allCases) { phase in
            TwoFingerTearSeamView_TearPanel(progress: phase.progress, size: size, jag: jag)
        } animation: { phase in
            switch phase {
            case .sealed:   return .easeInOut(duration: 0.5)
            case .stressed: return .easeIn(duration: 0.9)
            case .torn:     return .interpolatingSpring(stiffness: 140, damping: 9)
            }
        }
    }
}

// MARK: - Interactive rig (real two-finger spread)

private struct TwoFingerTearSeamView_InteractiveRig: View {
    let size: CGSize
    private let jag = TwoFingerTearSeamView_SeamJag(seed: 0xA17C_5EED, count: 16)

    @State private var progress: CGFloat = 0
    @State private var committed: Bool = false
    @State private var tearTrigger: Int = 0

    private let threshold: CGFloat = 0.62

    var body: some View {
        TwoFingerTearSeamView_TearPanel(progress: progress, size: size, jag: jag)
            .gesture(spread)
            .sensoryFeedback(.success, trigger: tearTrigger)
            .accessibilityLabel("Rip seam. Spread two fingers to tear.")
    }

    private var spread: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0)
            .onChanged { value in
                guard !committed else { return }
                // pinch-out magnification > 1 => pulling apart
                let pulled = max(value.magnification - 1.0, 0)
                progress = min(pulled * 1.35, 1.0)
            }
            .onEnded { _ in
                if progress >= threshold {
                    committed = true
                    tearTrigger &+= 1
                    withAnimation(.interpolatingSpring(stiffness: 130, damping: 8)) {
                        progress = 1.0
                    }
                    // auto re-seal so the tile stays reusable
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                        withAnimation(.easeInOut(duration: 0.55)) {
                            progress = 0
                        }
                        committed = false
                    }
                } else {
                    withAnimation(.interpolatingSpring(stiffness: 170, damping: 11)) {
                        progress = 0
                    }
                }
            }
    }
}

// MARK: - The torn panel (composition)

private struct TwoFingerTearSeamView_TearPanel: View {
    var progress: CGFloat
    let size: CGSize
    let jag: TwoFingerTearSeamView_SeamJag

    var body: some View {
        let dim = min(size.width, size.height)
        let panelW = min(size.width * 0.78, dim * 1.05)
        let panelH = min(size.height * 0.7, dim * 0.92)
        let corner = panelH * 0.12

        ZStack {
            halves(panelW: panelW, panelH: panelH, corner: corner)
            seamStress(panelW: panelW, panelH: panelH)
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func halves(panelW: CGFloat, panelH: CGFloat, corner: CGFloat) -> some View {
        // Max recoil kept well inside the panel so a torn frame is never blank.
        let gap = (panelW * 0.5) * progress   // total opening grows with progress
        let recoilTilt = Double(progress) * 7.0

        ZStack {
            // Left half: ragged on its right (inner) edge.
            half(side: -1, panelW: panelW, panelH: panelH, corner: corner,
                 tilt: -recoilTilt, anchor: .leading, dx: -gap * 0.5, shadowX: -2)

            // Right half: ragged on its left (inner) edge.
            half(side: 1, panelW: panelW, panelH: panelH, corner: corner,
                 tilt: recoilTilt, anchor: .trailing, dx: gap * 0.5, shadowX: 2)
        }
        .overlay(seamLabel(panelH: panelH))
    }

    @ViewBuilder
    private func half(side: CGFloat,
                      panelW: CGFloat,
                      panelH: CGFloat,
                      corner: CGFloat,
                      tilt: Double,
                      anchor: UnitPoint,
                      dx: CGFloat,
                      shadowX: CGFloat) -> some View {
        let shape = TwoFingerTearSeamView_RaggedHalf(progress: progress, side: side, jag: jag, corner: corner)
        shape
            .fill(panelFill)
            .overlay(shape.stroke(edgeStroke, lineWidth: 1))
            .frame(width: panelW, height: panelH)
            .rotationEffect(.degrees(tilt), anchor: anchor)
            .offset(x: dx)
            .shadow(color: .black.opacity(0.35 * progress + 0.12),
                    radius: 6, x: shadowX, y: 4)
    }

    /// Tension/whitening accent that lives over the closing seam.
    @ViewBuilder
    private func seamStress(panelW: CGFloat, panelH: CGFloat) -> some View {
        // Whitening peaks just before the rip, then drops as it opens.
        let stress = stressOpacity(progress)
        let seamWidth = max(2.0, (1.0 - progress) * panelW * 0.05 + 2.0)

        RoundedRectangle(cornerRadius: seamWidth * 0.5)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 1, green: 1, blue: 1).opacity(0),
                        Color(red: 1, green: 0.98, blue: 0.94),
                        Color(red: 1, green: 1, blue: 1).opacity(0)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .frame(width: seamWidth, height: panelH * (1.0 - progress * 0.45))
            .blur(radius: 1.5 + 2.0 * stress)
            .opacity(stress)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func seamLabel(panelH: CGFloat) -> some View {
        Image(systemName: "scissors")
            .font(.system(size: panelH * 0.16, weight: .semibold))
            .foregroundStyle(Color(red: 1, green: 1, blue: 1).opacity(0.75 * (1 - progress)))
            .rotationEffect(.degrees(90))
            .opacity(Double(1 - progress))
            .allowsHitTesting(false)
    }

    private func stressOpacity(_ p: CGFloat) -> Double {
        // bell curve peaking near the tear threshold (~0.55)
        let peak: CGFloat = 0.55
        let width: CGFloat = 0.34
        let d = (p - peak) / width
        return Double(min(max(exp(-d * d), 0), 1)) * (p < 0.02 ? 0 : 1)
    }

    private var panelFill: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.36, green: 0.42, blue: 0.86),
                Color(red: 0.55, green: 0.33, blue: 0.78),
                Color(red: 0.86, green: 0.38, blue: 0.55)
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private var edgeStroke: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1, green: 1, blue: 1).opacity(0.55),
                Color(red: 1, green: 1, blue: 1).opacity(0.12)
            ],
            startPoint: .top, endPoint: .bottom
        )
    }
}

// MARK: - Ragged half shape (animatable, stable jag)

/// One ragged half of the torn panel.
/// `side == -1` is the LEFT half (its right/inner edge is ragged).
/// `side == +1` is the RIGHT half (its left/inner edge is ragged).
/// `progress` widens the inner cut inward and grows the jag amplitude.
private struct TwoFingerTearSeamView_RaggedHalf: Shape {
    var progress: CGFloat
    let side: CGFloat
    let jag: TwoFingerTearSeamView_SeamJag
    let corner: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let centerX = rect.midX
        // How far the ragged edge pulls back from center as the rip opens.
        let pullback = rect.width * 0.30 * progress
        // Jag amplitude grows with tension/opening.
        let amp = rect.width * (0.015 + 0.06 * progress)

        // Inner edge x at a given vertex (toward center, offset by jag).
        func innerX(_ jagUnit: CGFloat) -> CGFloat {
            let base = centerX - side * pullback
            let jitter = side * (jagUnit - 0.4) * amp * 2.0
            return base - jitter
        }

        if side < 0 {
            // LEFT HALF: outer (left) straight edge, ragged right edge.
            path.move(to: CGPoint(x: rect.minX + corner, y: rect.minY))
            // top straight to seam
            path.addLine(to: CGPoint(x: innerX(jag.jag[0]), y: rect.minY))
            // ragged down the inner edge
            for i in 0..<jag.ys.count {
                let y = rect.minY + jag.ys[i] * rect.height
                path.addLine(to: CGPoint(x: innerX(jag.jag[i]), y: y))
            }
            // bottom edge back to outer
            path.addLine(to: CGPoint(x: rect.minX + corner, y: rect.maxY))
            // rounded outer-left corners
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - corner),
                control: CGPoint(x: rect.minX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + corner))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + corner, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY)
            )
        } else {
            // RIGHT HALF: outer (right) straight edge, ragged left edge.
            path.move(to: CGPoint(x: rect.maxX - corner, y: rect.minY))
            path.addLine(to: CGPoint(x: innerX(jag.jag[0]), y: rect.minY))
            for i in 0..<jag.ys.count {
                let y = rect.minY + jag.ys[i] * rect.height
                path.addLine(to: CGPoint(x: innerX(jag.jag[i]), y: y))
            }
            path.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY - corner),
                control: CGPoint(x: rect.maxX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + corner))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - corner, y: rect.minY),
                control: CGPoint(x: rect.maxX, y: rect.minY)
            )
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Stable seeded jag geometry (generated ONCE, not per frame)

private struct TwoFingerTearSeamView_SeamJag {
    /// Normalized (0...1) vertical positions of jag vertices down the seam.
    let ys: [CGFloat]
    /// Per-vertex normalized jag amount (0...1).
    let jag: [CGFloat]

    init(seed: UInt64, count: Int) {
        var rng = TwoFingerTearSeamView_SplitMix64(seed: seed)
        let n = max(count, 6)
        var ys: [CGFloat] = []
        var jag: [CGFloat] = []
        for i in 0...n {
            let t = CGFloat(i) / CGFloat(n)
            let jitter = (rng.unitCGFloat() - 0.5) * (0.7 / CGFloat(n))
            ys.append(min(max(t + jitter, 0), 1))
            jag.append(rng.unitCGFloat())
        }
        self.ys = ys
        self.jag = jag
    }
}

/// Deterministic TwoFingerTearSeamView_SplitMix64 RNG so the ragged edge is identical every frame.
private struct TwoFingerTearSeamView_SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func unitCGFloat() -> CGFloat {
        CGFloat(next() >> 11) / CGFloat(UInt64(1) << 53)
    }
}
