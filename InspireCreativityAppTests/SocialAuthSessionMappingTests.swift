import XCTest
@testable import InspireCreativityApp

/// Tests for the supabase-swift social-login integration (Strategy 2b).
///
/// These run fully headlessly — they never touch the network, the Keychain, or
/// the live Apple/Google handshakes (which cannot be exercised in CI). They
/// lock two things:
///   1. the pure SDK-session → app-`AuthSession` mapping, and
///   2. that `AuthStore.signInWithApple/Google` persist on success and map
///      failures to `lastError`, mirroring the email `signIn` shape.
final class SocialAuthSessionMappingTests: XCTestCase {

    // MARK: - Pure converter mapping

    func testConverterMapsAllFields() {
        let expiresUnix: TimeInterval = 1_800_000_000 // a fixed UNIX timestamp
        let confirmed = Date(timeIntervalSince1970: 1_700_000_000)
        let created = Date(timeIntervalSince1970: 1_690_000_000)

        let session = SocialAuthSessionConverter.makeSession(
            accessToken: "acc-token",
            refreshToken: "ref-token",
            expiresAtUnix: expiresUnix,
            userId: "11111111-2222-3333-4444-555555555555",
            email: "creator@example.com",
            emailConfirmedAt: confirmed,
            createdAt: created
        )

        XCTAssertEqual(session.accessToken, "acc-token")
        XCTAssertEqual(session.refreshToken, "ref-token")
        // expiresAt must be the UNIX timestamp interpreted as seconds-since-1970.
        XCTAssertEqual(session.expiresAt, Date(timeIntervalSince1970: expiresUnix))
        XCTAssertEqual(session.user.id, "11111111-2222-3333-4444-555555555555")
        XCTAssertEqual(session.user.email, "creator@example.com")
        XCTAssertEqual(session.user.emailConfirmedAt, confirmed)
        XCTAssertEqual(session.user.createdAt, created)
    }

    func testConverterToleratesNilOptionalUserFields() {
        let session = SocialAuthSessionConverter.makeSession(
            accessToken: "a",
            refreshToken: "r",
            expiresAtUnix: 0,
            userId: "u",
            email: nil,
            emailConfirmedAt: nil,
            createdAt: nil
        )
        XCTAssertNil(session.user.email)
        XCTAssertNil(session.user.emailConfirmedAt)
        XCTAssertNil(session.user.createdAt)
        XCTAssertEqual(session.expiresAt, Date(timeIntervalSince1970: 0))
    }

    // MARK: - AuthStore Apple/Google methods (fake service, no network)

    @MainActor
    func testSignInWithApplePersistsAndFlagsJustSignedIn() async {
        let fake = FakeSocialAuthService()
        let session = Self.sampleSession(accessToken: "apple-acc")
        fake.appleResult = .success(session)

        let (store, defaults, key) = Self.makeStore(service: fake)

        await store.signInWithApple(idToken: "id-token", nonce: "raw-nonce")

        XCTAssertEqual(fake.appleCallCount, 1)
        XCTAssertEqual(fake.lastIdToken, "id-token")
        XCTAssertEqual(fake.lastNonce, "raw-nonce")
        XCTAssertTrue(store.isAuthenticated)
        XCTAssertEqual(store.session?.accessToken, "apple-acc")
        XCTAssertTrue(store.justSignedIn)
        XCTAssertNil(store.lastError)
        XCTAssertFalse(store.isLoading)
        // Persisted to the same UserDefaults key the email flow uses.
        XCTAssertNotNil(defaults.data(forKey: key))
    }

    @MainActor
    func testSignInWithAppleFailureMapsToError() async {
        let fake = FakeSocialAuthService()
        fake.appleResult = .failure(SampleError.boom)

        let (store, _, _) = Self.makeStore(service: fake)

        await store.signInWithApple(idToken: "x", nonce: "y")

        XCTAssertFalse(store.isAuthenticated)
        XCTAssertFalse(store.justSignedIn)
        XCTAssertFalse(store.isLoading)
        guard case .network = store.lastError else {
            return XCTFail("Expected .network error, got \(String(describing: store.lastError))")
        }
    }

    @MainActor
    func testSignInWithGooglePersistsAndFlagsJustSignedIn() async {
        let fake = FakeSocialAuthService()
        fake.googleResult = .success(Self.sampleSession(accessToken: "google-acc"))

        let (store, defaults, key) = Self.makeStore(service: fake)

        await store.signInWithGoogle()

        XCTAssertEqual(fake.googleCallCount, 1)
        XCTAssertTrue(store.isAuthenticated)
        XCTAssertEqual(store.session?.accessToken, "google-acc")
        XCTAssertTrue(store.justSignedIn)
        XCTAssertNil(store.lastError)
        XCTAssertNotNil(defaults.data(forKey: key))
    }

    @MainActor
    func testSignInWithGoogleTypedAuthErrorIsPreserved() async {
        let fake = FakeSocialAuthService()
        fake.googleResult = .failure(AuthError.invalidCredentials)

        let (store, _, _) = Self.makeStore(service: fake)

        await store.signInWithGoogle()

        XCTAssertEqual(store.lastError, .invalidCredentials)
        XCTAssertFalse(store.isAuthenticated)
    }

    // MARK: - Helpers

    private enum SampleError: Error { case boom }

    private static func sampleSession(accessToken: String) -> AuthSession {
        AuthSession(
            accessToken: accessToken,
            refreshToken: "ref",
            expiresAt: Date(timeIntervalSince1970: 4_000_000_000),
            user: AuthUser(id: "u1", email: "u@e.com", emailConfirmedAt: nil, createdAt: nil)
        )
    }

    @MainActor
    private static func makeStore(
        service: FakeSocialAuthService
    ) -> (AuthStore, UserDefaults, String) {
        let suite = "SocialAuthTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let store = AuthStore(defaults: defaults, socialAuth: { service })
        return (store, defaults, "enigma.auth.session")
    }
}

/// In-memory fake conforming to the app's `SocialAuthServicing`. Lets us drive
/// `AuthStore`'s social methods deterministically without the SDK or network.
@MainActor
private final class FakeSocialAuthService: SocialAuthServicing {

    var appleResult: Result<AuthSession, Error> = .failure(NSError(domain: "test", code: 0))
    var googleResult: Result<AuthSession, Error> = .failure(NSError(domain: "test", code: 0))

    private(set) var appleCallCount = 0
    private(set) var googleCallCount = 0
    private(set) var lastIdToken: String?
    private(set) var lastNonce: String?

    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSession {
        appleCallCount += 1
        lastIdToken = idToken
        lastNonce = nonce
        return try appleResult.get()
    }

    func signInWithGoogle() async throws -> AuthSession {
        googleCallCount += 1
        return try googleResult.get()
    }
}
