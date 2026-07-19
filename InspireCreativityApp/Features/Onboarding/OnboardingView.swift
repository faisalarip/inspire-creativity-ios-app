//
//  OnboardingView.swift
//  InspireCreativityApp
//
//  First-run quest (v2.1): pick what you're building → Discover tunes its
//  rows to those categories, and the copy promise is front and center.
//

import SwiftUI

struct OnboardingView: View {

    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Set<Category> = []

    private let columns = [
        GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Theme.Palette.background.ignoresSafeArea()

            AnimationPreviewRegistry.view(for: "aurora-mesh")
                .opacity(0.25)
                .ignoresSafeArea()
            LinearGradient(
                colors: [
                    Theme.Palette.background.opacity(0.6),
                    Theme.Palette.background.opacity(0.95),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                Text("What are you building?")
                    .font(.system(size: 30, weight: .heavy))
                    .tracking(-0.8)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("Pick a few and we'll tune your feed. Every free animation's code copies in one tap — no account needed.")
                    .font(.system(size: 14.5))
                    .lineSpacing(3)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.top, 8)

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Category.allCases) { category in
                        let isOn = selected.contains(category)
                        Button {
                            if isOn { selected.remove(category) } else { selected.insert(category) }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 14))
                                    .foregroundStyle(isOn ? Theme.Palette.accent : .white.opacity(0.35))
                                Text(category.displayName)
                                    .font(.system(size: 13.5, weight: .semibold))
                                    .foregroundStyle(isOn ? .white : .white.opacity(0.7))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(
                                isOn ? Theme.Palette.accent.opacity(0.14) : Color.white.opacity(0.05),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(
                                        isOn ? Theme.Palette.accent.opacity(0.5) : Color.white.opacity(0.08),
                                        lineWidth: 1
                                    )
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 22)

                Button {
                    finish(Array(selected))
                } label: {
                    Text(selected.isEmpty ? "Show me everything" : "Show me animations")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.Palette.accent, in: RoundedRectangle(cornerRadius: 15))
                }
                .buttonStyle(.plain)
                .padding(.top, 24)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)

            Button("Skip") { finish([]) }
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

    private func finish(_ categories: [Category]) {
        container.onboardingPreferences.complete(categories: categories)
        container.analytics.log(.onboardingCompleted(categoriesCount: categories.count))
        dismiss()
    }
}
