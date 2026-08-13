//
//  NotificationPrimingView.swift
//  InspireCreativityApp
//
//  Pre-permission priming (v2.0, artboard 02): sell the value of pushes
//  before showing the real system prompt. Presented as a cover from
//  Discover's "Remind me".
//

import SwiftUI

struct NotificationPrimingView: View {

    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss

    @State private var granted = false

    private struct Perk: Identifiable {
        let id = UUID()
        let emoji: String
        let title: String
        let subtitle: String
    }

    private let perks = [
        Perk(emoji: "🎁", title: "Friday Drops",
             subtitle: "Be first to grab the 5 new animations each week — one is always free."),
        Perk(emoji: "🏷️", title: "Price drops",
             subtitle: "When something on your favorites goes on sale."),
        Perk(emoji: "✨", title: "Creators you follow",
             subtitle: "New animations from authors you care about."),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.Palette.background.ignoresSafeArea()

            AnimationPreviewRegistry.view(for: "aurora-borealis")
                .opacity(0.5)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Theme.Palette.background.opacity(0.55),
                    Theme.Palette.background.opacity(0.92),
                    Theme.Palette.background.opacity(0.96),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                bellHero
                    .padding(.bottom, 22)

                Text("Never miss a\nFriday Drop.")
                    .font(.system(size: 32, weight: .heavy))
                    .tracking(-1)
                    .lineSpacing(1)
                    .foregroundStyle(Theme.Palette.textPrimary)

                Text("2–3 notifications a week, only about things you chose. Tune or mute anytime.")
                    .font(.system(size: 15))
                    .tracking(-0.1)
                    .lineSpacing(4)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.top, 10)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(perks) { perk in
                        HStack(alignment: .top, spacing: 12) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.07))
                                .frame(width: 38, height: 38)
                                .overlay(Text(perk.emoji).font(.system(size: 17)))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.5)
                                )
                            VStack(alignment: .leading, spacing: 1) {
                                Text(perk.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .tracking(-0.2)
                                    .foregroundStyle(Theme.Palette.textPrimary)
                                Text(perk.subtitle)
                                    .font(.system(size: 13))
                                    .lineSpacing(3)
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                        }
                    }
                }
                .padding(.top, 22)

                ctaButton
                    .padding(.top, 26)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 46)
        }
        .overlay(alignment: .topTrailing) {
            Button("Not now") { dismiss() }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.08), in: Capsule())
                .buttonStyle(.plain)
                .padding(.trailing, 18)
                .padding(.top, 18)
        }
        .preferredColorScheme(.dark)
    }

    private var bellHero: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(
                LinearGradient(
                    colors: [Theme.Palette.accent.opacity(0.85), Theme.Palette.accent],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .frame(width: 76, height: 76)
            .overlay(
                Image(systemName: "bell.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
            )
            .overlay(alignment: .topTrailing) {
                Text("5")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(minWidth: 24, minHeight: 24)
                    .background(Color(hex: "#FF3B30"), in: Circle())
                    .overlay(Circle().strokeBorder(Theme.Palette.background, lineWidth: 2.5))
                    .offset(x: 8, y: -8)
            }
            .shadow(color: Theme.Palette.accent.opacity(0.45), radius: 20, y: 8)
    }

    private var ctaButton: some View {
        Button {
            guard !granted else { return }
            Task {
                let ok = await container.notificationCoordinator
                    .requestPermission(streak: container.streakTracker.current)
                if ok {
                    granted = true
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    dismiss()
                } else {
                    dismiss()
                }
            }
        } label: {
            Text(granted ? "Notifications on ✓" : "Turn on notifications")
                .font(.system(size: 16, weight: .bold))
                .tracking(-0.2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    granted ? Theme.Palette.success.opacity(0.18) : Theme.Palette.accent,
                    in: RoundedRectangle(cornerRadius: 15)
                )
                .foregroundStyle(granted ? Theme.Palette.success : .white)
        }
        .buttonStyle(.plain)
        .shadow(
            color: granted ? .clear : Theme.Palette.accent.opacity(0.35),
            radius: 15, y: 8
        )
    }
}
