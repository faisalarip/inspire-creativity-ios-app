//
//  MacSearchResults.swift
//  InspireCreativityApp
//
//  Search-results grid for the macOS redesigned shell (MacShellV2).
//  The caller is responsible for filtering; this view only renders.
//  Matches SearchResults from the Claude Design macos-app.jsx reference.
//  macOS-only — wrapped in #if os(macOS).
//

#if os(macOS)
import SwiftUI

/// Renders already-filtered search results as an adaptive grid of `MacAnimCard`
/// tiles with a result-count header and an empty state when there are no hits.
///
/// Matches the `SearchResults` component in the reference `macos-app.jsx`.
struct MacSearchResults: View {

    let query: String
    let items: [AnimationItem]
    let selectedID: String?
    let onOpen: (String) -> Void

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if items.isEmpty {
                    emptyState
                } else {
                    grid
                }
            }
            .padding(.top, 28)
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
        .background(Theme.Palette.background)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("\(items.count) result\(items.count == 1 ? "" : "s")")
                    .font(.system(size: 30, weight: .heavy))
                    .tracking(-0.8)
                    .foregroundColor(.white)

                Text("for \"\(query)\"")
                    .font(.system(size: 30, weight: .heavy))
                    .tracking(-0.8)
                    .foregroundColor(.white.opacity(0.35))
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.white.opacity(0.25))

            Text("No matches.")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))

            Text("Try a theme like \"cosmic\" or an author name.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Grid

    private var grid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 220), spacing: 18)],
            spacing: 18
        ) {
            ForEach(items) { item in
                MacAnimCard(
                    item: item,
                    isSelected: selectedID == item.id,
                    onOpen: { onOpen(item.id) }
                )
            }
        }
    }
}

// MARK: - Preview

#Preview("With results") {
    let sample = AnimationItem(
        id: "springBounce",
        name: "Spring Bounce",
        category: .microInteractions,
        difficulty: .beginner,
        iosVersion: "17+",
        isPro: false,
        isFeatured: true,
        tintHex: "#F472B6",
        author: "Demo",
        handle: "@demo",
        downloads: 1200,
        rating: 4.8,
        price: nil,
        description: "A bouncy spring micro-interaction.",
        swiftCode: ""
    )
    MacSearchResults(
        query: "bounce",
        items: [sample],
        selectedID: nil,
        onOpen: { _ in }
    )
    .frame(width: 700, height: 500)
}

#Preview("Empty state") {
    MacSearchResults(
        query: "xyz",
        items: [],
        selectedID: nil,
        onOpen: { _ in }
    )
    .frame(width: 700, height: 500)
}
#endif
