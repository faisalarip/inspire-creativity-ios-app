// catalog-id: tr-crumple-fade
import SwiftUI

// MARK: - Crumple Fade
// A tap-driven transition: the outgoing card scales inward while layered
// faceted light/shadow crease overlays bloom across it (faking a paper
// crumple) and it fades out, revealing the incoming card easing in beneath.
// Pure SwiftUI overlays + transforms, no shader. iOS 17.

struct CrumpleFadeView: View {
    var demo: Bool = false

    @State private var crumpled: Bool = false

    var body: some View {
        if demo {
            demoBody
        } else {
            interactiveBody
        }
    }

    // MARK: Demo — self-driving ping-pong loop

    private var demoBody: some View {
        // Trigger-less PhaseAnimator cycles the phases continuously (0→1→0…),
        // so the tile auto-crumples and un-crumples with no touch.
        PhaseAnimator([0.0, 1.0]) { phase in
            crumpleStage(progress: phase)
        } animation: { _ in
            .easeInOut(duration: 1.6)
        }
    }

    // MARK: Interactive — tap toggles the crumple

    private var interactiveBody: some View {
        crumpleStage(progress: crumpled ? 1.0 : 0.0)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                    crumpled.toggle()
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: crumpled)
    }

    // MARK: Shared stage — both modes feed a single progress value

    private func crumpleStage(progress: Double) -> some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                // Incoming card sits beneath and eases in as the outgoing leaves.
                CrumpleFadeView_IncomingCard(progress: progress)

                // Outgoing card crumples, creases and fades over the incoming one.
                CrumpleFadeView_OutgoingCard(progress: progress, size: size)
            }
            .frame(width: size.width, height: size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Incoming Card (revealed beneath)

private struct CrumpleFadeView_IncomingCard: View {
    let progress: Double

    var body: some View {
        // Reveal ramps in over the back half of the crumple so it's legible
        // by the time the outgoing card has shrunk away.
        let reveal = clamp((progress - 0.25) / 0.75)
        let scale = 0.92 + 0.08 * reveal

        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.18, green: 0.55, blue: 0.62),
                        Color(red: 0.10, green: 0.32, blue: 0.46)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
            )
            .overlay(
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .opacity(reveal)
            )
            .scaleEffect(scale)
            .opacity(0.35 + 0.65 * reveal)
            .padding(10)
    }
}

// MARK: - Outgoing Card (crumples + fades)

private struct CrumpleFadeView_OutgoingCard: View {
    let progress: Double
    let size: CGSize

    var body: some View {
        // Single progress drives scale, rotation, crease bloom and fade.
        let scale = 1.0 - 0.48 * progress
        let rotation = 6.0 * progress
        let cardOpacity = 1.0 - pow(progress, 1.4)
        let creaseOpacity = creaseBloom(progress)

        cardFace
            .overlay(
                CrumpleFadeView_CreaseOverlay(progress: progress, opacity: creaseOpacity)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            )
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .opacity(cardOpacity)
            .padding(10)
            .shadow(
                color: .black.opacity(0.25 * progress),
                radius: 10 * progress,
                x: 0,
                y: 4 * progress
            )
    }

    private var cardFace: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.94, green: 0.93, blue: 0.90),
                        Color(red: 0.82, green: 0.80, blue: 0.76)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
            )
            .overlay(
                VStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 30, weight: .regular))
                    Text("Tap")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Color(red: 0.32, green: 0.30, blue: 0.27))
                .opacity(1.0 - progress)
            )
    }

    // Creases bloom in mid-crumple, peaking near the end.
    private func creaseBloom(_ p: Double) -> Double {
        let ramp = clamp(p / 0.85)
        return ramp * (0.55 + 0.45 * ramp)
    }
}

// MARK: - Crease Overlay (faceted light/shadow polygons)

private struct CrumpleFadeView_CreaseOverlay: View {
    let progress: Double
    let opacity: Double

    var body: some View {
        // A gentle expansion of the facets so creases appear to spread.
        let spread = 0.85 + 0.15 * progress

        ZStack {
            ForEach(CrumpleFadeView_Facet.all) { facet in
                CrumpleFadeView_FacetShape(points: facet.points)
                    .fill(facet.gradient)
                    .blendMode(facet.blend)
                    .opacity(facet.weight)
            }
        }
        .scaleEffect(spread)
        .opacity(opacity)
        .allowsHitTesting(false)
    }
}

// A single crease facet: a polygon in unit space with a light or shadow gradient.
private struct CrumpleFadeView_Facet: Identifiable {
    let id: Int
    let points: [CGPoint]
    let blend: BlendMode
    let weight: Double
    let gradient: LinearGradient

    static let all: [CrumpleFadeView_Facet] = makeFacets()

    private static func makeFacets() -> [CrumpleFadeView_Facet] {
        // Unit-square coordinates (0...1). Stable across all frames.
        let raw: [(pts: [CGPoint], light: Bool, w: Double, angle: Double)] = [
            ([CGPoint(x: 0.0, y: 0.0), CGPoint(x: 0.42, y: 0.10), CGPoint(x: 0.20, y: 0.46)], true, 0.55, 35),
            ([CGPoint(x: 0.42, y: 0.10), CGPoint(x: 0.78, y: 0.0), CGPoint(x: 0.58, y: 0.40)], false, 0.5, 120),
            ([CGPoint(x: 0.78, y: 0.0), CGPoint(x: 1.0, y: 0.18), CGPoint(x: 0.72, y: 0.42)], true, 0.5, 70),
            ([CGPoint(x: 0.20, y: 0.46), CGPoint(x: 0.58, y: 0.40), CGPoint(x: 0.40, y: 0.74)], false, 0.55, 160),
            ([CGPoint(x: 0.58, y: 0.40), CGPoint(x: 0.92, y: 0.50), CGPoint(x: 0.66, y: 0.78)], true, 0.5, 20),
            ([CGPoint(x: 0.0, y: 0.30), CGPoint(x: 0.20, y: 0.46), CGPoint(x: 0.06, y: 0.80)], false, 0.45, 140),
            ([CGPoint(x: 0.40, y: 0.74), CGPoint(x: 0.66, y: 0.78), CGPoint(x: 0.48, y: 1.0)], true, 0.5, 95),
            ([CGPoint(x: 0.66, y: 0.78), CGPoint(x: 1.0, y: 0.72), CGPoint(x: 0.84, y: 1.0)], false, 0.5, 50),
            ([CGPoint(x: 0.06, y: 0.80), CGPoint(x: 0.40, y: 0.74), CGPoint(x: 0.18, y: 1.0)], true, 0.45, 110),
            ([CGPoint(x: 0.72, y: 0.42), CGPoint(x: 1.0, y: 0.18), CGPoint(x: 0.92, y: 0.50)], false, 0.45, 130)
        ]

        return raw.enumerated().map { index, item in
            CrumpleFadeView_Facet(
                id: index,
                points: item.pts,
                blend: item.light ? .plusLighter : .multiply,
                weight: item.w,
                gradient: facetGradient(light: item.light, angle: item.angle)
            )
        }
    }

    private static func facetGradient(light: Bool, angle: Double) -> LinearGradient {
        let unit = unitPoints(for: angle)
        let colors: [Color]
        if light {
            colors = [
                Color.white.opacity(0.85),
                Color.white.opacity(0.15)
            ]
        } else {
            colors = [
                Color.black.opacity(0.55),
                Color.black.opacity(0.10)
            ]
        }
        return LinearGradient(colors: colors, startPoint: unit.start, endPoint: unit.end)
    }

    private static func unitPoints(for angle: Double) -> (start: UnitPoint, end: UnitPoint) {
        let radians = angle * .pi / 180.0
        let dx = cos(radians)
        let dy = sin(radians)
        let start = UnitPoint(x: 0.5 - dx * 0.5, y: 0.5 - dy * 0.5)
        let end = UnitPoint(x: 0.5 + dx * 0.5, y: 0.5 + dy * 0.5)
        return (start, end)
    }
}

// Renders a unit-space polygon into the available rect.
private struct CrumpleFadeView_FacetShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: scaled(first, in: rect))
        for point in points.dropFirst() {
            path.addLine(to: scaled(point, in: rect))
        }
        path.closeSubpath()
        return path
    }

    private func scaled(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + point.x * rect.width,
            y: rect.minY + point.y * rect.height
        )
    }
}

// MARK: - Helpers

private func clamp(_ value: Double) -> Double {
    min(1.0, max(0.0, value))
}
