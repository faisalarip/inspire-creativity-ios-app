// catalog-id: btn-tear-perforation
import SwiftUI

// MARK: - TearPerforationView
//
// Swipe along the dotted perforation to rip the button like a coupon stub.
// The torn edge frays with jagged paper detail and a widening gap reveals the
// action underneath. Past threshold the stub detaches and flutters away.
//
// demo == true  -> self-driving TimelineView loop (tear -> flutter -> reform)
// demo == false -> real DragGesture along the perforation seam
//
// Pure SwiftUI, iOS 17. No app dependencies.

struct TearPerforationView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            content(size: geo.size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(size: CGSize) -> some View {
        if demo {
            TearPerforationView_DemoDriver(size: size)
        } else {
            TearPerforationView_InteractiveDriver(size: size)
        }
    }
}

// MARK: - Palette (Color literals only)

private enum TearPerforationView_TearPalette {
    // Warm paper / coupon stub
    static let paperTop = Color(red: 0.98, green: 0.95, blue: 0.88)
    static let paperBottom = Color(red: 0.93, green: 0.88, blue: 0.78)
    static let paperEdge = Color(red: 0.80, green: 0.71, blue: 0.56)
    static let ink = Color(red: 0.24, green: 0.20, blue: 0.14)
    static let perforation = Color(red: 0.55, green: 0.47, blue: 0.36)

    // Revealed action underneath (confirmed / go state)
    static let revealTop = Color(red: 0.16, green: 0.62, blue: 0.42)
    static let revealBottom = Color(red: 0.09, green: 0.45, blue: 0.30)
    static let revealText = Color(red: 0.97, green: 0.99, blue: 0.96)
    static let frayShadow = Color(red: 0.62, green: 0.52, blue: 0.38)
}

// MARK: - Jagged tear edge (Animatable Shape)
//
// A vertical ragged line that lives at a *fixed* perforation x.
// `progress` (0...1) does NOT move the seam sideways; it controls how far the
// paper has receded from that seam, which is what reveals the layer beneath.
//
// `side`:
//   .body  -> fills the region to the LEFT of (seam - recession). As progress
//             rises the right ragged edge pulls back toward the left.
//   .stub  -> fills the region to the RIGHT of (seam + recession). As progress
//             rises the left ragged edge peels rightward.
//
// The ragged offsets come from `jitter(_:)` — a pure deterministic hash — so the
// silhouette is identical on every redraw and never strobes (the named risk).
// Both shapes read the SAME jitter for the shared seam, keeping them complementary.

private struct TearPerforationView_TearEdgeShape: Shape {
    enum Side { case body, stub }

    var progress: CGFloat
    let side: Side
    let seamFraction: CGFloat   // 0...1 position of the perforation across width
    let segments: Int           // number of ragged teeth down the height

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let clamped = max(0, min(1, progress))
        let seamX = rect.minX + seamFraction * rect.width

        // How far the paper recedes from the seam at full tear, per side.
        let maxRecession = rect.width * 0.42
        let recession = maxRecession * clamped

        // Ragged amplitude: a touch larger as the tear opens (fresh fibers).
        let baseAmp = rect.width * 0.045
        let amp = baseAmp + rect.width * 0.02 * clamped

        var path = Path()
        let n = max(2, segments)

        switch side {
        case .body:
            let edgeX = seamX - recession
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            // Down the ragged right edge.
            for i in 0...n {
                let t = CGFloat(i) / CGFloat(n)
                let y = rect.minY + t * rect.height
                let offset = (jitter(i) - 0.5) * 2 * amp
                path.addLine(to: CGPoint(x: edgeX + offset, y: y))
            }
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()

        case .stub:
            let edgeX = seamX + recession
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            // Down the ragged left edge — same jitter so it mirrors the seam.
            for i in 0...n {
                let t = CGFloat(i) / CGFloat(n)
                let y = rect.minY + t * rect.height
                let offset = (jitter(i) - 0.5) * 2 * amp
                path.addLine(to: CGPoint(x: edgeX + offset, y: y))
            }
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }

    // Deterministic pseudo-random in 0...1. Stable per segment index, no @State,
    // never re-rolls across frames or re-inits.
    private func jitter(_ i: Int) -> CGFloat {
        let v = sin(Double(i) * 12.9898 + 4.123) * 43758.5453
        return CGFloat(v - v.rounded(.down))
    }
}

// MARK: - Shared visual constants

private enum TearPerforationView_TearLayout {
    static let seamFraction: CGFloat = 0.46
    static let detachThreshold: CGFloat = 0.6
    static let segments = 22
}

// MARK: - Revealed action (always opaque -> guarantees no blank frame)

private struct TearPerforationView_RevealLayer: View {
    let size: CGSize

    var body: some View {
        let corner = size.height * 0.22
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [TearPerforationView_TearPalette.revealTop, TearPerforationView_TearPalette.revealBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            Label(title: { Text("Confirmed") }, icon: { Image(systemName: "checkmark") })
                .labelStyle(.titleAndIcon)
                .font(.system(size: max(11, size.height * 0.24), weight: .bold, design: .rounded))
                .foregroundStyle(TearPerforationView_TearPalette.revealText)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(.horizontal, size.width * 0.06)
        }
    }
}

// MARK: - Paper face (used for both body and stub halves)

private struct TearPerforationView_PaperFace: View {
    let size: CGSize

    var body: some View {
        let corner = size.height * 0.22
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [TearPerforationView_TearPalette.paperTop, TearPerforationView_TearPalette.paperBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(TearPerforationView_TearPalette.paperEdge.opacity(0.6), lineWidth: 1)

            Text("RIP TO REDEEM")
                .font(.system(size: max(9, size.height * 0.16), weight: .heavy, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(TearPerforationView_TearPalette.ink)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .padding(.horizontal, size.width * 0.05)
        }
    }
}

// MARK: - Dotted perforation affordance (rides the fixed seam)

private struct TearPerforationView_PerforationLine: View {
    let size: CGSize
    let progress: CGFloat

    var body: some View {
        let x = TearPerforationView_TearLayout.seamFraction * size.width
        Path { p in
            p.move(to: CGPoint(x: x, y: size.height * 0.06))
            p.addLine(to: CGPoint(x: x, y: size.height * 0.94))
        }
        .stroke(
            TearPerforationView_TearPalette.perforation,
            style: StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [2.5, 4])
        )
        // Fades as the tear opens — it has "given way".
        .opacity(Double(1 - min(1, progress * 1.4)))
    }
}

// MARK: - Composited torn button (geometry-only; reused by both drivers)

private struct TearPerforationView_TornButton: View {
    let size: CGSize
    let progress: CGFloat   // 0...1 tear amount

    var body: some View {
        let p = max(0, min(1, progress))
        ZStack {
            // Bottom: the revealed action — always opaque, always legible.
            TearPerforationView_RevealLayer(size: size)

            // Body half: clipped to the receding left region.
            TearPerforationView_PaperFace(size: size)
                .overlay(frayHighlight(side: .body))
                .clipShape(
                    TearPerforationView_TearEdgeShape(
                        progress: p,
                        side: .body,
                        seamFraction: TearPerforationView_TearLayout.seamFraction,
                        segments: TearPerforationView_TearLayout.segments
                    )
                )
                .shadow(color: TearPerforationView_TearPalette.frayShadow.opacity(0.5 * Double(p)),
                        radius: 3, x: 3, y: 0)

            // Stub half: clipped to the right region, then flies off past threshold.
            stubView(p: p)

            // Dotted perforation affordance over the closed seam.
            TearPerforationView_PerforationLine(size: size, progress: p)
        }
        .compositingGroup()
    }

    @ViewBuilder
    private func stubView(p: CGFloat) -> some View {
        let detached = max(0, (p - TearPerforationView_TearLayout.detachThreshold) / (1 - TearPerforationView_TearLayout.detachThreshold))
        let flyX = size.width * 0.85 * detached
        let flyY = size.height * 0.55 * detached * detached
        let rot = Angle(degrees: Double(detached) * 26)
        let fade = 1 - Double(detached) * 0.85

        TearPerforationView_PaperFace(size: size)
            .overlay(frayHighlight(side: .stub))
            .clipShape(
                TearPerforationView_TearEdgeShape(
                    progress: p,
                    side: .stub,
                    seamFraction: TearPerforationView_TearLayout.seamFraction,
                    segments: TearPerforationView_TearLayout.segments
                )
            )
            .rotationEffect(rot, anchor: .bottomTrailing)
            .offset(x: flyX, y: flyY)
            .opacity(fade)
            .shadow(color: TearPerforationView_TearPalette.frayShadow.opacity(0.45 * Double(detached)),
                    radius: 4, x: -2, y: 4)
    }

    // A soft warm highlight hugging the torn edge to fake exposed paper fibers.
    @ViewBuilder
    private func frayHighlight(side: TearPerforationView_TearEdgeShape.Side) -> some View {
        let seamX = TearPerforationView_TearLayout.seamFraction * size.width
        let recede = size.width * 0.42 * max(0, min(1, progress))
        let center: CGFloat = side == .body ? (seamX - recede) : (seamX + recede)
        RadialGradient(
            colors: [TearPerforationView_TearPalette.frayShadow.opacity(0.55), .clear],
            center: UnitPoint(x: center / max(1, size.width), y: 0.5),
            startRadius: 0,
            endRadius: size.width * 0.18
        )
        .allowsHitTesting(false)
    }
}

// MARK: - Demo driver (self-running loop, never blank, no haptics)

private struct TearPerforationView_DemoDriver: View {
    let size: CGSize

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            TearPerforationView_TornButton(size: size, progress: Self.loopProgress(t))
        }
    }

    // ~3.4s cycle: ease the tear open 0->1, hold detached briefly, ease reform.
    static func loopProgress(_ time: TimeInterval) -> CGFloat {
        let period: TimeInterval = 3.4
        let phase = (time.truncatingRemainder(dividingBy: period)) / period // 0..1

        if phase < 0.45 {
            // tear open
            let u = phase / 0.45
            return easeInOut(CGFloat(u))
        } else if phase < 0.62 {
            // hold fully torn (stub flutters away)
            return 1
        } else {
            // ease back to whole (paper reforms)
            let u = (phase - 0.62) / 0.38
            return 1 - easeInOut(CGFloat(u))
        }
    }

    private static func easeInOut(_ x: CGFloat) -> CGFloat {
        let c = max(0, min(1, x))
        return c * c * (3 - 2 * c)
    }
}

// MARK: - Interactive driver (real DragGesture + gated haptic)

private struct TearPerforationView_InteractiveDriver: View {
    let size: CGSize

    @State private var committed: CGFloat = 0      // resting / settled tear amount
    @State private var live: CGFloat = 0           // live drag delta contribution
    @State private var impactTrigger: Int = 0      // stored Equatable for haptic

    var body: some View {
        let progress = max(0, min(1, committed + live))

        TearPerforationView_TornButton(size: size, progress: progress)
            .contentShape(Rectangle())
            .gesture(dragGesture())
            .sensoryFeedback(.impact(weight: .medium), trigger: impactTrigger)
    }

    private func dragGesture() -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Map horizontal drag distance to tear progress, relative to width
                // so it feels right in both a 120pt tile and a large detail view.
                let span = size.width * 0.65
                live = max(-committed, min(1 - committed, value.translation.width / max(1, span)))
            }
            .onEnded { _ in
                let final = max(0, min(1, committed + live))
                live = 0
                // Animate both the detach (committed 0->1) AND the snap-back from a
                // partial tear. Wrapping the resets in withAnimation guarantees the
                // spring fires even when `committed` does not change value (e.g. a
                // partial drag that snaps back to the resting 0).
                if final >= TearPerforationView_TearLayout.detachThreshold {
                    withAnimation(.interpolatingSpring(stiffness: 170, damping: 14)) {
                        committed = 1                 // spring the stub free
                    }
                    impactTrigger += 1                // fire haptic once, on the crossing
                } else {
                    withAnimation(.interpolatingSpring(stiffness: 170, damping: 14)) {
                        committed = 0                 // snap back to whole
                    }
                }
            }
    }
}
