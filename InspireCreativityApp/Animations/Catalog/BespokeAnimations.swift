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
                .init(id: "ges-accordion-fold-list",
              grid: { AnyView(AccordionFoldListView(demo: true)) },
              interactive: { AnyView(AccordionFoldListView(demo: false)) }),
        .init(id: "ges-crumple-dismiss",
              grid: { AnyView(CrumpleDismissView(demo: true)) },
              interactive: { AnyView(CrumpleDismissView(demo: false)) }),
        .init(id: "ges-drag-elastic-grid-warp",
              grid: { AnyView(DragElasticGridWarpView(demo: true)) },
              interactive: { AnyView(DragElasticGridWarpView(demo: false)) }),
        .init(id: "ges-drag-liquid-fill-tilt",
              grid: { AnyView(DragLiquidFillTiltView(demo: true)) },
              interactive: { AnyView(DragLiquidFillTiltView(demo: false)) }),
        .init(id: "ges-drag-reorder-spring",
              grid: { AnyView(DragReorderSpringView(demo: true)) },
              interactive: { AnyView(DragReorderSpringView(demo: false)) }),
        .init(id: "ges-drag-rope-bridge",
              grid: { AnyView(DragRopeBridgeView(demo: true)) },
              interactive: { AnyView(DragRopeBridgeView(demo: false)) }),
        .init(id: "ges-drag-spring-net",
              grid: { AnyView(DragSpringNetView(demo: true)) },
              interactive: { AnyView(DragSpringNetView(demo: false)) }),
        .init(id: "ges-edge-swipe-page-curl",
              grid: { AnyView(EdgeSwipePageCurlView(demo: true)) },
              interactive: { AnyView(EdgeSwipePageCurlView(demo: false)) }),
        .init(id: "mi-bubble-wrap-pop",
              grid: { AnyView(BubbleWrapPopView(demo: true)) },
              interactive: { AnyView(BubbleWrapPopView(demo: false)) }),
        .init(id: "mi-copy-shred",
              grid: { AnyView(CopyShredView(demo: true)) },
              interactive: { AnyView(CopyShredView(demo: false)) }),
        .init(id: "mi-copy-vanish",
              grid: { AnyView(CopyVanishView(demo: true)) },
              interactive: { AnyView(CopyVanishView(demo: false)) }),
        .init(id: "btn-accordion-stretch",
              grid: { AnyView(AccordionStretchView(demo: true)) },
              interactive: { AnyView(AccordionStretchView(demo: false)) }),
        .init(id: "btn-blinds-reveal",
              grid: { AnyView(BlindsRevealView(demo: true)) },
              interactive: { AnyView(BlindsRevealView(demo: false)) }),
        .init(id: "tr-clock-pie-wipe",
              grid: { AnyView(ClockPieWipeView(demo: true)) },
              interactive: { AnyView(ClockPieWipeView(demo: false)) }),
        .init(id: "tr-column-slat-slide",
              grid: { AnyView(ColumnSlatSlideView(demo: true)) },
              interactive: { AnyView(ColumnSlatSlideView(demo: false)) }),
        .init(id: "tx-confetti-letters",
              grid: { AnyView(ConfettiLettersView(demo: true)) },
              interactive: { AnyView(ConfettiLettersView(demo: false)) }),
        .init(id: "ld-bouncing-payload",
              grid: { AnyView(BouncingPayloadView(demo: true)) },
              interactive: { AnyView(BouncingPayloadView(demo: false)) }),
        .init(id: "nav-arc-fan-menu",
              grid: { AnyView(ArcFanMenuView(demo: true)) },
              interactive: { AnyView(ArcFanMenuView(demo: false)) }),
        .init(id: "ges-fling-paper-plane",
              grid: { AnyView(FlingPaperPlaneView(demo: true)) },
              interactive: { AnyView(FlingPaperPlaneView(demo: false)) }),
        .init(id: "ges-fling-pinball-bumpers",
              grid: { AnyView(FlingPinballBumpersView(demo: true)) },
              interactive: { AnyView(FlingPinballBumpersView(demo: false)) }),
        .init(id: "ges-fling-spinner-coast",
              grid: { AnyView(FlingSpinnerCoastView(demo: true)) },
              interactive: { AnyView(FlingSpinnerCoastView(demo: false)) }),
        .init(id: "ges-gravity-bin-toss",
              grid: { AnyView(GravityBinTossView(demo: true)) },
              interactive: { AnyView(GravityBinTossView(demo: false)) }),
        .init(id: "ges-hold-charge-burst",
              grid: { AnyView(HoldChargeBurstView(demo: true)) },
              interactive: { AnyView(HoldChargeBurstView(demo: false)) }),
        .init(id: "ges-hold-drag-slingshot-aim",
              grid: { AnyView(HoldDragSlingshotAimView(demo: true)) },
              interactive: { AnyView(HoldDragSlingshotAimView(demo: false)) }),
        .init(id: "ges-inertial-marble-throw",
              grid: { AnyView(InertialMarbleThrowView(demo: true)) },
              interactive: { AnyView(InertialMarbleThrowView(demo: false)) }),
        .init(id: "ges-jelly-drag-blob",
              grid: { AnyView(JellyDragBlobView(demo: true)) },
              interactive: { AnyView(JellyDragBlobView(demo: false)) }),
        .init(id: "ges-long-press-melt",
              grid: { AnyView(LongPressMeltView(demo: true)) },
              interactive: { AnyView(LongPressMeltView(demo: false)) }),
        .init(id: "ges-magnetic-cursor-ferrofluid",
              grid: { AnyView(MagneticCursorFerrofluidView(demo: true)) },
              interactive: { AnyView(MagneticCursorFerrofluidView(demo: false)) }),
        .init(id: "ges-peel-away-card",
              grid: { AnyView(PeelAwayCardView(demo: true)) },
              interactive: { AnyView(PeelAwayCardView(demo: false)) }),
        .init(id: "ges-pinch-collapse-grid",
              grid: { AnyView(PinchCollapseGridView(demo: true)) },
              interactive: { AnyView(PinchCollapseGridView(demo: false)) }),
        .init(id: "ges-pinch-focus-depth",
              grid: { AnyView(PinchFocusDepthView(demo: true)) },
              interactive: { AnyView(PinchFocusDepthView(demo: false)) }),
        .init(id: "ges-pinch-origami-crane",
              grid: { AnyView(PinchOrigamiCraneView(demo: true)) },
              interactive: { AnyView(PinchOrigamiCraneView(demo: false)) }),
        .init(id: "ges-pinch-zoom-clamp-frame",
              grid: { AnyView(PinchZoomClampFrameView(demo: true)) },
              interactive: { AnyView(PinchZoomClampFrameView(demo: false)) }),
        .init(id: "ges-rotate-clock-rewind",
              grid: { AnyView(RotateClockRewindView(demo: true)) },
              interactive: { AnyView(RotateClockRewindView(demo: false)) }),
        .init(id: "ges-rotate-combination-lock",
              grid: { AnyView(RotateCombinationLockView(demo: true)) },
              interactive: { AnyView(RotateCombinationLockView(demo: false)) }),
        .init(id: "ges-rotate-dial-knob",
              grid: { AnyView(RotateDialKnobView(demo: true)) },
              interactive: { AnyView(RotateDialKnobView(demo: false)) }),
        .init(id: "ges-rotate-gear-train",
              grid: { AnyView(RotateGearTrainView(demo: true)) },
              interactive: { AnyView(RotateGearTrainView(demo: false)) }),
// BESPOKE-REGISTRATION-INSERT (Tools/integrate_batch.py appends above this line)
    ]

    static let gridBuilders: [String: PreviewBuilder] =
        Dictionary(all.map { ($0.id, $0.grid) }, uniquingKeysWith: { first, _ in first })

    static let interactiveBuilders: [String: PreviewBuilder] =
        Dictionary(all.map { ($0.id, $0.interactive) }, uniquingKeysWith: { first, _ in first })
}
