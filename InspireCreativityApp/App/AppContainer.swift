//
//  AppContainer.swift
//  InspireCreativityApp
//
//  Lightweight dependency container + view-model factories. Composition
//  root — all concrete deps are instantiated once here and exposed as
//  protocols downstream.
//

import Foundation

/// Composition root. One instance per app launch, kept alive by the App.
@MainActor
final class AppContainer: ObservableObject {

    let animationRepository: AnimationRepositoryProtocol
    let favoritesRepository: FavoritesRepositoryProtocol
    let purchaseRepository: PurchaseRepositoryProtocol
    /// StoreKit 2 entitlement authority. Also vended directly to the paywall
    /// and Settings (for products / restore). `purchaseRepository` is this
    /// same instance behind the protocol.
    let store: StoreManager
    let authStore: AuthStore
    /// Analytics backend, injected into the instrumented view-models and
    /// `AuthStore`. DEBUG echoes to the console; release is a no-op for now
    /// (swapped for the Firebase tracker in a later task).
    let analytics: AnalyticsTracking

    /// Mockups shown in the Discover "Aurora in the wild" row and the
    /// TikTok-style Samples tab. Starts as the bundled 7-item fallback and
    /// is replaced by the full server catalog once `refreshUsageMockups()`
    /// returns. SwiftUI views observe this @Published via @EnvironmentObject.
    @Published private(set) var usageMockups: [UsageMockup] = UsageMockup.fallback

    init(
        animationRepository: AnimationRepositoryProtocol = SupabaseConfig.isConfigured
            ? RemoteAnimationRepository()
            : InMemoryAnimationRepository(),
        favoritesRepository: FavoritesRepositoryProtocol = FavoritesRepository()
    ) {
        let analytics: AnalyticsTracking = {
            #if DEBUG
            return ConsoleAnalyticsTracker()
            #else
            return NoOpAnalyticsTracker()   // replaced by Firebase in a later task
            #endif
        }()
        self.analytics = analytics
        let enabled = UserDefaults.standard.object(forKey: "analyticsEnabled") as? Bool ?? true
        analytics.setCollectionEnabled(enabled)

        let store = StoreManager()
        store.analytics = analytics
        self.store = store
        self.purchaseRepository = store
        self.animationRepository = animationRepository
        self.favoritesRepository = favoritesRepository
        self.authStore = AuthStore(analytics: analytics)

        // Kick off the usage-mockups fetch alongside the animations fetch.
        Task { [weak self] in
            await self?.refreshUsageMockups()
        }
    }

    /// Fetches `/rest/v1/usage_mockups` from Supabase and replaces the
    /// in-memory list on success. No-op when Supabase isn't configured.
    @discardableResult
    func refreshUsageMockups() async -> Bool {
        guard SupabaseConfig.isConfigured else { return false }
        let endpoint = "\(SupabaseConfig.url)/rest/v1/usage_mockups?select=*&order=position.asc"
        guard let url = URL(string: endpoint) else { return false }

        var request = URLRequest(url: url)
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                #if DEBUG
                print("[Supabase] usage_mockups non-2xx, keeping fallback")
                #endif
                return false
            }
            let dtos = try JSONDecoder().decode([UsageMockupDTO].self, from: data)
            let mockups = dtos.map { $0.toUsageMockup() }
            guard !mockups.isEmpty else { return false }
            self.usageMockups = mockups
            return true
        } catch {
            #if DEBUG
            print("[Supabase] usage_mockups fetch failed: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    // MARK: - View-model factories

    func makeDiscoverViewModel() -> DiscoverViewModel {
        DiscoverViewModel(repository: animationRepository)
    }

    func makeBrowseViewModel() -> BrowseViewModel {
        BrowseViewModel(repository: animationRepository, analytics: analytics)
    }

    func makeSearchViewModel() -> SearchViewModel {
        SearchViewModel(repository: animationRepository)
    }

    func makeLibraryViewModel() -> LibraryViewModel {
        LibraryViewModel(
            repository: animationRepository,
            favoritesRepo: favoritesRepository,
            purchases: purchaseRepository
        )
    }

    func makeDetailViewModel(animationId: String) -> DetailViewModel {
        DetailViewModel(
            animationId: animationId,
            repository: animationRepository,
            favorites: favoritesRepository,
            purchases: purchaseRepository,
            analytics: analytics
        )
    }

    func makePaywallViewModel() -> PaywallViewModel {
        PaywallViewModel(store: store)
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: External links — hosted legal pages + support contact
// MARK: ─────────────────────────────────────────────────────────────

/// Hosted resources surfaced in the paywall and Settings. These pages MUST be
/// live and reachable before App Store submission (Guideline 3.1.2 / 5.1.1).
/// Legal pages are hosted free on GitHub Pages (public repo `inspirecreativity-legal`).
/// Swap these for a custom domain later if you register one.
enum AppLinks {
    static let privacyURL = URL(string: "https://faisalarip.github.io/inspirecreativity-legal/privacy/")!
    static let termsURL   = URL(string: "https://faisalarip.github.io/inspirecreativity-legal/terms/")!
    static let supportEmail = "faisalarip10@gmail.com"
    static let supportURL = URL(string: "mailto:faisalarip10@gmail.com")!
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: Supabase integration — server-backed animation catalog
// MARK: ─────────────────────────────────────────────────────────────

/// Configure with your Supabase project. Leave both fields empty to fall
/// back to the bundled seed catalog (no network calls).
///
/// Where to find these:
///   1. Open your project at https://supabase.com/dashboard
///   2. Settings → API
///   3. Copy "Project URL" into `url`
///   4. Copy the "anon" / "public" key into `anonKey`
enum SupabaseConfig {
    static let url     = "https://kuqkeuasncqnbvnipetu.supabase.co"
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt1cWtldWFzbmNxbmJ2bmlwZXR1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk1MzkzOTQsImV4cCI6MjA5NTExNTM5NH0.GiHkjqnEbXps1pUtIS4o3H3AMYPiOrUSAukS7fEHkpc"

    static var isConfigured: Bool {
        !url.isEmpty && !anonKey.isEmpty
    }
}

extension Notification.Name {
    /// Posted on the main queue when the remote catalog has been fetched
    /// and the in-memory cache replaced. View models listen and refresh.
    static let animationsUpdated = Notification.Name("InspireCreativityApp.animationsUpdated")
}

/// JSON row coming out of Supabase REST (`/rest/v1/animations`).
/// Internal (not private) so unit tests can lock the fail-closed mapping.
struct AnimationDTO: Decodable {
    let id: String
    let name: String
    let category: String
    let difficulty: String?
    let ios_version: String?
    let is_pro: Bool?
    let is_featured: Bool?
    let tint_hex: String?
    let author: String
    let handle: String
    let downloads: Int?
    let rating: Double?
    let price: Double?
    let description: String
    let swift_code: String?
    let palette: [String]?
    let engine: String?

    func toAnimationItem() -> AnimationItem? {
        guard let category = Category(rawValue: category) else { return nil }
        let difficulty = Difficulty(rawValue: difficulty ?? "intermediate") ?? .intermediate
        return AnimationItem(
            id: id,
            name: name,
            category: category,
            difficulty: difficulty,
            iosVersion: ios_version ?? "17+",
            // Fail closed: a null is_pro must never give paid content away.
            isPro: is_pro ?? true,
            isFeatured: is_featured ?? false,
            tintHex: tint_hex ?? "#0a0a0c",
            author: author,
            handle: handle,
            downloads: downloads ?? 0,
            rating: rating ?? 5.0,
            price: price,
            description: description,
            swiftCode: resolvedSwiftCode()
        )
    }

    /// Code sample for the row. Prefers the server-supplied `swift_code`; when it
    /// is null but the row carries a palette, generate a palette-true snippet from
    /// the aurora descriptor so the code sheet matches the preview instead of
    /// shipping an empty sheet.
    private func resolvedSwiftCode() -> String {
        if let swift_code, !swift_code.isEmpty { return swift_code }
        if let descriptor = toAuroraDescriptor() {
            return AuroraCodeGen.swiftCode(for: descriptor)
        }
        return ""
    }

    /// If the row supplies a palette (and optionally an engine), produce a
    /// runtime aurora descriptor so the preview registry can render it with
    /// the existing parametric aurora view — no app rebuild needed.
    func toAuroraDescriptor() -> AuroraDescriptor? {
        guard let palette, !palette.isEmpty else { return nil }
        let engineValue: AuroraEngine
        switch engine?.lowercased() {
        case "mesh":    engineValue = .mesh
        case "spin":    engineValue = .spin
        case "bloom":   engineValue = .bloom
        case "streaks": engineValue = .streaks
        case "goo":     engineValue = .goo
        default:        engineValue = .mesh
        }
        return AuroraDescriptor(
            id: id, name: name, theme: category,
            engine: engineValue, palette: palette,
            speed: 12, isPro: is_pro ?? true, price: price,
            use: description, particles: nil
        )
    }
}

/// Animation repository that boots from the bundled seed catalog and, when
/// Supabase is configured, replaces it with the live remote catalog after
/// an async fetch. Posts `.animationsUpdated` when the cache changes so
/// view models can refresh their derived state.
final class RemoteAnimationRepository: AnimationRepositoryProtocol {

    private var cache: [AnimationItem]

    init(seed: [AnimationItem] = AnimationCatalogSeed.items) {
        self.cache = seed
        Task { [weak self] in
            await self?.refresh()
        }
    }

    @discardableResult
    func refresh() async -> Bool {
        guard SupabaseConfig.isConfigured else { return false }
        let endpoint = "\(SupabaseConfig.url)/rest/v1/animations?select=*"
        guard let url = URL(string: endpoint) else { return false }

        var request = URLRequest(url: url)
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                #if DEBUG
                print("[Supabase] non-2xx response, keeping seed cache")
                #endif
                return false
            }
            let dtos = try JSONDecoder().decode([AnimationDTO].self, from: data)
            let items = dtos.compactMap { $0.toAnimationItem() }
            guard !items.isEmpty else { return false }

            // Register parametric previews for any DTOs that included a palette.
            for dto in dtos {
                if let desc = dto.toAuroraDescriptor() {
                    await MainActor.run {
                        AnimationPreviewRegistry.runtimeDescriptors[dto.id] = desc
                    }
                }
            }

            await MainActor.run {
                // Merge with the bundled seed catalog so the app keeps showing the
                // 100+ handcrafted entries (which need compile-time preview views)
                // alongside whatever the server adds. Remote rows win on id collisions.
                var merged: [String: AnimationItem] = [:]
                for s in AnimationCatalogSeed.items { merged[s.id] = s }
                for r in items                       { merged[r.id] = r }
                self.cache = Array(merged.values)
                NotificationCenter.default.post(name: .animationsUpdated, object: nil)
            }
            return true
        } catch {
            #if DEBUG
            print("[Supabase] fetch failed: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    func all() -> [AnimationItem] {
        cache.sorted { $0.downloads > $1.downloads }
    }

    func find(id: String) -> AnimationItem? {
        cache.first { $0.id == id }
    }

    func items(in category: Category?) -> [AnimationItem] {
        guard let category else { return all() }
        return cache.filter { $0.category == category }
    }

    func categories() -> [(category: Category, count: Int)] {
        Category.allCases.compactMap { cat in
            let count = cache.filter { $0.category == cat }.count
            return count > 0 ? (cat, count) : nil
        }
    }

    func search(_ query: String) -> [AnimationItem] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        return cache.filter {
            $0.name.lowercased().contains(q) ||
            $0.category.rawValue.lowercased().contains(q) ||
            $0.author.lowercased().contains(q)
        }
    }

    func featured() -> AnimationItem {
        cache.randomElement()
            ?? AnimationCatalogSeed.items.randomElement()
            ?? AnimationCatalogSeed.items[0]
    }

    func trending() -> [AnimationItem] {
        CuratedRows.trending(from: cache)
    }

    func newlyAdded() -> [AnimationItem] {
        CuratedRows.newlyAdded(from: cache)
    }
}

/// JSON row coming out of Supabase REST (`/rest/v1/usage_mockups`).
private struct UsageMockupDTO: Decodable {
    let id: String
    let title: String
    let app_name: String
    let aurora_id: String
    let context: String?
    let why: String
    let swift_code: String?
    let position: Int?

    func toUsageMockup() -> UsageMockup {
        UsageMockup(
            id: id,
            title: title,
            appName: app_name,
            animationId: aurora_id,
            why: why,
            layout: UsageMockup.layout(forId: id),
            swiftCode: swift_code
        )
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: Supabase Auth — domain, service, store
// MARK: ─────────────────────────────────────────────────────────────

/// Authenticated user. Mirrors the `user` object Supabase returns from
/// `/auth/v1/*`. Snake-case JSON keys are mapped via the decoder's
/// `convertFromSnakeCase` strategy.
struct AuthUser: Codable, Equatable {
    let id: String
    let email: String?
    let emailConfirmedAt: Date?
    let createdAt: Date?
}

/// One signed-in session. Persisted to `UserDefaults` so the app boots
/// straight into the signed-in state after relaunch.
struct AuthSession: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let user: AuthUser
}

/// Result of `AuthService.signUp`. Either the project has email-confirm off
/// (we get a session immediately) or it's on (Supabase returns a user with
/// `confirmation_sent_at` but no session — we route the UI to "check your
/// email").
enum SignUpResult {
    case session(AuthSession)
    case confirmationRequired
}

/// Friendly, presentation-ready auth errors. The `errorDescription` is what
/// the UI surfaces in the error banner.
enum AuthError: LocalizedError, Equatable {
    case invalidCredentials
    case emailNotConfirmed
    case emailAlreadyRegistered
    case weakPassword(String)
    case network(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password. Please try again."
        case .emailNotConfirmed:
            return "Please verify your email first. Check your inbox for the link."
        case .emailAlreadyRegistered:
            return "An account with this email already exists. Try signing in."
        case .weakPassword(let detail):
            return detail
        case .network(let detail):
            return detail
        case .unknown(let detail):
            return detail
        }
    }
}

/// Shape of Supabase's `gotrue` error responses. The relevant text lives in
/// `error_description` (token endpoint) or `msg` (signup endpoint).
private struct SupabaseAuthErrorBody: Decodable {
    let error: String?
    let errorCode: String?
    let errorDescription: String?
    let msg: String?
    let code: Int?
}

/// `confirmation_sent_at`-bearing user payload returned by `/auth/v1/signup`
/// when email-confirm is on. Decoded with `convertFromSnakeCase` so this is
/// just `confirmationSentAt`.
private struct SignUpUserEnvelope: Decodable {
    let id: String?
    let email: String?
    let confirmationSentAt: Date?
    let emailConfirmedAt: Date?
    let createdAt: Date?
}

/// Token-response envelope returned by `/auth/v1/token` and by `/auth/v1/signup`
/// when email-confirm is off.
private struct TokenEnvelope: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Double?
    let tokenType: String?
    let user: AuthUser?
}

/// Stateless wrapper around Supabase's `gotrue` HTTP API. All methods are
/// `async throws` and use `URLSession.shared` with the same header pattern as
/// `RemoteAnimationRepository`.
enum AuthService {

    private static var baseURL: String { SupabaseConfig.url }
    private static var anonKey: String { SupabaseConfig.anonKey }

    /// Injectable URLSession. Production uses `.shared`; unit tests swap in a
    /// session backed by a `URLProtocol` mock so HTTP can be stubbed
    /// deterministically (see `MockURLProtocol` in the test target).
    static var session: URLSession = .shared

    /// Shared decoder. Supabase returns ISO-8601 timestamps with fractional
    /// seconds (e.g. `2024-01-15T10:30:00.123456Z`), so we use a custom
    /// strategy that accepts both fractional and second-precision forms.
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let isoFractional = ISO8601DateFormatter()
            isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFractional.date(from: string) { return date }
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]
            if let date = iso.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unparseable date: \(string)"
            )
        }
        return d
    }()

    /// Creates a `URLRequest` aimed at `/auth/v1/<path>` with the mandatory
    /// `apikey` + `Content-Type: application/json` headers attached.
    private static func makeRequest(
        path: String,
        method: String,
        body: [String: Any]? = nil,
        bearer: String? = nil
    ) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/auth/v1\(path)") else {
            throw AuthError.unknown("Bad auth URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let bearer {
            request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        }
        request.timeoutInterval = 20
        return request
    }

    /// Sends `request`, returns `(data, http)` on a 2xx and throws a mapped
    /// `AuthError` otherwise. Centralizes all the gotrue error-payload
    /// mapping so call sites read clean.
    private static func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AuthError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw AuthError.unknown("Bad response")
        }
        if (200..<300).contains(http.statusCode) {
            return (data, http)
        }
        // Try to decode gotrue's error body and map to a typed error.
        let body = try? decoder.decode(SupabaseAuthErrorBody.self, from: data)
        let message = body?.errorDescription
            ?? body?.msg
            ?? body?.error
            ?? "Request failed (\(http.statusCode))"
        let lower = message.lowercased()
        if lower.contains("not confirmed") || lower.contains("email not confirmed") {
            throw AuthError.emailNotConfirmed
        }
        if lower.contains("invalid login") || lower.contains("invalid credentials") {
            throw AuthError.invalidCredentials
        }
        if lower.contains("already registered") || lower.contains("user already") {
            throw AuthError.emailAlreadyRegistered
        }
        if lower.contains("password") && (lower.contains("short") || lower.contains("weak") || lower.contains("6 characters")) {
            throw AuthError.weakPassword(message)
        }
        if http.statusCode == 401 {
            throw AuthError.invalidCredentials
        }
        throw AuthError.unknown(message)
    }

    /// Creates an account. If email-confirm is **off**, returns `.session(_)`
    /// with a usable session. If email-confirm is **on**, Supabase returns
    /// 200 with `confirmation_sent_at` but no token — we surface that as
    /// `.confirmationRequired` so the UI can route to "check your email".
    static func signUp(
        email: String,
        password: String,
        firstName: String = "",
        lastName: String = ""
    ) async throws -> SignUpResult {
        var body: [String: Any] = ["email": email, "password": password]
        // Pass first/last name as Supabase user metadata (`data` → user_metadata).
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedFirst.isEmpty || !trimmedLast.isEmpty {
            let fullName = [trimmedFirst, trimmedLast]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            body["data"] = [
                "first_name": trimmedFirst,
                "last_name": trimmedLast,
                "full_name": fullName
            ]
        }
        let request = try makeRequest(
            path: "/signup",
            method: "POST",
            body: body
        )
        let (data, _) = try await send(request)

        // First try the token envelope (email-confirm off case).
        if let token = try? decoder.decode(TokenEnvelope.self, from: data),
           let access = token.accessToken,
           let refresh = token.refreshToken,
           let user = token.user {
            let expiresAt = Date().addingTimeInterval(token.expiresIn ?? 3600)
            return .session(AuthSession(
                accessToken: access,
                refreshToken: refresh,
                expiresAt: expiresAt,
                user: user
            ))
        }

        // Otherwise it's the "confirmation required" shape.
        if let envelope = try? decoder.decode(SignUpUserEnvelope.self, from: data),
           envelope.confirmationSentAt != nil || envelope.id != nil {
            return .confirmationRequired
        }

        // If we can't decode either shape but the HTTP code was 2xx, assume
        // confirmation flow is in play (safest user-facing default).
        return .confirmationRequired
    }

    /// Signs an existing user in. Throws `.emailNotConfirmed` when Supabase
    /// returns the corresponding 400, `.invalidCredentials` otherwise.
    static func signIn(email: String, password: String) async throws -> AuthSession {
        let request = try makeRequest(
            path: "/token?grant_type=password",
            method: "POST",
            body: ["email": email, "password": password]
        )
        let (data, _) = try await send(request)
        let token = try decoder.decode(TokenEnvelope.self, from: data)
        guard let access = token.accessToken,
              let refresh = token.refreshToken,
              let user = token.user else {
            throw AuthError.unknown("Malformed token response")
        }
        let expiresAt = Date().addingTimeInterval(token.expiresIn ?? 3600)
        return AuthSession(
            accessToken: access,
            refreshToken: refresh,
            expiresAt: expiresAt,
            user: user
        )
    }

    /// Revokes the current session on the server. Best-effort — if the call
    /// fails, callers still clear the local session.
    static func signOut(session: AuthSession) async throws {
        let request = try makeRequest(
            path: "/logout",
            method: "POST",
            bearer: session.accessToken
        )
        _ = try await send(request)
    }

    /// Sends a password-reset email via Supabase's `/auth/v1/recover`. The
    /// `redirect_to` points at our hosted reset page, which consumes the
    /// recovery token from the link and lets the user set a new password.
    /// NOTE: this URL must be in Supabase → Auth → URL Configuration →
    /// Redirect URLs, or gotrue ignores it and falls back to the Site URL.
    static func requestPasswordReset(email: String) async throws {
        let redirect = "https://faisalarip.github.io/inspirecreativity-legal/reset/"
        let encoded = redirect.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? redirect
        let request = try makeRequest(
            path: "/recover?redirect_to=\(encoded)",
            method: "POST",
            body: ["email": email]
        )
        _ = try await send(request)
    }

    /// Asks Supabase to resend the signup confirmation email.
    static func resendConfirmation(email: String) async throws {
        let request = try makeRequest(
            path: "/resend",
            method: "POST",
            body: ["type": "signup", "email": email]
        )
        _ = try await send(request)
    }

    /// Validates a session by fetching the current user. We use this on
    /// launch to detect tokens that have been revoked or expired.
    static func currentUser(accessToken: String) async throws -> AuthUser {
        let request = try makeRequest(
            path: "/user",
            method: "GET",
            bearer: accessToken
        )
        let (data, _) = try await send(request)
        return try decoder.decode(AuthUser.self, from: data)
    }

    /// Permanently deletes the signed-in user's account. Calls the
    /// `delete-account` Supabase Edge Function, which verifies the caller's JWT
    /// and uses the service role to delete the gotrue user + associated data.
    /// Required by App Store Guideline 5.1.1(v) for apps that create accounts.
    static func deleteAccount(accessToken: String) async throws {
        guard let url = URL(string: "\(baseURL)/functions/v1/delete-account") else {
            throw AuthError.unknown("Bad delete-account URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        _ = try await send(request)
    }
}

/// Observable auth state. Single source of truth for "is the user signed in"
/// and "what's their pending email-verification flow." Persists the session
/// to `UserDefaults` so the app boots into the signed-in state.
@MainActor
final class AuthStore: ObservableObject {

    /// Currently signed-in session, if any. `nil` means "show the auth gate."
    @Published private(set) var session: AuthSession?
    /// True while a signUp / signIn / signOut / resend call is in flight.
    @Published var isLoading: Bool = false
    /// Most recent failure. UI binds this to the error banner.
    @Published var lastError: AuthError?
    /// When signup returned `.confirmationRequired` we stash the email here
    /// so the verify-email screen can show it and the resend button works.
    @Published private(set) var pendingVerificationEmail: String?
    /// Set true exactly when a fresh sign-in / sign-up succeeds (NOT on session
    /// restore at launch), so the UI can show a one-time welcome. The view
    /// resets it to false once shown.
    @Published var justSignedIn: Bool = false

    private static let defaultsKey = "enigma.auth.session"
    private let defaults: UserDefaults
    private let analytics: AnalyticsTracking

    /// supabase-swift-backed engine for the two social flows. Lazily built so
    /// the SDK `SupabaseClient` is only constructed when a social button is
    /// actually tapped — email auth never touches it. Injectable for tests.
    private let socialAuth: () -> SocialAuthServicing
    private lazy var socialAuthService: SocialAuthServicing = socialAuth()

    var isAuthenticated: Bool { session != nil }

    init(
        defaults: UserDefaults = .standard,
        socialAuth: @escaping () -> SocialAuthServicing = { SocialAuthService() },
        analytics: AnalyticsTracking = NoOpAnalyticsTracker()
    ) {
        self.defaults = defaults
        self.socialAuth = socialAuth
        self.analytics = analytics
        if let data = defaults.data(forKey: Self.defaultsKey) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let restored = try? decoder.decode(AuthSession.self, from: data) {
                self.session = restored
                // Background-validate: if the access token has been revoked
                // we want to drop the persisted session so we don't show a
                // stale signed-in state.
                Task { [weak self] in
                    await self?.validateRestoredSession()
                }
            }
        }
    }

    /// Validates the restored session against `/auth/v1/user`. On failure we
    /// clear local state so the gate shows up.
    private func validateRestoredSession() async {
        guard let session else { return }
        do {
            _ = try await AuthService.currentUser(accessToken: session.accessToken)
        } catch AuthError.invalidCredentials {
            clearSession()
        } catch {
            // Network errors leave the cached session intact — the user can
            // still browse what they had until they explicitly retry.
        }
    }

    /// Signs the user up. On `.session(_)` we persist and clear the gate; on
    /// `.confirmationRequired` we stash the email for the verify screen.
    func signUp(email: String, password: String, firstName: String = "", lastName: String = "") async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            let result = try await AuthService.signUp(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName
            )
            switch result {
            case .session(let session):
                persist(session)
                pendingVerificationEmail = nil
                justSignedIn = true
            case .confirmationRequired:
                pendingVerificationEmail = email
            }
        } catch let error as AuthError {
            lastError = error
        } catch {
            lastError = .unknown(error.localizedDescription)
        }
    }

    /// Signs the user in and persists the resulting session.
    func signIn(email: String, password: String) async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            let session = try await AuthService.signIn(email: email, password: password)
            persist(session)
            pendingVerificationEmail = nil
            justSignedIn = true
            analytics.log(.signIn(method: "email"))
        } catch let error as AuthError {
            lastError = error
        } catch {
            lastError = .unknown(error.localizedDescription)
        }
    }

    /// Signs in via Sign in with Apple. `idToken` is the JWT extracted from the
    /// `ASAuthorizationAppleIDCredential`; `nonce` is the *raw* (unhashed)
    /// nonce whose SHA-256 was attached to the authorization request — Supabase
    /// needs the raw value to validate the hash embedded in the token. Mirrors
    /// the email `signIn` shape: persists on success, surfaces typed errors.
    func signInWithApple(idToken: String, nonce: String) async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            let session = try await socialAuthService.signInWithApple(idToken: idToken, nonce: nonce)
            persist(session)
            pendingVerificationEmail = nil
            justSignedIn = true
            analytics.log(.signIn(method: "apple"))
        } catch let error as AuthError {
            lastError = error
        } catch {
            lastError = .network(error.localizedDescription)
        }
    }

    /// Signs in via Google web OAuth (ASWebAuthenticationSession-backed inside
    /// the SDK). Mirrors the email `signIn` shape. User cancellation surfaces
    /// as a thrown error from the SDK; we map it to `.network` like any other
    /// failure (the UI simply shows the banner — there's no special-casing of
    /// cancel here because there's no token to act on).
    func signInWithGoogle() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            let session = try await socialAuthService.signInWithGoogle()
            persist(session)
            pendingVerificationEmail = nil
            justSignedIn = true
            analytics.log(.signIn(method: "google"))
        } catch let error as AuthError {
            lastError = error
        } catch {
            lastError = .network(error.localizedDescription)
        }
    }

    /// Signs the user out. We always clear the local session — even if the
    /// network call fails — so the user is never stuck in a half-signed-out
    /// state.
    func signOut() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        if let session {
            do {
                try await AuthService.signOut(session: session)
            } catch {
                // Intentional: continue clearing local state.
            }
        }
        clearSession()
    }

    /// Permanently deletes the user's account, then clears local state.
    /// Returns true on success. Surfaces failures via `lastError`.
    @discardableResult
    func deleteAccount() async -> Bool {
        guard let session else { return false }
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            try await AuthService.deleteAccount(accessToken: session.accessToken)
            clearSession()
            return true
        } catch let error as AuthError {
            lastError = error
            return false
        } catch {
            lastError = .unknown(error.localizedDescription)
            return false
        }
    }

    /// Re-sends the verification email for the pending email.
    func resendVerification() async {
        guard let email = pendingVerificationEmail else { return }
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            try await AuthService.resendConfirmation(email: email)
        } catch let error as AuthError {
            lastError = error
        } catch {
            lastError = .unknown(error.localizedDescription)
        }
    }

    /// Sends a password-reset email. Surfaces failures via `lastError`.
    /// Returns true when the request was accepted.
    @discardableResult
    func sendPasswordReset(email: String) async -> Bool {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            try await AuthService.requestPasswordReset(email: email)
            return true
        } catch let error as AuthError {
            lastError = error
            return false
        } catch {
            lastError = .unknown(error.localizedDescription)
            return false
        }
    }

    /// Clears the in-flight verification flow (used by the "back to sign in"
    /// button on the verify screen).
    func dismissPendingVerification() {
        pendingVerificationEmail = nil
    }

    /// Clears the in-memory error (used when the user starts editing again).
    func clearError() {
        lastError = nil
    }

    // MARK: - Persistence

    private func persist(_ session: AuthSession) {
        self.session = session
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(session) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }

    private func clearSession() {
        session = nil
        defaults.removeObject(forKey: Self.defaultsKey)
    }
}
