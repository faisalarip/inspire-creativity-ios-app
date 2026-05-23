//
//  DiscoverView.swift
//  StaggerApp
//

import SwiftUI

struct DiscoverView: View {

    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel: DiscoverViewModel

    init(viewModel: DiscoverViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                NavHeader(title: "Discover", isLarge: true, trailing: {
                    IconButton("bell") {}
                })
                .padding(.bottom, 12)

                Text("\(viewModel.totalCount) hand-crafted SwiftUI animations. Tap any one to preview, tweak, and copy.")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.horizontal, Theme.Spacing.xxl)
                    .padding(.bottom, Theme.Spacing.xxl)
                    .lineLimit(2)

                HeroCard(item: viewModel.featured) {
                    router.push(.detail(animationId: viewModel.featured.id))
                }
                .padding(.horizontal, Theme.Spacing.xl)

                SectionHeader("Trending this week", trailing: "See all") {
                    router.selectedTab = .browse
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.trending) { item in
                            AnimationCard(item, size: .small) {
                                router.push(.detail(animationId: item.id))
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                }

                AuroraPackPromoCard {
                    router.push(.detail(animationId: "aurora-mesh"))
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.xxxl)

                SectionHeader("Browse by category")
                CategoryGrid(categories: viewModel.categories) {
                    router.selectedTab = .browse
                }

                SectionHeader("New & noteworthy", trailing: "See all") {
                    router.selectedTab = .browse
                }
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(viewModel.newlyAdded) { item in
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
