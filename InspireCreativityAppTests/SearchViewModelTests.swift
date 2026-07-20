//
//  SearchViewModelTests.swift
//  InspireCreativityAppTests
//

import XCTest
@testable import InspireCreativityApp

@MainActor
final class SearchViewModelTests: XCTestCase {

    private func makeVM(defaults: UserDefaults? = nil) -> (SearchViewModel, RecentSearchesStore) {
        let suite = defaults ?? Fixtures.freshDefaults("searchvm")
        let store = RecentSearchesStore(defaults: suite)
        let vm = SearchViewModel(
            repository: InMemoryAnimationRepository(),
            recentSearches: store,
            analytics: SpyAnalyticsTracker(),
            journeyMetrics: JourneyMetrics(defaults: suite)
        )
        return (vm, store)
    }

    func testPopularResolvesCuratedIds() {
        let (vm, _) = makeVM()
        XCTAssertEqual(vm.popular.map(\.id), ["aurora-mesh", "liquid-chrome", "liquid-tabs", "hologram-card"])
    }

    func testCommitRecordsRecentAndSetsQuery() {
        let (vm, store) = makeVM()
        vm.commit("aurora")
        XCTAssertEqual(vm.query, "aurora")
        XCTAssertEqual(store.all(), ["aurora"])

        vm.commit("  ")
        XCTAssertEqual(store.all(), ["aurora"], "blank queries are not recorded")
    }

    func testClearRecents() {
        let (vm, store) = makeVM()
        vm.commit("aurora")
        vm.clearRecents()
        XCTAssertTrue(store.all().isEmpty)
    }

    func testDebouncedSearchProducesResultsAndEmptyStates() async {
        let (vm, _) = makeVM()
        vm.query = "aurora"
        try? await Task.sleep(nanoseconds: 400_000_000)
        guard case .results(let items) = vm.state else {
            return XCTFail("expected results for 'aurora', got \(vm.state)")
        }
        XCTAssertFalse(items.isEmpty)

        vm.query = "zzzz-no-match"
        try? await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertEqual(vm.state, .empty(query: "zzzz-no-match"))

        vm.clear()
        XCTAssertEqual(vm.state, .idle)
    }
}

// MARK: - Repository search matching

final class AnimationSearchTests: XCTestCase {

    private let repo = InMemoryAnimationRepository()

    func testThemeQueryReturnsAuroraThemeItems() {
        let results = repo.search("cosmic")
        XCTAssertGreaterThan(results.count, 3, "theme queries must return the theme's aurora set")
        XCTAssertTrue(results.contains { AuroraDescriptors.byId[$0.id]?.theme == "Cosmic" })
    }

    func testFreeQueryReturnsExactlyTheFreeSet() {
        let results = repo.search("free")
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.allSatisfy(\.isFree), "'free' must not leak pro items")
        XCTAssertEqual(results.count, repo.all().filter(\.isFree).count)
    }

    func testCategoryQueryReturnsWholeCategory() {
        let results = repo.search("loaders")
        XCTAssertEqual(
            Set(results.map(\.id)),
            Set(repo.all().filter { $0.category == .loaders }.map(\.id)),
            "a category query must return the full category")
    }

    func testResultsSortedByPopularity() {
        let downloads = repo.search("aurora").map(\.downloads)
        XCTAssertEqual(downloads, downloads.sorted(by: >))
    }
}
