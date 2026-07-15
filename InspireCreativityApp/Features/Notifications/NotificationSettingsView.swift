//
//  NotificationSettingsView.swift
//  InspireCreativityApp
//
//  Notification preferences (v2.0, artboard 04): master switch, per-category
//  toggles, delivery frequency and quiet hours.
//

import SwiftUI

struct NotificationSettingsView: View {

    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        Inner(
            coordinator: container.notificationCoordinator,
            streak: container.streakTracker.current,
            onBack: { router.pop() }
        )
        .onAppear { container.analytics.track(screen: .notificationSettings) }
    }

    // Nested so the coordinator can be an @ObservedObject (the container
    // itself never republishes coordinator changes).
    private struct Inner: View {

        @ObservedObject var coordinator: NotificationCoordinator
        let streak: Int
        let onBack: () -> Void

        var body: some View {
            ZStack {
                Theme.Palette.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header

                        if coordinator.authorization == .denied {
                            deniedBanner
                        }

                        masterCard

                        section("What you get") {
                            card {
                                toggleRow("Friday Drops", "The weekly release — 5 new animations", \.fridayDrops)
                                divider
                                toggleRow("Free this week", "When a pro animation goes free", \.freeThisWeek)
                                divider
                                toggleRow("Creators you follow", "New animations from followed authors", \.creators)
                                divider
                                toggleRow("Price drops", "Only for items in your favorites", \.priceDrops)
                                divider
                                toggleRow("Trending", "Popular in categories you browse", \.trending)
                                divider
                                toggleRow("Streak reminders", "One nudge before your streak resets", \.streakReminders)
                            }
                        }

                        section("Delivery") {
                            frequencyPicker
                            quietHoursRow
                        }

                        Text("Notifications deep-link straight to the animation. Muting here never affects your library or purchases.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.Palette.textTertiary)
                            .lineSpacing(3)
                            .padding(.horizontal, 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 60)
                }
            }
            .task { await coordinator.refreshAuthorization() }
        }

        // MARK: - Pieces

        private var header: some View {
            HStack(spacing: 10) {
                IconButton("chevron.left", action: onBack)
                Text("Notifications")
                    .font(.system(size: 22, weight: .heavy))
                    .tracking(-0.5)
                    .foregroundStyle(Theme.Palette.textPrimary)
            }
            .padding(.top, 12)
        }

        private var deniedBanner: some View {
            card {
                HStack(spacing: 12) {
                    Image(systemName: "bell.slash.fill")
                        .foregroundStyle(Theme.Palette.textSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notifications are off in iOS Settings")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Text("Enable them there to get Friday Drops and reminders.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                    Spacer()
                    #if os(iOS)
                    Button("Open Settings") { openSystemSettings() }
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(Theme.Palette.accent)
                        .buttonStyle(.plain)
                    #endif
                }
                .padding(14)
            }
        }

        private var masterCard: some View {
            card {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.Palette.accent)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "bell.badge.fill")
                                .font(.system(size: 17))
                                .foregroundStyle(.white)
                        )
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Push notifications")
                            .font(.system(size: 15.5, weight: .bold))
                            .tracking(-0.2)
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Text("Usually 2–3 a week")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                    Spacer()
                    Toggle("", isOn: binding(\.isEnabled))
                        .labelsHidden()
                        .tint(Theme.Palette.success)
                }
                .padding(14)
            }
        }

        private func toggleRow(
            _ title: String, _ subtitle: String,
            _ keyPath: WritableKeyPath<NotificationPreferences, Bool>
        ) -> some View {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .tracking(-0.2)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                Spacer()
                Toggle("", isOn: binding(keyPath))
                    .labelsHidden()
                    .tint(Theme.Palette.success)
                    .disabled(!coordinator.preferences.isEnabled)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .opacity(coordinator.preferences.isEnabled ? 1 : 0.4)
            .animation(.easeOut(duration: 0.2), value: coordinator.preferences.isEnabled)
        }

        private var frequencyPicker: some View {
            HStack(spacing: 4) {
                ForEach(NotificationPreferences.Frequency.allCases, id: \.self) { frequency in
                    let isOn = coordinator.preferences.frequency == frequency
                    Button {
                        var prefs = coordinator.preferences
                        prefs.frequency = frequency
                        coordinator.update(prefs, streak: streak)
                    } label: {
                        Text(frequency.title)
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isOn ? Theme.Palette.accent : .clear)
                            .foregroundStyle(isOn ? .white : Theme.Palette.textSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(cardBackground)
        }

        private var quietHoursRow: some View {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quiet hours")
                        .font(.system(size: 15, weight: .medium))
                        .tracking(-0.2)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text("10:00 PM – 8:00 AM")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(cardBackground)
            .padding(.top, 10)
        }

        // MARK: - Helpers

        private func binding(_ keyPath: WritableKeyPath<NotificationPreferences, Bool>) -> Binding<Bool> {
            Binding(
                get: { coordinator.preferences[keyPath: keyPath] },
                set: { newValue in
                    var prefs = coordinator.preferences
                    prefs[keyPath: keyPath] = newValue
                    coordinator.update(prefs, streak: streak)
                }
            )
        }

        private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .padding(.horizontal, 4)
                content()
            }
        }

        private func card(@ViewBuilder content: () -> some View) -> some View {
            VStack(spacing: 0, content: content)
                .background(cardBackground)
        }

        private var cardBackground: some View {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Theme.Palette.hairline, lineWidth: 0.5)
                )
        }

        private var divider: some View {
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 0.5)
                .padding(.leading, 16)
        }

        #if os(iOS)
        private func openSystemSettings() {
            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
        #endif
    }
}
