//
//  SocialAuthService.swift
//  InspireCreativityApp
//
//  Strategy 2b — supabase-swift is used ONLY as the engine for the two
//  social sign-in flows (Apple OIDC + Google web OAuth). The app's existing
//  hand-rolled email auth (`AuthService`), its `AuthSession` Codable, and its
//  `UserDefaults` persistence in `AuthStore` remain the single source of
//  truth. We configure the SDK with an in-memory `AuthLocalStorage` so the SDK
//  never persists a competing session in the Keychain — we take the `Session`
//  it returns, convert it to the app's `AuthSession`, and let `AuthStore`
//  persist it exactly as it persists an email sign-in.
//

import Foundation
import Supabase

// MARK: ─────────────────────────────────────────────────────────────
// MARK: In-memory SDK session storage
// MARK: ─────────────────────────────────────────────────────────────

/// Volatile, thread-safe implementation of the SDK's `AuthLocalStorage`.
///
/// The SDK insists on persisting the session it mints somewhere; by handing it
/// this process-lifetime dictionary (instead of the default Keychain store) we
/// guarantee the SDK never writes a second, competing session to disk. The
/// app's own `AuthStore` + `UserDefaults` stay the only durable auth state.
final class InMemoryAuthStorage: AuthLocalStorage, @unchecked Sendable {

    private let lock = NSLock()
    private var store: [String: Data] = [:]

    func store(key: String, value: Data) throws {
        lock.lock(); defer { lock.unlock() }
        store[key] = value
    }

    func retrieve(key: String) throws -> Data? {
        lock.lock(); defer { lock.unlock() }
        return store[key]
    }

    func remove(key: String) throws {
        lock.lock(); defer { lock.unlock() }
        store[key] = nil
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: Pure, testable session conversion
// MARK: ─────────────────────────────────────────────────────────────

/// Pure mapping from the primitive fields of an SDK session to the app's
/// `AuthSession`. Deliberately takes primitives (not the SDK's `Session`/`User`
/// types) so it is trivially unit-testable without constructing any SDK value
/// or hitting the network. The service layer is responsible for extracting
/// these primitives from the SDK's `Session`.
enum SocialAuthSessionConverter {

    /// Builds an app `AuthSession` from the raw token/user fields the SDK
    /// returns. `expiresAtUnix` is the UNIX timestamp (seconds since 1970) the
    /// SDK exposes on `Session.expiresAt`.
    static func makeSession(
        accessToken: String,
        refreshToken: String,
        expiresAtUnix: TimeInterval,
        userId: String,
        email: String?,
        emailConfirmedAt: Date?,
        createdAt: Date?
    ) -> AuthSession {
        AuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date(timeIntervalSince1970: expiresAtUnix),
            user: AuthUser(
                id: userId,
                email: email,
                emailConfirmedAt: emailConfirmedAt,
                createdAt: createdAt
            )
        )
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: Social auth service
// MARK: ─────────────────────────────────────────────────────────────

/// Protocol the `AuthStore` depends on, so the store can be tested against a
/// fake and the concrete SDK-backed implementation can be swapped out.
@MainActor
protocol SocialAuthServicing: Sendable {
    /// Verifies an Apple identity token via Supabase OIDC and returns the
    /// resulting session converted to the app's `AuthSession`.
    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSession
    /// Runs Google's web OAuth flow (ASWebAuthenticationSession-backed) and
    /// returns the resulting session converted to the app's `AuthSession`.
    func signInWithGoogle() async throws -> AuthSession
}

/// supabase-swift-backed implementation of `SocialAuthServicing`.
///
/// Constructs a `SupabaseClient` whose auth layer uses `InMemoryAuthStorage`,
/// so no SDK session is ever written to the Keychain. Reuses the same project
/// URL + anon key as the rest of the app (see `SupabaseConfig`).
@MainActor
final class SocialAuthService: SocialAuthServicing {

    /// Redirect target for the Google web-OAuth callback. Must match the
    /// custom URL scheme declared in Info.plist (`CFBundleURLTypes`) and be
    /// allow-listed in Supabase → Auth → URL Configuration → Redirect URLs.
    nonisolated static let googleRedirectURL = URL(string: "inspirecreativity://auth-callback")!

    private let client: SupabaseClient

    /// - Parameter client: injectable for tests. Defaults to a client wired to
    ///   `SupabaseConfig` with in-memory session storage.
    ///
    /// `nonisolated` so the default argument can be evaluated outside the main
    /// actor (e.g. from `AuthStore.init`'s default-argument closure). The
    /// `SupabaseClient` is `Sendable` and its construction is not main-actor
    /// bound; only the network-facing `signIn*` methods stay `@MainActor`.
    nonisolated init(client: SupabaseClient = SocialAuthService.makeClient()) {
        self.client = client
    }

    /// Builds the SDK client with in-memory storage and auto-refresh disabled
    /// (the app, not the SDK, owns session lifecycle). The global redirect URL
    /// is set so the convenience OAuth flow can derive the callback scheme.
    nonisolated static func makeClient() -> SupabaseClient {
        let url = URL(string: SupabaseConfig.url) ?? URL(string: "https://invalid.invalid")!
        let options = SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(
                storage: InMemoryAuthStorage(),
                redirectToURL: googleRedirectURL,
                autoRefreshToken: false
            )
        )
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: SupabaseConfig.anonKey,
            options: options
        )
    }

    // MARK: - Apple (OpenID Connect)

    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSession {
        let session = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
        return Self.convert(session)
    }

    // MARK: - Google (web OAuth via ASWebAuthenticationSession)

    func signInWithGoogle() async throws -> AuthSession {
        let session = try await client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: Self.googleRedirectURL
        )
        return Self.convert(session)
    }

    // MARK: - SDK → app adaptation

    /// Adapts the SDK's `Session`/`User` into the app's `AuthSession` by
    /// extracting primitives and delegating to the pure converter.
    private static func convert(_ session: Session) -> AuthSession {
        SocialAuthSessionConverter.makeSession(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            expiresAtUnix: session.expiresAt,
            userId: session.user.id.uuidString,
            email: session.user.email,
            emailConfirmedAt: session.user.emailConfirmedAt,
            createdAt: session.user.createdAt
        )
    }
}
