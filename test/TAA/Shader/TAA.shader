Shader "antiAliasing/TAA"
{
    Properties
    {
        [MainTexture] _MainTex("MainTex", 2D) = "white" {}
    }
    SubShader
    {

        HLSLINCLUDE

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

            CBUFFER_START(UnityPerMaterial)

            CBUFFER_END

            TEXTURE2D(_MainTex);
            TEXTURE2D(_LastFrameTexture);
            TEXTURE2D(_MotionVectorTexture);
            SAMPLER(sampler_MainTex);
            SAMPLER(sampler_LastFrameTexture);
            SAMPLER(sampler_MotionVectorTexture);
            float _Blend;
            float4x4 UNITY_MATRIX_PREV_VP;

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
                o.uv = i.texcoord;

                return o;
            }

            float3 RGBToYCoCg(float3 RGB)
            {
                float Y = dot(RGB, float3(1, 2, 1));
                float Co = dot(RGB, float3(2, 0, -2));
                float Cg = dot(RGB, float3(-1, 2, -1));

                float3 YCoCg = float3(Y, Co, Cg);
                return YCoCg;
            }

            float3 YCoCgToRGB(float3 YCoCg)
            {
                float Y = YCoCg.x * 0.25;
                float Co = YCoCg.y * 0.25;
                float Cg = YCoCg.z * 0.25;

                float R = Y + Co - Cg;
                float G = Y + Cg;
                float B = Y - Co - Cg;

                float3 RGB = float3(R, G, B);
                return RGB;
            }

            float3 ClipHistory(float3 History, float3 BoxMin, float3 BoxMax)
            {
                float3 Filtered = (BoxMin + BoxMax) * 0.5f;
                float3 RayOrigin = History;
                float3 RayDir = Filtered - History;
                RayDir = abs(RayDir) < (1.0 / 65536.0) ? (1.0 / 65536.0) : RayDir;
                float3 InvRayDir = rcp(RayDir);

                float3 MinIntersect = (BoxMin - RayOrigin) * InvRayDir;
                float3 MaxIntersect = (BoxMax - RayOrigin) * InvRayDir;
                float3 EnterIntersect = min(MinIntersect, MaxIntersect);
                float ClipBlend = max(EnterIntersect.x, max(EnterIntersect.y, EnterIntersect.z));
                ClipBlend = saturate(ClipBlend);
                return lerp(History, Filtered, ClipBlend);
            }

            float3 makeClip(float3 lastCcolor, float3 curColor, float2 uv) {
                float3 AABBMin, AABBMax;
                AABBMax = AABBMin = RGBToYCoCg(curColor);

                for (int x = -1; x <= 1; ++x)
                {
                    for (int y = -1; y <= 1; ++y)
                    {
                        float2 duv = float2(x, y) / _ScaledScreenParams.xy;
                        float3 C = RGBToYCoCg(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + duv).xyz);
                        AABBMin = min(AABBMin, C);
                        AABBMax = max(AABBMax, C);
                    }
                }
                float3 preYCoCg = RGBToYCoCg(lastCcolor);
                return YCoCgToRGB(ClipHistory(preYCoCg, AABBMin, AABBMax));
            }

            float4 frag(Varyings i) : SV_TARGET{

                float4 curColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);

                //float4 lastClipPos = mul(UNITY_MATRIX_PREV_VP, float4(i.worldPos, 1.0f));
                float4 lastClipPos = mul(_PrevViewProjMatrix, float4(i.worldPos, 1.0f));
                float2 lastScreenPos = (lastClipPos.xy / lastClipPos.w) * 2.0f - 1.0f;
                float2 uvOffset = SAMPLE_TEXTURE2D(_MotionVectorTexture, sampler_MotionVectorTexture, lastScreenPos).xy;
                float2 uv = lastScreenPos - uvOffset;
                float4 lastColor = SAMPLE_TEXTURE2D(_LastFrameTexture, sampler_LastFrameTexture, uv);

                lastColor.rgb = makeClip(lastColor.rgb, curColor.rgb, i.uv);

                float4 finalColor = lerp(lastColor, curColor, _Blend);
                return finalColor;

            }

        ENDHLSL

        Pass{

                Tags{
                    "RenderPipeline" = "UniversalPipeline"
                }

                    HLSLPROGRAM
                        #pragma vertex vert;
                        #pragma fragment frag;
                    ENDHLSL

        }

    }
}
