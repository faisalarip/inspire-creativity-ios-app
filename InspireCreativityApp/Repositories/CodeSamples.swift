//
//  CodeSamples.swift
//  InspireCreativityApp
//
//  Swift source snippets shown in the Detail screen's bottom sheet.
//  These are the actual "product" the catalog sells. Copy-paste runnable.
//

import Foundation

/// Namespaced raw Swift source strings. Mirrors `SWIFT_CODE` in the prototype.
enum Code {

    static let springButton = #"""
    import SwiftUI

    struct SpringPressStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
                .animation(.spring(response: 0.32, dampingFraction: 0.55),
                           value: configuration.isPressed)
        }
    }

    extension View {
        func springPress() -> some View {
            buttonStyle(SpringPressStyle())
        }
    }

    // Usage
    struct ContentView: View {
        var body: some View {
            Button("Continue") { /* action */ }
                .padding(.horizontal, 30)
                .padding(.vertical, 14)
                .background(Color.accentColor, in: .rect(cornerRadius: 14))
                .foregroundStyle(.white)
                .springPress()
        }
    }
    """#

    static let heartBurst = #"""
    import SwiftUI

    struct HeartBurstButton: View {
        @State private var liked = false
        @State private var burst = false
        let colors: [Color] = [.pink, .orange, .yellow, .red]

        var body: some View {
            ZStack {
                ForEach(0..<8, id: \.self) { i in
                    Circle()
                        .fill(colors[i % colors.count])
                        .frame(width: 6, height: 6)
                        .offset(
                            x: burst ? cos(Double(i) * .pi / 4) * 28 : 0,
                            y: burst ? sin(Double(i) * .pi / 4) * 28 : 0
                        )
                        .opacity(burst ? 0 : 1)
                        .animation(.easeOut(duration: 0.6).delay(0.05), value: burst)
                }

                Image(systemName: liked ? "heart.fill" : "heart")
                    .font(.system(size: 38))
                    .foregroundStyle(liked ? .red : .secondary)
                    .scaleEffect(liked ? 1.0 : 0.85)
                    .animation(.spring(response: 0.35, dampingFraction: 0.45), value: liked)
            }
            .onTapGesture {
                liked.toggle()
                burst = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { burst = false }
            }
        }
    }
    """#

    static let spinner = #"""
    import SwiftUI

    struct GradientSpinner: View {
        @State private var spinning = false

        var body: some View {
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [.clear, .accentColor, .accentColor.opacity(0.1)],
                        center: .center
                    ),
                    lineWidth: 4
                )
                .frame(width: 52, height: 52)
                .rotationEffect(.degrees(spinning ? 360 : 0))
                .animation(.linear(duration: 1.1).repeatForever(autoreverses: false),
                           value: spinning)
                .onAppear { spinning = true }
        }
    }
    """#

    static let pullRefresh = #"""
    import SwiftUI

    struct PullRefreshHeader: View {
        let progress: CGFloat   // 0...1 from scroll offset
        let isRefreshing: Bool

        var body: some View {
            ZStack {
                Image(systemName: "arrow.down")
                    .font(.system(size: 18, weight: .semibold))
                    .rotationEffect(.degrees(progress * 180))
                    .opacity(isRefreshing ? 0 : 1)
                    .animation(.spring(response: 0.3), value: progress)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.accentColor, lineWidth: 2.4)
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    .opacity(isRefreshing ? 1 : 0)
            }
            .frame(height: 60)
        }
    }
    """#

    static let cardFlip = #"""
    import SwiftUI

    struct FlipCard<Front: View, Back: View>: View {
        @Binding var flipped: Bool
        @ViewBuilder var front: () -> Front
        @ViewBuilder var back: () -> Back

        var body: some View {
            ZStack {
                front()
                    .opacity(flipped ? 0 : 1)
                    .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                back()
                    .opacity(flipped ? 1 : 0)
                    .rotation3DEffect(.degrees(flipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.75), value: flipped)
        }
    }
    """#

    static let waveLoader = #"""
    import SwiftUI

    struct WaveShape: Shape {
        var phase: CGFloat
        var amplitude: CGFloat = 6

        var animatableData: CGFloat {
            get { phase }
            set { phase = newValue }
        }

        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: rect.midY))
            for x in stride(from: 0, through: rect.width, by: 1) {
                let relative = x / rect.width
                let y = sin(relative * .pi * 4 + phase) * amplitude + rect.midY
                path.addLine(to: CGPoint(x: x, y: y))
            }
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.closeSubpath()
            return path
        }
    }

    struct WaveLoader: View {
        let progress: Double  // 0...1
        @State private var phase: CGFloat = 0

        var body: some View {
            Circle()
                .strokeBorder(.white.opacity(0.18), lineWidth: 2)
                .background(
                    WaveShape(phase: phase)
                        .fill(Color.accentColor)
                        .offset(y: (1 - progress) * 70)
                        .clipShape(Circle())
                )
                .frame(width: 70, height: 70)
                .onAppear {
                    withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                        phase = .pi * 2
                    }
                }
        }
    }
    """#

    static let pulseRings = #"""
    import SwiftUI

    struct PulseRings: View {
        @State private var animate = false

        var body: some View {
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color.accentColor, lineWidth: 2)
                        .scaleEffect(animate ? 2.2 : 0.4)
                        .opacity(animate ? 0 : 0.9)
                        .animation(
                            .easeOut(duration: 1.8)
                                .repeatForever(autoreverses: false)
                                .delay(Double(i) * 0.6),
                            value: animate
                        )
                }
                Circle().fill(Color.accentColor).frame(width: 18, height: 18)
            }
            .frame(width: 80, height: 80)
            .onAppear { animate = true }
        }
    }
    """#

    static let toast = #"""
    import SwiftUI

    struct Toast: View {
        let message: String
        @Binding var isShown: Bool

        var body: some View {
            VStack {
                if isShown {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(message).font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: .capsule)
                    .shadow(radius: 12, y: 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }
            .padding(.top, 12)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isShown)
        }
    }
    """#

    static let shimmer = #"""
    import SwiftUI

    struct Shimmer: ViewModifier {
        @State private var phase: CGFloat = -1

        func body(content: Content) -> some View {
            content
                .overlay(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.25), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .rotationEffect(.degrees(20))
                    .offset(x: phase * 300)
                    .blendMode(.plusLighter)
                )
                .mask(content)
                .onAppear {
                    withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
        }
    }

    extension View {
        func shimmer() -> some View { modifier(Shimmer()) }
    }
    """#

    static let ticker = #"""
    import SwiftUI

    struct NumberTicker: View {
        let value: Int
        let format: String  // e.g. "$%@"

        var body: some View {
            Text(String(format: format, "\(value)"))
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .contentTransition(.numericText(value: Double(value)))
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: value)
        }
    }
    """#

    static let hamburger = #"""
    import SwiftUI

    struct HamburgerIcon: View {
        @Binding var open: Bool

        var body: some View {
            ZStack {
                Capsule()
                    .frame(width: 22, height: 2.4)
                    .offset(y: open ? 0 : -6)
                    .rotationEffect(.degrees(open ? 45 : 0))
                Capsule()
                    .frame(width: 22, height: 2.4)
                    .scaleEffect(x: open ? 0 : 1)
                    .opacity(open ? 0 : 1)
                Capsule()
                    .frame(width: 22, height: 2.4)
                    .offset(y: open ? 0 : 6)
                    .rotationEffect(.degrees(open ? -45 : 0))
            }
            .foregroundStyle(Color.accentColor)
            .frame(width: 32, height: 32)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: open)
        }
    }
    """#

    static let typing = #"""
    import SwiftUI

    struct TypingDots: View {
        @State private var bounce = false

        var body: some View {
            HStack(spacing: 6) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 7, height: 7)
                        .offset(y: bounce ? -6 : 0)
                        .animation(
                            .easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.15),
                            value: bounce
                        )
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            .background(.gray.opacity(0.15),
                        in: .rect(topLeadingRadius: 18, bottomLeadingRadius: 4,
                                  bottomTrailingRadius: 18, topTrailingRadius: 18))
            .onAppear { bounce = true }
        }
    }
    """#

    static let liquidTabs = #"""
    import SwiftUI

    struct LiquidTabBar: View {
        @Binding var selection: Int
        let icons: [String]
        @Namespace private var ns

        var body: some View {
            HStack(spacing: 0) {
                ForEach(icons.indices, id: \.self) { i in
                    Button { selection = i } label: {
                        ZStack {
                            if selection == i {
                                Capsule()
                                    .fill(Color.accentColor)
                                    .matchedGeometryEffect(id: "pill", in: ns)
                                    .shadow(color: .accentColor.opacity(0.4), radius: 8, y: 4)
                            }
                            Image(systemName: icons[i])
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity, minHeight: 36)
                    }
                }
            }
            .padding(4)
            .background(.thinMaterial, in: .capsule)
            .animation(.spring(response: 0.45, dampingFraction: 0.7), value: selection)
        }
    }
    """#

    static let confetti = #"""
    import SwiftUI

    struct ConfettiPiece: View {
        let color: Color
        let angle: Double
        let trigger: Bool

        var body: some View {
            Rectangle()
                .fill(color)
                .frame(width: 6, height: 9)
                .cornerRadius(1)
                .offset(
                    x: trigger ? cos(angle) * 50 : 0,
                    y: trigger ? sin(angle) * 50 + 18 : 0
                )
                .rotationEffect(.degrees(trigger ? 360 : 0))
                .opacity(trigger ? 0 : 1)
                .animation(.easeOut(duration: 1.0), value: trigger)
        }
    }

    struct ConfettiBurst: View {
        @State private var go = false
        let colors: [Color] = [.orange, .yellow, .pink, .blue, .purple, .green]

        var body: some View {
            ZStack {
                ForEach(0..<14, id: \.self) { i in
                    ConfettiPiece(
                        color: colors[i % colors.count],
                        angle: Double(i) * (.pi * 2) / 14,
                        trigger: go
                    )
                }
            }
            .onTapGesture { go = false; DispatchQueue.main.async { go = true } }
        }
    }
    """#

    static let onboarding = #"""
    import SwiftUI

    struct OnboardingBlob: View {
        @State private var rotate1 = false
        @State private var rotate2 = false

        var body: some View {
            ZStack {
                BlobShape()
                    .fill(LinearGradient(
                        colors: [.accentColor, .pink.opacity(0.8)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .rotationEffect(.degrees(rotate1 ? 360 : 0))

                BlobShape()
                    .fill(LinearGradient(
                        colors: [.blue.opacity(0.7), .purple.opacity(0.7)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .blendMode(.screen)
                    .padding(8)
                    .rotationEffect(.degrees(rotate2 ? -360 : 0))
            }
            .frame(width: 80, height: 80)
            .onAppear {
                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) { rotate1 = true }
                withAnimation(.linear(duration: 11).repeatForever(autoreverses: false)) { rotate2 = true }
            }
        }
    }
    """#

    static let progressArc = #"""
    import SwiftUI

    struct ProgressArc: View {
        let progress: Double  // 0...1

        var body: some View {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.accentColor,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: progress)
                Text(progress, format: .percent.precision(.fractionLength(0)))
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .frame(width: 80, height: 80)
        }
    }
    """#

    // MARK: - Creative

    static let auroraMesh = #"""
    import SwiftUI

    @available(iOS 18, *)
    struct AuroraMeshBackground: View {
        @State private var t: CGFloat = 0

        var body: some View {
            MeshGradient(
                width: 3, height: 3,
                points: meshPoints(t),
                colors: [
                    .indigo, .purple, .pink,
                    .blue, .purple, .orange,
                    .cyan, .indigo, .pink
                ]
            )
            .onAppear {
                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                    t = 1
                }
            }
        }

        private func meshPoints(_ t: CGFloat) -> [SIMD2<Float>] {
            let s = Float(sin(t * .pi * 2)) * 0.1
            let c = Float(cos(t * .pi * 2)) * 0.1
            return [
                .init(0, 0),   .init(0.5, 0.05 + s), .init(1, 0),
                .init(0, 0.5), .init(0.55 + s, 0.5), .init(1, 0.5 + s),
                .init(0, 1),   .init(0.5, 0.95 - s), .init(1, 1)
            ]
        }
    }
    """#

    static let liquidHeart = #"""
    import SwiftUI

    struct LiquidHeart: View {
        @State private var pulse = false

        var body: some View {
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
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }
        }
    }
    """#

    static let elasticTabs = #"""
    import SwiftUI

    struct ElasticTabs: View {
        @Binding var selection: Int
        let labels: [String]
        @Namespace private var ns

        var body: some View {
            HStack(spacing: 4) {
                ForEach(labels.indices, id: \.self) { i in
                    Button { selection = i } label: {
                        Text(labels[i])
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(selection == i ? .white : .secondary)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background {
                                if selection == i {
                                    Capsule().fill(.accent)
                                        .matchedGeometryEffect(id: "tab", in: ns)
                                }
                            }
                    }
                }
            }
            .padding(4)
            .background(.regularMaterial, in: .capsule)
            .animation(.spring(response: 0.45, dampingFraction: 0.65), value: selection)
        }
    }
    """#

    static let hologramCard = #"""
    import SwiftUI

    struct HologramCard: View {
        @State private var shift = false

        var body: some View {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.cyan, .purple, .orange, .cyan],
                        startPoint: shift ? .topLeading : .bottomTrailing,
                        endPoint: shift ? .bottomTrailing : .topLeading
                    )
                )
                .rotation3DEffect(.degrees(shift ? 12 : -12), axis: (0, 1, 0))
                .shadow(color: .purple.opacity(0.6), radius: 18)
                .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                           value: shift)
                .onAppear { shift = true }
        }
    }
    """#

    static let parallaxCard = #"""
    import SwiftUI

    struct ParallaxCard: View {
        @State private var dragOffset: CGSize = .zero

        var body: some View {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(
                    colors: [.cyan, .purple, .pink],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 220, height: 140)
                .rotation3DEffect(
                    .degrees(Double(dragOffset.width / 14)),
                    axis: (0, 1, 0)
                )
                .rotation3DEffect(
                    .degrees(-Double(dragOffset.height / 14)),
                    axis: (1, 0, 0)
                )
                .gesture(
                    DragGesture()
                        .onChanged { dragOffset = $0.translation }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                                dragOffset = .zero
                            }
                        }
                )
        }
    }
    """#

    static let glitchText = #"""
    import SwiftUI

    struct GlitchText: View {
        let text: String
        @State private var jitter = false

        var body: some View {
            ZStack {
                Text(text).foregroundStyle(.cyan)
                    .offset(x: jitter ? -2 : 1, y: jitter ? 1 : -1)
                    .blendMode(.screen)
                Text(text).foregroundStyle(.red)
                    .offset(x: jitter ? 2 : -1, y: jitter ? -1 : 1)
                    .blendMode(.screen)
                Text(text).foregroundStyle(.white)
            }
            .font(.system(size: 36, weight: .heavy, design: .monospaced))
            .onAppear {
                withAnimation(.easeInOut(duration: 0.18).repeatForever(autoreverses: true)) {
                    jitter = true
                }
            }
        }
    }
    """#

    static let morphingFab = #"""
    import SwiftUI

    struct MorphingFab: View {
        @State private var saved = false

        var body: some View {
            Button { withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { saved.toggle() } } label: {
                HStack(spacing: 8) {
                    Image(systemName: saved ? "checkmark" : "plus")
                        .font(.system(size: 20, weight: .bold))
                    if saved {
                        Text("Saved").font(.system(size: 14, weight: .bold))
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, saved ? 18 : 18).padding(.vertical, 18)
                .background(.accent, in: .rect(cornerRadius: saved ? 14 : 30, style: .continuous))
                .shadow(color: .accent.opacity(0.45), radius: 16, y: 6)
            }
        }
    }
    """#

    // MARK: - Aurora

    static let auroraBorealis = #"""
    import SwiftUI

    @available(iOS 18, *)
    struct AuroraBorealis: View {
        @State private var t: CGFloat = 0

        var body: some View {
            ZStack {
                Color.black
                MeshGradient(
                    width: 3, height: 3,
                    points: animatedPoints(t),
                    colors: [
                        .black, .black, .black,
                        .green, .cyan, .blue,
                        .black, .black, .black
                    ]
                )
                .blur(radius: 12)
                .blendMode(.screen)
            }
            .onAppear {
                withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) { t = 1 }
            }
        }

        private func animatedPoints(_ t: CGFloat) -> [SIMD2<Float>] {
            let s = Float(sin(t * .pi * 2)) * 0.08
            return [
                .init(0, 0), .init(0.5, 0), .init(1, 0),
                .init(0, 0.5 + s), .init(0.5, 0.5 - s), .init(1, 0.5 + s),
                .init(0, 1), .init(0.5, 1), .init(1, 1)
            ]
        }
    }
    """#

    static let liquidChrome = #"""
    import SwiftUI

    struct LiquidChrome: View {
        @State private var t: CGFloat = 0

        var body: some View {
            LinearGradient(
                colors: [
                    Color(white: 0.15), Color(white: 0.65),
                    Color(white: 0.3),  Color(white: 0.85),
                    Color(white: 0.25)
                ],
                startPoint: UnitPoint(x: t, y: 0),
                endPoint:   UnitPoint(x: 1 - t, y: 1)
            )
            .hueRotation(.degrees(t * 90))
            .blur(radius: 4)
            .onAppear {
                withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) { t = 1 }
            }
        }
    }
    """#

    static let auroraPulse = #"""
    import SwiftUI

    struct AuroraPulse: View {
        @State private var pulse = false
        private let palette: [Color] = [.purple, .pink, .blue, .cyan, .indigo]

        var body: some View {
            ZStack {
                Color(red: 0.03, green: 0.03, blue: 0.1)
                ForEach(0..<5, id: \.self) { i in
                    Circle()
                        .fill(RadialGradient(
                            colors: [palette[i].opacity(0.6), .clear],
                            center: .center, startRadius: 4, endRadius: 80
                        ))
                        .frame(width: 160, height: 160)
                        .offset(
                            x: pulse ? CGFloat(cos(Double(i)) * 30) : CGFloat(sin(Double(i)) * 30),
                            y: pulse ? CGFloat(sin(Double(i)) * 30) : CGFloat(cos(Double(i)) * 30)
                        )
                        .blendMode(.screen)
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
    }
    """#

    static let lavaFlow = #"""
    import SwiftUI

    struct LavaFlow: View {
        @State private var t: CGFloat = 0

        var body: some View {
            ZStack {
                Color.black
                ForEach(0..<6, id: \.self) { i in
                    let phase = t + CGFloat(i) * 0.16
                    Circle()
                        .fill(RadialGradient(
                            colors: [.orange, .red.opacity(0.6), .clear],
                            center: .center, startRadius: 4, endRadius: 60
                        ))
                        .frame(width: 100, height: 100)
                        .offset(
                            x: cos(phase * .pi * 2) * 40,
                            y: sin(phase * .pi * 2) * 30
                        )
                        .blur(radius: 6)
                        .blendMode(.screen)
                }
            }
            .onAppear {
                withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) { t = 1 }
            }
        }
    }
    """#

    // MARK: - Advanced

    static let springChain = #"""
    import SwiftUI

    struct SpringChain: View {
        @State private var leader: CGPoint = .zero
        @State private var followers: [CGPoint] = Array(repeating: .zero, count: 6)

        var body: some View {
            ZStack {
                ForEach(0..<followers.count, id: \.self) { i in
                    Circle()
                        .fill(Color.accentColor.opacity(1.0 - Double(i) * 0.13))
                        .frame(width: CGFloat(20 - i * 2))
                        .position(followers[i])
                }
                Circle()
                    .fill(.white)
                    .frame(width: 16)
                    .position(leader)
            }
            .gesture(
                DragGesture()
                    .onChanged { g in
                        leader = g.location
                        for i in 0..<followers.count {
                            withAnimation(.spring(response: 0.5 + Double(i) * 0.1,
                                                  dampingFraction: 0.6)) {
                                followers[i] = g.location
                            }
                        }
                    }
            )
        }
    }
    """#

    static let throwableCard = #"""
    import SwiftUI

    struct ThrowableCard: View {
        @State private var offset: CGSize = .zero
        @GestureState private var dragOffset: CGSize = .zero

        var body: some View {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.linearGradient(colors: [.indigo, .purple, .pink],
                                      startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 220, height: 280)
                .offset(CGSize(width: offset.width + dragOffset.width,
                               height: offset.height + dragOffset.height))
                .rotationEffect(.degrees(Double(offset.width + dragOffset.width) / 22))
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { v, s, _ in s = v.translation }
                        .onEnded { v in
                            let velocity = v.predictedEndTranslation
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
                                if abs(velocity.width) > 240 {
                                    offset.width = velocity.width * 2
                                } else {
                                    offset = .zero
                                }
                            }
                        }
                )
        }
    }
    """#

    static let liquidRipple = #"""
    import SwiftUI

    /// Ripple distortion using SwiftUI's `Shader` + a Metal shader function
    /// `ripple(_:_:_:)`. Tap to spawn a ripple from the touch location.
    struct LiquidRipple: View {
        @State private var origin: CGPoint = .zero
        @State private var time: Float = 0

        var body: some View {
            Image("hero")
                .resizable()
                .scaledToFill()
                .visualEffect { content, proxy in
                    content.distortionEffect(
                        ShaderLibrary.ripple(
                            .float2(origin),
                            .float(time),
                            .float2(proxy.size)
                        ),
                        maxSampleOffset: CGSize(width: 24, height: 24)
                    )
                }
                .onTapGesture { location in
                    origin = location
                    time = 0
                    withAnimation(.linear(duration: 2.2)) { time = 1 }
                }
        }
    }
    """#
}
