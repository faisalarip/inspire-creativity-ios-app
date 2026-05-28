//
//  AnimationCard.swift
//  InspireCreativityApp
//
//  Shared catalog card. Two sizes (`.small`, `.medium`) match the prototype.
//

import SwiftUI

struct AnimationCard: View {

    enum Size { case small, medium }

    let item: AnimationItem
    let size: Size
    let action: () -> Void

    init(_ item: AnimationItem, size: Size = .medium, action: @escaping () -> Void = {}) {
        self.item = item
        self.size = size
        self.action = action
    }

    private var previewHeight: CGFloat { size == .small ? 116 : 160 }
    private var cardWidth: CGFloat? { size == .small ? 160 : nil }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    Color(hex: item.tintHex)
                    AnimationPreviewRegistry.view(for: item.id)
                    if item.isPro {
                        ProBadge()
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    iosBadge
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
                .frame(height: previewHeight)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card)
                        .strokeBorder(Theme.Palette.hairline, lineWidth: 0.5)
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(Theme.Typo.cardTitle)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(item.author)
                            .lineLimit(1)
                        Text("·")
                        Text(item.priceLabel)
                            .font(Theme.Typo.mono(12))
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: cardWidth)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name), \(item.category.displayName), \(item.priceLabel)")
    }

    private var iosBadge: some View {
        Text("iOS \(item.iosVersion)")
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(.ultraThinMaterial, in: Capsule())
    }
}
