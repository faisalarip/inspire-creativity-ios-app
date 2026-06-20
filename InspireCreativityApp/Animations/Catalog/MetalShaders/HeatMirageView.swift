//
//  HeatMirageView.swift
//  InspireCreativityApp — Bespoke catalog animation (Metal Shaders)
//
//  Heat Mirage: pixels bend with stacked noise octaves to create rising
//  heat-shimmer, with an intensity hotspot you drag to "aim the heat". Left
//  alone, a thermal column wanders up the view.
//
//  Requires the companion `HeatMirage.metal` in the same target.
//  `demo == true`  → self-driving wandering hotspot (grid tile).
//  `demo == false` → DragGesture aims the hotspot (Detail + the buyer's code).
//

// catalog-id: mtl-heat-mirage
// catalog-metal: HeatMirage.metal
import SwiftUI

struct HeatMirageView: View {
    var demo: Bool = false
    @State private var hotspot: CGPoint = .zero
    @State private var intensity: CGFloat = 0.6

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { ctx in
                let time = ctx.date.timeIntervalSinceReferenceDate
                let spot = demo ? Self.wander(time, in: geo.size) : effectiveHotspot(geo.size)
                heatContent
                    .distortionEffect(
                        ShaderLibrary.heatMirage(
                            .float(Float(time.truncatingRemainder(dividingBy: 1000))),
                            .float2(Float(spot.x), Float(spot.y)),
                            .float(Float(demo ? 1.0 : intensity))
                        ),
                        maxSampleOffset: CGSize(width: 14, height: 14)
                    )
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard !demo else { return }
                        hotspot = value.location
                        intensity = 1.0
                    }
                    .onEnded { _ in
                        guard !demo else { return }
                        withAnimation(.easeOut(duration: 0.8)) { intensity = 0.45 }
                    }
            )
        }
    }

    private func effectiveHotspot(_ size: CGSize) -> CGPoint {
        hotspot == .zero ? CGPoint(x: size.width / 2, y: size.height * 0.6) : hotspot
    }

    private var heatContent: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.55, blue: 0.12),
                         Color(red: 0.55, green: 0.10, blue: 0.20),
                         .black],
                startPoint: .top, endPoint: .bottom
            )
            VStack {
                Spacer()
                Text("HEAT")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    static func wander(_ t: TimeInterval, in size: CGSize) -> CGPoint {
        CGPoint(x: (sin(t * 0.5) * 0.5 + 0.5) * size.width,
                y: (cos(t * 0.37) * 0.5 + 0.5) * size.height)
    }
}
