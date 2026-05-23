//
//  LibraryView.swift
//  StaggerApp
//

import SwiftUI

struct LibraryView: View {

    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel: LibraryViewModel

    init(viewModel: LibraryViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                NavHeader(title: "Library", isLarge: true, trailing: {
                    IconButton("ellipsis") {}
                })
                userCard
                tabBar
                contentGrid
                Spacer().frame(height: 120)
            }
        }
        .background(Theme.Palette.background)
        .ignoresSafeArea(edges: .bottom)
    }

    private var userCard: some View {
        HStack(spacing: 12) {
            Avatar("You Dev", size: 48)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Hey, developer")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    if viewModel.isPro { ProBadge() }
                }
                Text("\(viewModel.owned.count) owned · \(viewModel.favorites.count) saved")
                    .font(Theme.Typo.mono(12))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            if !viewModel.isPro {
                Button { router.push(.paywall) } label: {
                    Text("Go Pro")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Theme.Palette.accent, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Theme.Palette.accent.opacity(0.18),
                    Theme.Palette.accent.opacity(0.04)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Theme.Palette.accent.opacity(0.3), lineWidth: 0.5)
        )
        .padding(.horizontal, Theme.Spacing.xl)
    }

    private var tabBar: some View {
        HStack(spacing: 18) {
            ForEach(LibraryViewModel.Tab.allCases, id: \.self) { t in
                let active = viewModel.tab == t
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { viewModel.tab = t }
                } label: {
                    VStack(spacing: 4) {
                        HStack(spacing: 5) {
                            Text(t.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(active ? .white : .white.opacity(0.5))
                            Text("\(count(for: t))")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        Rectangle()
                            .fill(active ? Theme.Palette.accent : .clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.xxl)
    }

    private func count(for tab: LibraryViewModel.Tab) -> Int {
        switch tab {
        case .owned: viewModel.owned.count
        case .favorites: viewModel.favorites.count
        case .recent: viewModel.recent.count
        }
    }

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
}
