//
//  DetailViewModel.swift
//  InspireCreativityApp
//

import Foundation
import Combine

/// Two-way access decision for the code sheet. Pure logic so the gate is
/// unit-testable. Purchasing never requires an account: a Pro entitlement
/// unlocks code in ANY auth state (a signed-out buyer or Restore must never
/// stay locked out), Pro items route to the paywall — and FREE code is open
/// to everyone. Copying free code is the activation moment (the analytics
/// showed a sign-in wall here cut ~77% of users off before first value).
enum CodeAccess: Equatable {
    case granted
    case needsPro

    static func evaluate(itemIsPro: Bool,
                         hasProEntitlement: Bool) -> CodeAccess {
        if hasProEntitlement { return .granted }
        return itemIsPro ? .needsPro : .granted
    }
}

@MainActor
final class DetailViewModel: ObservableObject {

    let item: AnimationItem
    @Published private(set) var isFavorited: Bool

    /// SwiftUI source for the code sheet, resolved on demand. Aurora catalog
    /// items ship with an empty `swiftCode` (generation is deferred off the
    /// launch path), so regenerate it the first time it's needed from the
    /// item's descriptor. Computed once, then cached.
    lazy var code: String = {
        if !item.swiftCode.isEmpty { return item.swiftCode }
        if let descriptor = AuroraDescriptors.byId[item.id]
            ?? AnimationPreviewRegistry.runtimeDescriptors[item.id] {
            return AuroraCodeGen.swiftCode(for: descriptor)
        }
        return item.swiftCode
    }()
    @Published private(set) var isOwned: Bool
    /// True when the Pro entitlement is active (StoreKit-derived), regardless
    /// of the signed-in state. Feeds `CodeAccess.evaluate`.
    @Published private(set) var hasPro: Bool

    private let favorites: FavoritesRepositoryProtocol
    private let purchases: PurchaseRepositoryProtocol
    private let analytics: AnalyticsTracking
    private let journeyMetrics: JourneyMetrics
    /// Optional engagement hooks (nil in previews/tests that don't care).
    private let recents: RecentItemsRepositoryProtocol?
    private let copyActivity: CopyActivityStore?
    private var cancellables: Set<AnyCancellable> = []
    /// Guards `markViewed()` so the view event fires once per real
    /// presentation, not once per view-model instance that happens to be
    /// constructed. See `markViewed()` for why this can't live in `init`.
    private var hasLoggedView = false

    init(
        animationId: String,
        repository: AnimationRepositoryProtocol,
        favorites: FavoritesRepositoryProtocol,
        purchases: PurchaseRepositoryProtocol,
        analytics: AnalyticsTracking = NoOpAnalyticsTracker(),
        journeyMetrics: JourneyMetrics = JourneyMetrics(),
        recents: RecentItemsRepositoryProtocol? = nil,
        copyActivity: CopyActivityStore? = nil
    ) {
        // Resolve the item once (fall back to featured for unknown ids), assign
        // stored props, then wire bindings unconditionally so the detail screen
        // always reflects later favorite / entitlement changes.
        let resolved = repository.find(id: animationId) ?? repository.featured()
        self.item = resolved
        self.favorites = favorites
        self.purchases = purchases
        self.analytics = analytics
        self.journeyMetrics = journeyMetrics
        self.recents = recents
        self.copyActivity = copyActivity
        self.isFavorited = favorites.isFavorite(resolved.id)
        self.isOwned = purchases.isOwned(resolved.id, freeOverride: resolved.isFree)
        self.hasPro = purchases.isPro
        bind()
    }

    private func bind() {
        let id = item.id
        let isFree = item.isFree

        favorites.idsPublisher
            .map { $0.contains(id) }
            .receive(on: DispatchQueue.main)
            .assign(to: &$isFavorited)

        purchases.isProPublisher
            .map { isPro in isFree || isPro }
            .receive(on: DispatchQueue.main)
            .assign(to: &$isOwned)

        purchases.isProPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$hasPro)
    }

    /// Logs the animation view + records it for journey metrics, exactly once per
    /// view-model instance. Called from the view's .onAppear rather than init so it
    /// fires once per real presentation — not on every parent re-render that eagerly
    /// reconstructs a throwaway view model (see MacAppView).
    func markViewed() {
        guard !hasLoggedView else { return }
        hasLoggedView = true
        analytics.log(.animationView(id: item.id, category: item.category.rawValue, isPro: item.isPro))
        journeyMetrics.recordAnimationView()
        recents?.record(item.id)
    }

    func toggleFavorite() {
        favorites.toggle(item.id)
        // Log the RESULTING state from the repository's synchronous source of
        // truth. `isFavorited` is updated asynchronously via `idsPublisher`, so
        // it still holds the stale pre-toggle value at this point.
        analytics.log(.favoriteToggled(id: item.id, on: favorites.isFavorite(item.id)))
        if favorites.isFavorite(item.id) { journeyMetrics.recordFavorite() }
    }

    /// Logs a code-copy from the leaf `CodeSheet` via an injected closure, so
    /// the view itself never holds the analytics dependency or the item id.
    func logCodeCopied() {
        analytics.log(.codeCopied(id: item.id))
        copyActivity?.recordCopy()
    }

    /// Logs the code-unlock intent from the leaf view's CTA. Granted access
    /// never reaches the lock CTA, so it is intentionally a no-op.
    func logCodeUnlockAttempt(_ access: CodeAccess) {
        let result: String
        switch access {
        case .needsPro: result = "needs_pro"
        case .granted:  return
        }
        analytics.log(.codeUnlockAttempt(result: result,
                                         animationID: item.id,
                                         category: item.category.rawValue,
                                         isPro: item.isPro))
        journeyMetrics.recordCodeUnlockAttempt(result: access)
    }
}
