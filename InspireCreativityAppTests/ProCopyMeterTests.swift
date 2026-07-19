//
//  ProCopyMeterTests.swift
//  InspireCreativityAppTests
//

import Combine
import XCTest
@testable import InspireCreativityApp

final class ProCopyMeterTests: XCTestCase {

    private let cal = Fixtures.utcCalendar
    // 2026-07-15 is a Wednesday; the surrounding drop period runs
    // Fri 2026-07-10 08:00 → Fri 2026-07-17 08:00 UTC.
    private let wednesday = Fixtures.date(2026, 7, 15, 12)

    func testDropPeriodSeedStableWithinPeriodChangesAtDrop() {
        let beforeDrop = Fixtures.date(2026, 7, 17, 7, 59)
        let afterDrop = Fixtures.date(2026, 7, 17, 8, 1)
        XCTAssertEqual(
            EngagementSchedule.dropPeriodSeed(for: wednesday, calendar: cal),
            EngagementSchedule.dropPeriodSeed(for: beforeDrop, calendar: cal),
            "same drop period → same seed")
        XCTAssertNotEqual(
            EngagementSchedule.dropPeriodSeed(for: beforeDrop, calendar: cal),
            EngagementSchedule.dropPeriodSeed(for: afterDrop, calendar: cal),
            "crossing Friday 08:00 starts a new period")
    }

    func testFreshMeterHasFullAllowance() {
        let meter = ProCopyMeter(defaults: Fixtures.freshDefaults("meter"), calendar: cal)
        XCTAssertEqual(meter.remaining(on: wednesday), ProCopyMeter.weeklyAllowance)
        XCTAssertFalse(meter.isRedeemed("aurora-mesh", on: wednesday))
    }

    func testRedeemConsumesAndUnlocks() {
        let meter = ProCopyMeter(defaults: Fixtures.freshDefaults("meter"), calendar: cal)
        XCTAssertTrue(meter.redeem("aurora-mesh", on: wednesday))
        XCTAssertEqual(meter.remaining(on: wednesday), 2)
        XCTAssertTrue(meter.isRedeemed("aurora-mesh", on: wednesday))
    }

    func testRedeemIsIdempotentPerPeriod() {
        let meter = ProCopyMeter(defaults: Fixtures.freshDefaults("meter"), calendar: cal)
        XCTAssertTrue(meter.redeem("aurora-mesh", on: wednesday))
        XCTAssertTrue(meter.redeem("aurora-mesh", on: wednesday), "re-redeeming stays unlocked")
        XCTAssertEqual(meter.remaining(on: wednesday), 2, "no double-charge")
    }

    func testExhaustedMeterRejectsNewIdsButKeepsRedeemedOnes() {
        let meter = ProCopyMeter(defaults: Fixtures.freshDefaults("meter"), calendar: cal)
        XCTAssertTrue(meter.redeem("a", on: wednesday))
        XCTAssertTrue(meter.redeem("b", on: wednesday))
        XCTAssertTrue(meter.redeem("c", on: wednesday))
        XCTAssertEqual(meter.remaining(on: wednesday), 0)
        XCTAssertFalse(meter.redeem("d", on: wednesday), "meter spent → paywall moment")
        XCTAssertTrue(meter.redeem("a", on: wednesday), "already-redeemed id stays unlocked")
    }

    func testAllowanceResetsAtTheFridayDrop() {
        let defaults = Fixtures.freshDefaults("meter")
        let meter = ProCopyMeter(defaults: defaults, calendar: cal)
        meter.redeem("a", on: wednesday)
        meter.redeem("b", on: wednesday)

        let nextPeriod = Fixtures.date(2026, 7, 17, 9) // Friday 09:00, after the drop
        XCTAssertEqual(meter.remaining(on: nextPeriod), ProCopyMeter.weeklyAllowance)
        XCTAssertFalse(meter.isRedeemed("a", on: nextPeriod), "unlocks expire with the period")
    }

    func testPersistsAcrossInstances() {
        let defaults = Fixtures.freshDefaults("meter")
        ProCopyMeter(defaults: defaults, calendar: cal).redeem("a", on: wednesday)
        let second = ProCopyMeter(defaults: defaults, calendar: cal)
        XCTAssertEqual(second.remaining(on: wednesday), 2)
        XCTAssertTrue(second.isRedeemed("a", on: wednesday))
    }
}

// MARK: - Detail gate integration

@MainActor
final class DetailMeterGateTests: XCTestCase {

    private final class FakePurchases: PurchaseRepositoryProtocol {
        var isPro = false
        var isProPublisher: AnyPublisher<Bool, Never> { Just(isPro).eraseToAnyPublisher() }
        func isOwned(_ id: String, freeOverride: Bool) -> Bool { freeOverride || isPro }
    }

    private func makeVM(
        animationId: String,
        meter: ProCopyMeter,
        analytics: SpyAnalyticsTracker = SpyAnalyticsTracker()
    ) -> DetailViewModel {
        DetailViewModel(
            animationId: animationId,
            repository: InMemoryAnimationRepository(),
            favorites: FavoritesRepository(defaults: Fixtures.freshDefaults("fav")),
            purchases: FakePurchases(),
            analytics: analytics,
            journeyMetrics: JourneyMetrics(defaults: Fixtures.freshDefaults("jm")),
            meter: meter
        )
    }

    func testRedeemUnlocksProItemAndLogs() {
        let meter = ProCopyMeter(defaults: Fixtures.freshDefaults("meter"))
        let analytics = SpyAnalyticsTracker()
        let vm = makeVM(animationId: "aurora-mesh", meter: meter, analytics: analytics) // pro item

        XCTAssertEqual(vm.meterRemaining, ProCopyMeter.weeklyAllowance)
        XCTAssertFalse(vm.meterUnlocked)
        XCTAssertTrue(vm.redeemMeterCopy())
        XCTAssertTrue(vm.meterUnlocked)
        XCTAssertEqual(vm.meterRemaining, ProCopyMeter.weeklyAllowance - 1)
        XCTAssertEqual(analytics.loggedNames, ["meter_copy_used"])
    }

    func testExhaustedMeterRoutesToPaywallMoment() {
        let defaults = Fixtures.freshDefaults("meter")
        let meter = ProCopyMeter(defaults: defaults)
        meter.redeem("a"); meter.redeem("b"); meter.redeem("c")

        let analytics = SpyAnalyticsTracker()
        let vm = makeVM(animationId: "aurora-mesh", meter: meter, analytics: analytics)
        XCTAssertEqual(vm.meterRemaining, 0)
        XCTAssertFalse(vm.redeemMeterCopy())
        XCTAssertFalse(vm.meterUnlocked)
        XCTAssertEqual(analytics.loggedNames, ["meter_exhausted"])
    }

    func testFreeItemNeverTouchesMeter() {
        let meter = ProCopyMeter(defaults: Fixtures.freshDefaults("meter"))
        let analytics = SpyAnalyticsTracker()
        let vm = makeVM(animationId: "spinner", meter: meter, analytics: analytics) // free item

        XCTAssertFalse(vm.redeemMeterCopy())
        XCTAssertEqual(meter.remaining(), ProCopyMeter.weeklyAllowance)
        XCTAssertTrue(analytics.events.isEmpty)
    }

    func testAlreadyRedeemedItemStartsUnlocked() {
        let defaults = Fixtures.freshDefaults("meter")
        ProCopyMeter(defaults: defaults).redeem("aurora-mesh")
        let vm = makeVM(animationId: "aurora-mesh", meter: ProCopyMeter(defaults: defaults))
        XCTAssertTrue(vm.meterUnlocked)
    }
}
