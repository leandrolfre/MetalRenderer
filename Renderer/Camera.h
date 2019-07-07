//
//  Camera.h
//  MetalStudy
//
//  Created by Leandro Freire on 01/04/2019.
//  Copyright © 2019 Leandro Freire. All rights reserved.
//

#import "Node.h"
#import <CoreGraphics/CoreGraphics.h>

@interface Camera : Node
{
    simd_float3 _up;
    simd_float3 _right;
    simd_float3 _front;
    float _fovyRadians;
    float _aspect;
    float _nearZ;
    float _farZ;
    
    float _b;
    float _t;
    float _l;
    float _r;
    bool _isOrthographic;
}

@property(nonatomic, readwrite, assign) float fovy;
@property(nonatomic, readwrite, assign) float aspect;
@property(nonatomic, readwrite, assign) float near;
@property(nonatomic, readwrite, assign) float far;
@property(nonatomic, readonly, assign) simd_float3 front;

+(id)perspective:(float)fov aspect:(float)aspect near:(float)near far:(float)far;
+(id)orthographic:(float)bottom top:(float)top left:(float)left right:(float)right near:(float)near far:(float)far;
-(matrix_float4x4) projection;
-(matrix_float4x4) view;
//-(void) lookAt:(CGPoint)dir;
-(void)lookAt:(simd_float3)target;

@end
