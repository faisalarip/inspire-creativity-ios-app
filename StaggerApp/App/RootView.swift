//
//  RootView.swift
//  StaggerApp
//
//  Top-level shell. Custom floating tab bar (matches prototype's
//  blurred dark style) layered above the per-tab NavigationStacks.
//

import SwiftUI

struct RootView: View {

    @EnvironmentObject private var container: AppContainer
    @StateObject private var router = AppRouter()

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.Palette.background.ignoresSafeArea()

            ZStack {
                tabContent(.discover).opacity(router.selectedTab == .discover ? 1 : 0)
                tabContent(.browse).opacity(router.selectedTab == .browse ? 1 : 0)
                tabContent(.search).opacity(router.selectedTab == .search ? 1 : 0)
                tabContent(.library).opacity(router.selectedTab == .library ? 1 : 0)
            }
            .animation(.easeOut(duration: 0.15), value: router.selectedTab)

            if !router.hidesTabBar {
                FloatingTabBar(selected: $router.selectedTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .environmentObject(router)
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: router.hidesTabBar)
    }

    @ViewBuilder
    private func tabContent(_ tab: AppTab) -> some View {
        NavigationStack(path: router.path(for: tab)) {
            tabRoot(tab)
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .detail(let id):
                        DetailView(viewModel: container.makeDetailViewModel(animationId: id))
                            .toolbar(.hidden, for: .navigationBar)
                    case .paywall:
                        PaywallView(viewModel: container.makePaywallViewModel())
                            .toolbar(.hidden, for: .navigationBar)
                    }
                }
        }
    }

    @ViewBuilder
    private func tabRoot(_ tab: AppTab) -> some View {
        switch tab {
        case .discover: DiscoverView(viewModel: container.makeDiscoverViewModel())
        case .browse:   BrowseView(viewModel: container.makeBrowseViewModel())
        case .search:   SearchView(viewModel: container.makeSearchViewModel())
        case .library:  LibraryView(viewModel: container.makeLibraryViewModel())
        }
    }
}
