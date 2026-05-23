//
//  AnimationCatalogSeed.swift
//  StaggerApp
//
//  Seeded animation catalog. Mirrors `ANIMATIONS` + `SWIFT_CODE` from the
//  prototype. ~30 entries spanning all categories.
//

import Foundation

/// Static catalog used to seed `InMemoryAnimationRepository`.
enum AnimationCatalogSeed {

    static let items: [AnimationItem] = [
        // MARK: - Core (previews.jsx)
        .init(
            id: "spring-button", name: "Spring Button",
            category: .buttons, difficulty: .beginner, iosVersion: "17+",
            isPro: false, isFeatured: false, tintHex: "#1e1e22",
            author: "Maya Ortega", handle: "@mortega.dev",
            downloads: 12_480, rating: 4.9, price: nil,
            description: "A satisfying tactile press with a spring overshoot. Reusable as a ViewModifier you can attach to any view.",
            swiftCode: Code.springButton
        ),
        .init(
            id: "heart-burst", name: "Heart Burst",
            category: .microInteractions, difficulty: .intermediate, iosVersion: "17+",
            isPro: true, isFeatured: false, tintHex: "#241820",
            author: "Kenji Saito", handle: "@kenji.codes",
            downloads: 8_920, rating: 4.8, price: 4.99,
            description: "Twitter-style heart with a haptic-feeling spring + particle burst. Customizable colors and particle count.",
            swiftCode: Code.heartBurst
        ),
        .init(
            id: "spinner", name: "Gradient Spinner",
            category: .loaders, difficulty: .beginner, iosVersion: "16+",
            isPro: false, isFeatured: false, tintHex: "#1a1a1e",
            author: "Lena Hofstad", handle: "@lena.swift",
            downloads: 23_100, rating: 4.9, price: nil,
            description: "Conic-gradient spinner using SwiftUI's AngularGradient. Smooth, GPU-accelerated, and accent-color aware.",
            swiftCode: Code.spinner
        ),
        .init(
            id: "pull-refresh", name: "Pull to Refresh",
            category: .gestures, difficulty: .intermediate, iosVersion: "17+",
            isPro: false, isFeatured: false, tintHex: "#181c20",
            author: "Devon Park", handle: "@devon.builds",
            downloads: 5_430, rating: 4.7, price: 7.99,
            description: "Custom pull-to-refresh that morphs an arrow into a spinner, with rubber-band resistance and haptic feedback.",
            swiftCode: Code.pullRefresh
        ),
        .init(
            id: "card-flip", name: "3D Card Flip",
            category: .transitions, difficulty: .intermediate, iosVersion: "17+",
            isPro: true, isFeatured: false, tintHex: "#1d1820",
            author: "Aria Chen", handle: "@aria.design",
            downloads: 3_210, rating: 4.6, price: 4.99,
            description: "3D card flip with proper backface culling. Pass two views and bind the flip state.",
            swiftCode: Code.cardFlip
        ),
        .init(
            id: "wave-loader", name: "Wave Loader",
            category: .loaders, difficulty: .advanced, iosVersion: "17+",
            isPro: true, isFeatured: false, tintHex: "#1a1d1e",
            author: "Yuki Tanaka", handle: "@yuki.motion",
            downloads: 6_780, rating: 4.8, price: 9.99,
            description: "Sine-wave fill progress indicator. Pass a 0...1 progress and the wave rises with a continuously animating crest.",
            swiftCode: Code.waveLoader
        ),
        .init(
            id: "pulse-rings", name: "Pulse Rings",
            category: .loaders, difficulty: .beginner, iosVersion: "16+",
            isPro: false, isFeatured: false, tintHex: "#1e1a1e",
            author: "Sam Reilly", handle: "@samreilly",
            downloads: 14_200, rating: 4.9, price: nil,
            description: "Three concentric rings expanding outward with staggered delays — perfect for live indicators.",
            swiftCode: Code.pulseRings
        ),
        .init(
            id: "toast", name: "Toast Drop",
            category: .transitions, difficulty: .beginner, iosVersion: "17+",
            isPro: false, isFeatured: false, tintHex: "#1a1c20",
            author: "Maya Ortega", handle: "@mortega.dev",
            downloads: 9_540, rating: 4.8, price: nil,
            description: "iOS-style toast with safe-area-aware positioning and a spring drop-in.",
            swiftCode: Code.toast
        ),
        .init(
            id: "shimmer", name: "Skeleton Shimmer",
            category: .loaders, difficulty: .beginner, iosVersion: "16+",
            isPro: false, isFeatured: false, tintHex: "#19191c",
            author: "Lena Hofstad", handle: "@lena.swift",
            downloads: 18_900, rating: 4.9, price: nil,
            description: "A reusable shimmer ViewModifier you can apply to any view as a loading skeleton.",
            swiftCode: Code.shimmer
        ),
        .init(
            id: "ticker", name: "Number Ticker",
            category: .textEffects, difficulty: .intermediate, iosVersion: "17+",
            isPro: true, isFeatured: false, tintHex: "#1a1e1a",
            author: "Kenji Saito", handle: "@kenji.codes",
            downloads: 4_120, rating: 4.7, price: 6.99,
            description: "Animated number ticker with per-digit roll-up animation. Uses ContentTransition.numericText() under the hood.",
            swiftCode: Code.ticker
        ),
        .init(
            id: "hamburger", name: "Hamburger Morph",
            category: .microInteractions, difficulty: .beginner, iosVersion: "16+",
            isPro: false, isFeatured: false, tintHex: "#1d1a1c",
            author: "Devon Park", handle: "@devon.builds",
            downloads: 7_800, rating: 4.8, price: nil,
            description: "Classic hamburger ↔ close icon morph using three Capsules. Pass a binding and it does the rest.",
            swiftCode: Code.hamburger
        ),
        .init(
            id: "typing", name: "Typing Dots",
            category: .microInteractions, difficulty: .beginner, iosVersion: "16+",
            isPro: false, isFeatured: false, tintHex: "#1c1c20",
            author: "Aria Chen", handle: "@aria.design",
            downloads: 11_200, rating: 4.8, price: nil,
            description: "Chat-style typing indicator. Three dots that bounce with staggered delays inside a chat bubble.",
            swiftCode: Code.typing
        ),
        .init(
            id: "liquid-tabs", name: "Liquid Tab Bar",
            category: .navigation, difficulty: .advanced, iosVersion: "18+",
            isPro: true, isFeatured: false, tintHex: "#1e1c22",
            author: "Yuki Tanaka", handle: "@yuki.motion",
            downloads: 2_890, rating: 4.9, price: 12.99,
            description: "Liquid-glass tab bar with a morphing accent pill. Uses matchedGeometryEffect for the slide.",
            swiftCode: Code.liquidTabs
        ),
        .init(
            id: "confetti", name: "Confetti Burst",
            category: .microInteractions, difficulty: .advanced, iosVersion: "17+",
            isPro: true, isFeatured: false, tintHex: "#22181c",
            author: "Sam Reilly", handle: "@samreilly",
            downloads: 5_670, rating: 4.7, price: 8.99,
            description: "Particle burst for celebration moments. 14 colored shards radiate outward with randomized rotation.",
            swiftCode: Code.confetti
        ),
        .init(
            id: "onboarding", name: "Onboarding Swirl",
            category: .onboarding, difficulty: .intermediate, iosVersion: "17+",
            isPro: false, isFeatured: false, tintHex: "#1c1a22",
            author: "Aria Chen", handle: "@aria.design",
            downloads: 4_980, rating: 4.7, price: 5.99,
            description: "Organic blob hero for onboarding screens. Two layered blobs rotate slowly at different speeds.",
            swiftCode: Code.onboarding
        ),
        .init(
            id: "progress-arc", name: "Progress Arc",
            category: .loaders, difficulty: .beginner, iosVersion: "16+",
            isPro: false, isFeatured: false, tintHex: "#1a1d1c",
            author: "Maya Ortega", handle: "@mortega.dev",
            downloads: 16_300, rating: 4.9, price: nil,
            description: "Circular progress with smooth stroke animation. Accepts any 0...1 progress; updates animate via withAnimation.",
            swiftCode: Code.progressArc
        ),

        // MARK: - Creative
        .init(
            id: "aurora-mesh", name: "Aurora Mesh",
            category: .backgrounds, difficulty: .advanced, iosVersion: "18+",
            isPro: true, isFeatured: true, tintHex: "#0a0a0c",
            author: "Yuki Tanaka", handle: "@yuki.motion",
            downloads: 18_400, rating: 4.95, price: 14.99,
            description: "iOS 18 MeshGradient animated through 9 control points. Production-ready hero surface for AI / intelligence UI.",
            swiftCode: Code.auroraMesh
        ),
        .init(
            id: "liquid-heart", name: "Liquid Heart",
            category: .microInteractions, difficulty: .advanced, iosVersion: "17+",
            isPro: true, isFeatured: false, tintHex: "#1a0d10",
            author: "Kenji Saito", handle: "@kenji.codes",
            downloads: 11_600, rating: 4.9, price: 9.99,
            description: "Heart-shape that pulses with a soft inner glow. Built from gradient fills and shadow layers.",
            swiftCode: Code.liquidHeart
        ),
        .init(
            id: "elastic-tabs", name: "Elastic Tabs",
            category: .navigation, difficulty: .intermediate, iosVersion: "17+",
            isPro: true, isFeatured: false, tintHex: "#15151a",
            author: "Lena Hofstad", handle: "@lena.swift",
            downloads: 9_840, rating: 4.85, price: 7.99,
            description: "Segmented control with matchedGeometryEffect-driven pill slide. Snappy and rubber-bandy.",
            swiftCode: Code.elasticTabs
        ),
        .init(
            id: "hologram-card", name: "Hologram Card",
            category: .transitions, difficulty: .advanced, iosVersion: "17+",
            isPro: true, isFeatured: false, tintHex: "#0d0d12",
            author: "Aria Chen", handle: "@aria.design",
            downloads: 6_300, rating: 4.8, price: 11.99,
            description: "Iridescent card surface with parallax tilt and hue-shifting gradient. Perfect for paywall / loyalty UI.",
            swiftCode: Code.hologramCard
        ),
        .init(
            id: "parallax-card", name: "3D Parallax Card",
            category: .gestures, difficulty: .intermediate, iosVersion: "17+",
            isPro: false, isFeatured: false, tintHex: "#1a1a1e",
            author: "Devon Park", handle: "@devon.builds",
            downloads: 14_500, rating: 4.85, price: nil,
            description: "Drag to tilt — card rotates in 3D, light glints follow the touch. Free starter for the catalog.",
            swiftCode: Code.parallaxCard
        ),
        .init(
            id: "glitch-text", name: "RGB Glitch Text",
            category: .textEffects, difficulty: .intermediate, iosVersion: "16+",
            isPro: false, isFeatured: false, tintHex: "#0a0a0c",
            author: "Sam Reilly", handle: "@samreilly",
            downloads: 7_120, rating: 4.7, price: nil,
            description: "Three colored text layers (red, cyan, white) jitter independently to give a CRT-glitch feel.",
            swiftCode: Code.glitchText
        ),
        .init(
            id: "morphing-fab", name: "Morphing FAB",
            category: .buttons, difficulty: .intermediate, iosVersion: "17+",
            isPro: true, isFeatured: false, tintHex: "#1a1716",
            author: "Maya Ortega", handle: "@mortega.dev",
            downloads: 5_400, rating: 4.75, price: 6.99,
            description: "Floating action button that morphs into a confirmation pill on tap.",
            swiftCode: Code.morphingFab
        ),

        // MARK: - Aurora pack
        .init(
            id: "aurora-borealis", name: "Aurora Borealis",
            category: .backgrounds, difficulty: .advanced, iosVersion: "18+",
            isPro: true, isFeatured: false, tintHex: "#050a14",
            author: "Yuki Tanaka", handle: "@yuki.motion",
            downloads: 9_300, rating: 4.9, price: 9.99,
            description: "Northern-lights mesh gradient with starfield. Slow and atmospheric.",
            swiftCode: Code.auroraBorealis
        ),
        .init(
            id: "liquid-chrome", name: "Liquid Chrome",
            category: .backgrounds, difficulty: .advanced, iosVersion: "17+",
            isPro: true, isFeatured: false, tintHex: "#0a0a0c",
            author: "Lena Hofstad", handle: "@lena.swift",
            downloads: 7_100, rating: 4.85, price: 9.99,
            description: "Metallic, slowly-flowing chrome surface for premium hero sections.",
            swiftCode: Code.liquidChrome
        ),
        .init(
            id: "aurora-pulse", name: "Aurora Pulse",
            category: .backgrounds, difficulty: .advanced, iosVersion: "17+",
            isPro: true, isFeatured: false, tintHex: "#08081a",
            author: "Kenji Saito", handle: "@kenji.codes",
            downloads: 5_900, rating: 4.8, price: 9.99,
            description: "Audio-reactive pulse pattern of overlapping radial glows.",
            swiftCode: Code.auroraPulse
        ),
        .init(
            id: "lava-flow", name: "Lava Flow",
            category: .backgrounds, difficulty: .advanced, iosVersion: "17+",
            isPro: true, isFeatured: false, tintHex: "#1a0500",
            author: "Devon Park", handle: "@devon.builds",
            downloads: 4_800, rating: 4.75, price: 9.99,
            description: "Hot, slow-flowing red/orange orbs. Great for fitness / gaming heroes.",
            swiftCode: Code.lavaFlow
        ),

        // MARK: - Advanced / physics
        .init(
            id: "spring-chain", name: "Spring Chain",
            category: .gestures, difficulty: .advanced, iosVersion: "17+",
            isPro: true, isFeatured: false, tintHex: "#16161a",
            author: "Sam Reilly", handle: "@samreilly",
            downloads: 4_400, rating: 4.85, price: 12.99,
            description: "A leader dot drags a chain of follower dots with staggered spring delays. Pure SwiftUI, no third-party libs.",
            swiftCode: Code.springChain
        ),
        .init(
            id: "throwable-card", name: "Throwable Card",
            category: .gestures, difficulty: .advanced, iosVersion: "17+",
            isPro: true, isFeatured: false, tintHex: "#1a1a1e",
            author: "Maya Ortega", handle: "@mortega.dev",
            downloads: 3_800, rating: 4.8, price: 11.99,
            description: "Drag-and-fling card with velocity-aware spring settle. Off-screen velocity dismisses.",
            swiftCode: Code.throwableCard
        ),
        .init(
            id: "liquid-ripple", name: "Liquid Ripple",
            category: .metalShaders, difficulty: .advanced, iosVersion: "17+",
            isPro: true, isFeatured: false, tintHex: "#0f1419",
            author: "Yuki Tanaka", handle: "@yuki.motion",
            downloads: 6_900, rating: 4.9, price: 19.99,
            description: "Concentric ripple shader. Tap to spawn — the ripple distorts the layer below using a Metal shader.",
            swiftCode: Code.liquidRipple
        )
    ]
}
