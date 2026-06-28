//
//  MacSidebar.swift
//  InspireCreativityApp
//

import SwiftUI

enum MacSidebarSection: Hashable, Identifiable {
    case discover
    case category(Category)
    case owned, favorites, recent

    var id: String {
        switch self {
        case .discover: "discover"
        case .category(let c): "cat-\(c.rawValue)"
        case .owned: "owned"
        case .favorites: "favorites"
        case .recent: "recent"
        }
    }

    var title: String {
        switch self {
        case .discover: "Discover"
        case .category(let c): c.displayName
        case .owned: "Owned"
        case .favorites: "Favorites"
        case .recent: "Recent"
        }
    }

    static func all(categories: [Category]) -> [MacSidebarSection] {
        [.discover] + categories.map(MacSidebarSection.category) + [.owned, .favorites, .recent]
    }
}
