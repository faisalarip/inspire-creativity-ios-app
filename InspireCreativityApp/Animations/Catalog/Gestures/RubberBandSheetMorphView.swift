//
//  RubberBandSheetMorphView.swift
//  InspireCreativityApp — Bespoke catalog animation
//
//  Rubber-Band Sheet Morph: a bottom sheet you drag upward stretches past its
//  rest height with rubber-band resistance, and its contents re-flow from a
//  compact summary row into a multi-column grid as it rises, snapping back with
//  an overshoot spring.
//
//  Self-contained: SwiftUI only, no app dependencies (paste-and-run).
//  `demo == true`  → self-driving loop (grid tile, no finger).
//  `demo == false` → real DragGesture (Detail view + the buyer's code).
//

// catalog-id: ges-rubberband-sheet-morph
import SwiftUI

struct RubberBandSheetMorphView: View {
    /// Drives the self-playing demo loop in non-interactive grid tiles.
    var demo: Bool = false

    var body: some View {
        if demo {
            TimelineView(.animation) { ctx in
                SheetMorphStage(progress: Self.loopProgress(ctx.date))
            }
        } else {
            InteractiveSheetMorph()
        }
    }

    /// Eased 0→1→0 triangle wave on a ~3.6s period for the demo loop.
    static func loopProgress(_ date: Date) -> CGFloat {
        let period = 3.6
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
        let triangle = t < 0.5 ? t * 2 : (1 - t) * 2
        let eased = triangle * triangle * (3 - 2 * triangle) // smoothstep
        return CGFloat(eased)
    }
}

// MARK: - Interactive variant (real drag)

private struct InteractiveSheetMorph: View {
    @State private var progress: CGFloat = 0      // 0 collapsed … 1 expanded
    @GestureState private var dragProgress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let live = clampRubber(progress + dragProgress)
            SheetMorphStage(progress: live)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .updating($dragProgress) { value, state, _ in
                            // Upward drag (negative y) increases progress.
                            state = -value.translation.height / max(120, geo.size.height * 0.6)
                        }
                        .onEnded { value in
                            let predicted = progress - value.predictedEndTranslation.height
                                / max(120, geo.size.height * 0.6)
                            withAnimation(.snappy(duration: 0.45, extraBounce: 0.2)) {
                                progress = predicted > 0.5 ? 1 : 0
                            }
                        }
                )
        }
    }

    /// Asymptotic rubber-band clamp so it can stretch a little past 0…1.
    private func clampRubber(_ p: CGFloat) -> CGFloat {
        if p < 0 { return -0.06 * (1 - 1 / (-p * 6 + 1)) }
        if p > 1 { return 1 + 0.06 * (1 - 1 / ((p - 1) * 6 + 1)) }
        return p
    }
}

// MARK: - Shared visual (used by both demo loop and interactive)

private struct SheetMorphStage: View {
    /// May slightly exceed 0…1 for the rubber-band overshoot.
    let progress: CGFloat

    var body: some View {
        GeometryReader { geo in
            let p = min(max(progress, 0), 1)
            let minH: CGFloat = 56
            let maxH = max(minH + 40, geo.size.height * 0.92)
            let overshoot = max(0, progress - 1) * 60
            let height = minH + (maxH - minH) * p + overshoot

            ZStack {
                backdrop(p: p)
                VStack {
                    Spacer(minLength: 0)
                    sheet(width: geo.size.width, height: height, p: p)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func backdrop(p: CGFloat) -> some View {
        LinearGradient(
            colors: [Color(red: 0.10, green: 0.11, blue: 0.18),
                     Color(red: 0.05, green: 0.06, blue: 0.10)],
            startPoint: .top, endPoint: .bottom
        )
        .overlay(Color.black.opacity(0.35 * p)) // dim as the sheet rises
    }

    private func sheet(width: CGFloat, height: CGFloat, p: CGFloat) -> some View {
        VStack(spacing: 10) {
            Capsule()
                .fill(.white.opacity(0.35))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            ZStack {
                compactRow.opacity(Double(1 - min(p * 1.6, 1)))
                expandedGrid.opacity(Double(max(0, p * 1.6 - 0.6)))
            }
            .padding(.horizontal, 14)
            Spacer(minLength: 0)
        }
        .frame(width: width, height: height, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.13, green: 0.14, blue: 0.22))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.4), radius: 16, y: -4)
    }

    private var compactRow: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8).fill(.cyan.opacity(0.85))
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 3) {
                Capsule().fill(.white.opacity(0.8)).frame(width: 90, height: 8)
                Capsule().fill(.white.opacity(0.4)).frame(width: 56, height: 6)
            }
            Spacer()
            Image(systemName: "chevron.up").font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var expandedGrid: some View {
        let cols = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        return LazyVGrid(columns: cols, spacing: 8) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill([Color.cyan, .purple, .pink, .orange][i].opacity(0.8))
                    .frame(height: 34)
                    .overlay(
                        Image(systemName: ["star.fill", "bolt.fill", "heart.fill", "leaf.fill"][i])
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }
        }
    }
}
