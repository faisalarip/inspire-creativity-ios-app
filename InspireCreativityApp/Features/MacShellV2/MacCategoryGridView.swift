//
//  MacCategoryGridView.swift
//  InspireCreativityApp
//
//  Scrollable category grid with a segmented sort control.
//  Matches CategoryGridView from the Claude Design macos-app.jsx reference.
//  macOS-only — wrapped in #if os(macOS).
//

#if os(macOS)
import SwiftUI

/// A scrollable grid of `MacAnimCard` tiles for a given category/collection,
/// with a header (title + subtitle/count) and a segmented sort control.
///
/// Matches the `CategoryGridView` component in the reference `macos-app.jsx`.
struct MacCategoryGridView: View {

    let title: String
    var subtitle: String? = nil
    let items: [AnimationItem]
    let selectedID: String?
    let onOpen: (String) -> Void

    // MARK: - Sort state

    private enum SortOrder: String, CaseIterable {
        case popular    = "Popular"
        case topRated   = "Top rated"
        case freeFirst  = "Free first"
    }

    @State private var sort: SortOrder = .popular

    // MARK: - Computed

    private var sortedItems: [AnimationItem] {
        switch sort {
        case .popular:
            return items.sorted { $0.downloads > $1.downloads }
        case .topRated:
            return items.sorted { $0.rating > $1.rating }
        case .freeFirst:
            return items.sorted { lhs, rhs in
                if lhs.isFree != rhs.isFree { return lhs.isFree }
                return lhs.downloads > rhs.downloads
            }
        }
    }

    private var subtitleText: String {
        subtitle ?? "\(items.count) animation\(items.count == 1 ? "" : "s")"
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerRow
                grid
            }
            .padding(.top, 28)
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
        .background(Theme.Palette.background)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .bottom) {
            // Left: title + subtitle
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 30, weight: .heavy))
                    .tracking(-0.8)
                    .foregroundColor(.white)

                Text(subtitleText)
                    .font(.system(size: 13.5))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            // Right: segmented sort control
            sortControl
        }
    }

    /// Three-pill segmented control inside a frosted rounded container.
    private var sortControl: some View {
        HStack(spacing: 2) {
            ForEach(SortOrder.allCases, id: \.self) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        sort = option
                    }
                } label: {
                    Text(option.rawValue)
                        .font(.system(size: 12.5, weight: sort == option ? .semibold : .regular))
                        .foregroundColor(sort == option ? .white : .white.opacity(0.55))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(sort == option ? Color.white.opacity(0.12) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - Grid

    private var grid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 220), spacing: 18)],
            spacing: 18
        ) {
            ForEach(sortedItems) { item in
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

#Preview {
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
    MacCategoryGridView(
        title: "Micro-interactions",
        items: [sample],
        selectedID: nil,
        onOpen: { _ in }
    )
    .frame(width: 700, height: 500)
}
#endif
