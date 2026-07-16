import XCTest
@testable import InspireCreativityApp

/// Locks the Discover → Browse category drill-down plus Browse v2's
/// scope / sort / paging behavior.
final class BrowseFilterTests: XCTestCase {

    /// The router hands a tapped category to Browse exactly once: reading it
    /// also clears it, so re-entering Browse later doesn't re-apply a stale
    /// filter.
    @MainActor
    func testTakePendingBrowseCategoryReturnsThenClears() {
        let router = AppRouter()
        XCTAssertNil(router.takePendingBrowseCategory(), "nothing pending by default")

        router.pendingBrowseCategory = .loaders
        XCTAssertEqual(router.takePendingBrowseCategory(), .loaders)
        XCTAssertNil(router.pendingBrowseCategory, "consuming the pending category must clear it")
        XCTAssertNil(router.takePendingBrowseCategory(), "a second take yields nil")
    }

    /// Drilling into a category filters the grid to only that category.
    @MainActor
    func testCategoryScopeFiltersDrillItems() {
        let vm = BrowseViewModel(repository: InMemoryAnimationRepository())
        vm.scope = .category(.backgrounds)

        XCTAssertFalse(vm.drillItems.isEmpty, "Backgrounds should contain items")
        XCTAssertTrue(vm.drillItems.allSatisfy { $0.category == .backgrounds },
                      "every drilled item must belong to the selected category")
    }

    /// Theme scope keeps only aurora animations with that descriptor theme.
    @MainActor
    func testThemeScopeFiltersToThemeIds() throws {
        let vm = BrowseViewModel(repository: InMemoryAnimationRepository())
        let theme = try XCTUnwrap(vm.themes.first?.name)
        vm.scope = .theme(theme)

        let expected = Set(AuroraDescriptors.all.filter { $0.theme == theme }.map(\.id))
        XCTAssertFalse(vm.drillItems.isEmpty)
        XCTAssertTrue(vm.drillItems.allSatisfy { expected.contains($0.id) })
    }

    /// Sort chips reorder the drilled grid.
    @MainActor
    func testSortOrders() {
        let vm = BrowseViewModel(repository: InMemoryAnimationRepository())
        vm.scope = .category(.backgrounds)

        vm.sort = .popular
        let downloads = vm.drillItems.map(\.downloads)
        XCTAssertEqual(downloads, downloads.sorted(by: >))

        vm.sort = .rating
        let ratings = vm.drillItems.map(\.rating)
        XCTAssertEqual(ratings, ratings.sorted(by: >))

        vm.sort = .freeFirst
        let proFlags = vm.drillItems.map(\.isPro)
        // All free items (if any are visible) must come before any pro item.
        if let firstPro = proFlags.firstIndex(of: true) {
            XCTAssertFalse(proFlags[firstPro...].contains(false),
                           "free items must sort ahead of pro items")
        }
    }

    /// Paging reveals 12 at a time; loadMore extends without reshuffling.
    @MainActor
    func testPagingIn12Steps() {
        let vm = BrowseViewModel(repository: InMemoryAnimationRepository())
        vm.scope = .category(.backgrounds)

        guard vm.drillTotal > 12 else {
            return XCTFail("expected more than one page of backgrounds")
        }
        XCTAssertEqual(vm.drillItems.count, 12)
        let firstPage = vm.drillItems.map(\.id)
        vm.loadMore()
        XCTAssertEqual(vm.drillItems.count, min(24, vm.drillTotal))
        XCTAssertEqual(Array(vm.drillItems.prefix(12)).map(\.id), firstPage)
    }

    /// Leaving the drill resets paging for the next visit.
    @MainActor
    func testScopeChangeResetsPaging() {
        let vm = BrowseViewModel(repository: InMemoryAnimationRepository())
        vm.scope = .category(.backgrounds)
        vm.loadMore()
        vm.scope = .overview
        vm.scope = .category(.backgrounds)
        XCTAssertEqual(vm.drillItems.count, min(12, vm.drillTotal))
    }
}
