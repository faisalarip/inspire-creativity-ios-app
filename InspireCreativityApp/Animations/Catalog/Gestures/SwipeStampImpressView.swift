// catalog-id: ges-swipe-stamp-impress
import SwiftUI

// Swipe-Stamp Impress
// Drag a rubber stamp down onto the surface; it presses in with a squash,
// leaving an ink impression that blooms outward with a feathered ink-bleed edge.
//
// demo == true  -> self-driving PhaseAnimator loop drops / squashes / blooms / lifts.
// demo == false -> interactive DragGesture: downward drag drives approach + squash,
//                  contact blooms the ink (with .impact haptic), release lifts the stamp
//                  leaving the persisted impression.

struct SwipeStampImpressView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            let side: CGFloat = min(geo.size.width, geo.size.height)
            ZStack {
                if demo {
                    SwipeStampImpressView_DemoStage(side: side)
                } else {
                    SwipeStampImpressView_InteractiveStage(side: side)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Phases (demo loop)

private enum SwipeStampImpressView_StampPhase: CaseIterable {
    case up
    case pressed
    case lifted

    var pressProgress: CGFloat {
        switch self {
        case .up:      return 0.0
        case .pressed: return 1.0
        case .lifted:  return 0.0
        }
    }

    // Ink stays inked after the press so the impression reads as left behind.
    var inkProgress: CGFloat {
        switch self {
        case .up:      return 0.0
        case .pressed: return 1.0
        case .lifted:  return 1.0
        }
    }

    var animation: Animation {
        switch self {
        case .up:      return .spring(duration: 0.85, bounce: 0.20)
        case .pressed: return .spring(duration: 0.55, bounce: 0.45)
        case .lifted:  return .easeInOut(duration: 0.70)
        }
    }
}

// MARK: - Demo (self-driving)

private struct SwipeStampImpressView_DemoStage: View {
    let side: CGFloat

    var body: some View {
        PhaseAnimator(SwipeStampImpressView_StampPhase.allCases) { phase in
            SwipeStampImpressView_StampScene(side: side,
                       pressProgress: phase.pressProgress,
                       inkProgress: phase.inkProgress,
                       contactUnit: 0.5)
        } animation: { phase in
            phase.animation
        }
    }
}

// MARK: - Interactive

private struct SwipeStampImpressView_InteractiveStage: View {
    let side: CGFloat

    @State private var pressProgress: CGFloat = 0
    @State private var inkProgress: CGFloat = 0
    // Horizontal contact location in [0,1]; 0.5 == centered.
    @State private var contactUnit: CGFloat = 0.5
    @State private var didContact: Bool = false
    @State private var contactPulse: Int = 0

    private let contactThreshold: CGFloat = 0.55

    var body: some View {
        SwipeStampImpressView_StampScene(side: side,
                   pressProgress: pressProgress,
                   inkProgress: inkProgress,
                   contactUnit: contactUnit)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .sensoryFeedback(.impact(weight: .medium), trigger: contactPulse)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let travel: CGFloat = side * 0.55
                let raw: CGFloat = max(0, value.translation.height) / max(travel, 1)
                let p: CGFloat = min(1, raw)
                pressProgress = p
                contactUnit = clampUnit(value.location.x / max(side, 1))

                let inContact: Bool = p >= contactThreshold
                if inContact {
                    let bloom: CGFloat = (p - contactThreshold) / (1 - contactThreshold)
                    inkProgress = max(inkProgress, min(1, bloom))
                    if !didContact {
                        didContact = true
                        contactPulse += 1
                        withAnimation(.spring(duration: 0.45, bounce: 0.40)) {
                            inkProgress = 1
                        }
                    }
                } else {
                    didContact = false
                }
            }
            .onEnded { _ in
                didContact = false
                withAnimation(.spring(duration: 0.55, bounce: 0.22)) {
                    pressProgress = 0
                }
            }
    }

    private func clampUnit(_ v: CGFloat) -> CGFloat {
        min(0.85, max(0.15, v))
    }
}

// MARK: - Scene composition

private struct SwipeStampImpressView_StampScene: View {
    let side: CGFloat
    let pressProgress: CGFloat
    let inkProgress: CGFloat
    let contactUnit: CGFloat

    var body: some View {
        ZStack {
            SwipeStampImpressView_SurfaceCard(side: side)
            SwipeStampImpressView_InkImpression(side: side,
                          inkProgress: inkProgress,
                          contactUnit: contactUnit)
            SwipeStampImpressView_RubberStamp(side: side,
                        pressProgress: pressProgress,
                        contactUnit: contactUnit)
        }
        .frame(width: side, height: side)
    }
}

// MARK: - Surface (paper card)

private struct SwipeStampImpressView_SurfaceCard: View {
    let side: CGFloat

    private let paperTop = Color(red: 0.96, green: 0.95, blue: 0.91)
    private let paperBottom = Color(red: 0.90, green: 0.88, blue: 0.82)

    var body: some View {
        let inset: CGFloat = side * 0.10
        let radius: CGFloat = side * 0.07
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(colors: [paperTop, paperBottom],
                               startPoint: .top, endPoint: .bottom)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color(red: 0.78, green: 0.75, blue: 0.68), lineWidth: 1)
            )
            .frame(width: side - inset, height: side - inset)
            .shadow(color: Color.black.opacity(0.18),
                    radius: side * 0.03, x: 0, y: side * 0.012)
    }
}

// MARK: - Ink impression (feathered bloom)

private struct SwipeStampImpressView_InkImpression: View {
    let side: CGFloat
    let inkProgress: CGFloat
    let contactUnit: CGFloat

    private let ink = Color(red: 0.10, green: 0.16, blue: 0.55)

    var body: some View {
        let p: CGFloat = max(0, min(1, inkProgress))
        let cx: CGFloat = side * contactUnit
        // Contact line sits in the lower-middle band of the card.
        let cy: CGFloat = side * 0.56
        let markW: CGFloat = side * 0.40
        let markH: CGFloat = side * 0.40

        markGlyph(width: markW, height: markH)
            .position(x: cx, y: cy)
            .opacity(Double(min(1, p * 1.4)))
            .mask(
                bloomMask(width: markW * 2.0, height: markH * 2.0, progress: p)
                    .position(x: cx, y: cy)
            )
    }

    // The actual stamped emblem: ring + star, in ink color.
    private func markGlyph(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Circle()
                .strokeBorder(ink, lineWidth: max(2, width * 0.055))
                .frame(width: width, height: height)
            SwipeStampImpressView_StarShape(points: 5)
                .fill(ink)
                .frame(width: width * 0.52, height: height * 0.52)
        }
        // slight bleed: blur grows with bloom so edges feather as it spreads
        .blur(radius: max(0.3, width * 0.012))
    }

    // Feathered radial reveal — opaque center fading to clear at the edge.
    private func bloomMask(width: CGFloat, height: CGFloat, progress: CGFloat) -> some View {
        let scale: CGFloat = 0.25 + progress * 1.05
        return RadialGradient(
            gradient: Gradient(stops: [
                .init(color: .black, location: 0.0),
                .init(color: .black, location: 0.62),
                .init(color: .black.opacity(0.45), location: 0.82),
                .init(color: .clear, location: 1.0)
            ]),
            center: .center,
            startRadius: 0,
            endRadius: width * 0.5
        )
        .frame(width: width, height: height)
        .scaleEffect(scale)
    }
}

// MARK: - Rubber stamp body

private struct SwipeStampImpressView_RubberStamp: View {
    let side: CGFloat
    let pressProgress: CGFloat
    let contactUnit: CGFloat

    private let woodTop = Color(red: 0.45, green: 0.27, blue: 0.16)
    private let woodBottom = Color(red: 0.32, green: 0.18, blue: 0.10)
    private let padColor = Color(red: 0.16, green: 0.13, blue: 0.12)

    var body: some View {
        let p: CGFloat = max(0, min(1, pressProgress))
        let contactThreshold: CGFloat = 0.55
        let squash: CGFloat = squashAmount(p, threshold: contactThreshold)

        let restY: CGFloat = -side * 0.30
        let contactY: CGFloat = side * 0.04
        let yOffset: CGFloat = restY + (contactY - restY) * p
        let xOffset: CGFloat = (contactUnit - 0.5) * side

        VStack(spacing: 0) {
            handle
            base
        }
        .frame(width: side * 0.30, height: side * 0.40)
        .scaleEffect(x: 1 + squash * 0.10, y: 1 - squash * 0.16, anchor: .bottom)
        .offset(x: xOffset, y: yOffset)
        .shadow(color: Color.black.opacity(0.22 + Double(p) * 0.12),
                radius: side * 0.025, x: 0, y: side * 0.02)
    }

    // Squash only kicks in once the pad makes contact.
    private func squashAmount(_ p: CGFloat, threshold: CGFloat) -> CGFloat {
        guard p > threshold else { return 0 }
        return (p - threshold) / (1 - threshold)
    }

    private var handle: some View {
        let w: CGFloat = side * 0.18
        let h: CGFloat = side * 0.20
        return RoundedRectangle(cornerRadius: w * 0.30, style: .continuous)
            .fill(
                LinearGradient(colors: [woodTop, woodBottom],
                               startPoint: .top, endPoint: .bottom)
            )
            .overlay(
                RoundedRectangle(cornerRadius: w * 0.30, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .frame(width: w, height: h)
    }

    private var base: some View {
        let w: CGFloat = side * 0.30
        let h: CGFloat = side * 0.18
        return RoundedRectangle(cornerRadius: side * 0.03, style: .continuous)
            .fill(
                LinearGradient(colors: [woodTop, woodBottom],
                               startPoint: .top, endPoint: .bottom)
            )
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: side * 0.02, style: .continuous)
                    .fill(padColor)
                    .frame(width: w * 0.88, height: h * 0.34)
                    .offset(y: h * 0.04)
            }
            .frame(width: w, height: h)
    }
}

// MARK: - Star shape (stamp emblem)

private struct SwipeStampImpressView_StarShape: Shape {
    let points: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let count: Int = max(3, points)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer: CGFloat = min(rect.width, rect.height) / 2
        let inner: CGFloat = outer * 0.42
        let step: Double = .pi / Double(count)
        var angle: Double = -.pi / 2

        for i in 0..<(count * 2) {
            let r: CGFloat = (i % 2 == 0) ? outer : inner
            let x: CGFloat = center.x + cos(angle) * r
            let y: CGFloat = center.y + sin(angle) * r
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
            angle += step
        }
        path.closeSubpath()
        return path
    }
}
