//
//  BrowseView.swift
//  InspireCreativityApp
//
//  v2.0 category-first browse (artboard 06): overview with visual category
//  cards, aurora theme moods and a popular grid; drill-in with sort chips
//  and show-more paging. Search moved to its own tab — the pill just jumps
//  there.
//

import SwiftUI

struct BrowseView: View {

    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel: BrowseViewModel

    private let gridColumns = [
        GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14),
    ]

    init(viewModel: BrowseViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                searchPill

                if viewModel.scope == .overview {
                    overview
                } else {
                    drill
                }

                Spacer().frame(height: 120)
            }
        }
        .refreshable { await viewModel.reload() }
        // Apply a category drilled-in from Discover. Uses onChange, not
        // onAppear: RootView keeps all tabs mounted in an opacity ZStack,
        // so onAppear fires once at launch and never on tab switch.
        .onChange(of: router.pendingBrowseCategory) { _, newValue in
            guard newValue != nil, let category = router.takePendingBrowseCategory() else { return }
            viewModel.scope = .category(category)
        }
        .background(Theme.Palette.background)
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Header + search pill

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Browse")
                .font(.system(size: 32, weight: .heavy))
                .tracking(-1)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("\(viewModel.totalCount) animations · \(viewModel.categories.count) categories · new every Friday")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .padding(.horizontal, Theme.Spacing.xxl)
        .padding(.top, 8)
    }

    private var searchPill: some View {
        Button {
            router.selectedTab = .search
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Text("Search animations, themes, authors…")
                    .font(.system(size: 14))
                    .tracking(-0.1)
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, 14)
    }

    // MARK: - Overview

    @ViewBuilder
    private var overview: some View {
        sectionHeader("Categories", top: 22)

        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            ForEach(viewModel.categories, id: \.category.id) { entry in
                CategoryCard(
                    category: entry.category,
                    count: entry.count,
                    representative: viewModel.representativeItem(for: entry.category),
                    isNew: entry.category == .backgrounds
                ) {
                    viewModel.scope = .category(entry.category)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)

        if !viewModel.themes.isEmpty {
            sectionHeader("Aurora themes", caption: "\(viewModel.themes.count) moods", top: 24)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.themes, id: \.name) { theme in
                        Chip(theme.name, count: theme.count) {
                            viewModel.scope = .theme(theme.name)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
            }
        }

        sectionHeader("Popular right now", caption: "most copied", top: 24)
        LazyVGrid(columns: gridColumns, spacing: 14) {
            ForEach(viewModel.popular) { item in
                AnimationCard(item) {
                    router.push(.detail(animationId: item.id))
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)

        Button {
            viewModel.scope = .category(.backgrounds)
        } label: {
            Text("Explore all \(viewModel.totalCount) animations")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 11)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }

    // MARK: - Drill-in

    @ViewBuilder
    private var drill: some View {
        HStack(spacing: 8) {
            Button {
                viewModel.scope = .overview
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .bold))
                    Text("All")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.08), in: Capsule())
            }
            .buttonStyle(.plain)

            Text(viewModel.scope.title ?? "")
                .font(.system(size: 17, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(Theme.Palette.textPrimary)

            Text("\(viewModel.drillTotal)")
                .font(Theme.Typo.mono(11.5, weight: .semibold))
                .foregroundStyle(Theme.Palette.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Theme.Palette.accent.opacity(0.16), in: Capsule())

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, 18)

        HStack(spacing: 4) {
            ForEach(BrowseViewModel.Sort.allCases, id: \.self) { sort in
                let isOn = viewModel.sort == sort
                Button {
                    viewModel.sort = sort
                } label: {
                    Text(sort.rawValue)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(isOn ? .white : .white.opacity(0.55))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background(
                            isOn ? Theme.Palette.accent : Color.white.opacity(0.06),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, 12)

        LazyVGrid(columns: gridColumns, spacing: 14) {
            ForEach(viewModel.drillItems) { item in
                AnimationCard(item) {
                    router.push(.detail(animationId: item.id))
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, 16)

        if viewModel.canLoadMore {
            Button {
                viewModel.loadMore()
            } label: {
                Text("Show more · \(viewModel.remainingCount) left")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 11)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
        }
    }

    // MARK: - Section header helper

    private func sectionHeader(_ title: String, caption: String? = nil, top: CGFloat) -> some View {
        HStack(alignment: .lastTextBaseline) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(Theme.Palette.textPrimary)
            Spacer()
            if let caption {
                Text(caption)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
        }
        .padding(.horizontal, Theme.Spacing.xxl)
        .padding(.top, top)
        .padding(.bottom, 12)
    }
}
