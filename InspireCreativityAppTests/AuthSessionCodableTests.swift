import XCTest
@testable import InspireCreativityApp

/// `AuthSession` is persisted to `UserDefaults` and re-read on launch. These
/// tests pin the on-disk JSON contract (property-name keys, ISO-8601 dates) so
/// a stored session keeps decoding across builds.
final class AuthSessionCodableTests: XCTestCase {

    private func makeEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
    private func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    private func sample() -> AuthSession {
        AuthSession(
            accessToken: "access-123",
            refreshToken: "refresh-456",
            expiresAt: Date(timeIntervalSince1970: 4_102_444_800), // 2100-01-01
            user: AuthUser(
                id: "uuid-1",
                email: "user@example.com",
                emailConfirmedAt: Date(timeIntervalSince1970: 1_700_000_000),
                createdAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        )
    }

    func testRoundTrips() throws {
        let original = sample()
        let data = try makeEncoder().encode(original)
        let decoded = try makeDecoder().decode(AuthSession.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    /// The JSON uses the Swift property names verbatim (no snake_case). The
    /// headless run-skill bypass relies on exactly these keys.
    func testJSONUsesPropertyNameKeys() throws {
        let data = try makeEncoder().encode(sample())
        let obj = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNotNil(obj["accessToken"])
        XCTAssertNotNil(obj["refreshToken"])
        XCTAssertNotNil(obj["expiresAt"])
        let user = try XCTUnwrap(obj["user"] as? [String: Any])
        XCTAssertEqual(user["id"] as? String, "uuid-1")
        XCTAssertNotNil(user["emailConfirmedAt"])
        // snake_case keys must NOT be present.
        XCTAssertNil(obj["access_token"])
    }

    /// The exact blob the run-skill injects must decode into a usable session.
    func testInjectedBypassBlobDecodes() throws {
        let json = #"{"accessToken":"fake-access","refreshToken":"fake-refresh","expiresAt":"2099-01-01T00:00:00Z","user":{"id":"00000000-0000-0000-0000-000000000000","email":"dev@local.test","emailConfirmedAt":"2024-01-01T00:00:00Z","createdAt":"2024-01-01T00:00:00Z"}}"#
        let decoded = try makeDecoder().decode(AuthSession.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.accessToken, "fake-access")
        XCTAssertEqual(decoded.user.email, "dev@local.test")
    }
}
