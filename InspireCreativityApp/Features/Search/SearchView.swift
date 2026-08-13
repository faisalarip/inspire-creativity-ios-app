//
//  SearchView.swift
//  InspireCreativityApp
//
//  v2.0 discovery-first search (artboard 08). Its own tab: suggestion chips,
//  ranked trending searches, persisted recents and a popular grid replace
//  the empty box; typing filters live.
//

import SwiftUI

struct SearchView: View {

    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel: SearchViewModel
    @FocusState private var focused: Bool
    @State private var resultLimit = 24

    private let gridColumns = [
        GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14),
    ]

    init(viewModel: SearchViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Search")
                    .font(.system(size: 32, weight: .heavy))
                    .tracking(-1)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .padding(.horizontal, Theme.Spacing.xxl)
                    .padding(.top, 8)

                searchField
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, 14)

                switch viewModel.state {
                case .idle:
                    idleContent
                case .empty(let query):
                    emptyState(query: query)
                case .results(let items):
                    results(items)
                }

                Spacer().frame(height: 120)
            }
        }
        .background(Theme.Palette.background)
        .ignoresSafeArea(edges: .bottom)
        .onChange(of: viewModel.query) { _, _ in resultLimit = 24 }
    }

    // MARK: - Input

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            TextField(
                "", text: $viewModel.query,
                prompt: Text("Animations, themes, authors…")
                    .foregroundColor(.white.opacity(0.45))
            )
            .textFieldStyle(.plain)
            .font(.system(size: 14.5))
            .foregroundStyle(.white)
            .focused($focused)
            .submitLabel(.search)
            .autocorrectionDisabled()
            .onSubmit { viewModel.commit(viewModel.query) }

            if !viewModel.query.isEmpty {
                Button { viewModel.clear() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(focused ? Theme.Palette.accent : .clear, lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.15), value: focused)
    }

    // MARK: - Idle (discovery)

    @ViewBuilder
    private var idleContent: some View {
        // Suggestion chips
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(viewModel.suggestions, id: \.self) { suggestion in
                    Button {
                        viewModel.commit(suggestion)
                    } label: {
                        Text(suggestion)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.65))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .overlay(
                                Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
        }
        .padding(.top, 10)

        // Trending searches
        caps("Trending searches")
            .padding(.top, 26)
        VStack(spacing: 0) {
            ForEach(Array(viewModel.trendingSearches.enumerated()), id: \.element.query) { index, entry in
                Button {
                    viewModel.commit(entry.query)
                } label: {
                    HStack(spacing: 14) {
                        Text("\(index + 1)")
                            .font(Theme.Typo.mono(14, weight: .heavy))
                            .foregroundStyle(index < 3 ? Theme.Palette.accent : .white.opacity(0.35))
                            .frame(width: 22, alignment: .leading)
                        Text(entry.query)
                            .font(.system(size: 15, weight: .medium))
                            .tracking(-0.2)
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Spacer()
                        deltaIcon(entry.delta)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)

        // Recents
        if !viewModel.recents.isEmpty {
            HStack(alignment: .lastTextBaseline) {
                caps("Recent", pad: false)
                Spacer()
                Button("Clear") { viewModel.clearRecents() }
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.Spacing.xxl)
            .padding(.top, 22)
            .padding(.bottom, 8)

            FlowLayout(spacing: 8) {
                ForEach(viewModel.recents, id: \.self) { recent in
                    Button {
                        viewModel.commit(recent)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                                .opacity(0.6)
                            Text(recent)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.06), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
        }

        // Popular this week
        HStack(alignment: .lastTextBaseline) {
            Text("Popular this week")
                .font(.system(size: 18, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(Theme.Palette.textPrimary)
            Spacer()
            Text("most searched")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.Palette.textTertiary)
        }
        .padding(.horizontal, Theme.Spacing.xxl)
        .padding(.top, 26)
        .padding(.bottom, 12)

        LazyVGrid(columns: gridColumns, spacing: 14) {
            ForEach(viewModel.popular) { item in
                AnimationCard(item) {
                    router.push(.detail(animationId: item.id))
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }

    // MARK: - Results / empty

    @ViewBuilder
    private func results(_ items: [AnimationItem]) -> some View {
        Text("\(items.count) result\(items.count == 1 ? "" : "s")")
            .font(Theme.Typo.mono(12.5))
            .foregroundStyle(Theme.Palette.textSecondary)
            .padding(.horizontal, Theme.Spacing.xxl)
            .padding(.top, 18)
            .padding(.bottom, 12)

        LazyVGrid(columns: gridColumns, spacing: 14) {
            ForEach(items.prefix(resultLimit)) { item in
                AnimationCard(item) {
                    router.push(.detail(animationId: item.id))
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)

        if items.count > resultLimit {
            Button {
                resultLimit += 24
            } label: {
                Text("Show more · \(items.count - resultLimit) left")
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

    private func emptyState(query: String) -> some View {
        VStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.05))
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.4))
                )
                .padding(.bottom, 9)
            Text("No matches for “\(query)”")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("Try a theme like “cosmic” or an author’s name.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 70)
        .padding(.horizontal, 40)
    }

    // MARK: - Helpers

    private func caps(_ title: String, pad: Bool = true) -> some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .bold))
            .tracking(1.1)
            .foregroundStyle(Theme.Palette.textTertiary)
            .padding(.horizontal, pad ? Theme.Spacing.xxl : 0)
            .padding(.bottom, pad ? 8 : 0)
    }

    @ViewBuilder
    private func deltaIcon(_ delta: SearchViewModel.Delta) -> some View {
        switch delta {
        case .up:
            Image(systemName: "arrow.up.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(hex: "#34D399"))
        case .down:
            Image(systemName: "arrow.down.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
        case .same:
            Capsule()
                .fill(Color.white.opacity(0.25))
                .frame(width: 13, height: 2)
        }
    }
}
