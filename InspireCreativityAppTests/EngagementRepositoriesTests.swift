//
//  EngagementRepositoriesTests.swift
//  InspireCreativityAppTests
//
//  Covers RecentItemsRepository, CollectionsRepository, RecentSearchesStore
//  and ActivityRepository (plan tasks 4–7).
//

import XCTest
@testable import InspireCreativityApp

final class RecentItemsRepositoryTests: XCTestCase {

    func testRecordOrdersMostRecentFirstAndDedupes() {
        let repo = RecentItemsRepository(defaults: Fixtures.freshDefaults("recents"))
        repo.record("a"); repo.record("b"); repo.record("a")
        XCTAssertEqual(repo.all(), ["a", "b"])
    }

    func testCapAtTen() {
        let repo = RecentItemsRepository(defaults: Fixtures.freshDefaults("recents"))
        (0..<12).forEach { repo.record("anim-\($0)") }
        XCTAssertEqual(repo.all().count, 10)
        XCTAssertEqual(repo.all().first, "anim-11")
    }

    func testPersistsAcrossInstances() {
        let defaults = Fixtures.freshDefaults("recents")
        RecentItemsRepository(defaults: defaults).record("a")
        XCTAssertEqual(RecentItemsRepository(defaults: defaults).all(), ["a"])
    }
}

final class CollectionsRepositoryTests: XCTestCase {

    func testFirstRunSeedsStarterCollections() {
        let repo = CollectionsRepository(defaults: Fixtures.freshDefaults("collections"))
        let names = repo.all().map(\.name)
        XCTAssertEqual(names, ["Onboarding ideas", "Client app · Nova"])
        XCTAssertEqual(repo.all().first?.animationIds.count, 4)
    }

    func testCreateAddRemoveDeletePersist() {
        let defaults = Fixtures.freshDefaults("collections")
        let repo = CollectionsRepository(defaults: defaults)
        let created = repo.create(name: "Test")
        repo.add("spinner", to: created.id)
        repo.add("spinner", to: created.id) // dedupe
        repo.add("toast", to: created.id)
        repo.remove("toast", from: created.id)

        let reloaded = CollectionsRepository(defaults: defaults)
        let found = reloaded.all().first { $0.id == created.id }
        XCTAssertEqual(found?.animationIds, ["spinner"])

        reloaded.delete(created.id)
        XCTAssertNil(CollectionsRepository(defaults: defaults).all().first { $0.id == created.id })
    }

    func testDeletingAllDoesNotReseed() {
        let defaults = Fixtures.freshDefaults("collections")
        let repo = CollectionsRepository(defaults: defaults)
        repo.all().forEach { repo.delete($0.id) }
        XCTAssertTrue(CollectionsRepository(defaults: defaults).all().isEmpty)
    }
}

final class RecentSearchesStoreTests: XCTestCase {

    func testRecordDedupesCaseInsensitively() {
        let store = RecentSearchesStore(defaults: Fixtures.freshDefaults("searches"))
        store.record("Aurora")
        store.record("glass")
        store.record("aurora")
        XCTAssertEqual(store.all(), ["aurora", "glass"])
    }

    func testIgnoresWhitespaceOnlyAndCapsAtEight() {
        let store = RecentSearchesStore(defaults: Fixtures.freshDefaults("searches"))
        store.record("   ")
        XCTAssertTrue(store.all().isEmpty)
        (0..<10).forEach { store.record("query \($0)") }
        XCTAssertEqual(store.all().count, 8)
        XCTAssertEqual(store.all().first, "query 9")
    }

    func testClearPersists() {
        let defaults = Fixtures.freshDefaults("searches")
        let store = RecentSearchesStore(defaults: defaults)
        store.record("aurora")
        store.clear()
        XCTAssertTrue(RecentSearchesStore(defaults: defaults).all().isEmpty)
    }
}

final class ActivityRepositoryTests: XCTestCase {

    private let cal = Fixtures.utcCalendar

    func testFirstRefreshSeedsInboxNewestFirst() {
        let repo = ActivityRepository(defaults: Fixtures.freshDefaults("activity"), calendar: cal)
        XCTAssertTrue(repo.all().isEmpty)
        repo.refresh(now: Fixtures.date(2026, 7, 15, 12)) // Wednesday
        let items = repo.all()
        XCTAssertEqual(items.count, 6)
        XCTAssertEqual(items.first?.headline, "Friday Drop is live")
        XCTAssertEqual(repo.unreadCount, 3)
    }

    func testMarkAllReadPersists() {
        let defaults = Fixtures.freshDefaults("activity")
        let repo = ActivityRepository(defaults: defaults, calendar: cal)
        repo.refresh(now: Fixtures.date(2026, 7, 15, 12))
        repo.markAllRead()
        XCTAssertEqual(repo.unreadCount, 0)
        XCTAssertEqual(ActivityRepository(defaults: defaults, calendar: cal).unreadCount, 0)
    }

    func testRefreshAppendsOneDropEntryPerDropPeriod() {
        let defaults = Fixtures.freshDefaults("activity")
        let repo = ActivityRepository(defaults: defaults, calendar: cal)
        repo.refresh(now: Fixtures.date(2026, 7, 15, 12)) // Wednesday: seed only
        XCTAssertEqual(repo.all().count, 6)

        repo.refresh(now: Fixtures.date(2026, 7, 17, 9))  // after Friday drop: +1
        XCTAssertEqual(repo.all().count, 7)
        XCTAssertEqual(repo.unreadCount, 4)

        repo.refresh(now: Fixtures.date(2026, 7, 18, 9))  // same period: no dupe
        XCTAssertEqual(repo.all().count, 7)

        repo.refresh(now: Fixtures.date(2026, 7, 21, 9))  // after Tuesday drop: +1
        XCTAssertEqual(repo.all().count, 8)
    }
}
