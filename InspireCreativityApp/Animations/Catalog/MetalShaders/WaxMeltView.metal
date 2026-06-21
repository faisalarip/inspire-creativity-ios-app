#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// A cheap deterministic hash → [0,1), used per-column so each vertical strand
// of "wax" drips a different length, giving the molten-strand look.
static float wm_hash(float x) {
    return fract(sin(x * 127.1) * 43758.5453);
}

// Smooth value noise across columns (interpolate between neighbouring hashes)
// so adjacent columns relate and the drips read as fluid rather than jagged.
static float wm_columnNoise(float u) {
    float i = floor(u);
    float f = fract(u);
    float a = wm_hash(i);
    float b = wm_hash(i + 1.0);
    float s = f * f * (3.0 - 2.0 * f); // smoothstep
    return mix(a, b, s);
}

// Distortion entry point.
// Returns the SOURCE coordinate to sample FROM. To make content droop DOWNWARD,
// we sample from ABOVE the current pixel (y - drip): each output row pulls in
// content from higher up, so the picture slides toward the floor.
//
// position : view-local points (NOT 0..1 UV)
// time     : seconds, for a slow live shimmer in the strands
// melt     : 0 (solid) … 1 (fully molten)
// size     : view size in points, to normalize the per-column frequency
[[ stitchable ]]
float2 waxMelt(float2 position, float time, float melt, float2 size) {
    if (melt <= 0.0001) {
        return position;
    }

    float w = max(size.x, 1.0);
    float h = max(size.y, 1.0);

    // Normalized horizontal position → a few dozen strand columns across the view.
    float columns = 26.0;
    float u = (position.x / w) * columns;

    // Per-column drip weight in [0,1]; mix two octaves + a slow time shimmer so
    // strands writhe gently while molten.
    float n = wm_columnNoise(u);
    float n2 = wm_columnNoise(u * 2.37 + 11.0);
    float colWeight = mix(n, n2, 0.35);
    colWeight = mix(0.30, 1.0, colWeight); // keep every column dripping a little

    float shimmer = 0.5 + 0.5 * sin(time * 1.7 + u * 1.3);
    colWeight *= mix(0.85, 1.0, shimmer);

    // Vertical falloff: top barely moves, bottom sags most (gravity pools the
    // wax toward the floor).
    float v = position.y / h;                 // 0 at top … 1 at bottom
    float gravity = v * v;                    // accelerate downward

    // Eased melt so the onset is gentle then runs.
    float m = melt * melt * (3.0 - 2.0 * melt);

    // Max strand length scales with melt; capped near the view height so the
    // furthest sample stays within the maxSampleOffset we declared on the view.
    float maxDrip = h * 0.92;
    float drip = maxDrip * m * gravity * colWeight;

    // Sample from above → content moves down.
    float sourceY = position.y - drip;

    // Subtle horizontal wobble so strands aren't perfectly straight ribbons.
    float wobble = sin(position.y * 0.06 + u * 2.0 + time * 2.1) * 4.0 * m * colWeight;
    float sourceX = position.x + wobble;

    return float2(sourceX, sourceY);
}
