import XCTest
@testable import InspireCreativityApp

/// Tests for `AuthStore` — the source of truth for "is the user signed in" and
/// the UserDefaults persistence + boot-time session validation. Drives the real
/// store through `AuthService` with `MockURLProtocol`-stubbed HTTP.
@MainActor
final class AuthStoreTests: XCTestCase {

    private let key = "enigma.auth.session"   // AuthStore.defaultsKey (persistence contract)
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "AuthStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        AuthService.session = MockURLProtocol.makeSession()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        MockURLProtocol.reset()
        AuthService.session = .shared
        super.tearDown()
    }

    private func stub(status: Int, json: String) {
        MockURLProtocol.requestHandler = { _ in (status, Data(json.utf8), ["Content-Type": "application/json"]) }
    }

    private let tokenJSON = """
    {"access_token":"acc","refresh_token":"ref","expires_in":3600,"token_type":"bearer",
     "user":{"id":"u1","email":"user@example.com","email_confirmed_at":"2024-01-01T00:00:00Z","created_at":"2024-01-01T00:00:00Z"}}
    """

    private func storeSessionBlob(accessToken: String) {
        let json = """
        {"accessToken":"\(accessToken)","refreshToken":"ref","expiresAt":"2099-01-01T00:00:00Z",
         "user":{"id":"u1","email":"user@example.com","emailConfirmedAt":"2024-01-01T00:00:00Z","createdAt":"2024-01-01T00:00:00Z"}}
        """
        defaults.set(Data(json.utf8), forKey: key)
    }

    /// Polls `condition` until true or timeout, yielding to the runloop. Used to
    /// await `AuthStore`'s fire-and-forget background validation Task.
    private func waitUntil(timeout: TimeInterval = 3,
                           _ condition: () -> Bool,
                           file: StaticString = #filePath, line: UInt = #line) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 30_000_000) // 30ms
        }
        XCTAssertTrue(condition(), "condition not met within \(timeout)s", file: file, line: line)
    }

    // MARK: fresh state

    func testFreshStoreIsSignedOut() {
        let store = AuthStore(defaults: defaults)
        XCTAssertFalse(store.isAuthenticated)
        XCTAssertNil(store.session)
    }

    // MARK: sign-in

    func testSignInSuccessAuthenticatesAndPersists() async {
        stub(status: 200, json: tokenJSON)
        let store = AuthStore(defaults: defaults)
        await store.signIn(email: "user@example.com", password: "secret")
        XCTAssertTrue(store.isAuthenticated)
        XCTAssertEqual(store.session?.accessToken, "acc")
        XCTAssertNil(store.lastError)
        XCTAssertNotNil(defaults.data(forKey: key), "session should be persisted")
    }

    func testSignInFailureSetsErrorAndStaysSignedOut() async {
        stub(status: 400, json: #"{"error_description":"Invalid login credentials"}"#)
        let store = AuthStore(defaults: defaults)
        await store.signIn(email: "user@example.com", password: "wrong")
        XCTAssertFalse(store.isAuthenticated)
        XCTAssertEqual(store.lastError, .invalidCredentials)
        XCTAssertNil(defaults.data(forKey: key))
    }

    // MARK: sign-up

    func testSignUpConfirmationRequiredStashesEmail() async {
        stub(status: 200, json: #"{"id":"u9","confirmation_sent_at":"2024-01-01T00:00:00Z"}"#)
        let store = AuthStore(defaults: defaults)
        await store.signUp(email: "new@example.com", password: "pw123456")
        XCTAssertFalse(store.isAuthenticated)
        XCTAssertEqual(store.pendingVerificationEmail, "new@example.com")
    }

    // MARK: sign-out

    func testSignOutClearsSessionAndStorage() async {
        stub(status: 200, json: tokenJSON)
        let store = AuthStore(defaults: defaults)
        await store.signIn(email: "user@example.com", password: "secret")
        XCTAssertTrue(store.isAuthenticated)
        stub(status: 204, json: "")        // /logout
        await store.signOut()
        XCTAssertFalse(store.isAuthenticated)
        XCTAssertNil(defaults.data(forKey: key))
    }

    // MARK: restore + boot validation

    func testRestoredSessionStartsAuthenticated() {
        storeSessionBlob(accessToken: "restored")
        stub(status: 200, json: #"{"id":"u1","email":"user@example.com","email_confirmed_at":"2024-01-01T00:00:00Z","created_at":"2024-01-01T00:00:00Z"}"#)
        let store = AuthStore(defaults: defaults)
        XCTAssertTrue(store.isAuthenticated, "should boot authenticated from stored session")
    }

    /// 401 on validation → invalidCredentials → session cleared.
    func testRestoredSessionClearedWhenValidationReturns401() async {
        storeSessionBlob(accessToken: "revoked")
        stub(status: 401, json: #"{"msg":"unauthorized"}"#)
        let store = AuthStore(defaults: defaults)
        XCTAssertTrue(store.isAuthenticated, "authenticated before validation completes")
        await waitUntil { !store.isAuthenticated }
        XCTAssertFalse(store.isAuthenticated)
    }

    /// 403 bad_jwt on validation → .unknown → session KEPT. This is exactly the
    /// behavior the run-skill's headless bypass exploits.
    func testRestoredSessionKeptWhenValidationReturns403BadJWT() async {
        storeSessionBlob(accessToken: "fake-access")
        stub(status: 403, json: #"{"code":403,"error_code":"bad_jwt","msg":"invalid JWT: token is malformed"}"#)
        let store = AuthStore(defaults: defaults)
        XCTAssertTrue(store.isAuthenticated)
        // Give the background validation time to run; it must NOT clear.
        try? await Task.sleep(nanoseconds: 800_000_000)
        XCTAssertTrue(store.isAuthenticated, "403 bad_jwt must not sign the user out")
    }
}
