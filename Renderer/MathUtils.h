//
//  MathUtils.hpp
//  MetalStudy
//
//  Created by Leandro Freire on 08/04/2019.
//  Copyright © 2019 Leandro Freire. All rights reserved.
//

#pragma once

#include <simd/matrix.h>
#include <simd/vector.h>
namespace math
{
    matrix_float4x4 projection(float fov, float aspect, float near, float far);
    matrix_float4x4 orthographic(float bottom, float top, float right, float left, float near, float far);
    matrix_float4x4 translate(simd::float3 translate);
    simd::float4x4 rotate(float radians, simd::float3 axis);
    matrix_float4x4 scale(simd::float3  scale);
    matrix_float3x3 normal(matrix_float4x4 model);
}

