//
//  AnimationItem.swift
//  StaggerApp
//
//  Domain entity describing a single animation in the catalog.
//  Pure value type — no UI imports, lives in the domain layer.
//

import Foundation

/// A single animation entry in the catalog.
///
/// Mirrors the shape of the prototype's `ANIMATIONS` array entries
/// plus its `SWIFT_CODE` lookup (collapsed into one entity here).
struct AnimationItem: Identifiable, Hashable {

    // MARK: - Identity & taxonomy
    let id: String
    let name: String
    let category: Category
    let difficulty: Difficulty
    let iosVersion: String          // "17+", "18+", etc.
    let isPro: Bool
    let isFeatured: Bool

    // MARK: - Visuals
    /// Hex string for the preview tile tint (e.g. "#1e1e22").
    let tintHex: String

    // MARK: - Author & marketplace metadata
    let author: String
    let handle: String
    let downloads: Int
    let rating: Double
    let price: Double?              // nil → free
    let description: String

    // MARK: - Code
    let swiftCode: String

    // MARK: - Computed
    var isFree: Bool { price == nil }
    var priceLabel: String { isFree ? "Free" : String(format: "$%.2f", price ?? 0) }
}
