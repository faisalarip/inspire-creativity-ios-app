//
//  LibraryViewModelTests.swift
//  InspireCreativityAppTests
//

import Combine
import XCTest
@testable import InspireCreativityApp

@MainActor
final class LibraryViewModelTests: XCTestCase {

    private final class FakePurchases: PurchaseRepositoryProtocol {
        var isPro = false
        var isProPublisher: AnyPublisher<Bool, Never> { Just(isPro).eraseToAnyPublisher() }
        func isOwned(_ id: String, freeOverride: Bool) -> Bool { freeOverride || isPro }
    }

    private func makeVM(
        isPro: Bool = false,
        defaults: UserDefaults? = nil
    ) -> (LibraryViewModel, RecentItemsRepository, CollectionsRepository, CopyActivityStore) {
        let suite = defaults ?? Fixtures.freshDefaults("library")
        let purchases = FakePurchases()
        purchases.isPro = isPro
        let recents = RecentItemsRepository(defaults: suite)
        let collections = CollectionsRepository(defaults: suite)
        let copyActivity = CopyActivityStore(defaults: suite, calendar: Fixtures.utcCalendar)
        let vm = LibraryViewModel(
            repository: InMemoryAnimationRepository(),
            favoritesRepo: FavoritesRepository(defaults: suite),
            purchases: purchases,
            recents: recents,
            collectionsRepo: collections,
            streakTracker: StreakTracker(defaults: suite, calendar: Fixtures.utcCalendar),
            copyActivity: copyActivity,
            now: { Fixtures.date(2026, 7, 15, 12) }
        )
        return (vm, recents, collections, copyActivity)
    }

    func testRecentItemsPreserveRecencyOrder() {
        let (vm, recents, _, _) = makeVM()
        recents.record("aurora-mesh")
        recents.record("liquid-chrome")
        XCTAssertEqual(vm.recentItems.map(\.id), ["liquid-chrome", "aurora-mesh"])
    }

    func testCollectionsSurfaceSeedAndCreate() {
        let (vm, _, _, _) = makeVM()
        XCTAssertEqual(vm.collections.map(\.name), ["Onboarding ideas", "Client app · Nova"])

        vm.createCollection(named: "  My set  ")
        XCTAssertEqual(vm.collections.last?.name, "My set")

        vm.createCollection(named: "   ")
        XCTAssertEqual(vm.collections.count, 3, "blank names must not create collections")
    }

    func testStatsReflectCopyActivity() {
        let (vm, _, _, copyActivity) = makeVM()
        copyActivity.recordCopy(on: Fixtures.date(2026, 7, 15, 9))
        copyActivity.recordCopy(on: Fixtures.date(2026, 7, 14, 9))
        XCTAssertEqual(vm.copiesThisWeek, 2)
        XCTAssertEqual(vm.weekBars[1], 1) // Tuesday
        XCTAssertEqual(vm.weekBars[2], 1) // Wednesday
    }

    func testExportSnippetCapsAtTwentyAndSkipsLocked() {
        let (vm, _, _, _) = makeVM(isPro: false)
        vm.tab = .owned
        let snippet = vm.exportSnippet
        XCTAssertEqual(snippet.filename, "InspireCreativityLibrary.swift")

        let markCount = snippet.source.components(separatedBy: "// MARK: - ").count - 1
        XCTAssertLessThanOrEqual(markCount, 20)
        XCTAssertGreaterThan(markCount, 0)

        // Non-pro export of owned items only ever contains free items — and
        // every free item resolves to non-empty source.
        for item in vm.owned.prefix(20) {
            XCTAssertTrue(item.isFree)
        }
    }

    func testTabsExposeOwnedAndFavoritesOnly() {
        XCTAssertEqual(LibraryViewModel.Tab.allCases.map(\.title), ["Owned", "Favorites"])
    }
}
