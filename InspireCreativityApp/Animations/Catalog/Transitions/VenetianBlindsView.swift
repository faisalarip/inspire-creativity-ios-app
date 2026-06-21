// catalog-id: tr-venetian-blinds
import SwiftUI

// MARK: - Venetian Blinds
// Horizontal slats flip in unison on their long axis (rotation3DEffect about .x).
// As each slat turns edge-on the destination view shows through the gaps; at the
// 90-degree apex the slat's content swaps from the "old" face to the "new" face,
// then flattens back face-on to compose the next view. A directional light rake
// (brightness gradient keyed to tilt, phase-shifted per slat) sweeps the row.

public struct VenetianBlindsView: View {
    public var demo: Bool = false

    public init(demo: Bool = false) {
        self.demo = demo
    }

    public var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if demo {
            TimelineView(.animation) { timeline in
                let p = Self.loopProgress(timeline.date)
                VenetianBlindsView_BlindsStage(size: size, progress: p)
            }
        } else {
            VenetianBlindsView_InteractiveBlinds(size: size)
        }
    }

    // Triangle ping-pong 0 -> 1 -> 0 over a ~3.4s loop for the self-driving demo.
    private static func loopProgress(_ date: Date) -> Double {
        let period: Double = 3.4
        let t = date.timeIntervalSinceReferenceDate
        let phase = (t.truncatingRemainder(dividingBy: period)) / period
        // ease the triangle a touch so the swap feels less mechanical
        let tri = phase < 0.5 ? phase * 2.0 : (1.0 - phase) * 2.0
        return Self.easeInOut(tri)
    }

    private static func easeInOut(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }
}

// MARK: - Interactive (tap to flip)

private struct VenetianBlindsView_InteractiveBlinds: View {
    let size: CGSize
    @State private var flipped: Bool = false

    var body: some View {
        VenetianBlindsView_BlindsStage(size: size, progress: flipped ? 1 : 0, staggered: true)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.72)) {
                    flipped.toggle()
                }
            }
    }
}

// MARK: - Stage (shared by demo + interactive)

private struct VenetianBlindsView_BlindsStage: View {
    let size: CGSize
    let progress: Double
    var staggered: Bool = false

    private var slatCount: Int {
        // Derive from height so it works in a 120pt tile and a large detail area.
        let h = max(size.height, 1)
        let n = Int((h / 26).rounded())
        return min(max(n, 7), 13)
    }

    var body: some View {
        let count = slatCount
        let slatHeight = size.height / CGFloat(count)

        ZStack {
            // Backing destination view: ALWAYS visible through the gaps, so the
            // frame is never blank even when every slat is near edge-on.
            VenetianBlindsView_DestinationFace(size: size)

            // Soft inner vignette for depth behind the slats.
            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0, green: 0, blue: 0).opacity(0),
                                 Color(red: 0, green: 0, blue: 0).opacity(0.35)],
                        center: .center,
                        startRadius: size.height * 0.2,
                        endRadius: size.height * 0.75
                    )
                )
                .allowsHitTesting(false)

            ForEach(0..<count, id: \.self) { i in
                VenetianBlindsView_Slat(
                    index: i,
                    count: count,
                    size: size,
                    slatHeight: slatHeight,
                    progress: slatProgress(for: i, count: count)
                )
                .modifier(
                    VenetianBlindsView_StaggerAnimation(
                        enabled: staggered,
                        index: i,
                        progress: progress
                    )
                )
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    // Per-slat progress with a small index stagger so the row isn't all edge-on
    // on the same frame (drives the light-rake sweep and avoids a blank frame).
    private func slatProgress(for index: Int, count: Int) -> Double {
        guard !staggered else { return progress }
        let spread = 0.18
        let frac = count > 1 ? Double(index) / Double(count - 1) : 0
        let delay = (frac - 0.5) * spread
        return min(max(progress + delay, 0), 1)
    }
}

// In the interactive path a single `flipped` toggle drives `progress`; we apply
// a per-slat delayed spring so the flip reads as a top-to-bottom wave.
private struct VenetianBlindsView_StaggerAnimation: ViewModifier {
    let enabled: Bool
    let index: Int
    let progress: Double

    func body(content: Content) -> some View {
        if enabled {
            content.animation(
                .spring(response: 0.6, dampingFraction: 0.72)
                    .delay(Double(index) * 0.035),
                value: progress
            )
        } else {
            content
        }
    }
}

// MARK: - Single slat

private struct VenetianBlindsView_Slat: View, Animatable {
    let index: Int
    let count: Int
    let size: CGSize
    let slatHeight: CGFloat
    var progress: Double   // 0 = old face flat, 1 = new face flat

    // Make `progress` the animatable attribute so the slat's body re-evaluates
    // at every interpolated step of a withAnimation/.animation transaction.
    // Without this, an endpoint-only progress (flipped ? 1 : 0) would interpolate
    // the already-derived rotation angle (0 at both ends) and never rotate
    // edge-on — degrading the tap into a plain cross-fade.
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    // Map 0->1 progress into a 0 -> 90 -> 0 tilt. The content swaps at the apex,
    // so the slat returns to face-on but now shows the new view (no mirrored
    // back-face math required).
    private var tilt: Double {
        let half = progress <= 0.5 ? progress : (1 - progress)
        return Double(half) * 2.0 * 90.0
    }

    // How "edge-on" the slat is, 0 (flat) -> 1 (edge-on). Drives the light rake.
    private var edgeOn: Double {
        tilt / 90.0
    }

    private var showingNewFace: Bool { progress > 0.5 }

    var body: some View {
        ZStack {
            faceBand(isNew: false)
                .opacity(showingNewFace ? 0 : 1)
            faceBand(isNew: true)
                .opacity(showingNewFace ? 1 : 0)
        }
        .frame(width: size.width, height: slatHeight)
        .overlay(lightRake)
        .overlay(slatSeams)
        .compositingGroup()
        .rotation3DEffect(
            .degrees(tilt),
            axis: (x: 1, y: 0, z: 0),
            anchor: .center,
            anchorZ: 0,
            perspective: 0.7
        )
        // Foreshorten height as it tilts toward edge-on for a physical read.
        .scaleEffect(x: 1, y: CGFloat(0.18 + 0.82 * (1 - edgeOn)), anchor: .center)
        .position(
            x: size.width / 2,
            y: slatHeight * CGFloat(index) + slatHeight / 2
        )
        .zIndex(edgeOn)
    }

    // A horizontal BAND of the full source/destination view, offset so the slats
    // reconstruct the complete image when face-on (slice, not tile).
    @ViewBuilder
    private func faceBand(isNew: Bool) -> some View {
        let face = Group {
            if isNew {
                VenetianBlindsView_DestinationFace(size: size)
            } else {
                VenetianBlindsView_SourceFace(size: size)
            }
        }
        face
            .frame(width: size.width, height: size.height)
            .offset(y: -slatHeight * CGFloat(index))
            .frame(width: size.width, height: slatHeight, alignment: .top)
            .clipped()
    }

    // Directional light gradient that brightens as the slat turns edge-on, with
    // a per-index phase shift so the highlight sweeps along the row.
    private var lightRake: some View {
        let phase = count > 1 ? Double(index) / Double(count - 1) : 0
        let sweep = 0.5 + 0.5 * sin((phase + progress) * .pi * 2)
        let intensity = edgeOn * (0.35 + 0.55 * sweep)
        return LinearGradient(
            colors: [
                Color(red: 1, green: 1, blue: 1).opacity(0),
                Color(red: 1, green: 1, blue: 1).opacity(intensity),
                Color(red: 1, green: 1, blue: 1).opacity(0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .blendMode(.screen)
        .allowsHitTesting(false)
    }

    // Thin top/bottom edge shading so adjacent slats read as separate louvres.
    private var slatSeams: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(red: 1, green: 1, blue: 1).opacity(0.12 + 0.18 * edgeOn))
                .frame(height: 1)
            Spacer(minLength: 0)
            Rectangle()
                .fill(Color(red: 0, green: 0, blue: 0).opacity(0.22 + 0.28 * edgeOn))
                .frame(height: 1)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - The two faces being composed

// "Old" / source view shown before the flip.
private struct VenetianBlindsView_SourceFace: View {
    let size: CGSize

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.09, blue: 0.16),
                    Color(red: 0.16, green: 0.12, blue: 0.26),
                    Color(red: 0.06, green: 0.10, blue: 0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // a soft moon/sun disc for recognizable composition
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.95, green: 0.86, blue: 0.62),
                            Color(red: 0.85, green: 0.62, blue: 0.40).opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size.height * 0.28
                    )
                )
                .frame(width: size.height * 0.42, height: size.height * 0.42)
                .position(x: size.width * 0.72, y: size.height * 0.32)
        }
    }
}

// "New" / destination view revealed by the flip. Also the always-on backing.
private struct VenetianBlindsView_DestinationFace: View {
    let size: CGSize

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.72, blue: 0.40),
                    Color(red: 0.96, green: 0.45, blue: 0.42),
                    Color(red: 0.55, green: 0.28, blue: 0.55)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            // bright horizon glow to read clearly through the slat gaps
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1, green: 0.97, blue: 0.86).opacity(0.9),
                            Color(red: 1, green: 0.85, blue: 0.55).opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size.height * 0.35
                    )
                )
                .frame(width: size.width * 0.9, height: size.height * 0.5)
                .position(x: size.width * 0.5, y: size.height * 0.62)
        }
    }
}
