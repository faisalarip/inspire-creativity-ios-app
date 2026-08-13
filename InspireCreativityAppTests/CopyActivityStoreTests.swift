//
//  CopyActivityStoreTests.swift
//  InspireCreativityAppTests
//

import XCTest
@testable import InspireCreativityApp

final class CopyActivityStoreTests: XCTestCase {

    private let cal = Fixtures.utcCalendar

    func testWeekBarsMondayFirst() {
        let store = CopyActivityStore(defaults: Fixtures.freshDefaults("copies"), calendar: cal)
        // 2026-07-15 is Wednesday, 2026-07-17 is Friday.
        store.recordCopy(on: Fixtures.date(2026, 7, 15, 9))
        store.recordCopy(on: Fixtures.date(2026, 7, 15, 10))
        store.recordCopy(on: Fixtures.date(2026, 7, 15, 11))
        store.recordCopy(on: Fixtures.date(2026, 7, 17, 9))
        XCTAssertEqual(store.weekBars(for: Fixtures.date(2026, 7, 15, 20)), [0, 0, 3, 0, 1, 0, 0])
        XCTAssertEqual(store.copiesThisWeek(for: Fixtures.date(2026, 7, 15, 20)), 4)
    }

    func testPreviousWeekExcludedFromBars() {
        let store = CopyActivityStore(defaults: Fixtures.freshDefaults("copies"), calendar: cal)
        store.recordCopy(on: Fixtures.date(2026, 7, 10)) // previous week (Friday)
        store.recordCopy(on: Fixtures.date(2026, 7, 14)) // this week (Tuesday)
        XCTAssertEqual(store.copiesThisWeek(for: Fixtures.date(2026, 7, 15)), 1)
    }

    func testOldEntriesPrunedOnRecord() {
        let defaults = Fixtures.freshDefaults("copies")
        let store = CopyActivityStore(defaults: defaults, calendar: cal)
        store.recordCopy(on: Fixtures.date(2026, 6, 1))
        store.recordCopy(on: Fixtures.date(2026, 7, 15))
        // The June entry is >21 days before July 15 and must be gone.
        XCTAssertEqual(store.copiesThisWeek(for: Fixtures.date(2026, 6, 1)), 0)
        XCTAssertEqual(store.copiesThisWeek(for: Fixtures.date(2026, 7, 15)), 1)
    }

    func testPersistsAcrossInstances() {
        let defaults = Fixtures.freshDefaults("copies")
        CopyActivityStore(defaults: defaults, calendar: cal).recordCopy(on: Fixtures.date(2026, 7, 15))
        XCTAssertEqual(CopyActivityStore(defaults: defaults, calendar: cal).copiesThisWeek(for: Fixtures.date(2026, 7, 15)), 1)
    }
}
