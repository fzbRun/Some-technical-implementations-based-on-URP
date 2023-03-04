Shader "Water/refractionDistortionFlow"
{
    Properties
    {
        _Color("Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _MainTex("Main Texture", 2D) = "white" {}
        [NoScaleOffset]_FlowMap("Flow Texture", 2D) = "white"{}
        //[NoScaleOffset]_NormalMap ("Normal Texture", 2D) = "bump"{}
        [NoScaleOffset]_DerivHeightMap("Deriv Height Texture", 2D) = "black"{}
        _UJump("U Jump per phase", Range(-0.25, 0.25)) = 0.25
        _VJump("V Jump per phase", Range(-0.25, 0.25)) = 0.25
        _Tiling("Tiling", Float) = 1.0
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
            #include "../shaderLibrary/LookingThroughWater.hlsl"

            #define INPUT_PROP(name) UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, name)

            UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
                UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
                UNITY_DEFINE_INSTANCED_PROP(float4, _MainTex_ST)
                UNITY_DEFINE_INSTANCED_PROP(float, _UJump)
                UNITY_DEFINE_INSTANCED_PROP(float, _VJump)
                UNITY_DEFINE_INSTANCED_PROP(float, _Tiling)
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
            TEXTURE2D(_DerivHeightMap);
            SAMPLER(sampler_MainTex);

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

            float4 frag(Varyings i) : SV_TARGET{
                /*
                float2 uv = i.uv;
                float3 flow = SAMPLE_TEXTURE2D(_FlowMap, sampler_MainTex, uv).rgb;
                flow.xy = flow.xy * 2.0f - 1.0f;
                flow *= _FlowStrength;
                float noise = SAMPLE_TEXTURE2D(_FlowMap, sampler_MainTex, uv).a;    //使每点的偏移不同，使水流随机
                float time = _Time.y * _Speed + noise;  //使每时每刻偏移不同
                float2 jump = float2(_UJump, _VJump);   //使偏移跳变
                float finalHeightScale = flow.z * _HeightScaleModulated + _HeightScale;

                //使用两个偏移来混合，使得不会出现剧烈变化（如0时变黑）
                float3 uvwA = FlowUVW(uv, time, flow.xy, false, jump, _Tiling, _FlowOffset);
                float3 uvwB = FlowUVW(uv, time, flow.xy, true, jump, _Tiling, _FlowOffset);

                uv = uvwA.xy;
                float3 dhA = UnpackDerivativeHeight(SAMPLE_TEXTURE2D(_DerivHeightMap, sampler_MainTex, uv)) * (uvwA.z * finalHeightScale);
                float4 Color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv) * uvwA.z;    //使用z值来使水流循环变化，不会跳变重置

                uv = uvwB.xy;
                float3 dhB = UnpackDerivativeHeight(SAMPLE_TEXTURE2D(_DerivHeightMap, sampler_MainTex, uv)) * (uvwB.z * finalHeightScale);
                Color += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv) * uvwB.z;
                Color *= _Color;

                float alpha = Color.a;
                Color.rgb = ColorBelowWater(i.position);
                alpha = 1.0f;

                float3 N = normalize(float3(-dhA.xy - dhB.xy, 1.0f));
                Light light = GetMainLight();
                float3 lightColor = light.color;
                float3 L = light.direction;
                float3 V = normalize(GetCameraPositionWS() - i.worldPos);
                float3 H = normalize(V + L);

                float3 ambient = 0.1f * Color;
                float3 diffuse = saturate(dot(N, L)) * Color;
                float3 specular = pow(saturate(dot(N, H)), 64 * _Smoothness) * _Smoothness;

                float3 finalColor = (ambient + diffuse + specular) * lightColor;
                */

                float3 Color = ColorBelowWater(TransformWorldToHClip(i.worldPos));

                return float4(Color, 1.0f);

            }

         ENDHLSL

         Pass {

            Tags{
                "Queue" = "Transparent"
                "IgnoreProjector" = "True"
                "RenderType" = "Transparent"
                "RenderPipeline" = "UniversalRenderPipeline"
            }

            Blend SrcAlpha OneMinusSrcAlpha

             HLSLPROGRAM
                 #pragma vertex vert;
                 #pragma fragment frag;
             ENDHLSL

         }
    }
}
