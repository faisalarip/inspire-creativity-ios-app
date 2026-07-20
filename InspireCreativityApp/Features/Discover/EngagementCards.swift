//
//  EngagementCards.swift
//  InspireCreativityApp
//
//  Discover v2's engagement components (artboard 05): streak chip, daily
//  pick hero, drop-countdown strip, weekly challenge card and the small
//  horizontal-row animation card (also reused by Library's continue row).
//

import SwiftUI

// MARK: - Streak chip

struct StreakChip: View {
    let count: Int

    private static let flame = Color(hex: "#FF9F0A")

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "flame.fill")
                .font(.system(size: 13))
            Text("\(count)")
                .font(.system(size: 13.5, weight: .bold))
                .monospacedDigit()
        }
        .foregroundStyle(Self.flame)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Self.flame.opacity(0.14), in: Capsule())
        .overlay(Capsule().strokeBorder(Self.flame.opacity(0.3), lineWidth: 0.5))
    }
}

// MARK: - Mini card (horizontal rows)

struct EngagementMiniCard: View {
    let item: AnimationItem
    var width: CGFloat = 150
    var previewHeight: CGFloat = 96
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                RoundedRectangle(cornerRadius: 13)
                    .fill(Color(hex: item.tintHex))
                    .frame(height: previewHeight)
                    .overlay(
                        AnimationPreviewRegistry.view(for: item.id)
                            .allowsHitTesting(false)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                    .overlay(
                        RoundedRectangle(cornerRadius: 13)
                            .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5)
                    )

                Text(item.name)
                    .font(.system(size: 12.5, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
                    .padding(.top, 7)
                Text(item.priceLabel)
                    .font(Theme.Typo.mono(11))
                    .foregroundStyle(
                        item.isFree ? Theme.Palette.success : Color.white.opacity(0.5)
                    )
                    .padding(.top, 1)
            }
            .frame(width: width)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Daily pick hero

struct DailyPickCard: View {
    let item: AnimationItem
    let resetLabel: String
    let copied: Bool
    let onOpen: () -> Void
    let onCopy: () -> Void

    var body: some View {
        Button(action: onOpen) {
            ZStack {
                Color(hex: item.tintHex)
                AnimationPreviewRegistry.view(for: item.id)

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.25), location: 0),
                        .init(color: .clear, location: 0.35),
                        .init(color: .black.opacity(0.72), location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )

                VStack {
                    HStack {
                        chip {
                            Text("DAILY PICK")
                                .font(.system(size: 10, weight: .heavy))
                                .tracking(1.2)
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        chip {
                            Text(resetLabel)
                                .font(Theme.Typo.mono(10.5, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                    .padding(12)

                    Spacer()

                    HStack(alignment: .bottom, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.system(size: 21, weight: .heavy))
                                .tracking(-0.5)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text("\(item.author) · 30-second read")
                                .font(.system(size: 12.5))
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        Button(action: onCopy) {
                            Text(copied ? "✓ Copied" : "Copy today’s code")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(copied ? Theme.Palette.success : Color(hex: "#0a0a0c"))
                                .padding(.horizontal, 15)
                                .padding(.vertical, 9)
                                .background(
                                    copied ? Theme.Palette.success.opacity(0.18) : Color.white,
                                    in: RoundedRectangle(cornerRadius: 11)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                }
            }
            .frame(height: 210)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private func chip(@ViewBuilder content: () -> some View) -> some View {
        content()
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.black.opacity(0.45), in: Capsule())
    }
}

// MARK: - Drop countdown strip

struct DropCountdownStrip: View {
    let countdownLabel: String
    let isReminderActive: Bool
    let onRemind: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("🎁").font(.system(size: 18))

            VStack(alignment: .leading, spacing: 1) {
                Text("Next Drop")
                    .font(.system(size: 14, weight: .bold))
                    .tracking(-0.2)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(countdownLabel)
                    .font(Theme.Typo.mono(12))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 8)

            Button(action: onRemind) {
                HStack(spacing: 5) {
                    Image(systemName: isReminderActive ? "checkmark" : "bell.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(isReminderActive ? "Reminder set" : "Remind me")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(isReminderActive ? Theme.Palette.success : .white)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(
                    isReminderActive ? Theme.Palette.success.opacity(0.18) : Theme.Palette.accent,
                    in: Capsule()
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            Theme.Palette.accent.opacity(0.10),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Theme.Palette.accent.opacity(0.28), lineWidth: 0.5)
        )
    }
}

// MARK: - Weekly challenge

struct WeeklyChallengeCard: View {
    let daysLeftLabel: String
    let joined: Bool
    let onJoin: () -> Void

    private static let purple = Color(hex: "#A78BFA")

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Self.purple)
                Text("WEEKLY CHALLENGE")
                    .font(.system(size: 10.5, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(Self.purple)
                Spacer()
                Text(daysLeftLabel)
                    .font(Theme.Typo.mono(11))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.bottom, 8)

            Text("Loader Week")
                .font(.system(size: 18, weight: .heavy))
                .tracking(-0.4)
                .foregroundStyle(Theme.Palette.textPrimary)

            Text("Build a loader that feels alive. Best entry ships in the library — with your name on it.")
                .font(.system(size: 13))
                .lineSpacing(4)
                .foregroundStyle(.white.opacity(0.65))
                .padding(.top, 3)

            HStack(spacing: 10) {
                HStack(spacing: -8) {
                    ForEach(["Maya Ortega", "Kenji Saito", "Lena Hofstad"], id: \.self) { name in
                        Avatar(name, size: 26)
                            .overlay(Circle().strokeBorder(Color(hex: "#131118"), lineWidth: 2))
                    }
                }
                Text("214 entries")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Button(action: onJoin) {
                    Text(joined ? "Joined ✓" : "Join")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(Color(hex: "#14121a"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(joined ? Self.purple.opacity(0.7) : Self.purple, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 12)
        }
        .padding(.init(top: 16, leading: 16, bottom: 15, trailing: 16))
        .background(
            LinearGradient(
                colors: [Self.purple.opacity(0.16), Color(hex: "#60A5FA").opacity(0.08)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Self.purple.opacity(0.3), lineWidth: 0.5)
        )
    }
}
