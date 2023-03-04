#ifndef STRUCT_DATA_INCLUDED
#define STRUCT_DATA_INCLUDED

struct Attributes {
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 uv : TEXCOORD0;
    /*
    float2 uv1 : TEXCOORD1;
    float2 uv2 : TEXCOORD2;
    float2 uv3 : TEXCOORD3;
    float4 color : COLOR;
    */
};

struct Varyings {
    float4 positionCS : SV_POSITION;
    float3 positionWS : TEXCOORD0;   //interpolators0
    float3 normalWS : TEXCOORD1; //interpolators1
    float4 tangentWS : TEXCOORD2;   //interpolators2
    float2 uv : TEXCOORD3; //interpolators3
    /*
    float2 uv1 : VAR_UV1;   //如果2个都要可以合为一个float4
    float2 uv2 : VAR_UV2;   //interpolators4
    float2 uv3 : VAR_UV3;   
    float2 color : VAT_COLOR    //interpolators5
    */
};

struct FragInput {
    float4 positionSS;
    float3 positionWS;
    float2 uv;
    float3x3 TBN;
};

struct SurfaceDataHDRP {
    float3 baseColor;
    float ambientOcclusion;
    float metallic;
    float3 specularColor;
    float3 normalWS;
    //float3 bentNormalWS;
    float perceptualSmoothness;
    float3 tangentWS;
    float specularOcclusion;
};

//全局光数据
struct BuiltinData {
    real opacity;
    real alphaClipTreshold;
    real3 bakeDiffuseLighting;
    real3 backBakeDiffuseLighting;
    real shadowMask0;
    real shadowMask1;
    real shadowMask2;
    real shadowMask3;
    real3 emissiveColor;
    real2 motionVector;
    real2 distortion;
    real distortionBlur;
    uint isLightmap;
    uint renderingLayers;
    float depthOffset;
};

/*
struct UVMappingHDRP {
    int mappingType;
    float2 uv;

    float2 uvZY;
    float2 uvXZ;
    float2 uvXY;
    
    float3 normalWS;
    float3 triplanarWeights;

};

struct LayerTexCoord {
    UVMapping base0;
    UVMapping base1;
    UVMapping base2;
    UVMapping base3;

    UVMapping details0;
    UVMapping details1;
    UVMapping details2;
    UVMapping details3;

    UVMapping blendMask;
};
*/

struct BSDFDataHDRP {
    float3 diffuseColor;
    float3 specularColor;
    float fresnel0;
    float ambientOcclusion;
    float specularOcclusion;
    float3 normalWS;
    float perceptualRoughness;
    float3 tangentWS;
    float3 bitangentWS;
    float roughness;
};

struct PreLightData {
    float NdotV;
    //float partLambdaV;
    //float energyCompensation;

    //IBL
    float3 iblR;
    float iblPerceptualRoughness;

    float3 specularFGD;
    float diffuseFGD;
};

#endif