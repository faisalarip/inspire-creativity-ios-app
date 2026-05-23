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
