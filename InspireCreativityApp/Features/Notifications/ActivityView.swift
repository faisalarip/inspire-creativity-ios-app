//
//  ActivityView.swift
//  InspireCreativityApp
//
//  In-app notification inbox (v2.0, artboard 03). Grouped Today / This week /
//  Earlier, with live preview tiles, unread dots and "Mark all read".
//

import Combine
import SwiftUI

struct ActivityView: View {

    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var router: AppRouter

    @State private var items: [ActivityItem] = []

    private var groups: [(label: String, items: [ActivityItem])] {
        let calendar = Calendar.current
        var today: [ActivityItem] = []
        var week: [ActivityItem] = []
        var earlier: [ActivityItem] = []
        for item in items {
            if calendar.isDateInToday(item.date) {
                today.append(item)
            } else if item.date > Date().addingTimeInterval(-7 * 86_400) {
                week.append(item)
            } else {
                earlier.append(item)
            }
        }
        return [("Today", today), ("This week", week), ("Earlier", earlier)]
            .filter { !$0.1.isEmpty }
    }

    var body: some View {
        ZStack {
            Theme.Palette.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header

                    ForEach(groups, id: \.label) { group in
                        Text(group.label.uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1.1)
                            .foregroundStyle(Theme.Palette.textTertiary)
                            .padding(.horizontal, 20)
                            .padding(.top, 24)
                            .padding(.bottom, 8)

                        ForEach(group.items) { item in
                            ActivityRow(item: item) {
                                if let id = item.animationId {
                                    router.push(.detail(animationId: id))
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 110)
            }
        }
        .onAppear { container.analytics.track(screen: .activity) }
        .onReceive(container.activityRepository.itemsPublisher) { _ in
            items = container.activityRepository.all()
        }
    }

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            HStack(spacing: 10) {
                IconButton("chevron.left") { router.pop() }
                Text("Activity")
                    .font(.system(size: 30, weight: .heavy))
                    .tracking(-1)
                    .foregroundStyle(Theme.Palette.textPrimary)
            }
            Spacer()
            Button("Mark all read") {
                container.activityRepository.markAllRead()
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.Palette.accent)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

// MARK: - Row

private struct ActivityRow: View {
    let item: ActivityItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                leading

                VStack(alignment: .leading, spacing: 2) {
                    (Text(item.headline).fontWeight(.semibold)
                        + Text(" \(item.detail)"))
                        .font(.system(size: 14.5))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    Text(item.subtitle)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 6) {
                    Text(timeLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Palette.textTertiary)
                    if !item.isRead {
                        Circle()
                            .fill(Theme.Palette.accent)
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var leading: some View {
        if let animationId = item.animationId {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#16161a"))
                .frame(width: 46, height: 46)
                .overlay(
                    AnimationPreviewRegistry.view(for: animationId)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Theme.Palette.hairline, lineWidth: 0.5)
                )
        } else if let author = item.authorName {
            Avatar(author, size: 46)
        } else {
            iconTile
        }
    }

    private var iconTile: some View {
        let (symbol, tint): (String, Color) = {
            switch item.kind {
            case .streak: return ("flame.fill", Color(hex: "#FF9F0A"))
            case .challenge: return ("trophy.fill", Color(hex: "#FFC857"))
            default: return ("bell.fill", Theme.Palette.accent)
            }
        }()
        return RoundedRectangle(cornerRadius: 12)
            .fill(tint.opacity(0.16))
            .frame(width: 46, height: 46)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: 18))
                    .foregroundStyle(tint)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(tint.opacity(0.3), lineWidth: 0.5)
            )
    }

    private var timeLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(item.date) {
            return item.date.formatted(date: .omitted, time: .shortened)
        }
        if item.date > Date().addingTimeInterval(-7 * 86_400) {
            return item.date.formatted(.dateTime.weekday(.abbreviated))
        }
        return item.date.formatted(.dateTime.month(.abbreviated).day())
    }
}
