//
//  Primitive.m
//  MetalStudy
//
//  Created by Leandro Freire on 27/03/2019.
//  Copyright © 2019 Leandro Freire. All rights reserved.
//

#import "Primitive.h"
#import <MetalKit/MetalKit.h>

@implementation Primitive

+(MDLMesh*)makeCube:(id<MTLDevice>)device withSize:(float)size
{
    id<MDLMeshBufferAllocator> allocator = [[MTKMeshBufferAllocator alloc] initWithDevice:device];
    MDLMesh* mdlMesh = [[MDLMesh newBoxWithDimensions:(vector_float3){size, size, size}
                                             segments:(vector_uint3){1, 1, 1}
                                         geometryType:MDLGeometryTypeTriangles
                                        inwardNormals:NO
                                            allocator:allocator] autorelease];
    
    return mdlMesh;
}

+(MDLMesh*)makeSphere:(id<MTLDevice>)device withSize:(float)size
{
    id<MDLMeshBufferAllocator> allocator = [[MTKMeshBufferAllocator alloc] initWithDevice:device];
    MDLMesh* mdlMesh = [[[MDLMesh alloc] initSphereWithExtent:(vector_float3){size, size, size}
                                         segments:(vector_uint2){100, 100}
                                    inwardNormals:NO
                                     geometryType:MDLGeometryTypeTriangles
                                        allocator:allocator] autorelease];
    
    return mdlMesh;
    
}

@end
