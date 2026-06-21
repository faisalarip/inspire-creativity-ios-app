// catalog-id: nav-flipboard-segment
import SwiftUI

// MARK: - Flipboard Segment
// A segmented control whose labels are rendered as split-flap (airport board) tiles.
// Switching segments flips the old label's characters down and the new label's up
// in a staggered per-tile cascade with a small mechanical overshoot.
//
// demo == true  -> a PhaseAnimator steps the selected segment on a ~3s dwell so the
//                  board keeps clattering through label changes with no touch.
// demo == false -> tap a segment tab to select it; the change re-fires every tile's
//                  KeyframeAnimator with an index-based stagger.

struct FlipboardSegmentView: View {
    var demo: Bool = false

    // The segment labels. Kept short (<= 8 chars) per the mechanism's perf note.
    private let segments: [String] = ["HOME", "INBOX", "ALERTS"]

    @State private var selectedIndex: Int = 0

    // Stable tile count for the whole board: the widest label. Keeping the tile
    // count fixed means each tile flips in place across swaps (stable identity)
    // instead of tiles being added/removed.
    private var tileCount: Int {
        max(segments.map { $0.count }.max() ?? 1, 1)
    }

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
            demoBoard(in: size)
        } else {
            interactiveBoard(in: size)
        }
    }

    // MARK: Demo (self-driving)

    @ViewBuilder
    private func demoBoard(in size: CGSize) -> some View {
        // The no-trigger PhaseAnimator cycles continuously through the phases
        // (0,1,2,0,1,2,...). Each step bumps the label the tiles render and thus
        // their changeID, re-firing the flip cascade. The dwell is controlled by
        // the per-phase animation's .delay.
        PhaseAnimator(Array(segments.indices)) { phaseIndex in
            board(label: segments[phaseIndex],
                  size: size,
                  tabs: tabStrip(active: phaseIndex, tappable: false))
        } animation: { _ in
            // ~3s dwell on each label before stepping to the next.
            .easeInOut(duration: 0.01).delay(3.0)
        }
    }

    // MARK: Interactive (tap-driven)

    @ViewBuilder
    private func interactiveBoard(in size: CGSize) -> some View {
        board(label: segments[selectedIndex],
              size: size,
              tabs: tabStrip(active: selectedIndex, tappable: true))
    }

    // MARK: Shared board layout

    @ViewBuilder
    private func board(label: String, size: CGSize, tabs: some View) -> some View {
        let board = boardMetrics(in: size)

        VStack(spacing: board.gap) {
            FlipboardSegmentView_FlipLabel(text: label,
                      tileCount: tileCount,
                      tileWidth: board.tileWidth,
                      tileHeight: board.tileHeight,
                      spacing: board.tileSpacing)
                .frame(height: board.tileHeight)
            tabs
                .frame(height: board.tabHeight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(board.outerPadding)
        .background(boardBackground(corner: board.boardCorner))
    }

    private func tabStrip(active: Int, tappable: Bool) -> some View {
        HStack(spacing: 6) {
            ForEach(segments.indices, id: \.self) { idx in
                FlipboardSegmentView_SegmentTab(title: segments[idx],
                           isActive: idx == active)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard tappable else { return }
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedIndex = idx
                        }
                    }
            }
        }
    }

    private func boardBackground(corner: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.06, green: 0.08, blue: 0.10),
                        Color(red: 0.03, green: 0.04, blue: 0.06)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    // MARK: Metrics

    struct BoardMetrics {
        var tileWidth: CGFloat
        var tileHeight: CGFloat
        var tileSpacing: CGFloat
        var gap: CGFloat
        var tabHeight: CGFloat
        var outerPadding: CGFloat
        var boardCorner: CGFloat
    }

    private func boardMetrics(in size: CGSize) -> BoardMetrics {
        let minSide: CGFloat = max(40, min(size.width, size.height))
        let maxChars: CGFloat = CGFloat(tileCount)

        // Fit the widest label horizontally with a little breathing room.
        let usableWidth: CGFloat = max(20, size.width * 0.92)
        let perChar: CGFloat = usableWidth / max(1, maxChars)
        var tileWidth: CGFloat = min(perChar * 0.82, minSide * 0.20)
        tileWidth = max(8, tileWidth)
        let tileHeight: CGFloat = tileWidth * 1.45

        return BoardMetrics(
            tileWidth: tileWidth,
            tileHeight: tileHeight,
            tileSpacing: max(1.5, tileWidth * 0.10),
            gap: max(6, minSide * 0.08),
            tabHeight: max(14, minSide * 0.16),
            outerPadding: max(6, minSide * 0.06),
            boardCorner: max(8, minSide * 0.10)
        )
    }
}

// MARK: - Flip Label

/// A fixed-width row of flip tiles. Pads to the widest segment so tile identity
/// (and therefore each tile's previous/current glyph) stays stable across swaps.
private struct FlipboardSegmentView_FlipLabel: View {
    let text: String
    let tileCount: Int
    let tileWidth: CGFloat
    let tileHeight: CGFloat
    let spacing: CGFloat

    private var characters: [Character] {
        Array(text.uppercased())
    }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<max(tileCount, 1), id: \.self) { i in
                FlipboardSegmentView_FlipTile(
                    char: glyph(at: i),
                    index: i,
                    tileWidth: tileWidth,
                    tileHeight: tileHeight
                )
            }
        }
    }

    private func glyph(at i: Int) -> Character {
        guard i >= 0, i < characters.count else { return " " }
        return characters[i]
    }
}

// MARK: - Flip Tile

/// One split-flap character cell.
///
/// Layering (back -> front):
///   1. static upper  = NEW char top half   (revealed as the falling flap drops)
///   2. static lower  = OLD char bottom half (covered as the rising flap closes)
///   3. falling flap  = OLD char top half    (anchor .bottom, 0 -> -90 over p 0..0.5)
///   4. rising flap   = NEW char bottom half  (anchor .top,   90 -> 0 over p 0.5..1)
///
/// Driven by a single `progress` 0->1 per swap. The KeyframeAnimator replays on every
/// `changeID` change (and once on appear). A leading hold bakes in the per-tile stagger,
/// and a spring overshoot on the rising flap's final track gives the mechanical bounce.
private struct FlipboardSegmentView_FlipTile: View {
    let char: Character
    let index: Int
    let tileWidth: CGFloat
    let tileHeight: CGFloat

    // Track the glyph across changes so the animation has both OLD and NEW.
    @State private var oldChar: Character
    @State private var newChar: Character
    @State private var changeID: Int = 0

    init(char: Character, index: Int, tileWidth: CGFloat, tileHeight: CGFloat) {
        self.char = char
        self.index = index
        self.tileWidth = tileWidth
        self.tileHeight = tileHeight
        // Start settled: old == new so the opening replay does not flip to garbage.
        _oldChar = State(initialValue: char)
        _newChar = State(initialValue: char)
    }

    private var halfHeight: CGFloat { tileHeight / 2 }
    private var stagger: Double { Double(index) * 0.09 }
    private var flipDuration: Double { 0.42 }

    var body: some View {
        KeyframeAnimator(initialValue: 0.0, trigger: changeID) { progress in
            tileBody(progress: progress)
        } keyframes: { _ in
            // Leading hold = per-tile stagger (KeyframeAnimator has no .delay()).
            KeyframeTrack(\.self) {
                LinearKeyframe(0.0, duration: stagger)
                // Top flap falls 0 -> -90.
                CubicKeyframe(0.5, duration: flipDuration * 0.5)
                // Bottom flap rises 90 -> 0 with a touch of spring bounce on landing.
                SpringKeyframe(1.0, duration: flipDuration * 0.5,
                               spring: .init(response: 0.28, dampingRatio: 0.55))
            }
        }
        .frame(width: tileWidth, height: tileHeight)
        .onChange(of: char) { _, newValue in
            guard newValue != newChar else { return }
            oldChar = newChar
            newChar = newValue
            changeID &+= 1
        }
    }

    // MARK: Composition

    private func tileBody(progress p: Double) -> some View {
        let a = angles(p)
        return ZStack {
            // 1. static upper: NEW top half
            staticHalf(char: newChar, isTop: true)

            // 2. static lower: OLD bottom half
            staticHalf(char: oldChar, isTop: false)

            // 3. falling flap: OLD top half (front, occludes NEW top until it drops)
            flap(char: oldChar, isTop: true, angle: a.top)

            // 4. rising flap: NEW bottom half (front, closes over OLD bottom)
            flap(char: newChar, isTop: false, angle: a.bottom)
        }
        .frame(width: tileWidth, height: tileHeight)
        .background(tileShell)
        .clipShape(RoundedRectangle(cornerRadius: tileWidth * 0.16, style: .continuous))
        .overlay(hingeLine)
    }

    /// Top flap: 0 -> -90 over p in 0..0.5, then parked at -90 (edge-on, invisible).
    /// Bottom flap: parked at 90 (edge-on) over 0..0.5, then 90 -> 0 over 0.5..1.
    private func angles(_ p: Double) -> (top: Double, bottom: Double) {
        let topAngle: Double
        let bottomAngle: Double
        if p <= 0.5 {
            let t = p / 0.5
            topAngle = -90.0 * t
            bottomAngle = 90.0
        } else {
            let t = (p - 0.5) / 0.5
            topAngle = -90.0
            bottomAngle = 90.0 * (1.0 - t)
        }
        return (topAngle, bottomAngle)
    }

    // MARK: Halves

    /// A static (non-rotating) half of a glyph cell.
    private func staticHalf(char: Character, isTop: Bool) -> some View {
        halfGlyph(char: char, isTop: isTop)
            .frame(width: tileWidth, height: tileHeight, alignment: isTop ? .top : .bottom)
    }

    /// A hinged flap holding one half of a glyph, rotated about its hinge edge.
    private func flap(char: Character, isTop: Bool, angle: Double) -> some View {
        halfGlyph(char: char, isTop: isTop)
            .frame(width: tileWidth, height: tileHeight, alignment: isTop ? .top : .bottom)
            .rotation3DEffect(
                .degrees(angle),
                axis: (x: 1, y: 0, z: 0),
                anchor: isTop ? .bottom : .top,
                anchorZ: 0,
                perspective: 0.55
            )
    }

    /// One half of a full-size glyph, clipped to the top or bottom of the cell,
    /// with a subtle vertical shade so the hinge catches light.
    private func halfGlyph(char: Character, isTop: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: tileWidth * 0.16, style: .continuous)
                .fill(panelGradient(isTop: isTop))

            Text(String(char))
                .font(.system(size: tileHeight * 0.62, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundColor(Color(red: 0.92, green: 0.95, blue: 0.98))
                .frame(width: tileWidth, height: tileHeight)
        }
        .frame(width: tileWidth, height: tileHeight, alignment: .center)
        // Show only the top or bottom half of the full-size composition.
        .frame(height: halfHeight, alignment: isTop ? .top : .bottom)
        .clipped()
    }

    // MARK: Decoration

    private func panelGradient(isTop: Bool) -> LinearGradient {
        let top = Color(red: 0.16, green: 0.18, blue: 0.21)
        let bottom = Color(red: 0.10, green: 0.11, blue: 0.13)
        return LinearGradient(
            colors: isTop ? [top, bottom] : [bottom, Color(red: 0.07, green: 0.08, blue: 0.10)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var tileShell: some View {
        RoundedRectangle(cornerRadius: tileWidth * 0.16, style: .continuous)
            .fill(Color(red: 0.05, green: 0.06, blue: 0.07))
    }

    private var hingeLine: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Rectangle()
                .fill(Color.black.opacity(0.55))
                .frame(height: max(0.75, tileHeight * 0.02))
            Spacer(minLength: 0)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Segment Tab

private struct FlipboardSegmentView_SegmentTab: View {
    let title: String
    let isActive: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundColor(isActive
                              ? Color(red: 0.05, green: 0.06, blue: 0.08)
                              : Color(red: 0.62, green: 0.66, blue: 0.72))
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isActive
                          ? Color(red: 0.96, green: 0.78, blue: 0.30)
                          : Color(red: 0.12, green: 0.14, blue: 0.17))
            )
    }
}
