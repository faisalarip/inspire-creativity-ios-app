//
//  DiscoverView.swift
//  InspireCreativityApp
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

                Text("\(viewModel.totalCount) hand-crafted SwiftUI animations. Tap any one to preview and copy.")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.horizontal, Theme.Spacing.xxl)
                    .padding(.bottom, Theme.Spacing.xl)
                    .lineLimit(2)

                SectionHeader("Trending this week", trailing: "See all") {
                    router.selectedTab = .browse
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(viewModel.trending) { item in
                            AnimationCard(item, size: .small) {
                                router.push(.detail(animationId: item.id))
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                }

                AuroraPackPromoCard {
                    router.push(.paywall)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.xxxl)

                SectionHeader("Aurora in the wild", trailing: "See all") {
                    router.selectedTab = .browse
                }
                Text("Each animation, shown inside a sample app layout.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, Theme.Spacing.xxl)
                    .padding(.top, -8)
                    .padding(.bottom, 12)

                ScrollView(.horizontal, showsIndicators: false) {
                    // Lazy: 30 mockups, each embedding a live aurora preview —
                    // an eager HStack instantiates (and animates) all of them.
                    LazyHStack(spacing: 14) {
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
        .refreshable {
            await viewModel.reload()
            await container.refreshUsageMockups()
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
        case aiChat, onboarding, paywall, music, success, reading, fitness
        case cryptoWallet, meditation, sleep, weather, bankSuccess
        case photoGallery, launchSplash, audioCall, voiceAssistant
        case nft, astrology, dating, yoga, coinDetail, subUnlocked
        case workoutSummary, ticket, yearReview, emptyInbox
        case recipe, travel, loyalty, achievement
        case generic
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

    /// Hardcoded fallback list — the full **30 "Aurora in the wild" iOS app
    /// contexts** from the design. Used at app boot before the Supabase fetch
    /// returns, or when Supabase isn't configured/reachable, so the Samples
    /// tab always shows all 30 offline. Mirrors `supabase_seed_mockups.sql`;
    /// each `layout` has a bespoke screen in `MockupViewRegistry`. (Two seed
    /// `aurora_id`s — `aurora-bloom`/`aurora-marble` — have no bundled preview,
    /// so success/reading use the resolvable `au-coreburst`/`au-pearl`.)
    static let fallback: [UsageMockup] = [
        .init(id: "mock-ai-chat",         title: "AI Assistant",           appName: "Intelligence",     animationId: "aurora-mesh",       why: "Aurora moves while AI reasons — signals \"thinking\" without a stale spinner.", layout: .aiChat),
        .init(id: "mock-onboarding",      title: "Onboarding Splash",      appName: "NorthLight",       animationId: "aurora-borealis",   why: "Northern lights as literal product — instant emotional hook in 1 second.", layout: .onboarding),
        .init(id: "mock-paywall",         title: "Pro Paywall",            appName: "Folio",            animationId: "liquid-chrome",     why: "Iridescent metal reads as \"premium\" — increases conversion.", layout: .paywall),
        .init(id: "mock-music",           title: "Now Playing",            appName: "Late Bloom",       animationId: "aurora-pulse",      why: "Background pulses with bass — passive engagement during listening.", layout: .music),
        .init(id: "mock-success",         title: "Success Moment",         appName: "Onboarding",       animationId: "au-coreburst",      why: "Bloom radiates from center — celebrates completion as a payoff.", layout: .success),
        .init(id: "mock-reading",         title: "Book Detail",            appName: "Paperbound",       animationId: "au-pearl",          why: "Pearl as paper texture — establishes editorial, tactile mood.", layout: .reading),
        .init(id: "mock-fitness",         title: "HIIT Timer",             appName: "Forge",            animationId: "lava-flow",         why: "Lava drives intensity — visual heat pushes the workout.", layout: .fitness),
        .init(id: "mock-crypto-wallet",   title: "Crypto Wallet",          appName: "Wavelet",          animationId: "au-sunset",         why: "Warm aurora softens hard numbers — feels like wealth, not anxiety.", layout: .cryptoWallet),
        .init(id: "mock-meditation",      title: "Meditation Session",     appName: "Stillness",        animationId: "au-calmdrift",      why: "Calm drift mirrors breath — viewers naturally synchronize.", layout: .meditation),
        .init(id: "mock-sleep",           title: "Sleep Tracking",         appName: "Dreamweave",       animationId: "au-midnight",       why: "Aurora midnight feels nocturnal — the bg sells the context before any UI.", layout: .sleep),
        .init(id: "mock-weather",         title: "Weather Forecast",       appName: "Skyline",          animationId: "au-storm",          why: "Storm Front bg signals conditions before reading any number.", layout: .weather),
        .init(id: "mock-bank-success",    title: "Transfer Sent",          appName: "BluePay",          animationId: "au-solar",          why: "Solar burst behind the checkmark = pure satisfaction.", layout: .bankSuccess),
        .init(id: "mock-photo-gallery",   title: "Photo Memories",         appName: "Bokeh",            animationId: "au-bokeh",          why: "Soft Bokeh dots echo lens blur — feels like film, not phone.", layout: .photoGallery),
        .init(id: "mock-launch-splash",   title: "Launch Splash",          appName: "Orbit",            animationId: "au-nebula",         why: "A drifting nebula gives 1.5s of magic instead of a dead loading dot.", layout: .launchSplash),
        .init(id: "mock-audio-call",      title: "Live Audio Room",        appName: "Tuesday Studio",   animationId: "au-pulsar",         why: "Pulsar beats with the active speaker — engagement signal you can feel.", layout: .audioCall),
        .init(id: "mock-voice-assistant", title: "Voice Assistant",        appName: "Aria",             animationId: "au-pearl",          why: "Pearl iridescence reads as \"intelligent listening\" not \"stuck\".", layout: .voiceAssistant),
        .init(id: "mock-nft",             title: "NFT Detail",             appName: "Strata",           animationId: "au-holofoil",       why: "Holographic foil shimmer is the universal \"rare\" signal.", layout: .nft),
        .init(id: "mock-astrology",       title: "Daily Horoscope",        appName: "Astralis",         animationId: "au-nebula",         why: "Nebula deepens the mystical, makes the words land harder.", layout: .astrology),
        .init(id: "mock-dating",          title: "Profile Card",           appName: "Soirée",           animationId: "au-sparkleveil",    why: "Sparkle veil keeps it romantic without being saccharine.", layout: .dating),
        .init(id: "mock-yoga",            title: "Yoga Pose Timer",        appName: "Asana",            animationId: "au-ethereal",       why: "Ethereal Mist is wash-of-calm — perfect under hold timers.", layout: .yoga),
        .init(id: "mock-coin-detail",     title: "Coin Detail",            appName: "Wavelet",          animationId: "au-blackhole",      why: "Black Hole gravitas frames the chart — risk made tangible.", layout: .coinDetail),
        .init(id: "mock-sub-unlocked",    title: "Premium Unlocked",       appName: "Wavelength",       animationId: "au-goldfoil",       why: "Gold foil = literal \"golden moment\" — celebrate the conversion.", layout: .subUnlocked),
        .init(id: "mock-workout-summary", title: "Workout Summary",        appName: "Forge",            animationId: "au-firewall",       why: "Firewall = visceral effort, satisfying after a hard session.", layout: .workoutSummary),
        .init(id: "mock-ticket",          title: "Event Ticket",           appName: "Curtain",          animationId: "au-stardust",       why: "Stardust makes a flat PDF ticket feel like the show already started.", layout: .ticket),
        .init(id: "mock-year-review",     title: "Year in Review",         appName: "Forge",            animationId: "au-supernova",      why: "Supernova = climactic — pairs with the year-defining stat.", layout: .yearReview),
        .init(id: "mock-empty-inbox",     title: "Inbox Zero",             appName: "Pebble Mail",      animationId: "au-calmdrift",      why: "Calm drift turns \"nothing to do\" into \"moment to breathe\".", layout: .emptyInbox),
        .init(id: "mock-recipe",          title: "Recipe Card",            appName: "Hearth",           animationId: "au-honeydrip",      why: "Honey Drip evokes warmth + taste — appetite-stimulating.", layout: .recipe),
        .init(id: "mock-travel",          title: "Travel Destination",     appName: "Compass",          animationId: "au-tropics",        why: "Tropical Haze previews the destination vibe before any photo.", layout: .travel),
        .init(id: "mock-loyalty",         title: "Tier Upgrade",           appName: "Lumière",          animationId: "au-goldfoil",       why: "Bronze → Gold transition feels like an actual coronation.", layout: .loyalty),
        .init(id: "mock-achievement",     title: "Achievement Unlocked",   appName: "Streak",           animationId: "au-coreburst",      why: "Core Burst behind a trophy = visceral reward firing in the brain.", layout: .achievement)
    ]

    /// Layout inference for server-added rows. The first 7 hardcoded IDs map
    /// to their custom layouts; anything else falls through to `.generic`.
    static func layout(forId id: String) -> Layout {
        switch id {
        case "mock-ai-chat":          return .aiChat
        case "mock-onboarding":       return .onboarding
        case "mock-paywall":          return .paywall
        case "mock-music":            return .music
        case "mock-success":          return .success
        case "mock-reading":          return .reading
        case "mock-fitness":          return .fitness
        case "mock-crypto-wallet":    return .cryptoWallet
        case "mock-meditation":       return .meditation
        case "mock-sleep":            return .sleep
        case "mock-weather":          return .weather
        case "mock-bank-success":     return .bankSuccess
        case "mock-photo-gallery":    return .photoGallery
        case "mock-launch-splash":    return .launchSplash
        case "mock-audio-call":       return .audioCall
        case "mock-voice-assistant":  return .voiceAssistant
        case "mock-nft":              return .nft
        case "mock-astrology":        return .astrology
        case "mock-dating":           return .dating
        case "mock-yoga":             return .yoga
        case "mock-coin-detail":      return .coinDetail
        case "mock-sub-unlocked":     return .subUnlocked
        case "mock-workout-summary":  return .workoutSummary
        case "mock-ticket":           return .ticket
        case "mock-year-review":      return .yearReview
        case "mock-empty-inbox":      return .emptyInbox
        case "mock-recipe":           return .recipe
        case "mock-travel":           return .travel
        case "mock-loyalty":          return .loyalty
        case "mock-achievement":      return .achievement
        default:                      return .generic
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
        // New layouts introduced for the Samples carousel use the generic
        // overlay here — the small 168×320 Discover card is intentionally
        // not bespoke per-id.
        default:            genericOverlay
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
            // Reserve space for the floating tab bar (~140pt incl. bottom safe
            // area + caption block under the iPhone-frame card) and the
            // header (~80pt). Cards size dynamically to fit the remaining
            // vertical space, matching the 390×780 viewport from the design.
            let headerHeight: CGFloat = 80
            let bottomReserved: CGFloat = 180
            let available = proxy.size.height - headerHeight - bottomReserved
            let cardHeight = max(420, min(available, 640))
            let cardWidth  = min(340, proxy.size.width - 56, cardHeight / 1.92)

            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 0)
                    .padding(.bottom, 14)

                ScrollView(.horizontal, showsIndicators: false) {
                    // Lazy for the same reason as Discover's mockup row: only
                    // the on-screen cards should exist (each animates forever).
                    LazyHStack(spacing: 18) {
                        ForEach(container.usageMockups) { m in
                            SampleCarouselCard(
                                mockup: m,
                                cardWidth: cardWidth,
                                cardHeight: cardHeight,
                                isLiked: liked.contains(m.id),
                                onToggleLike: { toggle(m.id) },
                                onOpenAnimation: {
                                    router.push(.detail(animationId: m.animationId))
                                }
                            )
                            .frame(maxWidth: cardWidth)
                        }
                    }
                    .padding(.horizontal, (proxy.size.width - cardWidth) / 2)
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .frame(height: cardHeight + 70)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Theme.Palette.background)
        }
        // Hide the (otherwise-empty) navigation bar so the ~44pt reservation
        // doesn't push the header way below the status bar.
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Aurora in the Wild")
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(.white)
            Text("\(container.usageMockups.count) real iOS app contexts · Swipe to explore")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private func toggle(_ id: String) {
        if liked.contains(id) { liked.remove(id) } else { liked.insert(id) }
    }
}

/// One slide of the horizontal Samples carousel. Renders the per-mockup
/// SwiftUI screen inside an iPhone-frame card, with a 2-line caption
/// (title + concept app name) underneath.
private struct SampleCarouselCard: View {
    let mockup: UsageMockup
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let isLiked: Bool
    let onToggleLike: () -> Void
    let onOpenAnimation: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Button(action: onOpenAnimation) {
                iPhoneFrameCard
            }
            .buttonStyle(.plain)
            caption
        }
    }

    /// Phone-shaped card. Dark `#0a0a0c` outer bg, 36pt continuous corners,
    /// subtle 30pt drop shadow. The per-mockup view is clipped to match.
    private var iPhoneFrameCard: some View {
        ZStack {
            Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0C / 255)
            MockupViewRegistry.view(
                for: mockup,
                cardWidth: cardWidth,
                cardHeight: cardHeight
            )
        }
        .frame(maxWidth: cardWidth, maxHeight: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        // Layered shadow: soft white ambient halo (visible against the dark
        // bg) + a deeper black drop shadow that grounds the card.
        .shadow(color: .white.opacity(0.08), radius: 26, y: 0)
        .shadow(color: .black.opacity(0.75), radius: 22, y: 18)
        .shadow(color: .black.opacity(0.45), radius: 40, y: 32)
    }

    private var caption: some View {
        VStack(spacing: 3) {
            Text(mockup.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            // Concept mockup — show only the illustrative app name. No
            // fabricated rating (these are example contexts, not real apps).
            Text(mockup.appName)
                .font(Theme.Typo.mono(11))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: MockupViewRegistry — dispatch UsageMockup → per-id SwiftUI view
// MARK: ─────────────────────────────────────────────────────────────

/// Central lookup that maps a `UsageMockup` to its bespoke per-id SwiftUI
/// screen. Parallel to `AnimationPreviewRegistry` — one entry per mockup
/// layout, plus a labeled fallback for unknown layouts.
enum MockupViewRegistry {

    @ViewBuilder
    static func view(for mockup: UsageMockup,
                     cardWidth: CGFloat,
                     cardHeight: CGFloat) -> some View {
        switch mockup.layout {
        case .aiChat:          MockAIChatView(mockup: mockup)
        case .onboarding:      MockOnboardingView(mockup: mockup)
        case .paywall:         MockPaywallView(mockup: mockup)
        case .music:           MockMusicView(mockup: mockup)
        case .success:         MockSuccessView(mockup: mockup)
        case .reading:         MockReadingView(mockup: mockup)
        case .fitness:         MockFitnessView(mockup: mockup)
        case .cryptoWallet:    MockCryptoWalletView(mockup: mockup)
        case .meditation:      MockMeditationView(mockup: mockup)
        case .sleep:           MockSleepView(mockup: mockup)
        case .weather:         MockWeatherView(mockup: mockup)
        case .bankSuccess:     MockBankSuccessView(mockup: mockup)
        case .photoGallery:    MockPhotoGalleryView(mockup: mockup)
        case .launchSplash:    MockLaunchSplashView(mockup: mockup)
        case .audioCall:       MockAudioCallView(mockup: mockup)
        case .voiceAssistant:  MockVoiceAssistantView(mockup: mockup)
        case .nft:             MockNFTView(mockup: mockup)
        case .astrology:       MockAstrologyView(mockup: mockup)
        case .dating:          MockDatingView(mockup: mockup)
        case .yoga:            MockYogaView(mockup: mockup)
        case .coinDetail:      MockCoinDetailView(mockup: mockup)
        case .subUnlocked:     MockSubUnlockedView(mockup: mockup)
        case .workoutSummary:  MockWorkoutSummaryView(mockup: mockup)
        case .ticket:          MockTicketView(mockup: mockup)
        case .yearReview:      MockYearReviewView(mockup: mockup)
        case .emptyInbox:      MockEmptyInboxView(mockup: mockup)
        case .recipe:          MockRecipeView(mockup: mockup)
        case .travel:          MockTravelView(mockup: mockup)
        case .loyalty:         MockLoyaltyView(mockup: mockup)
        case .achievement:     MockAchievementView(mockup: mockup)
        case .generic:         MockGenericFallbackView(mockup: mockup)
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: Shared mockup chrome — status bar, home indicator, masks
// MARK: ─────────────────────────────────────────────────────────────

/// iOS-style status bar (time + wifi + battery) used at the top of each
/// mockup screen.
private struct MockStatusBar: View {
    var tint: Color = .white
    var body: some View {
        HStack {
            Text("9:41")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "wifi").font(.system(size: 11, weight: .semibold))
                Image(systemName: "battery.100").font(.system(size: 13))
            }
        }
        .foregroundStyle(tint)
    }
}

/// Small white capsule at the bottom — the iPhone home indicator.
private struct MockHomeIndicator: View {
    var tint: Color = .white
    var body: some View {
        Capsule()
            .fill(tint.opacity(0.4))
            .frame(width: 134, height: 5)
            .padding(.bottom, 8)
    }
}

/// Vertical mask that fades the aurora out so the lower half of the screen
/// stays legible. Replicates the JSX `linear-gradient(180deg, black, clear)`
/// pattern shared by most mocks.
private struct AuroraTopMask<Content: View>: View {
    let content: Content
    var fadeStart: CGFloat = 0.5
    var fadeEnd: CGFloat = 1.0
    init(fadeStart: CGFloat = 0.5,
         fadeEnd: CGFloat = 1.0,
         @ViewBuilder content: () -> Content) {
        self.fadeStart = fadeStart
        self.fadeEnd = fadeEnd
        self.content = content()
    }
    var body: some View {
        content.mask(
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: fadeStart),
                    .init(color: .clear, location: fadeEnd)
                ],
                startPoint: .top, endPoint: .bottom
            )
        )
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 1. MockAIChatView — aurora-mesh · Apple Intelligence chat
// MARK: ─────────────────────────────────────────────────────────────

private struct MockAIChatView: View {
    let mockup: UsageMockup
    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0x08 / 255, green: 0x08 / 255, blue: 0x0C / 255)
            AuroraTopMask(fadeStart: 0.35, fadeEnd: 0.55) {
                AnimationPreviewRegistry.view(for: mockup.animationId)
            }
            VStack(spacing: 0) {
                MockStatusBar()
                    .padding(.horizontal, 20).padding(.top, 14)
                header.padding(.horizontal, 20).padding(.top, 16)
                Spacer(minLength: 18)
                bubblesArea
                    .padding(.horizontal, 16)
                Spacer()
                aiResponse.padding(.horizontal, 16)
                composer
                    .padding(.horizontal, 14).padding(.bottom, 6)
                MockHomeIndicator()
            }
        }
        .foregroundStyle(.white)
    }

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(.system(size: 11, weight: .bold))
                Text("Intelligence")
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            Spacer()
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .bold))
                .frame(width: 30, height: 30)
                .background(.ultraThinMaterial, in: Circle())
        }
    }

    private var bubblesArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    ForEach(0..<3) { _ in
                        Circle().fill(Color.white).frame(width: 5, height: 5)
                    }
                }
                Text("generating an answer")
                    .font(.system(size: 12)).italic()
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(.ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("Write a haiku about Tokyo at night, but make it feel cinematic.")
                .font(.system(size: 13))
                .foregroundStyle(.black)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.white.opacity(0.96),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.leading, 40)
        }
    }

    private var aiResponse: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Neon rain falls slow —")
            Text("Shibuya breathes through the glass.")
            HStack(spacing: 1) {
                Text("One stranger looks back.")
                    .foregroundStyle(.white.opacity(0.7))
                Rectangle()
                    .fill(Theme.Palette.accent)
                    .frame(width: 2, height: 12)
            }
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 50)
    }

    private var composer: some View {
        HStack(spacing: 8) {
            Text("Ask anything…")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 14)
            Circle()
                .fill(Theme.Palette.accent)
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                )
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 2. MockOnboardingView — aurora-borealis · NorthLight splash
// MARK: ─────────────────────────────────────────────────────────────

private struct MockOnboardingView: View {
    let mockup: UsageMockup
    var body: some View {
        ZStack {
            AnimationPreviewRegistry.view(for: mockup.animationId)
            RadialGradient(
                colors: [.clear, .clear, .black.opacity(0.6)],
                center: .center, startRadius: 60, endRadius: 320
            )
            VStack(spacing: 0) {
                MockStatusBar()
                    .padding(.horizontal, 20).padding(.top, 14)
                Spacer(minLength: 28)
                HStack(spacing: 6) {
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 11))
                    Text("NORTHLIGHT")
                        .font(.system(size: 13, weight: .heavy))
                        .tracking(4)
                }
                .foregroundStyle(.white.opacity(0.85))
                Spacer()
                VStack(spacing: 12) {
                    Text("See the sky\nwhere you sleep.")
                        .font(.system(size: 30, weight: .heavy))
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                    Text("Aurora alerts tuned to your exact GPS location. Get notified the moment the lights come out.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
                .padding(.horizontal, 20)
                Spacer()
                HStack(spacing: 6) {
                    Capsule().fill(.white).frame(width: 20, height: 6)
                    Circle().fill(.white.opacity(0.3)).frame(width: 6, height: 6)
                    Circle().fill(.white.opacity(0.3)).frame(width: 6, height: 6)
                }
                VStack(spacing: 8) {
                    primaryCTA("Start tracking", fg: .black, bg: .white)
                    Text("I already have an account")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 22).padding(.top, 10)
                MockHomeIndicator()
            }
        }
        .foregroundStyle(.white)
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 3. MockPaywallView — liquid-chrome · Folio Pro
// MARK: ─────────────────────────────────────────────────────────────

private struct MockPaywallView: View {
    let mockup: UsageMockup
    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0C / 255)
            AuroraTopMask(fadeStart: 0.3, fadeEnd: 0.55) {
                AnimationPreviewRegistry.view(for: mockup.animationId)
            }
            VStack(spacing: 0) {
                MockStatusBar()
                    .padding(.horizontal, 20).padding(.top, 14)
                HStack {
                    Spacer()
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 30, height: 30)
                        .background(Color.black.opacity(0.35), in: Circle())
                }
                .padding(.horizontal, 12).padding(.top, 6)
                Spacer(minLength: 8)
                logoCard
                VStack(spacing: 6) {
                    Text("Folio Pro")
                        .font(.system(size: 26, weight: .heavy))
                    Text("Unlimited portfolios. Pro analytics. White-glove sync.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 22)
                }
                .padding(.top, 14)
                features.padding(.horizontal, 22).padding(.top, 18)
                Spacer()
                VStack(spacing: 6) {
                    chromeCTA
                    Text("Cancel anytime · Restore purchase")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.horizontal, 22).padding(.bottom, 12)
                MockHomeIndicator()
            }
            .foregroundStyle(.white)
        }
    }

    private var logoCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
                .frame(width: 80, height: 80)
            Image(systemName: "star.fill")
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0xC9 / 255, green: 0xD6 / 255, blue: 0xFF / 255),
                            Color(red: 0x5F / 255, green: 0x76 / 255, blue: 0xA8 / 255)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
                )
        }
    }

    private var features: some View {
        VStack(spacing: 8) {
            ForEach(["Unlimited holdings", "Tax-loss harvesting AI", "Real-time alerts"], id: \.self) { row in
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [
                                    Color(red: 0xC9 / 255, green: 0xD6 / 255, blue: 0xFF / 255),
                                    Color(red: 0x5F / 255, green: 0x76 / 255, blue: 0xA8 / 255)
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 18, height: 18)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.black)
                    }
                    Text(row)
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.white.opacity(0.04),
                            in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                )
            }
        }
    }

    private var chromeCTA: some View {
        Text("Start 7-day free trial · $14.99/mo")
            .font(.system(size: 14, weight: .heavy))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0xC9 / 255, green: 0xD6 / 255, blue: 0xFF / 255),
                        Color(red: 0xB4 / 255, green: 0x9B / 255, blue: 0xD9 / 255)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .shadow(color: Color(red: 0xB4 / 255, green: 0x9B / 255, blue: 0xD9 / 255).opacity(0.3), radius: 10, y: 6)
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 4. MockMusicView — aurora-pulse · Late Bloom now-playing
// MARK: ─────────────────────────────────────────────────────────────

private struct MockMusicView: View {
    let mockup: UsageMockup
    var body: some View {
        ZStack {
            AnimationPreviewRegistry.view(for: mockup.animationId)
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.4), location: 0),
                    .init(color: .clear, location: 0.3),
                    .init(color: .clear, location: 0.7),
                    .init(color: .black.opacity(0.5), location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )
            VStack(spacing: 0) {
                MockStatusBar()
                    .padding(.horizontal, 20).padding(.top, 14)
                header.padding(.horizontal, 18).padding(.top, 12)
                Spacer(minLength: 14)
                albumArt
                Spacer().frame(height: 22)
                trackInfo
                Spacer()
                scrubber.padding(.horizontal, 28)
                controls.padding(.top, 18).padding(.bottom, 12)
                MockHomeIndicator()
            }
            .foregroundStyle(.white)
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "chevron.down")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            VStack(spacing: 1) {
                Text("PLAYING FROM ALBUM")
                    .font(.system(size: 9, weight: .semibold))
                    .opacity(0.6).tracking(1)
                Text("Late Bloom")
                    .font(.system(size: 13, weight: .semibold))
            }
            Spacer()
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .semibold))
        }
    }

    private var albumArt: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 0xFF / 255, green: 0x3D / 255, blue: 0x71 / 255),
                        Color(red: 0x7C / 255, green: 0x5A / 255, blue: 0xFF / 255),
                        Color(red: 0x22 / 255, green: 0xD3 / 255, blue: 0xEE / 255)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 200, height: 200)
                .shadow(color: Color(red: 0x7C / 255, green: 0x5A / 255, blue: 0xFF / 255).opacity(0.5), radius: 25, y: 12)
            Circle()
                .fill(.white.opacity(0.4))
                .frame(width: 50, height: 50)
                .blur(radius: 12)
                .offset(x: 24, y: -130)
            Text("LATE\nBLOOM")
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(.white)
                .padding(14)
        }
    }

    private var trackInfo: some View {
        VStack(spacing: 4) {
            Text("Midnight Static")
                .font(.system(size: 21, weight: .heavy))
            Text("Eira Volkov · Late Bloom")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.65))
        }
    }

    private var scrubber: some View {
        VStack(spacing: 6) {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.2)).frame(height: 3)
                    Capsule().fill(.white).frame(width: g.size.width * 0.42, height: 3)
                    Circle().fill(.white).frame(width: 10, height: 10)
                        .offset(x: g.size.width * 0.42 - 5)
                }
            }
            .frame(height: 10)
            HStack {
                Text("1:42")
                Spacer()
                Text("-2:18")
            }
            .font(Theme.Typo.mono(10))
            .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var controls: some View {
        HStack(spacing: 32) {
            Image(systemName: "backward.fill").font(.system(size: 22))
            ZStack {
                Circle().fill(.white).frame(width: 60, height: 60)
                Image(systemName: "pause.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.black)
            }
            Image(systemName: "forward.fill").font(.system(size: 22))
        }
        .foregroundStyle(.white)
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 5. MockSuccessView — aurora-bloom · Welcome aboard
// MARK: ─────────────────────────────────────────────────────────────

private struct MockSuccessView: View {
    let mockup: UsageMockup
    var body: some View {
        ZStack {
            AnimationPreviewRegistry.view(for: mockup.animationId)
            VStack(spacing: 0) {
                MockStatusBar()
                    .padding(.horizontal, 20).padding(.top, 14)
                Spacer()
                Text("PLAN UPGRADED")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.5)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                Text("Welcome\naboard.")
                    .font(.system(size: 40, weight: .black))
                    .multilineTextAlignment(.center)
                    .lineSpacing(-4)
                    .padding(.top, 16)
                Text("Your premium features are unlocked. Let's set up your first project.")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28).padding(.top, 12)
                Spacer()
                VStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Text("Set up project")
                            .font(.system(size: 14, weight: .heavy))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(Color(red: 0.10, green: 0.04, blue: 0.08))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.95),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Text("Receipt sent to maya@example.com")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 22).padding(.bottom, 12)
                MockHomeIndicator()
            }
            .foregroundStyle(.white)
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 6. MockReadingView — aurora-marble · Paperbound book detail
// MARK: ─────────────────────────────────────────────────────────────

private struct MockReadingView: View {
    let mockup: UsageMockup
    private let cream = Color(red: 0xF5 / 255, green: 0xED / 255, blue: 0xE0 / 255)
    private let ink = Color(red: 0x1A / 255, green: 0x0A / 255, blue: 0x08 / 255)

    var body: some View {
        ZStack(alignment: .top) {
            cream
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    AnimationPreviewRegistry.view(for: mockup.animationId)
                        .frame(height: 240)
                        .clipped()
                    VStack(spacing: 0) {
                        MockStatusBar()
                            .padding(.horizontal, 20).padding(.top, 14)
                        HStack {
                            navCircle(system: "chevron.left")
                            Spacer()
                            HStack(spacing: 6) {
                                navCircle(system: "magnifyingglass")
                                navCircle(system: "bookmark")
                            }
                        }
                        .padding(.horizontal, 14).padding(.top, 4)
                        Spacer().frame(height: 6)
                        bookCard
                        Spacer(minLength: 0)
                    }
                }
                .frame(height: 240)
                lowerPanel
            }
        }
    }

    private func navCircle(system: String) -> some View {
        Image(systemName: system)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(Color.black.opacity(0.4), in: Circle())
    }

    private var bookCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 0xD4 / 255, green: 0xA5 / 255, blue: 0x74 / 255),
                        Color(red: 0x8B / 255, green: 0x45 / 255, blue: 0x13 / 255)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 110, height: 165)
                .shadow(color: .black.opacity(0.45), radius: 20, y: 10)
            VStack(alignment: .leading, spacing: 0) {
                Text("A NOVEL")
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(2)
                    .opacity(0.75)
                Text("Where\nthe Pages\nBleed Gold")
                    .font(.system(size: 16, weight: .heavy, design: .serif))
                    .padding(.top, 22)
                    .lineSpacing(-2)
                Spacer()
                Text("Lina Whitfield")
                    .font(.system(size: 9))
                    .italic()
                    .opacity(0.85)
            }
            .foregroundStyle(Color(red: 0xF5 / 255, green: 0xE6 / 255, blue: 0xD3 / 255))
            .padding(12)
            .frame(width: 110, height: 165, alignment: .topLeading)
        }
    }

    private var lowerPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Where the Pages Bleed Gold")
                .font(.system(size: 20, weight: .heavy, design: .serif))
            Text("Lina Whitfield · 312 pages · Literary fiction")
                .font(.system(size: 12))
                .foregroundStyle(ink.opacity(0.55))
            HStack(spacing: 10) {
                Text("★ 4.7"); Text("·"); Text("12k reviews"); Text("·"); Text("8h 24m")
            }
            .font(.system(size: 12))
            .foregroundStyle(ink.opacity(0.65))
            .padding(.top, 6)
            Text("A bookseller in mid-century Kyoto inherits a marbled diary that rewrites itself overnight. As pages bleed gold ink…")
                .font(.system(size: 13, design: .serif))
                .foregroundStyle(ink.opacity(0.78))
                .padding(.top, 8)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Text("Begin reading · Chapter 1")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(cream)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(ink, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            MockHomeIndicator(tint: ink)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .foregroundStyle(ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cream)
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 7. MockFitnessView — lava-flow · HIIT timer
// MARK: ─────────────────────────────────────────────────────────────

private struct MockFitnessView: View {
    let mockup: UsageMockup
    var body: some View {
        ZStack {
            AnimationPreviewRegistry.view(for: mockup.animationId)
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.5), location: 0),
                    .init(color: .clear, location: 0.3),
                    .init(color: .clear, location: 0.6),
                    .init(color: .black.opacity(0.7), location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )
            VStack(spacing: 0) {
                MockStatusBar()
                    .padding(.horizontal, 20).padding(.top, 14)
                header.padding(.horizontal, 20).padding(.top, 12)
                Spacer(minLength: 16)
                timer
                Spacer().frame(height: 22)
                exerciseCard.padding(.horizontal, 22)
                Spacer().frame(height: 14)
                upNext.padding(.horizontal, 22)
                Spacer()
                controls.padding(.bottom, 10)
                MockHomeIndicator()
            }
            .foregroundStyle(.white)
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "line.3.horizontal").font(.system(size: 18))
            Spacer()
            Text("HIIT · ROUND 4 OF 8")
                .font(.system(size: 10, weight: .heavy))
                .tracking(1).opacity(0.7)
            Spacer()
            HStack(spacing: 4) {
                Circle().fill(Color(red: 0.2, green: 0.78, blue: 0.35))
                    .frame(width: 6, height: 6)
                Text("LIVE").font(.system(size: 10, weight: .heavy))
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
        }
    }

    private var timer: some View {
        VStack(spacing: 0) {
            Text("WORK")
                .font(.system(size: 14, weight: .heavy))
                .tracking(3).opacity(0.7)
            Text("00:42")
                .font(.system(size: 92, weight: .black, design: .monospaced))
                .shadow(color: Color(red: 1, green: 0.4, blue: 0).opacity(0.6), radius: 20)
        }
    }

    private var exerciseCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NOW")
                .font(.system(size: 10, weight: .heavy)).tracking(1.5).opacity(0.6)
            Text("Mountain Climbers")
                .font(.system(size: 22, weight: .heavy))
            HStack(spacing: 14) {
                Text("💪 Full body")
                Text("🔥 8.2 cal/min")
            }
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18).padding(.vertical, 14)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var upNext: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08))
                Text("🧘").font(.system(size: 16))
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text("UP NEXT")
                    .font(.system(size: 9, weight: .heavy)).tracking(1).opacity(0.5)
                Text("Rest · 20s")
                    .font(.system(size: 12, weight: .heavy))
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.white.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var controls: some View {
        HStack(spacing: 24) {
            roundButton(system: "backward.end.fill", size: 48)
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 1, green: 0.66, blue: 0.2),
                            Color(red: 1, green: 0.3, blue: 0)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 72, height: 72)
                    .shadow(color: Color(red: 1, green: 0.3, blue: 0).opacity(0.5), radius: 20, y: 8)
                Image(systemName: "pause.fill")
                    .font(.system(size: 22, weight: .bold))
            }
            roundButton(system: "forward.end.fill", size: 48)
        }
    }

    private func roundButton(system: String, size: CGFloat) -> some View {
        Circle()
            .fill(.ultraThinMaterial)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: system)
                    .font(.system(size: size * 0.36, weight: .bold))
            )
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 8. MockCryptoWalletView — au-sunset · Wallet
// MARK: ─────────────────────────────────────────────────────────────

private struct MockCryptoWalletView: View {
    let mockup: UsageMockup
    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0x08 / 255, green: 0x08 / 255, blue: 0x0A / 255)
            AnimationPreviewRegistry.view(for: mockup.animationId)
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.3), location: 0),
                    .init(color: .clear, location: 0.3),
                    .init(color: .clear, location: 0.7),
                    .init(color: .black.opacity(0.55), location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )
            VStack(spacing: 0) {
                MockStatusBar()
                    .padding(.horizontal, 20).padding(.top, 14)
                header.padding(.horizontal, 20).padding(.top, 14)
                Spacer(minLength: 14)
                balance
                Spacer().frame(height: 18)
                actions.padding(.horizontal, 22)
                Spacer()
                holdings.padding(.horizontal, 14).padding(.bottom, 10)
                MockHomeIndicator()
            }
            .foregroundStyle(.white)
        }
    }

    private var header: some View {
        HStack {
            Text("Wallet")
                .font(.system(size: 16, weight: .heavy))
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(.ultraThinMaterial, in: Circle())
        }
    }

    private var balance: some View {
        VStack(spacing: 4) {
            Text("TOTAL BALANCE")
                .font(.system(size: 10, weight: .heavy))
                .tracking(2).opacity(0.6)
            Text("$24,820")
                .font(.system(size: 42, weight: .heavy, design: .monospaced))
            Text("↑ $1,247 · +5.30% today")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Color(red: 0.2, green: 0.78, blue: 0.35))
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            ForEach(["Send", "Receive", "Swap", "Buy"], id: \.self) { a in
                Text(a)
                    .font(.system(size: 12, weight: .heavy))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var holdings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TOP HOLDINGS")
                .font(.system(size: 11, weight: .heavy)).tracking(1).opacity(0.6)
            VStack(spacing: 0) {
                holdingRow(sym: "BTC", name: "Bitcoin", pct: "+2.4%", val: "$12,420",
                           color: Color(red: 0xF7 / 255, green: 0x93 / 255, blue: 0x1A / 255), neg: false)
                Divider().background(Color.white.opacity(0.08))
                holdingRow(sym: "ETH", name: "Ethereum", pct: "+8.1%", val: "$ 8,920",
                           color: Color(red: 0x62 / 255, green: 0x7E / 255, blue: 0xEA / 255), neg: false)
                Divider().background(Color.white.opacity(0.08))
                holdingRow(sym: "SOL", name: "Solana", pct: "-1.2%", val: "$ 3,480",
                           color: Color(red: 0x14 / 255, green: 0xF1 / 255, blue: 0x95 / 255), neg: true)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func holdingRow(sym: String, name: String, pct: String, val: String, color: Color, neg: Bool) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(color).frame(width: 30, height: 30)
                Text(sym).font(.system(size: 10, weight: .heavy)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.system(size: 13, weight: .heavy))
                Text(pct)
                    .font(Theme.Typo.mono(11))
                    .foregroundStyle(neg ? Theme.Palette.accent : Color(red: 0.2, green: 0.78, blue: 0.35))
            }
            Spacer()
            Text(val).font(Theme.Typo.mono(13, weight: .heavy))
        }
        .padding(.vertical, 6)
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 9. MockMeditationView — au-calmdrift · Breathing session
// MARK: ─────────────────────────────────────────────────────────────

private struct MockMeditationView: View {
    let mockup: UsageMockup
    var body: some View {
        ZStack {
            AnimationPreviewRegistry.view(for: mockup.animationId)
            VStack(spacing: 0) {
                MockStatusBar()
                    .padding(.horizontal, 20).padding(.top, 14)
                VStack(spacing: 6) {
                    Text("DAY 12 · AWARENESS")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.5).opacity(0.65)
                    Text("Breathe with the sky.")
                        .font(.system(size: 22, design: .serif))
                        .italic()
                }
                .padding(.top, 14)
                Spacer()
                breathingCircle
                Spacer()
                VStack(spacing: 4) {
                    Text("04:32")
                        .font(.system(size: 34, weight: .light, design: .monospaced))
                    Text("of 10 minutes remaining")
                        .font(.system(size: 12)).opacity(0.6)
                }
                Spacer().frame(height: 24)
                HStack(spacing: 18) {
                    Circle().fill(.ultraThinMaterial)
                        .frame(width: 48, height: 48)
                        .overlay(Image(systemName: "pause.fill"))
                    Circle().fill(.ultraThinMaterial)
                        .frame(width: 60, height: 60)
                        .overlay(Image(systemName: "play.fill"))
                }
                .padding(.bottom, 14)
                MockHomeIndicator()
            }
            .foregroundStyle(.white)
        }
    }

    private var breathingCircle: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.3), lineWidth: 1)
                .frame(width: 150, height: 150)
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 116, height: 116)
            Text("INHALE")
                .font(.system(size: 13, weight: .semibold))
                .tracking(2)
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 10. MockSleepView — au-midnight · Sleep score
// MARK: ─────────────────────────────────────────────────────────────

private struct MockSleepView: View {
    let mockup: UsageMockup
    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0C / 255)
            AnimationPreviewRegistry.view(for: mockup.animationId)
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.3), location: 0),
                    .init(color: .clear, location: 0.3),
                    .init(color: .clear, location: 0.6),
                    .init(color: .black.opacity(0.5), location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )
            VStack(spacing: 0) {
                MockStatusBar()
                    .padding(.horizontal, 20).padding(.top, 14)
                header.padding(.horizontal, 20).padding(.top, 14)
                Spacer(minLength: 14)
                duration
                Spacer().frame(height: 20)
                stagesBar.padding(.horizontal, 22)
                Spacer().frame(height: 14)
                stageLegend.padding(.horizontal, 22)
                Spacer()
                insightCard.padding(.horizontal, 14).padding(.bottom, 8)
                MockHomeIndicator()
            }
            .foregroundStyle(.white)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Last night").font(.system(size: 13)).opacity(0.6)
                Text("Sleep score 88")
                    .font(.system(size: 26, weight: .heavy))
            }
            Spacer()
            Text("Wed · Mar 6")
                .font(Theme.Typo.mono(11)).opacity(0.7)
        }
    }

    private var duration: some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("7").font(.system(size: 68, weight: .heavy, design: .monospaced))
                Text("h").font(.system(size: 20, weight: .heavy)).opacity(0.6)
                Text("42").font(.system(size: 68, weight: .heavy, design: .monospaced))
                Text("m").font(.system(size: 20, weight: .heavy)).opacity(0.6)
            }
            Text("15 min more than your average")
                .font(.system(size: 12)).opacity(0.6)
        }
    }

    private var stagesBar: some View {
        HStack(spacing: 0) {
            stageSlice(c: Color(red: 0x31 / 255, green: 0x2E / 255, blue: 0x81 / 255), pct: 0.18)
            stageSlice(c: Color(red: 0x7C / 255, green: 0x3A / 255, blue: 0xED / 255), pct: 0.32)
            stageSlice(c: Color(red: 0xA7 / 255, green: 0x8B / 255, blue: 0xFA / 255), pct: 0.26)
            stageSlice(c: Color(red: 0xFC / 255, green: 0xD3 / 255, blue: 0x4D / 255), pct: 0.08)
            stageSlice(c: Color(red: 0xA7 / 255, green: 0x8B / 255, blue: 0xFA / 255), pct: 0.16)
        }
        .frame(height: 12)
        .clipShape(Capsule())
    }

    private func stageSlice(c: Color, pct: CGFloat) -> some View {
        Rectangle().fill(c).frame(maxWidth: .infinity)
            .layoutPriority(Double(pct))
    }

    private var stageLegend: some View {
        let stages: [(String, String, Color)] = [
            ("Deep", "1h 28m", Color(red: 0x31 / 255, green: 0x2E / 255, blue: 0x81 / 255)),
            ("REM", "2h 14m", Color(red: 0x7C / 255, green: 0x3A / 255, blue: 0xED / 255)),
            ("Light", "3h 22m", Color(red: 0xA7 / 255, green: 0x8B / 255, blue: 0xFA / 255)),
            ("Awake", "38m", Color(red: 0xFC / 255, green: 0xD3 / 255, blue: 0x4D / 255))
        ]
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(stages, id: \.0) { s in
                HStack(spacing: 8) {
                    Circle().fill(s.2).frame(width: 8, height: 8)
                    Text(s.0).font(.system(size: 12)).opacity(0.7)
                    Spacer()
                    Text(s.1).font(Theme.Typo.mono(12, weight: .heavy))
                }
            }
        }
    }

    private var insightCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("INSIGHT")
                .font(.system(size: 10, weight: .heavy)).tracking(1).opacity(0.6)
            Text("You fell asleep 22 minutes faster after evening walks this week.")
                .font(.system(size: 13))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 11. MockWeatherView — au-storm · Jakarta thunderstorm
// MARK: ─────────────────────────────────────────────────────────────

private struct MockWeatherView: View {
    let mockup: UsageMockup
    var body: some View {
        ZStack {
            Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0C / 255)
            AnimationPreviewRegistry.view(for: mockup.animationId)
            LinearGradient(colors: [.black.opacity(0.2), .clear, .black.opacity(0.5)],
                           startPoint: .top, endPoint: .bottom)
            VStack(spacing: 0) {
                MockStatusBar()
                    .padding(.horizontal, 20).padding(.top, 14)
                Spacer().frame(height: 8)
                VStack(spacing: 2) {
                    Text("Jakarta")
                        .font(.system(size: 22, weight: .medium))
                    Text("28°")
                        .font(.system(size: 78, weight: .ultraLight))
                    Text("Thunderstorms")
                        .font(.system(size: 15)).opacity(0.85)
                    Text("H: 32° · L: 25°")
                        .font(.system(size: 12)).opacity(0.65)
                }
                Spacer()
                hourly.padding(.horizontal, 14)
                Spacer().frame(height: 12)
                severe.padding(.horizontal, 14).padding(.bottom, 8)
                MockHomeIndicator()
            }
            .foregroundStyle(.white)
        }
    }

    private var hourly: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HOURLY FORECAST")
                .font(.system(size: 10, weight: .heavy)).tracking(1).opacity(0.6)
            HStack {
                ForEach([
                    ("Now", "28°", "⛈️"), ("4PM", "29°", "⛈️"), ("5PM", "28°", "🌧️"),
                    ("6PM", "27°", "🌧️"), ("7PM", "26°", "🌧️"), ("8PM", "25°", "☁️")
                ], id: \.0) { h in
                    VStack(spacing: 4) {
                        Text(h.0).font(.system(size: 10)).opacity(0.7)
                        Text(h.2).font(.system(size: 18))
                        Text(h.1).font(Theme.Typo.mono(12, weight: .heavy))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var severe: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("SEVERE WEATHER")
                    .font(.system(size: 10, weight: .heavy)).tracking(1).opacity(0.6)
                Text("Flash flood warning until 8 PM")
                    .font(.system(size: 13, weight: .semibold))
            }
            Spacer()
            Text("ALERT")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.black)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color(red: 0xFA / 255, green: 0xCC / 255, blue: 0x15 / 255),
                            in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 12. MockBankSuccessView — au-solar · Transfer sent
// MARK: ─────────────────────────────────────────────────────────────

private struct MockBankSuccessView: View {
    let mockup: UsageMockup
    var body: some View {
        ZStack {
            AnimationPreviewRegistry.view(for: mockup.animationId)
            VStack(spacing: 0) {
                MockStatusBar()
                    .padding(.horizontal, 20).padding(.top, 14)
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.95))
                        .frame(width: 76, height: 76)
                        .shadow(color: .black.opacity(0.3), radius: 14, y: 8)
                    Image(systemName: "checkmark")
                        .font(.system(size: 30, weight: .heavy))
                        .foregroundStyle(Color(red: 0.2, green: 0.78, blue: 0.35))
                }
                Text("Transfer sent")
                    .font(.system(size: 30, weight: .heavy))
                    .padding(.top, 16)
                Text("To Maya Ortega · BCA 7842 ···")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 6)
                Spacer()
                Text("Rp 2.450.000")
                    .font(.system(size: 50, weight: .heavy, design: .monospaced))
                Text("Ref · TX-2024031647821")
                    .font(Theme.Typo.mono(12))
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.top, 6)
                Spacer()
                HStack(spacing: 10) {
                    secondaryCTA("Share receipt")
                    primaryCTA("Done", fg: .black, bg: .white)
                }
                .padding(.horizontal, 22).padding(.bottom, 10)
                MockHomeIndicator()
            }
            .foregroundStyle(.white)
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 13. MockPhotoGalleryView — au-bokeh · Memories
// MARK: ─────────────────────────────────────────────────────────────

private struct MockPhotoGalleryView: View {
    let mockup: UsageMockup
    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0C / 255)
            AnimationPreviewRegistry.view(for: mockup.animationId)
            LinearGradient(colors: [.black.opacity(0.2), .clear, .black.opacity(0.4)],
                           startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 0) {
                MockStatusBar()
                    .padding(.horizontal, 20).padding(.top, 14)
                HStack {
                    Text("Memories").font(.system(size: 26, weight: .heavy))
                    Spacer()
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 30, height: 30)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding(.horizontal, 20).padding(.top, 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Featured collection")
                        .font(.system(size: 11)).opacity(0.6)
                    Text("Spring in Tokyo")
                        .font(.system(size: 19, weight: .heavy))
                }
                .padding(.horizontal, 20).padding(.top, 10)
                photoGrid.padding(.horizontal, 16).padding(.top, 12)
                Spacer()
                replayCTA.padding(.horizontal, 16).padding(.bottom, 8)
                MockHomeIndicator()
            }
            .foregroundStyle(.white)
        }
    }

    private var photoGrid: some View {
        let tiles: [LinearGradient] = [
            grad(0xFFD1DC, 0xFFB7C5),
            grad(0xC7CEEA, 0xB5EAD7),
            grad(0xFFDAC1, 0xE2F0CB),
            grad(0xFFB7C5, 0xF8B195),
            grad(0xB5EAD7, 0xC7CEEA),
            grad(0xF8B195, 0xFFDAC1),
            grad(0xC7CEEA, 0xFFD1DC)
        ]
        return LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 6),
            GridItem(.flexible(), spacing: 6),
            GridItem(.flexible(), spacing: 6)
        ], spacing: 6) {
            ForEach(0..<tiles.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 8)
                    .fill(tiles[i])
                    .frame(height: i == 0 || i == 5 ? 90 : 80)
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            }
        }
    }

    private func grad(_ a: UInt32, _ b: UInt32) -> LinearGradient {
        LinearGradient(colors: [hexColor(a), hexColor(b)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var replayCTA: some View {
        HStack(spacing: 10) {
            Text("✨").font(.system(size: 18))
            Text("Replay this trip as a movie")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 14. MockLaunchSplashView — au-galaxy · Orbit splash
// MARK: ─────────────────────────────────────────────────────────────

private struct MockLaunchSplashView: View {
    let mockup: UsageMockup
    var body: some View {
        ZStack {
            AnimationPreviewRegistry.view(for: mockup.animationId)
            // Soft focal glow so the splash centre reads as intentional light,
            // not a dead/dark frame.
            RadialGradient(
                colors: [Theme.Palette.accent.opacity(0.35), .clear],
                center: .center, startRadius: 8, endRadius: 180
            )
            .blendMode(.screen)
            .allowsHitTesting(false)
            VStack(spacing: 0) {
                MockStatusBar()
                    .padding(.horizontal, 20).padding(.top, 14)
                Spacer()
                OrbitLogo()
                    .padding(.bottom, 18)
                Text("Orbit")
                    .font(.system(size: 30, weight: .heavy))
                Text("Find your gravity.")
                    .font(.system(size: 13)).opacity(0.65).tracking(1)
                Spacer()
                LaunchLoadingDots()
                    .padding(.bottom, 18)
                MockHomeIndicator()
            }
            .foregroundStyle(.white)
        }
    }
}

/// "Orbit" app mark for the launch-splash mockup: a glowing planet with a
/// moon orbiting it. Replaces a dashed-circle SF Symbol that read as a broken
/// image / loading placeholder.
private struct OrbitLogo: View {
    @State private var angle: Double = 0
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .frame(width: 100, height: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                )
            // Orbit ring.
            Circle()
                .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
                .frame(width: 66, height: 66)
            // Planet.
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Theme.Palette.accent, Color(red: 0.49, green: 0.31, blue: 0.91)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 28)
                .shadow(color: Theme.Palette.accent.opacity(0.5), radius: 10)
            // Moon, revolving on the ring.
            Circle()
                .fill(.white)
                .frame(width: 7, height: 7)
                .shadow(color: .white.opacity(0.8), radius: 4)
                .offset(x: 33)
                .rotationEffect(.degrees(angle))
        }
        .onAppear {
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                angle = 360
            }
        }
    }
}

/// Three pulsing dots — a polished "launching" indicator that reads as
/// intentional, unlike a lone spinner + "Connecting…" which looks stuck.
private struct LaunchLoadingDots: View {
    @State private var animating = false
    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                    .opacity(animating ? 1 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 15. MockAudioCallView — au-pulsar · Live audio room
// MARK: ─────────────────────────────────────────────────────────────

private struct MockAudioCallView: View {
    let mockup: UsageMockup
    private let speakers: [(String, Bool, Bool, String)] = [
        ("Maya", true, true, "M"),
        ("Devon", true, false, "D"),
        ("Aria", false, false, "A"),
        ("Kenji", true, false, "K")
    ]

    var body: some View {
        ZStack {
            Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0C / 255)
            AnimationPreviewRegistry.view(for: mockup.animationId)
            LinearGradient(colors: [.clear, .clear, .black.opacity(0.4)],
                           startPoint: .top, endPoint: .bottom)
            VStack(spacing: 0) {
                MockStatusBar()
                    .padding(.horizontal, 20).padding(.top, 14)
                topBar.padding(.horizontal, 20).padding(.top, 10)
                roomHeader.padding(.top, 14)
                Spacer().frame(height: 22)
                Text("SPEAKERS · 4")
                    .font(.system(size: 11, weight: .heavy)).tracking(1.5).opacity(0.55)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22)
                speakerGrid.padding(.horizontal, 28).padding(.top, 12)
                Spacer()
                reactions.padding(.bottom, 10)
                MockHomeIndicator()
            }
            .foregroundStyle(.white)
        }
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 5) {
                Circle().fill(Color(red: 0xFF / 255, green: 0x3D / 255, blue: 0x71 / 255))
                    .frame(width: 6, height: 6)
                Text("LIVE · 247").font(.system(size: 11, weight: .heavy))
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            Spacer()
            Text("Leave quietly")
                .font(.system(size: 12, weight: .heavy))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var roomHeader: some View {
        VStack(spacing: 4) {
            Text("Late-night design crits 🌙")
                .font(.system(size: 18, weight: .heavy))
            Text("Hosted by Maya · Tuesday Studio")
                .font(.system(size: 12)).opacity(0.6)
        }
    }

    private var speakerGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 18) {
            ForEach(speakers, id: \.0) { s in
                VStack(spacing: 6) {
                    ZStack {
                        if s.2 {
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 68, height: 68)
                        }
                        Circle()
                            .fill(LinearGradient(
                                colors: [hexColor(0x7C5AFF), hexColor(0xFF3D71)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 58, height: 58)
                            .overlay(
                                Text(s.3)
                                    .font(.system(size: 22, weight: .heavy))
                                    .foregroundStyle(.white)
                            )
                        if !s.1 {
                            Circle()
                                .fill(Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0C / 255))
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Image(systemName: "mic.slash.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.white.opacity(0.6))
                                )
                                .offset(x: 20, y: 20)
                        }
                    }
                    Text(s.0).font(.system(size: 12, weight: .semibold))
                    if s.1 && s.2 {
                        Text("SPEAKING")
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(1)
                            .foregroundStyle(hexColor(0x7C5AFF))
                    }
                }
            }
        }
    }

    private var reactions: some View {
        HStack(spacing: 10) {
            reactionBubble("✋")
            reactionBubble("👋")
            ZStack {
                Circle().fill(.ultraThinMaterial).frame(width: 48, height: 48)
                Image(systemName: "mic.fill").font(.system(size: 16))
            }
        }
    }

    private func reactionBubble(_ text: String) -> some View {
        Circle().fill(.ultraThinMaterial)
            .frame(width: 48, height: 48)
            .overlay(Text(text).font(.system(size: 20)))
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 16. MockVoiceAssistantView — au-pearl · Voice listen
// MARK: ─────────────────────────────────────────────────────────────

private struct MockVoiceAssistantView: View {
    let mockup: UsageMockup
    var body: some View {
        ZStack {
            AnimationPreviewRegistry.view(for: mockup.animationId)
            LinearGradient(colors: [.black.opacity(0.15), .clear, .black.opacity(0.4)],
                           startPoint: .top, endPoint: .bottom)
            VStack(spacing: 0) {
                MockStatusBar()
                    .padding(.horizontal, 20).padding(.top, 14)
                Text("LISTENING…")
                    .font(.system(size: 11, weight: .heavy)).tracking(2).opacity(0.65)
                    .padding(.top, 14)
                Spacer().frame(height: 30)
                transcriptCard.padding(.horizontal, 22)
                Spacer()
                waveform.padding(.bottom, 22)
                Text("Tap to confirm · Slide to cancel")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 12)
                MockHomeIndicator()
            }
            .foregroundStyle(.white)
        }
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                Text("\"Set a timer for the chicken at ") +
                Text("thirty").foregroundColor(Theme.Palette.accent).underline() +
                Text(" minutes, and dim the kitchen lights\"")
            }
            .font(.system(size: 19, weight: .semibold))
            .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var waveform: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach([12, 22, 8, 32, 18, 40, 14, 28, 36, 10, 24, 18, 30, 14, 22, 32, 16, 10], id: \.self) { h in
                Capsule()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 3, height: CGFloat(h))
            }
        }
        .frame(height: 50)
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 17. MockNFTView — au-holofoil · NFT detail
// MARK: ─────────────────────────────────────────────────────────────

private struct MockNFTView: View {
    let mockup: UsageMockup
    var body: some View {
        ZStack {
            Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0C / 255)
            AnimationPreviewRegistry.view(for: mockup.animationId)
            LinearGradient(colors: [.clear, .black.opacity(0.4)],
                           startPoint: .top, endPoint: .bottom)
            VStack(spacing: 0) {
                MockStatusBar()
                    .padding(.horizontal, 20).padding(.top, 14)
                HStack {
                    nav("chevron.left"); Spacer(); nav("square.and.arrow.up")
                }
                .padding(.horizontal, 14).padding(.top, 8)
                Spacer().frame(height: 12)
                nftCard
                Spacer()
                bidPanel.padding(.horizontal, 16).padding(.bottom, 10)
                MockHomeIndicator()
            }
            .foregroundStyle(.white)
        }
    }

    private func nav(_ system: String) -> some View {
        Image(systemName: system)
            .font(.system(size: 13, weight: .semibold))
            .frame(width: 32, height: 32)
            .background(.ultraThinMaterial, in: Circle())
    }

    private var nftCard: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(
                    colors: [hexColor(0x7C3AED).opacity(0.3), hexColor(0xEC4899).opacity(0.3)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 200, height: 270)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.5), radius: 30, y: 18)
            Text("🦋").font(.system(size: 80))
                .frame(width: 200, height: 270)
            VStack(alignment: .leading, spacing: 2) {
                Text("HOLOGRAPHIC · #047 / 500")
                    .font(.system(size: 8, weight: .semibold)).tracking(2).opacity(0.6)
                Text("Iridescent Wing")
                    .font(.system(size: 16, weight: .heavy))
            }
            .padding(14)
        }
        .rotation3DEffect(.degrees(-6), axis: (x: 0.4, y: 1, z: 0))
    }

    private var bidPanel: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current bid").font(.system(size: 11)).opacity(0.6)
                    Text("3.2 ETH")
                        .font(.system(size: 22, weight: .heavy, design: .monospaced))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Ends in").font(.system(size: 11)).opacity(0.6)
                    Text("02h 14m")
                        .font(Theme.Typo.mono(13, weight: .heavy))
                }
            }
            primaryCTA("Place bid", fg: .black, bg: .white)
        }
        .padding(14)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 18. MockAstrologyView — au-nebula · Daily horoscope
// MARK: ─────────────────────────────────────────────────────────────

private struct MockAstrologyView: View {
    let mockup: UsageMockup
    var body: some View {
        ZStack {
            Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0C / 255)
            AnimationPreviewRegistry.view(for: mockup.animationId)
            LinearGradient(colors: [.clear, .clear, .black.opacity(0.45)],
                           startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 0) {
                MockStatusBar()
                    .padding(.horizontal, 20).padding(.top, 14)
                VStack(alignment: .leading, spacing: 4) {
                    Text("WEDNESDAY, MARCH 6")
                        .font(.system(size: 10, weight: .heavy)).tracking(2).opacity(0.6)
                    Text("Your stars")
                        .font(.system(size: 28, design: .serif)).italic()
                }
                .padding(.horizontal, 20).padding(.top, 10)
                Spacer().frame(height: 16)
                VStack(spacing: 10) {
                    Text("♎").font(.system(size: 54))
                    Text("LIBRA · SUN")
                        .font(.system(size: 12, weight: .semibold)).tracking(2).opacity(0.7)
                    Text("Mercury, your messenger, is dancing with Venus today. Words you share will land softer than usual — speak the truth you've held back.")
                        .font(.system(size: 15, design: .serif))
                        .italic()
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 30)
                        .padding(.top, 6)
                }
                .frame(maxWidth: .infinity)
                Spacer()
                stats.padding(.horizontal, 22)
                Spacer().frame(height: 12)
                primaryCTA("Read full reading", fg: .black, bg: .white)
                    .padding(.horizontal, 22).padding(.bottom, 8)
                MockHomeIndicator()
            }
            .foregroundStyle(.white)
        }
    }

    private var stats: some View {
        HStack(spacing: 8) {
            statTile("LOVE", glyph: "◐◑◐", v: "High")
            statTile("CAREER", glyph: "◐◐○", v: "Steady")
            statTile("ENERGY", glyph: "◐◑●", v: "Rising")
        }
    }

    private func statTile(_ l: String, glyph: String, v: String) -> some View {
        VStack(spacing: 3) {
            Text(l).font(.system(size: 9, weight: .heavy)).tracking(1).opacity(0.5)
            Text(glyph).font(.system(size: 14)).padding(.top, 2)
            Text(v).font(.system(size: 11)).opacity(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 19. MockDatingView — au-sparkleveil · Profile card
// MARK: ─────────────────────────────────────────────────────────────

private struct MockDatingView: View {
    let mockup: UsageMockup
    var body: some View {
        ZStack {
            Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0C / 255)
            AnimationPreviewRegistry.view(for: mockup.animationId)
            VStack(spacing: 0) {
                MockStatusBar()
                    .padding(.horizontal, 20).padding(.top, 14)
                photoCard.padding(.horizontal, 16).padding(.top, 8)
                bioCard.padding(.horizontal, 16).padding(.top, 12)
                Spacer()
                swipeActions.padding(.bottom, 10)
                MockHomeIndicator()
            }
            .foregroundStyle(.white)
        }
    }

    private var photoCard: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(
                    colors: [hexColor(0xFFD1DC), hexColor(0xFFB7C5)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
            Text("👩🏻‍🎤").font(.system(size: 76))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack {
                HStack(spacing: 4) {
                    ForEach(0..<4, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(i == 0 ? Color.white : Color.white.opacity(0.35))
                            .frame(height: 3)
                    }
                }
                .padding(12)
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lina, 27")
                        .font(.system(size: 24, weight: .heavy))
                    HStack(spacing: 4) {
                        Text("📍")
                        Text("2 km away · Jakarta")
                            .font(.system(size: 12)).opacity(0.9)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            }
        }
        .frame(height: 280)
    }

    private var bioCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\"Looking for someone who'll actually try the spicy menu with me 🌶️ · Cat: 2 · Coffee: black\"")
                .font(.system(size: 13)).italic()
                .lineSpacing(3)
            HStack(spacing: 6) {
                ForEach(["Hiking", "Coffee", "Vinyl", "Languages"], id: \.self) { t in
                    Text(t)
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 9).padding(.vertical, 3)
                        .background(Color.white.opacity(0.1), in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var swipeActions: some View {
        HStack(spacing: 14) {
            actionCircle(system: "xmark", size: 52, fg: .white, bg: nil)
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Theme.Palette.accent, hexColor(0xFB7185)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 62, height: 62)
                    .shadow(color: Theme.Palette.accent.opacity(0.5), radius: 14, y: 8)
                Image(systemName: "heart.fill").font(.system(size: 24)).foregroundStyle(.white)
            }
            actionCircle(system: "star.fill", size: 52, fg: hexColor(0x3B82F6), bg: nil)
        }
    }

    private func actionCircle(system: String, size: CGFloat, fg: Color, bg: Color?) -> some View {
        Circle()
            .fill(.ultraThinMaterial)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: system)
                    .font(.system(size: size * 0.34, weight: .bold))
                    .foregroundStyle(fg)
            )
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 20. MockYogaView — au-ethereal · Warrior II
// MARK: ─────────────────────────────────────────────────────────────

private struct MockYogaView: View {
    let mockup: UsageMockup
    var body: some View {
        ZStack {
            AnimationPreviewRegistry.view(for: mockup.animationId)
            VStack(spacing: 0) {
                MockStatusBar()
                    .padding(.horizontal, 20).padding(.top, 14)
                Text("MORNING FLOW · POSE 4 OF 12")
                    .font(.system(size: 10, weight: .heavy)).tracking(2).opacity(0.6)
                    .padding(.top, 14)
                Spacer().frame(height: 14)
                Text("🧘‍♀️").font(.system(size: 78))
                Text("Warrior II")
                    .font(.system(size: 24, design: .serif))
                    .padding(.top, 6)
                Text("Front knee bent. Arms parallel. Gaze\nover your front fingertips.")
                    .font(.system(size: 12)).italic()
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.top, 6)
                Spacer().frame(height: 18)
                circularTimer
                Spacer()
                yogaControls.padding(.bottom, 10)
                MockHomeIndicator()
            }
            .foregroundStyle(.white)
        }
    }

    private var circularTimer: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.1), lineWidth: 3)
                .frame(width: 150, height: 150)
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color.white, style: .init(lineWidth: 3, lineCap: .round))
                .frame(width: 150, height: 150)
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("0:38")
                    .font(.system(size: 36, weight: .light, design: .monospaced))
                Text("hold").font(.system(size: 11)).opacity(0.5)
            }
        }
    }

    private var yogaControls: some View {
        HStack(spacing: 16) {
            controlCircle("backward.fill", size: 48)
            controlCircle("pause.fill", size: 58)
            controlCircle("forward.fill", size: 48)
        }
    }

    private func controlCircle(_ system: String, size: CGFloat) -> some View {
        Circle().fill(.ultraThinMaterial)
            .frame(width: size, height: size)
            .overlay(Image(systemName: system).font(.system(size: size * 0.32, weight: .bold)))
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 21. MockCoinDetailView — au-blackhole · BTC chart
// MARK: ─────────────────────────────────────────────────────────────

private struct MockCoinDetailView: View {
    let mockup: UsageMockup
    var body: some View {
        ZStack {
            Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0C / 255)
            AnimationPreviewRegistry.view(for: mockup.animationId)
            VStack(spacing: 0) {
                MockStatusBar()
                    .padding(.horizontal, 20).padding(.top, 14)
                header.padding(.horizontal, 18).padding(.top, 10)
                Spacer().frame(height: 18)
                price
                Spacer().frame(height: 16)
                chart.padding(.horizontal, 6)
                rangePicker.padding(.horizontal, 22).padding(.top, 8)
                Spacer()
                buySellRow.padding(.horizontal, 16).padding(.bottom, 10)
                MockHomeIndicator()
            }
            .foregroundStyle(.white)
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "chevron.left")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(.ultraThinMaterial, in: Circle())
            Spacer()
            VStack(spacing: 1) {
                Text("BTC · Bitcoin").font(.system(size: 13, weight: .heavy))
                Text("● Live · NYSE")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(red: 0.2, green: 0.78, blue: 0.35))
            }
            Spacer()
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(.ultraThinMaterial, in: Circle())
        }
    }

    private var price: some View {
        VStack(spacing: 4) {
            Text("1 BTC =").font(.system(size: 11, weight: .semibold)).opacity(0.55)
            Text("$67,420.18")
                .font(.system(size: 36, weight: .heavy, design: .monospaced))
            Text("↑ $1,820 · +2.8% today")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Color(red: 0.2, green: 0.78, blue: 0.35))
        }
    }

    private var chart: some View {
        GeometryReader { g in
            ZStack {
                let area = Path { p in
                    p.move(to: CGPoint(x: 0, y: g.size.height * 0.7))
                    p.addCurve(to: CGPoint(x: g.size.width, y: g.size.height * 0.1),
                               control1: CGPoint(x: g.size.width * 0.4, y: g.size.height * 0.5),
                               control2: CGPoint(x: g.size.width * 0.7, y: g.size.height * 0.2))
                    p.addLine(to: CGPoint(x: g.size.width, y: g.size.height))
                    p.addLine(to: CGPoint(x: 0, y: g.size.height))
                    p.closeSubpath()
                }
                area.fill(LinearGradient(
                    colors: [Color(red: 0.2, green: 0.78, blue: 0.35).opacity(0.4), .clear],
                    startPoint: .top, endPoint: .bottom))
                let line = Path { p in
                    p.move(to: CGPoint(x: 0, y: g.size.height * 0.7))
                    p.addCurve(to: CGPoint(x: g.size.width, y: g.size.height * 0.1),
                               control1: CGPoint(x: g.size.width * 0.4, y: g.size.height * 0.5),
                               control2: CGPoint(x: g.size.width * 0.7, y: g.size.height * 0.2))
                }
                line.stroke(Color(red: 0.2, green: 0.78, blue: 0.35), lineWidth: 2)
                Circle()
                    .fill(Color(red: 0.2, green: 0.78, blue: 0.35))
                    .frame(width: 8, height: 8)
                    .position(x: g.size.width - 4, y: g.size.height * 0.1)
            }
        }
        .frame(height: 130)
    }

    private var rangePicker: some View {
        HStack {
            ForEach(Array(["1H", "1D", "1W", "1M", "1Y", "All"].enumerated()), id: \.offset) { idx, p in
                Text(p)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(idx == 2 ? .white : .white.opacity(0.5))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(
                        idx == 2 ? Color.white.opacity(0.12) : .clear,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                Spacer()
            }
        }
    }

    private var buySellRow: some View {
        HStack(spacing: 10) {
            Text("Sell")
                .font(.system(size: 14, weight: .heavy))
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(.ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text("Buy")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Color(red: 0.2, green: 0.78, blue: 0.35),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 22. MockSubUnlockedView — au-goldfoil · Premium activated
// MARK: ─────────────────────────────────────────────────────────────

private struct MockSubUnlockedView: View {
    let mockup: UsageMockup
    var body: some View {
        ZStack {
            AnimationPreviewRegistry.view(for: mockup.animationId)
            VStack(spacing: 0) {
                MockStatusBar()
                    .padding(.horizontal, 20).padding(.top, 14)
                Spacer().frame(height: 24)
                HStack(spacing: 6) {
                    Text("⭐").font(.system(size: 12))
                    Text("PREMIUM ACTIVATED")
                        .font(.system(size: 10, weight: .heavy)).tracking(1.5)
                }
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                Text("You're\ngolden.")
                    .font(.system(size: 38, weight: .black))
                    .multilineTextAlignment(.center)
                    .lineSpacing(-2)
                    .padding(.top, 18)
                Text("Welcome to Wavelength Pro. Every\nfeature, no limits, forever yours.")
                    .font(.system(size: 14))
                    .opacity(0.85)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 24).padding(.top, 14)
                Spacer().frame(height: 18)
                unlockedList.padding(.horizontal, 22)
                Spacer()
                primaryCTA("Start using Pro", fg: .black, bg: .white)
                    .padding(.horizontal, 22).padding(.bottom, 10)
                MockHomeIndicator()
            }
            .foregroundStyle(.white)
        }
    }

    private var unlockedList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("WHAT'S UNLOCKED")
                .font(.system(size: 11, weight: .heavy)).tracking(1).opacity(0.6)
                .padding(.bottom, 4)
            ForEach(["Unlimited transcriptions", "Multi-track sessions", "Pro export formats"], id: \.self) { f in
                HStack(spacing: 10) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Color(red: 0xFC / 255, green: 0xD3 / 255, blue: 0x4D / 255))
                    Text(f).font(.system(size: 13, weight: .semibold))
                }
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 23. MockWorkoutSummaryView — au-firewall · Run summary
// MARK: ─────────────────────────────────────────────────────────────

private struct MockWorkoutSummaryView: View {
    let mockup: UsageMockup
    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0C / 255)
            AnimationPreviewRegistry.view(for: mockup.animationId)
            LinearGradient(colors: [.black.opacity(0.2), .clear, .black.opacity(0.5)],
                           startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 0) {
                MockStatusBar()
                    .padding(.horizontal, 20).padding(.top, 14)
                VStack(alignment: .leading, spacing: 4) {
                    Text("RUN · 42 MIN AGO")
                        .font(.system(size: 10, weight: .heavy)).tracking(2).opacity(0.6)
                    Text("Burned bright today.")
                        .font(.system(size: 26, weight: .heavy))
                }
                .padding(.horizontal, 20).padding(.top, 10)
                statsGrid.padding(.horizontal, 22).padding(.top, 16)
                hrCard.padding(.horizontal, 16).padding(.top, 14)
                prBadge.padding(.horizontal, 16).padding(.top, 12)
                Spacer()
                MockHomeIndicator()
            }
            .foregroundStyle(.white)
        }
    }

    private var statsGrid: some View {
        let stats: [(String, String, String)] = [
            ("DISTANCE", "8.42", "km"),
            ("PACE", "5:12", "/km"),
            ("CALORIES", "624", "kcal"),
            ("TIME", "43:42", "")
        ]
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                   GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(stats, id: \.0) { s in
                VStack(alignment: .leading, spacing: 4) {
                    Text(s.0).font(.system(size: 10, weight: .heavy)).tracking(1.2).opacity(0.6)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(s.1).font(.system(size: 22, weight: .heavy, design: .monospaced))
                        Text(s.2).font(.system(size: 11, weight: .semibold)).opacity(0.55)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(.ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var hrCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("HEART RATE")
                    .font(.system(size: 10, weight: .heavy)).tracking(1).opacity(0.6)
                Spacer()
                Text("avg 148 · max 172")
                    .font(Theme.Typo.mono(11, weight: .heavy))
            }
            HStack(alignment: .bottom, spacing: 2) {
                ForEach([40, 55, 70, 82, 90, 85, 78, 88, 95, 88, 72, 60, 55, 70, 80, 92, 100, 95, 88, 75, 60, 50, 45, 38], id: \.self) { h in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(LinearGradient(
                            colors: [Theme.Palette.accent,
                                     Color(red: 0xFA / 255, green: 0xCC / 255, blue: 0x15 / 255)],
                            startPoint: .top, endPoint: .bottom))
                        .frame(maxWidth: .infinity)
                        .frame(height: CGFloat(h) * 0.38)
                }
            }
            .frame(height: 38)
        }
        .padding(14)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var prBadge: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(
                    LinearGradient(colors: [hexColor(0xFACC15), hexColor(0xF97316)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
                Text("🏅").font(.system(size: 18))
            }
            .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text("New personal record").font(.system(size: 13, weight: .heavy))
                Text("Fastest 5K split this month")
                    .font(.system(size: 11)).opacity(0.6)
            }
            Spacer()
        }
        .padding(14)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 24. MockTicketView — au-stardust · Concert ticket
// MARK: ─────────────────────────────────────────────────────────────

private struct MockTicketView: View {
    let mockup: UsageMockup
    var body: some View {
        ZStack {
            Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0C / 255)
            AnimationPreviewRegistry.view(for: mockup.animationId)
            VStack(spacing: 0) {
                MockStatusBar()
                    .padding(.horizontal, 20).padding(.top, 14)
                Text("YOUR TICKET")
                    .font(.system(size: 11, weight: .heavy)).tracking(2).opacity(0.65)
                    .padding(.top, 14)
                Spacer().frame(height: 18)
                ticketCard.padding(.horizontal, 16)
                Spacer()
                MockHomeIndicator()
            }
            .foregroundStyle(.white)
        }
    }

    private var ticketCard: some View {
        VStack(spacing: 0) {
            // Top
            VStack(alignment: .leading, spacing: 4) {
                Text("Saturday, Apr 12 · 9:00 PM")
                    .font(.system(size: 12)).opacity(0.6)
                Text("Late Bloom\nLive in Jakarta")
                    .font(.system(size: 26, weight: .heavy, design: .serif))
                    .italic()
                    .lineSpacing(-2)
                Text("Eira Volkov · Tour 2025")
                    .font(.system(size: 12)).opacity(0.6).padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.black.opacity(0.6))
            .overlay(
                Rectangle().fill(Color.white.opacity(0.18))
                    .frame(height: 0.5),
                alignment: .bottom
            )
            // Perforation
            HStack(spacing: 0) {
                Circle().fill(Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0C / 255))
                    .frame(width: 16, height: 16)
                    .offset(x: -8)
                ZStack {
                    Rectangle().fill(Color.black.opacity(0.6))
                    HStack(spacing: 4) {
                        ForEach(0..<24, id: \.self) { _ in
                            Capsule().fill(Color.white.opacity(0.3))
                                .frame(width: 6, height: 1)
                        }
                    }
                }
                .frame(height: 16)
                Circle().fill(Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0C / 255))
                    .frame(width: 16, height: 16)
                    .offset(x: 8)
            }
            // Bottom
            VStack(spacing: 14) {
                HStack {
                    seatCol("SECTION", "VIP-A")
                    Spacer()
                    seatCol("ROW", "03")
                    Spacer()
                    seatCol("SEAT", "12")
                }
                HStack(spacing: 12) {
                    qrPatch
                    VStack(alignment: .leading, spacing: 3) {
                        Text("SHOW ENTRY")
                            .font(.system(size: 9, weight: .heavy)).tracking(1.5).opacity(0.5)
                        Text("LB·24·A03·12")
                            .font(Theme.Typo.mono(12, weight: .heavy))
                        Text("Tap to use Wallet")
                            .font(.system(size: 9)).opacity(0.55)
                    }
                    .foregroundStyle(.black)
                    Spacer()
                }
                .padding(12)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(16)
            .background(Color.black.opacity(0.6))
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
        )
        .foregroundStyle(.white)
    }

    private func seatCol(_ l: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(l).font(.system(size: 9, weight: .heavy)).tracking(1.5).opacity(0.55)
            Text(v).font(.system(size: 20, weight: .heavy, design: .monospaced))
        }
    }

    private var qrPatch: some View {
        Rectangle()
            .fill(Color.white)
            .frame(width: 60, height: 60)
            .overlay(
                ZStack {
                    Path { p in
                        for x in stride(from: 0, to: 60, by: 4) {
                            p.move(to: CGPoint(x: x, y: 0))
                            p.addLine(to: CGPoint(x: x, y: 60))
                        }
                        for y in stride(from: 0, to: 60, by: 4) {
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: 60, y: y))
                        }
                    }
                    .stroke(Color.black, lineWidth: 1)
                }
            )
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 25. MockYearReviewView — au-supernova · 1,842 km
// MARK: ─────────────────────────────────────────────────────────────

private struct MockYearReviewView: View {
    let mockup: UsageMockup
    var body: some View {
        ZStack {
            AnimationPreviewRegistry.view(for: mockup.animationId)
            VStack(spacing: 0) {
                MockStatusBar()
                    .padding(.horizontal, 20).padding(.top, 14)
                Text("2025 · WRAPPED")
                    .font(.system(size: 10, weight: .heavy)).tracking(1.8)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 14)
                Spacer().frame(height: 18)
                VStack(spacing: 0) {
                    Text("You ran")
                        .font(.system(size: 28, weight: .black))
                    Text("1,842")
                        .font(.system(size: 76, weight: .black))
                        .foregroundStyle(Color(red: 0xFC / 255, green: 0xD3 / 255, blue: 0x4D / 255))
                    Text("kilometers.")
                        .font(.system(size: 28, weight: .black))
                }
                Text("That's like crossing\nfrom Jakarta to Bali · 7 times.")
                    .font(.system(size: 12)).opacity(0.75)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                Spacer()
                statTiles.padding(.horizontal, 16)
                Spacer().frame(height: 12)
                primaryCTA("Share your year", fg: .black, bg: .white)
                    .padding(.horizontal, 22).padding(.bottom, 10)
                MockHomeIndicator()
            }
            .foregroundStyle(.white)
        }
    }

    private var statTiles: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach([("Workouts", "247"), ("Total time", "184h"),
                     ("PRs broken", "12"), ("Streak record", "38d")], id: \.0) { s in
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.0.uppercased())
                        .font(.system(size: 9, weight: .heavy)).tracking(1).opacity(0.55)
                    Text(s.1)
                        .font(.system(size: 22, weight: .heavy, design: .monospaced))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 26. MockEmptyInboxView — au-calmdrift · Inbox zero
// MARK: ─────────────────────────────────────────────────────────────

private struct MockEmptyInboxView: View {
    let mockup: UsageMockup
    var body: some View {
        ZStack {
            AnimationPreviewRegistry.view(for: mockup.animationId)
            VStack(spacing: 0) {
                MockStatusBar()
                    .padding(.horizontal, 20).padding(.top, 14)
                HStack {
                    Text("Inbox").font(.system(size: 26, weight: .heavy))
                    Spacer()
                    Text("0 unread")
                        .font(.system(size: 12, weight: .heavy))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.ultraThinMaterial,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 20).padding(.top, 8)
                Spacer()
                Text("🍃").font(.system(size: 78))
                Text("You're all caught up.")
                    .font(.system(size: 23, weight: .semibold, design: .serif))
                    .padding(.top, 12)
                Text("Nothing in your inbox. Maybe take a moment, look up, breathe.")
                    .font(.system(size: 13)).opacity(0.65)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 36).padding(.top, 8)
                Spacer()
                secondaryCTA("Compose new")
                    .padding(.horizontal, 22).padding(.bottom, 10)
                MockHomeIndicator()
            }
            .foregroundStyle(.white)
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 27. MockRecipeView — au-honeydrip · Honey-Glazed toast
// MARK: ─────────────────────────────────────────────────────────────

private struct MockRecipeView: View {
    let mockup: UsageMockup
    private let cream = Color(red: 0xFE / 255, green: 0xF3 / 255, blue: 0xC7 / 255)
    private let ink = Color(red: 0x3A / 255, green: 0x24 / 255, blue: 0x10 / 255)

    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0C / 255)
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    AnimationPreviewRegistry.view(for: mockup.animationId)
                        .frame(height: 230).clipped()
                    VStack(spacing: 0) {
                        MockStatusBar()
                            .padding(.horizontal, 20).padding(.top, 14)
                        HStack {
                            navCircle(system: "chevron.left")
                            Spacer()
                            navCircle(system: "heart")
                        }
                        .padding(.horizontal, 14).padding(.top, 4)
                        Spacer()
                    }
                }
                .frame(height: 230)
                lowerPanel
            }
        }
    }

    private func navCircle(system: String) -> some View {
        Image(systemName: system)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(.ultraThinMaterial, in: Circle())
    }

    private var lowerPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("BREAKFAST · 12 MIN")
                Text("·")
                Text("★ 4.8")
            }
            .font(.system(size: 10, weight: .semibold)).tracking(1.5).opacity(0.55)
            Text("Honey-Glazed Cinnamon Toast")
                .font(.system(size: 22, weight: .heavy, design: .serif))
            HStack(spacing: 6) {
                ForEach(["Sweet", "Quick", "4 ingredients"], id: \.self) { t in
                    Text(t).font(.system(size: 11, weight: .heavy))
                        .padding(.horizontal, 9).padding(.vertical, 3)
                        .background(ink.opacity(0.1), in: Capsule())
                }
            }
            .padding(.top, 4)
            VStack(alignment: .leading, spacing: 4) {
                Text("Ingredients").font(.system(size: 13, weight: .heavy))
                    .padding(.bottom, 4)
                ForEach(Array(["4 thick brioche slices", "3 tbsp honey, warmed",
                               "1 tsp cinnamon", "2 tbsp salted butter"].enumerated()), id: \.offset) { idx, name in
                    HStack(spacing: 10) {
                        let isChecked = idx < 2
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isChecked ? ink : .clear)
                                .frame(width: 16, height: 16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(ink, lineWidth: 1.5)
                                )
                            if isChecked {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .heavy))
                                    .foregroundStyle(cream)
                            }
                        }
                        Text(name)
                            .font(.system(size: 13))
                            .strikethrough(isChecked)
                            .opacity(isChecked ? 0.5 : 1)
                    }
                }
            }
            .padding(.top, 10)
            Spacer()
            Text("Start cooking · 4 steps")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(cream)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(ink, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            MockHomeIndicator(tint: ink)
        }
        .padding(.horizontal, 20).padding(.top, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(ink)
        .background(cream)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.top, -24)
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 28. MockTravelView — au-tropics · Bali
// MARK: ─────────────────────────────────────────────────────────────

private struct MockTravelView: View {
    let mockup: UsageMockup
    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0C / 255)
            VStack(spacing: 0) {
                ZStack {
                    AnimationPreviewRegistry.view(for: mockup.animationId)
                        .frame(height: 360).clipped()
                    VStack(spacing: 0) {
                        MockStatusBar()
                            .padding(.horizontal, 20).padding(.top, 14)
                        HStack {
                            navCircle("chevron.left")
                            Spacer()
                            navCircle("square.and.arrow.up")
                        }
                        .padding(.horizontal, 14).padding(.top, 4)
                        Spacer()
                        VStack(spacing: 8) {
                            Text("DISCOVER · INDONESIA")
                                .font(.system(size: 11, weight: .heavy)).tracking(2).opacity(0.85)
                            Text("Bali")
                                .font(.system(size: 42, weight: .heavy, design: .serif))
                                .italic()
                            HStack(spacing: 12) {
                                Text("☀️ 31°C")
                                Text("·")
                                Text("🏝 86 places")
                                Text("·")
                                Text("$$")
                            }
                            .font(.system(size: 12)).opacity(0.85)
                        }
                        Spacer().frame(height: 26)
                    }
                }
                .frame(height: 360)
                topPicks
            }
            .foregroundStyle(.white)
        }
    }

    private func navCircle(_ system: String) -> some View {
        Image(systemName: system)
            .font(.system(size: 12, weight: .semibold))
            .frame(width: 30, height: 30)
            .background(.ultraThinMaterial, in: Circle())
    }

    private var topPicks: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TOP PICKS")
                .font(.system(size: 11, weight: .heavy)).tracking(1).opacity(0.85)
                .padding(.top, 4)
            ForEach(Array([
                ("Tegallalang Rice Terraces", "Ubud · Nature", "4.9"),
                ("Uluwatu Sunset", "Bukit · Beach", "4.8"),
                ("Tirta Empul", "Tampaksiring · Temple", "4.7")
            ].enumerated()), id: \.offset) { idx, p in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(
                            colors: [Color(hue: Double(idx) * 0.16 + 0.16, saturation: 0.6, brightness: 0.55),
                                     Color(hue: Double(idx) * 0.16 + 0.28, saturation: 0.5, brightness: 0.4)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 46, height: 46)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(p.0).font(.system(size: 13, weight: .heavy))
                        Text(p.1).font(.system(size: 11)).opacity(0.55)
                    }
                    Spacer()
                    Text("★ \(p.2)").font(Theme.Typo.mono(12, weight: .heavy))
                }
                .padding(.vertical, 6)
                if idx < 2 {
                    Divider().background(Color.white.opacity(0.08))
                }
            }
            Spacer()
            MockHomeIndicator()
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0C / 255)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.top, -24)
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 29. MockLoyaltyView — au-goldfoil · Bronze → Gold
// MARK: ─────────────────────────────────────────────────────────────

private struct MockLoyaltyView: View {
    let mockup: UsageMockup
    var body: some View {
        ZStack {
            AnimationPreviewRegistry.view(for: mockup.animationId)
            VStack(spacing: 0) {
                MockStatusBar()
                    .padding(.horizontal, 20).padding(.top, 14)
                Text("TIER UPGRADE")
                    .font(.system(size: 10, weight: .heavy)).tracking(2).opacity(0.65)
                    .padding(.top, 14)
                Spacer().frame(height: 16)
                tierRow
                Spacer().frame(height: 22)
                VStack(spacing: 8) {
                    Text("Welcome to Gold")
                        .font(.system(size: 26, weight: .heavy))
                    Text("You've spent enough nights with us to earn your stripes. Here's what changes.")
                        .font(.system(size: 12)).opacity(0.75)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.horizontal, 28)
                }
                Spacer().frame(height: 16)
                benefits.padding(.horizontal, 16)
                Spacer()
                primaryCTA("See all benefits", fg: .black, bg: .white)
                    .padding(.horizontal, 22).padding(.bottom, 10)
                MockHomeIndicator()
            }
            .foregroundStyle(.white)
        }
    }

    private var tierRow: some View {
        HStack(spacing: 16) {
            tierCard(emoji: "🥉", label: "BRONZE",
                     gradient: [hexColor(0x92400E), hexColor(0xB45309)],
                     w: 72, h: 92, opacity: 0.4)
            Image(systemName: "arrow.right")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(Color(red: 0xFC / 255, green: 0xD3 / 255, blue: 0x4D / 255))
            tierCard(emoji: "🥇", label: "GOLD",
                     gradient: [hexColor(0xFCD34D), hexColor(0xF59E0B), hexColor(0xD97706)],
                     w: 92, h: 118, opacity: 1)
                .shadow(color: hexColor(0xFCD34D).opacity(0.4), radius: 18, y: 8)
        }
    }

    private func tierCard(emoji: String, label: String, gradient: [Color],
                          w: CGFloat, h: CGFloat, opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: w, height: h)
            .overlay(
                VStack(spacing: 4) {
                    Text(emoji).font(.system(size: h * 0.32))
                    Text(label)
                        .font(.system(size: 10, weight: .heavy)).tracking(1.5)
                        .foregroundStyle(label == "GOLD" ? .black : .white)
                }
            )
            .opacity(opacity)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(["Free room upgrades · year-round",
                     "4 PM late checkout",
                     "15% off all restaurants"], id: \.self) { b in
                HStack(spacing: 10) {
                    Text("✦").foregroundStyle(Color(red: 0xFC / 255, green: 0xD3 / 255, blue: 0x4D / 255))
                    Text(b).font(.system(size: 13))
                }
                .padding(.vertical, 3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 30. MockAchievementView — au-coreburst · Streak Master
// MARK: ─────────────────────────────────────────────────────────────

private struct MockAchievementView: View {
    let mockup: UsageMockup
    var body: some View {
        ZStack {
            AnimationPreviewRegistry.view(for: mockup.animationId)
            VStack(spacing: 0) {
                MockStatusBar()
                    .padding(.horizontal, 20).padding(.top, 14)
                Text("ACHIEVEMENT UNLOCKED")
                    .font(.system(size: 10, weight: .heavy)).tracking(1.5)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 14)
                Spacer().frame(height: 18)
                trophy
                Text("Streak Master")
                    .font(.system(size: 24, weight: .heavy, design: .serif))
                    .padding(.top, 18)
                Text("Practiced 30 days in a row. Top 4% of all users this month.")
                    .font(.system(size: 12)).opacity(0.75)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36).padding(.top, 4)
                Spacer().frame(height: 18)
                rewardCard.padding(.horizontal, 16)
                Spacer()
                HStack(spacing: 10) {
                    secondaryCTA("Share")
                    primaryCTA("Continue", fg: .black, bg: .white)
                }
                .padding(.horizontal, 22).padding(.bottom, 10)
                MockHomeIndicator()
            }
            .foregroundStyle(.white)
        }
    }

    private var trophy: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.white.opacity(0.3),
                              style: .init(lineWidth: 2, dash: [4]))
                .frame(width: 140, height: 140)
            Circle()
                .fill(LinearGradient(
                    colors: [hexColor(0xFFE08A), hexColor(0xFF8E3C), hexColor(0xFF3D71)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 116, height: 116)
                .shadow(color: hexColor(0xFF8E3C).opacity(0.6), radius: 30)
            Text("🏆").font(.system(size: 56))
        }
    }

    private var rewardCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("REWARD").font(.system(size: 9, weight: .heavy)).tracking(1).opacity(0.55)
                Text("+ 500 XP").font(.system(size: 14, weight: .heavy))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("NEXT TIER").font(.system(size: 9, weight: .heavy)).tracking(1).opacity(0.55)
                Text("1,247 XP").font(.system(size: 14, weight: .heavy))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: Fallback — used for ids without a bespoke layout
// MARK: ─────────────────────────────────────────────────────────────

private struct MockGenericFallbackView: View {
    let mockup: UsageMockup
    var body: some View {
        ZStack {
            Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0C / 255)
            AnimationPreviewRegistry.view(for: mockup.animationId)
            LinearGradient(colors: [.clear, .black.opacity(0.5)],
                           startPoint: .top, endPoint: .bottom)
            VStack(spacing: 0) {
                MockStatusBar()
                    .padding(.horizontal, 20).padding(.top, 14)
                Spacer()
                VStack(spacing: 8) {
                    Text(mockup.appName.uppercased())
                        .font(.system(size: 12, weight: .heavy)).tracking(2).opacity(0.65)
                    Text(mockup.title)
                        .font(.system(size: 26, weight: .heavy))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                Spacer()
                primaryCTA("Open", fg: .black, bg: .white)
                    .padding(.horizontal, 22).padding(.bottom, 10)
                MockHomeIndicator()
            }
            .foregroundStyle(.white)
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: Reusable CTA helpers + color util (file-private, free functions)
// MARK: ─────────────────────────────────────────────────────────────

@ViewBuilder
private func primaryCTA(_ text: String, fg: Color, bg: Color) -> some View {
    Text(text)
        .font(.system(size: 14, weight: .heavy))
        .foregroundStyle(fg)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
}

@ViewBuilder
private func secondaryCTA(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 14, weight: .heavy))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
}

private func hexColor(_ hex: UInt32) -> Color {
    let r = Double((hex >> 16) & 0xFF) / 255
    let g = Double((hex >> 8) & 0xFF) / 255
    let b = Double(hex & 0xFF) / 255
    return Color(red: r, green: g, blue: b)
}

