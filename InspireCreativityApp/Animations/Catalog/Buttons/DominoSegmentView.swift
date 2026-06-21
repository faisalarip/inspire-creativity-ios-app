// catalog-id: btn-domino-segment
import SwiftUI

// MARK: - Domino Segment

/// A segmented control whose selection knocks each segment over like a falling
/// domino chain. The topple cascades (staggered per index) from the previously
/// selected tile to the newly chosen one, then every tile stands back up.
///
/// - `demo == true`  : a self-driving loop auto-advances the selection so the
///                     dominoes endlessly chain across the tile (no touch).
/// - `demo == false` : a real interactive segmented control — tap a segment to
///                     fire the staggered topple cascade with selection haptics.
struct DominoSegmentView: View {
    var demo: Bool = false

    private let segments = ["Daily", "Weekly", "Monthly"]

    @State private var selectedIndex: Int = 0
    @State private var previousIndex: Int = 0
    @Namespace private var pillNS

    var body: some View {
        GeometryReader { geo in
            let count = max(segments.count, 1)
            let spacing: CGFloat = geo.size.width * 0.02
            let inset: CGFloat = geo.size.width * 0.035
            let totalSpacing = spacing * CGFloat(count - 1)
            let tileWidth = max((geo.size.width - inset * 2 - totalSpacing) / CGFloat(count), 1)
            let tileHeight = max(geo.size.height * 0.5, 1)

            ZStack {
                track(size: geo.size)

                HStack(spacing: spacing) {
                    ForEach(segments.indices, id: \.self) { idx in
                        segmentTile(index: idx, width: tileWidth, height: tileHeight)
                    }
                }
                .padding(.horizontal, inset)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.selection, trigger: selectedIndex) { _, _ in !demo }
        .task(id: demo) {
            guard demo else { return }
            await runDemoLoop()
        }
    }

    // MARK: Selection

    /// Spring used both for the pill slide (matchedGeometryEffect) and as the
    /// base of the staggered per-tile topple.
    private var selectionSpring: Animation {
        .spring(response: 0.42, dampingFraction: 0.62)
    }

    /// Moves the selection inside an animation transaction so the
    /// matchedGeometryEffect pill physically travels between segments.
    private func select(_ index: Int) {
        withAnimation(selectionSpring) {
            previousIndex = selectedIndex
            selectedIndex = index
        }
    }

    // MARK: Demo loop

    /// Cycles 0 -> 1 -> 2 -> wrap, advancing on a cadence comfortably longer than
    /// the cascade settle so tiles are never caught mid-topple. A full round trip
    /// lands in the ~2.5-4s window the tile wants.
    private func runDemoLoop() async {
        var next = selectedIndex
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if Task.isCancelled { return }
            next = (next + 1) % segments.count
            select(next)
        }
    }

    // MARK: Background

    private func track(size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: size.height * 0.28, style: .continuous)
            .fill(Color(red: 0.13, green: 0.11, blue: 0.09))
            .overlay(
                RoundedRectangle(cornerRadius: size.height * 0.28, style: .continuous)
                    .stroke(Color(red: 0.32, green: 0.27, blue: 0.20), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: size.height * 0.05, y: 2)
    }

    // MARK: Segment tile

    @ViewBuilder
    private func segmentTile(index: Int, width: CGFloat, height: CGFloat) -> some View {
        PhaseAnimator([0.0, 78.0, 0.0], trigger: selectedIndex) { angle in
            tileBody(index: index, width: width, height: height, angle: angle)
        } animation: { _ in
            let distance = Double(abs(index - previousIndex))
            return selectionSpring.delay(distance * 0.05)
        }
        .frame(width: width, height: height)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !demo else { return }
            guard index != selectedIndex else { return }
            select(index)
        }
    }

    @ViewBuilder
    private func tileBody(index: Int, width: CGFloat, height: CGFloat, angle: Double) -> some View {
        let isSelected = index == selectedIndex
        // A toppling tile leans toward its trailing edge as the cascade passes;
        // direction follows the travel of the chain.
        let signedAngle = (index >= previousIndex) ? angle : -angle
        // Shading deepens as the tile leans away from the light — sells the 3D edge.
        let leanT = min(angle / 78.0, 1.0)

        ZStack {
            if isSelected {
                RoundedRectangle(cornerRadius: height * 0.32, style: .continuous)
                    .fill(activePill)
                    .matchedGeometryEffect(id: "pill", in: pillNS)
                    .shadow(color: Color(red: 0.98, green: 0.62, blue: 0.20).opacity(0.45),
                            radius: 6, y: 1)
            }

            Text(segments[index])
                .font(.system(size: max(height * 0.28, 9), weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(isSelected
                                 ? Color(red: 0.16, green: 0.12, blue: 0.08)
                                 : Color(red: 0.78, green: 0.74, blue: 0.66))
                .padding(.horizontal, width * 0.06)
        }
        .frame(width: width, height: height)
        .overlay(
            // Cast shadow that intensifies as the face turns away — fakes the
            // contact shadow of a physical domino mid-fall.
            RoundedRectangle(cornerRadius: height * 0.32, style: .continuous)
                .fill(Color.black.opacity(leanT * 0.28))
        )
        .rotation3DEffect(
            .degrees(signedAngle),
            axis: (x: 0, y: 1, z: 0),
            anchor: .leading,
            perspective: 0.55
        )
    }

    private var activePill: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.00, green: 0.80, blue: 0.36),
                Color(red: 0.97, green: 0.59, blue: 0.18)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
