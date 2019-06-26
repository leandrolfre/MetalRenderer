//
//  MathUtils.cpp
//  MetalStudy
//
//  Created by Leandro Freire on 08/04/2019.
//  Copyright © 2019 Leandro Freire. All rights reserved.
//

#include "MathUtils.h"

matrix_float4x4 math::projection(float fov, float aspect, float near, float far)
{
    float ys = 1 / tanf(fov * 0.5);
    float xs = ys / aspect;
    float zs = far / (near - far);
    
    return (matrix_float4x4) {{
        { xs,   0,          0,  0 },
        {  0,  ys,          0,  0 },
        {  0,   0,         zs, -1 },
        {  0,   0,  near * zs,  0 }
    }};
}

matrix_float4x4 matrix_make(float m00, float m10, float m20, float m30,
                                               float m01, float m11, float m21, float m31,
                                               float m02, float m12, float m22, float m32,
                                               float m03, float m13, float m23, float m33) {
    return (matrix_float4x4){ {
        { m00, m10, m20, m30 },
        { m01, m11, m21, m31 },
        { m02, m12, m22, m32 },
        { m03, m13, m23, m33 } } };
}

matrix_float4x4 math::orthographic(float bottom, float top, float right, float left, float near, float far)
{
    return matrix_make(2 / (right - left), 0, 0, 0,
                           0, 2 / (top - bottom), 0, 0,
                           0, 0, -1 / (far - near), 0,
                           (left + right) / (left - right), (top + bottom) / (bottom - top), near / (near - far), 1);
}

matrix_float4x4 math::translate(simd::float3 translate)
{
    simd::float4x4 translateMatrix(1.0f);
    translateMatrix.columns[3][0] = translate.x;
    translateMatrix.columns[3][1] = translate.y;
    translateMatrix.columns[3][2] = translate.z;
    return translateMatrix;
}

simd::float4x4 math::rotate(float radians, simd::float3 axis)
{
    axis = vector_normalize(axis);
    float ct = cosf(radians);
    float st = sinf(radians);
    float ci = 1 - ct;
    float x = axis.x, y = axis.y, z = axis.z;
    
    return (matrix_float4x4) {{
        { ct + x * x * ci,     y * x * ci + z * st, z * x * ci - y * st, 0},
        { x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0},
        { x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0},
        {                   0,                   0,                   0, 1}
    }};
}

matrix_float4x4 math::scale(simd::float3  scale)
{
    simd::float4x4 scaleMatrix(1.0f);
    scaleMatrix.columns[0][0] = scale.x;
    scaleMatrix.columns[1][1] = scale.y;
    scaleMatrix.columns[2][2] = scale.z;
    return scaleMatrix;
}

matrix_float3x3 math::normal(matrix_float4x4 model)
{
    matrix_float4x4 transposeInverse = simd_transpose(simd_inverse(model));
    return simd_matrix(transposeInverse.columns[0].xyz,
                       transposeInverse.columns[1].xyz,
                       transposeInverse.columns[2].xyz);
}
