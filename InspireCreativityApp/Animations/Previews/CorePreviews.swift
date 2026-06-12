//
//  CorePreviews.swift
//  InspireCreativityApp
//
//  Hand-coded SwiftUI animations approximating the prototype's `previews.jsx`.
//  Every view is self-contained: starts animating in `.onAppear`, loops forever.
//

import SwiftUI

// MARK: - Spring Button

struct SpringButtonPreview: View {
    @State private var pressed = false
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.Palette.accent)
                .frame(width: 120, height: 44)
                .scaleEffect(pressed ? 0.92 : 1)
                .shadow(color: Theme.Palette.accent.opacity(0.35), radius: 12, y: 6)
                .overlay {
                    Text("Continue")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await runLoop() }
    }
    @MainActor
    private func runLoop() async {
        while !Task.isCancelled {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) { pressed = true }
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) { pressed = false }
            try? await Task.sleep(nanoseconds: 900_000_000)
        }
    }
}

// MARK: - Heart Burst

struct HeartBurstPreview: View {
    @State private var liked = false
    @State private var burst = false
    private let colors: [Color] = [.pink, .orange, .yellow, .red]
    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                Circle()
                    .fill(colors[i % colors.count])
                    .frame(width: 6, height: 6)
                    .offset(
                        x: burst ? cos(Double(i) * .pi / 4) * 32 : 0,
                        y: burst ? sin(Double(i) * .pi / 4) * 32 : 0
                    )
                    .opacity(burst ? 0 : 1)
            }
            .animation(.easeOut(duration: 0.7), value: burst)

            Image(systemName: liked ? "heart.fill" : "heart")
                .font(.system(size: 38))
                .foregroundStyle(liked ? .red : .secondary)
                .scaleEffect(liked ? 1.0 : 0.85)
                .animation(.spring(response: 0.35, dampingFraction: 0.45), value: liked)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await runLoop() }
    }
    @MainActor
    private func runLoop() async {
        while !Task.isCancelled {
            liked.toggle()
            burst = true
            try? await Task.sleep(nanoseconds: 700_000_000)
            burst = false
            try? await Task.sleep(nanoseconds: 900_000_000)
        }
    }
}

// MARK: - Gradient Spinner

struct GradientSpinnerPreview: View {
    @State private var rotation: Double = 0
    var body: some View {
        Circle()
            .strokeBorder(
                AngularGradient(
                    colors: [.clear, Theme.Palette.accent, Theme.Palette.accent.opacity(0.1)],
                    center: .center
                ),
                lineWidth: 4
            )
            .frame(width: 52, height: 52)
            .rotationEffect(.degrees(rotation))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

// MARK: - Pull to Refresh

struct PullRefreshPreview: View {
    @State private var progress: CGFloat = 0
    @State private var refreshing = false
    var body: some View {
        ZStack {
            if !refreshing {
                Image(systemName: "arrow.down")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.Palette.accent)
                    .rotationEffect(.degrees(progress * 180))
            } else {
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Theme.Palette.accent, lineWidth: 3)
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(progress * 720))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await runLoop() }
    }
    @MainActor
    private func runLoop() async {
        while !Task.isCancelled {
            withAnimation(.easeOut(duration: 0.8)) { progress = 1 }
            try? await Task.sleep(nanoseconds: 800_000_000)
            refreshing = true
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            refreshing = false
            withAnimation(.easeIn(duration: 0.3)) { progress = 0 }
            try? await Task.sleep(nanoseconds: 600_000_000)
        }
    }
}

// MARK: - 3D Card Flip

struct CardFlipPreview: View {
    @State private var flipped = false
    var body: some View {
        ZStack {
            // Front
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.purple, Color.indigo],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .opacity(flipped ? 0 : 1)
                .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (0, 1, 0))
            // Back
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.7))
                .overlay {
                    VStack(spacing: 4) {
                        Rectangle().fill(Color.white.opacity(0.2)).frame(height: 14)
                        Rectangle().fill(Color.white.opacity(0.15)).frame(width: 60, height: 8)
                    }
                    .padding()
                }
                .opacity(flipped ? 1 : 0)
                .rotation3DEffect(.degrees(flipped ? 0 : -180), axis: (0, 1, 0))
        }
        .frame(width: 110, height: 70)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await runLoop() }
    }
    @MainActor
    private func runLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { flipped.toggle() }
        }
    }
}

// MARK: - Wave Loader

struct WaveLoaderPreview: View {
    @State private var phase: CGFloat = 0
    private let progress: Double = 0.62
    var body: some View {
        Circle()
            .strokeBorder(Color.white.opacity(0.18), lineWidth: 2)
            .background(
                WaveShape(phase: phase, amplitude: 6)
                    .fill(Theme.Palette.accent)
                    .offset(y: (1 - progress) * 70)
                    .clipShape(Circle())
            )
            .frame(width: 70, height: 70)
            .overlay {
                Text("62%")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                    phase = .pi * 2
                }
            }
    }
}

struct WaveShape: Shape {
    var phase: CGFloat
    var amplitude: CGFloat
    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.midY))
        for x in stride(from: 0, through: rect.width, by: 1) {
            let rel = x / rect.width
            let y = sin(rel * .pi * 4 + phase) * amplitude + rect.midY
            p.addLine(to: CGPoint(x: x, y: y))
        }
        p.addLine(to: CGPoint(x: rect.width, y: rect.height))
        p.addLine(to: CGPoint(x: 0, y: rect.height))
        p.closeSubpath()
        return p
    }
}

// MARK: - Pulse Rings

struct PulseRingsPreview: View {
    @State private var animate = false
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(Theme.Palette.accent, lineWidth: 2)
                    .frame(width: 38, height: 38)
                    .scaleEffect(animate ? 2.2 : 0.4)
                    .opacity(animate ? 0 : 0.9)
                    .animation(
                        .easeOut(duration: 1.8)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.6),
                        value: animate
                    )
            }
            Circle().fill(Theme.Palette.accent).frame(width: 18, height: 18)
        }
        .frame(width: 90, height: 90)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { animate = true }
    }
}

// MARK: - Toast Drop

struct ToastPreview: View {
    @State private var show = false
    var body: some View {
        VStack {
            if show {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.Palette.success)
                    Text("Saved").font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.thinMaterial, in: Capsule())
                .shadow(radius: 12, y: 6)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .padding(.top, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await runLoop() }
    }
    @MainActor
    private func runLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 700_000_000)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { show = true }
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            withAnimation(.easeInOut(duration: 0.3)) { show = false }
        }
    }
}

// MARK: - Shimmer

struct ShimmerPreview: View {
    @State private var phase: CGFloat = -1
    var body: some View {
        VStack(spacing: 8) {
            shimmerBar(width: 110)
            shimmerBar(width: 80)
            shimmerBar(width: 130)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }

    private func shimmerBar(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.white.opacity(0.1))
            .frame(width: width, height: 10)
            .overlay {
                LinearGradient(
                    colors: [.clear, .white.opacity(0.35), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .offset(x: phase * 160)
                .mask(RoundedRectangle(cornerRadius: 4))
            }
    }
}

// MARK: - Number Ticker

struct NumberTickerPreview: View {
    @State private var value: Int = 1234
    var body: some View {
        Text("$\(value)")
            .font(.system(size: 30, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .contentTransition(.numericText(value: Double(value)))
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: value)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task { await runLoop() }
    }
    @MainActor
    private func runLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            value += Int.random(in: 1...20)
            if value > 2000 { value = 1100 }
        }
    }
}

// MARK: - Hamburger

struct HamburgerPreview: View {
    @State private var open = false
    var body: some View {
        ZStack {
            Capsule()
                .frame(width: 26, height: 3)
                .offset(y: open ? 0 : -8)
                .rotationEffect(.degrees(open ? 45 : 0))
            Capsule()
                .frame(width: 26, height: 3)
                .scaleEffect(x: open ? 0 : 1)
                .opacity(open ? 0 : 1)
            Capsule()
                .frame(width: 26, height: 3)
                .offset(y: open ? 0 : 8)
                .rotationEffect(.degrees(open ? -45 : 0))
        }
        .foregroundStyle(Theme.Palette.accent)
        .frame(width: 36, height: 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: open)
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

// MARK: - Typing Dots

struct TypingDotsPreview: View {
    @State private var bounce = false
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Theme.Palette.accent)
                    .frame(width: 8, height: 8)
                    .offset(y: bounce ? -6 : 0)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.15),
                        value: bounce
                    )
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 18, bottomLeadingRadius: 4,
                bottomTrailingRadius: 18, topTrailingRadius: 18
            )
            .fill(Color.gray.opacity(0.2))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { bounce = true }
    }
}

// MARK: - Liquid Tab Bar

struct LiquidTabsPreview: View {
    @State private var selection = 0
    private let icons = ["house.fill", "magnifyingglass", "heart.fill", "person.fill"]
    @Namespace private var ns
    var body: some View {
        HStack(spacing: 0) {
            ForEach(icons.indices, id: \.self) { i in
                Button { selection = i } label: {
                    ZStack {
                        if selection == i {
                            Capsule()
                                .fill(Theme.Palette.accent)
                                .matchedGeometryEffect(id: "pill", in: ns)
                                .shadow(color: Theme.Palette.accent.opacity(0.4), radius: 8, y: 4)
                        }
                        Image(systemName: icons[i])
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.thinMaterial, in: Capsule())
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: selection)
        .task { await runLoop() }
    }
    @MainActor
    private func runLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            selection = (selection + 1) % icons.count
        }
    }
}

// MARK: - Confetti

struct ConfettiPreview: View {
    @State private var go = false
    private let colors: [Color] = [.orange, .yellow, .pink, .blue, .purple, .green]
    var body: some View {
        ZStack {
            ForEach(0..<14, id: \.self) { i in
                let angle = Double(i) * (.pi * 2) / 14
                Rectangle()
                    .fill(colors[i % colors.count])
                    .frame(width: 6, height: 10)
                    .cornerRadius(1)
                    .offset(
                        x: go ? cos(angle) * 55 : 0,
                        y: go ? sin(angle) * 55 + 18 : 0
                    )
                    .rotationEffect(.degrees(go ? 360 : 0))
                    .opacity(go ? 0 : 1)
                    .animation(.easeOut(duration: 1.0), value: go)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await runLoop() }
    }
    @MainActor
    private func runLoop() async {
        while !Task.isCancelled {
            go = false
            try? await Task.sleep(nanoseconds: 50_000_000)
            go = true
            try? await Task.sleep(nanoseconds: 1_300_000_000)
        }
    }
}

// MARK: - Onboarding Swirl

struct OnboardingBlobPreview: View {
    @State private var r1: Double = 0
    @State private var r2: Double = 0
    var body: some View {
        ZStack {
            BlobShape()
                .fill(
                    LinearGradient(
                        colors: [Theme.Palette.accent, .pink.opacity(0.8)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .rotationEffect(.degrees(r1))
            BlobShape()
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.7), .purple.opacity(0.7)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .blendMode(.screen)
                .padding(10)
                .rotationEffect(.degrees(r2))
        }
        .frame(width: 96, height: 96)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) { r1 = 360 }
            withAnimation(.linear(duration: 11).repeatForever(autoreverses: false)) { r2 = -360 }
        }
    }
}

struct BlobShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let bumps = 6
        let inner = r * 0.78
        for i in 0..<(bumps * 2) {
            let theta = Double(i) / Double(bumps * 2) * .pi * 2
            let radius = (i % 2 == 0) ? r : inner
            let x = c.x + cos(theta) * radius
            let y = c.y + sin(theta) * radius
            if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
            else { p.addLine(to: CGPoint(x: x, y: y)) }
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Progress Arc

struct ProgressArcPreview: View {
    @State private var progress: Double = 0.0
    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.08), lineWidth: 6)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Theme.Palette.accent,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)
            Text(String(format: "%.0f%%", progress * 100))
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .contentTransition(.numericText(value: progress))
        }
        .frame(width: 80, height: 80)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await runLoop() }
    }
    @MainActor
    private func runLoop() async {
        while !Task.isCancelled {
            let target = Double.random(in: 0.3...0.95)
            progress = target
            try? await Task.sleep(nanoseconds: 1_300_000_000)
        }
    }
}
