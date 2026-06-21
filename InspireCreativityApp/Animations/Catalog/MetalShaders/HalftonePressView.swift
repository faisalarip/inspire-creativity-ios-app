// catalog-id: mtl-halftone-press
// catalog-metal: HalftonePressView.metal
import SwiftUI

// MARK: - Halftone Press
// Reduces underlying content to a rotating-grid duotone halftone of dots whose
// radius tracks local luminance (dark = big dot, light = small dot).
//   demo == false : MagnifyGesture pinches the dot frequency coarse <-> fine.
//   demo == true  : a TimelineView auto-orbits the screen angle and eases the
//                   dot size between coarse newsprint and fine continuous tone.
//
// The halftone is a Metal [[stitchable]] layerEffect (iOS 17). It is parametrized
// by *cell size in points* (not cells-across) so the physical dot size is
// identical in a 120pt grid tile and in a large detail view, and so the shader's
// maxSampleOffset stays bounded by a constant.

struct HalftonePressView: View {
    var demo: Bool = false

    // Cell-size clamps, in points. Small cell = fine screen, large cell = coarse.
    private let minCell: CGFloat = 4.0
    private let maxCell: CGFloat = 22.0

    // Persisted (folded-in) cell size for the interactive pinch.
    @State private var baseCell: CGFloat = 13.0
    // Live cell size shown during an active pinch.
    @State private var liveCell: CGFloat = 13.0

    var body: some View {
        GeometryReader { geo in
            decorated(size: geo.size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: View-level dispatch
    //
    // We branch at the View level (not the ViewModifier level): `@ViewBuilder`
    // can only fold `View` branches via buildEither, so returning two different
    // concrete `ViewModifier` types from a `some ViewModifier` func does not
    // compile. Instead we build the content once and attach the appropriate
    // concrete modifiers inside each branch.
    @ViewBuilder
    private func decorated(size: CGSize) -> some View {
        let base = content(size: size)
            .frame(width: size.width, height: size.height)

        if demo {
            base.modifier(HalftonePressView_DemoHalftone(size: size, minCell: minCell, maxCell: maxCell))
        } else {
            base
                .modifier(HalftonePressView_StaticHalftone(size: size, cell: liveCell))
                .contentShape(Rectangle())
                .modifier(
                    HalftonePressView_PinchInteraction(
                        baseCell: $baseCell,
                        liveCell: $liveCell,
                        minCell: minCell,
                        maxCell: maxCell
                    )
                )
        }
    }

    // MARK: Source content (rich tonal range so dots track luminance)

    private func content(size: CGSize) -> some View {
        let dim = min(size.width, size.height)
        return ZStack {
            // Bright paper-tone backdrop with a soft tonal falloff.
            RadialGradient(
                colors: [
                    Color(red: 0.98, green: 0.97, blue: 0.94),
                    Color(red: 0.62, green: 0.66, blue: 0.74)
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: dim * 1.3
            )

            // A diagonal mid-tone sweep adds gradient energy across the frame.
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.12, blue: 0.18).opacity(0.0),
                    Color(red: 0.10, green: 0.12, blue: 0.18).opacity(0.85)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Overlapping dark shapes give crisp tonal masses for big comic dots.
            Circle()
                .fill(Color(red: 0.05, green: 0.06, blue: 0.09))
                .frame(width: dim * 0.52, height: dim * 0.52)
                .offset(x: -dim * 0.16, y: dim * 0.18)

            Image(systemName: "drop.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color(red: 0.02, green: 0.03, blue: 0.05))
                .frame(width: dim * 0.46, height: dim * 0.46)
                .offset(x: dim * 0.14, y: -dim * 0.08)

            // A bright highlight keeps the light end of the tonal range alive.
            Circle()
                .fill(Color(red: 1.0, green: 0.98, blue: 0.92))
                .frame(width: dim * 0.22, height: dim * 0.22)
                .blur(radius: dim * 0.02)
                .offset(x: dim * 0.22, y: dim * 0.24)
        }
    }
}

// MARK: - Static (interactive) halftone modifier

private struct HalftonePressView_StaticHalftone: ViewModifier {
    let size: CGSize
    let cell: CGFloat

    func body(content: Content) -> some View {
        content.layerEffect(
            ShaderLibrary.halftonePress(
                .float2(Float(size.width), Float(size.height)),
                .float(Float(cell)),
                .float(0.0), // fixed screen angle in interactive mode
                .float3(0.06, 0.07, 0.10), // ink (dark duotone)
                .float3(0.97, 0.96, 0.93)  // paper (light duotone)
            ),
            maxSampleOffset: CGSize(width: 24, height: 24)
        )
    }
}

// MARK: - Demo (self-driving) halftone modifier

private struct HalftonePressView_DemoHalftone: ViewModifier {
    let size: CGSize
    let minCell: CGFloat
    let maxCell: CGFloat

    func body(content: Content) -> some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let cell = demoCell(t)
            let angle = demoAngle(t)

            content.layerEffect(
                ShaderLibrary.halftonePress(
                    .float2(Float(size.width), Float(size.height)),
                    .float(Float(cell)),
                    .float(Float(angle)),
                    .float3(0.06, 0.07, 0.10),
                    .float3(0.97, 0.96, 0.93)
                ),
                maxSampleOffset: CGSize(width: 24, height: 24)
            )
        }
    }

    // Ease cell size coarse <-> fine on a ~3.4s loop, never degenerate.
    private func demoCell(_ t: Double) -> CGFloat {
        let phase = (sin(t * (2.0 * .pi / 3.4)) + 1.0) / 2.0 // 0...1
        let eased = phase * phase * (3.0 - 2.0 * phase)      // smoothstep
        return minCell + (maxCell - minCell) * CGFloat(eased)
    }

    // Slowly orbit the screen angle so the dot grid rotates in place.
    private func demoAngle(_ t: Double) -> CGFloat {
        CGFloat(t * 0.22)
    }
}

// MARK: - Pinch interaction modifier

private struct HalftonePressView_PinchInteraction: ViewModifier {
    @Binding var baseCell: CGFloat
    @Binding var liveCell: CGFloat
    let minCell: CGFloat
    let maxCell: CGFloat

    func body(content: Content) -> some View {
        content.gesture(
            MagnifyGesture()
                .onChanged { value in
                    // Pinch out (magnification > 1) -> smaller cell -> finer screen.
                    liveCell = clamp(baseCell / CGFloat(value.magnification))
                }
                .onEnded { value in
                    // Fold the gesture into the base so the screen holds on release.
                    baseCell = clamp(baseCell / CGFloat(value.magnification))
                    liveCell = baseCell
                }
        )
    }

    private func clamp(_ v: CGFloat) -> CGFloat {
        min(max(v, minCell), maxCell)
    }
}
