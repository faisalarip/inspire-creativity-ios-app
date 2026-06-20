// catalog-id: tr-clock-pie-wipe
import SwiftUI

/// Clock Pie Wipe — an angular sweep mask rotates around the center like a clock
/// hand, progressively unveiling the "next" scene in a radial pie sweep. A bright
/// leading-edge ray rides the sweeping radius like a radar beam.
///
/// `interaction: auto` — both `demo` states run the same self-driving sweep.
struct ClockPieWipeView: View {
    var demo: Bool = false

    /// Seconds for one full 360° sweep (one scene reveal).
    private let period: Double = 3.2

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                content(in: size, time: t)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Composed frame

    @ViewBuilder
    private func content(in size: CGSize, time t: TimeInterval) -> some View {
        let cycle = floor(t / period)
        let phase = t / period - cycle          // 0...1 within the current sweep
        let sweep = phase * 360.0               // degrees revealed so far
        let leading = sweep - 90.0              // leading radius, 0° = top (clock 12)

        let count = Self.scenes.count
        let baseIndex = Int(cycle.truncatingRemainder(dividingBy: Double(count)))
        let bgIndex = ((baseIndex % count) + count) % count
        let fgIndex = (bgIndex + 1) % count

        let radius = hypot(size.width, size.height) / 2.0

        ZStack {
            // Background: fully-opaque current scene — never blank on any frame.
            sceneView(Self.scenes[bgIndex], in: size)

            // Foreground: next scene, revealed through the rotating pie wedge.
            sceneView(Self.scenes[fgIndex], in: size)
                .mask(
                    PieWedge(startAngle: .degrees(-90), sweep: .degrees(sweep))
                        .frame(width: radius * 2, height: radius * 2)
                )

            // Radar ray riding the leading radius.
            radarRay(radius: radius, angleDegrees: leading)
                .opacity(phase < 0.004 || phase > 0.996 ? 0.0 : 1.0)

            // Static clock face overlay (hub + ticks) for mechanical precision.
            clockFurniture(radius: radius)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    // MARK: - Radar ray

    private func radarRay(radius: CGFloat, angleDegrees: Double) -> some View {
        let beam = LinearGradient(
            stops: [
                .init(color: .white.opacity(0.0), location: 0.0),
                .init(color: .white.opacity(0.35), location: 0.55),
                .init(color: .white, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        return ZStack {
            // Soft glow under the crisp ray.
            Capsule()
                .fill(Color.white.opacity(0.25))
                .frame(width: 6, height: radius)
                .blur(radius: 5)
                .offset(y: -radius / 2)
            Capsule()
                .fill(beam)
                .frame(width: 2.0, height: radius)
                .offset(y: -radius / 2)
        }
        .rotationEffect(.degrees(angleDegrees + 90))
    }

    // MARK: - Clock furniture

    private func clockFurniture(radius: CGFloat) -> some View {
        let r = min(radius, 600)
        return ZStack {
            ForEach(0..<12, id: \.self) { i in
                Capsule()
                    .fill(Color.white.opacity(i % 3 == 0 ? 0.30 : 0.14))
                    .frame(width: i % 3 == 0 ? 2.2 : 1.4,
                           height: i % 3 == 0 ? 9 : 5)
                    .offset(y: -(r * 0.46))
                    .rotationEffect(.degrees(Double(i) / 12.0 * 360.0))
            }
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.9), .white.opacity(0.15)],
                        center: .center, startRadius: 0, endRadius: 7
                    )
                )
                .frame(width: 10, height: 10)
        }
    }

    // MARK: - Scenes (each cycle reveals a visibly different "next view")

    private struct Scene: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let top: Color
        let bottom: Color
        let tint: Color
    }

    private static let scenes: [Scene] = [
        Scene(symbol: "sunrise.fill", title: "MORNING",
              top: Color(hexCode: 0x2A1B3D), bottom: Color(hexCode: 0x44318D),
              tint: Color(hexCode: 0xFFB86B)),
        Scene(symbol: "sun.max.fill", title: "MIDDAY",
              top: Color(hexCode: 0x0E4D64), bottom: Color(hexCode: 0x137DC5),
              tint: Color(hexCode: 0xFFE08A)),
        Scene(symbol: "sunset.fill", title: "EVENING",
              top: Color(hexCode: 0x6A1E3A), bottom: Color(hexCode: 0xC0392B),
              tint: Color(hexCode: 0xFFC07A)),
        Scene(symbol: "moon.stars.fill", title: "NIGHT",
              top: Color(hexCode: 0x0B1026), bottom: Color(hexCode: 0x222B5A),
              tint: Color(hexCode: 0x9FB8FF))
    ]

    @ViewBuilder
    private func sceneView(_ scene: Scene, in size: CGSize) -> some View {
        let dim = min(size.width, size.height)
        ZStack {
            LinearGradient(
                colors: [scene.top, scene.bottom],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            // Subtle angular sheen so the wedge edge catches light.
            AngularGradient(
                colors: [
                    .white.opacity(0.0), scene.tint.opacity(0.16),
                    .white.opacity(0.0), .white.opacity(0.0)
                ],
                center: .center
            )
            .blendMode(.screen)

            VStack(spacing: dim * 0.06) {
                Image(systemName: scene.symbol)
                    .font(.system(size: dim * 0.30, weight: .medium))
                    .foregroundStyle(scene.tint)
                    .shadow(color: scene.tint.opacity(0.6), radius: dim * 0.05)
                Text(scene.title)
                    .font(.system(size: max(9, dim * 0.11),
                                  weight: .heavy, design: .rounded))
                    .tracking(dim * 0.02)
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
    }
}

// MARK: - Pie wedge shape (animatable sweep)

private struct PieWedge: Shape {
    var startAngle: Angle
    var sweep: Angle

    var animatableData: Double {
        get { sweep.degrees }
        set { sweep = .degrees(newValue) }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = max(rect.width, rect.height)   // overshoot to guarantee corners
        let clamped = min(max(sweep.degrees, 0), 360)
        guard clamped > 0 else { return path }
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: startAngle + .degrees(clamped),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Hex color helper

private extension Color {
    init(hexCode hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
