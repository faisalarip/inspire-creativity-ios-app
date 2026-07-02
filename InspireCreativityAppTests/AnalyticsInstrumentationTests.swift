import XCTest
@testable import InspireCreativityApp

@MainActor
final class AnalyticsInstrumentationTests: XCTestCase {

    func testDetailLogsAnimationViewOnOpen() {
        let spy = SpyAnalyticsTracker()
        let vm = DetailViewModel(animationId: AnimationCatalogSeed.items[0].id,
                                 repository: InMemoryAnimationRepository(),
                                 favorites: FavoritesRepository(),
                                 purchases: StoreManager(),
                                 analytics: spy)
        _ = vm
        XCTAssertTrue(spy.events.contains { if case .animationView = $0 { return true } else { return false } },
                      "opening Detail must log animation_view")
    }

    func testToggleFavoriteLogsEvent() {
        let spy = SpyAnalyticsTracker()
        let item = AnimationCatalogSeed.items[0]
        // Start from a clean store so the item is NOT favorited initially.
        let favorites = FavoritesRepository(defaults: Self.ephemeralDefaults())
        XCTAssertFalse(favorites.isFavorite(item.id), "precondition: item starts unfavorited")
        let vm = DetailViewModel(animationId: item.id,
                                 repository: InMemoryAnimationRepository(),
                                 favorites: favorites,
                                 purchases: StoreManager(),
                                 analytics: spy)

        // First toggle: unfavorited -> favorited, so the event must record on: true.
        vm.toggleFavorite()
        XCTAssertEqual(spy.events.last, .favoriteToggled(id: item.id, on: true),
                       "toggling an unfavorited item must log favorite_toggled with the resulting state on: true")

        // Second toggle: favorited -> unfavorited, so the event must record on: false.
        vm.toggleFavorite()
        XCTAssertEqual(spy.events.last, .favoriteToggled(id: item.id, on: false),
                       "toggling a favorited item must log favorite_toggled with the resulting state on: false")
    }

    func testPushDetailTracksDetailScreen() {
        let spy = SpyAnalyticsTracker()
        let router = AppRouter()
        router.analytics = spy
        router.push(.detail(animationId: "x"))
        XCTAssertEqual(spy.screens, [.detail],
                       "pushing .detail must track the detail screen")
    }

    func testPushPaywallTracksPaywallScreen() {
        let spy = SpyAnalyticsTracker()
        let router = AppRouter()
        router.analytics = spy
        router.push(.paywall(source: "settings"))
        XCTAssertEqual(spy.screens, [.paywall],
                       "pushing .paywall must track the paywall screen")
    }

    func testPushSettingsTracksNoScreen() {
        let spy = SpyAnalyticsTracker()
        let router = AppRouter()
        router.analytics = spy
        router.push(.settings)
        XCTAssertTrue(spy.screens.isEmpty,
                      ".settings is intentionally unmapped — no screen view on push")
    }

    /// Bug 2 regression: constructing a BrowseViewModel must NOT log
    /// `category_selected` on launch. CombineLatest3 emits its initial
    /// `(nil, .featured, "")` on subscription; the dedup baseline is seeded to
    /// the initial category so that synthetic emission is treated as
    /// already-seen. The first genuine user category change must still log.
    func testBrowseDoesNotLogCategorySelectedOnLaunch() {
        let spy = SpyAnalyticsTracker()
        let vm = BrowseViewModel(repository: InMemoryAnimationRepository(),
                                 analytics: spy)

        // Let the 120ms debounce (DispatchQueue.main) settle without any user action.
        let settled = expectation(description: "debounce settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { settled.fulfill() }
        wait(for: [settled], timeout: 1.0)

        XCTAssertTrue(categoryEvents(in: spy).isEmpty,
                      "no category_selected event may fire before the user changes the category")

        // A genuine user category change must log exactly once.
        vm.selectedCategory = .loaders
        let logged = expectation(description: "category change logged")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { logged.fulfill() }
        wait(for: [logged], timeout: 1.0)

        XCTAssertEqual(categoryEvents(in: spy), [.categorySelected(Category.loaders.rawValue)],
                       "the first genuine category change must log category_selected exactly once")
    }

    func testCodeUnlockAttemptLogsNeedsPro() {
        let spy = SpyAnalyticsTracker()
        // Pick a Pro item so the gate is needs_pro when signed out & not Pro.
        let proItem = AnimationCatalogSeed.items.first { $0.isPro }!
        let vm = DetailViewModel(animationId: proItem.id,
                                 repository: InMemoryAnimationRepository(),
                                 favorites: FavoritesRepository(),
                                 purchases: StoreManager(),
                                 analytics: spy)
        vm.logCodeUnlockAttempt(.needsPro)
        XCTAssertTrue(spy.events.contains {
            if case let .codeUnlockAttempt(result, _, _, _) = $0 { return result == "needs_pro" } else { return false }
        }, "unlock attempt on a Pro item must log code_unlock_attempt result=needs_pro")
    }

    func testCodeUnlockAttemptGrantedLogsNothing() {
        let spy = SpyAnalyticsTracker()
        let vm = DetailViewModel(animationId: AnimationCatalogSeed.items[0].id,
                                 repository: InMemoryAnimationRepository(),
                                 favorites: FavoritesRepository(),
                                 purchases: StoreManager(),
                                 analytics: spy)
        let before = spy.events.count
        vm.logCodeUnlockAttempt(.granted)
        XCTAssertEqual(spy.events.count, before, "granted access must not log an unlock attempt")
    }

    func testSearchRecordsJourneySearch() {
        let d = UserDefaults(suiteName: "BrowseSearch.\(UUID().uuidString)")!
        let metrics = JourneyMetrics(defaults: d)
        let vm = BrowseViewModel(repository: InMemoryAnimationRepository(),
                                 analytics: SpyAnalyticsTracker(),
                                 journeyMetrics: metrics)
        vm.searchText = "spinner"
        let settled = expectation(description: "debounce settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { settled.fulfill() }
        wait(for: [settled], timeout: 1.0)
        XCTAssertGreaterThanOrEqual(d.integer(forKey: "journey.searchesCount"), 1,
                                    "a debounced search must record a journey search")
    }

    /// Filters a spy's events down to `category_selected` only (search events
    /// also flow through the same sink).
    private func categoryEvents(in spy: SpyAnalyticsTracker) -> [AnalyticsEvent] {
        spy.events.filter { if case .categorySelected = $0 { return true } else { return false } }
    }

    /// Isolated, empty UserDefaults so favorites state is deterministic per test.
    private static func ephemeralDefaults() -> UserDefaults {
        let suite = "AnalyticsInstrumentationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
