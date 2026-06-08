//
//  AuroraPackPromoCard.swift
//  InspireCreativityApp
//
//  Promotional card on the Discover screen advertising the 7-piece pack.
//

import SwiftUI

struct AuroraPackPromoCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .leading) {
                LinearGradient(
                    colors: [
                        Color(red: 0.18, green: 0.05, blue: 0.22),
                        Color(red: 0.05, green: 0.05, blue: 0.18)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )

                // Background preview reel
                HStack(spacing: 0) {
                    Spacer()
                    AnimationPreviewRegistry.view(for: "aurora-borealis")
                        .frame(width: 160)
                        .opacity(0.85)
                        .blur(radius: 0.2)
                }

                LinearGradient(
                    colors: [
                        Color(red: 0.18, green: 0.05, blue: 0.22).opacity(0.9),
                        .clear
                    ],
                    startPoint: .leading, endPoint: .trailing
                )

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles").font(.system(size: 10))
                        Text("INSPIRECREATIVITY PRO")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(1.2)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: [Theme.Palette.accent.opacity(0.4), .purple.opacity(0.4)],
                            startPoint: .leading, endPoint: .trailing
                        ),
                        in: Capsule()
                    )

                    Text("The Aurora Collection")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(.white)

                    Text("Lush mesh-gradient surfaces — unlock them and the entire library with Pro.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                }
                .padding(18)
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Unlock the Aurora Collection with InspireCreativity Pro")
    }
}
