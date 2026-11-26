#include <metal_stdlib>
#include <RealityKit/RealityKit.h>
using namespace metal;

// Each quad stores its star's centre in position, a signed corner in uv0, radius in
// uv1.x and temperature colour in color. Swift supplies scale, viewport height,
// minimum visible diameter and halo extent in custom_parameter().
[[visible]]
void starBillboardGeometry(realitykit::geometry_parameters params) {
    auto geometry = params.geometry();
    const float4 controls = params.uniforms().custom_parameter();
    const float4x4 worldToView = params.uniforms().model_to_view() * params.uniforms().world_to_model();
    const float depth = -(worldToView * float4(geometry.world_position(), 1)).z;
    const float radius = geometry.uv1().x * controls.x;
    const float projectionY = params.uniforms().view_to_projection()[1][1];
    const float diameter = radius * abs(projectionY) * controls.y / max(depth, 0.0001f);
    const bool visible = depth > 0.01f && diameter >= controls.z;

    // Collapse sub-pixel stars to degenerate triangles: no fragments or halo are drawn.
    const float extent = visible ? radius * controls.w : 0;
    const float3 right = float3(worldToView[0][0], worldToView[1][0], worldToView[2][0]);
    const float3 up = float3(worldToView[0][1], worldToView[1][1], worldToView[2][1]);
    const float2 corner = geometry.uv0();
    geometry.set_world_position_offset((right * corner.x + up * corner.y) * extent);
    geometry.set_custom_attribute(float4(smoothstep(controls.z, controls.z * 2, diameter), controls.w, 0, 0));
}

// Cores write depth before halos. Discard the rest of the quad so invisible corners
// cannot occlude other stars. A little limb darkening keeps large stars from looking flat.
[[visible]]
void starCoreSurface(realitykit::surface_parameters params) {
    const float4 attributes = params.geometry().custom_attribute();
    const float distance = length(params.geometry().uv0()) * attributes.y;
    const float antialias = max(fwidth(distance), 0.02f);
    const float core = 1 - smoothstep(1 - antialias, 1, distance);
    const float opacity = core * attributes.x;
    if (opacity < 0.001f) { discard_fragment(); }
    const half limb = half(0.7f + 0.3f * sqrt(max(0.0f, 1 - distance * distance)));
    params.surface().set_emissive_color(half3(params.geometry().color().rgb) * limb);
    params.surface().set_opacity(half(opacity));
}

// The isolated halo shader is the main iteration point for the glow. Distances are
// in stellar radii, so changing halo extent never changes the core size.
[[visible]]
void starGlowSurface(realitykit::surface_parameters params) {
    const float4 attributes = params.geometry().custom_attribute();
    const float distance = length(params.geometry().uv0()) * attributes.y;
    const float antialias = max(fwidth(distance), 0.02f);
    const float outsideCore = smoothstep(1 - antialias, 1 + antialias, distance);
    const float halo = 0.16f * exp(-1.5f * max(distance * distance - 1, 0.0f));
    const float edge = 1 - smoothstep(attributes.y - 0.4f, attributes.y, distance);
    const float opacity = halo * outsideCore * edge * attributes.x;
    if (opacity < 0.001f) { discard_fragment(); }
    const half3 color = half3(params.geometry().color().rgb);
    params.surface().set_emissive_color(color);
    params.surface().set_opacity(half(opacity));
}
