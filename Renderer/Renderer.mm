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
Model* model;
-(id) initWithView:(MTKView *)view mode:(RenderMode) renderMode
{
    if (self = [super init])
    {
        _renderMode = renderMode;
        _device = MTLCreateSystemDefaultDevice();
        _commandQueue = [_device newCommandQueue];
        
        _currentCamera = [[Camera alloc] init];
        [_currentCamera lookAt:CGPointZero];
        //_currentCamera =[[Camera orthographic:-2 top:2 left:-2 right:2 near:0.1f far:100.0f] retain];
        _models = [[NSMutableArray alloc] init];
        _view = view;
        _view.sampleCount = 4;
        _view.device = _device;
        _view.delegate = self;
        _view.clearColor = MTLClearColorMake(0.73, 0.92, 1.0, 1.0);
        _view.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
        
        rotate = 0.0f;
        model = [[[Model alloc] initWithName:@"sponza" device:_device colorFormat:_view.colorPixelFormat] autorelease];
        [model setPosition:(simd::float4){0.0f, 0.0f, 0.0f, 1.0f}];
        model.rotation = (simd::float3){0.0f, 0.0f, 0.0f};
        model.scale = (simd::float3){0.001f, 0.001f, 0.001f};
        
        _lightDebug = [[Model alloc] initWithMDLMesh:[Primitive makeCube:_device withSize:1.0f] device:_device colorFormat:_view.colorPixelFormat];
        _lightDebug.scale = (simd::float3){0.1f, 0.1f, 0.1f};
        _lightDebug.position = (simd::float4){0.0f, 10.0f, 0.4f, 1.0f};
        [_models addObject:model];
        //[_models addObject:_lightDebug];
        _sceneAABB = [model getAABB];
        
        //build shadow map
         _shadowRenderPassDescriptor = [[MTLRenderPassDescriptor renderPassDescriptor] retain];
        [self  buildShadowPipeline];
        
        if (renderMode == RenderModeDeferred)
        {
            _view.framebufferOnly = NO;
            [self buildGbufferRenderPipelineState];
            //[self buildCompositionRenderPipeline];
        }
//        _shadowtexture = [self buildTexture:MTLPixelFormatDepth32Float size:_view.drawableSize label:@"Shadow"];
//        [self setupDepthAttachment:_shadowtexture renderPassDescriptor:_shadowRenderPassDescriptor];
        //build shadow render state pipeline
        
        //build G buffer render state pipeline
        
        //build quad buffer
        
        //build composition render state pipeline
        
//        _lights[0] = [self buildDefaultLight];
//        _lights[0].position = (vector_float3){0.0f, 0.5f, -0.1f};
//        _lights[0].type = PointLight;
//        _lights[0].attenuation = (vector_float3){0.4, 0.6, 0.7};
//        _lights[0].color = (vector_float3){255/255.0f, 199/255.0f, 130/255.0f};
//        _lights[0].specularColor = (vector_float3){255/255.0f, 147/255.0f, 52/255.0f};
        
        _lights[0] = [self buildDefaultLight];
        _lights[0].position = (vector_float3){0.0f, 10.0f, 0.4f};
        _lights[0].type = DirectionalLight;
        _lights[0].attenuation = (vector_float3){0.2, 0.4, 0.5};
        
        _shadowCamera = [[Camera orthographic:-2 top:2 left:-2 right:2 near:0.01f far:100.0f] retain];
        _shadowCamera.position = (vector_float4){_lights[0].position.x, _lights[0].position.y, _lights[0].position.z, 1.0f};
        [_shadowCamera reallyLookAt:(simd_float3){0.0,0.0,0.0}];
        
        
        
        _fragUniforms.lightCount = 1;
        
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
        
        [self mtkView:_view drawableSizeWillChange:_view.bounds.size];
    }
    return self;
}


- (void)drawInMTKView:(nonnull MTKView *)view {
    switch (_renderMode) {
        case RenderModeForward:
            [self forwardRendering];
            break;
        case RenderModeDeferred:
            [self deferredRendering];
            break;
        default:
            break;
    }
}

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

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    _currentCamera.aspect = size.width / (float)size.height;
    _uniforms.projectionMatrix = _currentCamera.projection;
    _shadowTexture = [self buildTexture:MTLPixelFormatDepth32Float size:CGSizeMake(4096, 4096) label:@"Shadow"];
    [self setupDepthAttachment:_shadowTexture renderPassDescriptor:&_shadowRenderPassDescriptor];
    if (_renderMode == RenderModeDeferred)
        [self buildGbufferRenderPassDescriptor:size];
}


-(void)zoomCam:(CGFloat)delta sensitivity:(float)sensitivity
{
    simd::float4 cameraVector = (simd::float4){_currentCamera.front.x, _currentCamera.front.y, _currentCamera.front.z, 0.0};
    _currentCamera.position = _currentCamera.position + delta * sensitivity * cameraVector;
}

-(void)lookAt:(CGPoint) t
{
    double sensitivity = 0.1;
    t.x *= sensitivity;
    t.y *= sensitivity;
    x+=M_PI * (t.x/180.0f);
    y+=M_PI * (t.y/180.0f);
    
    [_currentCamera lookAt:CGPointMake(x, y)];
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

-(void)buildGbufferTextures:(CGSize)size
{
    _albedoTexture = [self buildTexture:MTLPixelFormatBGRA8Unorm size:size label:@"Albedo Texture"];
    _normalTexture = [self buildTexture:MTLPixelFormatRGBA16Float size:size label:@"Normal Texture"];
    _positionTexture = [self buildTexture:MTLPixelFormatRGBA16Float size:size label:@"Position Texture"];
    _depthTexture = [self buildTexture:MTLPixelFormatDepth32Float size:size label:@"Depth Texture"];
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
    NSError* error;
    _gBufferPipelineState = [[_device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error] retain];
    NSLog(@"%@", error);
    
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
    NSError* error;
    _gBufferPipelineState = [[_device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error] retain];
    NSLog(@"%@", error);
    
}

-(void)buildGbufferRenderPassDescriptor:(CGSize)size
{
    _gBufferRenderPassDescriptor = [[MTLRenderPassDescriptor renderPassDescriptor] retain];
    [self buildGbufferTextures:size];
    NSArray* textures = [NSArray arrayWithObjects:_albedoTexture, _normalTexture, _positionTexture, nil];
    int position = 0;
    for (id<MTLTexture> texture in textures) {
        [self setupColorAttachment:position texture:texture renderPassDescriptor:&_gBufferRenderPassDescriptor];
        ++position;
    }
    
    [self setupDepthAttachment:_depthTexture renderPassDescriptor:&_gBufferRenderPassDescriptor];
}

-(void)forwardRendering
{
    rotate += 0.1 * (1 / ((float)_view.preferredFramesPerSecond));

    float radius = 3.0f;
   // _lights[0].position = (vector_float3){_lights[0].position.x, cos(rotate) * radius, sin(rotate) * radius};
    //_lightDebug.position = (vector_float4){_lightDebug.position.x, cos(rotate) * radius, sin(rotate) * radius, 1.0f};
    //Render
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBufferWithUnretainedReferences];
    
    id<MTLRenderCommandEncoder> shadowEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_shadowRenderPassDescriptor];
    [self renderShadowPass:shadowEncoder];
    
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_view.currentRenderPassDescriptor];
    [renderEncoder setCullMode:MTLCullModeNone];
    
    _uniforms.projectionMatrix = [_currentCamera projection];
    [renderEncoder setFragmentBytes:&_lights length:sizeof(Light) * 1 atIndex:BufferIndexLight];
    for(Model* model : _models)
    {
        [self draw:renderEncoder model:model];
    }
    
    [renderEncoder endEncoding];
    [commandBuffer presentDrawable:_view.currentDrawable];
    [commandBuffer commit];
}

-(void)deferredRendering
{
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBufferWithUnretainedReferences];
    
    id<MTLRenderCommandEncoder> shadowEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_shadowRenderPassDescriptor];
    [self renderShadowPass:shadowEncoder];
    
    id<MTLRenderCommandEncoder> gBufferEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_gBufferRenderPassDescriptor];
    [self renderGbufferPass:gBufferEncoder];
    
//    id<MTLBlitCommandEncoder> blitEncoder = [commandBuffer blitCommandEncoder];
//    [blitEncoder pushDebugGroup:@"Blit"];
//    blitEncoder.label = @"Blit encoder";
//    MTLOrigin origin = MTLOriginMake(0, 0, 0);
//    MTLSize size = MTLSizeMake(int(_view.drawableSize.width), int(_view.drawableSize.height), 1);
//
//    [blitEncoder copyFromTexture:_albedoTexture
//                     sourceSlice:0
//                     sourceLevel:0
//                    sourceOrigin:origin
//                      sourceSize:size
//                       toTexture:_view.currentDrawable.texture
//                destinationSlice:0
//                destinationLevel:0
//               destinationOrigin:origin];
//
//    [blitEncoder endEncoding];
//    [blitEncoder popDebugGroup];
//
    
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_view.currentRenderPassDescriptor];
    [self renderCompositionPass:renderEncoder];
    
    [commandBuffer presentDrawable:_view.currentDrawable];
    [commandBuffer commit];
}

-(void)renderShadowPass:(id<MTLRenderCommandEncoder>) renderEncoder
{
    [renderEncoder pushDebugGroup:@"Shadow pass"];
    [renderEncoder setLabel:@"Shadow encoder"];
    [renderEncoder setDepthBias:0.015 slopeScale:7 clamp:0.02];
    [renderEncoder setCullMode:MTLCullModeFront];
    
   // _shadowCamera = [Camera orthographic:-2 top:2 left:-2 right:2 near:0.01f far:100.0f];
    _shadowCamera.position = (vector_float4){_lights[0].position.x, _lights[0].position.y, _lights[0].position.z, 1.0f};
    [_shadowCamera reallyLookAt:(simd_float3){0.0,0.0,0.0}];
    
//    vector_float4 minInView =  matrix_multiply([_shadowCamera view],matrix_multiply([_models[0] modelMatrix], (vector_float4) {_sceneAABB.minBounds.x, _sceneAABB.minBounds.y, _sceneAABB.minBounds.z, 1.0}));
//    vector_float4 maxInView = matrix_multiply([_shadowCamera view], matrix_multiply([_models[0] modelMatrix], (vector_float4) {_sceneAABB.maxBounds.x, _sceneAABB.maxBounds.y, _sceneAABB.maxBounds.z, 1.0}));
//
//    vector_float4 points[8] = {
//        minInView,
//        (vector_float4) {minInView.x, minInView.y, maxInView.z},
//        (vector_float4) {minInView.x, maxInView.y, minInView.z},
//        (vector_float4) {minInView.x, maxInView.y, maxInView.z},
//        (vector_float4) {maxInView.x, minInView.y, minInView.z},
//        (vector_float4) {maxInView.x, maxInView.y, minInView.z},
//        (vector_float4) {maxInView.x, minInView.y, maxInView.z},
//        maxInView
//    };
//
//    float l, r, t, b, n, f;
//    l = r = t = b = n = f = 0.0;
//    for (int i = 0; i < 8; ++i) {
//        if (points[i].x < l) l = points[i].x;
//        if (points[i].y < b) b = points[i].y;
//        if (points[i].z < n) n = points[i].z;
//
//        if (points[i].x > r) r = points[i].x;
//        if (points[i].y > t) t = points[i].y;
//        if (points[i].z > f) f = points[i].z;
//    }
//
//    _shadowCamera = [[Camera orthographic:b top:t left:l right:r near:0.001 far:ceil(fmax(abs(n), abs(f)))] retain];
//    _shadowCamera.position = (vector_float4){_lights[0].position.x, _lights[0].position.y, _lights[0].position.z, 1.0f};
//    [_shadowCamera reallyLookAt:(simd_float3){0.0,0.0,0.0}];
    
    
    _uniforms.viewMatrix = [_shadowCamera view];
    
    _uniforms.projectionMatrix = _shadowCamera.projection;
    _uniforms.shadowMatrix = matrix_multiply(_uniforms.projectionMatrix, _uniforms.viewMatrix);
    [renderEncoder setRenderPipelineState:_shadowPipelineState];
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
    
    [renderEncoder setDepthStencilState:model.depthState];
    [renderEncoder setFragmentSamplerState:model.samplerState atIndex:TextureSampler];
    
    auto submeshes = [model submeshes];
    
    for(Submesh& submesh : submeshes)
    {
        if (![[renderEncoder label] isEqualToString:@"Shadow encoder"])
        {
            if (_renderMode == RenderModeForward)
            {
                [renderEncoder setRenderPipelineState:submesh.renderState];
            }
            
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
            
            if (_shadowTexture)
            {
                [renderEncoder setFragmentTexture:_shadowTexture atIndex:Shadow];
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
    [renderEncoder setCullMode:MTLCullModeNone];
    
    _uniforms.projectionMatrix = _currentCamera.projection;
    _uniforms.viewMatrix = [_currentCamera view];
    
    for(Model* model : _models)
    {
        [self draw:renderEncoder model:model];
    }
    [renderEncoder endEncoding];
    [renderEncoder popDebugGroup];
}

-(void)renderCompositionPass:(id<MTLRenderCommandEncoder>) renderEncoder
{
    [renderEncoder pushDebugGroup:@"Composition Pass"];
    [renderEncoder setLabel:@"Composition Encoder"];
    [renderEncoder setRenderPipelineState:_compositionPipelineState];
    [renderEncoder setVertexBuffer:_quadVertices offset:0 atIndex:VertexAttributePosition];
    [renderEncoder setVertexBuffer:_quadTexCoords offset:0 atIndex:VertexAttributeTexcoord];
    
    [renderEncoder setFragmentTexture:_albedoTexture atIndex:0];
    [renderEncoder setFragmentTexture:_normalTexture atIndex:1];
    [renderEncoder setFragmentTexture:_positionTexture atIndex:2];
    [renderEncoder setFragmentBytes:&_fragUniforms length:sizeof(FragmentUniforms) atIndex:BufferIndexFragmentUniforms];
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:12];
    [renderEncoder endEncoding];
    [renderEncoder popDebugGroup];
}

@end
