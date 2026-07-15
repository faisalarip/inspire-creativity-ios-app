//
//  StreakTrackerTests.swift
//  InspireCreativityAppTests
//

import XCTest
@testable import InspireCreativityApp

final class StreakTrackerTests: XCTestCase {

    private let cal = Fixtures.utcCalendar

    func testFirstOpenStartsStreakAtOne() {
        let tracker = StreakTracker(defaults: Fixtures.freshDefaults("streak"), calendar: cal)
        XCTAssertEqual(tracker.current, 0)
        XCTAssertEqual(tracker.recordAppOpen(on: Fixtures.date(2026, 7, 15, 9)), 1)
    }

    func testSameDayRepeatDoesNotIncrement() {
        let tracker = StreakTracker(defaults: Fixtures.freshDefaults("streak"), calendar: cal)
        tracker.recordAppOpen(on: Fixtures.date(2026, 7, 15, 9))
        XCTAssertEqual(tracker.recordAppOpen(on: Fixtures.date(2026, 7, 15, 21)), 1)
    }

    func testConsecutiveDaysIncrement() {
        let tracker = StreakTracker(defaults: Fixtures.freshDefaults("streak"), calendar: cal)
        tracker.recordAppOpen(on: Fixtures.date(2026, 7, 15))
        XCTAssertEqual(tracker.recordAppOpen(on: Fixtures.date(2026, 7, 16)), 2)
        XCTAssertEqual(tracker.recordAppOpen(on: Fixtures.date(2026, 7, 17)), 3)
    }

    func testGapResetsToOne() {
        let tracker = StreakTracker(defaults: Fixtures.freshDefaults("streak"), calendar: cal)
        tracker.recordAppOpen(on: Fixtures.date(2026, 7, 15))
        tracker.recordAppOpen(on: Fixtures.date(2026, 7, 16))
        XCTAssertEqual(tracker.recordAppOpen(on: Fixtures.date(2026, 7, 19)), 1)
    }

    func testPersistsAcrossInstances() {
        let defaults = Fixtures.freshDefaults("streak")
        StreakTracker(defaults: defaults, calendar: cal).recordAppOpen(on: Fixtures.date(2026, 7, 15))
        let second = StreakTracker(defaults: defaults, calendar: cal)
        XCTAssertEqual(second.current, 1)
        XCTAssertEqual(second.recordAppOpen(on: Fixtures.date(2026, 7, 16)), 2)
    }
}
