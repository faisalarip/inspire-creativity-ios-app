import XCTest
@testable import InspireCreativityApp

final class AnalyticsEventTests: XCTestCase {

    private let reservedPrefixes = ["ga_", "firebase_", "google_"]

    func testEventNamesAreGA4Valid() {
        let events: [AnalyticsEvent] = [
            .animationView(id: "ges-x", category: "Gestures", isPro: true),
            .codeCopied(id: "ges-x"),
            .favoriteToggled(id: "ges-x", on: true),
            .search(termLength: 4),
            .categorySelected("Gestures"),
            .paywallViewed(source: "detail"),
            .purchaseCompleted(productID: "pro.lifetime", source: "detail"),
            .signIn(method: "apple"),
            .auroraPromoTap
        ]
        for event in events {
            let name = event.name
            XCTAssertLessThanOrEqual(name.count, 40, "\(name) exceeds GA4's 40-char limit")
            XCTAssertEqual(name, name.lowercased(), "\(name) must be snake_case")
            XCTAssertTrue(name.allSatisfy { $0.isLowercase || $0.isNumber || $0 == "_" },
                          "\(name) has invalid characters")
            XCTAssertFalse(reservedPrefixes.contains { name.hasPrefix($0) },
                           "\(name) uses a reserved GA4 prefix")
        }
    }

    func testSearchCarriesLengthNotRawQuery() {
        let params = AnalyticsEvent.search(termLength: 7).parameters
        XCTAssertEqual(params["term_length"] as? Int, 7)
        XCTAssertNil(params["query"], "raw query must never be logged (PII)")
        XCTAssertNil(params["term"], "raw term must never be logged (PII)")
    }

    func testParameterValuesAreWithinGA4Limits() {
        let params = AnalyticsEvent.animationView(id: "ges-x", category: "Gestures", isPro: false).parameters
        XCTAssertEqual(params["animation_id"] as? String, "ges-x")
        XCTAssertEqual(params["category"] as? String, "Gestures")
        XCTAssertEqual(params["is_pro"] as? Bool, false)
        for (key, value) in params {
            XCTAssertLessThanOrEqual(key.count, 40, "param key \(key) too long")
            if let s = value as? String { XCTAssertLessThanOrEqual(s.count, 100, "param \(key) value too long") }
        }
    }

    func testPurchaseCompletedCarriesProductAndSource() {
        let event = AnalyticsEvent.purchaseCompleted(
            productID: "com.faisalarip.InspireCreativityApp.pro.lifetime",
            source: "settings"
        )
        XCTAssertEqual(event.name, "purchase_completed")
        let params = event.parameters
        XCTAssertEqual(params["product_id"] as? String,
                       "com.faisalarip.InspireCreativityApp.pro.lifetime")
        XCTAssertEqual(params["source"] as? String, "settings",
                       "purchase_completed must record where the IAP originated, matching paywall_viewed's taxonomy")
    }

    func testEventEquatable() {
        XCTAssertEqual(AnalyticsEvent.favoriteToggled(id: "a", on: true),
                       AnalyticsEvent.favoriteToggled(id: "a", on: true))
        XCTAssertNotEqual(AnalyticsEvent.favoriteToggled(id: "a", on: true),
                          AnalyticsEvent.favoriteToggled(id: "a", on: false))
    }
}
