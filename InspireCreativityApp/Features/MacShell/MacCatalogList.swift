//
//  MacCatalogList.swift
//  InspireCreativityApp
//
//  Middle column: search + a grid of cards for the selected sidebar section.
//

#if os(macOS)
import SwiftUI

/// Middle column: search + a grid of cards for the selected sidebar section.
struct MacCatalogList: View {
    let items: [AnimationItem]
    @Binding var selectedItemID: AnimationItem.ID?
    @Binding var search: String

    private let columns = [GridItem(.adaptive(minimum: 220), spacing: 14)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(items) { item in
                    AnimationCard(item) { selectedItemID = item.id }
                        .overlay {
                            if selectedItemID == item.id {
                                RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.Palette.accent, lineWidth: 2)
                            }
                        }
                }
            }
            .padding(16)
        }
        .searchable(text: $search, placement: .toolbar, prompt: "Search animations, authors…")
        .background(Theme.Palette.background)
    }
}
#endif
