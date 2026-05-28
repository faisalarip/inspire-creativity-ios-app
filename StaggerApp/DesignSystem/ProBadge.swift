//
//  ProBadge.swift
//  InspireCreativityApp
//

import SwiftUI

/// Small gold gradient pill that marks an animation as "Pro".
struct ProBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .font(.system(size: 7, weight: .bold))
            Text("PRO")
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.5)
        }
        .foregroundStyle(Color(red: 0x1A / 255, green: 0x0E / 255, blue: 0))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            LinearGradient(
                colors: [Theme.Palette.proGoldStart, Theme.Palette.proGoldEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .accessibilityLabel("Pro animation")
    }
}

#Preview {
    ProBadge()
        .padding()
        .background(Theme.Palette.background)
}
