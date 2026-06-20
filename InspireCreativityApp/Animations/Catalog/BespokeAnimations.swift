//
//  BespokeAnimations.swift
//  InspireCreativityApp
//
//  Central registration for the bespoke catalog animations. Each entry maps a
//  catalog id to two preview builders:
//   • grid        — the self-driving demo loop shown in grid tiles (demo: true)
//   • interactive — the real, finger-driven component shown in Detail (demo: false)
//
//  Integration appends one `.init(...)` line per animation. The per-animation
//  VIEW lives in its own file under Animations/Catalog/<Category>/.
//

import SwiftUI

struct BespokeAnimation {
    let id: String
    let grid: PreviewBuilder
    let interactive: PreviewBuilder
}

enum BespokeAnimations {

    static let all: [BespokeAnimation] = [
        .init(id: "ges-rubberband-sheet-morph",
              grid: { AnyView(RubberBandSheetMorphView(demo: true)) },
              interactive: { AnyView(RubberBandSheetMorphView(demo: false)) }),
        .init(id: "tx-shatter-glass",
              grid: { AnyView(GlassShatterSettleView(demo: true)) },
              interactive: { AnyView(GlassShatterSettleView(demo: false)) }),
        .init(id: "mtl-heat-mirage",
              grid: { AnyView(HeatMirageView(demo: true)) },
              interactive: { AnyView(HeatMirageView(demo: false)) }),
    ]

    static let gridBuilders: [String: PreviewBuilder] =
        Dictionary(all.map { ($0.id, $0.grid) }, uniquingKeysWith: { first, _ in first })

    static let interactiveBuilders: [String: PreviewBuilder] =
        Dictionary(all.map { ($0.id, $0.interactive) }, uniquingKeysWith: { first, _ in first })
}
