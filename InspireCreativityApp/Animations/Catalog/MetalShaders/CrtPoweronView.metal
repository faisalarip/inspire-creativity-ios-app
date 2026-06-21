#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

// Vintage CRT power-on color effect.
//
//   position : user-space point (injected by SwiftUI)
//   color    : the incoming premultiplied pixel (injected by SwiftUI)
//   size     : view size in points (uniform) — used to normalize everything
//   time     : seconds, for the rolling scanlines / sync bar
//   powerOn  : 0 = collapsed bright line, 1 = full picture
//
// colorEffect cannot sample neighbors, so the "collapse to a line" is a
// vertical visibility mask that blends toward a blown-out white line at the
// minimum (never a fully-blank frame), then blooms open as powerOn -> 1.
[[ stitchable ]]
half4 crtPowerOn(float2 position, half4 color, float2 size, float time, float powerOn) {
    float2 uv = position / max(size, float2(1.0, 1.0));   // 0..1
    float2 centered = uv - 0.5;                            // -0.5..0.5

    // Un-premultiply so we can do real color math, then re-premultiply at the end.
    float a = max(float(color.a), 0.0001);
    float3 rgb = float3(color.rgb) / a;

    // --- Phosphor tint: lift toward a warm green/amber phosphor glow ---
    float lum = dot(rgb, float3(0.299, 0.587, 0.114));
    float3 phosphor = float3(0.55, 1.0, 0.62);            // P1-ish green
    rgb = mix(rgb, rgb * phosphor + phosphor * 0.04, 0.35);

    // --- Scanlines (horizontal), gently rolling with time ---
    float lineCount = clamp(size.y * 0.5, 90.0, 320.0);
    float roll = time * 0.6;
    float scan = 0.5 + 0.5 * sin((uv.y * lineCount + roll) * 6.2831853);
    float scanline = mix(0.72, 1.0, scan);                // 0.72..1.0 darkening
    rgb *= scanline;

    // Subtle vertical RGB phosphor triad (aperture-grille feel)
    float triad = fract(uv.x * lineCount * 0.5);
    float3 mask3 = float3(1.0);
    if (triad < 0.333)      mask3 = float3(1.0, 0.85, 0.85);
    else if (triad < 0.666) mask3 = float3(0.85, 1.0, 0.85);
    else                    mask3 = float3(0.85, 0.85, 1.0);
    rgb *= mix(float3(1.0), mask3, 0.18);

    // --- Rolling sync bar: a soft bright band drifting down the screen ---
    float barPos = fract(time * 0.09);
    float d = abs(uv.y - barPos);
    d = min(d, 1.0 - d);                                  // wrap
    float bar = exp(-d * d * 220.0);
    rgb += bar * float3(0.10, 0.16, 0.12);

    // --- Phosphor bloom: lift glow in bright areas ---
    rgb += pow(lum, 1.5) * 0.10 * phosphor;

    // --- Barrel vignette (darken corners) ---
    float r2 = dot(centered, centered);
    float vignette = clamp(1.0 - r2 * 1.35, 0.0, 1.0);
    vignette = mix(0.30, 1.0, vignette);
    rgb *= vignette;

    // --- Power-on collapse / bloom mask ---
    // openHalf is the half-height of the visible band: ~full when on,
    // shrinking to a thin slit as powerOn -> 0.
    float p = clamp(powerOn, 0.0, 1.0);
    float openHalf = mix(0.012, 0.62, smoothstep(0.0, 1.0, p));
    float dy = abs(centered.y);

    // visible inside the band, fading at its edge
    float band = 1.0 - smoothstep(openHalf, openHalf + 0.06, dy);

    // Horizontal scan-line brightness: a sharp blown-out white streak at the
    // vertical center, strongest when collapsed. This is the "never blank" state.
    float lineGlow = exp(-(centered.y * centered.y) * 1600.0);
    float collapse = 1.0 - p;                              // 0 on, 1 collapsed
    float flash = lineGlow * (0.35 + 0.9 * collapse);

    // Horizontal sweep: the picture also pinches horizontally a touch at the
    // very end of the collapse, blooming back out.
    float hOpen = mix(0.15, 1.0, smoothstep(0.0, 0.35, p));
    float hBand = 1.0 - smoothstep(hOpen, hOpen + 0.10, abs(centered.x));
    float visible = band * mix(0.6, 1.0, hBand);

    // Compose: picture gated by the band, plus the bright white collapse line.
    float3 outRGB = rgb * visible;
    outRGB += flash * float3(0.85, 1.0, 0.88);             // blown-out warm-white line
    outRGB = min(outRGB, float3(1.4));                     // allow slight over-bright bloom

    // Re-premultiply with full opacity (opaque CRT face).
    float3 finalRGB = clamp(outRGB, 0.0, 1.0);
    return half4(half3(finalRGB), 1.0h);
}
