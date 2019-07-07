//
//  Renderer.h
//  MetalStudy
//
//  Created by Leandro Freire on 27/03/2019.
//  Copyright © 2019 Leandro Freire. All rights reserved.
//

#import <MetalKit/MetalKit.h>
#import "ShaderTypes.h"
#import <CoreGraphics/CoreGraphics.h>

@class Camera;

const int LightCount = 5;
const int MaxBuffersInFlight = 3;
@interface Renderer : NSObject <MTKViewDelegate>
{
    NSMutableArray* _models;
    NSMutableArray<id<MTLBuffer>>* _uniformBuffers;
    NSMutableArray<id<MTLBuffer>>* _lightPositionBuffers;
    MTKView* _view;
    Camera* _currentCamera;
    Camera* _shadowCamera;
    
    MTLRenderPassDescriptor* _shadowRenderPassDescriptor;
    MTLRenderPassDescriptor* _gBufferRenderPassDescriptor;
    MTLRenderPassDescriptor* _finalRenderPassDescriptor;
    
    CGFloat x, y;
    MDLAxisAlignedBoundingBox _sceneAABB;
    
    id<MTLDevice> _device;
    id<MTLCommandQueue> _commandQueue;
    
    id<MTLTexture> _shadowTexture;
    id<MTLTexture> _albedoTexture;
    id<MTLTexture> _normalTexture;
    id<MTLTexture> _depthTexture;
    
    id<MTLRenderPipelineState> _shadowPipelineState;
    id<MTLRenderPipelineState> _gBufferPipelineState;
    id<MTLRenderPipelineState> _directionalLightPipelineState;
    id<MTLDepthStencilState> _directionalLightDepthStencilState;
    id<MTLDepthStencilState> _shadowDepthStencilState;
    id<MTLDepthStencilState> _gBufferDepthStencilState;
    
    MTLVertexDescriptor* _defaultVertexDescriptor;
    
    
    id<MTLBuffer> _quadVertices;
    id <MTLBuffer> _lightsData;
    id <MTLBuffer> _directionalLightBuffer;
    
    Light _pointLights[LightCount];
    Light _directionalLight;
    FragmentUniforms _fragUniforms;
    dispatch_semaphore_t _inFlightSemaphore;
    int _currentBufferIndex;
}

-(id)initWithView:(MTKView*)view;
-(void)zoomCam:(CGFloat)delta sensitivity:(float)sensitivity;
-(void)lookAt:(CGPoint) t;
@end
