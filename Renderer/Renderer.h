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
    id<MTLTexture> _positionTexture;
    id<MTLTexture> _depthTexture;
    
    id<MTLRenderPipelineState> _shadowPipelineState;
    id<MTLRenderPipelineState> _gBufferPipelineState;
    id<MTLRenderPipelineState> _directionalLightPipelineState;
    id<MTLDepthStencilState> _directionalLightDepthStencilState;
    id<MTLDepthStencilState> _shadowDepthStencilState;
    id<MTLDepthStencilState> _gBufferDepthStencilState;
    
    
    
    id<MTLBuffer> _quadVertices;
    id<MTLBuffer> _quadTexCoords;
    
    Light _pointLights[LightCount];
    Light _directionalLight;
    Uniforms _uniforms;
    FragmentUniforms _fragUniforms;
    dispatch_semaphore_t _inFlightSemaphore;
}

-(id)initWithView:(MTKView*)view;
-(void)zoomCam:(CGFloat)delta sensitivity:(float)sensitivity;
-(void)lookAt:(CGPoint) t;
@end
