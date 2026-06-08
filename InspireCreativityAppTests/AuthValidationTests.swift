import XCTest
@testable import InspireCreativityApp

/// Pure-logic tests for the client-side email gate. No network.
final class AuthValidationTests: XCTestCase {

    func testAcceptsWellFormedAddresses() {
        let valid = [
            "a@b.co",
            "faisal.arif@tuntun.co.id",
            "user+tag@example.com",
            "UPPER.CASE@Domain.IO",
            "name_123@sub.domain.org",
        ]
        for email in valid {
            XCTAssertTrue(AuthValidation.isValidEmail(email), "expected valid: \(email)")
        }
    }

    func testRejectsMalformedAddresses() {
        let invalid = [
            "",
            "plainaddress",
            "@no-local.com",
            "no-at-sign.com",
            "trailing@dot.",
            "spaces in@email.com",
            "two@@at.com",
            "no-tld@domain",
        ]
        for email in invalid {
            XCTAssertFalse(AuthValidation.isValidEmail(email), "expected invalid: \(email)")
        }
    }

    func testTrimsSurroundingWhitespace() {
        XCTAssertTrue(AuthValidation.isValidEmail("  user@example.com \n"))
    }
}

/// Locks in the free/Pro split so a future seed edit can't silently give the
/// catalog away (the bug where sub-$10 Pro backgrounds leaked as free).
final class CatalogGatingTests: XCTestCase {

    func testFreeTasterIsExactlyTwenty() {
        let free = AnimationCatalogSeed.items.filter(\.isFree).count
        XCTAssertEqual(free, 20, "Free taster drifted from 20 — check isPro flags in the seed/aurora descriptors")
    }

    func testIsFreeIsTheInverseOfIsPro() {
        for item in AnimationCatalogSeed.items {
            XCTAssertEqual(item.isFree, !item.isPro,
                           "\(item.id): isFree must mirror !isPro so the badge and access gate never disagree")
        }
    }
}
