#pragma once

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

#include "ShaderTypes.h"

class Mesh {
public:
    virtual MTLVertexDescriptor *vertexDescriptor() const;
    virtual void draw(id<MTLRenderCommandEncoder> renderCommandEncoder, PoseConstants poseConstants) = 0;

    simd_float4x4 modelMatrix() const { return _modelMatrix; }

    void setModelMatrix(simd_float4x4 m) { _modelMatrix = m; };

private:
    simd_float4x4 _modelMatrix;
};

class TexturedMesh: public Mesh {
public:
    TexturedMesh();
    TexturedMesh(MDLMesh *mdlMesh, NSString *imageName, id<MTLDevice> device);

    void draw(id<MTLRenderCommandEncoder> renderCommandEncoder, PoseConstants poseConstants) override;

protected:
    MTKMesh *_mesh;
    id<MTLTexture> _texture;
};

class SpatialEnvironmentMesh: public TexturedMesh {
public:
    SpatialEnvironmentMesh(NSString *imageName, CGFloat radius, id<MTLDevice> device);
    void draw(id<MTLRenderCommandEncoder> renderCommandEncoder, PoseConstants poseConstants) override;

private:
    simd_float4x4 _environmentRotation;
};
