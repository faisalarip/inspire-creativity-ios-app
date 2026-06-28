//
//  AnalyticsConsentPrompt.swift
//  InspireCreativityApp
//
//  Lightweight first-run analytics consent prompt for EEA/UK users.
//  Shown once via the `analyticsConsentGate(container:)` view modifier
//  applied at both the iOS RootView and macOS MacRootView shell roots.
//

import SwiftUI

// MARK: - Consent prompt sheet

/// A compact sheet explaining anonymous analytics and offering Allow / Not Now.
struct AnalyticsConsentPrompt: View {

    let onDecision: (AnalyticsConsent.Decision) -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(Theme.Palette.accent)

                Text("Help improve InspireCreativity")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("We collect anonymous usage analytics to understand which animations you love and to make the app better. No personal data is shared with third parties.")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            VStack(spacing: 12) {
                Button {
                    onDecision(.granted)
                } label: {
                    Text("Allow analytics")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Theme.Palette.accent, in: RoundedRectangle(cornerRadius: 13))
                }
                .buttonStyle(.plain)

                Button {
                    onDecision(.denied)
                } label: {
                    Text("Not now")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(28)
        .background(Theme.Palette.background)
        .preferredColorScheme(.dark)
    }
}

// MARK: - View modifier

private struct AnalyticsConsentGateModifier: ViewModifier {

    @EnvironmentObject private var container: AppContainer
    @State private var showPrompt = false

    func body(content: Content) -> some View {
        content
            .onAppear { checkIfPromptNeeded() }
            .sheet(isPresented: $showPrompt) {
                AnalyticsConsentPrompt { decision in
                    let region = Locale.current.region?.identifier
                    AnalyticsConsent.storeDecision(decision)
                    let enabled = UserDefaults.standard.object(forKey: AnalyticsConsent.analyticsEnabledKey) as? Bool ?? true
                    container.analytics.setCollectionEnabled(
                        AnalyticsConsent.collectionAllowed(
                            regionCode: region,
                            decision: decision,
                            analyticsEnabled: enabled
                        )
                    )
                    showPrompt = false
                }
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.hidden)
                // Require an explicit tap — drag-to-dismiss would leave the decision
                // in the undecided state, causing the prompt to re-appear next launch.
                .interactiveDismissDisabled(true)
            }
    }

    private func checkIfPromptNeeded() {
        let region = Locale.current.region?.identifier
        let decision = AnalyticsConsent.storedDecision()
        showPrompt = AnalyticsConsent.needsPrompt(regionCode: region, decision: decision)
    }
}

extension View {
    /// Presents the EEA/UK analytics consent prompt on first launch when needed.
    /// Safe to apply on any platform — only shows if the device locale is EEA/UK
    /// and no prior decision is stored.
    func analyticsConsentGate() -> some View {
        modifier(AnalyticsConsentGateModifier())
    }
}
