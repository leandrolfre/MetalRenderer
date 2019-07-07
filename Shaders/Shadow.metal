//
//  Shadowmetal.metal
//  MetalStudy
//
//  Created by Leandro Freire on 13/05/2019.
//  Copyright © 2019 Leandro Freire. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
#import "ShaderTypes.h"

struct VertexIn
{
    float3 position [[attribute(VertexAttributePosition)]];
};

vertex float4 vertex_depth(const VertexIn in [[stage_in]],
                           constant Uniforms& uniforms [[buffer(BufferIndexUniforms)]])
{
    matrix_float4x4 mvp = uniforms.shadowMatrix * uniforms.modelMatrix;
    float4 position = mvp * float4(in.position, 1.0);
    return position;
}
