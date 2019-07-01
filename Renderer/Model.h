//
//  Model.h
//  MetalStudy
//
//  Created by Leandro Freire on 01/04/2019.
//  Copyright © 2019 Leandro Freire. All rights reserved.
//
#import "Node.h"
#import <MetalKit/MetalKit.h>
#import "ShaderTypes.h"
#include <vector>

struct TextureMap
{
    TextureMap() : diffuse(nil), normal(nil), specular(nil), alpha(nil) {}
    id<MTLTexture> diffuse;
    id<MTLTexture> normal;
    id<MTLTexture> specular;
    id<MTLTexture> alpha;
};

struct Submesh
{
    id<MTLBuffer> buffer;
    id<MTLRenderPipelineState> renderState;
    Material material;
    TextureMap maps;
    int primitiveType;
    int indexCount;
    int offset;
    int indexType;
};

@interface Model : Node
{
    MTKMesh* _mesh;
    NSMutableArray<id<MTLBuffer>>* _buffers;
    id<MTLRenderPipelineState> _renderState;
    id<MTLDepthStencilState> _depthState;
    id<MTLSamplerState> _samplerState;
    MDLAxisAlignedBoundingBox _aabb;
    std::vector<Submesh> _submeshes;
}

@property(nonatomic, readwrite, retain) NSMutableArray<id<MTLBuffer>>* buffers;
@property(nonatomic, readwrite, retain) id<MTLDepthStencilState> depthState;
@property(nonatomic, readwrite, retain) id<MTLSamplerState> samplerState;

//-(id) initWithMesh:(MTKMesh*) mesh device:(id<MTLDevice>) device colorFormat:(MTLPixelFormat)colorFormat;
-(id) initWithMDLMesh:(MDLMesh*) mesh device:(id<MTLDevice>) device colorFormat:(MTLPixelFormat)colorFormat vertexDescriptor:(MDLVertexDescriptor*)vertexDescriptor;
-(id) initWithName:(NSString*) name device:(id<MTLDevice>) device colorFormat:(MTLPixelFormat)colorFormat vertexDescriptor:(MDLVertexDescriptor*)vertexDescriptor;
-(std::vector<Submesh>&)submeshes;
-(MDLAxisAlignedBoundingBox) getAABB;
@end
