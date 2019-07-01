//
//  Node.h
//  MetalStudy
//
//  Created by Leandro Freire on 01/04/2019.
//  Copyright © 2019 Leandro Freire. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <simd/matrix.h>
#include <simd/vector.h>

@interface Node : NSObject
{
    simd::float3 _position;
    simd::float3 _rotation;
    simd::float3 _scale;
}

@property(nonatomic, readwrite, assign) simd::float3 position;
@property(nonatomic, readwrite, assign) simd::float3 rotation;
@property(nonatomic, readwrite, assign) simd::float3 scale;

-(simd::float4x4) modelMatrix;

@end
