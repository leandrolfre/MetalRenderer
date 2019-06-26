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
@class Model;
typedef enum
{
    RenderModeForward,
    RenderModeDeferred
} RenderMode;

const int LightCount = 5;
@interface Renderer : NSObject <MTKViewDelegate>
{
    MTKView* _view;
    id<MTLDevice> _device;
    id<MTLCommandQueue> _commandQueue;
    NSMutableArray* _models;
    id<MTLTexture> _shadowTexture;
    id<MTLTexture> _albedoTexture;
    id<MTLTexture> _normalTexture;
    id<MTLTexture> _positionTexture;
    id<MTLTexture> _depthTexture;
    MTLRenderPassDescriptor* _shadowRenderPassDescriptor;
    id<MTLRenderPipelineState> _shadowPipelineState;
    MTLRenderPassDescriptor* _gBufferRenderPassDescriptor;
    id<MTLRenderPipelineState> _gBufferPipelineState;
    id<MTLRenderPipelineState> _compositionPipelineState;
    id<MTLBuffer> _quadVertices;
    id<MTLBuffer> _quadTexCoords;
    Light _lights[LightCount];
    Camera* _currentCamera;
    Camera* _shadowCamera;
    Uniforms _uniforms;
    FragmentUniforms _fragUniforms;
    float rotate;
    double x, y;
    RenderMode _renderMode;
    MDLAxisAlignedBoundingBox _sceneAABB;
    Model* _lightDebug;
}

-(id)initWithView:(MTKView*)view mode:(RenderMode) renderMode;
-(void)zoomCam:(CGFloat)delta sensitivity:(float)sensitivity;
-(void)lookAt:(CGPoint) t;
@end
