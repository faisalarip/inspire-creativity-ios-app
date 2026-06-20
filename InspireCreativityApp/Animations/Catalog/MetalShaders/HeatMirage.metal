//
//  HeatMirage.metal
//  InspireCreativityApp — Bespoke catalog animation (Metal Shaders)
//
//  Companion shader for HeatMirageView. A `[[ stitchable ]]` distortion that
//  offsets each sample coordinate by summed noise octaves scrolling upward to
//  fake rising heat-shimmer, with an intensity hotspot.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]]
float2 heatMirage(float2 position, float time, float2 hotspot, float intensity) {
    float2 p = position;
    float wave = sin(p.y * 0.06 - time * 3.0) * 2.0
               + sin(p.y * 0.13 - time * 5.0) * 1.2
               + sin(p.x * 0.05 + time * 2.0) * 0.8;
    float d = distance(p, hotspot);
    float falloff = exp(-d * 0.004) * intensity;
    p.x += wave * (0.6 + falloff * 5.0);
    p.y -= falloff * 3.0;
    return p;
}
