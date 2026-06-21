#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

// Chromatic Velocity — splits the layer's R/G/B channels along `dir` by `split`
// pixels, sampling the layer three times and recombining. Referenced from SwiftUI
// via ShaderLibrary.chromaticVelocity in a .layerEffect modifier.
//
// position : pixel coordinate of the destination sample
// layer    : the source layer being sampled (SwiftUI::Layer)
// split    : per-channel offset distance in pixels (clamped on the Swift side)
// dir      : unit direction along which to displace R and B (G stays centered)
[[ stitchable ]]
half4 chromaticVelocity(float2 position, SwiftUI::Layer layer, float split, float2 dir) {
    float2 offset = dir * split;

    half4 r = layer.sample(position + offset);
    half4 g = layer.sample(position);
    half4 b = layer.sample(position - offset);

    // Average the three alphas so the smear keeps a coherent silhouette.
    half a = (r.a + g.a + b.a) / 3.0h;

    return half4(r.r, g.g, b.b, a);
}
