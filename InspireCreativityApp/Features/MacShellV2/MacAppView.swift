//
//  MacAppView.swift
//  InspireCreativityApp
//
//  Root composition for the macOS redesigned shell (MacShellV2): a custom
//  3-pane layout that matches the Claude Design reference (macos-app.jsx):
//  a 52pt top toolbar over a row of [sidebar | center | detail-when-selected].
//  Replaces the old NavigationSplitView `MacRootView`.
//  macOS-only — wrapped in #if os(macOS).
//

#if os(macOS)
import SwiftUI

struct MacAppView: View {

    // MARK: Dependencies

    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var authStore: AuthStore
    // Injected at the scene root; observed so `isPro` / purchase changes
    // re-render the sidebar Pro card and the Owned grid.
    @EnvironmentObject private var store: StoreManager

    // MARK: State

    @State private var nav: MacNav = .discover
    @State private var selectedID: String? = nil
    @State private var query: String = ""
    @State private var showSettings = false
    @State private var showPaywall = false

    /// Stable featured id, chosen once so the Discover hero does not re-roll
    /// (`repository.featured()` returns a random element on every call).
    @State private var featuredID: String? = nil

    var body: some View {
        let liveStore = container.store

        VStack(spacing: 0) {
            MacToolbar(query: $query, onProfile: { showSettings = true })

            HStack(spacing: 0) {
                MacSidebar(
                    container: container,
                    store: liveStore,
                    selection: $nav,
                    onGoPro: { showPaywall = true }
                )

                centerColumn
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let id = selectedID {
                    MacDetailPane(
                        viewModel: container.makeDetailViewModel(animationId: id),
                        onClose: { selectedID = nil }
                    )
                    .environmentObject(container)
                    .environmentObject(authStore)
                    .environmentObject(liveStore)
                    .id(id)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#0a0a0c").ignoresSafeArea())
        .preferredColorScheme(.dark)
        .tint(Theme.Palette.accent)
        .animation(.easeOut(duration: 0.2), value: selectedID)
        .onChange(of: nav) { _, _ in
            // Switching the top-level destination clears the open detail.
            selectedID = nil
        }
        .task {
            // Pin the featured hero exactly once per launch.
            if featuredID == nil {
                featuredID = container.animationRepository.featured().id
            }
            await container.store.syncOnFirstMacLaunchIfNeeded()
        }
        .analyticsConsentGate()
        .sheet(isPresented: $showSettings) {
            SettingsView(
                store: container.store,
                onGoPro: { showSettings = false; showPaywall = true }
            )
            .environmentObject(container)
            .environmentObject(authStore)
            .environmentObject(container.store)
            .frame(minWidth: 520, minHeight: 600)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(viewModel: container.makePaywallViewModel(source: "mac"))
                .environmentObject(container)
                .environmentObject(container.store)
                .frame(minWidth: 520, minHeight: 640)
        }
    }

    // MARK: - Center column

    @ViewBuilder
    private var centerColumn: some View {
        if !trimmedQuery.isEmpty {
            MacSearchResults(
                query: trimmedQuery,
                items: searchResults,
                selectedID: selectedID,
                onOpen: open
            )
        } else {
            switch nav {
            case .discover:
                MacDiscoverView(
                    container: container,
                    selectedID: selectedID,
                    onOpen: open,
                    onNav: { nav = $0; query = "" },
                    featuredID: featuredID
                )
            case .category(let category):
                MacCategoryGridView(
                    title: category.displayName,
                    items: container.animationRepository.items(in: category),
                    selectedID: selectedID,
                    onOpen: open
                )
            case .owned:
                MacCategoryGridView(
                    title: "Owned",
                    items: ownedItems,
                    selectedID: selectedID,
                    onOpen: open
                )
            case .favorites:
                MacCategoryGridView(
                    title: "Favorites",
                    items: favoriteItems,
                    selectedID: selectedID,
                    onOpen: open
                )
            case .recent:
                MacCategoryGridView(
                    title: "Recent",
                    items: recentItems,
                    selectedID: selectedID,
                    onOpen: open
                )
            }
        }
    }

    // MARK: - Actions

    private func open(_ id: String) {
        selectedID = id
    }

    // MARK: - Derived data

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespaces)
    }

    /// Case-insensitive match across name, category, author and description.
    private var searchResults: [AnimationItem] {
        let q = trimmedQuery.lowercased()
        return container.animationRepository.all().filter { item in
            item.name.lowercased().contains(q)
                || item.category.displayName.lowercased().contains(q)
                || item.author.lowercased().contains(q)
                || item.description.lowercased().contains(q)
        }
    }

    private var ownedItems: [AnimationItem] {
        let isPro = store.isPro
        return container.animationRepository.all().filter { $0.isFree || isPro }
    }

    private var favoriteItems: [AnimationItem] {
        container.animationRepository.all()
            .filter { container.favoritesRepository.isFavorite($0.id) }
    }

    private var recentItems: [AnimationItem] {
        Array(container.animationRepository.all().prefix(3))
    }
}
#endif
