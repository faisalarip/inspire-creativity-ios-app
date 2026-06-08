import XCTest
@testable import InspireCreativityApp

/// Client-server contract tests for `AuthService`. Every Supabase HTTP exchange
/// is stubbed through `MockURLProtocol` so we assert on request construction and
/// response/error mapping deterministically and offline.
final class AuthServiceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AuthService.session = MockURLProtocol.makeSession()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        AuthService.session = .shared
        super.tearDown()
    }

    /// Set the canned response for the next request.
    private func stub(status: Int, json: String, headers: [String: String] = ["Content-Type": "application/json"]) {
        MockURLProtocol.requestHandler = { _ in (status, Data(json.utf8), headers) }
    }

    private let tokenJSON = """
    {"access_token":"acc","refresh_token":"ref","expires_in":3600,"token_type":"bearer",
     "user":{"id":"u1","email":"user@example.com","email_confirmed_at":"2024-01-01T00:00:00Z","created_at":"2024-01-01T00:00:00Z"}}
    """

    // MARK: sign-in

    func testSignInSuccessReturnsSession() async throws {
        stub(status: 200, json: tokenJSON)
        let session = try await AuthService.signIn(email: "user@example.com", password: "secret")
        XCTAssertEqual(session.accessToken, "acc")
        XCTAssertEqual(session.refreshToken, "ref")
        XCTAssertEqual(session.user.email, "user@example.com")
    }

    func testSignInSendsCorrectRequest() async throws {
        stub(status: 200, json: tokenJSON)
        _ = try await AuthService.signIn(email: "user@example.com", password: "pw123456")
        let req = try XCTUnwrap(MockURLProtocol.lastRequest)
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertEqual(req.url?.path, "/auth/v1/token")
        XCTAssertEqual(req.url?.query, "grant_type=password")
        XCTAssertNotNil(req.value(forHTTPHeaderField: "apikey"))
        XCTAssertEqual(req.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = try XCTUnwrap(req.capturedBody)
        let obj = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(obj["email"] as? String, "user@example.com")
        XCTAssertEqual(obj["password"] as? String, "pw123456")
    }

    func testSignInInvalidCredentialsMapsError() async {
        stub(status: 400, json: #"{"error_description":"Invalid login credentials"}"#)
        await assertThrows(.invalidCredentials) {
            _ = try await AuthService.signIn(email: "u@e.com", password: "wrong")
        }
    }

    func testSignInEmailNotConfirmedMapsError() async {
        stub(status: 400, json: #"{"error_code":"email_not_confirmed","msg":"Email not confirmed"}"#)
        await assertThrows(.emailNotConfirmed) {
            _ = try await AuthService.signIn(email: "u@e.com", password: "pw")
        }
    }

    // MARK: sign-up

    func testSignUpConfirmationRequiredWhenNoToken() async throws {
        stub(status: 200, json: #"{"id":"u9","email":"new@e.com","confirmation_sent_at":"2024-01-01T00:00:00Z"}"#)
        let result = try await AuthService.signUp(email: "new@e.com", password: "pw123456")
        guard case .confirmationRequired = result else {
            return XCTFail("expected .confirmationRequired, got \(result)")
        }
    }

    func testSignUpReturnsSessionWhenConfirmOff() async throws {
        stub(status: 200, json: tokenJSON)
        let result = try await AuthService.signUp(email: "new@e.com", password: "pw123456")
        guard case .session(let s) = result else {
            return XCTFail("expected .session, got \(result)")
        }
        XCTAssertEqual(s.accessToken, "acc")
    }

    func testSignUpAlreadyRegisteredMapsError() async {
        stub(status: 422, json: #"{"msg":"User already registered"}"#)
        await assertThrows(.emailAlreadyRegistered) {
            _ = try await AuthService.signUp(email: "dupe@e.com", password: "pw123456")
        }
    }

    // MARK: currentUser — the behavior the headless bypass depends on

    func testCurrentUserSucceedsOn200() async throws {
        stub(status: 200, json: #"{"id":"u1","email":"user@example.com","email_confirmed_at":"2024-01-01T00:00:00Z","created_at":"2024-01-01T00:00:00Z"}"#)
        let user = try await AuthService.currentUser(accessToken: "acc")
        XCTAssertEqual(user.id, "u1")
    }

    /// A malformed (non-JWT) token yields 403 `bad_jwt`, which must map to
    /// `.unknown` — NOT `.invalidCredentials`. AuthStore only clears the
    /// session on `.invalidCredentials`, so this is what keeps an injected
    /// fake session alive (run-skill bypass).
    func testCurrentUserMalformedTokenMapsToUnknownNotInvalidCredentials() async {
        stub(status: 403, json: #"{"code":403,"error_code":"bad_jwt","msg":"invalid JWT: unable to parse or verify signature, token is malformed"}"#)
        do {
            _ = try await AuthService.currentUser(accessToken: "fake-access")
            XCTFail("expected throw")
        } catch let error as AuthError {
            XCTAssertNotEqual(error, .invalidCredentials, "403 bad_jwt must NOT be invalidCredentials")
            if case .unknown = error { /* ok */ } else {
                XCTFail("expected .unknown, got \(error)")
            }
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }

    func testCurrentUser401MapsToInvalidCredentials() async {
        stub(status: 401, json: #"{"msg":"unauthorized"}"#)
        await assertThrows(.invalidCredentials) {
            _ = try await AuthService.currentUser(accessToken: "revoked")
        }
    }

    // MARK: transport errors

    func testTransportFailureMapsToNetworkError() async {
        MockURLProtocol.requestHandler = { _ in
            throw NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        }
        do {
            _ = try await AuthService.signIn(email: "u@e.com", password: "pw")
            XCTFail("expected throw")
        } catch let error as AuthError {
            if case .network = error { /* ok */ } else { XCTFail("expected .network, got \(error)") }
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }

    // MARK: helper

    private func assertThrows(_ expected: AuthError,
                              _ block: () async throws -> Void,
                              file: StaticString = #filePath, line: UInt = #line) async {
        do {
            try await block()
            XCTFail("expected \(expected) to be thrown", file: file, line: line)
        } catch let error as AuthError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("unexpected error type: \(error)", file: file, line: line)
        }
    }
}
