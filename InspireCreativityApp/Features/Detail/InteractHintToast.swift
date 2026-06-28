//
//  InteractHintToast.swift
//  InspireCreativityApp
//
//  Transient "Tap & drag to interact" hint shown over an interactive
//  animation preview, letting the user know the animation responds to touch.
//  Cross-platform (iOS + macOS) — no #if guards.
//

import SwiftUI

/// Transient hint shown over an interactive animation preview, letting the user
/// know the animation responds to touch (not just a passive loop).
struct InteractHintToast: View {
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 13, weight: .semibold))
            Text("Tap & drag to interact")
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        .accessibilityLabel("This preview is interactive. Tap and drag to play with the animation.")
    }
}
