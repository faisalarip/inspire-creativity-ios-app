// catalog-id: ges-two-finger-shear
import SwiftUI

// MARK: - Two-Finger Shear Card
//
// Drag two fingers in opposite directions across the card (top half one way,
// bottom half the other) to shear it into a parallelogram with a glossy skew
// highlight. Release and it springs back to a true rectangle with an elastic
// wobble. The shear is dimensionless (offset / card height) so it behaves the
// same in a 120pt tile and in a large detail area.

struct TwoFingerShearView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let card = max(40, side * 0.74)

            ZStack {
                TwoFingerShearView_BackdropView()

                if demo {
                    TwoFingerShearView_DemoShearStage(cardSide: card)
                } else {
                    TwoFingerShearView_InteractiveShearStage(cardSide: card)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Animatable shear effect

/// A ProjectionTransform whose shear coefficient is animatable, so it tweens
/// smoothly under .interpolatingSpring and PhaseAnimator instead of snapping.
private struct TwoFingerShearView_ShearEffect: GeometryEffect {
    var shear: CGFloat

    var animatableData: CGFloat {
        get { shear }
        set { shear = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let cy = size.height / 2
        // x' = x + shear * y, compensated by -shear*cy so the vertical center
        // stays put and the card leans symmetrically into a parallelogram.
        let transform = CGAffineTransform(
            a: 1, b: 0,
            c: shear, d: 1,
            tx: -shear * cy, ty: 0
        )
        return ProjectionTransform(transform)
    }
}

// MARK: - Backdrop

private struct TwoFingerShearView_BackdropView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.08, blue: 0.13),
                        Color(red: 0.04, green: 0.04, blue: 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .ignoresSafeArea()
    }
}

// MARK: - The card visual (shared by demo + interactive)

private struct TwoFingerShearView_ShearCard: View {
    var side: CGFloat
    var shear: CGFloat

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: side * 0.16, style: .continuous)
    }

    // Normalized 0...1 magnitude used to intensify the gloss + rim under tension.
    private var tension: CGFloat {
        min(1, abs(shear) / 0.4)
    }

    var body: some View {
        ZStack {
            faceFill
            glossSheen
            rimStroke
            gripHints
        }
        .frame(width: side, height: side)
        .clipShape(shape)
        .modifier(TwoFingerShearView_ShearEffect(shear: shear))
        .shadow(
            color: Color(red: 0.0, green: 0.0, blue: 0.0).opacity(0.45),
            radius: 16, x: shear * side * 0.35, y: 12
        )
    }

    private var faceFill: some View {
        shape
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.42, green: 0.55, blue: 0.98),
                        Color(red: 0.62, green: 0.36, blue: 0.92),
                        Color(red: 0.32, green: 0.42, blue: 0.86)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    // Diagonal sheen that lives inside the (clipped) card, so it shears along
    // with the face. Its angle drifts with the shear amount to "track the skew".
    private var glossSheen: some View {
        let lean = shear * 0.9
        return LinearGradient(
            colors: [
                Color(red: 1, green: 1, blue: 1).opacity(0.0),
                Color(red: 1, green: 1, blue: 1).opacity(0.28 + 0.4 * tension),
                Color(red: 1, green: 1, blue: 1).opacity(0.0)
            ],
            startPoint: UnitPoint(x: 0.15 + lean, y: 0.0),
            endPoint: UnitPoint(x: 0.55 + lean, y: 1.0)
        )
        .blendMode(.screen)
    }

    private var rimStroke: some View {
        shape
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color(red: 1, green: 1, blue: 1).opacity(0.55 + 0.3 * tension),
                        Color(red: 1, green: 1, blue: 1).opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.4
            )
    }

    // Two faint grip bars hint that the top and bottom edges are draggable.
    private var gripHints: some View {
        VStack {
            gripBar
            Spacer()
            gripBar
        }
        .padding(.vertical, side * 0.12)
        .opacity(0.5)
    }

    private var gripBar: some View {
        Capsule()
            .fill(Color(red: 1, green: 1, blue: 1).opacity(0.6))
            .frame(width: side * 0.42, height: 4)
    }
}

// MARK: - Demo: self-driving PhaseAnimator loop

private enum TwoFingerShearView_ShearPhase: CaseIterable {
    case rect, shearedLeft, rectMid, shearedRight

    var shear: CGFloat {
        switch self {
        case .rect:         return 0
        case .shearedLeft:  return -0.38
        case .rectMid:      return 0
        case .shearedRight: return 0.38
        }
    }

    var animation: Animation {
        switch self {
        case .rect, .rectMid:
            // Settle back square with a bouncy wobble.
            return .interpolatingSpring(stiffness: 120, damping: 9)
        case .shearedLeft, .shearedRight:
            // Lean into the parallelogram smoothly.
            return .easeInOut(duration: 0.85)
        }
    }
}

private struct TwoFingerShearView_DemoShearStage: View {
    var cardSide: CGFloat

    var body: some View {
        PhaseAnimator(TwoFingerShearView_ShearPhase.allCases) { phase in
            TwoFingerShearView_ShearCard(side: cardSide, shear: phase.shear)
        } animation: { phase in
            phase.animation
        }
    }
}

// MARK: - Interactive: two independent finger halves

private struct TwoFingerShearView_InteractiveShearStage: View {
    var cardSide: CGFloat

    @State private var topShear: CGFloat = 0      // contribution from top finger
    @State private var bottomShear: CGFloat = 0   // contribution from bottom finger
    @State private var releasedShear: CGFloat = 0 // spring-home target on release
    @State private var isDragging = false
    @State private var impactTrigger = 0

    // While dragging, shear pins 1:1 to the fingers; once released we hand off
    // to the spring-animated `releasedShear`.
    private var liveShear: CGFloat {
        let raw = topShear - bottomShear
        return max(-0.45, min(0.45, raw))
    }

    private var shear: CGFloat {
        isDragging ? liveShear : releasedShear
    }

    var body: some View {
        ZStack {
            TwoFingerShearView_ShearCard(side: cardSide, shear: shear)

            // Invisible, hittable top/bottom halves capture one finger each.
            // Two separate DragGestures on separate views = true two-finger
            // input without UIKit (a single DragGesture is single-touch).
            VStack(spacing: 0) {
                halfCatcher(isTop: true)
                halfCatcher(isTop: false)
            }
            .frame(width: cardSide, height: cardSide)
        }
        .sensoryFeedback(.impact, trigger: impactTrigger)
    }

    private func halfCatcher(isTop: Bool) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(halfDrag(isTop: isTop))
    }

    private func halfDrag(isTop: Bool) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDragging = true
                // Normalize by card height so the shear is size-independent.
                let contribution = value.translation.width / cardSide
                if isTop {
                    topShear = contribution
                } else {
                    bottomShear = contribution
                }
            }
            .onEnded { _ in
                let wasSheared = abs(liveShear) > 0.04
                // Capture the live value as the spring's starting point.
                releasedShear = liveShear
                isDragging = false
                topShear = 0
                bottomShear = 0
                if wasSheared {
                    impactTrigger += 1
                }
                withAnimation(.interpolatingSpring(stiffness: 130, damping: 8.5)) {
                    releasedShear = 0
                }
            }
    }
}
