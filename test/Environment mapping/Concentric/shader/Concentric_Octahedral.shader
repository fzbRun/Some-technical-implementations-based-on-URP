Shader "Environment_Mapping/Concentric_Octahedral"
{
    Properties
    {
        _Concentric_Octahedral_Map ("_Concentric_Octahedral_Map", 2D) = "white" {}
    }
        SubShader
    {

        HLSLINCLUDE

           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
           #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

            TEXTURE2D(_Concentric_Octahedral_Map);
            SAMPLER(sampler_Concentric_Octahedral_Map);
            UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
                UNITY_DEFINE_INSTANCED_PROP(float4, _Concentric_Octahedral_Map_TexelSize);
            UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

            struct Attributes {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 texcoord : TEXCOORD0;
            };

            struct Varyings {
                float4 position : SV_POSITION;
                float3 normal : VAR_NORMAL;
                float2 uv : VAR_UV;
            };

            Varyings vert(Attributes i) {

                Varyings o;

                o.position = TransformObjectToHClip(i.vertex);
                o.normal = TransformObjectToWorldNormal(i.normal);
                o.uv = i.texcoord;

                return o;

            }

            float sign1(float x) {
                return x >= 0.0f ? 1.0f : -1.0f;
            }

            float2 sampleConcentric_Octahedral_Map(float3 normal) {

                float x = abs(normal.x);
                float y = abs(normal.y);
                float z = abs(normal.z);

                float a = max(x, z);
                float b = min(x, z);
                float fai = a == 0.0f ? 0.0f : b / a;

                float fai2PI = (float)(0.00000406531 + 0.636227 * fai +
                    0.00615523 * fai * fai -
                    0.247326 * fai * fai * fai +
                    0.0881627 * fai * fai * fai * fai +
                    0.0419157 * fai * fai * fai * fai * fai -
                    0.0251427 * fai * fai * fai * fai * fai * fai);
                if (x < z)
                {
                    fai2PI = 1.0f - fai2PI;
                }

                float r = sqrt(1.0f - y);

                float v = r * fai2PI;
                float u = r - v;

                if (u == 0.0f) {
                    u = _Concentric_Octahedral_Map_TexelSize.r;
                }

                float2 uv = float2(u, v);
                if (normal.y < 0.0f) {
                    uv = 1.0f - float2(v, u);
                }

                uv = uv * float2(sign1(normal.x), sign1(normal.z));
                uv = uv * 0.5f + 0.5f;

                return uv;

            }

            float4 frag(Varyings i) : SV_TARGET{

                float3 normal = normalize(i.normal);
                float2 uv = sampleConcentric_Octahedral_Map(normal);
                //uv += 0.5f * _Concentric_Octahedral_Map_TexelSize.xy;

                # if UNITY_UV_STARTS_AT_TOP
                    uv.y = 1 - uv.y;
                # endif

                float4 Color = SAMPLE_TEXTURE2D(_Concentric_Octahedral_Map, sampler_Concentric_Octahedral_Map, uv);

                //return float4(uv, 0.0f, 1.0f);
                return Color;

            }

            ENDHLSL

            Pass {

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
