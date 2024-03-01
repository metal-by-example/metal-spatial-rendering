
#include "SpatialRenderer.h"
#include "Mesh.h"
#include "ShaderTypes.h"

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <Spatial/Spatial.h>

#include <vector>

static simd_float4x4 matrix_float4x4_from_double4x4(simd_double4x4 m) {
    return simd_matrix(simd_make_float4(m.columns[0][0], m.columns[0][1], m.columns[0][2], m.columns[0][3]),
                       simd_make_float4(m.columns[1][0], m.columns[1][1], m.columns[1][2], m.columns[1][3]),
                       simd_make_float4(m.columns[2][0], m.columns[2][1], m.columns[2][2], m.columns[2][3]),
                       simd_make_float4(m.columns[3][0], m.columns[3][1], m.columns[3][2], m.columns[3][3]));
}

SpatialRenderer::SpatialRenderer(cp_layer_renderer_t layerRenderer) :
    _layerRenderer { layerRenderer },
    _sceneTime(0.0),
    _lastRenderTime(CACurrentMediaTime())
{
    _device = cp_layer_renderer_get_device(layerRenderer);
    _commandQueue = [_device newCommandQueue];

    makeResources();

    cp_layer_renderer_configuration_t layerConfiguration = cp_layer_renderer_get_configuration(layerRenderer);
    _layerRendererLayout = cp_layer_renderer_configuration_get_layout(layerConfiguration);
    makeRenderPipelines();
}

void SpatialRenderer::makeResources() {
    MTKMeshBufferAllocator *bufferAllocator = [[MTKMeshBufferAllocator alloc] initWithDevice:_device];
    MDLMesh *sphereMesh = [MDLMesh newEllipsoidWithRadii:simd_make_float3(0.5, 0.5, 0.5)
                                          radialSegments:24
                                        verticalSegments:24
                                            geometryType:MDLGeometryTypeTriangles
                                           inwardNormals:NO
                                              hemisphere:NO
                                               allocator:bufferAllocator];
    _globeMesh = std::make_unique<TexturedMesh>(sphereMesh, @"bluemarble.png", _device);

    _environmentMesh = std::make_unique<SpatialEnvironmentMesh>(@"studio.hdr", 3.0, _device);
}

void SpatialRenderer::makeRenderPipelines() {
    NSError *error = nil;
    cp_layer_renderer_configuration_t layerConfiguration = cp_layer_renderer_get_configuration(_layerRenderer);
    
    MTLRenderPipelineDescriptor *pipelineDescriptor = [MTLRenderPipelineDescriptor new];
    pipelineDescriptor.colorAttachments[0].pixelFormat = cp_layer_renderer_configuration_get_color_format(layerConfiguration);
    pipelineDescriptor.depthAttachmentPixelFormat = cp_layer_renderer_configuration_get_depth_format(layerConfiguration);
    
    id<MTLLibrary> library = [_device newDefaultLibrary];
    id<MTLFunction> vertexFunction, fragmentFunction;
    
    {
        vertexFunction = [library newFunctionWithName:@"vertex_main"];
        fragmentFunction = [library newFunctionWithName:@"fragment_main"];
        pipelineDescriptor.vertexFunction = vertexFunction;
        pipelineDescriptor.fragmentFunction = fragmentFunction;
        pipelineDescriptor.vertexDescriptor = _globeMesh->vertexDescriptor();
        pipelineDescriptor.inputPrimitiveTopology = MTLPrimitiveTopologyClassTriangle;
        
        _contentRenderPipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    }
    {
        vertexFunction = [library newFunctionWithName:@"vertex_environment"];
        fragmentFunction = [library newFunctionWithName:@"fragment_environment"];
        pipelineDescriptor.vertexFunction = vertexFunction;
        pipelineDescriptor.fragmentFunction = fragmentFunction;
        pipelineDescriptor.vertexDescriptor = _environmentMesh->vertexDescriptor();
        pipelineDescriptor.inputPrimitiveTopology = MTLPrimitiveTopologyClassTriangle;
        
        _environmentRenderPipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    }
    
    MTLDepthStencilDescriptor *depthDescriptor = [MTLDepthStencilDescriptor new];
    depthDescriptor.depthWriteEnabled = YES;
    depthDescriptor.depthCompareFunction = MTLCompareFunctionLess;
    _contentDepthStencilState = [_device newDepthStencilStateWithDescriptor:depthDescriptor];

    depthDescriptor.depthWriteEnabled = NO;
    depthDescriptor.depthCompareFunction = MTLCompareFunctionLess;
    _backgroundDepthStencilState = [_device newDepthStencilStateWithDescriptor:depthDescriptor];
}

void SpatialRenderer::drawAndPresent(cp_frame_t frame, cp_drawable_t drawable) {
    CFTimeInterval renderTime = CACurrentMediaTime();
    CFTimeInterval timestep = MIN(renderTime - _lastRenderTime, 1.0 / 60.0);
    _sceneTime += timestep;

    float c = cos(_sceneTime * 0.5f);
    float s = sin(_sceneTime * 0.5f);
    simd_float4x4 modelTransform = simd_matrix(simd_make_float4(   c, 0.0f,    -s, 0.0f),
                                               simd_make_float4(0.0f, 1.0f,  0.0f, 0.0f),
                                               simd_make_float4(   s, 0.0f,     c, 0.0f),
                                               simd_make_float4(0.0f, 0.0f, -1.5f, 1.0f));
    _globeMesh->setModelMatrix(modelTransform);

    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    
    size_t viewCount = cp_drawable_get_view_count(drawable);
    
    std::vector<MTLViewport> viewports;
    viewports.reserve(viewCount);
    
    std::vector<PoseConstants> poseConstants;
    poseConstants.reserve(viewCount);
    
    std::vector<PoseConstants> poseConstantsForEnvironment;
    poseConstantsForEnvironment.resize(viewCount);
    
    LayerConstants layerConstants;
    
    for (int i = 0; i < viewCount; ++i) {
        viewports[i] = viewportForViewIndex(drawable, i);
        
        poseConstants[i] = poseConstantsForViewIndex(drawable, i);
        
        poseConstantsForEnvironment[i] = poseConstantsForViewIndex(drawable, i);
        // Remove the translational part of the view matrix to make the environment stay "infinitely" far away
        poseConstantsForEnvironment[i].viewMatrix.columns[3] = simd_make_float4(0.0, 0.0, 0.0, 1.0);
    }
    
    if (_layerRendererLayout == cp_layer_renderer_layout_dedicated) {
        layerConstants.layerCount = 1;
        layerConstants.viewportCount = 1;
        
        for (int i = 0; i < viewCount; ++i) {
            MTLRenderPassDescriptor *renderPassDescriptor = createRenderPassDescriptor(drawable, i);
            id<MTLRenderCommandEncoder> renderCommandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
            
            [renderCommandEncoder setCullMode:MTLCullModeBack];

            [renderCommandEncoder setFrontFacingWinding:MTLWindingClockwise];
            [renderCommandEncoder setDepthStencilState:_backgroundDepthStencilState];
            [renderCommandEncoder setRenderPipelineState:_environmentRenderPipelineState];
            _environmentMesh->draw(renderCommandEncoder, &poseConstantsForEnvironment[i], &layerConstants, 1);
            
            [renderCommandEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
            [renderCommandEncoder setDepthStencilState:_contentDepthStencilState];
            [renderCommandEncoder setRenderPipelineState:_contentRenderPipelineState];
            _globeMesh->draw(renderCommandEncoder, &poseConstants[i], &layerConstants, 1);
            
            [renderCommandEncoder endEncoding];
        }
    }
    else {
        if (_layerRendererLayout == cp_layer_renderer_layout_layered) {
            layerConstants.layerCount = (unsigned)viewCount;
            layerConstants.viewportCount = 1;
        }
        else if (_layerRendererLayout == cp_layer_renderer_layout_shared) {
            layerConstants.layerCount = 1;
            layerConstants.viewportCount = (unsigned)viewCount;
        }
        
        MTLRenderPassDescriptor *renderPassDescriptor = createRenderPassDescriptor(drawable, 0);
        id<MTLRenderCommandEncoder> renderCommandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        
        if (_layerRendererLayout == cp_layer_renderer_layout_shared) {
            [renderCommandEncoder setViewports: &viewports[0] count: layerConstants.viewportCount];
        }
        
        [renderCommandEncoder setCullMode:MTLCullModeBack];

        [renderCommandEncoder setFrontFacingWinding:MTLWindingClockwise];
        [renderCommandEncoder setDepthStencilState:_backgroundDepthStencilState];
        [renderCommandEncoder setRenderPipelineState:_environmentRenderPipelineState];
        _environmentMesh->draw(renderCommandEncoder, &poseConstantsForEnvironment[0], &layerConstants, viewCount);
        
        [renderCommandEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
        [renderCommandEncoder setDepthStencilState:_contentDepthStencilState];
        [renderCommandEncoder setRenderPipelineState:_contentRenderPipelineState];
        _globeMesh->draw(renderCommandEncoder, &poseConstants[0], &layerConstants, viewCount);
        
        [renderCommandEncoder endEncoding];
    }

    cp_drawable_encode_present(drawable, commandBuffer);

    [commandBuffer commit];
}

MTLRenderPassDescriptor* SpatialRenderer::createRenderPassDescriptor(cp_drawable_t drawable, size_t index) {
    MTLRenderPassDescriptor *passDescriptor = [[MTLRenderPassDescriptor alloc] init];

    passDescriptor.colorAttachments[0].texture = cp_drawable_get_color_texture(drawable, index);
    passDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;

    passDescriptor.depthAttachment.texture = cp_drawable_get_depth_texture(drawable, index);
    passDescriptor.depthAttachment.storeAction = MTLStoreActionStore;

    if (_layerRendererLayout == cp_layer_renderer_layout_layered) {
        passDescriptor.renderTargetArrayLength = cp_drawable_get_view_count(drawable);
    }
    else {
        passDescriptor.renderTargetArrayLength = 1;
    }
    
    passDescriptor.rasterizationRateMap = cp_drawable_get_rasterization_rate_map(drawable, index);

    return passDescriptor;
}

MTLViewport SpatialRenderer::viewportForViewIndex(cp_drawable_t drawable, size_t index) {
    cp_view_t view = cp_drawable_get_view(drawable, index);
    cp_view_texture_map_t texture_map = cp_view_get_view_texture_map(view);
    return cp_view_texture_map_get_viewport(texture_map);
}

PoseConstants SpatialRenderer::poseConstantsForViewIndex(cp_drawable_t drawable, size_t index) {
    PoseConstants outPose;

    ar_device_anchor_t anchor = cp_drawable_get_device_anchor(drawable);

    simd_float4x4 poseTransform = ar_anchor_get_origin_from_anchor_transform(anchor);

    cp_view_t view = cp_drawable_get_view(drawable, index);
    simd_float4 tangents = cp_view_get_tangents(view);
    simd_float2 depth_range = cp_drawable_get_depth_range(drawable);
    SPProjectiveTransform3D projectiveTransform = SPProjectiveTransform3DMakeFromTangents(tangents[0], tangents[1],
                                                                                          tangents[2], tangents[3],
                                                                                          depth_range[1], depth_range[0],
                                                                                          true);
    outPose.projectionMatrix = matrix_float4x4_from_double4x4(projectiveTransform.matrix);

    simd_float4x4 cameraMatrix = simd_mul(poseTransform, cp_view_get_transform(view));
    outPose.viewMatrix = simd_inverse(cameraMatrix);
    return outPose;
}
