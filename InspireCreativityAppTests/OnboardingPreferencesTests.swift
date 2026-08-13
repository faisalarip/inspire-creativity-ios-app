//
//  OnboardingPreferencesTests.swift
//  InspireCreativityAppTests
//

import XCTest
@testable import InspireCreativityApp

final class OnboardingPreferencesTests: XCTestCase {

    func testFreshInstallIsNotCompleted() {
        let prefs = OnboardingPreferences(defaults: Fixtures.freshDefaults("onboarding"))
        XCTAssertFalse(prefs.isCompleted)
        XCTAssertTrue(prefs.categories.isEmpty)
    }

    func testCompleteRoundTripsCategories() {
        let defaults = Fixtures.freshDefaults("onboarding")
        OnboardingPreferences(defaults: defaults).complete(categories: [.loaders, .buttons])
        let reloaded = OnboardingPreferences(defaults: defaults)
        XCTAssertTrue(reloaded.isCompleted)
        XCTAssertEqual(reloaded.categories, [.loaders, .buttons])
    }

    func testSkipIsCompletedWithNoPreference() {
        let prefs = OnboardingPreferences(defaults: Fixtures.freshDefaults("onboarding"))
        prefs.complete(categories: [])
        XCTAssertTrue(prefs.isCompleted)
        XCTAssertTrue(prefs.categories.isEmpty)
    }

    @MainActor
    func testDiscoverTrendingPersonalizesToPicks() {
        let suite = Fixtures.freshDefaults("onboarding")
        let prefs = OnboardingPreferences(defaults: suite)
        prefs.complete(categories: [.loaders])

        let vm = DiscoverViewModel(
            repository: InMemoryAnimationRepository(),
            purchases: FakeProPurchases(),
            streakTracker: StreakTracker(defaults: suite, calendar: Fixtures.utcCalendar),
            activity: ActivityRepository(defaults: suite, calendar: Fixtures.utcCalendar),
            copyActivity: CopyActivityStore(defaults: suite, calendar: Fixtures.utcCalendar),
            onboarding: prefs,
            defaults: suite,
            calendar: Fixtures.utcCalendar,
            now: { Fixtures.date(2026, 7, 15, 12) }
        )
        XCTAssertFalse(vm.trending.isEmpty)
        XCTAssertTrue(vm.trending.allSatisfy { $0.category == .loaders },
                      "trending must bias to onboarding picks")
    }
}

import Combine
final class FakeProPurchases: PurchaseRepositoryProtocol {
    var isPro = false
    var isProPublisher: AnyPublisher<Bool, Never> { Just(isPro).eraseToAnyPublisher() }
    func isOwned(_ id: String, freeOverride: Bool) -> Bool { freeOverride || isPro }
}
