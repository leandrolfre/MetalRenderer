//
//  Node.m
//  MetalStudy
//
//  Created by Leandro Freire on 01/04/2019.
//  Copyright © 2019 Leandro Freire. All rights reserved.
//

#import "Node.h"
#include "MathUtils.h"

@implementation Node
@synthesize position = _position;
@synthesize rotation = _rotation;
@synthesize scale = _scale;

-(instancetype)init
{
    if (self = [super init]) {
        self.position = (simd::float3){0.0f, 0.0f, 0.0f};
        self.rotation = (simd::float3){0.0f, 0.0f, 0.0f};
        self.scale = (simd::float3){1.0f, 1.0f, 1.0f};
    }
    return self;
}

-(simd::float4x4) modelMatrix;
{
    simd::float4x4 translateMatrix = math::translate(_position.xyz);
    simd::float4x4 rotateMatrix =   math::rotate(_rotation.x, (simd::float3){1.0f, 0.0f, 0.0f}) *
                                    math::rotate(_rotation.y, (simd::float3){0.0f, 1.0f, 0.0f}) *
                                    math::rotate(_rotation.z, (simd::float3){0.0f, 0.0f, 1.0f});
    simd::float4x4 scaleMatrix = math::scale(_scale);
    
    return translateMatrix * rotateMatrix * scaleMatrix;
}

@end
