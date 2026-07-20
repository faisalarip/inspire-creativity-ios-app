//
//  UnlockedView.swift
//  InspireCreativityApp
//
//  Everything the user can open right now — free items, metered unlocks
//  this drop period, or the whole catalog with Pro — split into "New to
//  you" and "Seen", with explored-progress up top. The collection gimmick
//  that makes 300+ animations feel like a game, not a wall.
//

import Combine
import SwiftUI

struct UnlockedView: View {

    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var router: AppRouter

    @State private var seenIds: Set<String> = []

    private let gridColumns = [
        GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14),
    ]

    private var unlocked: [AnimationItem] {
        let isPro = container.purchaseRepository.isPro
        return container.animationRepository.all().filter {
            $0.isFree || isPro || container.proCopyMeter.isRedeemed($0.id)
        }
    }

    var body: some View {
        let items = unlocked
        let fresh = items.filter { !seenIds.contains($0.id) }
        let seen = items.filter { seenIds.contains($0.id) }

        ZStack {
            Theme.Palette.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header(unlockedCount: items.count, seenCount: seen.count)

                    if !fresh.isEmpty {
                        sectionHeader("New to you", count: fresh.count)
                        grid(fresh, showNewBadge: true)
                    }
                    if !seen.isEmpty {
                        sectionHeader("Seen", count: seen.count)
                        grid(seen, showNewBadge: false)
                    }

                    Spacer().frame(height: 120)
                }
            }
        }
        .onAppear { container.analytics.track(screen: .unlocked) }
        .onReceive(container.seenItemsRepository.idsPublisher) { seenIds = $0 }
    }

    private func header(unlockedCount: Int, seenCount: Int) -> some View {
        let total = container.animationRepository.all().count
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                IconButton("chevron.left") { router.pop() }
                Text("Unlocked")
                    .font(.system(size: 30, weight: .heavy))
                    .tracking(-1)
                    .foregroundStyle(Theme.Palette.textPrimary)
            }

            Text("You've explored \(seenCount) of \(unlockedCount) unlocked · \(total) in the catalog")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.top, 10)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(Theme.Palette.accent)
                        .frame(width: unlockedCount > 0
                               ? proxy.size.width * CGFloat(seenCount) / CGFloat(unlockedCount)
                               : 0)
                }
            }
            .frame(height: 6)
            .padding(.top, 10)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, 12)
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("\(count)")
                .font(Theme.Typo.mono(12))
                .foregroundStyle(Theme.Palette.textSecondary)
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.xxl)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }

    private func grid(_ items: [AnimationItem], showNewBadge: Bool) -> some View {
        LazyVGrid(columns: gridColumns, spacing: 14) {
            ForEach(items) { item in
                AnimationCard(item) {
                    router.push(.detail(animationId: item.id))
                }
                .overlay(alignment: .topLeading) {
                    if showNewBadge {
                        Text("NEW")
                            .font(.system(size: 8.5, weight: .heavy))
                            .tracking(0.6)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.Palette.accent, in: RoundedRectangle(cornerRadius: 5))
                            .padding(7)
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }
}
