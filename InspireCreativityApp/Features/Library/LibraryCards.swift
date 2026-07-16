//
//  LibraryCards.swift
//  InspireCreativityApp
//
//  Library v2 components (artboard 09): the stats card with weekly-activity
//  bars, and the collection shelf cards.
//

import SwiftUI

// MARK: - Stats card

struct LibraryStatsCard: View {

    let streak: Int
    let ownedCount: Int
    let savedCount: Int
    let isPro: Bool
    let weekBars: [Int]
    let copiesThisWeek: Int
    let onGoPro: () -> Void

    private static let flame = Color(hex: "#FF9F0A")
    private static let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]

    /// Monday-first index of today, matching `CopyActivityStore.weekBars`.
    private var todayIndex: Int {
        (Calendar.current.component(.weekday, from: Date()) + 5) % 7
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Avatar("You Dev", size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 7) {
                        Text("Hey, developer")
                            .font(.system(size: 16, weight: .bold))
                            .tracking(-0.3)
                            .foregroundStyle(Theme.Palette.textPrimary)
                        if isPro { ProBadge() }
                    }
                    HStack(spacing: 6) {
                        if streak > 0 {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Self.flame)
                            Text("\(streak)-day streak")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Self.flame)
                        }
                        Text("\(streak > 0 ? "· " : "")\(ownedCount) owned · \(savedCount) saved")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                Spacer()
                if !isPro {
                    Button(action: onGoPro) {
                        Text("Go Pro")
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Theme.Palette.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            // Weekly activity bars
            HStack(alignment: .bottom, spacing: 6) {
                let peak = max(weekBars.max() ?? 0, 1)
                ForEach(0..<7, id: \.self) { index in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(index == todayIndex ? Theme.Palette.accent : Color.white.opacity(0.14))
                            .frame(height: max(3, CGFloat(weekBars[index]) / CGFloat(peak) * 32))
                            .frame(maxWidth: .infinity)
                        Text(Self.dayLetters[index])
                            .font(Theme.Typo.mono(9))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity, alignment: .bottom)
                }

                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(copiesThisWeek)")
                        .font(Theme.Typo.mono(18, weight: .heavy))
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text("copies this week")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.leading, 8)
            }
            .frame(height: 44, alignment: .bottom)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Theme.Palette.accent.opacity(0.16),
                    Color(hex: "#131316"),
                    Color(hex: "#101013"),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.5)
        )
    }
}

// MARK: - Collection cards

struct CollectionCard: View {

    let name: String
    let items: [AnimationItem]
    let totalCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2)],
                    spacing: 2
                ) {
                    ForEach(0..<4, id: \.self) { index in
                        Group {
                            if index < items.count {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(Color(hex: items[index].tintHex))
                                    .overlay(
                                        AnimationPreviewRegistry.view(for: items[index].id)
                                            .clipShape(RoundedRectangle(cornerRadius: 7))
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(Color.white.opacity(0.04))
                            }
                        }
                        .frame(height: 56)
                    }
                }
                .padding(2)

                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.system(size: 13, weight: .bold))
                        .tracking(-0.2)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(1)
                    Text("\(totalCount) animation\(totalCount == 1 ? "" : "s")")
                        .font(Theme.Typo.mono(10.5))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.init(top: 9, leading: 12, bottom: 11, trailing: 12))
            }
            .frame(width: 168)
            .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

struct NewCollectionTile: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                Text("New")
                    .font(.system(size: 11.5, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.5))
            .frame(width: 108)
            .frame(maxHeight: .infinity)
            .frame(minHeight: 160)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        Color.white.opacity(0.18),
                        style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
