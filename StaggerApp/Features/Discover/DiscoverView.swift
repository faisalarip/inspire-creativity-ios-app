//
//  DiscoverView.swift
//  StaggerApp
//

import SwiftUI

struct DiscoverView: View {

    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel: DiscoverViewModel

    init(viewModel: DiscoverViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Compact title — no large-title block, no bell action.
                Text("Discover")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.Spacing.xxl)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                Text("\(viewModel.totalCount) hand-crafted SwiftUI animations. Tap any one to preview, tweak, and copy.")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.horizontal, Theme.Spacing.xxl)
                    .padding(.bottom, Theme.Spacing.xl)
                    .lineLimit(2)

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
                        ForEach(container.usageMockups) { m in
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

struct UsageMockup: Identifiable, Hashable {
    enum Layout: String {
        case aiChat, onboarding, paywall, music, success, reading, fitness, generic
    }
    let id: String
    let title: String       // "AI Assistant"
    let appName: String     // "Intelligence"
    let animationId: String // links to ANIMATIONS catalog
    let why: String
    let layout: Layout
    let swiftCode: String?  // SwiftUI snippet shown in the code rail (nil for fallback rows)

    init(id: String, title: String, appName: String,
         animationId: String, why: String, layout: Layout,
         swiftCode: String? = nil) {
        self.id = id; self.title = title; self.appName = appName
        self.animationId = animationId; self.why = why
        self.layout = layout; self.swiftCode = swiftCode
    }

    /// Hardcoded fallback list — used at app boot before the Supabase fetch
    /// returns, or when Supabase isn't configured. The seven layouts here are
    /// the ones with custom overlays in `UsageMockupCard`. Server-added rows
    /// with unknown layouts render the generic overlay.
    static let fallback: [UsageMockup] = [
        .init(id: "mock-ai-chat",    title: "AI Assistant",   appName: "Intelligence", animationId: "aurora-mesh",     why: "Mesh moves while the model reasons — signals 'thinking' without a stale spinner.", layout: .aiChat),
        .init(id: "mock-onboarding", title: "App Onboarding", appName: "NorthLight",   animationId: "aurora-borealis", why: "Northern lights as literal product — sets emotional tone in 1 second.",          layout: .onboarding),
        .init(id: "mock-paywall",    title: "Pro Paywall",    appName: "Folio",        animationId: "liquid-chrome",   why: "Iridescent metal reads as 'premium'.",                                           layout: .paywall),
        .init(id: "mock-music",      title: "Now Playing",    appName: "Late Bloom",   animationId: "aurora-pulse",    why: "Background pulses with the bass — passive engagement while listening.",          layout: .music),
        .init(id: "mock-success",    title: "Success Moment", appName: "Welcome",      animationId: "au-coreburst",    why: "Bloom radiates from center — celebrates completion as a payoff.",                layout: .success),
        .init(id: "mock-reading",    title: "Book Detail",    appName: "Paperbound",   animationId: "au-pearl",        why: "Pearl as paper texture — establishes editorial, tactile mood.",                  layout: .reading),
        .init(id: "mock-fitness",    title: "HIIT Timer",     appName: "Forge",        animationId: "lava-flow",       why: "Lava drives intensity — visual heat pushes the workout.",                        layout: .fitness)
    ]

    /// Layout inference for server-added rows. The first 7 hardcoded IDs map
    /// to their custom layouts; anything else falls through to `.generic`.
    static func layout(forId id: String) -> Layout {
        switch id {
        case "mock-ai-chat":    return .aiChat
        case "mock-onboarding": return .onboarding
        case "mock-paywall":    return .paywall
        case "mock-music":      return .music
        case "mock-success":    return .success
        case "mock-reading":    return .reading
        case "mock-fitness":    return .fitness
        default:                return .generic
        }
    }
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
        case .generic:      genericOverlay
        }
    }

    /// Used for server-added mockups that don't match one of the seven
    /// hardcoded layouts. Keeps the visual neutral so the aurora carries
    /// the page; the title + app name + a single subtle CTA pill suffice.
    private var genericOverlay: some View {
        VStack(spacing: 6) {
            statusBar
            Spacer()
            VStack(alignment: .leading, spacing: 4) {
                Text(mockup.appName)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white)
                Text(mockup.title)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
            primaryButton(text: "Open")
        }
        .padding(12)
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
// MARK: SamplesView — horizontal carousel of iPhone-frame mockup cards
// MARK: ─────────────────────────────────────────────────────────────

struct SamplesView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var container: AppContainer
    @State private var liked: Set<String> = []

    var body: some View {
        GeometryReader { proxy in
            // Reserve space for the floating tab bar (~110pt incl. bottom safe
            // area + visual buffer) and the header (~80pt). Cards size
            // dynamically to fit the remaining vertical space.
            let headerHeight: CGFloat = 80
            let bottomReserved: CGFloat = 110
            let available = proxy.size.height - headerHeight - bottomReserved
            let cardHeight = max(420, min(available, 640))
            let cardWidth  = min(340, proxy.size.width - 56, cardHeight / 1.65)

            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 14)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 18) {
                        ForEach(container.usageMockups) { m in
                            SampleCarouselCard(
                                mockup: m,
                                isLiked: liked.contains(m.id),
                                onToggleLike: { toggle(m.id) },
                                onOpenAnimation: {
                                    router.push(.detail(animationId: m.animationId))
                                }
                            )
                            .frame(width: cardWidth, height: cardHeight)
                        }
                    }
                    .padding(.horizontal, (proxy.size.width - cardWidth) / 2)
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .frame(height: cardHeight + 28)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Theme.Palette.background)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Samples")
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(.white)
            Text("\(container.usageMockups.count) auroras in real iOS app contexts. Swipe.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private func toggle(_ id: String) {
        if liked.contains(id) { liked.remove(id) } else { liked.insert(id) }
    }
}

/// One slide of the horizontal carousel. Top half is an iPhone-screen-shaped
/// aurora hero with status bar + circular nav buttons; the bottom half is an
/// editorial content card with the mockup's metadata + a CTA.
private struct SampleCarouselCard: View {
    let mockup: UsageMockup
    let isLiked: Bool
    let onToggleLike: () -> Void
    let onOpenAnimation: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            phoneScreen
                .frame(maxHeight: .infinity)
            content
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .background(contentBackground)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.35), radius: 30, y: 18)
    }

    // ── Top "phone screen" hero ────────────────────────────────

    private var phoneScreen: some View {
        ZStack(alignment: .top) {
            Color.black
            AnimationPreviewRegistry.view(for: mockup.animationId)
                .clipped()
            statusBar
                .padding(.horizontal, 18)
                .padding(.top, 14)
            HStack {
                navCircle(system: "chevron.left", action: {})
                Spacer()
                navCircle(
                    system: isLiked ? "heart.fill" : "heart",
                    tint: isLiked ? Theme.Palette.accent : .white,
                    action: onToggleLike
                )
            }
            .padding(.horizontal, 14)
            .padding(.top, 42)
        }
    }

    private var statusBar: some View {
        HStack {
            Text("9:41")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "wifi").font(.system(size: 11, weight: .semibold))
                Image(systemName: "battery.100").font(.system(size: 13))
            }
        }
        .foregroundStyle(.white)
    }

    private func navCircle(system: String, tint: Color = .white,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(Color.black.opacity(0.55))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: system)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tint)
                )
        }
        .buttonStyle(.plain)
    }

    // ── Bottom editorial content card ──────────────────────────

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(metaLine)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(contentForeground.opacity(0.55))

            Text(mockup.title)
                .font(.system(size: 22, weight: .heavy, design: .serif))
                .foregroundStyle(contentForeground)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(2)

            chips

            Text(mockup.why)
                .font(.system(size: 13))
                .foregroundStyle(contentForeground.opacity(0.65))
                .lineLimit(4)
                .padding(.top, 2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 6)

            Button(action: onOpenAnimation) {
                HStack {
                    Text("Open animation")
                        .font(.system(size: 14, weight: .bold))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 18)
    }

    private var chips: some View {
        HStack(spacing: 6) {
            chip(mockup.appName)
            chip(mockup.layout.rawValue.capitalized)
            chip("Aurora")
        }
    }

    private func chip(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(contentForeground.opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(contentForeground.opacity(0.08), in: Capsule())
    }

    private var metaLine: String {
        // Static rating per id keeps each card stable across renders.
        let hash = abs(mockup.id.hashValue)
        let rating = 4.6 + Double(hash % 4) * 0.1
        return "\(mockup.appName.uppercased()) · ★ \(String(format: "%.1f", rating))"
    }

    private var contentBackground: Color {
        // Warm cream — matches the screenshot reference.
        Color(red: 0.97, green: 0.93, blue: 0.83)
    }

    private var contentForeground: Color {
        Color(red: 0.13, green: 0.08, blue: 0.02)
    }
}

