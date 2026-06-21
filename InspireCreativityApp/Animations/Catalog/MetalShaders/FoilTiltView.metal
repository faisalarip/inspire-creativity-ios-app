#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

// Hue (0..1) to RGB. MSL has no built-in hue helper, so do the classic
// abs(fract(h+k)*6-3)-1 clamp per channel.
static half3 hue2rgb(half h) {
    half r = abs(fract(h + 1.0h) * 6.0h - 3.0h) - 1.0h;
    half g = abs(fract(h + 2.0h / 3.0h) * 6.0h - 3.0h) - 1.0h;
    half b = abs(fract(h + 1.0h / 3.0h) * 6.0h - 3.0h) - 1.0h;
    return clamp(half3(r, g, b), 0.0h, 1.0h);
}

// Holographic foil-stamp diffraction.
//   position : pixel coords in points (implicit colorEffect arg)
//   color    : the source pixel (implicit) — its alpha is the sticker mask,
//              its luminance is the embossed relief texture
//   size     : view size in points (uniform)
//   tilt     : virtual viewing-angle vector from drag / idle rock (uniform)
//   time     : seconds, for a faint flowing shimmer (uniform)
[[ stitchable ]] half4 foilTilt(float2 position,
                                half4 color,
                                float2 size,
                                float2 tilt,
                                float time) {
    // Fully transparent source -> nothing here (keeps the die-cut silhouette).
    if (color.a < 0.001h) {
        return color;
    }

    // Normalized, centered coords in -1..1 (roughly) — independent of tile size.
    float2 uv = (position / max(size, float2(1.0))) * 2.0 - 1.0;
    float aspect = size.x / max(size.y, 1.0);
    uv.x *= aspect;

    // Embossed relief from the source luminance: this is the surface the light
    // diffracts off, so the rainbow follows the engraved pattern.
    half lum = dot(color.rgb, half3(0.299h, 0.587h, 0.114h));

    // --- Diffraction angle term ---
    // The hue is a function of pixel position projected onto the tilt vector
    // plus the relief, so tilting sweeps the spectrum across the pattern.
    float proj = dot(uv, float2(tilt.x, tilt.y));
    float relief = float(lum) * 2.4;
    float radial = length(uv) * 1.2;

    // Multiple detuned bands give the dense, thin-film "many rainbows" look
    // of real foil instead of one broad gradient.
    float phase = proj * 3.2 + relief + radial + time * 0.15;
    half hue = half(fract(phase * 0.5));

    half3 rainbow = hue2rgb(hue);
    // A second, higher-frequency band layered in for thin-film richness.
    half3 rainbow2 = hue2rgb(half(fract(phase * 1.3 + 0.33)));
    rainbow = mix(rainbow, rainbow2, 0.35h);

    // Boost saturation/vividness — foil is intense, not pastel.
    half3 foil = pow(rainbow, half3(0.85h));

    // --- Specular glint band ---
    // A narrow bright streak whose position tracks the tilt, racing across as
    // you tilt. Driven by the same projection so it stays coherent with the hue.
    float glintCoord = proj * 2.0 - length(float2(tilt.x, tilt.y)) * 0.6;
    float glintBand = fract(glintCoord * 0.5 + 0.5) - 0.5;
    float glint = exp(-(glintBand * glintBand) * 90.0);
    // A faster-moving secondary glint for sparkle on the high-relief ridges.
    // Square the centered band directly: pow() with a base that can go
    // negative is undefined in MSL and can produce NaN (blank pixels).
    float gd = fract(glintCoord + time * 0.2) - 0.5;
    float glint2 = exp(-(gd * gd) * 160.0);
    half glintAmt = half(glint * 0.9 + glint2 * 0.5) * (0.5h + 0.5h * lum);

    // --- Compose ---
    // Keep EVERY pixel iridescent: never gate the whole output on luminance,
    // or flat mid-gray regions would go dark. Floor it at 0.4.
    half shade = 0.40h + 0.60h * lum;
    half3 rgb = foil * shade;

    // Add the white specular glint on top.
    rgb += half3(glintAmt);

    // A subtle dark base tint in the valleys to sell the metallic depth.
    rgb = mix(rgb, rgb * half3(0.55h, 0.58h, 0.70h), (1.0h - lum) * 0.30h);

    rgb = clamp(rgb, 0.0h, 1.0h);

    // Premultiply by the source alpha so the foil only fills the sticker shape,
    // not the whole rectangular tile.
    return half4(rgb * color.a, color.a);
}
