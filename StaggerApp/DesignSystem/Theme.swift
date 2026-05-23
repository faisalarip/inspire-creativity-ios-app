//
//  Theme.swift
//  StaggerApp
//
//  Centralized design tokens — colors, spacing, radii, typography.
//  Matches the prototype's dark palette and #FF6B4A accent.
//

import SwiftUI

/// Static design tokens used across the app.
/// Treat this as a tree-shakeable namespace — no instances, no state.
enum Theme {

    // MARK: - Colors

    enum Palette {
        /// Primary canvas background. Matches prototype `#0a0a0c`.
        static let background = Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0C / 255)

        /// Slightly raised surface (cards, sheets).
        static let surface = Color(red: 0x18 / 255, green: 0x18 / 255, blue: 0x1B / 255)

        /// Card fill — `rgba(255,255,255,0.03)`.
        static let cardFill = Color.white.opacity(0.03)

        /// Hairline border — `rgba(255,255,255,0.06)`.
        static let hairline = Color.white.opacity(0.06)

        /// Accent (primary orange-red) — `#FF6B4A`.
        static let accent = Color(red: 0xFF / 255, green: 0x6B / 255, blue: 0x4A / 255)

        /// Secondary accent for the Pro gradient — `#FFC857` → `#FF8E3C`.
        static let proGoldStart = Color(red: 0xFF / 255, green: 0xC8 / 255, blue: 0x57 / 255)
        static let proGoldEnd   = Color(red: 0xFF / 255, green: 0x8E / 255, blue: 0x3C / 255)

        /// Success green — `#34c759`.
        static let success = Color(red: 0x34 / 255, green: 0xC7 / 255, blue: 0x59 / 255)

        /// Primary text on dark.
        static let textPrimary = Color.white

        /// Secondary text — `rgba(255,255,255,0.55)`.
        static let textSecondary = Color.white.opacity(0.55)

        /// Tertiary text — `rgba(255,255,255,0.4)`.
        static let textTertiary = Color.white.opacity(0.40)

        /// iOS badge blue tint.
        static let iosBlue = Color(red: 0x7A / 255, green: 0xC1 / 255, blue: 0xFF / 255)
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 6
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 14
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 20
        static let xxxl: CGFloat = 24
    }

    // MARK: - Radii

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 10
        static let lg: CGFloat = 12
        static let xl: CGFloat = 14
        static let xxl: CGFloat = 16
        static let card: CGFloat = 14
        static let sheet: CGFloat = 22
    }

    // MARK: - Typography

    enum Typo {
        /// Large title, ~30–34pt, 800 weight.
        static let largeTitle = Font.system(size: 32, weight: .heavy, design: .default)
        /// Section header (19pt, 700).
        static let sectionTitle = Font.system(size: 19, weight: .bold)
        /// Card title (14pt, 600).
        static let cardTitle = Font.system(size: 14, weight: .semibold)
        /// Body 15.
        static let body = Font.system(size: 15, weight: .regular)
        /// Secondary 13.
        static let caption = Font.system(size: 13, weight: .regular)
        /// Tiny meta 11.
        static let meta = Font.system(size: 11, weight: .medium)

        /// Mono — used for prices, IDs, code.
        static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .monospaced)
        }
    }
}
