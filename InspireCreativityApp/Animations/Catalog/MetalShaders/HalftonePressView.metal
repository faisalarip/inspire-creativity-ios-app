#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

// Halftone Press
// Rotating-grid duotone halftone. For each output pixel:
//   1. Rotate the pixel about the view center by +angle into "grid space".
//   2. Snap to the center of its grid cell.
//   3. Rotate that cell center back by -angle into layer space and sample
//      the layer there to read the cell's luminance.
//   4. Dot radius = f(luminance): dark cells -> big dots, light cells -> small.
//   5. Output duotone: ink inside the dot, paper outside, smoothstep edge.
//
// `cellSize` is in points, so the physical dot size is resolution-independent.
// The sample point is offset from the pixel by at most ~0.71 * cellSize, so the
// SwiftUI side sets maxSampleOffset to comfortably cover the largest cell.

[[ stitchable ]]
half4 halftonePress(float2 position,
                    SwiftUI::Layer layer,
                    float2 size,
                    float cellSize,
                    float angle,
                    float3 inkColor,
                    float3 paperColor) {
    float cell = max(cellSize, 2.0);
    float2 center = size * 0.5;

    float s = sin(angle);
    float c = cos(angle);

    // Forward-rotate the pixel about the center into grid space.
    float2 rel = position - center;
    float2 g = float2(rel.x * c - rel.y * s,
                      rel.x * s + rel.y * c);

    // Snap to the cell center in grid space.
    float2 cellCenterG = (floor(g / cell) + 0.5) * cell;

    // Back-rotate the cell center into layer space to pick the sample point.
    // Inverse rotation uses (c, +s) / (-s, c).
    float2 sampleRel = float2(cellCenterG.x * c + cellCenterG.y * s,
                              -cellCenterG.x * s + cellCenterG.y * c);
    float2 samplePos = sampleRel + center;

    // Read the cell's tone. Clamp the sample inside the view to avoid edge bleed.
    float2 clamped = clamp(samplePos, float2(0.0), size);
    half4 src = layer.sample(clamped);

    // Premultiplied-safe luminance (Rec.709), respecting alpha.
    half a = max(src.a, half(0.0001));
    half3 rgb = src.rgb / a;
    float lum = dot(float3(rgb), float3(0.2126, 0.7152, 0.0722));
    lum = clamp(lum * float(src.a), 0.0, 1.0);

    // Dot radius from inverted luminance. Max radius slightly over half the cell
    // so dark regions can fully merge into solid ink. sqrt keeps area perceptual.
    float darkness = 1.0 - lum;
    float maxR = cell * 0.72;
    float radius = sqrt(darkness) * maxR;

    // Distance from this pixel to its cell center, measured in grid space.
    float dist = distance(g, cellCenterG);

    // Smoothstep edge over ~1px for crisp but anti-aliased dots.
    float edge = 1.0;
    float mask = 1.0 - smoothstep(radius - edge, radius + edge, dist);

    float3 outRGB = mix(paperColor, inkColor, mask);
    return half4(half3(outRGB), 1.0h);
}
