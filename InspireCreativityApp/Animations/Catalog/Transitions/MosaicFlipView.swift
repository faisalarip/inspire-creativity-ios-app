// catalog-id: tr-mosaic-flip
import SwiftUI

// MARK: - Mosaic Tile Flip
// A 2D grid of tiles flips in a diagonal wave, each tile rotating on
// rotation3DEffect about .y and swapping its face from the old view to the new
// one at 90 degrees, like a split-flap departures board reshuffling.
//
// Demo: a TimelineView(.animation) drives a continuous triangle progress so the
// staggered per-tile localProgress is live every frame and the wave renders.
// Interactive: a tap toggles `flipped`; every tile springs from its OWN delayed
// .animation keyed to (row+col), which is what produces the diagonal wave (not a
// single shared withAnimation, which would flip everything in unison).

struct MosaicFlipView: View {
    var demo: Bool = false

    private let rows: Int = 5
    private let cols: Int = 6

    var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if demo {
            demoBody(in: size)
        } else {
            interactiveBody(in: size)
        }
    }

    // MARK: Demo (self-driving, no touch)

    private func demoBody(in size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let progress: Double = triangleProgress(at: timeline.date)
            grid(in: size, globalProgress: progress, flipped: nil)
        }
    }

    // Continuous 0 -> 1 -> 0 triangle over `period` seconds. A triangle (not a
    // sawtooth) avoids a hard snap-reverse at the loop point so the wave breathes.
    private func triangleProgress(at date: Date) -> Double {
        let period: Double = 3.6
        let t: Double = date.timeIntervalSinceReferenceDate
        let phase: Double = (t.truncatingRemainder(dividingBy: period)) / period
        return phase < 0.5 ? phase * 2.0 : (1.0 - phase) * 2.0
    }

    // MARK: Interactive (tap to flip the wave)

    private func interactiveBody(in size: CGSize) -> some View {
        MosaicFlipView_InteractiveMosaic { flipped in
            grid(in: size, globalProgress: flipped ? 1.0 : 0.0, flipped: flipped)
        }
    }

    // MARK: Shared grid

    // `flipped` is nil in demo (value is already live per-frame, no per-tile
    // animation needed) and a Bool in interactive (drives each tile's own
    // staggered spring).
    private func grid(in size: CGSize, globalProgress: Double, flipped: Bool?) -> some View {
        let inset: CGFloat = max(4, min(size.width, size.height) * 0.05)
        let boardW: CGFloat = max(1, size.width - inset * 2)
        let boardH: CGFloat = max(1, size.height - inset * 2)
        let tileW: CGFloat = boardW / CGFloat(cols)
        let tileH: CGFloat = boardH / CGFloat(rows)
        let maxDiag: Double = Double((rows - 1) + (cols - 1))

        return ZStack {
            backdrop
            tiles(boardW: boardW, boardH: boardH,
                  tileW: tileW, tileH: tileH,
                  maxDiag: maxDiag, globalProgress: globalProgress, flipped: flipped)
                .frame(width: boardW, height: boardH)
                .clipShape(RoundedRectangle(cornerRadius: inset, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: inset, style: .continuous)
                        .strokeBorder(Color(red: 1, green: 1, blue: 1).opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color(red: 0, green: 0, blue: 0).opacity(0.45),
                        radius: 12, x: 0, y: 8)
        }
        .frame(width: size.width, height: size.height)
    }

    private func tiles(boardW: CGFloat, boardH: CGFloat,
                       tileW: CGFloat, tileH: CGFloat,
                       maxDiag: Double, globalProgress: Double, flipped: Bool?) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<rows, id: \.self) { row in
                ForEach(0..<cols, id: \.self) { col in
                    tile(row: row, col: col,
                         boardW: boardW, boardH: boardH,
                         tileW: tileW, tileH: tileH,
                         maxDiag: maxDiag, globalProgress: globalProgress, flipped: flipped)
                }
            }
        }
    }

    private func tile(row: Int, col: Int,
                      boardW: CGFloat, boardH: CGFloat,
                      tileW: CGFloat, tileH: CGFloat,
                      maxDiag: Double, globalProgress: Double, flipped: Bool?) -> some View {
        // Demo: localProgress is a live per-tile value (the wave lives in the value).
        // Interactive: targetProgress is the same 0/1 for every tile; the wave lives
        // entirely in the per-tile staggered .animation delay below.
        let isInteractive: Bool = flipped != nil
        let target: Double
        if isInteractive {
            target = globalProgress
        } else {
            target = localProgress(row: row, col: col, maxDiag: maxDiag, global: globalProgress)
        }

        let anim: Animation?
        if isInteractive {
            let unit: Double = 0.06
            let delay: Double = Double(row + col) * unit
            anim = .spring(response: 0.55, dampingFraction: 0.74).delay(delay)
        } else {
            anim = nil // value is already live per-frame; suppress ambient smear.
        }

        return MosaicFlipView_MosaicTile(
            row: row, col: col,
            boardW: boardW, boardH: boardH,
            tileW: tileW, tileH: tileH,
            targetProgress: target,
            animation: anim
        )
        .frame(width: tileW, height: tileH)
        .offset(x: CGFloat(col) * tileW, y: CGFloat(row) * tileH)
    }

    // Diagonal wave: stagger each tile's local progress by (row+col), windowed so
    // the flip is shorter than the full timeline. Keeps the wave readable and
    // guarantees the board is never fully edge-on at once.
    private func localProgress(row: Int, col: Int, maxDiag: Double, global: Double) -> Double {
        let diag: Double = Double(row + col)
        let norm: Double = maxDiag > 0 ? diag / maxDiag : 0
        let window: Double = 0.55           // each tile flips over 55% of the timeline
        let spread: Double = 1.0 - window   // leading delay span
        let start: Double = norm * spread
        let raw: Double = (global - start) / window
        return min(1, max(0, raw))
    }

    private var backdrop: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.06, blue: 0.09),
                        Color(red: 0.02, green: 0.02, blue: 0.04)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .ignoresSafeArea()
    }
}

// MARK: - Interactive wrapper

private struct MosaicFlipView_InteractiveMosaic<Content: View>: View {
    @ViewBuilder var content: (Bool) -> Content

    @State private var flipped: Bool = false

    var body: some View {
        content(flipped)
            .contentShape(Rectangle())
            .onTapGesture {
                // No withAnimation here: each tile owns its delayed spring so the
                // angles fan out into a diagonal wave instead of flipping in unison.
                flipped.toggle()
            }
    }
}

// MARK: - Single flipping tile

private struct MosaicFlipView_MosaicTile: View {
    let row: Int
    let col: Int
    let boardW: CGFloat
    let boardH: CGFloat
    let tileW: CGFloat
    let tileH: CGFloat
    let targetProgress: Double      // 0 -> 1 for THIS tile
    let animation: Animation?       // non-nil => interactive (per-tile staggered spring)

    private var angle: Double { targetProgress * 180.0 }
    private var showsBack: Bool { angle >= 90.0 }

    var body: some View {
        ZStack {
            // Front face (old view) visible 0..<90.
            slice(of: MosaicFlipView_FaceA(boardW: boardW, boardH: boardH))
                .opacity(showsBack ? 0 : 1)

            // Back face (new view) visible 90..180.
            // Pre-rotated 180 about .y so the parent's mirroring at full flip
            // cancels out and the new face reassembles un-mirrored.
            slice(of: MosaicFlipView_FaceB(boardW: boardW, boardH: boardH))
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(showsBack ? 1 : 0)
        }
        .overlay(seamSheen)
        .rotation3DEffect(
            .degrees(angle),
            axis: (x: 0, y: 1, z: 0),
            anchor: .center,
            perspective: 0.55
        )
        .compositingGroup()
        .shadow(color: Color(red: 0, green: 0, blue: 0).opacity(edgeShadowOpacity),
                radius: 3, x: 0, y: 0)
        // Outermost: governs angle AND face opacities together (both derive from
        // targetProgress) so the swap stays glued to the rotation. nil in demo.
        .animation(animation, value: targetProgress)
    }

    // Edge-on tiles darken slightly for depth as they pass 90.
    private var edgeShadowOpacity: Double {
        let t: Double = abs(sin(angle * .pi / 180.0))   // peaks at 90
        return 0.05 + t * 0.35
    }

    // A thin specular line + edge shading that rakes as the tile turns.
    private var seamSheen: some View {
        let t: Double = abs(sin(angle * .pi / 180.0))
        return Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 1, green: 1, blue: 1).opacity(0.0),
                        Color(red: 1, green: 1, blue: 1).opacity(0.22 * t),
                        Color(red: 0, green: 0, blue: 0).opacity(0.30 * t)
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }

    // Crop tile (row,col) out of a full-bleed face. Offset BEFORE the clipping
    // frame, top-leading alignment, so tiles reassemble seamlessly.
    private func slice<F: View>(of face: F) -> some View {
        face
            .frame(width: boardW, height: boardH)
            .offset(x: -CGFloat(col) * tileW, y: -CGFloat(row) * tileH)
            .frame(width: tileW, height: tileH, alignment: .topLeading)
            .clipped()
    }
}

// MARK: - Full-bleed faces (must span the whole rect so every slice is legible)

private struct MosaicFlipView_FaceA: View {
    let boardW: CGFloat
    let boardH: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.36, green: 0.20, blue: 0.62),
                    Color(red: 0.16, green: 0.10, blue: 0.42),
                    Color(red: 0.08, green: 0.06, blue: 0.24)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            // Diagonal motif so edge tiles still carry detail.
            ForEach(0..<7, id: \.self) { i in
                Capsule()
                    .fill(Color(red: 1, green: 1, blue: 1).opacity(0.06))
                    .frame(width: boardW * 1.4, height: max(6, boardH * 0.05))
                    .rotationEffect(.degrees(-30))
                    .offset(y: CGFloat(i) * boardH * 0.18 - boardH * 0.6)
            }

            RadialGradient(
                colors: [
                    Color(red: 0.95, green: 0.55, blue: 0.95).opacity(0.55),
                    Color(red: 0.95, green: 0.55, blue: 0.95).opacity(0.0)
                ],
                center: .init(x: 0.3, y: 0.3),
                startRadius: 0,
                endRadius: max(boardW, boardH) * 0.7
            )
        }
        .frame(width: boardW, height: boardH)
    }
}

private struct MosaicFlipView_FaceB: View {
    let boardW: CGFloat
    let boardH: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.55, blue: 0.58),
                    Color(red: 0.05, green: 0.32, blue: 0.55),
                    Color(red: 0.03, green: 0.14, blue: 0.30)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            // Grid motif so every slice reads as part of the new face.
            ForEach(0..<8, id: \.self) { i in
                Rectangle()
                    .fill(Color(red: 1, green: 1, blue: 1).opacity(0.05))
                    .frame(width: max(2, boardW * 0.012), height: boardH * 1.4)
                    .offset(x: CGFloat(i) * boardW * 0.14 - boardW * 0.5)
            }

            RadialGradient(
                colors: [
                    Color(red: 0.45, green: 1.0, blue: 0.85).opacity(0.55),
                    Color(red: 0.45, green: 1.0, blue: 0.85).opacity(0.0)
                ],
                center: .init(x: 0.7, y: 0.7),
                startRadius: 0,
                endRadius: max(boardW, boardH) * 0.7
            )
        }
        .frame(width: boardW, height: boardH)
    }
}
