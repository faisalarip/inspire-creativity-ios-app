//
//  CreativePreviews.swift
//  InspireCreativityApp
//
//  Creative-tier previews: hologram cards, parallax, glitch text, morphing FAB.
//

import SwiftUI

// MARK: - Aurora Mesh

struct AuroraMeshPreview: View {
    @State private var t: CGFloat = 0
    var body: some View {
        ZStack {
            if #available(iOS 18, *) {
                AuroraMesh18(time: t)
            } else {
                AuroraGradientFallback()
                    .hueRotation(.degrees(t * 360))
            }
            Text("Intelligence")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(.white.opacity(0.95))
                .shadow(radius: 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) { t = 1 }
        }
    }
}

@available(iOS 18, *)
private struct AuroraMesh18: View {
    let time: CGFloat
    var body: some View {
        let p: (CGFloat, CGFloat) -> SIMD2<Float> = { x, y in SIMD2<Float>(Float(x), Float(y)) }
        let s = sin(time * .pi * 2)
        let c = cos(time * .pi * 2)
        return MeshGradient(
            width: 3, height: 3,
            points: [
                p(0, 0), p(0.5, 0.05 + 0.05 * s), p(1, 0),
                p(0.0, 0.5 + 0.1 * c), p(0.55 + 0.1 * s, 0.5), p(1, 0.5 + 0.05 * s),
                p(0, 1), p(0.5, 0.95 - 0.05 * s), p(1, 1)
            ],
            colors: [
                .indigo, .purple, .pink,
                .blue, .purple, .orange,
                .cyan, .indigo, .pink
            ]
        )
    }
}

struct AuroraGradientFallback: View {
    var body: some View {
        LinearGradient(
            colors: [.indigo, .purple, .pink, .orange],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}

// MARK: - Liquid Heart

struct LiquidHeartPreview: View {
    @State private var pulse = false
    var body: some View {
        ZStack {
            Image(systemName: "heart.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.red, .pink, .orange],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .scaleEffect(pulse ? 1.12 : 0.96)
                .shadow(color: .pink.opacity(0.6), radius: pulse ? 18 : 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Elastic Tabs

struct ElasticTabsPreview: View {
    @State private var selection = 0
    @Namespace private var ns
    private let labels = ["Now", "Top", "Live"]
    var body: some View {
        HStack(spacing: 4) {
            ForEach(labels.indices, id: \.self) { i in
                Button { selection = i } label: {
                    Text(labels[i])
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(selection == i ? .white : .white.opacity(0.5))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background {
                            if selection == i {
                                Capsule()
                                    .fill(Theme.Palette.accent)
                                    .matchedGeometryEffect(id: "tab", in: ns)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.06), in: Capsule())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.45, dampingFraction: 0.65), value: selection)
        .task { await runLoop() }
    }
    @MainActor
    private func runLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            selection = (selection + 1) % labels.count
        }
    }
}

// MARK: - Hologram Card

struct HologramCardPreview: View {
    @State private var shift = false
    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.4, green: 0.8, blue: 1.0),
                        Color(red: 0.8, green: 0.4, blue: 1.0),
                        Color(red: 1.0, green: 0.6, blue: 0.4),
                        Color(red: 0.4, green: 0.8, blue: 1.0)
                    ],
                    startPoint: shift ? .topLeading : .bottomTrailing,
                    endPoint: shift ? .bottomTrailing : .topLeading
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
            }
            .frame(width: 110, height: 70)
            .rotation3DEffect(.degrees(shift ? 12 : -12), axis: (0, 1, 0))
            .shadow(color: .purple.opacity(0.6), radius: 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: shift)
            .onAppear { shift = true }
    }
}

// MARK: - 3D Parallax Card

struct ParallaxCardPreview: View {
    @State private var x: Double = 0
    @State private var y: Double = 0
    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.cyan, Color.purple, Color.pink],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .frame(width: 130, height: 80)
            .rotation3DEffect(.degrees(y), axis: (1, 0, 0))
            .rotation3DEffect(.degrees(x), axis: (0, 1, 0))
            .shadow(radius: 14, y: 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    x = 14
                    y = -10
                }
            }
    }
}

// MARK: - Glitch Text

struct GlitchTextPreview: View {
    @State private var jitter = false
    var body: some View {
        ZStack {
            Text("GLITCH")
                .font(.system(size: 28, weight: .heavy, design: .monospaced))
                .foregroundStyle(.cyan)
                .offset(x: jitter ? -2 : 1, y: jitter ? 1 : -1)
                .blendMode(.screen)
            Text("GLITCH")
                .font(.system(size: 28, weight: .heavy, design: .monospaced))
                .foregroundStyle(.red)
                .offset(x: jitter ? 2 : -1, y: jitter ? -1 : 1)
                .blendMode(.screen)
            Text("GLITCH")
                .font(.system(size: 28, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.18).repeatForever(autoreverses: true)) {
                jitter = true
            }
        }
    }
}

// MARK: - Morphing FAB

struct MorphingFabPreview: View {
    @State private var open = false
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: open ? 14 : 30, style: .continuous)
                .fill(Theme.Palette.accent)
                .frame(width: open ? 130 : 56, height: open ? 56 : 56)
                .shadow(color: Theme.Palette.accent.opacity(0.45), radius: 16, y: 6)
            HStack(spacing: 8) {
                Image(systemName: open ? "checkmark" : "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                if open {
                    Text("Saved")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .transition(.opacity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.5, dampingFraction: 0.65), value: open)
        .task { await runLoop() }
    }
    @MainActor
    private func runLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            open.toggle()
        }
    }
}
