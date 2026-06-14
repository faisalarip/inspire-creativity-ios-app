import XCTest
@testable import InspireCreativityApp

/// Locks the Discover → Browse category drill-down. Tapping a category tile on
/// Discover must carry that category into a *filtered* Browse tab — the bug was
/// that the tap discarded the category and dumped the user into an unfiltered
/// Browse.
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

    /// Selecting a category filters the Browse grid to only that category.
    @MainActor
    func testSelectingCategoryFiltersVisibleItems() async {
        let vm = BrowseViewModel(repository: InMemoryAnimationRepository())
        vm.selectedCategory = .backgrounds
        await waitForDebounce()

        XCTAssertFalse(vm.visibleItems.isEmpty, "Backgrounds should contain items")
        XCTAssertTrue(vm.visibleItems.allSatisfy { $0.category == .backgrounds },
                      "every visible item must belong to the selected category")
    }

    /// Clearing the category shows the whole catalog again (so it's strictly
    /// larger than a single-category slice).
    @MainActor
    func testNilCategoryShowsMoreThanOneCategory() async {
        let vm = BrowseViewModel(repository: InMemoryAnimationRepository())
        vm.selectedCategory = .loaders
        await waitForDebounce()
        let loadersCount = vm.visibleItems.count

        vm.selectedCategory = nil
        await waitForDebounce()
        XCTAssertGreaterThan(vm.visibleItems.count, loadersCount,
                             "the full catalog must be larger than a single category")
    }

    /// The Browse filter pipeline is Combine-debounced (~120ms); wait past it.
    private func waitForDebounce() async {
        try? await Task.sleep(nanoseconds: 400_000_000)
    }
}
