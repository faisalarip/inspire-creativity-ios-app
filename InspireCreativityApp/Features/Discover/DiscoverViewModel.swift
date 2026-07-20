//
//  DiscoverViewModel.swift
//  InspireCreativityApp
//
//  v2.0 engagement layer: daily pick, streak, drop countdown, weekly
//  challenge, free-this-week rotation, trending.
//

import Combine
import Foundation

@MainActor
final class DiscoverViewModel: ObservableObject {

    @Published private(set) var dailyPick: AnimationItem?
    @Published private(set) var dailyResetLabel = ""
    @Published private(set) var dropCountdownLabel = ""
    @Published private(set) var challengeDaysLeft = ""
    @Published private(set) var challengeJoined = false
    @Published private(set) var freeThisWeek: [AnimationItem] = []
    @Published private(set) var dropPicks: [AnimationItem] = []
    @Published private(set) var trending: [AnimationItem] = []
    @Published private(set) var streak = 0
    @Published private(set) var unreadCount = 0
    @Published private(set) var isPro: Bool
    /// Flips after a successful daily-pick copy (drives the button's ✓ state).
    @Published private(set) var dailyCopied = false

    private let repository: AnimationRepositoryProtocol
    private let purchases: PurchaseRepositoryProtocol
    private let streakTracker: StreakTracker
    private let activity: ActivityRepositoryProtocol
    private let copyActivity: CopyActivityStore
    private let analytics: AnalyticsTracking
    /// First-run category picks; nil or empty → global curation.
    private let onboarding: OnboardingPreferences?
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let now: () -> Date
    private var cancellables: Set<AnyCancellable> = []

    /// "Friday, July 17" — the header's date line.
    var dateLabel: String {
        now().formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    init(
        repository: AnimationRepositoryProtocol,
        purchases: PurchaseRepositoryProtocol,
        streakTracker: StreakTracker,
        activity: ActivityRepositoryProtocol,
        copyActivity: CopyActivityStore,
        analytics: AnalyticsTracking = NoOpAnalyticsTracker(),
        onboarding: OnboardingPreferences? = nil,
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.purchases = purchases
        self.streakTracker = streakTracker
        self.activity = activity
        self.copyActivity = copyActivity
        self.analytics = analytics
        self.onboarding = onboarding
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
        self.isPro = purchases.isPro

        refreshDerived()

        purchases.isProPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$isPro)

        activity.itemsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.unreadCount = self?.activity.unreadCount ?? 0 }
            .store(in: &cancellables)

        streakTracker.didChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.streak = self?.streakTracker.current ?? 0 }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .animationsUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshDerived() }
            .store(in: &cancellables)

        onboarding?.didChange
            .sink { [weak self] in self?.refreshDerived() }
            .store(in: &cancellables)
    }

    /// Recomputes every date-derived section. Called at init, on catalog
    /// updates, and from the view's onAppear so countdowns stay fresh.
    func refreshDerived() {
        let date = now()
        let all = repository.all()
        dailyPick = EngagementSchedule.dailyPick(from: all, on: date, calendar: calendar)
        dailyResetLabel = EngagementSchedule.dailyResetLabel(from: date, calendar: calendar)
        let drop = EngagementSchedule.nextDrop(after: date, calendar: calendar)
        dropCountdownLabel = "\(EngagementSchedule.countdownLabel(to: drop, from: date)) · 5 new animations"
        challengeDaysLeft = EngagementSchedule.challengeDaysLeftLabel(from: date, calendar: calendar)
        challengeJoined = defaults.bool(forKey: challengeKey)
        freeThisWeek = EngagementSchedule.freeThisWeek(from: all, on: date, calendar: calendar)
        dropPicks = EngagementSchedule.dropPicks(from: all, on: date, calendar: calendar)
        // Personalized trending: bias toward the categories picked at
        // onboarding; fall back to the global curated row.
        let picks = onboarding?.categories ?? []
        if picks.isEmpty {
            trending = repository.trending()
        } else {
            trending = Array(
                all.filter { picks.contains($0.category) }
                    .sorted { $0.downloads > $1.downloads }
                    .prefix(8)
            )
        }
        streak = streakTracker.current
        unreadCount = activity.unreadCount
    }

    // MARK: - Weekly challenge

    /// Joined-state is per challenge week, so it resets on Monday.
    private var challengeKey: String {
        let date = now()
        let seed = calendar.component(.yearForWeekOfYear, from: date) * 100
            + calendar.component(.weekOfYear, from: date)
        return "engagement.challenge.joined.\(seed)"
    }

    func joinChallenge() {
        defaults.set(true, forKey: challengeKey)
        challengeJoined = true
    }

    // MARK: - Daily pick copy

    enum DailyCopyOutcome: Equatable { case copied, needsDetail }

    /// Copies today's code when access is already granted; otherwise the view
    /// routes to Detail where the sign-in / paywall gate lives.
    func copyDailyPick() -> DailyCopyOutcome {
        guard let pick = dailyPick,
              CodeAccess.evaluate(
                  itemIsPro: pick.isPro,
                  hasProEntitlement: purchases.isPro
              ) == .granted else { return .needsDetail }

        var source = pick.swiftCode
        if source.isEmpty,
           let descriptor = AuroraDescriptors.byId[pick.id]
               ?? AnimationPreviewRegistry.runtimeDescriptors[pick.id] {
            source = AuroraCodeGen.swiftCode(for: descriptor)
        }
        guard !source.isEmpty else { return .needsDetail }

        Clipboard.copy(source)
        copyActivity.recordCopy(on: now())
        analytics.log(.codeCopied(id: pick.id))
        dailyCopied = true
        return .copied
    }

    /// Pull-to-refresh: re-fetches the remote catalog. On success the
    /// repository posts `.animationsUpdated`, which refreshes the rows above.
    func reload() async {
        await repository.refresh()
    }
}
