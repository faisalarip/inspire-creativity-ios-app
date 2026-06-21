#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Mercury Pour — metaball threshold + chrome specular rim.
//
// The view blurs the bright beads in SwiftUI BEFORE this layer effect, so the
// layer we sample is already a smooth gooey field. Here we only:
//   1. threshold the blurred luminance with smoothstep → the metal surface,
//   2. read 4 neighbours to estimate a surface gradient → a fake normal,
//   3. light that normal with a specular glint + an environment gradient that
//      is biased by the gravity direction → chrome.
//
// Cheap: 5 samples per pixel, modest maxSampleOffset.

static inline half luma(half4 c) {
    return dot(c.rgb, half3(0.299h, 0.587h, 0.114h));
}

[[ stitchable ]]
half4 mercuryPour(float2 pos,
                  SwiftUI::Layer layer,
                  float2 size,
                  float time,
                  float2 gravity) {

    // Center sample of the pre-blurred field.
    half4 c = layer.sample(pos);
    half  l = luma(c) * c.a;

    // --- Metaball threshold (soft edge so the rim reads as metal, not aliased).
    half edge0 = 0.32h;
    half edge1 = 0.55h;
    half surface = smoothstep(edge0, edge1, l);

    if (surface <= 0.001h) {
        // Outside the metal: faint cool backdrop tint, never fully black so the
        // tile is legible on every frame.
        half3 bg = half3(0.035h, 0.045h, 0.07h);
        return half4(bg, 1.0h);
    }

    // --- Neighbour samples → gradient of the blurred field (fake surface normal).
    float o = 3.0;
    half lx0 = luma(layer.sample(pos + float2(-o, 0.0)));
    half lx1 = luma(layer.sample(pos + float2( o, 0.0)));
    half ly0 = luma(layer.sample(pos + float2(0.0, -o)));
    half ly1 = luma(layer.sample(pos + float2(0.0,  o)));

    half gx = (lx1 - lx0);
    half gy = (ly1 - ly0);
    // Normal tilts away from rising luminance; z gives it body.
    half3 n = normalize(half3(-gx * 2.2h, -gy * 2.2h, 1.0h));

    // --- Lighting. Gravity biases the environment so the sheen shifts as you pour.
    float2 g = gravity;
    float glen = length(g);
    if (glen > 0.0001) { g = g / glen; } else { g = float2(0.0, -1.0); }

    half3 lightDir = normalize(half3(half(g.x) * 0.6h, half(-g.y) * 0.6h, 0.85h));
    half3 viewDir  = half3(0.0h, 0.0h, 1.0h);
    half3 halfV    = normalize(lightDir + viewDir);

    half ndl  = max(dot(n, lightDir), 0.0h);
    half ndh  = max(dot(n, halfV), 0.0h);
    half spec = pow(ndh, 48.0h);          // tight chrome glint
    half spec2 = pow(ndh, 9.0h) * 0.5h;   // broader sheen

    // Environment gradient (top bright, bottom dark) rotated a touch by gravity +
    // a slow time wobble so the chrome surface looks like it reflects a room.
    half env = 0.5h + 0.5h * n.y;
    half wob = 0.08h * half(sin(time * 0.8 + n.x * 4.0));
    env = clamp(env + wob, 0.0h, 1.0h);

    half3 dark   = half3(0.08h, 0.10h, 0.14h);
    half3 mid    = half3(0.45h, 0.50h, 0.58h);
    half3 bright = half3(0.85h, 0.90h, 0.97h);
    half3 chrome = mix(dark, mid, env);
    chrome = mix(chrome, bright, env * env);

    // Diffuse body + speculars.
    half3 col = chrome * (0.55h + 0.45h * ndl);
    col += half3(1.0h, 1.0h, 1.0h) * spec;
    col += bright * spec2;

    // --- Rim: emphasise the metaball silhouette so merging beads show surface
    // tension at the contact neck. surface ~ between edge0/edge1 = the rim band.
    half rim = surface * (1.0h - surface) * 4.0h;
    col += half3(0.9h, 0.95h, 1.0h) * rim * 0.35h;

    // Composite over the faint backdrop using the threshold as coverage.
    half3 bg = half3(0.035h, 0.045h, 0.07h);
    half3 outc = mix(bg, col, surface);
    return half4(outc, 1.0h);
}
