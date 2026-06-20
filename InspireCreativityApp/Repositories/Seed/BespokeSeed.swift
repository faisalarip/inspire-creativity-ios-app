//
//  BespokeSeed.swift
//  InspireCreativityApp
//
//  Catalog metadata for the bespoke animations. `swiftCode` is pulled from the
//  generated `BespokeCodeSamples` (built from each view's own source), so the
//  copied code always matches the preview. Author/downloads/rating are derived
//  deterministically from the id so listings look real without hand-authoring.
//

import Foundation

enum BespokeSeed {

    static let bespoke: [AnimationItem] = [
        make(id: "ges-rubberband-sheet-morph", name: "Rubber-Band Sheet Morph",
             category: .gestures, difficulty: .advanced, iosVersion: "17+",
             tintHex: "#0d0e16",
             description: "A bottom sheet you drag upward stretches past its rest height with rubber-band resistance, its contents re-flowing from a compact summary row into a multi-column layout as it rises, then snapping back with an overshoot spring."),
        make(id: "tx-shatter-glass", name: "Glass Shatter Settle",
             category: .textEffects, difficulty: .advanced, iosVersion: "18+",
             tintHex: "#04050a",
             description: "The headline appears as offset angular shards that fly back together from the edges, each glyph rotating and decelerating into perfect alignment with a brief chromatic edge-glint — like time-reversed breaking. (Requires iOS 18.)"),
        make(id: "mtl-heat-mirage", name: "Heat Mirage",
             category: .metalShaders, difficulty: .intermediate, iosVersion: "17+",
             tintHex: "#1a0500",
             description: "Pixels bend with stacked noise octaves to create rising heat-shimmer, with an intensity hotspot you drag to aim the heat. Left alone, a thermal column wanders up the view."),
    ]

    // MARK: - Deterministic listing factory

    private static let authors: [(String, String)] = [
        ("Yuki Tanaka", "@yuki.motion"), ("Maya Ortega", "@mortega.dev"),
        ("Kenji Saito", "@kenji.codes"), ("Aria Chen", "@aria.design"),
        ("Lena Hofstad", "@lena.swift"), ("Devon Park", "@devon.builds")
    ]

    /// All bespoke animations are Pro: the catalog's free taster is locked at
    /// exactly 20 (see `CatalogGatingTests`), so new premium content must never
    /// add to the free set. Pro price normalizes to a flat $10.
    static func make(id: String, name: String, category: Category, difficulty: Difficulty,
                     iosVersion: String, tintHex: String,
                     description: String) -> AnimationItem {
        let h = stableHash(id)
        let (author, handle) = authors[h % authors.count]
        return AnimationItem(
            id: id, name: name, category: category, difficulty: difficulty,
            iosVersion: iosVersion, isPro: true, isFeatured: false, tintHex: tintHex,
            author: author, handle: handle,
            downloads: 1_800 + (h % 18_000),
            rating: 4.5 + Double(h % 5) * 0.1,
            price: 10,
            description: description,
            swiftCode: BespokeCodeSamples.code(for: id)
        )
    }

    /// FNV-1a over the id — stable across launches (unlike `String.hashValue`).
    private static func stableHash(_ s: String) -> Int {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in s.utf8 { hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211 }
        return Int(hash & 0x7FFF_FFFF)
    }
}
