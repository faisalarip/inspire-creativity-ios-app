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
    }

    private var orderedCategories: [Category] {
        browse.categories.map(\.category)
    }

    private var visibleItems: [AnimationItem] {
        switch selection {
        case .discover:
            return container.animationRepository.all()
        case .category(let cat):
            return container.animationRepository.items(in: cat)
        case .owned, .favorites, .recent:
            let all = container.animationRepository.all()
            switch selection {
            case .owned:
                return all.filter { $0.isFree || container.store.isPro }
            case .favorites:
                return all.filter { container.favoritesRepository.isFavorite($0.id) }
            default:
                return Array(all.prefix(3))
            }
        }
    }
}
#endif
