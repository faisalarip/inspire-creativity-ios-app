//
//  AnimationPreviewRegistry.swift
//  StaggerApp
//
//  Maps animation IDs to their preview SwiftUI views. Using a closure-typed
//  registry instead of `some View` lets the data layer reference previews
//  without leaking concrete view types into the domain layer.
//

import SwiftUI

/// Factory closure that produces a type-erased preview view.
typealias PreviewBuilder = () -> AnyView

/// Central lookup of `id -> preview`.
enum AnimationPreviewRegistry {

    /// All known preview builders keyed by animation id.
    static let builders: [String: PreviewBuilder] = [
        // Originals (previews.jsx)
        "spring-button":  { AnyView(SpringButtonPreview()) },
        "heart-burst":    { AnyView(HeartBurstPreview()) },
        "spinner":        { AnyView(GradientSpinnerPreview()) },
        "pull-refresh":   { AnyView(PullRefreshPreview()) },
        "card-flip":      { AnyView(CardFlipPreview()) },
        "wave-loader":    { AnyView(WaveLoaderPreview()) },
        "pulse-rings":    { AnyView(PulseRingsPreview()) },
        "toast":          { AnyView(ToastPreview()) },
        "shimmer":        { AnyView(ShimmerPreview()) },
        "ticker":         { AnyView(NumberTickerPreview()) },
        "hamburger":      { AnyView(HamburgerPreview()) },
        "typing":         { AnyView(TypingDotsPreview()) },
        "liquid-tabs":    { AnyView(LiquidTabsPreview()) },
        "confetti":       { AnyView(ConfettiPreview()) },
        "onboarding":     { AnyView(OnboardingBlobPreview()) },
        "progress-arc":   { AnyView(ProgressArcPreview()) },

        // Creative (previews-creative.jsx)
        "aurora-mesh":    { AnyView(AuroraMeshPreview()) },
        "liquid-heart":   { AnyView(LiquidHeartPreview()) },
        "elastic-tabs":   { AnyView(ElasticTabsPreview()) },
        "hologram-card":  { AnyView(HologramCardPreview()) },
        "parallax-card":  { AnyView(ParallaxCardPreview()) },
        "glitch-text":    { AnyView(GlitchTextPreview()) },
        "morphing-fab":   { AnyView(MorphingFabPreview()) },

        // Aurora (previews-aurora.jsx)
        "aurora-borealis": { AnyView(AuroraBorealisPreview()) },
        "liquid-chrome":   { AnyView(LiquidChromePreview()) },
        "aurora-pulse":    { AnyView(AuroraPulsePreview()) },
        "lava-flow":       { AnyView(LavaFlowPreview()) },

        // Advanced (previews-advanced.jsx)
        "spring-chain":   { AnyView(SpringChainPreview()) },
        "throwable-card": { AnyView(ThrowableCardPreview()) },
        "liquid-ripple":  { AnyView(LiquidRipplePreview()) }
    ]

    /// Returns the preview view for a given id, or a fallback placeholder.
    @ViewBuilder
    static func view(for id: String) -> some View {
        if let make = builders[id] {
            make()
        } else {
            PlaceholderPreview(id: id)
        }
    }
}

private struct PlaceholderPreview: View {
    let id: String
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.purple.opacity(0.4), .blue.opacity(0.4)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Image(systemName: "sparkles")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
