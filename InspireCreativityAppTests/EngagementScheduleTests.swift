//
//  EngagementScheduleTests.swift
//  InspireCreativityAppTests
//

import XCTest
@testable import InspireCreativityApp

final class EngagementScheduleTests: XCTestCase {

    private let cal = Fixtures.utcCalendar
    private let items = (0..<5).map { Fixtures.item(id: "anim-\($0)") }

    // MARK: - Daily pick

    func testDailyPickIsStableWithinADay() {
        let morning = Fixtures.date(2026, 7, 15, 8)
        let evening = Fixtures.date(2026, 7, 15, 22)
        XCTAssertEqual(
            EngagementSchedule.dailyPick(from: items, on: morning, calendar: cal)?.id,
            EngagementSchedule.dailyPick(from: items, on: evening, calendar: cal)?.id
        )
    }

    func testDailyPickRotatesAcrossDays() {
        let picks = (15...19).compactMap { day in
            EngagementSchedule.dailyPick(from: items, on: Fixtures.date(2026, 7, day), calendar: cal)?.id
        }
        XCTAssertEqual(picks.count, 5)
        XCTAssertGreaterThan(Set(picks).count, 1, "pick should rotate day to day")
    }

    func testDailyPickOrderIndependentOfInputOrder() {
        let date = Fixtures.date(2026, 7, 15)
        XCTAssertEqual(
            EngagementSchedule.dailyPick(from: items, on: date, calendar: cal)?.id,
            EngagementSchedule.dailyPick(from: items.reversed(), on: date, calendar: cal)?.id
        )
    }

    func testDailyPickEmptyReturnsNil() {
        XCTAssertNil(EngagementSchedule.dailyPick(from: [], on: Fixtures.date(2026, 7, 15), calendar: cal))
    }

    // MARK: - Reset countdown

    func testDailyPickResetsInUntilMidnight() {
        let now = Fixtures.date(2026, 7, 15, 15)
        XCTAssertEqual(EngagementSchedule.dailyPickResetsIn(from: now, calendar: cal), 9 * 3600, accuracy: 1)
    }

    func testDailyResetLabels() {
        XCTAssertEqual(EngagementSchedule.dailyResetLabel(from: Fixtures.date(2026, 7, 15, 15), calendar: cal), "resets in 9h")
        XCTAssertEqual(EngagementSchedule.dailyResetLabel(from: Fixtures.date(2026, 7, 15, 23, 30), calendar: cal), "resets in 30m")
    }

    // MARK: - Friday Drop

    func testNextDropFromWednesdayIsSameWeekFriday() {
        // 2026-07-15 is a Wednesday; the drop lands Friday 2026-07-17 08:00 UTC.
        let drop = EngagementSchedule.nextDrop(after: Fixtures.date(2026, 7, 15, 12), calendar: cal)
        XCTAssertEqual(drop, Fixtures.date(2026, 7, 17, 8))
    }

    func testNextDropOnFridayMorningBeforeEight() {
        let drop = EngagementSchedule.nextDrop(after: Fixtures.date(2026, 7, 17, 7), calendar: cal)
        XCTAssertEqual(drop, Fixtures.date(2026, 7, 17, 8))
    }

    func testNextDropOnFridayAfterEightIsNextWeek() {
        let drop = EngagementSchedule.nextDrop(after: Fixtures.date(2026, 7, 17, 9), calendar: cal)
        XCTAssertEqual(drop, Fixtures.date(2026, 7, 24, 8))
    }

    func testCountdownLabels() {
        let now = Fixtures.date(2026, 7, 15, 12)
        XCTAssertEqual(EngagementSchedule.countdownLabel(to: Fixtures.date(2026, 7, 18, 2), from: now), "in 2d 14h")
        XCTAssertEqual(EngagementSchedule.countdownLabel(to: Fixtures.date(2026, 7, 16, 2, 5), from: now), "in 14h 5m")
        XCTAssertEqual(EngagementSchedule.countdownLabel(to: Fixtures.date(2026, 7, 15, 12, 5), from: now), "in 5m")
        XCTAssertEqual(EngagementSchedule.countdownLabel(to: now, from: now), "now")
    }

    // MARK: - Free this week

    func testFreeThisWeekReturnsFourFreeItems() {
        let mixed = items + [Fixtures.item(id: "pro-1", isPro: true), Fixtures.item(id: "z-free")]
        let free = EngagementSchedule.freeThisWeek(from: mixed, on: Fixtures.date(2026, 7, 15), calendar: cal)
        XCTAssertEqual(free.count, 4)
        XCTAssertTrue(free.allSatisfy(\.isFree))
    }

    func testFreeThisWeekStableWithinWeekRotatesAcrossWeeks() {
        let pool = (0..<9).map { Fixtures.item(id: "free-\($0)") }
        let monday = EngagementSchedule.freeThisWeek(from: pool, on: Fixtures.date(2026, 7, 13), calendar: cal)
        let thursday = EngagementSchedule.freeThisWeek(from: pool, on: Fixtures.date(2026, 7, 16), calendar: cal)
        let nextWeek = EngagementSchedule.freeThisWeek(from: pool, on: Fixtures.date(2026, 7, 20), calendar: cal)
        XCTAssertEqual(monday.map(\.id), thursday.map(\.id))
        XCTAssertNotEqual(monday.map(\.id), nextWeek.map(\.id))
    }

    func testFreeThisWeekWithFewFreeItemsReturnsAll() {
        let pool = [Fixtures.item(id: "a"), Fixtures.item(id: "b"), Fixtures.item(id: "pro", isPro: true)]
        let free = EngagementSchedule.freeThisWeek(from: pool, on: Fixtures.date(2026, 7, 15), calendar: cal)
        XCTAssertEqual(free.map(\.id), ["a", "b"])
    }

    // MARK: - Challenge window

    func testChallengeDaysLeft() {
        // Wed 15th → Sunday 19th = 4 days out.
        XCTAssertEqual(EngagementSchedule.challengeDaysLeftLabel(from: Fixtures.date(2026, 7, 15), calendar: cal), "4d left")
        XCTAssertEqual(EngagementSchedule.challengeDaysLeftLabel(from: Fixtures.date(2026, 7, 16), calendar: cal), "3d left")
        XCTAssertEqual(EngagementSchedule.challengeDaysLeftLabel(from: Fixtures.date(2026, 7, 19), calendar: cal), "ends today")
    }
}
