#pragma once

#include "ShaderTypes.h"
#include "Mesh.h"

#include <memory>

#import <CompositorServices/CompositorServices.h>
#import <Metal/Metal.h>

class SpatialRenderer {
public:
    SpatialRenderer(cp_layer_renderer_t layerRenderer);
    void drawAndPresent(cp_frame_t frame, cp_drawable_t drawable);

private:
    void makeResources();
    void makeRenderPipelines(cp_layer_renderer_layout layout);
    MTLRenderPassDescriptor* createRenderPassDescriptor(cp_drawable_t drawable, size_t index);
    PoseConstants poseConstantsForViewIndex(cp_drawable_t drawable, size_t index);

    id<MTLDevice> _device;
    id<MTLCommandQueue> _commandQueue;
    id<MTLRenderPipelineState> _environmentRenderPipelineState;
    id<MTLRenderPipelineState> _contentRenderPipelineState;
    id<MTLDepthStencilState> _contentDepthStencilState;
    id<MTLDepthStencilState> _backgroundDepthStencilState;
    cp_layer_renderer_t _layerRenderer;
    std::unique_ptr<TexturedMesh> _globeMesh;
    std::unique_ptr<SpatialEnvironmentMesh> _environmentMesh;
    CFTimeInterval _sceneTime;
    CFTimeInterval _lastRenderTime;
};
