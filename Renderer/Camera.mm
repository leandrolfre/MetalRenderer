//
//  Camera.m
//  MetalStudy
//
//  Created by Leandro Freire on 01/04/2019.
//  Copyright © 2019 Leandro Freire. All rights reserved.
//

#import "Camera.h"
#include "MathUtils.h"

@implementation Camera

@synthesize fovy = _fovyRadians;
@synthesize aspect = _aspect;
@synthesize near = _nearZ;
@synthesize far = _farZ;
@synthesize front = _front;

-(instancetype) init
{
    if (self = [super init])
    {
        _fovyRadians = (45.0f / 180.0f) * M_PI;
        _aspect = 1.0f;
        _nearZ = 0.001f;
        _farZ = 1000.0f;
        _position = (simd_float3) {0.0, 0.0, 0.0};
        _up = (simd_float3){0.0f, 1.0f, 0.0f};
        _front = ((simd_float3){0.0f, 0.0f, -1.0f});
        _front = simd_normalize(_position - _front);
        _right = simd_normalize(simd_cross(_up, _front));
        _up = simd_normalize(simd_cross(_front, _right));
        _isOrthographic = false;
    }
    return self;
}

-(instancetype) initOrthographic:(float)bottom top:(float)top left:(float)left right:(float)right near:(float)near far:(float)far
{
    if (self = [self init])
    {
        _nearZ = near;
        _farZ = far;
        _position = (simd_float3) {0.0, 0.0, 0.0};
        _b = bottom;
        _r = right;
        _l = left;
        _t = top;
        _isOrthographic = true;
    }
    return self;
}

+(id)perspective:(float)fov aspect:(float)aspect near:(float)near far:(float)far
{
    return [[[Camera alloc] init] autorelease];
}

+(id)orthographic:(float)bottom top:(float)top left:(float)left right:(float)right near:(float)near far:(float)far
{
    return [[[Camera alloc] initOrthographic:bottom top:top left:left right:right near:near far:far] autorelease];
}

-(matrix_float4x4) projection
{
    if (_isOrthographic)
    {
        return math::orthographic(_b, _t, _r, _l, _nearZ, _farZ);
    }
    else
    {
        return math::projection(_fovyRadians, _aspect, _nearZ, _farZ);
    }
    
}

-(matrix_float4x4) view
{
    
    //glm::lookAt(cameraPos, cameraPos + cameraFront, cameraUp);
//    return matrix_invert([self modelMatrix]);
    auto camMatrix = (matrix_float4x4) {{
        {    _right.x,    _right.y,    _right.z,  0},
        {       _up.x,       _up.y,       _up.z,  0},
        {    _front.x,    _front.y,    _front.z,  0},
        {   _position.x,   _position.y,   _position.z,  1}
    }};

    return matrix_invert(camMatrix);
}

//-(void) lookAt:(CGPoint)dir
//{
//    simd_float3 f;
//    f.x = cos(dir.y) * cos(dir.x);
//    f.y = sin(dir.y);
//    f.z = cos(dir.y) * sin(dir.x);
//    _front = simd_normalize(f);
//    _right = simd_normalize(simd_cross(_front, _up));
//    _up = simd_normalize(simd_cross(_right, _front));
//}

-(void) lookAt:(simd_float3)target
{
    simd_float3 f = _position.xyz - target;
    _front = simd_normalize(f);
    _right = simd_normalize(simd_cross(_front, _up));
    _up = simd_normalize(simd_cross(_right, _front));
}

@end
