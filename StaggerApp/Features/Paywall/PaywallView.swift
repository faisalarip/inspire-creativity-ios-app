//
//  PaywallView.swift
//  StaggerApp
//

import SwiftUI

struct PaywallView: View {

    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel: PaywallViewModel

    init(viewModel: PaywallViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
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
    }

    private var heroBand: some View {
        // The hero stack itself respects safe area, so the close + Restore
        // row lands below the status bar and stays tappable. Only the
        // visual background layers (gradient, grid, fade) opt into
        // .ignoresSafeArea(edges: .top) so they still bleed under the
        // status bar for the edge-to-edge look.
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

            // Top nav — respects safe area so taps don't fall under the
            // status bar's reserved hit region.
            HStack {
                IconButton("xmark") { router.pop() }
                Spacer()
                Button("Restore") {}
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
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
                Text("ENIGMA PRO")
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

    private var planPicker: some View {
        VStack(spacing: 10) {
            ForEach(PaywallViewModel.Plan.allCases) { plan in
                PlanRow(plan: plan, isActive: viewModel.plan == plan) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        viewModel.plan = plan
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 26)
    }

    private var cta: some View {
        Button {
            viewModel.subscribe()
            router.pop()
        } label: {
            Text("Start 7-day free trial")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Theme.Palette.accent, in: RoundedRectangle(cornerRadius: 14))
                .shadow(color: Theme.Palette.accent.opacity(0.35), radius: 16, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private var disclaimer: some View {
        Text("Cancel anytime. Subscription auto-renews unless turned off 24h before the trial ends. Terms · Privacy.")
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.4))
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
    }
}

private struct PlanRow: View {
    let plan: PaywallViewModel.Plan
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
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
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(plan.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                        if let badge = plan.badge {
                            Text(badge.uppercased())
                                .font(.system(size: 9, weight: .heavy))
                                .tracking(0.4)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Theme.Palette.accent, in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    Text(plan.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Text(plan.price)
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
