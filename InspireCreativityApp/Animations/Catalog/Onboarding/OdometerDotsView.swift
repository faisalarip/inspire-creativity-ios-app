// catalog-id: ob-odometer-dots
import SwiftUI

// MARK: - Odometer Steps
// A horizontal step counter whose current step is a mechanical split-flap tile
// that flips "01" -> "02" digit-by-digit, while surrounding dots slide along a
// rail and recolor. demo == true self-flips through the sequence on a loop;
// demo == false is driven by a horizontal swipe.
struct OdometerDotsView: View {
    var demo: Bool = false

    // Step model: indices 0...(stepCount-1). `position` is continuous so a value
    // like 1.7 means "70% through the flip from step 1 -> step 2". This single
    // source of truth feeds both the demo loop and the interactive drag.
    private let stepCount: Int = 5

    // Interactive state (only used when demo == false).
    @State private var committed: Double = 0          // last settled integer step
    @State private var dragPosition: Double = 0        // live position during/after drag

    var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if demo {
            TimelineView(.animation) { timeline in
                let pos = demoPosition(at: timeline.date)
                board(position: pos, size: size)
            }
        } else {
            board(position: dragPosition, size: size)
                .contentShape(Rectangle())
                .gesture(stepDrag(size: size))
        }
    }

    // MARK: - Demo loop driver

    // Advances one step per segment, always flipping FORWARD, and wraps the
    // last -> first as a forward flip ("05" -> "01"). `position` stays in
    // [0, stepCount); the displayed digit is modular so the wrap reads cleanly.
    private func demoPosition(at date: Date) -> Double {
        let flipDuration: Double = 0.62
        let holdDuration: Double = 0.55
        let segment = flipDuration + holdDuration
        let cycle = segment * Double(stepCount)            // full pass then wrap
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
        let index = Int(t / segment)                       // step we are leaving
        let local = t - Double(index) * segment
        let base = Double(index)
        if local <= flipDuration {
            let raw = local / flipDuration                 // 0...1 across the flip
            return base + easeInOut(raw)                   // forward into base+1
        }
        // Hold: if we just flipped off the last step, snap to 0; else hold base+1.
        return (index == stepCount - 1) ? 0 : base + 1
    }

    private func easeInOut(_ x: Double) -> Double {
        x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2
    }

    // MARK: - Interactive drag

    private func stepDrag(size: CGSize) -> some Gesture {
        let tileW = tileWidth(for: size)
        return DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Drag left = advance; map translation to fractional steps.
                let delta = Double(-value.translation.width / max(tileW, 1))
                let proposed = committed + delta
                dragPosition = clampPosition(proposed)
            }
            .onEnded { value in
                let delta = Double(-value.translation.width / max(tileW, 1))
                let predicted = Double(-value.predictedEndTranslation.width / max(tileW, 1))
                let proposed = committed + delta
                let withFlick = committed + predicted
                // Commit to the next/prev step if past the half-tile threshold or flicked.
                var target = (proposed).rounded()
                if abs(withFlick - committed) > 0.45 {
                    target = (committed + (withFlick > committed ? 1 : -1)).rounded()
                }
                target = clampPosition(target).rounded()
                committed = target
                withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
                    dragPosition = target
                }
            }
    }

    private func clampPosition(_ p: Double) -> Double {
        min(max(p, 0), Double(stepCount - 1))
    }

    // MARK: - Board layout

    @ViewBuilder
    private func board(position: Double, size: CGSize) -> some View {
        let tileH = tileHeight(for: size)
        VStack(spacing: tileH * 0.22) {
            splitFlapTile(position: position, size: size)
            dotsRail(position: position, size: size)
            label(position: position, size: size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(tileH * 0.18)
    }

    private func tileHeight(for size: CGSize) -> CGFloat {
        let byHeight = size.height * 0.46
        let byWidth = size.width * 0.40
        return max(28, min(byHeight, byWidth))
    }

    private func tileWidth(for size: CGSize) -> CGFloat {
        tileHeight(for: size) * 0.74
    }

    // MARK: - Split-flap tile

    @ViewBuilder
    private func splitFlapTile(position: Double, size: CGSize) -> some View {
        let tileH = tileHeight(for: size)
        let tileW = tileWidth(for: size)
        let fromIndex = Int(floor(position))
        let p = position - floor(position)            // 0...1 fractional flip
        // `to` is the digit appearing. When p == 0 there is no flip in progress.
        let toIndex = min(fromIndex + 1, stepCount)
        let fromDigit = stepLabel(for: fromIndex)
        let toDigit = stepLabel(for: toIndex)

        ZStack {
            // Back layers: always show a settled, legible half so the tile is
            // never blank on any frame. The top back layer shows the NEW digit
            // (revealed only after the front top flap falls away in the 1st
            // half); the bottom back layer shows the OLD digit until the landing
            // flap covers it in the 2nd half.
            VStack(spacing: 0) {
                staticHalf(digit: toDigit, edge: .top,
                           tileW: tileW, tileH: tileH)
                staticHalf(digit: fromDigit, edge: .bottom,
                           tileW: tileW, tileH: tileH)
            }
            // Falling front flaps that animate the mechanical flip.
            frontFlaps(p: p, fromDigit: fromDigit, toDigit: toDigit,
                       tileW: tileW, tileH: tileH)
            // Center seam line.
            Rectangle()
                .fill(Color(red: 0.05, green: 0.05, blue: 0.07))
                .frame(width: tileW, height: max(1, tileH * 0.012))
        }
        .frame(width: tileW, height: tileH)
        .shadow(color: Color.black.opacity(0.35), radius: tileH * 0.06, y: tileH * 0.04)
    }

    @ViewBuilder
    private func frontFlaps(p: CGFloat, fromDigit: String, toDigit: String,
                            tileW: CGFloat, tileH: CGFloat) -> some View {
        // Top flap: the old digit's TOP half rotates down and away (0 -> -90).
        let topAngle: Double = p < 0.5 ? Double(-90 * (p / 0.5)) : -90
        // Bottom flap: the new digit's BOTTOM half rises into place (90 -> 0)
        // with a slight overshoot into the seam for that mechanical snap.
        let bottomRaw: CGFloat = p < 0.5 ? 1 : (1 - (p - 0.5) / 0.5)   // 1 -> 0 in 2nd half
        let bottomAngle: Double = Double(90 * bottomRaw) + overshoot(p)

        // A VStack (not ZStack) so each flap occupies its true half: the top
        // flap sits in [0, tileH/2] and `anchor: .bottom` pivots exactly on the
        // seam; the bottom flap sits in [tileH/2, tileH] and `anchor: .top`
        // pivots on the seam — matching the back layers' VStack exactly.
        VStack(spacing: 0) {
            // Old top half falling away.
            halfFace(digit: fromDigit, edge: .top, tileW: tileW, tileH: tileH,
                     shade: 0.10 + 0.30 * min(1, CGFloat(-topAngle) / 90))
                .rotation3DEffect(.degrees(topAngle),
                                  axis: (x: 1, y: 0, z: 0),
                                  anchor: .bottom, perspective: 0.45)
                .opacity(p < 0.5 ? 1 : 0)

            // New bottom half snapping up.
            halfFace(digit: toDigit, edge: .bottom, tileW: tileW, tileH: tileH,
                     shade: 0.10 + 0.30 * min(1, bottomRaw))
                .rotation3DEffect(.degrees(bottomAngle),
                                  axis: (x: 1, y: 0, z: 0),
                                  anchor: .top, perspective: 0.45)
                .opacity(p < 0.5 ? 0 : 1)
        }
        .frame(width: tileW, height: tileH)
    }

    // A small spring-like overshoot as the bottom flap lands (only near p ~ 1).
    // `phase` is pinned to Double so the exp()/sin() calls below are unambiguous.
    private func overshoot(_ p: CGFloat) -> Double {
        guard p > 0.82 else { return 0 }
        let phase: Double = Double((p - 0.82) / 0.18)       // 0...1 over the landing
        let decay: Double = exp(-3.4 * phase)
        return -7 * decay * sin(phase * Double.pi * 2.2)    // tiny wobble past 0
    }

    // MARK: - Tile halves

    enum HalfEdge { case top, bottom }

    // A static (non-rotating) half used in the back layers.
    @ViewBuilder
    private func staticHalf(digit: String, edge: HalfEdge,
                            tileW: CGFloat, tileH: CGFloat) -> some View {
        halfFace(digit: digit, edge: edge, tileW: tileW, tileH: tileH,
                 shade: edge == .top ? 0.0 : 0.06)
    }

    // Renders one half of a tile: the full glyph is laid out at full tile height,
    // then clipped to the top or bottom half so the seam aligns perfectly.
    @ViewBuilder
    private func halfFace(digit: String, edge: HalfEdge,
                          tileW: CGFloat, tileH: CGFloat, shade: CGFloat) -> some View {
        let alignment: Alignment = edge == .top ? .top : .bottom
        let corners = roundedHalf(edge: edge, radius: tileH * 0.14)
        ZStack {
            corners
                .fill(tileGradient(shade: shade))
            digitText(digit, tileH: tileH)
                .frame(width: tileW, height: tileH)
                .frame(width: tileW, height: tileH / 2, alignment: alignment)
                .clipped()
        }
        .frame(width: tileW, height: tileH / 2)
        .clipShape(corners)
        .overlay(
            corners.stroke(Color(red: 0.0, green: 0.0, blue: 0.0).opacity(0.25),
                           lineWidth: 0.5)
        )
    }

    private func tileGradient(shade: CGFloat) -> LinearGradient {
        let base = 0.16
        return LinearGradient(
            colors: [
                Color(red: base + 0.05, green: base + 0.06, blue: base + 0.09),
                Color(red: max(0, base - Double(shade)),
                      green: max(0, base + 0.01 - Double(shade)),
                      blue: max(0, base + 0.04 - Double(shade)))
            ],
            startPoint: .top, endPoint: .bottom)
    }

    private func roundedHalf(edge: HalfEdge, radius: CGFloat) -> UnevenRoundedRectangle {
        switch edge {
        case .top:
            return UnevenRoundedRectangle(topLeadingRadius: radius,
                                          bottomLeadingRadius: 0,
                                          bottomTrailingRadius: 0,
                                          topTrailingRadius: radius)
        case .bottom:
            return UnevenRoundedRectangle(topLeadingRadius: 0,
                                          bottomLeadingRadius: radius,
                                          bottomTrailingRadius: radius,
                                          topTrailingRadius: 0)
        }
    }

    @ViewBuilder
    private func digitText(_ value: String, tileH: CGFloat) -> some View {
        Text(value)
            .font(.system(size: tileH * 0.62, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(
                LinearGradient(colors: [
                    Color(red: 0.98, green: 0.97, blue: 0.94),
                    Color(red: 0.82, green: 0.83, blue: 0.88)
                ], startPoint: .top, endPoint: .bottom)
            )
            .minimumScaleFactor(0.4)
            .lineLimit(1)
    }

    // MARK: - Dots rail

    @ViewBuilder
    private func dotsRail(position: Double, size: CGSize) -> some View {
        let tileH = tileHeight(for: size)
        let dot = max(6, tileH * 0.16)
        let spacing = dot * 1.6
        let active = position
        ZStack {
            Capsule()
                .fill(Color(red: 0.16, green: 0.15, blue: 0.20))
                .frame(height: max(3, dot * 0.42))
            HStack(spacing: spacing) {
                ForEach(0..<stepCount, id: \.self) { i in
                    dotView(index: i, active: active, dot: dot)
                }
            }
        }
        .frame(height: dot * 1.6)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func dotView(index i: Int, active: Double, dot: CGFloat) -> some View {
        let distance = abs(Double(i) - active)
        let nearness = max(0, 1 - distance)                // 1 at the active step
        let scale = 1.0 + 0.65 * nearness
        let on = Color(red: 0.55, green: 0.42, blue: 0.95)
        let fill = blendActive(t: CGFloat(nearness))
        Circle()
            .fill(fill)
            .frame(width: dot, height: dot)
            .scaleEffect(scale)
            .overlay(
                Circle()
                    .stroke(on.opacity(nearness), lineWidth: dot * 0.12)
                    .scaleEffect(scale + CGFloat(nearness) * 0.5)
                    .opacity(nearness * 0.6)
            )
            .shadow(color: on.opacity(nearness * 0.7),
                    radius: dot * 0.5 * CGFloat(nearness))
    }

    // Interpolates the dot fill between the inactive grey and the active violet
    // using known literal components (no UIColor round-trip, fully SwiftUI).
    private func blendActive(t: CGFloat) -> Color {
        let off: (Double, Double, Double) = (0.34, 0.33, 0.42)
        let on: (Double, Double, Double) = (0.55, 0.42, 0.95)
        let k = Double(min(max(t, 0), 1))
        return Color(red: off.0 + (on.0 - off.0) * k,
                     green: off.1 + (on.1 - off.1) * k,
                     blue: off.2 + (on.2 - off.2) * k)
    }

    // MARK: - Caption label

    @ViewBuilder
    private func label(position: Double, size: CGSize) -> some View {
        let tileH = tileHeight(for: size)
        // Modular so the wrap segment (position ~ stepCount) reads "1" not "6".
        let current = (Int(position.rounded()) % stepCount) + 1
        HStack(spacing: 4) {
            Text("STEP")
                .font(.system(size: tileH * 0.16, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.62, green: 0.60, blue: 0.70))
            Text("\(current)")
                .font(.system(size: tileH * 0.18, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.86, green: 0.84, blue: 0.94))
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: current)
            Text("OF \(stepCount)")
                .font(.system(size: tileH * 0.16, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.62, green: 0.60, blue: 0.70))
        }
        .tracking(1.2)
        .minimumScaleFactor(0.5)
        .lineLimit(1)
    }

    // MARK: - Helpers

    // Two-digit zero-padded label for a step index (0 -> "01").
    private func stepLabel(for index: Int) -> String {
        let n = (index % stepCount) + 1
        return String(format: "%02d", n)
    }
}
