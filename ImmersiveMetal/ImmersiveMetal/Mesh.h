#pragma once

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

#import "ShaderTypes.h"

class Mesh {
public:
    virtual MTLVertexDescriptor *vertexDescriptor() const;
    virtual void draw(id<MTLRenderCommandEncoder> renderCommandEncoder, PoseConstants *poseConstants, size_t poseCount) = 0;

    simd_float4x4 modelMatrix() const { return _modelMatrix; }

    void setModelMatrix(simd_float4x4 m) { _modelMatrix = m; };

private:
    simd_float4x4 _modelMatrix = matrix_identity_float4x4;
};

class TexturedMesh: public Mesh {
public:
    TexturedMesh();
    TexturedMesh(MDLMesh *mdlMesh, NSString *imageName, id<MTLDevice> device);

    void draw(id<MTLRenderCommandEncoder> renderCommandEncoder, PoseConstants *poseConstants, size_t poseCount) override;

protected:
    MTKMesh *_mesh;
    id<MTLTexture> _texture;
};

class SpatialEnvironmentMesh: public TexturedMesh {
public:
    SpatialEnvironmentMesh(NSString *imageName, CGFloat radius, id<MTLDevice> device);
    void draw(id<MTLRenderCommandEncoder> renderCommandEncoder, PoseConstants *poseConstants, size_t poseCount) override;

    float cutoffAngle() const;
    void setCutoffAngle(float cutoffAngle);

private:
    simd_float4x4 _environmentRotation;
    float _cutoffAngle = 180.0f;
    float _cutoffEdgeWidth = 0.125f;
};
