// catalog-id: mi-day-night-toggle
import SwiftUI

// MARK: - Day-Night Toggle
// A switch that morphs a sun into a crescent moon by sliding an opaque eraser
// disc across a glowing disc (carving the crescent via destinationOut), while
// tiny stars fade in and the track crossfades from sky-blue to indigo.
//
// One scalar `progress` in [0, 1] drives every visual:
//   0 -> full day  (sun, blue sky, rays, no stars, thumb on the left)
//   1 -> full night (crescent moon, indigo sky, stars, thumb on the right)
//
// CRITICAL: every day/night transition rides on an *animatable* modifier
// (.offset / .opacity) — never on a ShapeStyle fill parameter. Gradients are
// ShapeStyles and do NOT interpolate, so each color shift is done by stacking
// two fills and crossfading the top one with .opacity(progress). This keeps
// the slide, the carve, and the color morph all in sync when SwiftUI animates
// `progress` from 0 to 1 on tap.
//
// In demo mode `progress` is driven by a raised-cosine TimelineView loop so the
// tile is always alive and legible. Interactive mode toggles `isOn` on tap and
// animates `progress` 0<->1 with .easeInOut.

public struct DayNightToggleView: View {
    var demo: Bool = false

    @State private var isOn: Bool = false

    public var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if demo {
            TimelineView(.animation) { timeline in
                DayNightToggleView_ToggleScene(progress: demoProgress(at: timeline.date), size: size)
            }
        } else {
            DayNightToggleView_ToggleScene(progress: isOn ? 1 : 0, size: size)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        isOn.toggle()
                    }
                }
                .sensoryFeedback(.selection, trigger: isOn)
        }
    }

    // Raised-cosine 0->1->0 over ~3.4s: smooth dwell at both ends, never blank.
    private func demoProgress(at date: Date) -> CGFloat {
        let period: Double = 3.4
        let t = date.timeIntervalSinceReferenceDate
        let phase = t.truncatingRemainder(dividingBy: period) / period
        return CGFloat((1 - cos(phase * 2 * .pi)) / 2)
    }
}

// MARK: - Scene

private struct DayNightToggleView_ToggleScene: View {
    var progress: CGFloat
    var size: CGSize

    private var unit: CGFloat {
        // Toggle height; clamp so we never produce NaN on first layout.
        let byHeight = size.height * 0.42
        let byWidth = size.width / 2.1
        return max(8, min(byHeight, byWidth))
    }

    var body: some View {
        let trackH = unit
        let trackW = unit * 1.85
        let pad = trackH * 0.12
        let diameter = trackH - pad * 2
        let travel = trackW - trackH   // spare horizontal room (symmetric pad)

        ZStack {
            DayNightToggleView_TrackView(progress: progress, width: trackW, height: trackH)
            DayNightToggleView_StarField(progress: progress, width: trackW, height: trackH)
            DayNightToggleView_DiscStack(progress: progress, diameter: diameter)
                .offset(x: -travel / 2 + travel * progress) // animatable slide
        }
        .frame(width: trackW, height: trackH)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Track (sky-blue -> indigo crossfade)

private struct DayNightToggleView_TrackView: View {
    var progress: CGFloat
    var width: CGFloat
    var height: CGFloat

    private var dayGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.42, green: 0.74, blue: 0.98),
                Color(red: 0.26, green: 0.56, blue: 0.92)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var nightGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.16, green: 0.13, blue: 0.34),
                Color(red: 0.05, green: 0.04, blue: 0.14)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            Capsule().fill(dayGradient)
            // .opacity is animatable -> smooth crossfade in both branches.
            Capsule().fill(nightGradient).opacity(Double(progress))
        }
        .overlay(
            Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 0.6)
        )
        .frame(width: width, height: height)
        .shadow(color: Color.black.opacity(0.28), radius: height * 0.10, y: height * 0.05)
    }
}

// MARK: - Stars (fixed positions, opacity by progress)

private struct DayNightToggleView_StarField: View {
    var progress: CGFloat
    var width: CGFloat
    var height: CGFloat

    // Hardcoded unit-fraction positions + relative radius. Never randomized in
    // body, so they don't re-roll every frame. Kept on the left half so the
    // moon thumb (which slides to the right) doesn't sit on top of them.
    private static let stars: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [
        (0.14, 0.28, 0.030),
        (0.24, 0.62, 0.022),
        (0.34, 0.34, 0.026),
        (0.20, 0.46, 0.018),
        (0.40, 0.66, 0.020),
        (0.30, 0.20, 0.016),
        (0.46, 0.44, 0.024)
    ]

    var body: some View {
        ZStack {
            ForEach(Array(Self.stars.enumerated()), id: \.offset) { _, s in
                Circle()
                    .fill(Color.white)
                    .frame(width: s.r * width * 2, height: s.r * width * 2)
                    .position(x: s.x * width, y: s.y * height)
                    .blur(radius: s.r * width * 0.25)
            }
        }
        .frame(width: width, height: height)
        .opacity(Double(progress))
        .allowsHitTesting(false)
    }
}

// MARK: - Disc (sun <-> crescent moon)

private struct DayNightToggleView_DiscStack: View {
    var progress: CGFloat
    var diameter: CGFloat

    var body: some View {
        ZStack {
            // Soft outer halo (sun glow -> moon glow). Blurred + low alpha, so a
            // structural color crossfade here is cheap and unobtrusive.
            haloLayer

            // Carved disc. compositingGroup() MUST wrap THIS inner ZStack only,
            // so destinationOut erases within the disc, not the track behind it.
            ZStack {
                Circle().fill(sunGradient)
                // Animatable color morph: moon fill crossfades in over the sun.
                Circle().fill(moonGradient).opacity(Double(progress))
                // Opaque eraser (alpha 1) — required for destinationOut to bite.
                Circle()
                    .fill(Color.black)
                    .frame(width: diameter, height: diameter)
                    .offset(x: eraserOffset)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
        }
        .frame(width: diameter, height: diameter)
        .overlay(rayBurst.opacity(Double(1 - progress)))
    }

    // At progress 0 the eraser sits clear of the disc (full sun). As progress
    // -> 1 it slides in to about a third of the diameter to carve the crescent.
    private var eraserOffset: CGFloat {
        let start = diameter * 1.05   // fully clear of the disc
        let end = diameter * 0.34     // overlapped -> crescent bite
        return start + (end - start) * progress
    }

    private var sunGradient: RadialGradient {
        RadialGradient(
            colors: [
                Color(red: 1.0, green: 0.93, blue: 0.62),
                Color(red: 1.0, green: 0.78, blue: 0.28)
            ],
            center: .init(x: 0.38, y: 0.34),
            startRadius: 0,
            endRadius: diameter * 0.75
        )
    }

    private var moonGradient: RadialGradient {
        RadialGradient(
            colors: [
                Color(red: 0.97, green: 0.97, blue: 1.0),
                Color(red: 0.74, green: 0.78, blue: 0.90)
            ],
            center: .init(x: 0.38, y: 0.34),
            startRadius: 0,
            endRadius: diameter * 0.75
        )
    }

    private var haloLayer: some View {
        ZStack {
            Circle().fill(sunHalo)
            Circle().fill(moonHalo).opacity(Double(progress))
        }
        .scaleEffect(1.42)
        .blur(radius: diameter * 0.10)
        .allowsHitTesting(false)
    }

    private var sunHalo: RadialGradient {
        RadialGradient(
            colors: [Color(red: 1.0, green: 0.85, blue: 0.40).opacity(0.55), Color.clear],
            center: .center,
            startRadius: diameter * 0.30,
            endRadius: diameter * 0.78
        )
    }

    private var moonHalo: RadialGradient {
        RadialGradient(
            colors: [Color(red: 0.78, green: 0.82, blue: 0.98).opacity(0.50), Color.clear],
            center: .center,
            startRadius: diameter * 0.30,
            endRadius: diameter * 0.78
        )
    }

    // Radiating sun rays, fading out as night arrives.
    private var rayBurst: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                Capsule()
                    .fill(Color(red: 1.0, green: 0.86, blue: 0.42))
                    .frame(width: diameter * 0.06, height: diameter * 0.22)
                    .offset(y: -diameter * 0.80)
                    .rotationEffect(.degrees(Double(i) / 8 * 360))
            }
        }
        .allowsHitTesting(false)
    }
}
