
#include "Mesh.h"

#import <ModelIO/ModelIO.h>

static id<MTLTexture> _Nullable CreateTextureFromImage(NSString *imageName, id<MTLDevice> device, NSError **error) {
    MTKTextureLoader *textureLoader = [[MTKTextureLoader alloc] initWithDevice:device];
    NSURL *imageURL = [[NSBundle mainBundle] URLForResource:imageName withExtension:nil];
    CGImageSourceRef imageSource = CGImageSourceCreateWithURL((__bridge CFURLRef)imageURL, NULL);
    if (imageSource) {
        CGImageRef image = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
        if (image) {
            id<MTLTexture> texture = [textureLoader newTextureWithCGImage:image options:nil error:error];
            CGImageRelease(image);
            return texture;
        }
        CFRelease(imageSource);
    }
    return nil;
}

MTLVertexDescriptor *Mesh::vertexDescriptor() const {
    MTLVertexDescriptor *vertexDescriptor = [MTLVertexDescriptor new];
    vertexDescriptor.attributes[0].format = MTLVertexFormatFloat3;
    vertexDescriptor.attributes[0].bufferIndex = 0;
    vertexDescriptor.attributes[0].offset = 0;
    vertexDescriptor.attributes[1].format = MTLVertexFormatFloat3;
    vertexDescriptor.attributes[1].bufferIndex = 0;
    vertexDescriptor.attributes[1].offset = sizeof(float) * 3;
    vertexDescriptor.attributes[2].format = MTLVertexFormatFloat2;
    vertexDescriptor.attributes[2].bufferIndex = 0;
    vertexDescriptor.attributes[2].offset = sizeof(float) * 6;
    vertexDescriptor.layouts[0].stride = sizeof(float) * 8;
    return vertexDescriptor;
}

TexturedMesh::TexturedMesh() = default;

TexturedMesh::TexturedMesh(MDLMesh *mdlMesh, NSString *imageName, id<MTLDevice> device) {
    NSError *error = nil;

    _texture = CreateTextureFromImage(imageName, device, &error);

    MDLVertexDescriptor *mdlVertexDescriptor = [MDLVertexDescriptor new];
    mdlVertexDescriptor.attributes[0].name = MDLVertexAttributePosition;
    mdlVertexDescriptor.attributes[0].format = MDLVertexFormatFloat3;
    mdlVertexDescriptor.attributes[0].bufferIndex = 0;
    mdlVertexDescriptor.attributes[0].offset = 0;
    mdlVertexDescriptor.attributes[1].name = MDLVertexAttributeNormal;
    mdlVertexDescriptor.attributes[1].format = MDLVertexFormatFloat3;
    mdlVertexDescriptor.attributes[1].bufferIndex = 0;
    mdlVertexDescriptor.attributes[1].offset = sizeof(float) * 3;
    mdlVertexDescriptor.attributes[2].name = MDLVertexAttributeTextureCoordinate;
    mdlVertexDescriptor.attributes[2].format = MDLVertexFormatFloat2;
    mdlVertexDescriptor.attributes[2].bufferIndex = 0;
    mdlVertexDescriptor.attributes[2].offset = sizeof(float) * 6;
    mdlVertexDescriptor.layouts[0].stride = sizeof(float) * 8;
    
    mdlMesh.vertexDescriptor = mdlVertexDescriptor;
    
    _mesh = [[MTKMesh alloc] initWithMesh:mdlMesh device:device error:&error];
}

void TexturedMesh::draw(id<MTLRenderCommandEncoder> renderCommandEncoder, PoseConstants poseConstants) {
    InstanceConstants instanceConstants;
    instanceConstants.modelMatrix  = modelMatrix();

    MTKSubmesh *submesh = _mesh.submeshes.firstObject;
    MTKMeshBuffer *vertexBuffer = _mesh.vertexBuffers.firstObject;
    [renderCommandEncoder setVertexBuffer:vertexBuffer.buffer
                                   offset:vertexBuffer.offset
                                  atIndex:0];
    [renderCommandEncoder setVertexBytes:&poseConstants length:sizeof(poseConstants) atIndex:1];
    [renderCommandEncoder setVertexBytes:&instanceConstants length:sizeof(instanceConstants) atIndex:2];
    [renderCommandEncoder setFragmentTexture:_texture atIndex:0];
    [renderCommandEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                                     indexCount:submesh.indexCount
                                      indexType:submesh.indexType
                                    indexBuffer:submesh.indexBuffer.buffer
                              indexBufferOffset:submesh.indexBuffer.offset];
}

SpatialEnvironmentMesh::SpatialEnvironmentMesh(NSString *imageName, CGFloat radius, id<MTLDevice> device) :
    TexturedMesh()
{
    NSError *error = nil;
    _texture = CreateTextureFromImage(imageName, device, &error);

    _environmentRotation = matrix_identity_float4x4;

    MTKMeshBufferAllocator *bufferAllocator = [[MTKMeshBufferAllocator alloc] initWithDevice:device];
    MDLMesh *mdlMesh = [MDLMesh newEllipsoidWithRadii:simd_make_float3(radius, radius, radius)
                                       radialSegments:24
                                     verticalSegments:24
                                         geometryType:MDLGeometryTypeTriangles
                                        inwardNormals:YES
                                           hemisphere:NO
                                            allocator:bufferAllocator];

    MDLVertexDescriptor *mdlVertexDescriptor = [MDLVertexDescriptor new];
    mdlVertexDescriptor.attributes[0].name = MDLVertexAttributePosition;
    mdlVertexDescriptor.attributes[0].format = MDLVertexFormatFloat3;
    mdlVertexDescriptor.attributes[0].bufferIndex = 0;
    mdlVertexDescriptor.attributes[0].offset = 0;
    mdlVertexDescriptor.attributes[1].name = MDLVertexAttributeNormal;
    mdlVertexDescriptor.attributes[1].format = MDLVertexFormatFloat3;
    mdlVertexDescriptor.attributes[1].bufferIndex = 0;
    mdlVertexDescriptor.attributes[1].offset = sizeof(float) * 3;
    mdlVertexDescriptor.attributes[2].name = MDLVertexAttributeTextureCoordinate;
    mdlVertexDescriptor.attributes[2].format = MDLVertexFormatFloat2;
    mdlVertexDescriptor.attributes[2].bufferIndex = 0;
    mdlVertexDescriptor.attributes[2].offset = sizeof(float) * 6;
    mdlVertexDescriptor.layouts[0].stride = sizeof(float) * 8;

    mdlMesh.vertexDescriptor = mdlVertexDescriptor;

    _mesh = [[MTKMesh alloc] initWithMesh:mdlMesh device:device error:&error];
}


void SpatialEnvironmentMesh::draw(id<MTLRenderCommandEncoder> renderCommandEncoder, PoseConstants poseConstants) {
    EnvironmentConstants environmentConstants;
    environmentConstants.modelMatrix = modelMatrix();
    environmentConstants.environmentRotation = matrix_identity_float4x4;

    // Remove the translational part of the view matrix to make the environment stay "infinitely" far away
    poseConstants.viewMatrix.columns[3] = simd_make_float4(0.0, 0.0, 0.0, 1.0);

    MTKSubmesh *submesh = _mesh.submeshes.firstObject;
    MTKMeshBuffer *vertexBuffer = _mesh.vertexBuffers.firstObject;
    [renderCommandEncoder setVertexBuffer:vertexBuffer.buffer
                                   offset:vertexBuffer.offset
                                  atIndex:0];
    [renderCommandEncoder setVertexBytes:&poseConstants length:sizeof(poseConstants) atIndex:1];
    [renderCommandEncoder setVertexBytes:&environmentConstants length:sizeof(environmentConstants) atIndex:2];
    [renderCommandEncoder setFragmentTexture:_texture atIndex:0];
    [renderCommandEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                                     indexCount:submesh.indexCount
                                      indexType:submesh.indexType
                                    indexBuffer:submesh.indexBuffer.buffer
                              indexBufferOffset:submesh.indexBuffer.offset];
}
