//
//  AnimationPreviewRegistry.swift
//  InspireCreativityApp
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

    /// Runtime aurora descriptors added after launch — e.g. rows loaded from
    /// Supabase that include a `palette` field. Populated on the main actor
    /// by `RemoteAnimationRepository`; read only on the main actor.
    static var runtimeDescriptors: [String: AuroraDescriptor] = [:]

    /// Returns the preview view for a given id, or a fallback placeholder.
    /// Every preview is wrapped in `PreviewStage` so subtrees marked paused
    /// (hidden tabs, inactive scene) stop rendering entirely.
    @ViewBuilder
    static func view(for id: String) -> some View {
        PreviewStage {
            if let make = builders[id] {
                make()
            } else if let make = BespokeAnimations.gridBuilders[id] {
                make()
            } else if let descriptor = AuroraDescriptors.byId[id] {
                ParametricAuroraPreview(descriptor: descriptor)
            } else if let descriptor = runtimeDescriptors[id] {
                ParametricAuroraPreview(descriptor: descriptor)
            } else {
                PlaceholderPreview(id: id)
            }
        }
    }

    /// Preview for the large Detail surface. Bespoke animations supply a real,
    /// finger-interactive variant here; everything else falls back to the
    /// self-driving grid loop from `view(for:)`.
    @ViewBuilder
    static func interactiveView(for id: String) -> some View {
        if let make = BespokeAnimations.interactiveBuilders[id] {
            PreviewStage { make() }
        } else {
            view(for: id)
        }
    }

    /// Whether `interactiveView(for:)` returns a genuinely finger-driven
    /// component (a bespoke animation) rather than a self-driving loop. The
    /// Detail screen uses this to surface a one-time "tap & drag" hint only
    /// where interaction actually does something.
    static func isInteractive(_ id: String) -> Bool {
        BespokeAnimations.interactiveBuilders[id] != nil
    }
}

// MARK: - Power management

private struct PreviewsPausedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True when animation previews in this subtree must stop rendering.
    /// RootView sets it for hidden tabs and inactive scenes: every preview is
    /// `repeatForever`/loop-driven, so leaving them mounted off-screen keeps
    /// the GPU redrawing continuously (device heat + battery drain).
    var previewsPaused: Bool {
        get { self[PreviewsPausedKey.self] }
        set { self[PreviewsPausedKey.self] = newValue }
    }
}

/// Swaps a live preview for a static fill while paused. Unmounting the
/// preview subtree stops its `repeatForever` animations and cancels its
/// `.task` drive loops; remounting restarts the animation from scratch,
/// which is fine for decorative previews.
private struct PreviewStage<Content: View>: View {
    @Environment(\.previewsPaused) private var paused
    @ViewBuilder let content: () -> Content

    var body: some View {
        if paused {
            Color.black
        } else {
            content()
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
