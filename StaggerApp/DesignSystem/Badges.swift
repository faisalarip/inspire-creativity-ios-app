//
//  Badges.swift
//  StaggerApp
//

import SwiftUI

/// Generic capsule badge with custom tinting.
struct Badge: View {
    let text: String
    let icon: String?
    let foreground: Color
    let background: Color

    init(
        _ text: String,
        icon: String? = nil,
        foreground: Color = Color.white.opacity(0.8),
        background: Color = Color.white.opacity(0.07)
    ) {
        self.text = text
        self.icon = icon
        self.foreground = foreground
        self.background = background
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon).font(.system(size: 9, weight: .bold))
            }
            Text(text).font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .foregroundStyle(foreground)
        .background(background, in: Capsule())
    }
}

/// Three-bar difficulty indicator badge.
struct DifficultyBadge: View {
    let level: Difficulty

    var body: some View {
        let colors = colorPair(for: level)
        HStack(spacing: 4) {
            HStack(spacing: 1) {
                ForEach(0..<3, id: \.self) { i in
                    Rectangle()
                        .fill(filled(at: i) ? colors.fg : Color.white.opacity(0.15))
                        .frame(width: 3, height: 3)
                        .cornerRadius(1)
                }
            }
            Text(level.rawValue.capitalized)
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .foregroundStyle(colors.fg)
        .background(colors.bg, in: Capsule())
    }

    private func filled(at index: Int) -> Bool {
        switch level {
        case .beginner: return index == 0
        case .intermediate: return index <= 1
        case .advanced: return index <= 2
        }
    }

    private func colorPair(for level: Difficulty) -> (fg: Color, bg: Color) {
        switch level {
        case .beginner:
            return (.green, Color.green.opacity(0.18))
        case .intermediate:
            return (Theme.Palette.proGoldStart, Theme.Palette.proGoldStart.opacity(0.18))
        case .advanced:
            return (Color(red: 1.0, green: 0.55, blue: 0.36), Theme.Palette.accent.opacity(0.2))
        }
    }
}
