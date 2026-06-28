//
//  ProStatusView.swift
//  InspireCreativityApp
//
//  "Membership card" shown inside SettingsView when the user holds an active
//  Pro lifetime unlock. Works on iOS and macOS (pure SwiftUI, no platform
//  conditionals needed).
//

import SwiftUI

struct ProStatusView: View {

    @ObservedObject var store: StoreManager
    @State private var isRestoring = false
    @State private var restoreMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Membership".uppercased())
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(.white.opacity(0.4))

            VStack(alignment: .leading, spacing: 16) {
                // Gold pill badge
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("INSPIRECREATIVITY PRO")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(0.5)
                }
                .foregroundStyle(Color(red: 0x1A / 255, green: 0x0E / 255, blue: 0))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    LinearGradient(
                        colors: [Theme.Palette.proGoldStart, Theme.Palette.proGoldEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Capsule()
                )

                // Title + details
                VStack(alignment: .leading, spacing: 6) {
                    Text("You're Pro")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(.white)

                    Text("Active · Lifetime access")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.Palette.proGoldStart, Theme.Palette.proGoldEnd],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("Every animation unlocked — forever.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.65))

                    Text("Thanks for supporting InspireCreativity. ♥")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.top, 2)
                }

                Divider().overlay(Theme.Palette.hairline)

                // Restore purchases convenience button
                Button {
                    Task { await restorePurchases() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 20)
                        Text("Restore purchases")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        if isRestoring {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white.opacity(0.6))
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.25))
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isRestoring)

                if let restoreMessage {
                    Text(restoreMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Theme.Palette.proGoldStart.opacity(0.35),
                                Theme.Palette.proGoldEnd.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
            )
        }
    }

    // MARK: - Private

    private func restorePurchases() async {
        isRestoring = true
        restoreMessage = nil
        defer { isRestoring = false }
        do {
            try await store.restore()
            restoreMessage = store.isPro
                ? "Purchases restored."
                : "No previous purchases found for your Apple ID."
        } catch {
            restoreMessage = "Couldn't restore purchases. Please try again."
        }
    }
}

#Preview {
    ScrollView {
        ProStatusView(store: StoreManager())
            .padding(20)
    }
    .background(Theme.Palette.background)
}
