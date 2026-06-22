//
//  PaywallView.swift
//  InspireCreativityApp
//

import SwiftUI

struct PaywallView: View {

    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel: PaywallViewModel

    /// Where the user opened the paywall from (e.g. "detail", "settings",
    /// "promo", "library"). Logged as the `paywall_viewed` source.
    private let source: String

    init(viewModel: PaywallViewModel, source: String) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.source = source
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroBand
                pitch
                features
                planPicker
                cta
                disclaimer
            }
        }
        .background(Theme.Palette.background.ignoresSafeArea())
        .onChange(of: viewModel.didComplete) { _, done in
            if done { router.pop() }
        }
        .onAppear {
            container.analytics.log(.paywallViewed(source: source))
        }
    }

    private var heroBand: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    Color(red: 0.16, green: 0.08, blue: 0.06),
                    Theme.Palette.background
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 260)
            .ignoresSafeArea(edges: .top)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3),
                      spacing: 6) {
                ForEach([
                    "aurora-mesh", "hologram-card", "liquid-heart",
                    "morphing-fab", "aurora-borealis", "elastic-tabs"
                ], id: \.self) { id in
                    ZStack {
                        Color.black
                        AnimationPreviewRegistry.view(for: id)
                    }
                    .frame(height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .opacity(0.6)
                }
            }
            .padding(8)
            .frame(height: 260)
            .ignoresSafeArea(edges: .top)

            LinearGradient(
                colors: [.clear, Theme.Palette.background],
                startPoint: .center, endPoint: .bottom
            )
            .frame(height: 260)
            .ignoresSafeArea(edges: .top)

            HStack {
                IconButton("xmark") { router.pop() }
                Spacer()
                Button {
                    Task { await viewModel.restore() }
                } label: {
                    Text("Restore")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .disabled(viewModel.isPurchasing)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
        .frame(height: 260)
    }

    private var pitch: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: "star.fill").font(.system(size: 10))
                Text("INSPIRECREATIVITY PRO")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.5)
            }
            .foregroundStyle(Color(red: 0x1A / 255, green: 0x0E / 255, blue: 0))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(
                LinearGradient(
                    colors: [Theme.Palette.proGoldStart, Theme.Palette.proGoldEnd],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                in: Capsule()
            )

            Text("Every animation,\nforever.")
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(.white)
                .lineSpacing(2)

            Text("Stop reinventing the spring curve. Get the entire library and ship delight in your next app.")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.65))
                .lineSpacing(2)
        }
        .padding(.horizontal, 24)
        .padding(.top, -20)
    }

    private var features: some View {
        VStack(spacing: 14) {
            ForEach(viewModel.features) { feature in
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Theme.Palette.success.opacity(0.15))
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(Theme.Palette.success)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(feature.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(feature.subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 26)
    }

    @ViewBuilder
    private var planPicker: some View {
        if viewModel.isLoadingProducts {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .frame(maxWidth: .infinity)
                .padding(.top, 30)
        } else if viewModel.productsUnavailable {
            VStack(spacing: 6) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.5))
                Text("Pricing unavailable")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Check your connection and try again.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
                Button("Retry") { Task { await viewModel.store.loadProducts() } }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.accent)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 30)
        } else {
            VStack(spacing: 10) {
                let plans = PaywallViewModel.Plan.allCases
                ForEach(plans) { plan in
                    PlanRow(
                        title: plan.title,
                        subtitle: viewModel.subtitle(for: plan),
                        price: viewModel.displayPrice(for: plan),
                        badge: plan.badge,
                        isActive: viewModel.plan == plan,
                        showsSelector: plans.count > 1
                    ) {
                        withAnimation(.easeOut(duration: 0.18)) {
                            viewModel.plan = plan
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 26)
        }
    }

    @ViewBuilder
    private var cta: some View {
        VStack(spacing: 10) {
            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(red: 1.0, green: 0.5, blue: 0.5))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            Button {
                Task { await viewModel.purchaseSelected() }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isPurchasing {
                        ProgressView().progressViewStyle(.circular).tint(.white)
                    }
                    Text(viewModel.isPurchasing ? "Processing…" : viewModel.ctaTitle)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Theme.Palette.accent, in: RoundedRectangle(cornerRadius: 14))
                .shadow(color: Theme.Palette.accent.opacity(0.35), radius: 16, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isPurchasing || viewModel.productsUnavailable || viewModel.product(for: viewModel.plan) == nil)
            .opacity((viewModel.productsUnavailable || viewModel.product(for: viewModel.plan) == nil) ? 0.5 : 1)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private var disclaimer: some View {
        VStack(spacing: 8) {
            Text(viewModel.disclosure)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            HStack(spacing: 6) {
                Link("Terms of Use", destination: AppLinks.termsURL)
                Text("·").foregroundStyle(.white.opacity(0.3))
                Link("Privacy Policy", destination: AppLinks.privacyURL)
            }
            .font(.system(size: 11, weight: .semibold))
            .tint(.white.opacity(0.6))
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
    }
}

private struct PlanRow: View {
    let title: String
    let subtitle: String
    let price: String
    let badge: String?
    let isActive: Bool
    var showsSelector: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if showsSelector {
                    ZStack {
                        Circle()
                            .strokeBorder(
                                isActive ? Theme.Palette.accent : Color.white.opacity(0.25),
                                lineWidth: 2
                            )
                            .frame(width: 20, height: 20)
                        if isActive {
                            Circle()
                                .fill(Theme.Palette.accent)
                                .frame(width: 9, height: 9)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                        if let badge {
                            Text(badge.uppercased())
                                .font(.system(size: 9, weight: .heavy))
                                .tracking(0.4)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Theme.Palette.accent, in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Text(price)
                    .font(Theme.Typo.mono(16, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(14)
            .background(
                isActive ? Theme.Palette.accent.opacity(0.08) : Color.white.opacity(0.02),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        isActive ? Theme.Palette.accent : Color.white.opacity(0.1),
                        lineWidth: isActive ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
