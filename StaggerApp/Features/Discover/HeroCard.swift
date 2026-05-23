//
//  HeroCard.swift
//  StaggerApp
//
//  Featured animation card on the Discover screen.
//

import SwiftUI

struct HeroCard: View {
    let item: AnimationItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                Color(hex: item.tintHex)
                AnimationPreviewRegistry.view(for: item.id)

                // Bottom legibility gradient
                LinearGradient(
                    colors: [.clear, .black.opacity(0.65)],
                    startPoint: .center, endPoint: .bottom
                )

                VStack {
                    HStack {
                        Text("FEATURED")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(1)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                        Spacer()
                    }
                    .padding(12)
                    Spacer()
                    HStack(alignment: .lastTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            HStack(spacing: 6) {
                                Avatar(item.author, size: 20)
                                Text(item.author)
                                Text("·").opacity(0.5)
                                RatingView(value: item.rating, size: 10)
                            }
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                    }
                    .padding(16)
                }
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Featured: \(item.name)")
    }
}
