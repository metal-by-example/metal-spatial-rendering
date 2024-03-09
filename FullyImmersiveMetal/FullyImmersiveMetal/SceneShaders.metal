
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position  [[attribute(0)]];
    float3 normal    [[attribute(1)]];
    float2 texCoords [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 viewNormal;
    float2 texCoords;
    uint layer [[ render_target_array_index ]];
};

struct PoseConstants {
    float4x4 projectionMatrix;
    float4x4 viewMatrix;
};

struct InstanceConstants {
    float4x4 modelMatrix;
};

[[vertex]]
VertexOut vertex_main(VertexIn in [[stage_in]],
                      constant PoseConstants *poses [[buffer(1)]],
                      constant InstanceConstants &instance [[buffer(2)]],
                      const uint instance_id [[ instance_id ]])
{
    VertexOut out;
    
    const constant auto& pose = poses[instance_id];
        
    out.position = pose.projectionMatrix * pose.viewMatrix * instance.modelMatrix * float4(in.position, 1.0f);
    out.viewNormal = (pose.viewMatrix * instance.modelMatrix * float4(in.normal, 0.0f)).xyz;
    out.texCoords = in.texCoords;
    out.texCoords.x = 1.0f - out.texCoords.x; // Flip uvs horizontally to match Model I/O
    out.layer = instance_id;
    return out;
}

[[fragment]]
float4 fragment_main(VertexOut in [[stage_in]],
                            texture2d<float> texture [[texture(0)]])
{
    constexpr sampler environmentSampler(coord::normalized,
                                         filter::linear,
                                         mip_filter::none,
                                         address::repeat);

    //float3 N = normalize(in.viewNormal);
    float4 color = texture.sample(environmentSampler, in.texCoords);
    return color;
}
