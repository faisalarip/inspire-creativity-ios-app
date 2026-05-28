//
//  Difficulty.swift
//  InspireCreativityApp
//

import Foundation

/// Skill level required to use an animation.
enum Difficulty: String, Codable, Hashable, CaseIterable {
    case beginner
    case intermediate
    case advanced
}
