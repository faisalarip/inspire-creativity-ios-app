//
//  CategoryCard.swift
//  InspireCreativityApp
//
//  Browse v2 category tile: live representative preview bleeding in from the
//  right edge, tint dot, name and count.
//

import SwiftUI

struct CategoryCard: View {

    let category: Category
    let count: Int
    let representative: AnimationItem?
    var isNew = false
    let action: () -> Void

    /// Design's per-category tint dots (artboard 06).
    private static let tints: [Category: Color] = [
        .backgrounds: Color(hex: "#A78BFA"),
        .loaders: Color(hex: "#22D3EE"),
        .buttons: Color(hex: "#FF6B4A"),
        .microInteractions: Color(hex: "#F472B6"),
        .transitions: Color(hex: "#34D399"),
        .navigation: Color(hex: "#60A5FA"),
        .gestures: Color(hex: "#FBBF24"),
        .onboarding: Color(hex: "#FB7185"),
        .textEffects: Color(hex: "#C4B5FD"),
        .metalShaders: Color(hex: "#F97316"),
    ]

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .leading) {
                Color(hex: representative?.tintHex ?? "#16161a")

                if let representative {
                    HStack {
                        Spacer()
                        AnimationPreviewRegistry.view(for: representative.id)
                            .frame(width: 110)
                            .mask(
                                LinearGradient(
                                    colors: [.clear, .black],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .opacity(0.9)
                    }
                }

                LinearGradient(
                    stops: [
                        .init(color: Theme.Palette.background.opacity(0.9), location: 0.34),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .leading, endPoint: .trailing
                )

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Self.tints[category] ?? Theme.Palette.accent)
                            .frame(width: 7, height: 7)
                        if isNew {
                            Text("5 NEW")
                                .font(.system(size: 8.5, weight: .heavy))
                                .tracking(0.6)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.Palette.accent, in: RoundedRectangle(cornerRadius: 5))
                        }
                    }
                    Spacer()
                    Text(category.displayName)
                        .font(.system(size: 13.5, weight: .bold))
                        .tracking(-0.2)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text("\(count)")
                        .font(Theme.Typo.mono(10.5))
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.top, 2)
                }
                .padding(13)
            }
            .frame(height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
