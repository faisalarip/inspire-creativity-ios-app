//
//  MacCategoryStyle.swift
//  InspireCreativityApp
//
//  Tint colors and SF Symbol icon names for every Category,
//  derived from the Claude Design reference (macos-app.jsx CAT_TINT map).
//  macOS-only — wrapped in #if os(macOS).
//

#if os(macOS)
import SwiftUI

/// Static helpers that map a `Category` to its design-system tint color and
/// SF Symbol icon name.  Values are taken directly from the reference JSX.
enum MacCategoryStyle {

    // MARK: - Tint

    /// Returns the CAT_TINT hex color for the given category.
    static func tint(_ category: Category) -> Color {
        switch category {
        case .backgrounds:       return Color(hex: "#A78BFA")
        case .loaders:           return Color(hex: "#22D3EE")
        case .buttons:           return Color(hex: "#FF6B4A")
        case .microInteractions: return Color(hex: "#F472B6")
        case .transitions:       return Color(hex: "#34D399")
        case .navigation:        return Color(hex: "#60A5FA")
        case .gestures:          return Color(hex: "#FBBF24")
        case .onboarding:        return Color(hex: "#FB7185")
        case .textEffects:       return Color(hex: "#C4B5FD")
        case .metalShaders:      return Color(hex: "#F97316")
        }
    }

    // MARK: - Category icons

    /// Returns the SF Symbol name for the given category.
    static func iconName(_ category: Category) -> String {
        switch category {
        case .backgrounds:       return "photo"
        case .loaders:           return "circle.dotted"
        case .buttons:           return "capsule"
        case .microInteractions: return "sparkle"
        case .transitions:       return "arrow.left.arrow.right"
        case .navigation:        return "square.grid.2x2"
        case .gestures:          return "hand.draw"
        case .onboarding:        return "person.crop.circle"
        case .textEffects:       return "textformat"
        case .metalShaders:      return "cube"
        }
    }

    // MARK: - Navigation section icons

    /// SF Symbol for the "Discover" section.
    static let discoverIcon  = "house"
    /// SF Symbol for the "Owned" library section.
    static let ownedIcon     = "shippingbox"
    /// SF Symbol for the "Favorites" section.
    static let favoritesIcon = "heart"
    /// SF Symbol for the "Recent" section.
    static let recentIcon    = "clock"
}
#endif
