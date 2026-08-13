//
//  NotificationPlannerTests.swift
//  InspireCreativityAppTests
//

import XCTest
@testable import InspireCreativityApp

final class NotificationPlannerTests: XCTestCase {

    func testDefaultsRoundTrip() {
        let defaults = Fixtures.freshDefaults("prefs")
        XCTAssertEqual(NotificationPreferences.load(from: defaults), .default)
        var prefs = NotificationPreferences.default
        prefs.trending = true
        prefs.frequency = .weekly
        prefs.save(to: defaults)
        XCTAssertEqual(NotificationPreferences.load(from: defaults), prefs)
    }

    func testDefaultHasTrendingOffEverythingElseOn() {
        let d = NotificationPreferences.default
        XCTAssertTrue(d.isEnabled && d.fridayDrops && d.freeThisWeek && d.creators && d.priceDrops && d.streakReminders)
        XCTAssertFalse(d.trending)
        XCTAssertEqual(d.frequency, .realtime)
    }

    func testAllOnWithStreakYieldsFourPlans() {
        var prefs = NotificationPreferences.default
        prefs.trending = true // still no local plan for trending
        let plans = EngagementNotificationPlanner.plans(for: prefs, streak: 6)
        XCTAssertEqual(plans.map(\.id), [
            "engagement.drop.tuesday",
            "engagement.drop.friday",
            "engagement.free.friday",
            "engagement.streak.daily",
        ])
        XCTAssertEqual(plans[0].weekday, 3)
        XCTAssertEqual(plans[0].hour, 8)
        XCTAssertEqual(plans[1].weekday, 6)
        XCTAssertEqual(plans[1].hour, 8)
        XCTAssertEqual(plans[2].weekday, 6)
        XCTAssertEqual(plans[2].hour, 9)
        XCTAssertNil(plans[3].weekday)
        XCTAssertTrue(plans[3].title.contains("6-day streak"))
    }

    func testMasterOffYieldsNoPlans() {
        var prefs = NotificationPreferences.default
        prefs.isEnabled = false
        XCTAssertTrue(EngagementNotificationPlanner.plans(for: prefs, streak: 6).isEmpty)
    }

    func testZeroStreakSuppressesStreakPlan() {
        let plans = EngagementNotificationPlanner.plans(for: .default, streak: 0)
        XCTAssertFalse(plans.contains { $0.id == "engagement.streak.daily" })
    }

    func testCreatorsPriceDropsTrendingScheduleNothingLocally() {
        var prefs = NotificationPreferences.default
        prefs.fridayDrops = false
        prefs.freeThisWeek = false
        prefs.streakReminders = false
        prefs.creators = true
        prefs.priceDrops = true
        prefs.trending = true
        XCTAssertTrue(EngagementNotificationPlanner.plans(for: prefs, streak: 6).isEmpty)
    }
}

// MARK: - Coordinator

@MainActor
final class NotificationCoordinatorTests: XCTestCase {

    private final class SpyScheduler: NotificationScheduling {
        var status: NotificationAuthorization = .notDetermined
        var grantOnRequest = true
        private(set) var removeAllCount = 0
        private(set) var scheduled: [NotificationPlan] = []

        func authorizationStatus() async -> NotificationAuthorization { status }
        func requestAuthorization() async -> Bool {
            if grantOnRequest { status = .authorized }
            else { status = .denied }
            return grantOnRequest
        }
        func removeAllPending() { removeAllCount += 1; scheduled = [] }
        func schedule(_ plan: NotificationPlan) { scheduled.append(plan) }
    }

    func testApplySchedulesWhenAuthorizedAndEnabled() async {
        let spy = SpyScheduler()
        spy.status = .authorized
        let coordinator = NotificationCoordinator(
            scheduler: spy, defaults: Fixtures.freshDefaults("coord"), analytics: SpyAnalyticsTracker()
        )
        await coordinator.refreshAuthorization()
        coordinator.apply(streak: 6)
        XCTAssertEqual(spy.removeAllCount, 1)
        XCTAssertEqual(spy.scheduled.count, 4) // Tue drop, Fri drop, free, streak
    }

    func testApplyOnlyRemovesWhenDeniedOrDisabled() async {
        let spy = SpyScheduler()
        spy.status = .denied
        let coordinator = NotificationCoordinator(
            scheduler: spy, defaults: Fixtures.freshDefaults("coord"), analytics: SpyAnalyticsTracker()
        )
        await coordinator.refreshAuthorization()
        coordinator.apply(streak: 6)
        XCTAssertTrue(spy.scheduled.isEmpty)

        spy.status = .authorized
        await coordinator.refreshAuthorization()
        var prefs = coordinator.preferences
        prefs.isEnabled = false
        coordinator.update(prefs, streak: 6)
        XCTAssertTrue(spy.scheduled.isEmpty)
    }

    func testRequestPermissionGrantedEnablesAndSchedulesAndLogs() async {
        let spy = SpyScheduler()
        let analytics = SpyAnalyticsTracker()
        let defaults = Fixtures.freshDefaults("coord")
        var prefs = NotificationPreferences.default
        prefs.isEnabled = false
        prefs.save(to: defaults)

        let coordinator = NotificationCoordinator(scheduler: spy, defaults: defaults, analytics: analytics)
        let granted = await coordinator.requestPermission(streak: 3)

        XCTAssertTrue(granted)
        XCTAssertTrue(coordinator.preferences.isEnabled)
        XCTAssertTrue(coordinator.isRemindMeActive)
        XCTAssertEqual(spy.scheduled.count, 4) // Tue drop, Fri drop, free, streak
        XCTAssertEqual(analytics.events, [.notificationPermission(granted: true)])
        XCTAssertEqual(NotificationPreferences.load(from: defaults).isEnabled, true)
    }

    func testRequestPermissionDeniedLogsAndSchedulesNothing() async {
        let spy = SpyScheduler()
        spy.grantOnRequest = false
        let analytics = SpyAnalyticsTracker()
        let coordinator = NotificationCoordinator(
            scheduler: spy, defaults: Fixtures.freshDefaults("coord"), analytics: analytics
        )
        let granted = await coordinator.requestPermission(streak: 3)
        XCTAssertFalse(granted)
        XCTAssertFalse(coordinator.isRemindMeActive)
        XCTAssertTrue(spy.scheduled.isEmpty)
        XCTAssertEqual(analytics.events, [.notificationPermission(granted: false)])
    }
}
