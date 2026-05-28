//
//  AdvancedPreviews.swift
//  InspireCreativityApp
//
//  Advanced/physics previews: spring chain, throwable card, metal-like ripple.
//

import SwiftUI

// MARK: - Spring Chain

struct SpringChainPreview: View {
    @State private var leader: CGPoint = .zero
    @State private var followers: [CGPoint] = Array(repeating: .zero, count: 6)
    @State private var animateToTarget = false
    var body: some View {
        ZStack {
            // Trail
            ForEach(0..<followers.count, id: \.self) { i in
                Circle()
                    .fill(Theme.Palette.accent.opacity(1.0 - Double(i) * 0.13))
                    .frame(width: CGFloat(20 - i * 2), height: CGFloat(20 - i * 2))
                    .position(followers[i] == .zero ? CGPoint(x: 100, y: 60) : followers[i])
            }
            // Leader
            Circle()
                .fill(Color.white)
                .frame(width: 14, height: 14)
                .position(leader == .zero ? CGPoint(x: 100, y: 60) : leader)
                .shadow(color: Theme.Palette.accent, radius: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { runLoop() }
    }
    private func runLoop() {
        Task { @MainActor in
            let positions: [CGPoint] = [
                .init(x: 40, y: 30), .init(x: 160, y: 40),
                .init(x: 50, y: 90), .init(x: 150, y: 100)
            ]
            var idx = 0
            while !Task.isCancelled {
                let target = positions[idx % positions.count]
                withAnimation(.spring(response: 0.7, dampingFraction: 0.55)) {
                    leader = target
                }
                // Stagger the followers with delays
                for f in 0..<followers.count {
                    let delay = UInt64(80_000_000 * (f + 1))
                    try? await Task.sleep(nanoseconds: delay)
                    withAnimation(.spring(response: 0.7, dampingFraction: 0.55)) {
                        followers[f] = target
                    }
                }
                try? await Task.sleep(nanoseconds: 600_000_000)
                idx += 1
            }
        }
    }
}

// MARK: - Throwable Card

struct ThrowableCardPreview: View {
    @State private var offset: CGSize = .zero
    @State private var rotation: Double = 0
    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [.indigo, .purple, .pink],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: "hand.point.up.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(width: 110, height: 70)
            .rotationEffect(.degrees(rotation))
            .offset(offset)
            .shadow(radius: 12, y: 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { runLoop() }
    }
    private func runLoop() {
        Task { @MainActor in
            while !Task.isCancelled {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) {
                    offset = CGSize(width: 30, height: -8)
                    rotation = 6
                }
                try? await Task.sleep(nanoseconds: 600_000_000)
                withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) {
                    offset = CGSize(width: -28, height: 6)
                    rotation = -8
                }
                try? await Task.sleep(nanoseconds: 700_000_000)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    offset = .zero
                    rotation = 0
                }
                try? await Task.sleep(nanoseconds: 800_000_000)
            }
        }
    }
}

// MARK: - Liquid Ripple

struct LiquidRipplePreview: View {
    @State private var phase: CGFloat = 0
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.1, blue: 0.2), Color.black],
                startPoint: .top, endPoint: .bottom
            )
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(Color.cyan.opacity(0.6 - Double(i) * 0.18), lineWidth: 1.5)
                    .frame(width: 30 + CGFloat(i) * 30, height: 30 + CGFloat(i) * 30)
                    .scaleEffect(1.0 + phase * 0.3)
                    .opacity(1.0 - phase)
            }
            .blur(radius: 0.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeOut(duration: 2.2).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}
