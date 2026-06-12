//
//  AuroraCodeGen.swift
//  InspireCreativityApp
//
//  Palette-true Swift source generation for aurora catalog items.
//
//  Each of the ~77 aurora backgrounds is rendered at runtime by
//  `ParametricAuroraPreview` (see AuroraPreviews.swift) from an
//  `AuroraDescriptor` (engine + palette + speed + particles). Historically
//  every aurora item shipped the same hardcoded `Code.auroraMesh` snippet,
//  which looked nothing like the preview the buyer saw. This generator emits
//  a per-engine Swift snippet that interpolates the item's *own* palette,
//  speed and particle config, so the copied code visually MATCHES the
//  preview (it is a faithful translation, not a pixel-exact capture).
//
//  IMPORTANT — keep in sync with `ParametricAuroraPreview` in
//  Animations/Previews/AuroraPreviews.swift. The templates below are a
//  mechanical port of that view's per-engine rendering. If you change an
//  engine's rendering there, update the matching template here (and vice
//  versa) or the copied code will silently drift from the preview.
//
//  The generated snippets are SELF-CONTAINED: each embeds its own local
//  `Color(hex:)` initializer (falling back to `.black` on malformed input)
//  and never references the app's internal `HexColor` extension. A reader
//  can paste one generated file into a fresh Xcode project and it compiles.
//

import Foundation

/// Generates self-contained, palette-true SwiftUI source for an aurora
/// background, one template per `AuroraEngine`.
///
/// The output mirrors what ``ParametricAuroraPreview`` renders for the same
/// descriptor, so the code a buyer copies matches the preview they saw.
enum AuroraCodeGen {

    /// Returns ready-to-paste SwiftUI source for `descriptor`, built from its
    /// engine template and its own palette, speed and particle configuration.
    ///
    /// - Parameter descriptor: The aurora descriptor driving both the preview
    ///   and the generated code.
    /// - Returns: A complete `.swift` file body (imports SwiftUI, a self-contained
    ///   `Color(hex:)`, and a `View` named after the descriptor).
    static func swiftCode(for descriptor: AuroraDescriptor) -> String {
        let typeName = self.typeName(for: descriptor)
        let palette = paletteLiteral(descriptor.palette)
        // Preview clamps with `max(2, descriptor.speed)`; mirror that exactly.
        let duration = max(2, descriptor.speed)
        let durationLiteral = numberLiteral(duration)
        let body = engineBody(
            engine: descriptor.engine,
            typeName: typeName,
            palette: palette,
            durationLiteral: durationLiteral,
            particles: descriptor.particles
        )
        return body
    }

    // MARK: - Type name

    private static func typeName(for descriptor: AuroraDescriptor) -> String {
        // "au-blackhole" / "Aurora Sunset" -> "AuroraBlackholeBackground"
        let source = descriptor.id.hasPrefix("au-")
            ? String(descriptor.id.dropFirst(3))
            : descriptor.id
        let cleaned = source
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        let camel = cleaned
            .split(whereSeparator: { $0 == " " })
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined()
        let base = camel.isEmpty ? "Aurora" : camel
        let prefixed = base.hasPrefix("Aurora") ? base : "Aurora" + base
        return prefixed + "Background"
    }

    // MARK: - Literals

    /// `["#FF6B4A", "#FFA34D"]` — every hex appears verbatim so generated code
    /// is greppable for its palette (test invariant (c)).
    private static func paletteLiteral(_ palette: [String]) -> String {
        let quoted = palette.map { "\"\($0)\"" }.joined(separator: ", ")
        return "[\(quoted)]"
    }

    /// Renders a Double without a trailing `.0` when it is integral, so `8` not
    /// `8.0` and `2.5` stays `2.5`.
    private static func numberLiteral(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        return String(value)
    }

    // MARK: - Shared preamble

    /// The self-contained header: SwiftUI import + a local `Color(hex:)`.
    /// Falls back to `.black` (NOT the app's internal `Theme.Palette.surface`)
    /// so the snippet stands alone.
    private static let preamble = """
    import SwiftUI

    // Self-contained hex color — paste-and-run, no app dependencies.
    private extension Color {
        init(hex: String) {
            var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            if s.hasPrefix("#") { s.removeFirst() }
            guard s.count == 6, let v = UInt64(s, radix: 16) else {
                self = .black
                return
            }
            self = Color(
                red: Double((v >> 16) & 0xFF) / 255,
                green: Double((v >> 8) & 0xFF) / 255,
                blue: Double(v & 0xFF) / 255
            )
        }
    }
    """

    // MARK: - Engine bodies

    private static func engineBody(
        engine: AuroraEngine,
        typeName: String,
        palette: String,
        durationLiteral: String,
        particles: AuroraParticles?
    ) -> String {
        switch engine {
        case .mesh:    return meshBody(typeName: typeName, palette: palette, durationLiteral: durationLiteral, blur: 28, scale: 1.0, particles: particles)
        case .goo:     return meshBody(typeName: typeName, palette: palette, durationLiteral: durationLiteral, blur: 14, scale: 0.85, particles: particles)
        case .spin:    return spinBody(typeName: typeName, palette: palette, durationLiteral: durationLiteral, particles: particles)
        case .bloom:   return bloomBody(typeName: typeName, palette: palette, durationLiteral: durationLiteral, particles: particles)
        case .streaks: return streaksBody(typeName: typeName, palette: palette, durationLiteral: durationLiteral, particles: particles)
        }
    }

    // mesh + goo share the drifting-radial-blob renderer; goo just runs a
    // tighter blur and smaller blobs. Mirrors `meshBlobs(blur:scale:)`.
    private static func meshBody(
        typeName: String,
        palette: String,
        durationLiteral: String,
        blur: Int,
        scale: Double,
        particles: AuroraParticles?
    ) -> String {
        let scaleLiteral = numberLiteral(scale)
        return """
        \(preamble)

        /// Drifting radial color blobs, screen-blended over black — a palette-true
        /// match for the in-app preview (\(blur)pt blur, \(scaleLiteral)× blobs).
        struct \(typeName): View {
            @State private var t: Double = 0
            private let palette = \(palette)
            private var colors: [Color] { palette.map { Color(hex: $0) } }

            var body: some View {
                ZStack {
                    Color.black
                    GeometryReader { geo in
                        ZStack {
                            ForEach(0..<colors.count, id: \\.self) { i in
                                let phase = t + Double(i) * 0.25
                                let c = colors[i % colors.count]
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [c.opacity(0.85), c.opacity(0)],
                                            center: .center,
                                            startRadius: 2,
                                            endRadius: geo.size.width * 0.55
                                        )
                                    )
                                    .frame(width: geo.size.width * \(scaleLiteral),
                                           height: geo.size.width * \(scaleLiteral))
                                    .offset(
                                        x: cos(phase * .pi * 2 + Double(i)) * geo.size.width * 0.25,
                                        y: sin(phase * .pi * 2 * 0.85 + Double(i) * 1.3) * geo.size.height * 0.3
                                    )
                                    .blendMode(.screen)
                            }
                        }
                        .blur(radius: \(blur))
                    }
        \(particleOverlaySource(particles))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .onAppear {
                    withAnimation(.linear(duration: \(durationLiteral)).repeatForever(autoreverses: false)) {
                        t = 1
                    }
                }
            }
        }
        \(particleHelperSource(particles))
        """
    }

    // Mirrors `spinSweep`: a rotating angular gradient, screen-blended, with a
    // black multiply overlay to deepen the wheel.
    private static func spinBody(
        typeName: String,
        palette: String,
        durationLiteral: String,
        particles: AuroraParticles?
    ) -> String {
        return """
        \(preamble)

        /// A slowly rotating angular-gradient sweep — a palette-true match for
        /// the in-app preview.
        struct \(typeName): View {
            @State private var t: Double = 0
            private let palette = \(palette)
            private var colors: [Color] { palette.map { Color(hex: $0) } }

            var body: some View {
                ZStack {
                    Color.black
                    GeometryReader { geo in
                        let stops = colors + [colors.first ?? .white]
                        AngularGradient(colors: stops, center: .center)
                            .frame(width: geo.size.width * 1.6, height: geo.size.width * 1.6)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)
                            .rotationEffect(.degrees(t * 360))
                            .blur(radius: 12)
                            .blendMode(.screen)
                            .overlay(
                                Color.black.opacity(0.25)
                                    .blendMode(.multiply)
                            )
                    }
        \(particleOverlaySource(particles))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .onAppear {
                    withAnimation(.linear(duration: \(durationLiteral)).repeatForever(autoreverses: false)) {
                        t = 1
                    }
                }
            }
        }
        \(particleHelperSource(particles))
        """
    }

    // Mirrors `bloomBurst`: three concentric pulsing radial circles.
    private static func bloomBody(
        typeName: String,
        palette: String,
        durationLiteral: String,
        particles: AuroraParticles?
    ) -> String {
        return """
        \(preamble)

        /// A pulsing concentric bloom — a palette-true match for the in-app preview.
        struct \(typeName): View {
            @State private var t: Double = 0
            private let palette = \(palette)
            private var colors: [Color] { palette.map { Color(hex: $0) } }

            var body: some View {
                ZStack {
                    Color.black
                    GeometryReader { geo in
                        let pulse = 0.55 + sin(t * .pi * 2) * 0.3
                        ZStack {
                            ForEach(0..<3, id: \\.self) { i in
                                let c = colors[i % colors.count]
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [c.opacity(0.95), c.opacity(0)],
                                            center: .center,
                                            startRadius: 0,
                                            endRadius: geo.size.width * 0.55
                                        )
                                    )
                                    .frame(width: geo.size.width * pulse * (1.0 - Double(i) * 0.18),
                                           height: geo.size.width * pulse * (1.0 - Double(i) * 0.18))
                                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                                    .blendMode(.screen)
                            }
                        }
                        .blur(radius: 8)
                    }
        \(particleOverlaySource(particles))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .onAppear {
                    withAnimation(.linear(duration: \(durationLiteral)).repeatForever(autoreverses: false)) {
                        t = 1
                    }
                }
            }
        }
        \(particleHelperSource(particles))
        """
    }

    // Mirrors `streakBands`: tilted, screen-blended capsule bands.
    private static func streaksBody(
        typeName: String,
        palette: String,
        durationLiteral: String,
        particles: AuroraParticles?
    ) -> String {
        return """
        \(preamble)

        /// Tilted, drifting light bands — a palette-true match for the in-app preview.
        struct \(typeName): View {
            @State private var t: Double = 0
            private let palette = \(palette)
            private var colors: [Color] { palette.map { Color(hex: $0) } }

            var body: some View {
                ZStack {
                    Color.black
                    GeometryReader { geo in
                        ZStack {
                            ForEach(0..<colors.count, id: \\.self) { i in
                                let c = colors[i % colors.count]
                                let phase = t + Double(i) * 0.18
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [c.opacity(0), c.opacity(0.85), c.opacity(0)],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * 1.5, height: geo.size.height * 0.18)
                                    .rotationEffect(.degrees(-14))
                                    .offset(
                                        x: cos(phase * .pi * 2) * 30,
                                        y: (Double(i) - Double(colors.count - 1) / 2) * geo.size.height * 0.22
                                            + sin(phase * .pi * 2 * 0.7) * 8
                                    )
                                    .blur(radius: 18)
                                    .blendMode(.screen)
                            }
                        }
                    }
        \(particleOverlaySource(particles))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .onAppear {
                    withAnimation(.linear(duration: \(durationLiteral)).repeatForever(autoreverses: false)) {
                        t = 1
                    }
                }
            }
        }
        \(particleHelperSource(particles))
        """
    }

    // MARK: - Particle overlay (mirrors `particleOverlay` + `particleShape`)

    /// The `GeometryReader` overlay placed inside the engine's `ZStack`, or an
    /// empty string when the descriptor has no particles. Pre-indented to sit at
    /// the same depth as the engine background.
    private static func particleOverlaySource(_ particles: AuroraParticles?) -> String {
        guard let p = particles else { return "" }
        let colorExpr = p.colorHex.map { "Color(hex: \"\($0)\")" } ?? "Color.white"
        return """
                    GeometryReader { geo in
                        let particleColor = \(colorExpr)
                        ForEach(0..<\(p.density), id: \\.self) { i in
                            let seed = Double(i)
                            let x = (sin(seed * 12.9898) * 0.5 + 0.5) * geo.size.width
                            let y = (cos(seed * 78.233) * 0.5 + 0.5) * geo.size.height
                            let twinkle = 0.4 + sin(t * .pi * 2 + seed) * 0.4
                            AuroraParticle(color: particleColor, alpha: twinkle)
                                .position(x: x, y: y)
                        }
                    }
        """
    }

    /// The `AuroraParticle` helper view, specialized to the descriptor's kind.
    /// Empty when the descriptor has no particles. Mirrors `particleShape(kind:…)`.
    private static func particleHelperSource(_ particles: AuroraParticles?) -> String {
        guard let p = particles else { return "" }
        let shape: String
        switch p.kind {
        case .stars, .sparkle, .bokeh:
            let size = p.kind == .bokeh ? "6" : "2"
            let blur = p.kind == .bokeh ? "1.5" : "0"
            shape = """
                    Circle()
                        .fill(color.opacity(alpha))
                        .frame(width: \(size), height: \(size))
                        .blur(radius: \(blur))
            """
        case .snow, .dust:
            shape = """
                    Circle()
                        .fill(color.opacity(alpha * 0.7))
                        .frame(width: 1.5, height: 1.5)
            """
        case .rain:
            shape = """
                    Capsule()
                        .fill(color.opacity(alpha * 0.5))
                        .frame(width: 1, height: 6)
            """
        case .embers:
            shape = """
                    Circle()
                        .fill(color.opacity(alpha))
                        .frame(width: 2, height: 2)
                        .blur(radius: 0.6)
            """
        }
        return """


        /// One twinkling \(p.kind) particle.
        private struct AuroraParticle: View {
            let color: Color
            let alpha: Double
            var body: some View {
        \(shape)
            }
        }
        """
    }
}
