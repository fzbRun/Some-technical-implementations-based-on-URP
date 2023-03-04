#ifndef UNIVERSAL_SSAO_INCLUDED
#define UNIVERSAL_SSAO_INCLUDED

// Includes
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"

// Textures & Samplers
TEXTURE2D_X(_BaseMap);
TEXTURE2D_X(_ScreenSpaceOcclusionTexture);

SAMPLER(sampler_BaseMap);
SAMPLER(sampler_ScreenSpaceOcclusionTexture);

half4 _SSAOParams;
half4 _CameraViewTopLeftCorner[2];
half4x4 _CameraProjections[2];

float4 _SourceSize;
float4 _ProjectionParams2;
float4 _CameraViewXExtent[2];
float4 _CameraViewYExtent[2];
float4 _CameraViewZExtent[2];

float4 _Dirs[4];

#define INTENSITY _SSAOParams.x
#define RADIUS _SSAOParams.y
#define DOWNSAMPLE _SSAOParams.z

#if defined(SHADER_API_GLES) && !defined(SHADER_API_GLES3)
#define SAMPLE_COUNT 3
#else
#define SAMPLE_COUNT int(_SSAOParams.w)
#endif

#define SCREEN_PARAMS        GetScaledScreenParams()
#define SAMPLE_BASEMAP(uv)   SAMPLE_TEXTURE2D_X(_BaseMap, sampler_BaseMap, UnityStereoTransformScreenSpaceTex(uv));

//就是最后ao的平方系数
static const half kContrast = half(0.5);

static const half kGeometryCoeff = half(0.8);

static const half kBeta = half(0.002);
static const half kEpsilon = half(0.0001);

#if defined(USING_STEREO_MATRICES)
#define unity_eyeIndex unity_StereoEyeIndex
#else
#define unity_eyeIndex 0
#endif

half4 PackAONormal(half ao, half3 n)
{
    return half4(ao, n * half(0.5) + half(0.5));
}

float2x2 makeNoiseMatrix(float2 uv) {

    half noise = InterleavedGradientNoise(uv, 0);
    //half noise = SAMPLE_TEXTURE2D(_NoiseMap, sampler_CameraDepthTexture, uv);
    noise = radians(noise * 90.0f);
    float2x2 noiseMatrix = float2x2(cos(noise), -sin(noise), sin(noise), cos(noise));
    return noiseMatrix;
}

float SampleAndGetLinearEyeDepth(float2 uv)
{
    float rawDepth = SampleSceneDepth(uv.xy);
#if defined(_ORTHOGRAPHIC)
    return LinearDepthToEyeDepth(rawDepth);
#else
    return LinearEyeDepth(rawDepth, _ZBufferParams);
#endif
}

half3 ReconstructViewPos(float2 uv, float depth, float4x4 ip)
{
    uv.y = 1.0 - uv.y;

#if defined(_ORTHOGRAPHIC)
    float zScale = depth * _ProjectionParams.w;
    float3 viewPos = _CameraViewTopLeftCorner[unity_eyeIndex].xyz
        + _CameraViewXExtent[unity_eyeIndex].xyz * uv.x
        + _CameraViewYExtent[unity_eyeIndex].xyz * uv.y
        + _CameraViewZExtent[unity_eyeIndex].xyz * zScale;
#else
    float zScale = depth * _ProjectionParams2.x;
    float3 viewPos = _CameraViewTopLeftCorner[unity_eyeIndex].xyz
        + _CameraViewXExtent[unity_eyeIndex].xyz * uv.x
        + _CameraViewYExtent[unity_eyeIndex].xyz * uv.y;
    viewPos *= zScale;
#endif

    return mul(UNITY_MATRIX_V, half3(viewPos));
}

float3 getViewPos(float4x4 ip, float2 uv) {

    float depth = SampleSceneDepth(uv);
    //float depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, UnityStereoTransformScreenSpaceTex(uv)).r;
#if UNITY_REVERSED_Z
    depth = 1.0f - depth;
#else
    depth = depth * 2.0f - 1.0f;
#endif
    return ComputeWorldSpacePosition(uv, depth, ip);
    /*
    float2 xy = uv * 2.0f - 1.0f;
    float4 clipPos = float4(xy, depth, 1.0f);
    float4 viewPos = mul(ip, clipPos);
    return viewPos.xyz / viewPos.w;
    */
}

half3 ReconstructNormal(float2 uv, float depth, float3 vpos, float4x4 ip)
{
#if defined(_RECONSTRUCT_NORMAL_LOW)
    return half3(normalize(cross(ddy(vpos), ddx(vpos))));
#else
    float2 delta = float2(_SourceSize.zw * 2.0);

    // Sample the neighbour fragments
    float2 lUV = float2(-delta.x, 0.0);
    float2 rUV = float2(delta.x, 0.0);
    float2 uUV = float2(0.0, delta.y);
    float2 dUV = float2(0.0, -delta.y);

    float3 l1 = float3(uv + lUV, 0.0); l1.z = SampleAndGetLinearEyeDepth(l1.xy); // Left1
    float3 r1 = float3(uv + rUV, 0.0); r1.z = SampleAndGetLinearEyeDepth(r1.xy); // Right1
    float3 u1 = float3(uv + uUV, 0.0); u1.z = SampleAndGetLinearEyeDepth(u1.xy); // Up1
    float3 d1 = float3(uv + dUV, 0.0); d1.z = SampleAndGetLinearEyeDepth(d1.xy); // Down1

#if defined(_RECONSTRUCT_NORMAL_MEDIUM) //1111111111111111111111111
    uint closest_horizontal = l1.z > r1.z ? 0 : 1;
    uint closest_vertical = d1.z > u1.z ? 0 : 1;
#else
    float3 l2 = float3(uv + lUV * 2.0, 0.0); l2.z = SampleAndGetLinearEyeDepth(l2.xy); // Left2
    float3 r2 = float3(uv + rUV * 2.0, 0.0); r2.z = SampleAndGetLinearEyeDepth(r2.xy); // Right2
    float3 u2 = float3(uv + uUV * 2.0, 0.0); u2.z = SampleAndGetLinearEyeDepth(u2.xy); // Up2
    float3 d2 = float3(uv + dUV * 2.0, 0.0); d2.z = SampleAndGetLinearEyeDepth(d2.xy); // Down2

    //2倍的1采样点深度减去2采样点深度，就是1采样点深度减去沿着12采样点方向的像素点xy对应的深度与1像素点的差值，得到对应像素点的深度
    const uint closest_horizontal = abs((2.0 * l1.z - l2.z) - depth) < abs((2.0 * r1.z - r2.z) - depth) ? 0 : 1;
    const uint closest_vertical = abs((2.0 * d1.z - d2.z) - depth) < abs((2.0 * u1.z - u2.z) - depth) ? 0 : 1;
#endif

    float3 P1;
    float3 P2;
    if (closest_vertical == 0)
    {
        P1 = closest_horizontal == 0 ? l1 : d1;
        P2 = closest_horizontal == 0 ? d1 : r1;
    }
    else
    {
        P1 = closest_horizontal == 0 ? u1 : r1;
        P2 = closest_horizontal == 0 ? l1 : u1;
    }

    // Use the cross product to calculate the normal...
    return -half3(normalize(cross(getViewPos(ip, P2.xy) - vpos, getViewPos(ip, P1.xy) - vpos)));
#endif
}

half3 SampleNormal(float2 uv, float4x4 ip)
{
#if defined(_SOURCE_DEPTH_NORMALS)
    return half3(SampleSceneNormals(uv));
#else
    float depth = SampleAndGetLinearEyeDepth(uv);
    half3 vpos = getViewPos(ip, uv);
    return ReconstructNormal(uv, depth, vpos, ip);
#endif
}

half4 SSAO(Varyings input) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    float2 uv = input.uv;

    // Parameters used in coordinate conversion
    half3x3 camTransform = (half3x3)_CameraProjections[unity_eyeIndex]; // camera viewProjection matrix
    float4x4 ip = _CameraProjections[unity_eyeIndex];

    float3 vpos_o = getViewPos(ip, uv);
    float3 norm_o;
#if defined(_SOURCE_DEPTH_NORMALS)
    norm_o = half3(SampleSceneNormals(uv));
#else
    norm_o = ReconstructNormal(uv, SampleAndGetLinearEyeDepth(uv), vpos_o, ip);
#endif

    half ao = 0.0f;
    float2x2 noiseMatrix = makeNoiseMatrix(uv);
    for (int d = 0; d < 4; d++) {

        //float2 dir = mul(makeNoiseMatrix(uv), _Dirs[d].xy);
        float2 dir = _Dirs[d].xy;
        half max = 0.0f;

        for (int s = 1; s < SAMPLE_COUNT + 1; s++)
        {

            half2 uv_s = dir * s * _SourceSize.zw + uv;

            float3 s_viewPos = getViewPos(_CameraProjections[unity_eyeIndex], uv_s);

            float3 v_s2 = s_viewPos - vpos_o;

            half3 H = normalize(v_s2);
            half sinH = H.z;
            half sinT = normalize(H - norm_o * dot(norm_o, H)).z;
            half sin = sinH - sinT;

            float distance = pow(length(v_s2), 2);
            half check = step(distance, RADIUS) * step(max, sin);

            ao += (RADIUS - distance) * (sin - max) * check;
            max = sin * check + max * (1.0f - check);

        }
    }

    ao = PositivePow(ao * INTENSITY * 0.25f, kContrast);
    //return 1.0f - ao;
    return PackAONormal(ao, norm_o);
    //return float4(norm_o, 1.0f);
}

half3 GetPackedNormal(half4 p)
{
    return p.gba * half(2.0) - half(1.0);
}

half GetPackedAO(half4 p)
{
    return p.r;
}

half EncodeAO(half x)
{
#if UNITY_COLORSPACE_GAMMA
    return half(1.0 - max(LinearToSRGB(1.0 - saturate(x)), 0.0));
#else
    return x;
#endif
}

half CompareNormal(half3 d1, half3 d2)
{
    return smoothstep(kGeometryCoeff, half(1.0), dot(d1, d2));
}

// Trigonometric function utility
half2 CosSin(half theta)
{
    half sn, cs;
    sincos(theta, sn, cs);
    return half2(cs, sn);
}

// Geometry-aware separable bilateral filter
half4 Blur(float2 uv, float2 delta) : SV_Target
{
    half4 p0 = (half4) SAMPLE_BASEMAP(uv);
    half4 p1a = (half4) SAMPLE_BASEMAP(uv - delta * 1.3846153846);
    half4 p1b = (half4) SAMPLE_BASEMAP(uv + delta * 1.3846153846);
    half4 p2a = (half4) SAMPLE_BASEMAP(uv - delta * 3.2307692308);
    half4 p2b = (half4) SAMPLE_BASEMAP(uv + delta * 3.2307692308);

    #if defined(BLUR_SAMPLE_CENTER_NORMAL)
        #if defined(_SOURCE_DEPTH_NORMALS)
            half3 n0 = half3(SampleSceneNormals(uv));
        #else
            half3 n0 = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, UnityStereoTransformScreenSpaceTex(uv)).yzw;
            n0 = n0 * 2.0f - 1.0f;
        #endif
    #else
        //half3 n0 = GetPackedNormal(p0);
        half3 n0 = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, UnityStereoTransformScreenSpaceTex(uv)).yzw;
        n0 = n0 * 2.0f - 1.0f;
    #endif

    half w0 = half(0.2270270270);
    half w1a = CompareNormal(n0, GetPackedNormal(p1a)) * half(0.3162162162);
    half w1b = CompareNormal(n0, GetPackedNormal(p1b)) * half(0.3162162162);
    half w2a = CompareNormal(n0, GetPackedNormal(p2a)) * half(0.0702702703);
    half w2b = CompareNormal(n0, GetPackedNormal(p2b)) * half(0.0702702703);

    half s = half(0.0);
    s += GetPackedAO(p0) * w0;
    s += GetPackedAO(p1a) * w1a;
    s += GetPackedAO(p1b) * w1b;
    s += GetPackedAO(p2a) * w2a;
    s += GetPackedAO(p2b) * w2b;
    s *= rcp(w0 + w1a + w1b + w2a + w2b);

    return PackAONormal(s, n0);
}

half BlurSmall(float2 uv, float2 delta)
{
    half4 p0 = (half4) SAMPLE_BASEMAP(uv);
    half4 p1 = (half4) SAMPLE_BASEMAP(uv + float2(-delta.x, -delta.y));
    half4 p2 = (half4) SAMPLE_BASEMAP(uv + float2(delta.x, -delta.y));
    half4 p3 = (half4) SAMPLE_BASEMAP(uv + float2(-delta.x, delta.y));
    half4 p4 = (half4) SAMPLE_BASEMAP(uv + float2(delta.x, delta.y));

    half3 n0 = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, UnityStereoTransformScreenSpaceTex(uv)).yzw;
    n0 = n0 * 2.0f - 1.0f;

    half w0 = half(1.0);
    half w1 = CompareNormal(n0, GetPackedNormal(p1));
    half w2 = CompareNormal(n0, GetPackedNormal(p2));
    half w3 = CompareNormal(n0, GetPackedNormal(p3));
    half w4 = CompareNormal(n0, GetPackedNormal(p4));

    half s = half(0.0);
    s += GetPackedAO(p0) * w0;
    s += GetPackedAO(p1) * w1;
    s += GetPackedAO(p2) * w2;
    s += GetPackedAO(p3) * w3;
    s += GetPackedAO(p4) * w4;

    return s *= rcp(w0 + w1 + w2 + w3 + w4);
}

half4 HorizontalBlur(Varyings input) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    const float2 uv = input.uv;
    const float2 delta = float2(_SourceSize.z, 0.0);
    return Blur(uv, delta);
}

half4 VerticalBlur(Varyings input) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    const float2 uv = input.uv;
    const float2 delta = float2(0.0, _SourceSize.w * rcp(DOWNSAMPLE));
    return Blur(uv, delta);
}

half4 FinalBlur(Varyings input) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    const float2 uv = input.uv;
    const float2 delta = _SourceSize.zw;
    return half(1.0) - BlurSmall(uv, delta);
}

#endif //UNIVERSAL_SSAO_INCLUDED
