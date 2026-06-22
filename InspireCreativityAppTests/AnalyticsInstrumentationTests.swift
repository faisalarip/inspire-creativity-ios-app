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
        let vm = DetailViewModel(animationId: item.id,
                                 repository: InMemoryAnimationRepository(),
                                 favorites: FavoritesRepository(),
                                 purchases: StoreManager(),
                                 analytics: spy)
        vm.toggleFavorite()
        XCTAssertTrue(spy.events.contains(.favoriteToggled(id: item.id, on: vm.isFavorited)),
                      "toggleFavorite must log favorite_toggled with the resulting state")
    }
}
