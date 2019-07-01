//
//  Renderer.m
//  MetalStudy
//
//  Created by Leandro Freire on 27/03/2019.
//  Copyright © 2019 Leandro Freire. All rights reserved.
//

#import "Renderer.h"
#import "Primitive.h"
#import "Model.h"
#import "Camera.h"
#include "MathUtils.h"

@implementation Renderer
-(id) initWithView:(MTKView *)view
{
    if (self = [super init])
    {
        _models = [[NSMutableArray alloc] init];
        _view = view;
        _fragUniforms.lightCount = 1;
        _inFlightSemaphore = dispatch_semaphore_create(MaxBuffersInFlight);
        [self mtkView:_view drawableSizeWillChange:_view.bounds.size];
    }
    return self;
}

-(void) loadScene
{
    simd_float3 targetZero = (simd_float3){0.0f, 0.0f, 0.0f};
    _currentCamera = [[Camera alloc] init];
    [_currentCamera lookAt:targetZero];
    
    Model* model = [[[Model alloc] initWithName:@"sponza" device:_device colorFormat:_view.colorPixelFormat] autorelease];
    [model setPosition:(simd::float3){0.0f, 0.0f, 0.0f}];
    model.rotation = (simd::float3){0.0f, 0.0f, 0.0f};
    model.scale = (simd::float3){0.001f, 0.001f, 0.001f};
    _sceneAABB = [model getAABB];
    [_models addObject:model];
    
    _directionalLight = [self buildDefaultLight];
    _directionalLight.position = (vector_float3){0.0f, 10.0f, 0.4f};
    _directionalLight.type = DirectionalLight;
    _directionalLight.attenuation = (vector_float3){0.2, 0.4, 0.5};
    
    //        _lights[0] = [self buildDefaultLight];
    //        _lights[0].position = (vector_float3){0.0f, 0.5f, -0.1f};
    //        _lights[0].type = PointLight;
    //        _lights[0].attenuation = (vector_float3){0.4, 0.6, 0.7};
    //        _lights[0].color = (vector_float3){255/255.0f, 199/255.0f, 130/255.0f};
    //        _lights[0].specularColor = (vector_float3){255/255.0f, 147/255.0f, 52/255.0f};
    
    _shadowCamera = [[Camera orthographic:-2 top:2 left:-2 right:2 near:0.01f far:100.0f] retain];
    _shadowCamera.position = _directionalLight.position;
    [_shadowCamera lookAt:targetZero];
    
    float quadVertices[] = {
        -1.0, 1.0,
        1.0, -1.0,
        -1.0, -1.0,
        -1.0, 1.0,
        1.0, 1.0,
        1.0, -1.0
    };
    
    float quadTexCoords[] = {
        0.0, 0.0,
        1.0, 1.0,
        0.0, 1.0,
        0.0, 0.0,
        1.0, 0.0,
        1.0, 1.0
    };
    
    _quadVertices = [_device newBufferWithBytes:quadVertices length:sizeof(float)*12 options:MTLResourceUsageRead];
    _quadTexCoords = [_device newBufferWithBytes:quadTexCoords length:sizeof(float)*12 options:MTLResourceUsageRead];
}

-(id<MTLCommandBuffer>)beginFrame:(SEL)update
{
    if (update)
    {
        dispatch_semaphore_wait(_inFlightSemaphore, DISPATCH_TIME_FOREVER);
    }
    
    id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    
    __block dispatch_semaphore_t block_sema = _inFlightSemaphore;
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer)
     {
         dispatch_semaphore_signal(block_sema);
     }];
    
    if (update)
    {
        [self performSelector:update];
    }
    
    return commandBuffer;
}

-(void)endFrame:(nonnull id <MTLCommandBuffer>) commandBuffer
{
    // Schedule a present once the framebuffer is complete using the current drawable
    if(_view.currentDrawable)
    {
        [commandBuffer presentDrawable:_view.currentDrawable];
    }
    
    // Finalize rendering here & push the command buffer to the GPU
    [commandBuffer commit];
}

-(void)updateBuffers
{
    
}

- (void)drawInMTKView:(nonnull MTKView *)view
{
    id<MTLCommandBuffer> commandBuffer = [self beginFrame:@selector(updateBuffers)];
    
    id<MTLRenderCommandEncoder> shadowEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_shadowRenderPassDescriptor];
    [self renderShadowPass:shadowEncoder];
    
    _gBufferRenderPassDescriptor.depthAttachment.texture = _view.depthStencilTexture;
    _gBufferRenderPassDescriptor.stencilAttachment.texture = _view.depthStencilTexture;
    
    id<MTLRenderCommandEncoder> gBufferEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_gBufferRenderPassDescriptor];
    [self renderGbufferPass:gBufferEncoder];
    
    [commandBuffer commit];
    
    commandBuffer = [self beginFrame:nil];
    
    id <MTLTexture> drawableTexture =  _view.currentDrawable.texture;
    if (drawableTexture)
    {
        // Render the lighting and composition pass
        _finalRenderPassDescriptor.colorAttachments[0].texture = drawableTexture;
        _finalRenderPassDescriptor.depthAttachment.texture = _view.depthStencilTexture;
        _finalRenderPassDescriptor.stencilAttachment.texture = _view.depthStencilTexture;
        
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_finalRenderPassDescriptor];
        renderEncoder.label = @"Lighting & Composition Pass";
        
        [self renderDirectionalLightPass:renderEncoder];
        
        [self drawPointLightMask:renderEncoder];
        
        [self drawPointLights:renderEncoder];
        
        [renderEncoder endEncoding];
    }
    
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_view.currentRenderPassDescriptor];
    [self renderCompositionPass:renderEncoder];
    
    [self endFrame:commandBuffer];
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    _currentCamera.aspect = size.width / (float)size.height;
    _uniforms.projectionMatrix = _currentCamera.projection;
    [self buildGbufferRenderPassDescriptor:size];
}

#pragma cameraControl

-(void)zoomCam:(CGFloat)delta sensitivity:(float)sensitivity
{
    simd::float3 cameraVector = (simd::float3){_currentCamera.front.x, _currentCamera.front.y, _currentCamera.front.z};
    _currentCamera.position = _currentCamera.position + delta * sensitivity * cameraVector;
}

-(void)lookAt:(CGPoint) t
{
    double sensitivity = 0.1;
    t.x *= sensitivity;
    t.y *= sensitivity;
    x+=M_PI * (t.x/180.0f);
    y+=M_PI * (t.y/180.0f);
    
    simd_float3 f;
    f.x = cos(y) * cos(x);
    f.y = sin(y);
    f.z = cos(y) * sin(x);
    
    [_currentCamera lookAt:f];
}

#pragma loadResources

-(void) loadMetal
{
    _view.sampleCount = 4;
    _view.delegate = self;
    _view.clearColor = MTLClearColorMake(0.73, 0.92, 1.0, 1.0);
    _view.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
    
    _device = _view.device;
    _commandQueue = [_device newCommandQueue];
    
    [self buildShadowRenderPassDescriptor];
    [self buildGbufferRenderPassDescriptor:_view.bounds.size];
    [self buildFinalRenderPassDescriptor];
    
    [self buildShadowPipeline];
    [self buildGbufferRenderPipelineState];
    [self buildCompositionRenderPipelineState];
}

-(void)buildShadowRenderPassDescriptor
{
    [_shadowRenderPassDescriptor release];
    _shadowRenderPassDescriptor = [[MTLRenderPassDescriptor renderPassDescriptor] retain];
    _shadowTexture = [self buildTexture:MTLPixelFormatDepth32Float size:CGSizeMake(4096, 4096) label:@"Shadow"];
    [self setupDepthAttachment:_shadowTexture renderPassDescriptor:&_shadowRenderPassDescriptor];
}

-(void)buildGbufferRenderPassDescriptor:(CGSize)size
{
    [_gBufferRenderPassDescriptor release];
    _gBufferRenderPassDescriptor = [[MTLRenderPassDescriptor renderPassDescriptor] retain];
    _albedoTexture = [self buildTexture:MTLPixelFormatBGRA8Unorm size:size label:@"Albedo Texture"];
    _normalTexture = [self buildTexture:MTLPixelFormatRGBA16Float size:size label:@"Normal Texture"];
    _positionTexture = [self buildTexture:MTLPixelFormatRGBA16Float size:size label:@"Position Texture"];
    
    NSArray* textures = [NSArray arrayWithObjects:_albedoTexture, _normalTexture, _positionTexture, nil];
    int position = 0;
    
    for (id<MTLTexture> texture in textures) {
        [self setupColorAttachment:position texture:texture renderPassDescriptor:&_gBufferRenderPassDescriptor];
        ++position;
    }
    
    [self setupDepthAttachment:nil renderPassDescriptor:&_gBufferRenderPassDescriptor];
}

-(void)buildFinalRenderPassDescriptor
{
    _finalRenderPassDescriptor = [MTLRenderPassDescriptor new];
    _finalRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    _finalRenderPassDescriptor.depthAttachment.loadAction = MTLLoadActionLoad;
    _finalRenderPassDescriptor.stencilAttachment.loadAction = MTLLoadActionLoad;
}

-(void)buildShadowPipeline
{
    MTLRenderPipelineDescriptor* pipelineDescriptor = [[[MTLRenderPipelineDescriptor alloc] init] autorelease];
    pipelineDescriptor.vertexFunction = [[_device newDefaultLibrary] newFunctionWithName:@"vertex_depth"];
    pipelineDescriptor.fragmentFunction = nil;
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatInvalid;
    pipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO([Model defaultVertexDescriptor]);
    pipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
    _shadowPipelineState = [[_device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:nil] retain];
    
    MTLDepthStencilDescriptor *depthStateDesc = [[[MTLDepthStencilDescriptor alloc] init] autorelease];
    depthStateDesc.label = @"Shadow Gen";
    depthStateDesc.depthCompareFunction = MTLCompareFunctionLessEqual;
    depthStateDesc.depthWriteEnabled = YES;
    _shadowDepthStencilState = [_device newDepthStencilStateWithDescriptor:depthStateDesc];
}

-(void)buildGbufferRenderPipelineState
{
    MTLRenderPipelineDescriptor* pipelineDescriptor = [[[MTLRenderPipelineDescriptor alloc] init] autorelease];
    id<MTLLibrary> lib = [_device newDefaultLibrary];
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineDescriptor.colorAttachments[1].pixelFormat = MTLPixelFormatRGBA16Float;
    pipelineDescriptor.colorAttachments[2].pixelFormat = MTLPixelFormatRGBA16Float;
    pipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
    pipelineDescriptor.label = @"GBuffer state";
    pipelineDescriptor.vertexFunction = [lib newFunctionWithName:@"vertex_main"];
    pipelineDescriptor.fragmentFunction = [lib newFunctionWithName:@"gBufferFragment"];
    pipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO([Model defaultVertexDescriptor]);
    _gBufferPipelineState = [[_device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:nil] retain];
    
    MTLStencilDescriptor* stencilStateDesc = [[MTLStencilDescriptor new] autorelease];
    stencilStateDesc.stencilCompareFunction = MTLCompareFunctionAlways;
    stencilStateDesc.stencilFailureOperation = MTLStencilOperationKeep;
    stencilStateDesc.depthFailureOperation = MTLStencilOperationKeep;
    stencilStateDesc.depthStencilPassOperation = MTLStencilOperationReplace;
    stencilStateDesc.readMask = 0x0;
    stencilStateDesc.writeMask = 0xFF;

    MTLDepthStencilDescriptor *depthStateDesc = [[MTLDepthStencilDescriptor new] autorelease];
    depthStateDesc.label =  @"GBuffer depth";
    depthStateDesc.depthCompareFunction = MTLCompareFunctionLess;
    depthStateDesc.depthWriteEnabled = YES;
    depthStateDesc.frontFaceStencil = stencilStateDesc;
    depthStateDesc.backFaceStencil = stencilStateDesc;
    
    _gBufferDepthStencilState = [_device newDepthStencilStateWithDescriptor:depthStateDesc];
}

-(void)buildCompositionRenderPipelineState
{
    MTLRenderPipelineDescriptor* pipelineDescriptor = [[[MTLRenderPipelineDescriptor alloc] init] autorelease];
    id<MTLLibrary> lib = [_device newDefaultLibrary];
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
    pipelineDescriptor.label = @"GBuffer state";
    pipelineDescriptor.vertexFunction = [lib newFunctionWithName:@"vertex_main"];
    pipelineDescriptor.fragmentFunction = [lib newFunctionWithName:@"gBufferFragment"];
    pipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO([Model defaultVertexDescriptor]);
    _gBufferPipelineState = [[_device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:nil] retain];
}

#pragma render

-(void)renderShadowPass:(id<MTLRenderCommandEncoder>) renderEncoder
{
    [renderEncoder pushDebugGroup:@"Shadow pass"];
    [renderEncoder setLabel:@"Shadow encoder"];
    [renderEncoder setRenderPipelineState:_shadowPipelineState];
    [renderEncoder setDepthStencilState:_shadowDepthStencilState];
    [renderEncoder setDepthBias:0.015 slopeScale:7 clamp:0.02];
    [renderEncoder setCullMode:MTLCullModeBack];
    
    _uniforms.viewMatrix = [_shadowCamera view];
    _uniforms.projectionMatrix = _shadowCamera.projection;
    _uniforms.shadowMatrix = matrix_multiply(_uniforms.projectionMatrix, _uniforms.viewMatrix);
    
    for(Model* model : _models)
    {
        [self draw:renderEncoder model:model];
    }
    
    [renderEncoder endEncoding];
    [renderEncoder popDebugGroup];
}

-(void)draw: (id<MTLRenderCommandEncoder>) renderEncoder model:(Model*)model
{
    _uniforms.modelViewMatrix = matrix_multiply([_currentCamera view], [model modelMatrix]);
    _uniforms.modelMatrix = [model modelMatrix];
    _uniforms.normalMatrix = math::normal(_uniforms.modelMatrix);
    
    _fragUniforms.cameraPos = _currentCamera.position;
    
    [renderEncoder setVertexBytes:&_uniforms length:sizeof(Uniforms) atIndex:BufferIndexUniforms];
    
    int index = 0;
    for (id<MTLBuffer> buffer in model.buffers) {
        [renderEncoder setVertexBuffer:buffer offset:0 atIndex:index];
        index++;
    }
    
    [renderEncoder setFragmentSamplerState:model.samplerState atIndex:TextureSampler];
    
    auto submeshes = [model submeshes];
    
    for(Submesh& submesh : submeshes)
    {
        if (![[renderEncoder label] isEqualToString:@"Shadow encoder"])
        {
            if (submesh.maps.diffuse)
            {
                [renderEncoder setFragmentTexture:submesh.maps.diffuse atIndex:Diffuse];
            }
            
            _fragUniforms.hasNormalMap = 0;
            if (submesh.maps.normal)
            {
                _fragUniforms.hasNormalMap = 1;
                [renderEncoder setFragmentTexture:submesh.maps.normal atIndex:Normal];
            }
            _fragUniforms.hasSpecularMap = 0;
            if (submesh.maps.specular)
            {
                _fragUniforms.hasSpecularMap = 1;
                [renderEncoder setFragmentTexture:submesh.maps.specular atIndex:Specular];
            }
            
            if (submesh.maps.alpha)
            {
                [renderEncoder setFragmentTexture:submesh.maps.alpha atIndex:Alpha];
            }
        }
        
        [renderEncoder setFragmentBytes:&_fragUniforms length:sizeof(FragmentUniforms) atIndex:BufferIndexFragmentUniforms];
        [renderEncoder setFragmentBytes:&submesh.material length:sizeof(Material) atIndex:BufferIndexFragmentMaterial];
        
        [renderEncoder drawIndexedPrimitives:(MTLPrimitiveType)submesh.primitiveType
                                  indexCount:submesh.indexCount
                                   indexType:(MTLIndexType)submesh.indexType
                                 indexBuffer:submesh.buffer
                           indexBufferOffset:submesh.offset];
    }
}

-(void)renderGbufferPass:(id<MTLRenderCommandEncoder>) renderEncoder
{
    [renderEncoder pushDebugGroup:@"Gbuffer Pass"];
    [renderEncoder setLabel:@"Gbuffer encoder"];
    [renderEncoder setRenderPipelineState:_gBufferPipelineState];
    [renderEncoder setDepthStencilState:_gBufferDepthStencilState];
    [renderEncoder setCullMode:MTLCullModeBack];
    
    [renderEncoder setStencilReferenceValue:128];
    //    [renderEncoder setVertexBuffer:_uniformBuffers[_currentBufferIndex] offset:0 atIndex:AAPLBufferIndexUniforms];
    //    [renderEncoder setFragmentBuffer:_uniformBuffers[_currentBufferIndex] offset:0 atIndex:AAPLBufferIndexUniforms];
    //    [renderEncoder setFragmentTexture:_shadowMap atIndex:AAPLTextureIndexShadow];
    
    [renderEncoder setFragmentTexture:_shadowTexture atIndex:Shadow];
    
    _uniforms.projectionMatrix = _currentCamera.projection;
    _uniforms.viewMatrix = [_currentCamera view];
    
    for(Model* model : _models)
    {
        [self draw:renderEncoder model:model];
    }
    [renderEncoder endEncoding];
    [renderEncoder popDebugGroup];
}

-(void)renderDirectionalLightPass:(id<MTLRenderCommandEncoder>) renderEncoder
{
    [renderEncoder pushDebugGroup:@"Composition Pass"];
    [renderEncoder setLabel:@"Composition Encoder"];
    
    [renderEncoder setRenderPipelineState:_directionalLightPipelineState];
    [renderEncoder setDepthStencilState:_directionalLightDepthStencilState];
    
    [renderEncoder setCullMode:MTLCullModeBack];
    [renderEncoder setStencilReferenceValue:128];
    [renderEncoder setVertexBuffer:_quadVertices offset:0 atIndex:VertexAttributePosition];
    [renderEncoder setVertexBuffer:_quadTexCoords offset:0 atIndex:VertexAttributeTexcoord];
    
    [renderEncoder setFragmentTexture:_albedoTexture atIndex:0];
    [renderEncoder setFragmentTexture:_normalTexture atIndex:1];
    [renderEncoder setFragmentTexture:_positionTexture atIndex:2];
    [renderEncoder setFragmentBytes:&_fragUniforms length:sizeof(FragmentUniforms) atIndex:BufferIndexFragmentUniforms];
    
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
    
    [renderEncoder endEncoding];
    [renderEncoder popDebugGroup];
}

#pragma helpers

-(Light) buildDefaultLight
{
    Light light;
    light.position = (vector_float3){0.0f, 0.0f, 0.0f};
    light.color = (vector_float3){1.0f, 1.0f, 1.0f};
    light.specularColor = (vector_float3){1.0f, 1.0f, 1.0f};
    light.intensity = 1.0;
    light.attenuation = (vector_float3){1.0f, 0.0f, 0.0f};
    light.type = LightType::DirectionalLight;
    return light;
}

-(id<MTLTexture>) buildTexture:(MTLPixelFormat)format size:(CGSize)size label:(NSString*) label
{
    MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:format width:size.width height:size.height mipmapped:NO];
    descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
    descriptor.storageMode = MTLStorageModePrivate;
    id<MTLTexture> texture = [_device newTextureWithDescriptor:descriptor];
    texture.label = [NSString stringWithFormat:@"%@ texture", label];
    return texture;
}

-(void)setupDepthAttachment:(id<MTLTexture>)texture renderPassDescriptor:(MTLRenderPassDescriptor**) descriptor
{
    (*descriptor).depthAttachment.texture = texture;
    (*descriptor).depthAttachment.loadAction = MTLLoadActionClear;
    (*descriptor).depthAttachment.storeAction = MTLStoreActionStore;
    (*descriptor).depthAttachment.clearDepth = 1;
}

-(void)setupColorAttachment:(int)position texture:(id<MTLTexture>)texture renderPassDescriptor:(MTLRenderPassDescriptor**) descriptor
{
    MTLRenderPassColorAttachmentDescriptor* attachment = (*descriptor).colorAttachments[position];
    attachment.texture = texture;
    attachment.loadAction = MTLLoadActionClear;
    attachment.storeAction = MTLStoreActionStore;
    attachment.clearColor = MTLClearColorMake(0.73, 0.92, 1.0, 1.0);
}

@end
