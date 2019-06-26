//
//  Shaders.metal
//  MetalStudy
//
//  Created by Leandro Freire on 23/03/2019.
//  Copyright © 2019 Leandro Freire. All rights reserved.
//

// File for Metal kernel and shader functions

#include <metal_stdlib>
#include <simd/simd.h>

// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "ShaderTypes.h"

using namespace metal;

constant bool hasNormalTexture [[ function_constant(NormalMapConstant)]];
constant bool hasDiffuseTexture [[ function_constant(DiffuseMapConstant)]];
constant bool hasSpecularTexture [[ function_constant(SpecularMapConstant)]];
constant bool hasAlphaTexture [[ function_constant(AlphaMapConstant)]];

typedef struct
{
    float3 position [[attribute(VertexAttributePosition)]];
    float3 normal [[attribute(VertexAttributeNormal)]];
    float2 texCoord [[attribute(VertexAttributeTexcoord)]];
    float3 tangent [[attribute(VertexAttributeTangent)]];
    float3 bitangent [[attribute(VertexAttributeBitangent)]];
} VertexIn;

typedef struct
{
    float4 position [[position]];
    float3 worldNormal;
    float4 worldPosition;
    float4 shadowPosition;
    float2 texCoord;
    float3 worldTangent;
    float3 worldBitangent;
} VertexOut;

typedef struct
{
    float4 albedo [[color(0)]];
    float4 normal [[color(1)]];
    float4 position [[color(2)]];
} GbufferOut;

float4 fog(float4 position, float4 color)
{
    float distance = position.z / position.w;
    float density = 2.8f;
    float fog = 1.0f - clamp(exp(-density * distance), 0.0f, 1.0f);
    return mix(color, float4(0.7f, 0.7f, 0.7f, 1.0f), fog);
}

float shadowCalc(float4 fragPosLightSpace, depth2d<float> shadowTexture)
{
    float2 shadowUV = fragPosLightSpace.xy;
    shadowUV = shadowUV * 0.5 + 0.5;
    shadowUV.y = 1 - shadowUV.y;
    
    constexpr sampler s(coord::normalized,
                        filter::linear,
                        mip_filter::none,
                        address::clamp_to_edge,
                        compare_func::less);
//    float shadow = shadowTexture.sample_compare(s, fragPosLightSpace.xy, fragPosLightSpace.z);
//    float closestDepth = shadowTexture.sample(s, shadowUV);
    float currentDepth = fragPosLightSpace.z / fragPosLightSpace.w;

    float shadow = 0.0;
    float texelSize = 1.0 / 4096;
    for(int x = -1; x <= 1; ++x)
    {
        for(int y = -1; y <= 1; ++y)
        {
            float pcfDepth = shadowTexture.sample(s, shadowUV + float2(x, y) * texelSize);
            shadow += currentDepth > pcfDepth ? 1.0 : 0.0;
        }
    }
    shadow /= 9.0;

    if(currentDepth > 1.0)
        shadow = 0.0;
    
    return shadow;
    
    //return currentDepth > closestDepth ? 1.0 : 0.0;
    
}

vertex VertexOut vertex_main(const VertexIn in [[ stage_in ]],
                             constant Uniforms& uniforms [[ buffer(BufferIndexUniforms) ]])
{
    VertexOut out;
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix  * float4(in.position, 1.0);
    out.worldNormal = uniforms.normalMatrix * in.normal;
    out.worldTangent = uniforms.normalMatrix * in.tangent;
    out.worldBitangent = uniforms.normalMatrix * in.bitangent;
    out.worldPosition = uniforms.modelMatrix  * float4(in.position, 1.0);
    out.texCoord = in.texCoord;
    out.shadowPosition = uniforms.shadowMatrix * uniforms.modelMatrix * float4(in.position, 1.0);
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant Light* lights [[buffer(BufferIndexLight)]],
                              constant FragmentUniforms& fragmentUniforms [[buffer(BufferIndexFragmentUniforms)]],
                              constant Material& material [[buffer(BufferIndexFragmentMaterial)]],
                              sampler textureSampler [[sampler(TextureSampler)]],
                              texture2d<float> diffuse [[texture(Diffuse), function_constant(hasDiffuseTexture)]],
                              texture2d<float> normal [[texture(Normal), function_constant(hasNormalTexture)]],
                              texture2d<float> specular [[texture(Specular), function_constant(hasSpecularTexture)]],
                              texture2d<float> alpha [[texture(Alpha), function_constant(hasAlphaTexture)]],
                              depth2d<float> shadowTexture [[texture(Shadow)]])
{
    
    float3 specularColor = float3(0.0);
    float materialShininess = material.specularExponent;
    
    float materialSpecularColor = material.specularColor.r;
    float3 baseColor = material.diffuseColor;
    float3 normalDir = in.worldNormal;
    float3 alphaMask = float3(1.0);
    
    if(hasSpecularTexture)
    {
        materialSpecularColor = specular.sample(textureSampler, in.texCoord).r;
    }
    
    if(hasDiffuseTexture)
    {
        baseColor = diffuse.sample(textureSampler, in.texCoord).rgb;
    }

    if (hasNormalTexture)
    {
        float3 normalMap = normal.sample(textureSampler, in.texCoord).rgb;
        normalMap = normalMap * 2.0 - 1.0;
        normalDir = float3x3(in.worldTangent,
                               in.worldBitangent,
                               in.worldNormal) * normalMap;
    }
    
    if (hasAlphaTexture)
    {
        alphaMask = alpha.sample(textureSampler, in.texCoord).rgb;
        if (alphaMask.r < 0.8)
            discard_fragment();
    }
    
    float3 ambientLight = 0.4 * baseColor;;
    float3 diffuseColor = 0.0;
    
    normalDir = normalize(normalDir);
    float3 lightDir;
    float diffuseIntensity;
    for(unsigned int i = 0;  i < fragmentUniforms.lightCount; ++i)
    {
        
        if (lights[i].type == DirectionalLight)
        {
            lightDir = normalize(lights[i].position);
            diffuseIntensity = saturate(dot(lightDir, normalDir));
            diffuseColor += baseColor * lights[i].color * diffuseIntensity;
        }
        else if (lights[i].type == PointLight)
        {
            float d = distance(lights[i].position.xyz, in.worldPosition.xyz);
            lightDir = normalize(lights[i].position.xyz - in.worldPosition.xyz);
            float attenuation = 1.0 / (lights[i].attenuation.x + lights[i].attenuation.y * d + lights[i].attenuation.z * (d*d));
            diffuseIntensity = saturate(dot(lightDir, normalDir));
            float3 color = lights[i].color * baseColor * diffuseIntensity;
            color *= attenuation;
            diffuseColor+= color;
        }
        
        float3 r = reflect(lightDir, normalDir);
        float3 v = normalize(in.worldPosition.xyz - fragmentUniforms.cameraPos.xyz);
        float specularIntensity = pow(saturate(dot(r,v)), materialShininess);
        specularColor += lights[i].specularColor * materialSpecularColor * specularIntensity;
        
    }
    
    float shadow = shadowCalc(in.shadowPosition, shadowTexture);
    //half shadow_contribution = shadow + 0.1h;
    
    // Clamp shadow values to 1;
    //shadow_contribution = min(1.0h, shadow_contribution);
    
    //float3 color =  specularColor + diffuseColor + (ambientLight * baseColor);
    float3 color = (ambientLight + (1.0 - shadow) * (diffuseColor + specularColor));
    //float3 color = (ambientLight + shadow * (diffuseColor + specularColor));
    //return fog(in.position, float4(color, 1.0f));
    return float4(color, 1.0f);
}

fragment GbufferOut gBufferFragment(VertexOut in [[stage_in]],
                                    constant FragmentUniforms& fragmentUniforms [[buffer(BufferIndexFragmentUniforms)]],
                                    constant Material& material [[buffer(BufferIndexFragmentMaterial)]],
                                    sampler textureSampler [[sampler(TextureSampler)]],
                                    texture2d<float> diffuse [[texture(Diffuse)]],
                                    texture2d<float> normal [[texture(Normal)]],
                                    texture2d<float> specular [[texture(Specular)]],
                                    depth2d<float> shadowTexture [[texture(Shadow)]])
{
    GbufferOut out;

    out.albedo = diffuse.sample(textureSampler, in.texCoord);

    if (fragmentUniforms.hasSpecularMap)
    {
        out.albedo.a = specular.sample(textureSampler, in.texCoord).r;
    }
    
    out.normal = float4(in.worldNormal, 1.0);
    if (fragmentUniforms.hasNormalMap)
    {
        float3 normalMap = normal.sample(textureSampler, in.texCoord).rgb;
        normalMap = normalMap * 2.0 - 1.0;
        out.normal = float4(float3x3(in.worldTangent,
                                     in.worldBitangent,
                                     in.worldNormal) * normalMap, 1.0);
    }
    
    out.normal = normalize(out.normal);
    out.normal.a = shadowCalc(in.shadowPosition, shadowTexture);
    out.position = in.worldPosition;
    
    return out;
}
