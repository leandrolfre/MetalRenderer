//
//  ShaderTypes.h
//  MetalStudy
//
//  Created by Leandro Freire on 23/03/2019.
//  Copyright © 2019 Leandro Freire. All rights reserved.
//

//
//  Header containing types and enum constants shared between Metal shaders and Swift/ObjC source
//
#ifndef ShaderTypes_h
#define ShaderTypes_h

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#else
#import <Foundation/Foundation.h>
#endif

#include <simd/simd.h>

typedef NS_ENUM(NSInteger, BufferIndex)
{
    BufferIndexVertices                 = 0,
    BufferIndexUniforms                 = 11,
    BufferIndexLight                    = 12,
    BufferIndexFragmentUniforms         = 13,
    BufferIndexFragmentMaterial         = 14
};

typedef enum
{
    TextureSampler = 0
} FragmentSampler;

typedef NS_ENUM(NSInteger, VertexAttribute)
{
    VertexAttributePosition     = 0,
    VertexAttributeNormal       = 1,
    VertexAttributeTexcoord     = 2,
    VertexAttributeTangent      = 3,
    VertexAttributeBitangent    = 4
};

typedef NS_ENUM(NSInteger, TextureIndex)
{
    TextureIndexColor    = 0,
};

typedef enum
{
    Unused = 0,
    DirectionalLight = 1,
    SpotLight = 2,
    PointLight = 3,
    AmbientLight = 4
} LightType;

typedef struct
{
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 modelViewMatrix;
    matrix_float4x4 modelMatrix;
    matrix_float4x4 shadowMatrix;
    matrix_float3x3 normalMatrix;
} Uniforms;

typedef struct
{
    unsigned int lightCount;
    vector_float3 cameraPos;
    unsigned int hasNormalMap;
    unsigned int hasSpecularMap;
} FragmentUniforms;

typedef struct
{
    vector_float3 position;
    vector_float3 color;
    vector_float3 specularColor;
    vector_float3 attenuation;
    LightType type;
    float intensity;
} Light;

typedef struct
{
    vector_float3 diffuseColor;
    vector_float3 specularColor;
    float specularExponent;
    float transparency;
} Material;

typedef enum
{
    Diffuse = 0,
    Normal = 1,
    Specular = 2,
    Alpha = 3,
    Shadow = 4
} Textures;

typedef enum
{
    NormalMapConstant = 0,
    DiffuseMapConstant = 1,
    SpecularMapConstant = 2,
    AlphaMapConstant = 3
} FunctionConstants;

#endif /* ShaderTypes_h */

