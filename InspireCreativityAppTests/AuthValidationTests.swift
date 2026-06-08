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
