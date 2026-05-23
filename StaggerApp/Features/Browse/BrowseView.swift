//
//  BrowseView.swift
//  StaggerApp
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
                NavHeader(title: "Browse", isLarge: true)
                    .padding(.bottom, 4)

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
                    Text("\(viewModel.visibleItems.count) results")
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

                Spacer().frame(height: 120)
            }
        }
        .background(Theme.Palette.background)
        .ignoresSafeArea(edges: .bottom)
    }
}
