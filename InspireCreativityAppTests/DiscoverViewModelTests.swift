//
//  DiscoverViewModelTests.swift
//  InspireCreativityAppTests
//

import Combine
import XCTest
@testable import InspireCreativityApp

@MainActor
final class DiscoverViewModelTests: XCTestCase {

    private final class FakePurchases: PurchaseRepositoryProtocol {
        var isPro = false
        var isProPublisher: AnyPublisher<Bool, Never> { Just(isPro).eraseToAnyPublisher() }
        func isOwned(_ id: String, freeOverride: Bool) -> Bool { freeOverride || isPro }
    }

    private func makeVM(
        signedIn: Bool = true,
        isPro: Bool = false,
        defaults: UserDefaults? = nil,
        now: Date = Fixtures.date(2026, 7, 15, 12)
    ) -> (DiscoverViewModel, SpyAnalyticsTracker, CopyActivityStore, UserDefaults) {
        let suite = defaults ?? Fixtures.freshDefaults("discover")
        let analytics = SpyAnalyticsTracker()
        let copyActivity = CopyActivityStore(defaults: suite, calendar: Fixtures.utcCalendar)
        let purchases = FakePurchases()
        purchases.isPro = isPro
        let vm = DiscoverViewModel(
            repository: InMemoryAnimationRepository(),
            purchases: purchases,
            streakTracker: StreakTracker(defaults: suite, calendar: Fixtures.utcCalendar),
            activity: ActivityRepository(defaults: suite, calendar: Fixtures.utcCalendar),
            copyActivity: copyActivity,
            analytics: analytics,
            signedIn: { signedIn },
            defaults: suite,
            calendar: Fixtures.utcCalendar,
            now: { now }
        )
        return (vm, analytics, copyActivity, suite)
    }

    func testDerivedSectionsPopulated() {
        let (vm, _, _, _) = makeVM()
        XCTAssertNotNil(vm.dailyPick)
        XCTAssertEqual(vm.dailyResetLabel, "resets in 12h")
        XCTAssertTrue(vm.dropCountdownLabel.hasPrefix("in 1d 20h"))
        XCTAssertEqual(vm.challengeDaysLeft, "4d left")
        XCTAssertEqual(vm.freeThisWeek.count, 4)
        XCTAssertTrue(vm.freeThisWeek.allSatisfy(\.isFree))
        XCTAssertFalse(vm.trending.isEmpty)
    }

    func testJoinChallengePersistsForTheWeek() {
        let suite = Fixtures.freshDefaults("discover")
        let (vm, _, _, _) = makeVM(defaults: suite)
        XCTAssertFalse(vm.challengeJoined)
        vm.joinChallenge()
        XCTAssertTrue(vm.challengeJoined)

        // Same week, fresh instance → still joined.
        let (vm2, _, _, _) = makeVM(defaults: suite, now: Fixtures.date(2026, 7, 16, 9))
        XCTAssertTrue(vm2.challengeJoined)

        // Next week → resets.
        let (vm3, _, _, _) = makeVM(defaults: suite, now: Fixtures.date(2026, 7, 22, 9))
        XCTAssertFalse(vm3.challengeJoined)
    }

    func testCopyDailyPickWhenGrantedRecordsEverything() throws {
        // Pro entitlement grants every pick regardless of the day's rotation.
        let (vm, analytics, copyActivity, _) = makeVM(signedIn: true, isPro: true)
        XCTAssertNotNil(vm.dailyPick)

        XCTAssertEqual(vm.copyDailyPick(), .copied)
        XCTAssertTrue(vm.dailyCopied)
        XCTAssertEqual(analytics.loggedNames, ["code_copied"])
        XCTAssertEqual(copyActivity.copiesThisWeek(for: Fixtures.date(2026, 7, 15)), 1)
    }

    func testCopyDailyPickNeedsDetailWhenSignedOut() {
        let (vm, analytics, _, _) = makeVM(signedIn: false)
        XCTAssertEqual(vm.copyDailyPick(), .needsDetail)
        XCTAssertFalse(vm.dailyCopied)
        XCTAssertTrue(analytics.events.isEmpty)
    }

    func testUnreadCountReflectsActivityInbox() {
        let suite = Fixtures.freshDefaults("discover")
        let activity = ActivityRepository(defaults: suite, calendar: Fixtures.utcCalendar)
        activity.refresh(now: Fixtures.date(2026, 7, 15, 9))
        let (vm, _, _, _) = makeVM(defaults: suite)
        XCTAssertEqual(vm.unreadCount, 3)
    }
}
