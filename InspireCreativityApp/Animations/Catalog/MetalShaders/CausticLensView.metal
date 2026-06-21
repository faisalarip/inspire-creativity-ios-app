#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

// Caustic Glass Lens — single-pass refraction + caustics + chrome rim.
//
// Implicit args (position, layer) come first; then the Swift-supplied uniforms
// in declaration order: center, radius, time, size.
//
// Inside the lens radius we sample the backdrop *inward* (magnify), add a slight
// edge-refraction bend, paint swimming underwater caustic light bands, and draw
// a specular chrome rim. Outside, we return the layer unchanged so the rest of
// the content stays crisp (and the tile is never blank).

[[ stitchable ]]
half4 causticLens(float2 pos,
                  SwiftUI::Layer layer,
                  float2 center,
                  float radius,
                  float time,
                  float2 size) {

    float2 d = pos - center;
    float dist = length(d);

    // Outside the glass: passthrough.
    if (dist >= radius) {
        return layer.sample(pos);
    }

    // Normalized radius 0 (center) .. 1 (rim).
    float r = dist / max(radius, 1.0);
    float2 dir = (dist > 0.0001) ? (d / dist) : float2(0.0, 0.0);

    // ---- Refraction / magnification -------------------------------------
    // Base magnification: sample inward so the center enlarges. mag < 1.
    float baseMag = 0.62;
    // Edge bend: a glass droplet refracts harder near the rim. Push the sample
    // coordinate outward as r->1 with a smooth lens profile.
    float bend = pow(r, 3.0) * 0.34;
    float mag = baseMag + bend;

    float2 src = center + d * mag;

    // Animated ripple in the sampling so the refracted image subtly breathes.
    float ripple = sin(r * 18.0 - time * 2.2) * (1.0 - r) * 2.4;
    src += dir * ripple;

    // Keep the sample coordinate on-screen (avoid transparent reads at edges).
    src = clamp(src, float2(0.5, 0.5), size - float2(0.5, 0.5));

    half4 refracted = layer.sample(src);

    // ---- Underwater caustic light bands ---------------------------------
    // Two superimposed sine fields, advected over time, raised to a sharp power
    // to read as thin focused light filaments swimming inside the lens.
    float2 uv = (pos - center) / max(radius, 1.0); // -1..1 within lens
    float t = time;

    float w1 = sin(uv.x * 6.0 + t * 1.3) + sin(uv.y * 5.0 - t * 1.1);
    float w2 = sin((uv.x + uv.y) * 4.5 + t * 0.9)
             + sin((uv.x - uv.y) * 5.5 - t * 1.5);
    float field = (w1 + w2) * 0.25 + 0.5;     // ~0..1
    field = clamp(field, 0.0, 1.0);

    // Sharpen into bands.
    float bands = pow(field, 3.0);
    // Fade caustics toward the rim so they pool in the interior.
    float interior = smoothstep(1.0, 0.25, r);
    float caustic = bands * interior;

    // Cool-white caustic tint.
    half3 causticColor = half3(0.72h, 0.92h, 1.0h);
    half3 lit = refracted.rgb + causticColor * half(caustic) * 0.85h;

    // Faint cyan body tint so the glass reads as colored water.
    half3 glassTint = half3(0.55h, 0.85h, 0.95h);
    lit = mix(lit, lit * glassTint, half(0.18 * interior));

    // ---- Chrome / specular rim ------------------------------------------
    // Bright thin ring at the edge of the lens.
    float rimWidth = 0.10;
    float rim = smoothstep(1.0 - rimWidth, 1.0, r) * smoothstep(1.02, 0.98, r);
    half3 rimColor = half3(1.0h, 0.98h, 0.92h);
    lit += rimColor * half(rim) * 1.2h;

    // Directional top-left specular hotspot on the dome.
    float2 lightDir = normalize(float2(-0.6, -0.8));
    float spec = clamp(dot(dir, lightDir), 0.0, 1.0);
    spec = pow(spec, 4.0) * smoothstep(0.45, 1.0, r); // strongest near rim
    lit += rimColor * half(spec) * 0.6h;

    // Soft inner shadow opposite the light for dome volume.
    float shade = clamp(dot(dir, -lightDir), 0.0, 1.0);
    shade = pow(shade, 2.0) * smoothstep(0.5, 1.0, r) * 0.25;
    lit *= (1.0h - half(shade));

    // Antialias the lens boundary.
    float edge = smoothstep(radius, radius - 1.5, dist);
    half3 outside = layer.sample(pos).rgb;
    half3 finalRGB = mix(outside, lit, half(edge));

    return half4(finalRGB, 1.0h);
}
