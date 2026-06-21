#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Radial damped-sine shockwave that returns the coordinate to sample FROM.
// pos      : current pixel position in user-space points (same space as origin)
// time     : seconds elapsed since the impulse fired (NOT wall-clock)
// origin   : impulse origin in user-space points
// amplitude: peak displacement in points (already velocity-seeded + clamped by Swift)
// dir      : normalized fling direction (or float2(0) for a non-directional nudge)
[[ stitchable ]]
float2 jellyWobble(float2 pos,
                   float time,
                   float2 origin,
                   float amplitude,
                   float2 dir) {
    if (amplitude < 0.01) {
        return pos;
    }

    float2 d = pos - origin;
    float r = length(d);

    // Guard the singularity at the impulse origin.
    float2 radial = r > 0.001 ? d / r : float2(0.0);

    // The wavefront sweeps outward at `speed`; we envelope the wave around it
    // but keep the envelope wide so the WHOLE surface sloshes (jelly), with a
    // gentle traveling crest rather than a hairline ring.
    float speed = 320.0;          // points / second the crest travels
    float front = speed * time;   // current crest radius
    float spread = 220.0;         // envelope width (wide => jelly, not a ring)

    float gx = (r - front) / spread;
    float envelope = exp(-gx * gx);            // traveling crest
    float plane = exp(-r / 520.0);             // whole-plane slosh contribution

    // Damped oscillation: rings ride outward and fade over time.
    float freq = 0.045;                        // spatial frequency (1/points)
    float omega = 11.0;                        // temporal angular frequency
    float decay = exp(-time * 2.6);            // settle-down envelope
    float wave = sin(r * freq - time * omega);

    // Directional inertia: the side the fling points toward sloshes more,
    // the trailing side recoils. dot in [-1, 1]; bias keeps it always positive
    // so the radial wobble survives even for a zero-velocity tap.
    float bias = 0.55 + 0.45 * dot(radial, dir);

    float radialOffset = amplitude * decay * bias *
                         (0.7 * envelope + 0.35 * plane) * wave;

    // A secondary slosh that drags the surface bodily along the fling axis,
    // decaying faster so it reads as initial inertia before the rings take over.
    float dragDecay = exp(-time * 3.4);
    float dragWave = sin(time * omega * 0.5) * dragDecay;
    float2 dragOffset = dir * amplitude * 0.5 * dragWave * plane;

    return pos + radial * radialOffset + dragOffset;
}
