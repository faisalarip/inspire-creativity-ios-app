import XCTest
@testable import InspireCreativityApp

final class AnalyticsUserPropertyTests: XCTestCase {
    func testNamesAndValuesWithinGA4Limits() {
        let props: [AnalyticsUserProperty] = [
            .isPro(true), .signedIn(false), .platform("macos"),
            .engagementLevel("engaged"), .animationsViewedBucket("11_30")
        ]
        for p in props {
            XCTAssertLessThanOrEqual(p.name.count, 24, "\(p.name) exceeds 24-char user-property limit")
            XCTAssertEqual(p.name, p.name.lowercased(), "\(p.name) must be snake_case")
            if let v = p.value { XCTAssertLessThanOrEqual(v.count, 36, "\(p.name) value too long") }
        }
    }

    func testMapping() {
        XCTAssertEqual(AnalyticsUserProperty.isPro(true).name, "is_pro")
        XCTAssertEqual(AnalyticsUserProperty.isPro(true).value, "true")
        XCTAssertEqual(AnalyticsUserProperty.signedIn(false).value, "false")
        XCTAssertEqual(AnalyticsUserProperty.platform("ios").name, "platform")
        XCTAssertEqual(AnalyticsUserProperty.engagementLevel("power").name, "engagement_level")
        XCTAssertEqual(AnalyticsUserProperty.animationsViewedBucket("0").name, "animations_viewed_bucket")
    }

    func testSpyRecordsUserProperties() {
        let spy = SpyAnalyticsTracker()
        spy.set(.isPro(true))
        XCTAssertEqual(spy.userProperties.first?.name, "is_pro")
        XCTAssertEqual(spy.userProperties.first?.value, "true")
    }
}
