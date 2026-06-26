//
//  BrowseView.swift
//  InspireCreativityApp
//

import SwiftUI

struct BrowseView: View {

    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel: BrowseViewModel

    init(viewModel: BrowseViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Compact header (no large-title block)
                HStack {
                    Text("Browse")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.xxl)
                .padding(.top, 8)
                .padding(.bottom, 12)

                // Search field (replaces the dedicated Search tab)
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                    TextField("", text: $viewModel.searchText,
                              prompt: Text("Search animations, authors…")
                                .foregroundColor(.white.opacity(0.4)))
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                    if !viewModel.searchText.isEmpty {
                        Button { viewModel.searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                )
                .padding(.horizontal, Theme.Spacing.xxl)
                .padding(.bottom, 12)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Chip("All",
                             count: viewModel.totalCount,
                             isActive: viewModel.selectedCategory == nil) {
                            viewModel.selectedCategory = nil
                        }
                        ForEach(viewModel.categories, id: \.category.id) { entry in
                            Chip(entry.category.displayName,
                                 count: entry.count,
                                 isActive: viewModel.selectedCategory == entry.category) {
                                viewModel.selectedCategory = entry.category
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                }

                HStack {
                    Text("\(viewModel.resultCount) results")
                        .font(Theme.Typo.mono(13))
                        .foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    Button { viewModel.toggleSort() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease")
                                .font(.system(size: 12))
                            Text(viewModel.sortOrder.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Theme.Spacing.xxl)
                .padding(.vertical, 12)

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

                // Reveal the next page as the user nears the end of the grid.
                // A visible button is kept as an explicit, accessible fallback.
                if viewModel.canLoadMore {
                    Button {
                        viewModel.loadMore()
                    } label: {
                        HStack(spacing: 6) {
                            Text("Load more")
                                .font(.system(size: 14, weight: .semibold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.06), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, Theme.Spacing.xxl)
                    .padding(.top, 16)
                    .onAppear { viewModel.loadMore() }
                }

                Spacer().frame(height: 120)
            }
        }
        .refreshable {
            await viewModel.reload()
        }
        // Apply a category drilled-in from Discover. Uses onChange, not
        // onAppear: RootView keeps all four tabs mounted in an opacity ZStack,
        // so onAppear fires once at launch and never on tab switch.
        .onChange(of: router.pendingBrowseCategory) { _, newValue in
            guard newValue != nil, let category = router.takePendingBrowseCategory() else { return }
            viewModel.selectedCategory = category
        }
        .background(Theme.Palette.background)
        .ignoresSafeArea(edges: .bottom)
    }
}
