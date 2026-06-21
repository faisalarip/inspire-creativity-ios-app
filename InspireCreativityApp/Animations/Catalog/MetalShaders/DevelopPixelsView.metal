#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

// Develop: snap each pixel's sample coordinate to the center of a grid cell,
// then sample the layer there. As `cellSize` animates from large -> 1px the
// image resolves from coarse mosaic blocks to full resolution.
//
// `position` and `layer.sample` are both in local point space, so `cellSize`
// is supplied in points. cellSize is clamped to >= 1 to avoid floor()/divide
// producing NaN (which would yield a blank/garbage frame).
[[ stitchable ]]
half4 developPixels(float2 position, SwiftUI::Layer layer, float cellSize) {
    float c = max(cellSize, 1.0);
    float2 cell = floor(position / c);
    float2 sampleCoord = (cell + 0.5) * c;
    return layer.sample(sampleCoord);
}
