//
//  AppContainer.swift
//  StaggerApp
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

    init(
        animationRepository: AnimationRepositoryProtocol = SupabaseConfig.isConfigured
            ? RemoteAnimationRepository()
            : InMemoryAnimationRepository(),
        favoritesRepository: FavoritesRepositoryProtocol = FavoritesRepository(),
        purchaseRepository: PurchaseRepositoryProtocol = PurchaseRepository()
    ) {
        self.animationRepository = animationRepository
        self.favoritesRepository = favoritesRepository
        self.purchaseRepository = purchaseRepository
    }

    // MARK: - View-model factories

    func makeDiscoverViewModel() -> DiscoverViewModel {
        DiscoverViewModel(repository: animationRepository)
    }

    func makeBrowseViewModel() -> BrowseViewModel {
        BrowseViewModel(repository: animationRepository)
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
            purchases: purchaseRepository
        )
    }

    func makePaywallViewModel() -> PaywallViewModel {
        PaywallViewModel(purchases: purchaseRepository)
    }
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
    static let url     = ""   // e.g. "https://abcd1234.supabase.co"
    static let anonKey = ""   // public anon key

    static var isConfigured: Bool {
        !url.isEmpty && !anonKey.isEmpty
    }
}

extension Notification.Name {
    /// Posted on the main queue when the remote catalog has been fetched
    /// and the in-memory cache replaced. View models listen and refresh.
    static let animationsUpdated = Notification.Name("StaggerApp.animationsUpdated")
}

/// JSON row coming out of Supabase REST (`/rest/v1/animations`).
private struct AnimationDTO: Decodable {
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
            isPro: is_pro ?? false,
            isFeatured: is_featured ?? false,
            tintHex: tint_hex ?? "#0a0a0c",
            author: author,
            handle: handle,
            downloads: downloads ?? 0,
            rating: rating ?? 5.0,
            price: price,
            description: description,
            swiftCode: swift_code ?? ""
        )
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
            speed: 12, isPro: is_pro ?? false, price: price,
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
                self.cache = items
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
        cache.first(where: { $0.isFeatured })
            ?? cache.first
            ?? AnimationCatalogSeed.items[0]
    }

    func trending() -> [AnimationItem] {
        ["liquid-heart", "hologram-card", "elastic-tabs", "morphing-fab", "aurora-mesh"]
            .compactMap(find(id:))
    }

    func newlyAdded() -> [AnimationItem] {
        ["parallax-card", "glitch-text", "spring-chain", "liquid-tabs"]
            .compactMap(find(id:))
    }
}
