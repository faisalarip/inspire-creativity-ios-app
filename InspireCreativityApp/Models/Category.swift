//
//  Category.swift
//  InspireCreativityApp
//

import Foundation

/// Top-level taxonomy for animations.
enum Category: String, Codable, Hashable, CaseIterable, Identifiable {
    case backgrounds      = "Backgrounds"
    case loaders          = "Loaders"
    case buttons          = "Buttons"
    case microInteractions = "Micro-interactions"
    case transitions      = "Transitions"
    case navigation       = "Navigation"
    case gestures         = "Gestures"
    case onboarding       = "Onboarding"
    case textEffects      = "Text effects"
    case metalShaders     = "Metal Shaders"

    var id: String { rawValue }
    var displayName: String { rawValue }
}

/// Unambiguous alias for contexts where other imported modules also declare
/// a `Category` type (e.g. the test target's transitive dependencies).
typealias AnimationCategory = Category
