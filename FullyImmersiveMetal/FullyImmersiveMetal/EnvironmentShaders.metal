#include <metal_stdlib>
using namespace metal;

#include "ShaderTypes.h"

constant bool useLayeredRendering [[function_constant(0)]];

struct VertexIn {
    float3 position  [[attribute(0)]];
    float3 normal    [[attribute(1)]];
    float2 texCoords [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 modelNormal;
    float2 texCoords;
};

struct LayeredVertexOut {
    float4 position [[position]];
    float3 modelNormal;
    float2 texCoords;
    uint renderTargetIndex [[render_target_array_index]];
    uint viewportIndex [[viewport_array_index]];
};

struct EnvironmentFragmentIn {
    float4 position [[position]];
    float3 modelNormal;
    float2 texCoords;
    uint renderTargetIndex [[render_target_array_index]];
    uint viewportIndex [[viewport_array_index]];
};

[[vertex]]
LayeredVertexOut vertex_environment(VertexIn in [[stage_in]],
                                    constant PoseConstants *poses [[buffer(1)]],
                                    constant EnvironmentConstants &environment [[buffer(2)]],
                                    uint amplificationID [[amplification_id]])
{
    constant auto &pose = poses[amplificationID];

    float4 modelPosition = float4(in.position, 1.0f);
    float4 worldPosition = environment.modelMatrix * modelPosition;

    LayeredVertexOut out;
    out.position = pose.projectionMatrix * pose.viewMatrix * worldPosition;
    out.modelNormal = -in.normal;
    out.texCoords = in.texCoords;

    if (useLayeredRendering) {
        out.renderTargetIndex = amplificationID;
    }
    out.viewportIndex = amplificationID;
    return out;
}

[[vertex]]
VertexOut vertex_dedicated_environment(VertexIn in [[stage_in]],
                                       constant PoseConstants *poses [[buffer(1)]],
                                       constant EnvironmentConstants &environment [[buffer(2)]])
{
    constant auto &pose = poses[0];

    float4 modelPosition = float4(in.position, 1.0f);
    float4 worldPosition = environment.modelMatrix * modelPosition;

    VertexOut out;
    out.position = pose.projectionMatrix * pose.viewMatrix * worldPosition;
    out.modelNormal = -in.normal;
    out.texCoords = in.texCoords;
    return out;
}

static float2 EquirectUVFromCubeDirection(float3 v) {
    const float2 scales { 0.1591549f, 0.3183099f };
    const float2 biases { 0.5f, 0.5f };
    // Assumes +Z is forward. For -X forward, use atan2(v.z, v.x) below instead.
    float2 uv = float2(atan2(-v.x, v.z), asin(-v.y)) * scales + biases;
    return uv;
}

[[fragment]]
half4 fragment_environment(EnvironmentFragmentIn in [[stage_in]],
                           texture2d<half, access::sample> environmentTexture [[texture(0)]])
{
    constexpr sampler environmentSampler(coord::normalized, filter::linear, mip_filter::none, address::repeat);

    float3 N = normalize(in.modelNormal);
    float2 texCoords = EquirectUVFromCubeDirection(N);
    half4 color = environmentTexture.sample(environmentSampler, texCoords);
    return color;
}
