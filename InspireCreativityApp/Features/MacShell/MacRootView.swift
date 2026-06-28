//
//  MacRootView.swift
//  InspireCreativityApp
//
//  macOS NavigationSplitView shell: sidebar sections, searchable card grid,
//  and a detail column placeholder (full detail pane arrives in Task 9).
//

#if os(macOS)
import SwiftUI

struct MacRootView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var browse: BrowseViewModel
    @State private var selection: MacSidebarSection = .discover
    @State private var selectedItemID: AnimationItem.ID?
    @State private var search = ""
    @State private var showSettings = false
    @State private var showPaywall = false

    init(container: AppContainer) {
        _browse = StateObject(wrappedValue: container.makeBrowseViewModel())
    }

    var body: some View {
        NavigationSplitView {
            List(MacSidebarSection.all(categories: orderedCategories), selection: $selection) { section in
                Text(section.title).tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210)
        } content: {
            MacCatalogList(items: visibleItems, selectedItemID: $selectedItemID, search: $search)
                .navigationSplitViewColumnWidth(min: 320, ideal: 420)
        } detail: {
            if let id = selectedItemID {
                MacDetailView(viewModel: container.makeDetailViewModel(animationId: id))
                    .id(id)
            } else {
                ContentUnavailableView("Select an animation", systemImage: "sparkles")
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: search) { _, q in browse.searchText = q }
        .onChange(of: selection) { _, _ in selectedItemID = nil }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showSettings = true } label: { Image(systemName: "person.crop.circle") }
                    .help("Account & Settings")
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(store: container.store, onGoPro: { showSettings = false; showPaywall = true })
                .environmentObject(container)
                .environmentObject(container.authStore)
                .environmentObject(container.store)
                .frame(minWidth: 520, minHeight: 600)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(viewModel: container.makePaywallViewModel(source: "settings"))
                .environmentObject(container)
                .environmentObject(container.store)
                .frame(minWidth: 520, minHeight: 640)
        }
    }

    private var orderedCategories: [Category] {
        browse.categories.map(\.category)
    }

    private var visibleItems: [AnimationItem] {
        let base: [AnimationItem]
        switch selection {
        case .discover:
            base = container.animationRepository.all()
        case .category(let cat):
            base = container.animationRepository.items(in: cat)
        case .owned, .favorites, .recent:
            let all = container.animationRepository.all()
            switch selection {
            case .owned:
                base = all.filter { $0.isFree || container.store.isPro }
            case .favorites:
                base = all.filter { container.favoritesRepository.isFavorite($0.id) }
            default:
                base = Array(all.prefix(3))
            }
        }
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return base }
        return base.filter {
            $0.name.lowercased().contains(q) ||
            $0.category.rawValue.lowercased().contains(q) ||
            $0.author.lowercased().contains(q)
        }
    }
}
#endif
