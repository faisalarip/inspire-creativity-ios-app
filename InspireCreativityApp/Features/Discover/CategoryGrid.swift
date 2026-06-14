//
//  CategoryGrid.swift
//  InspireCreativityApp
//
//  2-column tile grid showing a representative animation preview per category.
//

import SwiftUI

struct CategoryGrid: View {
    let categories: [(category: Category, count: Int)]
    let onPick: (Category) -> Void

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            ForEach(categories.prefix(6), id: \.category.id) { entry in
                CategoryTile(category: entry.category, count: entry.count) {
                    onPick(entry.category)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }
}

private struct CategoryTile: View {
    let category: Category
    let count: Int
    let action: () -> Void

    private var representativePreviewId: String {
        // Pick a stable id per category.
        switch category {
        case .backgrounds: return "aurora-mesh"
        case .loaders: return "progress-arc"
        case .buttons: return "spring-button"
        case .microInteractions: return "heart-burst"
        case .transitions: return "card-flip"
        case .navigation: return "liquid-tabs"
        case .gestures: return "parallax-card"
        case .onboarding: return "onboarding"
        case .textEffects: return "ticker"
        case .metalShaders: return "liquid-ripple"
        }
    }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .leading) {
                Color.white.opacity(0.04)
                HStack {
                    Spacer()
                    AnimationPreviewRegistry.view(for: representativePreviewId)
                        .frame(width: 90)
                        .scaleEffect(0.85)
                        .opacity(0.85)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(category.displayName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("\(count) packs")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.leading, 14)
                .padding(.vertical, 14)
            }
            .frame(height: 92)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Theme.Palette.hairline, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(category.displayName), \(count) packs")
    }
}
