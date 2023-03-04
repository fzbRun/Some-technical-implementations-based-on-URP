Shader "Water/directionalFlow"
{
    Properties
    {
        _Color("Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _MainTex("Main Texture", 2D) = "white" {}
        [NoScaleOffset]_FlowMap("Flow Texture", 2D) = "white"{}
        [Toggle(_DUAL_GRID)] _DualGrid ("Dual Grid", Int) = 0
        [NoScaleOffset]_DerivHeightMap("Deriv Height Texture", 2D) = "black"{}
        _Tiling("Tiling", Float) = 1.0
        _TilingModulated("Tiling Modulated", Float) = 1.0
        _GirdResolution ("Grid Resolution", Float) = 10.0
        _Speed("Speed", Float) = 1.0
        _FlowStrength("Flow Strength", Float) = 1.0
        _FlowOffset("Flow Offset", Float) = 0.0
        _HeightScale("Height Scale", Float) = 0.25
        _HeightScaleModulated("Height Scale Modulated", Float) = 0.75
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 1.0
        _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
    }
        SubShader
        {
             HLSLINCLUDE

                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
                #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
                #include "../shaderLibrary/Flow.hlsl"

                #define INPUT_PROP(name) UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, name)

                UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
                    UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
                    UNITY_DEFINE_INSTANCED_PROP(float4, _MainTex_ST)
                    //UNITY_DEFINE_INSTANCED_PROP(float, _UJump)
                    //UNITY_DEFINE_INSTANCED_PROP(float, _VJump)
                    UNITY_DEFINE_INSTANCED_PROP(float, _Tiling)
                    UNITY_DEFINE_INSTANCED_PROP(float, _TilingModulated)
                    UNITY_DEFINE_INSTANCED_PROP(float, _GirdResolution)
                    UNITY_DEFINE_INSTANCED_PROP(float, _Speed)
                    UNITY_DEFINE_INSTANCED_PROP(float, _FlowStrength)
                    UNITY_DEFINE_INSTANCED_PROP(float, _FlowOffset)
                    UNITY_DEFINE_INSTANCED_PROP(float, _HeightScale)
                    UNITY_DEFINE_INSTANCED_PROP(float, _HeightScaleModulated)
                    UNITY_DEFINE_INSTANCED_PROP(float, _Smoothness)
                    UNITY_DEFINE_INSTANCED_PROP(float, _Metallic)
                UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

                TEXTURE2D(_MainTex);
                TEXTURE2D(_FlowMap);
                //TEXTURE2D(_NormalMap);
                TEXTURE2D(_DerivHeightMap);
                SAMPLER(sampler_FlowMap);

                struct Attributes {
                    float4 vertex : POSITION;
                    float2 texcoord : TEXCOORD0;
                };

                struct Varyings {
                    float4 position : SV_POSITION;
                    float3 worldPos : VAR_WORLDPOS;
                    float2 uv : VAR_UV;
                };

                Varyings vert(Attributes i) {

                    Varyings o;

                    o.worldPos = TransformObjectToWorld(i.vertex);
                    o.position = TransformWorldToHClip(o.worldPos);
                    o.uv = i.texcoord * _MainTex_ST.xy + _MainTex_ST.zw;

                    return o;
                }

                float3 UnpackDerivativeHeight(float4 textureData) {
                    float3 dh = textureData.agb;
                    dh.xy = dh.xy * 2.0f - 1.0f;
                    return dh;
                }

                float3 FlowCell(float2 uv, float2 offset, float time, bool girdB) {

                    float2x2 derivRotation;
                    float2 shift = 1.0f - offset;
                    shift *= 0.0f;
                    offset *= 0.5f;
                    if (girdB) {
                        offset += 0.25f;
                        shift -= 0.25f;
                    }
                    float2 uvTiled = (floor(uv * _GirdResolution + offset) + shift) / _GirdResolution;
                    float3 flow = SAMPLE_TEXTURE2D(_FlowMap, sampler_FlowMap, uvTiled).rgb;
                    flow.xy = flow.xy * 2.0f - 1.0f;
                    flow.z *= _FlowStrength;
                    float tiling = flow.z * _TilingModulated + _Tiling;
                    float2 uvFlow = DirectionalFlowUV(uv + offset, flow, tiling, time, derivRotation);

                    float3 dh = UnpackDerivativeHeight(SAMPLE_TEXTURE2D(_DerivHeightMap, sampler_FlowMap, uvFlow));
                    dh.xy = mul(derivRotation, dh.xy);
                    dh *= flow.z * _HeightScaleModulated + _HeightScale;

                    return dh;

                }

                float3 FlowGird(float2 uv, float time, bool girdB) {
                    float3 dhA = FlowCell(uv, float2(0.0f, 0.0f), time, girdB);
                    float3 dhB = FlowCell(uv, float2(1.0f, 0.0f), time, girdB);
                    float3 dhC = FlowCell(uv, float2(0.0f, 1.0f), time, girdB);
                    float3 dhD = FlowCell(uv, float2(1.0f, 1.0f), time, girdB);

                    float2 t = uv * _GirdResolution;
                    if (girdB) {
                        t += 0.25f;
                    }
                    t = abs(2.0f * frac(t) - 1.0f);
                    float wA = (1.0f - t.x) * (1.0f - t.y);
                    float wB = t.x * (1.0f - t.y);
                    float wC = (1.0f - t.x) * t.y;
                    float wD = t.x * t.y;

                    float3 dh = dhA * wA + dhB * wB + dhC * wC + dhD * wD;
                    return dh;
                }

                float4 frag(Varyings i) : SV_TARGET{

                    float2 uv = i.uv;
                    float time = _Time.y * _Speed;

                    float3 dh = FlowGird(uv, time, false);
                    #if defined(_DUAL_GRID)
                    dh = (dh + FlowGird(uv, time, true)) * 0.5f;
                    #endif

                    float4 Color = dh.z * dh.z *_Color;

                    //float3 N = normalize(normalA + normalB);
                    float3 N = normalize(float3(-dh.xy, 1.0f));
                    Light light = GetMainLight();
                    float3 lightColor = light.color;
                    float3 L = light.direction;
                    float3 V = normalize(GetCameraPositionWS() - i.worldPos);
                    float3 H = normalize(V + L);

                    float3 ambient = 0.1f * Color;
                    float3 diffuse = saturate(dot(N, L)) * Color;
                    float3 specular = pow(saturate(dot(N, H)), 64 * _Smoothness) * _Smoothness;

                    float3 finalColor = (ambient + diffuse + specular) * lightColor;

                    return float4(finalColor, 1.0f);

                }

             ENDHLSL

             Pass {

                 Tags{
                     "RenderPipeline" = "UniversalPipeline"
                 }

                 HLSLPROGRAM
                     #pragma shader_feature _DUAL_GRID
                     #pragma vertex vert;
                     #pragma fragment frag;
                 ENDHLSL

             }
        }
}
