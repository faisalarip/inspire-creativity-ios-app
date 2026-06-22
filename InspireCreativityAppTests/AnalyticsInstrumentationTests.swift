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

    /// Isolated, empty UserDefaults so favorites state is deterministic per test.
    private static func ephemeralDefaults() -> UserDefaults {
        let suite = "AnalyticsInstrumentationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
