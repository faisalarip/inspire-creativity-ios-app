// catalog-id: ld-flip-clock-progress
import SwiftUI

// Flip-Clock Counter — a split-flap percentage counter (000% → 100%).
// Each digit is two stacked half-tiles. The top half hinges DOWN over the
// bottom with a 3D fold, a hinge-shadow gradient, and a damped overshoot as
// the new glyph snaps into place.
//
// Both demo==true and demo==false are auto-driven (the spec's interaction is
// "auto — same as previewLoop"): there is no gesture. demo loops 0→100→0
// forever; non-demo counts 0→100 once and holds at 100 like a real loader.
//
// Fold convention (the one render-time unknown — flip in ONE place if backward):
//   axis (1,0,0), anchor .bottom on the top flap, NEGATIVE degrees tips the
//   top edge toward the viewer and folds it down to edge-on at the seam.
//   perspective ~0.4 gives the fold depth instead of a flat vertical squash.

struct FlipClockProgressView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            TimelineView(.animation) { context in
                let count = currentCount(at: context.date)
                board(count: count, side: side)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Driver (stateless, derived from the timeline date)

    /// Continuous percentage in [0, 100], eased.
    private func currentCount(at date: Date) -> Double {
        let t = date.timeIntervalSinceReferenceDate
        if demo {
            // Loop 0→100→0 forever on a ~7s round trip with eased extremes.
            let period: Double = 7.0
            let phase = (t.truncatingRemainder(dividingBy: period)) / period // 0..1
            let triangle = phase < 0.5 ? (phase * 2.0) : (2.0 - phase * 2.0)  // 0→1→0
            return easeInOut(triangle) * 100.0
        } else {
            // Count up over ~4.5s, then hold at 100, then re-arm (real loader semantics).
            let fillDuration: Double = 4.5
            let elapsed = t.truncatingRemainder(dividingBy: fillDuration + 6.0) // long hold
            let progress = min(elapsed / fillDuration, 1.0)
            return easeOutCubic(progress) * 100.0
        }
    }

    private func easeInOut(_ x: Double) -> Double {
        x < 0.5 ? 2.0 * x * x : 1.0 - pow(-2.0 * x + 2.0, 2.0) / 2.0
    }

    private func easeOutCubic(_ x: Double) -> Double {
        1.0 - pow(1.0 - x, 3.0)
    }

    // MARK: - Board

    private func board(count: Double, side: CGFloat) -> some View {
        let digitW = side * 0.215
        let digitH = side * 0.34
        let gap = side * 0.018
        let percentW = side * 0.16

        let hundreds = digitState(count: count, place: 100.0)
        let tens = digitState(count: count, place: 10.0)
        let units = digitState(count: count, place: 1.0)

        return VStack(spacing: 0) {
            HStack(alignment: .center, spacing: gap) {
                FlipClockProgressView_FlipDigit(state: hundreds, width: digitW, height: digitH)
                FlipClockProgressView_FlipDigit(state: tens, width: digitW, height: digitH)
                FlipClockProgressView_FlipDigit(state: units, width: digitW, height: digitH)
                percentTile(width: percentW, height: digitH)
            }
            railShadow(width: digitW * 3 + percentW + gap * 3)
                .frame(height: digitH * 0.10)
        }
    }

    /// Computes the current glyph, the next glyph, and a fold weight w∈[0,1]
    /// for the digit at the given decimal place.
    private func digitState(count: Double, place: Double) -> FlipClockProgressView_DigitState {
        let scaled = count / place
        let floored = floor(scaled)
        let frac = scaled - floored                 // 0..1 progress toward next tick
        let current = Int(floored) % 10
        let next = (current + 1) % 10

        // Only fold in the tail of the fraction so the digit reads steady most
        // of the time, then snaps. Faster places (units) fold often, slower
        // places (hundreds) flip crisply — the desirable odometer look.
        let foldStart: Double = 0.78
        var w: Double = 0.0
        if frac > foldStart {
            w = (frac - foldStart) / (1.0 - foldStart)
        }
        // Above 100 there is no "next" to flip into; freeze the fold.
        let atCeiling = scaled >= 9.999 && place >= 100.0
        if atCeiling { w = 0.0 }

        return FlipClockProgressView_DigitState(current: current, next: next, fold: min(max(w, 0.0), 1.0))
    }

    // MARK: - Static tiles

    private func percentTile(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            tileBackground
            Text("%")
                .font(.system(size: height * 0.46, weight: .semibold, design: .rounded))
                .foregroundStyle(Self.glyphColor)
            seam.frame(height: 1)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: height * 0.14, style: .continuous))
    }

    private var tileBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Self.tileGradient)
    }

    private var seam: some View {
        Rectangle().fill(Color(red: 0.0, green: 0.0, blue: 0.0).opacity(0.55))
    }

    private func railShadow(width: CGFloat) -> some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [Color(red: 0, green: 0, blue: 0).opacity(0.35),
                             Color(red: 0, green: 0, blue: 0).opacity(0.0)],
                    center: .center, startRadius: 0, endRadius: width * 0.5
                )
            )
            .frame(width: width)
            .blur(radius: 2)
    }

    // MARK: - Shared palette

    static let glyphColor = Color(red: 0.93, green: 0.95, blue: 0.97)

    static let tileGradient = LinearGradient(
        colors: [Color(red: 0.13, green: 0.16, blue: 0.20),
                 Color(red: 0.07, green: 0.09, blue: 0.12)],
        startPoint: .top, endPoint: .bottom
    )
}

// MARK: - Digit state

private struct FlipClockProgressView_DigitState: Equatable {
    var current: Int
    var next: Int
    var fold: Double   // 0 = steady on `current`, 1 = fully folded to `next`
}

// MARK: - A single flapping digit

private struct FlipClockProgressView_FlipDigit: View {
    let state: FlipClockProgressView_DigitState
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            staticLayers
            if state.fold > 0.0001 {
                flaps
            }
            seamLine
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: height * 0.14, style: .continuous))
        .shadow(color: Color(red: 0, green: 0, blue: 0).opacity(0.3),
                radius: 3, x: 0, y: 2)
    }

    // Static backdrop.
    // Bottom half: always CURRENT (covered by the NEXT bottom flap as it lands,
    // then revealed once the tick increments and CURRENT becomes the new value).
    // Top half: CURRENT while resting (so a steady digit reads correctly on every
    // frame), switching to NEXT only while folding — the moment the top flap lifts
    // away it reveals NEXT behind it. Gating this on `folding` is essential: with
    // a bare NEXT here, a resting digit would show next-on-top / current-on-bottom.
    private var staticLayers: some View {
        let folding = state.fold > 0.0001
        return VStack(spacing: 0) {
            FlipClockProgressView_HalfTile(digit: folding ? state.next : state.current,
                     half: .top, width: width, height: height)
            FlipClockProgressView_HalfTile(digit: state.current, half: .bottom, width: width, height: height)
        }
    }

    // The two moving flaps. Each flap is exactly one half-tile (height/2 tall),
    // pinned to its seam edge inside the full-tile frame so the hinge anchor
    // lands on the center seam.
    private var flaps: some View {
        let w = state.fold
        // Phase 1 (w 0→0.5): top flap (CURRENT top) folds 0 → -90, anchored at bottom (seam).
        // Phase 2 (w 0.5→1): bottom flap (NEXT bottom) folds 90 → 0 with overshoot, anchored at top (seam).
        let topProgress = min(w / 0.5, 1.0)                 // 0..1
        let topAngle = -90.0 * topProgress                  // 0 → -90 (toward viewer, down)
        let topVisible = w < 0.5

        let bottomProgress = max((w - 0.5) / 0.5, 0.0)      // 0..1
        let bottomAngle = 90.0 * (1.0 - overshoot(bottomProgress)) // 90 → ~bounce → 0
        let bottomVisible = w >= 0.5

        return ZStack {
            // Top flap: shows CURRENT top, hinged at its bottom edge (the seam).
            if topVisible {
                topFlap(progress: topProgress, angle: topAngle)
            }
            // Bottom flap: shows NEXT bottom, hinged at its top edge, dropping in.
            if bottomVisible {
                bottomFlap(progress: bottomProgress, angle: bottomAngle)
            }
        }
        .frame(width: width, height: height)
    }

    // The flap is the native half-tile (height/2 tall). The rotation anchor
    // refers to the HALF-TILE's own bounds — so .bottom == the seam edge — and
    // only AFTER rotating do we pin it into the top half of the full tile.
    private func topFlap(progress: Double, angle: Double) -> some View {
        FlipClockProgressView_HalfTile(digit: state.current, half: .top, width: width, height: height)
            .overlay { hingeShade(startTop: false, opacity: progress * 0.75) }
            .rotation3DEffect(
                .degrees(angle),
                axis: (x: 1, y: 0, z: 0),
                anchor: .bottom,
                perspective: 0.4
            )
            .frame(width: width, height: height, alignment: .top)
    }

    private func bottomFlap(progress: Double, angle: Double) -> some View {
        FlipClockProgressView_HalfTile(digit: state.next, half: .bottom, width: width, height: height)
            .overlay { hingeShade(startTop: true, opacity: (1.0 - progress) * 0.75) }
            .rotation3DEffect(
                .degrees(angle),
                axis: (x: 1, y: 0, z: 0),
                anchor: .top,
                perspective: 0.4
            )
            .frame(width: width, height: height, alignment: .bottom)
    }

    // Damped-cosine landing bounce: a value that races to 1, OVERSHOOTS past it
    // (so bottomAngle = 90·(1-overshoot) swings slightly negative — the flap dips
    // below level), then settles back to 1. This is the spec's mechanical spring
    // bounce, baked into the easing curve since a frame-computed TimelineView
    // can't fire a real .spring().
    private func overshoot(_ p: Double) -> Double {
        if p >= 1.0 { return 1.0 }
        let decay = exp(-5.0 * p)
        return 1.0 - decay * cos(6.0 * p)
    }

    private var seamLine: some View {
        Rectangle()
            .fill(Color(red: 0, green: 0, blue: 0).opacity(0.55))
            .frame(height: 1)
    }

    // Hinge shadow: darkens the flap toward the seam edge as it folds, then
    // lifts as it lands. `startTop == true` darkens the top edge (bottom flap),
    // false darkens the bottom edge (top flap).
    private func hingeShade(startTop: Bool, opacity: Double) -> some View {
        LinearGradient(
            colors: [Color(red: 0, green: 0, blue: 0).opacity(opacity),
                     Color(red: 0, green: 0, blue: 0).opacity(0.0)],
            startPoint: startTop ? .top : .bottom,
            endPoint: startTop ? .bottom : .top
        )
    }
}

// MARK: - Half tile (top or bottom clip of a glyph)

private enum FlipClockProgressView_TileHalf { case top, bottom }

private struct FlipClockProgressView_HalfTile: View {
    let digit: Int
    let half: FlipClockProgressView_TileHalf
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .fill(FlipClockProgressView.tileGradient)
            // Glyph centered in the FULL tile, then the half is cropped.
            Text(String(digit))
                .font(.system(size: height * 0.62, weight: .semibold, design: .rounded))
                .foregroundStyle(FlipClockProgressView.glyphColor)
                .frame(width: width, height: height)
            // A subtle top-edge highlight on the upper half for the curved plastic look.
            if half == .top {
                LinearGradient(
                    colors: [Color(red: 1, green: 1, blue: 1).opacity(0.10),
                             Color(red: 1, green: 1, blue: 1).opacity(0.0)],
                    startPoint: .top, endPoint: .bottom
                )
            }
        }
        // Crop to the requested half: pin the full-size content to top/bottom,
        // shrink the frame to half-height, then clip. (Clip lives INSIDE the
        // half-tile; rotation is applied later in the assembly — never after clip.)
        .frame(width: width, height: height, alignment: half == .top ? .top : .bottom)
        .frame(width: width, height: height / 2.0,
               alignment: half == .top ? .top : .bottom)
        .clipped()
    }
}
