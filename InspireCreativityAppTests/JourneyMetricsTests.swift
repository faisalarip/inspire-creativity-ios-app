import XCTest
@testable import InspireCreativityApp

final class JourneyMetricsTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let suite = "JourneyMetricsTests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    func testViewsBucketBoundaries() {
        XCTAssertEqual(JourneyMetrics.viewsBucket(0), "0")
        XCTAssertEqual(JourneyMetrics.viewsBucket(1), "1_3")
        XCTAssertEqual(JourneyMetrics.viewsBucket(3), "1_3")
        XCTAssertEqual(JourneyMetrics.viewsBucket(4), "4_10")
        XCTAssertEqual(JourneyMetrics.viewsBucket(10), "4_10")
        XCTAssertEqual(JourneyMetrics.viewsBucket(11), "11_30")
        XCTAssertEqual(JourneyMetrics.viewsBucket(30), "11_30")
        XCTAssertEqual(JourneyMetrics.viewsBucket(31), "31_plus")
    }

    func testEngagementBoundaries() {
        XCTAssertEqual(JourneyMetrics.engagement(0), "new")
        XCTAssertEqual(JourneyMetrics.engagement(3), "browser")
        XCTAssertEqual(JourneyMetrics.engagement(4), "engaged")
        XCTAssertEqual(JourneyMetrics.engagement(15), "engaged")
        XCTAssertEqual(JourneyMetrics.engagement(16), "power")
    }

    func testElapsedAndSecondsBuckets() {
        XCTAssertEqual(JourneyMetrics.elapsedBucket(59 * 60), "lt_1h")
        XCTAssertEqual(JourneyMetrics.elapsedBucket(2 * 3600), "1_24h")
        XCTAssertEqual(JourneyMetrics.elapsedBucket(3 * 86_400), "1_7d")
        XCTAssertEqual(JourneyMetrics.elapsedBucket(10 * 86_400), "7_30d")
        XCTAssertEqual(JourneyMetrics.elapsedBucket(40 * 86_400), "gt_30d")
        XCTAssertEqual(JourneyMetrics.secondsBucket(4), "lt_5s")
        XCTAssertEqual(JourneyMetrics.secondsBucket(10), "5_15s")
        XCTAssertEqual(JourneyMetrics.secondsBucket(30), "15_60s")
        XCTAssertEqual(JourneyMetrics.secondsBucket(90), "gt_60s")
    }

    func testRecordingAndSnapshot() {
        let d = freshDefaults()
        var t = Date(timeIntervalSince1970: 1_000_000)      // first-open time
        let m = JourneyMetrics(defaults: d, now: { t })
        m.recordAnimationView(); m.recordAnimationView(); m.recordAnimationView(); m.recordAnimationView() // 4
        m.recordCodeUnlockAttempt(result: .needsSignIn)     // does NOT count as pro lock
        XCTAssertFalse(m.hitProLock)
        m.recordCodeUnlockAttempt(result: .needsPro)        // pro lock
        XCTAssertTrue(m.hitProLock)
        t = Date(timeIntervalSince1970: 1_000_000 + 2 * 3600) // 2h later
        let ctx = m.snapshotForPurchase(signedIn: true)
        XCTAssertEqual(ctx.hitProLock, true)
        XCTAssertEqual(ctx.animationsViewedBucket, "4_10")
        XCTAssertEqual(ctx.timeToPurchaseBucket, "1_24h")
        XCTAssertEqual(ctx.signedIn, true)
    }

    func testPersistenceAcrossInstances() {
        let d = freshDefaults()
        JourneyMetrics(defaults: d).recordAnimationView()
        XCTAssertEqual(JourneyMetrics(defaults: d).animationsViewedBucket, "1_3")
    }
}
