//
//  SeenItemsRepositoryTests.swift
//  InspireCreativityAppTests
//

import XCTest
@testable import InspireCreativityApp

final class SeenItemsRepositoryTests: XCTestCase {

    func testMarkSeenPersistsAndDedupes() {
        let defaults = Fixtures.freshDefaults("seen")
        let repo = SeenItemsRepository(defaults: defaults)
        XCTAssertFalse(repo.isSeen("aurora-mesh"))
        repo.markSeen("aurora-mesh")
        repo.markSeen("aurora-mesh")
        XCTAssertTrue(repo.isSeen("aurora-mesh"))
        XCTAssertEqual(repo.all().count, 1)

        let reloaded = SeenItemsRepository(defaults: defaults)
        XCTAssertTrue(reloaded.isSeen("aurora-mesh"))
    }

    @MainActor
    func testDetailViewMarksSeen() {
        let defaults = Fixtures.freshDefaults("seen")
        let seen = SeenItemsRepository(defaults: defaults)
        let vm = DetailViewModel(
            animationId: "spinner",
            repository: InMemoryAnimationRepository(),
            favorites: FavoritesRepository(defaults: defaults),
            purchases: StoreManager(),
            seen: seen
        )
        vm.markViewed()
        XCTAssertTrue(seen.isSeen("spinner"))
    }
}
