
#include <metal_stdlib>
using namespace metal;

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

struct PoseConstants {
    float4x4 projectionMatrix;
    float4x4 viewMatrix;
};

struct EnvironmentConstants {
    float4x4 modelMatrix;
    float4x4 environmentRotation;
};

[[vertex]]
VertexOut vertex_environment(VertexIn in [[stage_in]],
                             constant PoseConstants &pose [[buffer(1)]],
                             constant EnvironmentConstants &environment [[buffer(2)]])
{
    VertexOut out;
    out.position = pose.projectionMatrix * pose.viewMatrix * float4(in.position, 1.0f);
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
float4 fragment_environment(VertexOut in [[stage_in]],
                            texture2d<float> environmentTexture [[texture(0)]])
{
    constexpr sampler environmentSampler(coord::normalized,
                                         filter::linear,
                                         mip_filter::none,
                                         address::repeat);

    float3 N = normalize(in.modelNormal);
    float2 texCoords = EquirectUVFromCubeDirection(N);
    float4 color = environmentTexture.sample(environmentSampler, texCoords);
    return color;
}
