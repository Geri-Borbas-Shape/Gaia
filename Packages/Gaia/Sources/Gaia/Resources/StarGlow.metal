#include <metal_stdlib>
#include <RealityKit/RealityKit.h>
using namespace metal;

// Each quad stores its star's centre in position, a signed corner in uv0, radius in
// uv1.x and temperature colour in color. Swift supplies scale, viewport height,
// minimum visible diameter and maximum displayed diameter in custom_parameter().
[[visible]]
void starBillboardGeometry(realitykit::geometry_parameters params) {
    auto geometry = params.geometry();
    const float4 controls = params.uniforms().custom_parameter();
    const float4x4 worldToView = params.uniforms().model_to_view() * params.uniforms().world_to_model();
    const float depth = -(worldToView * float4(geometry.world_position(), 1)).z;
    float radius = geometry.uv1().x * controls.x;
    const float projectionY = params.uniforms().view_to_projection()[1][1];
    const float diameter = radius * abs(projectionY) * controls.y / max(depth, 0.0001f);
    const float4 clip = params.uniforms().view_to_projection() * worldToView * float4(geometry.world_position(), 1);
    const bool visible = depth > 0.01f && diameter >= controls.z
                         && abs(clip.x) <= clip.w && abs(clip.y) <= clip.w;
    radius *= min(1.0f, controls.w / max(diameter, 0.0001f));

    // Collapse sub-pixel stars to degenerate triangles: no fragments or halo are drawn.
    const float extent = visible ? radius : 0;
    const float3 right = float3(worldToView[0][0], worldToView[1][0], worldToView[2][0]);
    const float3 up = float3(worldToView[0][1], worldToView[1][1], worldToView[2][1]);
    const float2 corner = geometry.uv0();
    geometry.set_world_position_offset((right * corner.x + up * corner.y) * extent);
    geometry.set_custom_attribute(float4(1, 1, 0, 0));
}

// Core coverage is opaque: partial-alpha fragments must not write depth ahead of
// stars behind them and leave a dark fringe at overlapping silhouettes.
[[visible]]
void starCoreSurface(realitykit::surface_parameters params) {
    const float4 attributes = params.geometry().custom_attribute();
    const float distance = length(params.geometry().uv0()) * attributes.y;
    if (distance > 1) { discard_fragment(); }
    const half limb = half(0.7f + 0.3f * sqrt(max(0.0f, 1 - distance * distance)));
    params.surface().set_emissive_color(half3(params.geometry().color().rgb) * limb * half(attributes.x));
    params.surface().set_opacity(1);
}

struct GlowStar {
    float4 positionRadius;
    float4 color;
};

struct GlowFrame {
    float4x4 worldToView;
    float4x4 projection;
    float4 controls; // radius scale, viewport height in points, minimum diameter, halo extent
    float4 glow; // intensity, bias exponent, unscaled profile extent, reserved
    float4 visibility; // maximum displayed diameter, reserved
};

struct GlowVertex {
    float4 position [[position]];
    float2 uv;
    float4 color;
    float4 appearance; // visibility fade, profile extent, intensity, bias exponent
};

vertex GlowVertex starGlowVertex(uint vertexID [[vertex_id]], uint instanceID [[instance_id]],
                                constant GlowStar *stars [[buffer(0)]], constant GlowFrame &frame [[buffer(1)]],
                                constant uint *visibleIndices [[buffer(2)]]) {
    constexpr float2 corners[] = {{-1,-1}, {1,-1}, {1,1}, {-1,-1}, {1,1}, {-1,1}};
    const GlowStar star = stars[visibleIndices[instanceID]];
    const float4 centre = frame.worldToView * float4(star.positionRadius.xyz, 1);
    const float depth = -centre.z;
    float radius = star.positionRadius.w * frame.controls.x;
    const float diameter = radius * abs(frame.projection[1][1]) * frame.controls.y / max(depth, 0.0001f);
    const float2 corner = corners[vertexID];
    float4 clip = frame.projection * centre;
    const bool visible = depth > 0.01f && diameter >= frame.controls.z
                         && abs(clip.x) <= clip.w && abs(clip.y) <= clip.w;
    radius *= min(1.0f, frame.visibility.x / max(diameter, 0.0001f));
    clip.xy += corner * radius * frame.controls.w * float2(frame.projection[0][0], frame.projection[1][1]);
    clip.z = 0; // The overlay never participates in scene depth testing.
    if (!visible) { clip = float4(2, 2, 0, 1); }
    return {clip, corner, star.color,
            float4(1, frame.glow.z, frame.glow.x, frame.glow.y)};
}

// A continuous halo across the centre as well as the edge. Each instance is screen
// blended over the completed scene: S + D*(1-S). Black contributes nothing, and
// overlapping halos can only brighten the image, regardless of instance order.
fragment half4 starGlowFragment(GlowVertex in [[stage_in]]) {
    const float distance = length(in.uv) * in.appearance.y;
    const float halo = exp(-1.5f * max(distance * distance - 1, 0.0f));
    const float edge = 1 - smoothstep(in.appearance.y - 0.4f, in.appearance.y, distance);
    // Bias changes the falloff without changing the peak brightness. Size scales
    // the billboard separately, so all three controls remain independent.
    const float intensity = in.appearance.z * pow(halo * edge, in.appearance.w) * in.appearance.x;
    return half4(half3(saturate(in.color.rgb * intensity)), 0);
}

struct SceneCopyVertex {
    float4 position [[position]];
    float2 uv;
};

vertex SceneCopyVertex starSceneCopyVertex(uint vertexID [[vertex_id]]) {
    constexpr float2 positions[] = {{-1,-1}, {3,-1}, {-1,3}};
    const float2 position = positions[vertexID];
    return {float4(position, 0, 1), float2(position.x * 0.5f + 0.5f, 0.5f - position.y * 0.5f)};
}

fragment half4 starSceneCopyFragment(SceneCopyVertex in [[stage_in]], texture2d<half> source [[texture(0)]]) {
    constexpr sampler sample(filter::nearest, address::clamp_to_edge);
    return source.sample(sample, in.uv);
}
