// catalog-id: btn-flip-clock-toggle
import SwiftUI

// MARK: - Flip-Clock Toggle
// A split-flap airport-departures-board toggle. Tapping (or, in demo, an auto loop)
// flips the state ON<->OFF: the top flap of the OLD value folds down out of view,
// revealing the NEW value's top behind it; then the NEW value's bottom flap folds
// up into place over the OLD bottom, with a mechanical spring settle.
//
// Fold direction note: the top flap hinges at its BOTTOM edge (the seam). Its angle
// goes 0 -> -90 about the X axis, so its free TOP edge drops toward the viewer/down
// to the seam (a classic falling flap). The bottom flap hinges at its TOP edge (the
// seam), angle 90 -> 0, so it swings up from behind into place.

public struct FlipClockToggleView: View {
    public var demo: Bool = false

    public init(demo: Bool = false) {
        self.demo = demo
    }

    public var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            // Card is portrait-ish like a real split-flap tile.
            let cardW = side * 0.62
            let cardH = side * 0.78

            ZStack {
                if demo {
                    FlipClockToggleView_DemoDriver(cardW: cardW, cardH: cardH)
                } else {
                    FlipClockToggleView_InteractiveDriver(cardW: cardW, cardH: cardH)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Drivers

/// Self-driving demo: a TimelineView computes flip progress from elapsed time and
/// auto-toggles ON<->OFF on a ~3s round trip (two flips of ~1.5s each).
private struct FlipClockToggleView_DemoDriver: View {
    let cardW: CGFloat
    let cardH: CGFloat

    private let flipDuration: Double = 1.5

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let cycle = t.truncatingRemainder(dividingBy: flipDuration)
            // Number of completed flips so far determines parity (which value is "to").
            let flipIndex = Int(t / flipDuration)
            // Eased progress 0->1 within this flip, with a slight settle dip near the end.
            let raw = cycle / flipDuration
            let progress = settledProgress(easeInOut(raw))

            // Even flip index = going to ON, odd = going to OFF (alternating).
            let toValue = (flipIndex % 2 == 0)
            let fromValue = !toValue

            FlipClockToggleView_FlipCard(fromOn: fromValue,
                     toOn: toValue,
                     progress: progress,
                     cardW: cardW,
                     cardH: cardH)
        }
    }

    /// Smooth 0->1 ease so the auto flip doesn't read as linear/robotic.
    private func easeInOut(_ x: Double) -> Double {
        let c = max(0, min(1, x))
        return c < 0.5 ? 2 * c * c : 1 - pow(-2 * c + 2, 2) / 2
    }

    /// Adds a tiny overshoot+settle near the end so the flap "lands" mechanically.
    private func settledProgress(_ p: Double) -> Double {
        guard p > 0.82 else { return p }
        let k = (p - 0.82) / 0.18            // 0..1 over the tail
        let bounce = sin(k * Double.pi) * 0.06
        return min(1.06, p + bounce)
    }
}

/// Real interactive component: tap toggles isOn; a spring drives the flip progress
/// with an overshoot settle. Tap (not drag) does not interfere with ScrollView.
private struct FlipClockToggleView_InteractiveDriver: View {
    let cardW: CGFloat
    let cardH: CGFloat

    @State private var isOn: Bool = false
    @State private var previous: Bool = false
    @State private var progress: Double = 1.0   // 1 == settled on current value
    @State private var flipToken: Int = 0

    var body: some View {
        VStack(spacing: cardH * 0.16) {
            FlipClockToggleView_FlipCard(fromOn: previous,
                     toOn: isOn,
                     progress: progress,
                     cardW: cardW,
                     cardH: cardH)

            Text(isOn ? "ON" : "OFF")
                .font(.system(size: max(9, cardW * 0.16), weight: .semibold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(Color(red: 0.55, green: 0.55, blue: 0.60))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        .onTapGesture { flip() }
        .sensoryFeedbackCompat(token: flipToken)
    }

    private func flip() {
        previous = isOn
        isOn.toggle()
        flipToken += 1
        // Start a fresh flip from 0 and spring to 1 with a bounce settle.
        progress = 0
        withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) {
            progress = 1
        }
    }
}

// MARK: - The split-flap card

/// Renders a single split-flap tile mid-flip. `progress` 0->1 drives a two-stage flip:
/// stage 1 (0..0.5) the OLD top flap folds down; stage 2 (0.5..1) the NEW bottom flap
/// folds up. Both static halves stay rendered so the tile is never blank.
private struct FlipClockToggleView_FlipCard: View {
    let fromOn: Bool
    let toOn: Bool
    let progress: Double
    let cardW: CGFloat
    let cardH: CGFloat

    private var topAngle: Double {
        // OLD top folds 0 -> -90 over the first half. Clamp so a >1 overshoot
        // can't un-fold it back into view.
        let p = min(1.0, max(0.0, progress / 0.5))
        return -90.0 * p
    }

    private var bottomAngle: Double {
        // NEW bottom folds 90 -> 0 over the second half; allow a slight negative
        // overshoot for the mechanical settle, then it returns to 0.
        let p = (progress - 0.5) / 0.5
        let clamped = max(0.0, p)
        return 90.0 * (1.0 - clamped)
    }

    var body: some View {
        ZStack {
            // Layer 1 (back): static TOP showing the NEW value, revealed as old top folds.
            // Pinned to the upper half so it sits above the seam.
            half(on: toOn, top: true)
                .offset(y: -cardH / 4)

            // Layer 2 (back): static BOTTOM showing the OLD value, until new bottom covers it.
            // Pinned to the lower half.
            half(on: fromOn, top: false)
                .offset(y: cardH / 4)

            // Layer 3: the falling top flap = OLD value's top, hinged at the seam (.bottom).
            half(on: fromOn, top: true)
                .overlay(foldShade(forFold: foldAmount(of: topAngle)))
                .rotation3DEffect(
                    .degrees(topAngle),
                    axis: (x: 1, y: 0, z: 0),
                    anchor: .bottom,
                    perspective: 0.45
                )
                .offset(y: -cardH / 4)              // place hinge on the seam (outermost)
                .opacity(progress < 0.5 ? 1 : 0)    // edge-on by 0.5; hide cleanly after

            // Layer 4: the rising bottom flap = NEW value's bottom, hinged at the seam (.top).
            half(on: toOn, top: false)
                .overlay(foldShade(forFold: foldAmount(of: bottomAngle)))
                .rotation3DEffect(
                    .degrees(bottomAngle),
                    axis: (x: 1, y: 0, z: 0),
                    anchor: .top,
                    perspective: 0.45
                )
                .offset(y: cardH / 4)               // place hinge on the seam (outermost)
                .opacity(progress >= 0.5 ? 1 : 0)   // appears once the top flap has cleared
        }
        .frame(width: cardW, height: cardH)
        .overlay(seam)
        .shadow(color: Color.black.opacity(0.45), radius: 10, x: 0, y: 6)
    }

    // A half of a card face, cropped to the upper or lower portion.
    private func half(on: Bool, top: Bool) -> some View {
        cardFace(on: on)
            .frame(width: cardW, height: cardH)
            .frame(height: cardH / 2, alignment: top ? .top : .bottom)
            .clipped()
    }

    // The full card face: rounded plate + centered label.
    private func cardFace(on: Bool) -> some View {
        let plateTop = Color(red: 0.16, green: 0.16, blue: 0.19)
        let plateBottom = Color(red: 0.085, green: 0.085, blue: 0.11)
        let label = on ? "ON" : "OFF"
        let labelColor = on
            ? Color(red: 0.45, green: 0.92, blue: 0.62)
            : Color(red: 0.78, green: 0.80, blue: 0.86)

        return RoundedRectangle(cornerRadius: cardW * 0.14, style: .continuous)
            .fill(
                LinearGradient(colors: [plateTop, plateBottom],
                               startPoint: .top, endPoint: .bottom)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cardW * 0.14, style: .continuous)
                    .stroke(Color(red: 0.30, green: 0.30, blue: 0.34), lineWidth: 1)
            )
            .overlay(
                Text(label)
                    .font(.system(size: cardW * 0.38, weight: .heavy, design: .rounded))
                    .foregroundStyle(labelColor)
                    .shadow(color: labelColor.opacity(on ? 0.55 : 0.0), radius: on ? 8 : 0)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .padding(.horizontal, cardW * 0.06)
            )
    }

    // Thin dark seam line across the horizontal center.
    private var seam: some View {
        Rectangle()
            .fill(Color.black.opacity(0.85))
            .frame(height: max(1, cardH * 0.012))
    }

    // Returns 0..1 fold amount from a flap's current angle magnitude.
    private func foldAmount(of angle: Double) -> Double {
        min(1.0, abs(angle) / 90.0)
    }

    // A shading gradient laid over a folding flap so it darkens as it leaves the plane.
    private func foldShade(forFold fold: Double) -> some View {
        LinearGradient(
            colors: [Color.black.opacity(0.05 + 0.45 * fold),
                     Color.black.opacity(0.0)],
            startPoint: .center, endPoint: .top
        )
        .allowsHitTesting(false)
    }
}

// MARK: - Sensory feedback (graceful no-op on the iOS 17 baseline path)

private extension View {
    @ViewBuilder
    func sensoryFeedbackCompat(token: Int) -> some View {
        if #available(iOS 17.0, *) {
            self.sensoryFeedback(.selection, trigger: token)
        } else {
            self
        }
    }
}
