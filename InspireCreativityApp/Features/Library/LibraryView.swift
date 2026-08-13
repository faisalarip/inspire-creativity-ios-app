//
//  LibraryView.swift
//  InspireCreativityApp
//
//  v2.0 Library (artboard 09): stats card with streak + weekly activity,
//  continue row, user collections, owned/favorites tabs and .swift export.
//  Sign-out lives in Settings.
//

import SwiftUI

struct LibraryView: View {

    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel: LibraryViewModel

    @State private var showNewCollection = false
    @State private var newCollectionName = ""
    @State private var seenIds: Set<String> = []

    init(viewModel: LibraryViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                NavHeader(title: "Library", isLarge: true, trailing: {
                    IconButton("gearshape.fill") { router.push(.settings) }
                })

                LibraryStatsCard(
                    streak: viewModel.streak,
                    ownedCount: viewModel.owned.count,
                    savedCount: viewModel.favorites.count,
                    isPro: viewModel.isPro,
                    weekBars: viewModel.weekBars,
                    copiesThisWeek: viewModel.copiesThisWeek,
                    onGoPro: { router.push(.paywall(source: "library", animationId: nil)) }
                )
                .padding(.horizontal, Theme.Spacing.xl)

                unlockedRow

                if !viewModel.recentItems.isEmpty {
                    sectionHeader("Pick up where you left off", top: 22)
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(viewModel.recentItems) { item in
                                EngagementMiniCard(item: item, width: 132, previewHeight: 90) {
                                    router.push(.detail(animationId: item.id))
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                    }
                }

                collectionsShelf
                tabBar
                contentGrid

                Spacer().frame(height: 120)
            }
        }
        .onAppear { viewModel.refreshStats() }
        .onReceive(container.seenItemsRepository.idsPublisher) { seenIds = $0 }
        .background(Theme.Palette.background)
        .ignoresSafeArea(edges: .bottom)
        .alert("New collection", isPresented: $showNewCollection) {
            TextField("Name", text: $newCollectionName)
            Button("Create") {
                viewModel.createCollection(named: newCollectionName)
                newCollectionName = ""
            }
            Button("Cancel", role: .cancel) { newCollectionName = "" }
        } message: {
            Text("Group animations for a project or an idea.")
        }
    }

    /// Entry to the Unlocked collection-progress page ("explored X of Y").
    private var unlockedRow: some View {
        Button {
            router.push(.unlocked)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Palette.accent)
                Text("Your unlocked animations")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                if unseenUnlockedCount > 0 {
                    Text("\(unseenUnlockedCount) new")
                        .font(Theme.Typo.mono(11, weight: .semibold))
                        .foregroundStyle(Theme.Palette.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.Palette.accent.opacity(0.14), in: Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Theme.Palette.hairline, lineWidth: 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, 10)
    }

    private var unseenUnlockedCount: Int {
        viewModel.owned.filter { !seenIds.contains($0.id) }.count
    }

    // MARK: - Collections

    private var collectionsShelf: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                Text("Collections")
                    .font(.system(size: 18, weight: .bold))
                    .tracking(-0.4)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                Button("New collection") { showNewCollection = true }
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.Palette.accent)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.Spacing.xxl)
            .padding(.top, 24)
            .padding(.bottom, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(viewModel.collections) { collection in
                        CollectionCard(
                            name: collection.name,
                            items: Array(viewModel.items(for: collection).prefix(4)),
                            totalCount: collection.animationIds.count
                        ) {
                            router.push(.collection(id: collection.id))
                        }
                    }
                    NewCollectionTile { showNewCollection = true }
                }
                .padding(.horizontal, Theme.Spacing.xl)
            }
        }
    }

    // MARK: - Tabs + export

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(LibraryViewModel.Tab.allCases, id: \.self) { tab in
                let active = viewModel.tab == tab
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { viewModel.tab = tab }
                } label: {
                    VStack(spacing: 6) {
                        HStack(spacing: 5) {
                            Text(tab.title)
                                .font(.system(size: 15, weight: .semibold))
                                .tracking(-0.2)
                                .foregroundStyle(active ? .white : .white.opacity(0.5))
                            Text("\(count(for: tab))")
                                .font(.system(size: 12))
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        Rectangle()
                            .fill(active ? Theme.Palette.accent : .clear)
                            .frame(height: 2)
                    }
                    .fixedSize()
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
            }
            Spacer()
            ShareLink(item: viewModel.exportSnippet, preview: SharePreview("InspireCreativityLibrary.swift")) {
                HStack(spacing: 5) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Export .swift")
                        .font(.system(size: 12.5, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.xxl)
    }

    private func count(for tab: LibraryViewModel.Tab) -> Int {
        switch tab {
        case .owned: viewModel.owned.count
        case .favorites: viewModel.favorites.count
        }
    }

    // MARK: - Grid

    @ViewBuilder
    private var contentGrid: some View {
        if viewModel.visibleItems.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "tray")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.4))
                Text("Nothing here yet")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.6))
                Text("Tap the heart on a detail page to save it.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
        } else {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                spacing: 14
            ) {
                ForEach(viewModel.visibleItems) { item in
                    AnimationCard(item) {
                        router.push(.detail(animationId: item.id))
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, 14)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, top: CGFloat) -> some View {
        Text(title)
            .font(.system(size: 18, weight: .bold))
            .tracking(-0.4)
            .foregroundStyle(Theme.Palette.textPrimary)
            .padding(.horizontal, Theme.Spacing.xxl)
            .padding(.top, top)
            .padding(.bottom, 12)
    }
}
