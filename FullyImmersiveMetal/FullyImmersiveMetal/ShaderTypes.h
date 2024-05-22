#pragma once

#include <simd/simd.h>

struct PoseConstants {
    simd_float4x4 projectionMatrix;
    simd_float4x4 viewMatrix;
};

struct InstanceConstants {
    simd_float4x4 modelMatrix;
};

struct LayerConstants {
    unsigned layerCount, viewportCount;
};

struct EnvironmentConstants {
    simd_float4x4 modelMatrix;
    simd_float4x4 environmentRotation;
};
