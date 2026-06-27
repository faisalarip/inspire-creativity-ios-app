//
//  SettingsView.swift
//  InspireCreativityApp
//
//  Account, purchases, legal, and support. Hosts the App-Store-required
//  Restore Purchases and Delete Account actions.
//

import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var container: AppContainer
    @ObservedObject var store: StoreManager

    @AppStorage("analyticsEnabled") private var analyticsEnabled = true
    @State private var showAuthSheet = false
    @State private var showDeleteConfirm = false
    @State private var restoreMessage: String?
    @State private var isRestoring = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack(alignment: .top) {
            Theme.Palette.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Settings")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.top, 8)

                    accountSection
                    purchasesSection
                    aboutSection
                    if authStore.isAuthenticated { dangerSection }

                    Text("InspireCreativity \(appVersion)")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.35))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 80)
            }

            HStack {
                IconButton("chevron.left") { router.pop() }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
        }
        .hiddenNavigationBar()
        .sheet(isPresented: $showAuthSheet) {
            AuthGateView()
                .environmentObject(authStore)
        }
        .onChange(of: authStore.isAuthenticated) { _, isAuth in
            if isAuth { showAuthSheet = false }
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        SettingsCard(title: "Account") {
            if let email = authStore.session?.user.email {
                row(icon: "envelope.fill", title: email, mono: true)
                Divider().overlay(Theme.Palette.hairline)
                actionRow(icon: "rectangle.portrait.and.arrow.right",
                          title: "Sign out",
                          loading: authStore.isLoading) {
                    Task { await authStore.signOut() }
                }
            } else {
                actionRow(icon: "person.crop.circle",
                          title: "Sign in or create account",
                          subtitle: "Optional — browsing and purchases work without an account") {
                    authStore.clearError()
                    showAuthSheet = true
                }
            }
        }
    }

    // MARK: - Purchases

    private var purchasesSection: some View {
        SettingsCard(title: "Purchases") {
            HStack(spacing: 12) {
                Image(systemName: store.isPro ? "checkmark.seal.fill" : "lock.fill")
                    .foregroundStyle(store.isPro ? Theme.Palette.success : .white.opacity(0.6))
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.isPro ? "InspireCreativity Pro" : "Free plan")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(store.isPro ? "All animations unlocked" : "Free animations only")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                if !store.isPro {
                    Button { router.push(.paywall(source: "settings")) } label: {
                        Text("Go Pro")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Theme.Palette.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)

            Divider().overlay(Theme.Palette.hairline)

            actionRow(icon: "arrow.clockwise",
                      title: "Restore purchases",
                      loading: isRestoring) {
                Task { await restore() }
            }

            if let restoreMessage {
                Text(restoreMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - About / Legal

    private var aboutSection: some View {
        SettingsCard(title: "About") {
            linkRow(icon: "hand.raised.fill", title: "Privacy Policy", url: AppLinks.privacyURL)
            Divider().overlay(Theme.Palette.hairline)
            linkRow(icon: "doc.text.fill", title: "Terms of Use", url: AppLinks.termsURL)
            Divider().overlay(Theme.Palette.hairline)
            actionRow(icon: "envelope.fill", title: "Contact support") {
                openURL(AppLinks.supportURL)
            }
            Divider().overlay(Theme.Palette.hairline)
            Toggle(isOn: $analyticsEnabled) {
                HStack(spacing: 12) {
                    Image(systemName: "chart.bar.fill")
                        .foregroundStyle(.white.opacity(0.8)).frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Share usage analytics")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                        Text("Anonymous — helps improve the app")
                            .font(.system(size: 12)).foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .toggleStyle(.switch)
            .tint(Theme.Palette.accent)
            .onChange(of: analyticsEnabled) { _, on in
                container.analytics.setCollectionEnabled(on)
            }
        }
    }

    // MARK: - Danger zone

    private var dangerSection: some View {
        SettingsCard(title: "Danger zone") {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "trash.fill")
                        .foregroundStyle(Color(red: 1, green: 0.4, blue: 0.4))
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Delete account")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.45))
                        Text("Permanently deletes your account and data")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    if authStore.isLoading {
                        ProgressView().progressViewStyle(.circular).tint(.white.opacity(0.6))
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(authStore.isLoading)
            .confirmationDialog(
                "Delete your account? This permanently removes your account and cannot be undone.",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete account", role: .destructive) {
                    Task { await authStore.deleteAccount() }
                }
                Button("Cancel", role: .cancel) {}
            }

            if let message = authStore.lastError?.errorDescription {
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(red: 1, green: 0.5, blue: 0.5))
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Row builders

    private func row(icon: String, title: String, mono: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 24)
            Text(title)
                .font(mono ? Theme.Typo.mono(13) : .system(size: 15))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func actionRow(
        icon: String,
        title: String,
        subtitle: String? = nil,
        loading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                Spacer()
                if loading {
                    ProgressView().progressViewStyle(.circular).tint(.white.opacity(0.6))
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .disabled(loading)
    }

    private func linkRow(icon: String, title: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.vertical, 4)
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(v) (\(b))"
    }

    private func restore() async {
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

/// Titled card wrapper matching the app's dark surfaces.
private struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(.white.opacity(0.4))
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Theme.Palette.hairline, lineWidth: 0.5)
            )
        }
    }
}
