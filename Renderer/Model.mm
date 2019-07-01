//
//  Model.m
//  MetalStudy
//
//  Created by Leandro Freire on 01/04/2019.
//  Copyright © 2019 Leandro Freire. All rights reserved.
//

#import "Model.h"
#import <ModelIO/ModelIO.h>
#import "TextureManager.h"

@implementation Model

@synthesize buffers = _buffers;
//@synthesize renderState = _renderState;
@synthesize depthState = _depthState;

-(id) initWithMesh:(MTKMesh*)mesh device:(id<MTLDevice>) device colorFormat:(MTLPixelFormat)colorFormat
{
    if (self = [super init])
    {
        _mesh = [mesh retain];
        self.buffers = [NSMutableArray array];
        for(MTKMeshBuffer* meshBuffer in _mesh.vertexBuffers)
        {
            [_buffers addObject:meshBuffer.buffer];
        }
        
        self.depthState = [device newDepthStencilStateWithDescriptor:[self buildDepthDescriptor]];
        self.samplerState = [device newSamplerStateWithDescriptor:[self buildSamplerDescriptor]];
    }
    return self;
}

-(id) initWithMDLMesh:(MDLMesh*)mdlMesh device:(id<MTLDevice>) device colorFormat:(MTLPixelFormat)colorFormat vertexDescriptor:(MDLVertexDescriptor *)vertexDescriptor {
    
    [mdlMesh addTangentBasisForTextureCoordinateAttributeNamed:MDLVertexAttributeTextureCoordinate
                                              normalAttributeNamed:MDLVertexAttributeNormal
                                             tangentAttributeNamed:MDLVertexAttributeTangent];
    
    [mdlMesh addTangentBasisForTextureCoordinateAttributeNamed:MDLVertexAttributeTextureCoordinate
                                             tangentAttributeNamed:MDLVertexAttributeTangent
                                           bitangentAttributeNamed:MDLVertexAttributeBitangent];
    
    mdlMesh.vertexDescriptor = vertexDescriptor;
    
    MTKMesh* mesh = [[[MTKMesh alloc] initWithMesh:mdlMesh
                                            device:device
                                             error:nil] autorelease];
    _aabb = mdlMesh.boundingBox;
    for (int i = 0; i < mesh.submeshes.count; ++i) {
        MTKSubmesh* submesh =  [mesh.submeshes objectAtIndex:i];
        Material mat;
        TextureMap maps;
        MDLMaterial* m = [mdlMesh.submeshes objectAtIndex:i].material;
        NSString* texName = [m propertyWithSemantic:MDLMaterialSemanticBaseColor].stringValue;
        if ([texName isEqualToString:@"textures/gi_flag.tga"]) continue;
        if (texName)
        {
            maps.diffuse = [[TextureManager sharedManager] loadTexture:texName device:device SRGB:NO];
        }
        
        texName = [m propertyWithSemantic:MDLMaterialSemanticTangentSpaceNormal].stringValue;
        if (texName)
        {
            maps.normal = [[TextureManager sharedManager] loadTexture:texName device:device SRGB:NO];
        }
        
        texName = [m propertyNamed:@"specular"].stringValue;
        if (texName)
        {
            maps.specular = [[TextureManager sharedManager] loadTexture:texName device:device SRGB:NO];
        }
        
        texName = [m propertyNamed:@"opacity"].stringValue;
        if (texName)
        {
            maps.alpha = [[TextureManager sharedManager] loadTexture:texName device:device SRGB:NO];
        }
        
        mat.diffuseColor = [m propertyWithSemantic:MDLMaterialSemanticBaseColor].float3Value;
        mat.specularColor = [m propertyWithSemantic:MDLMaterialSemanticSpecular].float3Value;
        mat.specularExponent = [m propertyWithSemantic:MDLMaterialSemanticSpecularExponent].floatValue;
        mat.transparency = [m propertyNamed:@"d"].floatValue;
        
        id<MTLRenderPipelineState> renderState = [device newRenderPipelineStateWithDescriptor:[self buildDescriptor:device colorFormat:colorFormat vertexDecriptor:mesh.vertexDescriptor maps:(TextureMap&) maps] error:nil];
        _submeshes.push_back({
            submesh.indexBuffer.buffer,
            renderState,
            mat,
            maps,
            (int)submesh.primitiveType,
            (int)submesh.indexCount,
            (int)submesh.indexBuffer.offset,
            (int)submesh.indexType
        });
    }
    
    if (self = [self initWithMesh:mesh device:device colorFormat:colorFormat])
    {
    }
    return self;
}

-(id) initWithName:(NSString*)name device:(id<MTLDevice>) device colorFormat:(MTLPixelFormat)colorFormat vertexDescriptor:(MDLVertexDescriptor *)vertexDescriptor
{
    NSURL* assetUrl = [[NSBundle mainBundle] URLForResource:name withExtension:@"obj"];
    MTKMeshBufferAllocator* allocator = [[MTKMeshBufferAllocator alloc] initWithDevice:device];
    
    MDLAsset* asset = [[MDLAsset alloc] initWithURL:assetUrl
                                   vertexDescriptor:nil
                                    bufferAllocator:allocator];
    MDLMesh* mdlMesh = (MDLMesh*)[asset objectAtIndex:0];
    
    if (self = [self initWithMDLMesh:mdlMesh device:device colorFormat:colorFormat vertexDescriptor:vertexDescriptor]) {}
    
    return self;
}

-(MTLRenderPipelineDescriptor*) buildDescriptor:(id<MTLDevice>) device colorFormat:(MTLPixelFormat)colorFormat vertexDecriptor:(MDLVertexDescriptor*)vertexDescriptor maps:(TextureMap&) maps
{
    const bool hasNormal = maps.normal ? true : false;
    const bool hasDiffuse = maps.diffuse ? true : false;
    const bool hasSpecular = maps.specular ? true : false;
    const bool hasAlpha = maps.alpha ? true : false;
    MTLFunctionConstantValues* functionValues = [MTLFunctionConstantValues new];
    [functionValues setConstantValue:&hasNormal type:MTLDataTypeBool atIndex:NormalMapConstant];
    [functionValues setConstantValue:&hasDiffuse type:MTLDataTypeBool atIndex:DiffuseMapConstant];
    [functionValues setConstantValue:&hasSpecular type:MTLDataTypeBool atIndex:SpecularMapConstant];
    [functionValues setConstantValue:&hasAlpha type:MTLDataTypeBool atIndex:AlphaMapConstant];
    
    id <MTLLibrary> library = [device newDefaultLibrary];
    id <MTLFunction> vertexFunction = [library newFunctionWithName:@"vertex_main"];
    id <MTLFunction> fragmentFunction = [library newFunctionWithName:@"fragment_main" constantValues:functionValues error:nil];
    
     MTLRenderPipelineDescriptor* descriptor = [[MTLRenderPipelineDescriptor alloc] init];
    descriptor.colorAttachments[0].pixelFormat = colorFormat;
    
    //MSAA
    descriptor.sampleCount = 4;
    
//    descriptor.colorAttachments[0].blendingEnabled = YES;
//    descriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
//    descriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
//    descriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
//    descriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
//    descriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
//    descriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;

    descriptor.vertexFunction = vertexFunction;
    descriptor.fragmentFunction = fragmentFunction;
    descriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(vertexDescriptor);
    descriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
    
    return descriptor;
}

-(MTLDepthStencilDescriptor*) buildDepthDescriptor
{
    MTLDepthStencilDescriptor* descriptor = [[[MTLDepthStencilDescriptor alloc] init] autorelease];
    descriptor.depthCompareFunction = MTLCompareFunctionLess;
    descriptor.depthWriteEnabled = YES;
    
    return descriptor;
}

-(MTLSamplerDescriptor*) buildSamplerDescriptor
{
    MTLSamplerDescriptor* descriptor = [[[MTLSamplerDescriptor alloc] init] autorelease];
    descriptor.tAddressMode = MTLSamplerAddressModeRepeat;
    descriptor.sAddressMode = MTLSamplerAddressModeRepeat;
    descriptor.minFilter = MTLSamplerMinMagFilterNearest;
    descriptor.magFilter = MTLSamplerMinMagFilterLinear;
    descriptor.mipFilter = MTLSamplerMipFilterLinear;
    descriptor.maxAnisotropy = 8;
    
    return descriptor;
}

-(std::vector<Submesh>&)submeshes
{
    return _submeshes;
}

-(MDLAxisAlignedBoundingBox) getAABB
{
    return _aabb;
}

@end


