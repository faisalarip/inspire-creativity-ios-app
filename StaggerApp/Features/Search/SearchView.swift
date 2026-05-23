//
//  SearchView.swift
//  StaggerApp
//

import SwiftUI

struct SearchView: View {

    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel: SearchViewModel
    @FocusState private var fieldFocused: Bool

    init(viewModel: SearchViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Search")
                    .font(Theme.Typo.largeTitle)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.Spacing.xxl)
                    .padding(.top, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.xl)

                searchField
                    .padding(.horizontal, Theme.Spacing.xl)

                content
            }
        }
        .background(Theme.Palette.background)
        .ignoresSafeArea(edges: .bottom)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
            TextField("Search animations, authors, categories…", text: $viewModel.query)
                .focused($fieldFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .tint(Theme.Palette.accent)
            if !viewModel.query.isEmpty {
                Button { viewModel.clear() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(fieldFocused ? Theme.Palette.accent : Color.clear, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.15), value: fieldFocused)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            idlePanels
        case .empty(let q):
            emptyState(for: q)
        case .results(let items):
            resultsList(items: items)
        }
    }

    private var idlePanels: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("RECENT")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Button("Clear") {}
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.xxl)
            .padding(.bottom, 10)

            ForEach(viewModel.recentQueries, id: \.self) { q in
                Button { viewModel.use(query: q) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "clock")
                            .foregroundStyle(.white.opacity(0.4))
                        Text(q).foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "arrow.up.left")
                            .foregroundStyle(.white.opacity(0.25))
                    }
                    .font(.system(size: 14))
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.white.opacity(0.05)).frame(height: 0.5)
                            .padding(.horizontal, Theme.Spacing.xl)
                    }
                }
                .buttonStyle(.plain)
            }

            Text("TRENDING TAGS")
                .font(.system(size: 12, weight: .bold))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.xxl)
                .padding(.bottom, 10)

            FlowLayout(spacing: 8) {
                ForEach(viewModel.trendingTags, id: \.self) { tag in
                    Chip("#\(tag)") { viewModel.use(query: tag) }
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)

            Spacer().frame(height: 120)
        }
    }

    private func emptyState(for query: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.white.opacity(0.4))
            Text("No matches for \"\(query)\"")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.6))
            Text("Try a different keyword or browse by category.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func resultsList(items: [AnimationItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(items.count) result\(items.count == 1 ? "" : "s")")
                .font(Theme.Typo.mono(12))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.xxl)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                spacing: 14
            ) {
                ForEach(items) { item in
                    AnimationCard(item) {
                        router.push(.detail(animationId: item.id))
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)

            Spacer().frame(height: 120)
        }
    }
}
