// catalog-id: mi-radio-ink
import SwiftUI

/// Ink-Fill Radio — selecting an option drops a spreading ink blot that fills
/// the circle from the touch point while the previously selected option drains
/// away. Self-contained, no app dependencies. iOS 17+.
struct RadioInkView: View {

    /// demo == true  -> self-driving PhaseAnimator loop cycling the selection.
    /// demo == false -> real interactive radio group (tap to select, ink blooms
    ///                  from the tap point).
    var demo: Bool = false

    // MARK: Options

    struct InkOption: Identifiable {
        let id: Int
        let glyph: String
    }

    private let options: [InkOption] = [
        InkOption(id: 0, glyph: "A"),
        InkOption(id: 1, glyph: "B"),
        InkOption(id: 2, glyph: "C")
    ]

    // MARK: Palette (literal colors only)

    private let paper = Color(red: 0.078, green: 0.082, blue: 0.094)
    private let inkCore = Color(red: 0.44, green: 0.52, blue: 0.98)
    private let inkEdge = Color(red: 0.30, green: 0.36, blue: 0.86)
    private let ringIdle = Color(red: 0.36, green: 0.38, blue: 0.46)
    private let ringActive = Color(red: 0.62, green: 0.68, blue: 1.00)
    private let labelColor = Color(red: 0.80, green: 0.82, blue: 0.90)

    // MARK: Interactive state

    @State private var selectedIndex: Int = 0
    /// Normalized drop origin per option (where the ink soaks in from).
    @State private var dropAnchors: [UnitPoint] = [.top, .top, .top]

    var body: some View {
        GeometryReader { geo in
            let metrics = RadioInkView_Metrics(size: geo.size, count: options.count)

            if demo {
                demoBody(metrics: metrics)
            } else {
                interactiveBody(metrics: metrics)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(paper)
    }

    // MARK: Demo (self-driving) path

    private func demoBody(metrics: RadioInkView_Metrics) -> some View {
        // PhaseAnimator (auto-cycling init) walks the active index
        // 0 -> 1 -> 2 -> (wrap to 0) on a continuous loop. Each phase change
        // animates the bloom/drain via radioRow's internal easeOut keyed on
        // isSelected.
        PhaseAnimator(options.map(\.id)) { active in
            optionStack(metrics: metrics,
                        activeIndex: active,
                        anchorFor: { _ in .top })
        } animation: { _ in
            .easeInOut(duration: 1.1).delay(0.15)
        }
    }

    // MARK: Interactive path

    private func interactiveBody(metrics: RadioInkView_Metrics) -> some View {
        optionStack(metrics: metrics,
                    activeIndex: selectedIndex,
                    anchorFor: { index in dropAnchors[safe: index] ?? .top })
        .sensoryFeedback(.selection, trigger: selectedIndex)
    }

    // MARK: Shared layout

    private func optionStack(metrics: RadioInkView_Metrics,
                             activeIndex: Int,
                             anchorFor: @escaping (Int) -> UnitPoint) -> some View {
        VStack(spacing: metrics.rowSpacing) {
            ForEach(options) { option in
                row(option: option,
                    metrics: metrics,
                    isSelected: option.id == activeIndex,
                    anchor: anchorFor(option.id))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(metrics.outerPadding)
    }

    private func row(option: InkOption,
                     metrics: RadioInkView_Metrics,
                     isSelected: Bool,
                     anchor: UnitPoint) -> some View {
        HStack(spacing: metrics.labelGap) {
            radioRow(diameter: metrics.diameter,
                     isSelected: isSelected,
                     anchor: anchor)

            if metrics.showLabels {
                Text(option.glyph)
                    .font(.system(size: metrics.labelSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? ringActive : labelColor)
                    .animation(.easeOut(duration: 0.35), value: isSelected)
            }

            if metrics.showLabels { Spacer(minLength: 0) }
        }
        .contentShape(Rectangle())
        .modifier(RadioInkView_TapToSelect(enabled: !demo,
                              optionID: option.id,
                              diameter: metrics.diameter,
                              onSelect: { id, unit in
                                  dropAnchors[safe2: id] = unit
                                  withAnimation(.easeOut(duration: 0.55)) {
                                      selectedIndex = id
                                  }
                              }))
    }

    // MARK: Radio (ring + ink bloom). Shared by both paths.

    private func radioRow(diameter: CGFloat,
                          isSelected: Bool,
                          anchor: UnitPoint) -> some View {
        let inkScale: CGFloat = isSelected ? 1.0 : 0.0
        let inkOpacity: Double = isSelected ? 1.0 : 0.0
        let overshoot: CGFloat = diameter * 2.4   // >= 2x so an off-center
                                                  // bloom still reaches the rim.

        return ZStack {
            // Idle disc so the radio always reads, never fully blank.
            Circle()
                .fill(paper)
                .overlay(
                    Circle()
                        .fill(Color(red: 0.13, green: 0.135, blue: 0.16))
                )

            // Ink bloom — oversized, clipped to the radio circle, scaling out
            // from the drop anchor with an easeOut soak. Drains on deselect.
            inkBlob(size: overshoot)
                .scaleEffect(inkScale, anchor: anchor)
                .opacity(inkOpacity)
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())

            // Always-drawn ring sits outside the ink for legibility.
            Circle()
                .strokeBorder(isSelected ? ringActive : ringIdle,
                              lineWidth: max(1.5, diameter * 0.07))
        }
        .frame(width: diameter, height: diameter)
        // The single source of the bloom/drain curve for BOTH paths.
        .animation(.easeOut(duration: 0.55), value: isSelected)
        .animation(.easeOut(duration: 0.55), value: anchor)
    }

    private func inkBlob(size: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [inkCore, inkEdge],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.5
                )
            )
            .overlay(
                Circle()
                    .stroke(inkCore.opacity(0.35), lineWidth: size * 0.02)
                    .blur(radius: size * 0.02)
            )
            .frame(width: size, height: size)
    }
}

// MARK: - Tap capture (records normalized drop origin within the radio)

private struct RadioInkView_TapToSelect: ViewModifier {
    let enabled: Bool
    let optionID: Int
    let diameter: CGFloat
    let onSelect: (Int, UnitPoint) -> Void

    func body(content: Content) -> some View {
        if enabled {
            content.gesture(
                SpatialTapGesture(coordinateSpace: .local)
                    .onEnded { value in
                        onSelect(optionID, unitPoint(from: value.location))
                    }
            )
        } else {
            content
        }
    }

    /// Map the tap point (in the row's local space) to a UnitPoint roughly
    /// inside the radio circle, which sits at the leading edge of the row.
    private func unitPoint(from location: CGPoint) -> UnitPoint {
        let x = (location.x / max(diameter, 1)).clampedUnit()
        let y = (location.y / max(diameter, 1)).clampedUnit()
        return UnitPoint(x: x, y: y)
    }
}

// MARK: - RadioInkView_Metrics

private struct RadioInkView_Metrics {
    let diameter: CGFloat
    let rowSpacing: CGFloat
    let labelGap: CGFloat
    let labelSize: CGFloat
    let outerPadding: CGFloat
    let showLabels: Bool

    init(size: CGSize, count: Int) {
        let minSide = min(size.width, size.height)
        let isCompact = minSide < 160

        // Diameter scales off available height across the rows.
        let perRow = size.height / CGFloat(max(count, 1))
        let raw = min(perRow * 0.46, size.width * 0.34)
        diameter = max(14, min(raw, 64))

        rowSpacing = max(8, diameter * 0.55)
        labelGap = max(8, diameter * 0.35)
        labelSize = max(11, diameter * 0.52)
        outerPadding = isCompact ? diameter * 0.4 : diameter * 0.8
        // Hide labels in very small tiles so the radios dominate and read.
        showLabels = size.width >= 96
    }
}

// MARK: - Small helpers

private extension CGFloat {
    func clampedUnit() -> CGFloat { Swift.min(1, Swift.max(0, self)) }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension Array where Element == UnitPoint {
    subscript(safe2 index: Int) -> UnitPoint {
        get { indices.contains(index) ? self[index] : .top }
        set { if indices.contains(index) { self[index] = newValue } }
    }
}
