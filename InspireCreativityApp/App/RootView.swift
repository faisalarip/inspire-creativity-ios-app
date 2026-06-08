//
//  RootView.swift
//  InspireCreativityApp
//
//  Top-level shell. Custom floating tab bar (matches prototype's
//  blurred dark style) layered above the per-tab NavigationStacks.
//

import SwiftUI

struct RootView: View {

    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var router = AppRouter()

    var body: some View {
        // Browsing the catalog never requires an account (Guideline 5.1.1).
        // Sign-in is offered as an optional feature inside Settings; the
        // verify-email interstitial still surfaces when a signup is pending.
        ZStack {
            signedInShell
                .transition(.opacity)
            if authStore.pendingVerificationEmail != nil {
                AuthGateView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: authStore.pendingVerificationEmail)
    }

    private var signedInShell: some View {
        ZStack(alignment: .bottom) {
            Theme.Palette.background.ignoresSafeArea()

            ZStack {
                tabContent(.discover).opacity(router.selectedTab == .discover ? 1 : 0)
                tabContent(.browse).opacity(router.selectedTab == .browse ? 1 : 0)
                tabContent(.samples).opacity(router.selectedTab == .samples ? 1 : 0)
                tabContent(.library).opacity(router.selectedTab == .library ? 1 : 0)
            }
            .animation(.easeOut(duration: 0.15), value: router.selectedTab)

            if !router.hidesTabBar {
                FloatingTabBar(selected: $router.selectedTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .environmentObject(router)
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: router.hidesTabBar)
    }

    @ViewBuilder
    private func tabContent(_ tab: AppTab) -> some View {
        NavigationStack(path: router.path(for: tab)) {
            tabRoot(tab)
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .detail(let id):
                        DetailView(viewModel: container.makeDetailViewModel(animationId: id))
                            .toolbar(.hidden, for: .navigationBar)
                    case .paywall:
                        PaywallView(viewModel: container.makePaywallViewModel())
                            .toolbar(.hidden, for: .navigationBar)
                    case .settings:
                        SettingsView(store: container.store)
                            .toolbar(.hidden, for: .navigationBar)
                    }
                }
        }
    }

    @ViewBuilder
    private func tabRoot(_ tab: AppTab) -> some View {
        switch tab {
        case .discover: DiscoverView(viewModel: container.makeDiscoverViewModel())
        case .browse:   BrowseView(viewModel: container.makeBrowseViewModel())
        case .samples:  SamplesView()
        case .library:  LibraryView(viewModel: container.makeLibraryViewModel())
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: Auth gate — signed-out experience
// MARK: ─────────────────────────────────────────────────────────────

/// Top-level container for the three auth screens. State machine reads off
/// `AuthStore.pendingVerificationEmail` plus its own `screen` enum so the
/// user can move between Sign In and Register without losing field state.
struct AuthGateView: View {

    @EnvironmentObject private var authStore: AuthStore

    enum Screen { case signIn, register }
    @State private var screen: Screen = .signIn
    @State private var prefilledEmail: String = ""

    var body: some View {
        ZStack {
            Theme.Palette.background.ignoresSafeArea()

            // Verify screen wins as long as a pending email exists.
            if let email = authStore.pendingVerificationEmail {
                VerifyEmailView(
                    email: email,
                    onBack: {
                        // Back → leave the verify interstitial and return to the
                        // auth form the user came from (their field state is gone,
                        // but the email is pre-filled for convenience).
                        prefilledEmail = email
                        authStore.dismissPendingVerification()
                    },
                    onReturnToSignIn: {
                        // "I've verified — Sign in" → drop pending, route to
                        // sign in with the email pre-filled.
                        prefilledEmail = email
                        authStore.dismissPendingVerification()
                        screen = .signIn
                    }
                )
                .transition(.opacity)
            } else {
                switch screen {
                case .signIn:
                    SignInView(prefilledEmail: prefilledEmail) {
                        // "Create account" link.
                        prefilledEmail = ""
                        authStore.clearError()
                        screen = .register
                    }
                    .transition(.opacity)
                case .register:
                    RegisterView {
                        // "Already have an account? Sign in" link.
                        authStore.clearError()
                        screen = .signIn
                    }
                    .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: screen)
        .animation(.easeInOut(duration: 0.2), value: authStore.pendingVerificationEmail)
        .preferredColorScheme(.dark)
    }
}

/// Sign-in screen. The first thing a signed-out user sees.
private struct SignInView: View {

    @EnvironmentObject private var authStore: AuthStore
    let prefilledEmail: String
    let onCreateAccount: () -> Void

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var resetNote: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AuthLogo()
                    .padding(.top, 96)
                    .frame(maxWidth: .infinity, alignment: .center)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Welcome back")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(.white)
                    Text("Sign in to your InspireCreativity account.")
                        .font(Theme.Typo.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.top, 32)

                if let resetNote {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.Palette.success)
                            .font(.system(size: 13, weight: .semibold))
                        Text(resetNote)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 10).padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Theme.Palette.success.opacity(0.10))
                    )
                } else if let message = authStore.lastError?.errorDescription {
                    AuthErrorBanner(message: message)
                }

                AuthField(
                    placeholder: "Email",
                    text: $email,
                    isSecure: false,
                    contentType: .emailAddress,
                    keyboard: .emailAddress
                )

                AuthField(
                    placeholder: "Password",
                    text: $password,
                    isSecure: true,
                    contentType: .password,
                    keyboard: .default
                )

                HStack {
                    Spacer()
                    Button("Forgot password?") {
                        Task {
                            resetNote = nil
                            let ok = await authStore.sendPasswordReset(
                                email: email.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                            if ok { resetNote = "Password reset link sent. Check your email." }
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.accent.opacity(canResetPassword ? 1 : 0.4))
                    .disabled(!canResetPassword)
                }

                AuthPrimaryButton(
                    title: "Sign in",
                    isLoading: authStore.isLoading,
                    isDisabled: !canSubmit
                ) {
                    Task { await submit() }
                }
                .padding(.top, 4)

                HStack(spacing: 6) {
                    Text("Don't have an account?")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.55))
                    Button("Create account", action: onCreateAccount)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Palette.accent)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)

                Spacer().frame(height: 60)
            }
            .padding(.horizontal, Theme.Spacing.xxl)
        }
        .onAppear {
            if email.isEmpty { email = prefilledEmail }
        }
    }

    private var canSubmit: Bool {
        AuthValidation.isValidEmail(email) && password.count >= 6 && !authStore.isLoading
    }

    private var canResetPassword: Bool {
        AuthValidation.isValidEmail(email) && !authStore.isLoading
    }

    private func submit() async {
        await authStore.signIn(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )
    }
}

/// Account-creation screen.
private struct RegisterView: View {

    @EnvironmentObject private var authStore: AuthStore
    let onSignInTap: () -> Void

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var localError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AuthLogo()
                    .padding(.top, 96)
                    .frame(maxWidth: .infinity, alignment: .center)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Create your account")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(.white)
                    Text("Sign up to save favorites and unlock Pro.")
                        .font(Theme.Typo.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.top, 32)

                if let local = localError {
                    AuthErrorBanner(message: local)
                } else if let message = authStore.lastError?.errorDescription {
                    AuthErrorBanner(message: message)
                }

                HStack(spacing: 12) {
                    AuthField(
                        placeholder: "First name",
                        text: $firstName,
                        isSecure: false,
                        contentType: .givenName,
                        keyboard: .default,
                        autocapitalization: .words
                    )
                    AuthField(
                        placeholder: "Last name",
                        text: $lastName,
                        isSecure: false,
                        contentType: .familyName,
                        keyboard: .default,
                        autocapitalization: .words
                    )
                }

                AuthField(
                    placeholder: "Email",
                    text: $email,
                    isSecure: false,
                    contentType: .emailAddress,
                    keyboard: .emailAddress
                )

                AuthField(
                    placeholder: "Password (min 6 characters)",
                    text: $password,
                    isSecure: true,
                    contentType: .newPassword,
                    keyboard: .default
                )

                AuthField(
                    placeholder: "Confirm password",
                    text: $confirmPassword,
                    isSecure: true,
                    contentType: .newPassword,
                    keyboard: .default
                )

                AuthPrimaryButton(
                    title: "Create account",
                    isLoading: authStore.isLoading,
                    isDisabled: !canSubmit
                ) {
                    Task { await submit() }
                }
                .padding(.top, 4)

                HStack(spacing: 6) {
                    Text("Already have an account?")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.55))
                    Button("Sign in", action: onSignInTap)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Palette.accent)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)

                Spacer().frame(height: 60)
            }
            .padding(.horizontal, Theme.Spacing.xxl)
        }
    }

    private var canSubmit: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && AuthValidation.isValidEmail(email)
            && password.count >= 6
            && password == confirmPassword
            && !authStore.isLoading
    }

    private func submit() async {
        localError = nil
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFirst.isEmpty, !trimmedLast.isEmpty else {
            localError = "Enter your first and last name."
            return
        }
        guard AuthValidation.isValidEmail(email) else {
            localError = "Enter a valid email address."
            return
        }
        guard password.count >= 6 else {
            localError = "Password must be at least 6 characters."
            return
        }
        guard password == confirmPassword else {
            localError = "Passwords don't match."
            return
        }
        await authStore.signUp(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            firstName: trimmedFirst,
            lastName: trimmedLast
        )
    }
}

/// "Check your email" interstitial shown after signup when the project has
/// email-confirm on. Offers a "resend" button and a path back to sign in.
private struct VerifyEmailView: View {

    @EnvironmentObject private var authStore: AuthStore
    let email: String
    var onBack: () -> Void
    let onReturnToSignIn: () -> Void

    @State private var resendConfirmation: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AuthLogo()
                    .padding(.top, 96)
                    .frame(maxWidth: .infinity, alignment: .center)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Check your email")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(.white)
                    Text("We sent a verification link to ")
                        .font(Theme.Typo.body)
                        .foregroundStyle(.white.opacity(0.7))
                    + Text(email)
                        .font(Theme.Typo.body.weight(.semibold))
                        .foregroundStyle(.white)
                    + Text(". Tap the link, then come back and sign in.")
                        .font(Theme.Typo.body)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.top, 32)

                if let message = authStore.lastError?.errorDescription {
                    AuthErrorBanner(message: message)
                }

                if let confirmation = resendConfirmation {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.Palette.success)
                        Text(confirmation)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(.vertical, 10).padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Theme.Palette.success.opacity(0.10))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Theme.Palette.success.opacity(0.35), lineWidth: 0.5)
                    )
                }

                AuthPrimaryButton(
                    title: "I've verified — Sign in",
                    isLoading: false,
                    isDisabled: false
                ) {
                    onReturnToSignIn()
                }
                .padding(.top, 8)

                Button {
                    Task { await resend() }
                } label: {
                    HStack(spacing: 6) {
                        if authStore.isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(Theme.Palette.accent)
                        }
                        Text(authStore.isLoading ? "Resending…" : "Resend email")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.Palette.accent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .disabled(authStore.isLoading)

                Spacer().frame(height: 60)
            }
            .padding(.horizontal, Theme.Spacing.xxl)
        }
        .overlay(alignment: .topLeading) {
            IconButton("chevron.left", action: onBack)
                .padding(.horizontal, Theme.Spacing.xxl)
                .padding(.top, 8)
        }
    }

    private func resend() async {
        resendConfirmation = nil
        await authStore.resendVerification()
        if authStore.lastError == nil {
            resendConfirmation = "Verification email re-sent."
        }
    }
}

// MARK: - Auth UI primitives

/// Square brand mark used at the top of every auth screen. Renders the
/// bundled `AppLogo` image (sourced from the AppIcon at build time).
private struct AuthLogo: View {
    var body: some View {
        Image("AppLogo")
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Theme.Palette.accent.opacity(0.4), radius: 18, x: 0, y: 8)
    }
}

/// Styled text/secure field used throughout the auth flow.
private struct AuthField: View {
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    let contentType: UITextContentType?
    let keyboard: UIKeyboardType
    var autocapitalization: TextInputAutocapitalization = .never

    var body: some View {
        Group {
            if isSecure {
                SecureField("", text: $text, prompt: prompt)
            } else {
                TextField("", text: $text, prompt: prompt)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled(true)
            }
        }
        .textContentType(contentType)
        .foregroundStyle(.white)
        .font(.system(size: 15))
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Theme.Palette.hairline, lineWidth: 0.5)
        )
    }

    private var prompt: Text {
        Text(placeholder).foregroundColor(.white.opacity(0.45))
    }
}

/// Full-width accent CTA used on every auth screen.
private struct AuthPrimaryButton: View {
    let title: String
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.Palette.accent.opacity(isDisabled ? 0.4 : 1.0))
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
    }
}

/// Inline red banner that surfaces an auth error.
private struct AuthErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.45))
                .font(.system(size: 13, weight: .semibold))
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10).padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(red: 1.0, green: 0.35, blue: 0.35).opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(red: 1.0, green: 0.35, blue: 0.35).opacity(0.4), lineWidth: 0.5)
        )
    }
}

/// Stateless validation helpers for the auth screens.
enum AuthValidation {
    /// Basic RFC-5322-ish regex. Good enough as a client gate; Supabase is
    /// the authoritative validator.
    static func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }
}
