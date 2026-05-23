//
//  AuroraPreviews.swift
//  StaggerApp
//
//  Aurora pack previews — animated mesh gradients with iOS 17 fallbacks.
//

import SwiftUI

// MARK: - Aurora Borealis

struct AuroraBorealisPreview: View {
    @State private var t: CGFloat = 0
    var body: some View {
        ZStack {
            Color.black
            // Stars
            ForEach(0..<20, id: \.self) { i in
                let seed = Double(i)
                Circle()
                    .fill(Color.white.opacity(0.65))
                    .frame(width: 1.5, height: 1.5)
                    .position(
                        x: CGFloat((sin(seed * 12.9) * 0.5 + 0.5)) * 200,
                        y: CGFloat((cos(seed * 7.3) * 0.5 + 0.5)) * 80
                    )
            }
            // Aurora bands
            ForEach(0..<3, id: \.self) { i in
                let phase = t + CGFloat(i) * 0.3
                AuroraBand(phase: phase)
                    .fill(
                        LinearGradient(
                            colors: [
                                [Color.green, Color.cyan, Color.blue][i].opacity(0),
                                [Color.green, Color.cyan, Color.blue][i].opacity(0.6),
                                [Color.green, Color.cyan, Color.blue][i].opacity(0)
                            ],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .blendMode(.screen)
                    .blur(radius: 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) {
                t = 1
            }
        }
    }
}

private struct AuroraBand: Shape {
    var phase: CGFloat
    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let h = rect.height
        let midY = rect.midY
        p.move(to: CGPoint(x: 0, y: midY))
        for x in stride(from: 0, through: rect.width, by: 2) {
            let rel = x / rect.width
            let y = midY + sin(rel * .pi * 3 + phase * .pi * 2) * h * 0.2
            p.addLine(to: CGPoint(x: x, y: y))
        }
        for x in stride(from: rect.width, through: 0, by: -2) {
            let rel = x / rect.width
            let y = midY + sin(rel * .pi * 3 + phase * .pi * 2) * h * 0.2 + 32
            p.addLine(to: CGPoint(x: x, y: y))
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Liquid Chrome

struct LiquidChromePreview: View {
    @State private var t: CGFloat = 0
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(white: 0.15),
                    Color(white: 0.65),
                    Color(white: 0.3),
                    Color(white: 0.85),
                    Color(white: 0.25)
                ],
                startPoint: UnitPoint(x: t, y: 0),
                endPoint: UnitPoint(x: 1 - t, y: 1)
            )
            .hueRotation(.degrees(t * 90))
            .blur(radius: 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                t = 1
            }
        }
    }
}

// MARK: - Aurora Pulse

struct AuroraPulsePreview: View {
    @State private var pulse = false
    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.03, blue: 0.1)
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                [Color.purple, Color.pink, Color.blue, Color.cyan, Color.indigo][i].opacity(0.6),
                                .clear
                            ],
                            center: .center,
                            startRadius: 4,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .offset(
                        x: pulse ? CGFloat(cos(Double(i)) * 30) : CGFloat(sin(Double(i)) * 30),
                        y: pulse ? CGFloat(sin(Double(i)) * 30) : CGFloat(cos(Double(i)) * 30)
                    )
                    .blendMode(.screen)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Lava Flow

struct LavaFlowPreview: View {
    @State private var t: CGFloat = 0
    var body: some View {
        ZStack {
            Color.black
            ForEach(0..<6, id: \.self) { i in
                let phase = t + CGFloat(i) * 0.16
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.orange,
                                Color.red.opacity(0.6),
                                .clear
                            ],
                            center: .center,
                            startRadius: 4, endRadius: 60
                        )
                    )
                    .frame(width: 100, height: 100)
                    .offset(
                        x: cos(phase * .pi * 2) * 40,
                        y: sin(phase * .pi * 2) * 30
                    )
                    .blur(radius: 6)
                    .blendMode(.screen)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                t = 1
            }
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: Parametric aurora — drives the big Backgrounds library.
// One view + a descriptor table renders all 60+ aurora variants.
// MARK: ─────────────────────────────────────────────────────────────

enum AuroraEngine { case mesh, spin, bloom, streaks, goo }

enum AuroraParticleKind { case stars, snow, dust, rain, embers, bokeh, sparkle }

struct AuroraParticles {
    let kind: AuroraParticleKind
    let density: Int
    let colorHex: String?
}

struct AuroraDescriptor {
    let id: String
    let name: String
    let theme: String
    let engine: AuroraEngine
    let palette: [String]
    let speed: Double
    let isPro: Bool
    let price: Double?
    let use: String
    let particles: AuroraParticles?
}

struct ParametricAuroraPreview: View {
    let descriptor: AuroraDescriptor
    @State private var t: Double = 0

    private var colors: [Color] {
        descriptor.palette.map { Color(hex: $0) }
    }

    var body: some View {
        ZStack {
            Color.black
            background
            particleOverlay
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .onAppear {
            withAnimation(.linear(duration: max(2, descriptor.speed)).repeatForever(autoreverses: false)) {
                t = 1
            }
        }
    }

    @ViewBuilder private var background: some View {
        switch descriptor.engine {
        case .mesh:    meshBlobs(blur: 28, scale: 1.0)
        case .spin:    spinSweep
        case .bloom:   bloomBurst
        case .streaks: streakBands
        case .goo:     meshBlobs(blur: 14, scale: 0.85)
        }
    }

    private func meshBlobs(blur: CGFloat, scale: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<colors.count, id: \.self) { i in
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
                        .frame(width: geo.size.width * scale,
                               height: geo.size.width * scale)
                        .offset(
                            x: cos(phase * .pi * 2 + Double(i)) * geo.size.width * 0.25,
                            y: sin(phase * .pi * 2 * 0.85 + Double(i) * 1.3) * geo.size.height * 0.3
                        )
                        .blendMode(.screen)
                }
            }
            .blur(radius: blur)
        }
    }

    private var spinSweep: some View {
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
    }

    private var bloomBurst: some View {
        GeometryReader { geo in
            let pulse = 0.55 + sin(t * .pi * 2) * 0.3
            ZStack {
                ForEach(0..<3, id: \.self) { i in
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
    }

    private var streakBands: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<colors.count, id: \.self) { i in
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
    }

    @ViewBuilder private var particleOverlay: some View {
        if let p = descriptor.particles {
            GeometryReader { geo in
                let color = p.colorHex.map { Color(hex: $0) } ?? .white
                ForEach(0..<p.density, id: \.self) { i in
                    let seed = Double(i)
                    let x = (sin(seed * 12.9898) * 0.5 + 0.5) * geo.size.width
                    let y = (cos(seed * 78.233) * 0.5 + 0.5) * geo.size.height
                    let twinkle = 0.4 + sin(t * .pi * 2 + seed) * 0.4
                    particleShape(kind: p.kind, color: color, alpha: twinkle)
                        .position(x: x, y: y)
                }
            }
        }
    }

    @ViewBuilder
    private func particleShape(kind: AuroraParticleKind, color: Color, alpha: Double) -> some View {
        switch kind {
        case .stars, .sparkle, .bokeh:
            Circle()
                .fill(color.opacity(alpha))
                .frame(width: kind == .bokeh ? 6 : 2, height: kind == .bokeh ? 6 : 2)
                .blur(radius: kind == .bokeh ? 1.5 : 0)
        case .snow, .dust:
            Circle().fill(color.opacity(alpha * 0.7)).frame(width: 1.5, height: 1.5)
        case .rain:
            Capsule().fill(color.opacity(alpha * 0.5)).frame(width: 1, height: 6)
        case .embers:
            Circle()
                .fill(color.opacity(alpha))
                .frame(width: 2, height: 2)
                .blur(radius: 0.6)
        }
    }
}

// Curated descriptor table — drives both the catalog seed and the preview registry.
enum AuroraDescriptors {

    private static let palettes: [String: [String]] = [
        "sunset":    ["#FF6B4A","#FFA34D","#F87171","#F472B6"],
        "twilight":  ["#A78BFA","#7C3AED","#FB7185","#FCD34D"],
        "dawn":      ["#FECACA","#FDBA74","#FCD34D","#86EFAC"],
        "midnight":  ["#1E40AF","#312E81","#7C3AED","#A78BFA"],
        "arctic":    ["#DBEAFE","#93C5FD","#3B82F6","#E0F2FE"],
        "desert":    ["#FED7AA","#FB923C","#EA580C","#92400E"],
        "storm":     ["#1E293B","#475569","#94A3B8","#FACC15"],
        "tropics":   ["#06B6D4","#10B981","#FB923C","#F472B6"],
        "cyber":     ["#EC4899","#06B6D4","#A855F7","#FACC15"],
        "pastel":    ["#FBCFE8","#DDD6FE","#A7F3D0","#FED7AA"],
        "mono":      ["#F4F4F5","#A1A1AA","#52525B","#71717A"],
        "neon":      ["#FF00FF","#00FFFF","#FFFF00","#00FF80"],
        "noir":      ["#0A0A0C","#27272A","#71717A","#FCD34D"],
        "romantic":  ["#9F1239","#FB7185","#FECDD3","#FCE7F3"],
        "ethereal":  ["#E0F2FE","#A5F3FC","#DDD6FE","#FDE68A"],
        "pearl":     ["#FFFFF0","#FDE68A","#FECACA","#DBEAFE"],
        "oilSlick":  ["#7C3AED","#0EA5E9","#10B981","#F472B6"],
        "bubble":    ["#FBCFE8","#A5F3FC","#FDE68A","#DDD6FE"],
        "mercury":   ["#F9FAFB","#D1D5DB","#9CA3AF","#3F3F46"],
        "gold":      ["#FCD34D","#F59E0B","#D97706","#FEF3C7"],
        "copper":    ["#B45309","#EA580C","#FDBA74","#FEF3C7"],
        "silver":    ["#F9FAFB","#E5E7EB","#9CA3AF","#4B5563"],
        "bronze":    ["#92400E","#B45309","#D97706","#FEF3C7"],
        "beetle":    ["#7C3AED","#10B981","#0EA5E9","#FACC15"],
        "nacre":     ["#FFE4E1","#FFF0F5","#F0F8FF","#E6E6FA"],
        "galaxy":    ["#312E81","#7C3AED","#EC4899","#0EA5E9"],
        "nebula":    ["#BE185D","#7C3AED","#1E40AF","#0EA5E9"],
        "cosmic":    ["#581C87","#1E1B4B","#0EA5E9","#FACC15"],
        "solar":     ["#FACC15","#F97316","#DC2626","#FEF3C7"],
        "blackHole": ["#0A0A0C","#7C3AED","#FB923C","#FACC15"],
        "pulsar":    ["#06B6D4","#3B82F6","#A855F7","#F472B6"],
        "milkyWay":  ["#1E1B4B","#3B82F6","#A78BFA","#FACC15"],
        "supernova": ["#FCD34D","#FB923C","#DC2626","#7C3AED"],
        "fire":      ["#FEF3C7","#FCD34D","#F97316","#DC2626"],
        "ocean":     ["#0C4A6E","#0284C7","#06B6D4","#67E8F9"],
        "forest":    ["#14532D","#16A34A","#84CC16","#FBBF24"],
        "ice":       ["#F0F9FF","#BAE6FD","#38BDF8","#1E40AF"],
        "jade":      ["#064E3B","#10B981","#A7F3D0","#ECFDF5"],
        "rose":      ["#9F1239","#E11D48","#FB7185","#FECACA"]
    ]

    static let all: [AuroraDescriptor] = {
        typealias D = (String, String, String, AuroraEngine, String, Double, Bool, Double?, String, AuroraParticles?)
        let raw: [D] = [
            ("au-sunset","Aurora Sunset","Atmospheric",.mesh,"sunset",8,true,6.99,"Splash screens · warm hero",nil),
            ("au-twilight","Aurora Twilight","Atmospheric",.mesh,"twilight",9,true,6.99,"Sleep apps · meditation",nil),
            ("au-dawn","Aurora Dawn","Atmospheric",.mesh,"dawn",10,true,6.99,"Morning routines · journaling",nil),
            ("au-midnight","Aurora Midnight","Atmospheric",.mesh,"midnight",12,true,8.99,"Night mode hero · sleep tracking",AuroraParticles(kind: .stars, density: 30, colorHex: nil)),
            ("au-arctic","Arctic Light","Atmospheric",.streaks,"arctic",7,true,9.99,"Travel · weather apps",AuroraParticles(kind: .snow, density: 25, colorHex: nil)),
            ("au-desert","Desert Heat","Atmospheric",.mesh,"desert",11,true,7.99,"Travel · adventure",AuroraParticles(kind: .dust, density: 30, colorHex: "#FED7AA")),
            ("au-storm","Storm Front","Atmospheric",.streaks,"storm",5,true,8.99,"Weather warnings · trading",AuroraParticles(kind: .rain, density: 35, colorHex: nil)),
            ("au-tropics","Tropical Haze","Atmospheric",.mesh,"tropics",9,true,7.99,"Vacation rental · summer launch",nil),
            ("au-foggy","Foggy Marsh","Atmospheric",.mesh,"mono",14,false,nil,"Reading apps · podcast",nil),
            ("au-cloudveil","Cloud Veil","Atmospheric",.mesh,"pastel",13,true,5.99,"Soft onboarding · prayer apps",nil),
            ("au-mirage","Mirage Ripple","Atmospheric",.goo,"desert",14,true,11.99,"Heat zones · physical wellness",nil),
            ("au-heatwave","Heat Wave","Atmospheric",.goo,"fire",12,true,10.99,"Fitness · cooking apps",nil),
            ("au-pearl","Pearl Sheen","Iridescent",.spin,"pearl",16,true,11.99,"Luxury · jewelry",nil),
            ("au-oilslick","Oil Slick","Iridescent",.spin,"oilSlick",10,true,12.99,"Music · creative tools",nil),
            ("au-bubble","Soap Bubble","Iridescent",.spin,"bubble",12,true,9.99,"Kids · playful brands",nil),
            ("au-mercury","Mercury Pool","Iridescent",.spin,"mercury",15,true,13.99,"Premium · finance",nil),
            ("au-goldfoil","Gold Foil","Iridescent",.spin,"gold",18,true,12.99,"Luxury · winner · awards",nil),
            ("au-copper","Copper Patina","Iridescent",.spin,"copper",14,true,10.99,"Craft · artisan brands",nil),
            ("au-silver","Silver Sheen","Iridescent",.spin,"silver",14,true,11.99,"Tech · enterprise",nil),
            ("au-bronze","Bronze Glow","Iridescent",.spin,"bronze",16,true,10.99,"Awards · gaming achievements",nil),
            ("au-beetle","Beetle Wing","Iridescent",.spin,"beetle",11,true,12.99,"Nature · niche",nil),
            ("au-nacre","Mother of Pearl","Iridescent",.spin,"nacre",18,true,11.99,"Wedding · beauty",nil),
            ("au-holofoil","Holographic Foil","Iridescent",.spin,"oilSlick",8,true,14.99,"Trading cards · collectibles",nil),
            ("au-galaxy","Galaxy Spiral","Cosmic",.mesh,"galaxy",14,true,9.99,"Space apps · ambient",AuroraParticles(kind: .stars, density: 50, colorHex: nil)),
            ("au-nebula","Nebula Drift","Cosmic",.mesh,"nebula",16,true,9.99,"Astrology · sci-fi",AuroraParticles(kind: .stars, density: 60, colorHex: nil)),
            ("au-solar","Solar Flare","Cosmic",.bloom,"solar",3,true,11.99,"Big reveals · launch",nil),
            ("au-blackhole","Black Hole","Cosmic",.bloom,"blackHole",6,true,13.99,"Sci-fi · gaming",AuroraParticles(kind: .dust, density: 30, colorHex: "#FACC15")),
            ("au-supernova","Supernova Burst","Cosmic",.bloom,"supernova",2.5,true,12.99,"Win celebration · trigger",nil),
            ("au-cosmicdust","Cosmic Dust","Cosmic",.mesh,"cosmic",20,true,10.99,"Ambient loop · background music",AuroraParticles(kind: .sparkle, density: 40, colorHex: "#FACC15")),
            ("au-milkyway","Milky Way","Cosmic",.streaks,"milkyWay",12,true,11.99,"Astronomy · planetarium",AuroraParticles(kind: .stars, density: 80, colorHex: nil)),
            ("au-pulsar","Pulsar Beat","Cosmic",.mesh,"pulsar",1.4,true,10.99,"Beat-reactive · radio",nil),
            ("au-eventhorizon","Event Horizon","Cosmic",.spin,"blackHole",8,true,13.99,"Sci-fi · dramatic",nil),
            ("au-stardust","Stardust Field","Particles",.mesh,"midnight",18,true,8.99,"Hero · award reveal",AuroraParticles(kind: .sparkle, density: 50, colorHex: "#FCD34D")),
            ("au-sparkleveil","Sparkle Veil","Particles",.mesh,"romantic",12,true,7.99,"Romance · gift moment",AuroraParticles(kind: .sparkle, density: 60, colorHex: "#FECDD3")),
            ("au-snowsky","Snowfall Sky","Particles",.mesh,"arctic",15,true,7.99,"Holiday · seasonal",AuroraParticles(kind: .snow, density: 40, colorHex: nil)),
            ("au-glassrain","Glass Rain","Particles",.mesh,"mono",10,true,7.99,"Loading · stormy mood",AuroraParticles(kind: .rain, density: 60, colorHex: nil)),
            ("au-emberrise","Ember Rise","Particles",.mesh,"fire",12,true,9.99,"Fireplace · campfire app",AuroraParticles(kind: .embers, density: 30, colorHex: nil)),
            ("au-bokeh","Soft Bokeh","Particles",.mesh,"romantic",14,true,8.99,"Wedding · photo apps",AuroraParticles(kind: .bokeh, density: 20, colorHex: "#FECDD3")),
            ("au-fireflies","Fireflies","Particles",.mesh,"forest",16,true,9.99,"Nature · summer night",AuroraParticles(kind: .sparkle, density: 30, colorHex: "#FDE68A")),
            ("au-pollen","Pollen Drift","Particles",.mesh,"dawn",18,true,7.99,"Spring · meditation",AuroraParticles(kind: .dust, density: 40, colorHex: "#FDE68A")),
            ("au-petalstorm","Petal Storm","Particles",.mesh,"romantic",10,true,8.99,"Romantic moments · weddings",AuroraParticles(kind: .snow, density: 25, colorHex: nil)),
            ("au-vortex","Vortex Pull","Geometric",.mesh,"cyber",4,true,9.99,"Trippy · psychedelic",nil),
            ("au-spiral","Spiral Galaxy","Geometric",.spin,"galaxy",22,true,10.99,"Space · loading state",nil),
            ("au-wavegrid","Wave Grid","Geometric",.mesh,"ocean",8,true,8.99,"Underwater · sound viz",nil),
            ("au-ringpulse","Ring Pulse","Geometric",.bloom,"tropics",2.5,false,nil,"Tap target · live indicator",nil),
            ("au-radialspin","Radial Spin","Geometric",.spin,"sunset",14,true,8.99,"Loading · circular progress",nil),
            ("au-coreburst","Core Burst","Geometric",.bloom,"fire",2,true,9.99,"Energy drinks · sports",nil),
            ("au-liquiddrop","Liquid Drop","Liquid",.goo,"ocean",10,true,10.99,"Water apps · meditation",nil),
            ("au-mercursplash","Mercury Splash","Liquid",.goo,"silver",9,true,11.99,"Futuristic · sci-fi",nil),
            ("au-petalpool","Petal Pool","Liquid",.goo,"rose",11,true,10.99,"Wellness · spa",nil),
            ("au-honeydrip","Honey Drip","Liquid",.goo,"gold",14,true,9.99,"Food · cooking · loaders",nil),
            ("au-champagne","Champagne Pop","Liquid",.goo,"gold",7,true,11.99,"Celebration · checkout success",AuroraParticles(kind: .sparkle, density: 30, colorHex: "#FCD34D")),
            ("au-jelloflow","Jello Flow","Liquid",.goo,"jade",10,true,9.99,"Playful brands · fitness",nil),
            ("au-romantic","Romantic Glow","Mood",.mesh,"romantic",11,true,7.99,"Dating · romance · cards",nil),
            ("au-ethereal","Ethereal Mist","Mood",.mesh,"ethereal",16,false,nil,"Meditation · spiritual",nil),
            ("au-noir","Noir Sparkle","Mood",.mesh,"noir",13,true,8.99,"Premium dark UI · cinema",AuroraParticles(kind: .sparkle, density: 30, colorHex: "#FCD34D")),
            ("au-vibrant","Vibrant Pop","Mood",.mesh,"neon",7,true,6.99,"Energy drinks · party",nil),
            ("au-calmdrift","Calm Drift","Mood",.mesh,"pastel",20,false,nil,"Anxiety · breathing · sleep",nil),
            ("au-firewall","Firewall","Mood",.streaks,"fire",6,true,10.99,"Security · gaming",AuroraParticles(kind: .embers, density: 25, colorHex: nil)),
            ("au-oceandepth","Ocean Depth","Mood",.mesh,"ocean",18,true,8.99,"Diving · marine apps",nil),
            ("au-iceshard","Ice Shard","Mood",.streaks,"ice",8,true,9.99,"Cold storage · winter",nil),
            ("au-emberglow","Ember Glow","Atmospheric",.mesh,"fire",13,true,7.99,"Hearth · winter ambient",AuroraParticles(kind: .embers, density: 20, colorHex: "#FCD34D")),
            ("au-monsoon","Monsoon Sky","Atmospheric",.streaks,"storm",6,true,8.49,"Rainy day · podcast cover",AuroraParticles(kind: .rain, density: 50, colorHex: nil)),
            ("au-cherryhaze","Cherry Haze","Atmospheric",.mesh,"romantic",12,true,7.49,"Sakura season · spring promo",AuroraParticles(kind: .bokeh, density: 18, colorHex: "#FECDD3")),
            ("au-chromebloom","Chrome Bloom","Iridescent",.bloom,"silver",10,true,12.49,"Premium reveal · luxury",nil),
            ("au-prismslick","Prism Slick","Iridescent",.spin,"oilSlick",11,true,13.49,"Music · creative tools",nil),
            ("au-quartz","Quartz Sheen","Iridescent",.spin,"pearl",14,true,10.49,"Wellness · crystal apps",nil),
            ("au-quasar","Quasar Drift","Cosmic",.mesh,"pulsar",13,true,10.49,"Dashboards · ambient",AuroraParticles(kind: .stars, density: 40, colorHex: nil)),
            ("au-novachain","Nova Chain","Cosmic",.bloom,"supernova",3,true,12.49,"Achievement · level-up",nil),
            ("au-cometdust","Comet Dust","Cosmic",.streaks,"galaxy",10,true,11.49,"Sci-fi · onboarding",AuroraParticles(kind: .dust, density: 35, colorHex: "#A78BFA")),
            ("au-glowmoth","Glowmoth Flutter","Particles",.mesh,"forest",17,true,8.49,"Nature · summer night",AuroraParticles(kind: .sparkle, density: 26, colorHex: "#FDE68A")),
            ("au-cinderfall","Cinder Fall","Particles",.mesh,"fire",11,true,8.99,"Action · gaming hero",AuroraParticles(kind: .embers, density: 35, colorHex: "#F97316")),
            ("au-bloomgrid","Bloom Grid","Geometric",.bloom,"tropics",3.5,true,9.49,"Live status · IoT",nil),
            ("au-helix","Helix Drift","Geometric",.spin,"nebula",16,true,9.99,"Data viz · genetic apps",nil),
            ("au-tideflow","Tide Flow","Liquid",.goo,"ocean",12,true,10.49,"Meditation · breathwork",nil),
            ("au-velvetcalm","Velvet Calm","Mood",.mesh,"pastel",18,false,nil,"Sleep · gentle reminders",nil),
            ("au-skylineneon","Skyline Neon","Mood",.streaks,"neon",6,true,9.49,"Nightlife · streetwear",nil)
        ]
        return raw.map { r in
            AuroraDescriptor(
                id: r.0, name: r.1, theme: r.2, engine: r.3,
                palette: palettes[r.4] ?? palettes["midnight"]!,
                speed: r.5, isPro: r.6, price: r.7, use: r.8, particles: r.9
            )
        }
    }()

    static let byId: [String: AuroraDescriptor] = {
        var d: [String: AuroraDescriptor] = [:]
        for a in all { d[a.id] = a }
        return d
    }()
}
