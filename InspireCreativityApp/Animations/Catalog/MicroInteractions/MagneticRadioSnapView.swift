// catalog-id: mi-magnetic-radio-snap
import SwiftUI

// Snap-Together Choice Chips
// Selectable chips drift slightly apart at rest; the chosen chip snaps to a
// magnetic notch (its idle drift collapses to zero) with a click-in scale pop
// while siblings recoil away, like puzzle pieces settling into a slot.

struct MagneticRadioSnapView: View {
    var demo: Bool = false

    private let labels = ["Light", "Auto", "Dark", "System"]

    @State private var selected: Int = 1

    var body: some View {
        GeometryReader { geo in
            content(geo: geo)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sensoryFeedback(.selection, trigger: selected)
    }

    @ViewBuilder
    private func content(geo: GeometryProxy) -> some View {
        let metrics = MagneticRadioSnapView_MRSMetrics(size: geo.size, count: labels.count)

        ZStack {
            backdrop(metrics: metrics)
            chipRow(metrics: metrics)
        }
        .frame(width: geo.size.width, height: geo.size.height)
        .modifier(MagneticRadioSnapView_MRSDriver(demo: demo, count: labels.count, selected: $selected))
    }

    // MARK: - Backdrop

    private func backdrop(metrics: MagneticRadioSnapView_MRSMetrics) -> some View {
        RoundedRectangle(cornerRadius: metrics.trackCorner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.11, green: 0.10, blue: 0.16),
                        Color(red: 0.07, green: 0.06, blue: 0.11)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: metrics.trackCorner, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .frame(width: metrics.trackWidth, height: metrics.trackHeight)
            .shadow(color: .black.opacity(0.35), radius: metrics.trackHeight * 0.12, y: 4)
    }

    // MARK: - Chip row

    private func chipRow(metrics: MagneticRadioSnapView_MRSMetrics) -> some View {
        HStack(spacing: metrics.spacing) {
            ForEach(labels.indices, id: \.self) { index in
                chipView(index: index, metrics: metrics)
            }
        }
    }

    private func chipView(index: Int, metrics: MagneticRadioSnapView_MRSMetrics) -> some View {
        let isSelected = index == selected
        // Magnetic snap: the chosen chip's idle drift collapses to the notch (0,0).
        // Because `selected` changes inside withAnimation(.spring), this glides in.
        let drift = isSelected
            ? (dx: CGFloat(0), dy: CGFloat(0))
            : MagneticRadioSnapView_MRSDrift.offset(for: index, magnitude: metrics.driftMagnitude)
        // Siblings recoil away from the selected chip.
        let recoilSign: CGFloat = index < selected ? -1 : (index > selected ? 1 : 0)

        return MagneticRadioSnapView_MRSChip(
            label: labels[index],
            isSelected: isSelected,
            metrics: metrics
        )
        .offset(x: drift.dx, y: drift.dy)
        .keyframeAnimator(
            initialValue: MagneticRadioSnapView_MRSPop(),
            trigger: selected
        ) { view, value in
            view
                .scaleEffect(value.scale)
                .offset(x: value.recoil * recoilSign)
                .rotationEffect(.degrees(value.tilt))
        } keyframes: { _ in
            // All three tracks always emitted (no result-builder conditionals);
            // the per-chip condition lives in the keyframe values.
            KeyframeTrack(\.scale) {
                SpringKeyframe(isSelected ? 1.18 : 1.0, duration: 0.16, spring: .bouncy(extraBounce: 0.2))
                SpringKeyframe(1.0, duration: 0.42, spring: Spring(duration: 0.4, bounce: 0.5))
            }
            KeyframeTrack(\.tilt) {
                CubicKeyframe(isSelected ? -3 : 0, duration: 0.10)
                SpringKeyframe(0, duration: 0.42, spring: Spring(bounce: 0.45))
            }
            KeyframeTrack(\.recoil) {
                CubicKeyframe(isSelected ? 0 : metrics.recoilMagnitude, duration: 0.12)
                SpringKeyframe(0, duration: 0.5, spring: Spring(bounce: 0.4))
            }
        }
        .zIndex(isSelected ? 1 : 0)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !demo else { return }
            withAnimation(.spring(duration: 0.4, bounce: 0.5)) {
                selected = index
            }
        }
    }
}

// MARK: - Chip

private struct MagneticRadioSnapView_MRSChip: View {
    let label: String
    let isSelected: Bool
    let metrics: MagneticRadioSnapView_MRSMetrics

    var body: some View {
        Text(label)
            .font(.system(size: metrics.fontSize, weight: isSelected ? .bold : .medium, design: .rounded))
            .foregroundStyle(isSelected ? Color(red: 0.10, green: 0.08, blue: 0.14) : Color.white.opacity(0.72))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, metrics.chipPaddingH)
            .padding(.vertical, metrics.chipPaddingV)
            .frame(minWidth: metrics.chipMinWidth)
            .background(chipBackground)
            .overlay(notch)
            .animation(.easeInOut(duration: 0.3), value: isSelected)
    }

    private var chipBackground: some View {
        Capsule(style: .continuous)
            .fill(
                isSelected
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.62, green: 0.78, blue: 1.0),
                                Color(red: 0.40, green: 0.56, blue: 0.98)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    : AnyShapeStyle(Color.white.opacity(0.08))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(
                        isSelected ? Color.white.opacity(0.55) : Color.white.opacity(0.12),
                        lineWidth: isSelected ? 1.2 : 1
                    )
            )
            .shadow(
                color: isSelected ? Color(red: 0.40, green: 0.56, blue: 0.98).opacity(0.55) : .clear,
                radius: isSelected ? metrics.chipMinWidth * 0.18 : 0,
                y: isSelected ? 2 : 0
            )
    }

    // A small magnetic "notch" indicator under the selected chip.
    @ViewBuilder
    private var notch: some View {
        if isSelected {
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: metrics.notchSize, height: metrics.notchSize)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .offset(y: metrics.notchSize * 0.9)
                .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - Animatable pop value

private struct MagneticRadioSnapView_MRSPop {
    var scale: CGFloat = 1.0
    var recoil: CGFloat = 0.0
    var tilt: Double = 0.0
}

// MARK: - Deterministic idle drift

private enum MagneticRadioSnapView_MRSDrift {
    static func offset(for index: Int, magnitude: CGFloat) -> (dx: CGFloat, dy: CGFloat) {
        let i = Double(index)
        // Seeded, frame-stable pseudo-random drift — never re-randomized in body.
        let dx = CGFloat(sin(i * 2.3 + 0.7)) * magnitude
        let dy = CGFloat(cos(i * 1.7 + 1.3)) * magnitude * 0.6
        return (dx, dy)
    }
}

// MARK: - Layout metrics derived from geometry

private struct MagneticRadioSnapView_MRSMetrics {
    let trackWidth: CGFloat
    let trackHeight: CGFloat
    let trackCorner: CGFloat
    let spacing: CGFloat
    let fontSize: CGFloat
    let chipPaddingH: CGFloat
    let chipPaddingV: CGFloat
    let chipMinWidth: CGFloat
    let driftMagnitude: CGFloat
    let recoilMagnitude: CGFloat
    let notchSize: CGFloat

    init(size: CGSize, count: Int) {
        let w = max(size.width, 1)
        let h = max(size.height, 1)
        let minSide = min(w, h)

        let base: CGFloat = max(min(w, h * 2.2), 1)
        self.fontSize = max(min(base * 0.052, 18), 8)
        self.spacing = max(minSide * 0.04, 4)
        self.chipPaddingH = fontSize * 0.7
        self.chipPaddingV = fontSize * 0.5
        self.chipMinWidth = fontSize * 2.6
        self.trackWidth = min(w * 0.94, w - 8)
        self.trackHeight = min(h * 0.5, fontSize * 4.2)
        self.trackCorner = trackHeight * 0.3
        self.driftMagnitude = max(minSide * 0.012, 1.2)
        self.recoilMagnitude = max(minSide * 0.05, 4)
        self.notchSize = max(fontSize * 0.22, 2.5)
    }
}

// MARK: - Driver: demo auto-cycle vs. interactive

private struct MagneticRadioSnapView_MRSDriver: ViewModifier {
    let demo: Bool
    let count: Int
    @Binding var selected: Int

    func body(content: Content) -> some View {
        if demo {
            content
                .onReceive(
                    Timer.publish(every: 0.85, on: .main, in: .common).autoconnect()
                ) { _ in
                    withAnimation(.spring(duration: 0.42, bounce: 0.5)) {
                        selected = (selected + 1) % max(count, 1)
                    }
                }
        } else {
            content
        }
    }
}
