//
//  DiscoverView.swift
//  StaggerApp
//

import SwiftUI

struct DiscoverView: View {

    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel: DiscoverViewModel

    init(viewModel: DiscoverViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                NavHeader(title: "Discover", isLarge: true, trailing: {
                    IconButton("bell") {}
                })
                .padding(.bottom, 12)

                Text("\(viewModel.totalCount) hand-crafted SwiftUI animations. Tap any one to preview, tweak, and copy.")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.horizontal, Theme.Spacing.xxl)
                    .padding(.bottom, Theme.Spacing.xxl)
                    .lineLimit(2)

                HeroCard(item: viewModel.featured) {
                    router.push(.detail(animationId: viewModel.featured.id))
                }
                .padding(.horizontal, Theme.Spacing.xl)

                SectionHeader("Trending this week", trailing: "See all") {
                    router.selectedTab = .browse
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.trending) { item in
                            AnimationCard(item, size: .small) {
                                router.push(.detail(animationId: item.id))
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                }

                AuroraPackPromoCard {
                    router.push(.detail(animationId: "aurora-mesh"))
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.xxxl)

                SectionHeader("Aurora in the wild", trailing: "See all") {
                    router.selectedTab = .browse
                }
                Text("Each animation, shown inside a real app context.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, Theme.Spacing.xxl)
                    .padding(.top, -8)
                    .padding(.bottom, 12)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(UsageMockup.all) { m in
                            UsageMockupCard(mockup: m) {
                                router.push(.detail(animationId: m.animationId))
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                }

                SectionHeader("Browse by category")
                CategoryGrid(categories: viewModel.categories) {
                    router.selectedTab = .browse
                }

                SectionHeader("New & noteworthy", trailing: "See all") {
                    router.selectedTab = .browse
                }
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(viewModel.newlyAdded) { item in
                        AnimationCard(item) {
                            router.push(.detail(animationId: item.id))
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)

                Spacer().frame(height: 120)
            }
        }
        .background(Theme.Palette.background)
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: Usage mockups — "Aurora in the wild · Real iOS app usage"
// MARK: ─────────────────────────────────────────────────────────────

struct UsageMockup: Identifiable {
    enum Layout { case aiChat, onboarding, paywall, music, success, reading, fitness }
    let id: String
    let title: String       // "AI Assistant"
    let appName: String     // "Intelligence"
    let animationId: String // links to ANIMATIONS catalog
    let why: String
    let layout: Layout

    static let all: [UsageMockup] = [
        .init(id: "mock-ai-chat",    title: "AI Assistant",   appName: "Intelligence", animationId: "aurora-mesh",     why: "Mesh moves while the model reasons — signals 'thinking' without a stale spinner.", layout: .aiChat),
        .init(id: "mock-onboarding", title: "App Onboarding", appName: "NorthLight",   animationId: "aurora-borealis", why: "Northern lights as literal product — sets emotional tone in 1 second.",          layout: .onboarding),
        .init(id: "mock-paywall",    title: "Pro Paywall",    appName: "Folio",        animationId: "liquid-chrome",   why: "Iridescent metal reads as 'premium'.",                                           layout: .paywall),
        .init(id: "mock-music",      title: "Now Playing",    appName: "Late Bloom",   animationId: "aurora-pulse",    why: "Background pulses with the bass — passive engagement while listening.",          layout: .music),
        .init(id: "mock-success",    title: "Success Moment", appName: "Welcome",      animationId: "au-coreburst",    why: "Bloom radiates from center — celebrates completion as a payoff.",                layout: .success),
        .init(id: "mock-reading",    title: "Book Detail",    appName: "Paperbound",   animationId: "au-pearl",        why: "Pearl as paper texture — establishes editorial, tactile mood.",                  layout: .reading),
        .init(id: "mock-fitness",    title: "HIIT Timer",     appName: "Forge",        animationId: "lava-flow",       why: "Lava drives intensity — visual heat pushes the workout.",                        layout: .fitness)
    ]
}

struct UsageMockupCard: View {
    let mockup: UsageMockup
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    // Aurora background fills the phone-mockup
                    AnimationPreviewRegistry.view(for: mockup.animationId)
                    // Dark scrim for legibility
                    LinearGradient(
                        colors: [Color.black.opacity(0.05), Color.black.opacity(0.55)],
                        startPoint: .top, endPoint: .bottom
                    )
                    // Faux iOS overlay specific to the use case
                    overlay
                }
                .frame(width: 168, height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                )

                Text(mockup.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(mockup.appName)
                    .font(Theme.Typo.mono(11))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var overlay: some View {
        switch mockup.layout {
        case .aiChat:       aiChatOverlay
        case .onboarding:   onboardingOverlay
        case .paywall:      paywallOverlay
        case .music:        musicOverlay
        case .success:      successOverlay
        case .reading:      readingOverlay
        case .fitness:      fitnessOverlay
        }
    }

    // ── Faux UI overlays (kept lightweight — vibe, not full mockups) ──

    private var aiChatOverlay: some View {
        VStack(spacing: 6) {
            statusBar
            Spacer()
            HStack {
                MockBubble(text: "What's the plan for tonight?", isUser: true)
                Spacer(minLength: 12)
            }
            HStack {
                Spacer(minLength: 12)
                MockBubble(text: "Pasta + early walk.", isUser: false)
            }
            inputPill
        }
        .padding(10)
    }

    private var onboardingOverlay: some View {
        VStack(spacing: 6) {
            statusBar
            Spacer()
            Text("See the sky\nwhere you sleep.")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            primaryButton(text: "Start tracking")
        }
        .padding(12)
    }

    private var paywallOverlay: some View {
        VStack(spacing: 6) {
            statusBar
            Spacer()
            VStack(alignment: .leading, spacing: 4) {
                Text("Folio Pro")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(.white)
                ForEach(["Unlimited shelves", "Reading insights", "Hand-picked weekly"], id: \.self) { row in
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color(red: 0.95, green: 0.9, blue: 0.6))
                        Text(row)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            primaryButton(text: "Start 7-day trial")
        }
        .padding(12)
    }

    private var musicOverlay: some View {
        VStack(spacing: 8) {
            statusBar
            Spacer()
            Text("LATE\nBLOOM")
                .font(.system(size: 22, weight: .black))
                .tracking(2)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Spacer()
            HStack(spacing: 22) {
                Image(systemName: "backward.fill")
                Image(systemName: "play.fill").font(.system(size: 22))
                Image(systemName: "forward.fill")
            }
            .foregroundStyle(.white)
        }
        .padding(12)
    }

    private var successOverlay: some View {
        VStack(spacing: 6) {
            statusBar
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.white)
            Text("Welcome aboard.")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(.white)
            Spacer()
            primaryButton(text: "Set up project")
        }
        .padding(12)
    }

    private var readingOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            statusBar
            Spacer()
            Text("Where the\nPages Bleed\nGold")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(red: 0.1, green: 0.08, blue: 0.05))
            Text("A meditation on craft.")
                .font(.system(size: 10))
                .foregroundStyle(Color.black.opacity(0.55))
            Spacer()
            HStack {
                Text("Begin reading · Chapter 1")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(red: 0.1, green: 0.08, blue: 0.05))
                Spacer()
            }
            .padding(8)
            .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(12)
    }

    private var fitnessOverlay: some View {
        VStack(spacing: 4) {
            statusBar
            Spacer()
            Text("00:42")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("Mountain Climbers")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
            Circle()
                .fill(Color.white)
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: "pause.fill").foregroundStyle(.black))
        }
        .padding(12)
    }

    // ── Shared mini-bits ──────────────────────────────────────

    private var statusBar: some View {
        HStack {
            Text("9:41")
                .font(Theme.Typo.mono(9))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
            HStack(spacing: 3) {
                Image(systemName: "wifi").font(.system(size: 8))
                Image(systemName: "battery.100").font(.system(size: 8))
            }
            .foregroundStyle(.white.opacity(0.85))
        }
    }

    private var inputPill: some View {
        HStack {
            Text("Reply…")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Image(systemName: "mic.fill")
                .font(.system(size: 8))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(Color.black.opacity(0.35), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
    }

    private func primaryButton(text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 9))
    }
}

private struct MockBubble: View {
    let text: String
    let isUser: Bool
    var body: some View {
        Text(text)
            .font(.system(size: 9))
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(
                isUser
                ? Color.white.opacity(0.15)
                : Color.black.opacity(0.35),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
            )
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: SamplesView — TikTok-style full-screen vertical pager
// MARK: ─────────────────────────────────────────────────────────────

struct SamplesView: View {
    @EnvironmentObject private var router: AppRouter
    @State private var liked: Set<String> = []

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(UsageMockup.all) { m in
                        SamplePage(
                            mockup: m,
                            isLiked: liked.contains(m.id),
                            onToggleLike: { toggle(m.id) },
                            onOpenAnimation: {
                                router.push(.detail(animationId: m.animationId))
                            }
                        )
                        .frame(width: proxy.size.width,
                               height: proxy.size.height)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .background(Color.black)
            .ignoresSafeArea()
        }
    }

    private func toggle(_ id: String) {
        if liked.contains(id) { liked.remove(id) } else { liked.insert(id) }
    }
}

private struct SamplePage: View {
    let mockup: UsageMockup
    let isLiked: Bool
    let onToggleLike: () -> Void
    let onOpenAnimation: () -> Void

    var body: some View {
        ZStack {
            // 1. Aurora animation as full-bleed background
            AnimationPreviewRegistry.view(for: mockup.animationId)

            // 2. Top + bottom scrim for legibility
            LinearGradient(
                colors: [
                    Color.black.opacity(0.35),
                    Color.black.opacity(0),
                    Color.black.opacity(0),
                    Color.black.opacity(0.55)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // 3. Faux iOS UI overlay (scaled up from the card variant)
            ScaledOverlay(mockup: mockup)
                .allowsHitTesting(false)

            // 4. Right-rail TikTok controls
            VStack {
                Spacer()
                rightRail
            }
            .padding(.trailing, 14)
            .padding(.bottom, 130)
            .frame(maxWidth: .infinity, alignment: .trailing)

            // 5. Caption block bottom-left
            VStack(alignment: .leading, spacing: 6) {
                Spacer()
                Text(mockup.appName)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(.white)
                Text(mockup.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                Text(mockup.why)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(3)
            }
            .padding(.leading, 18)
            .padding(.trailing, 84)
            .padding(.bottom, 130)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .contentShape(Rectangle())
    }

    private var rightRail: some View {
        VStack(spacing: 18) {
            railButton(system: isLiked ? "heart.fill" : "heart",
                       tint: isLiked ? Theme.Palette.accent : .white,
                       caption: isLiked ? "Liked" : "Like",
                       action: onToggleLike)
            railButton(system: "chevron.left.forwardslash.chevron.right",
                       tint: .white,
                       caption: "Code",
                       action: onOpenAnimation)
            railButton(system: "square.and.arrow.up",
                       tint: .white,
                       caption: "Share",
                       action: {})
        }
    }

    private func railButton(system: String, tint: Color, caption: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle().fill(Color.black.opacity(0.35))
                        .frame(width: 44, height: 44)
                    Image(systemName: system)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(tint)
                }
                Text(caption)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .buttonStyle(.plain)
    }
}

/// Scales the existing card-sized phone mockup up to a centered "phone frame"
/// inside the TikTok-style page. The outer aurora background is still visible
/// around it, so the page reads as "aurora at large + the app it powers in a
/// phone frame."
private struct ScaledOverlay: View {
    let mockup: UsageMockup
    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width  / 168 * 0.78,
                            geo.size.height / 320 * 0.66)
            UsageMockupCard(mockup: mockup, onTap: {})
                .disabled(true)
                .frame(width: 168, height: 320)
                .scaleEffect(scale)
                .shadow(color: .black.opacity(0.45), radius: 30, y: 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
