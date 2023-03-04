Shader "Environment_Mapping/Double_Paraboloid"
{
    Properties
    {
        _Front_Double_Paraboloid_Map("Front Double Paraboloid Map", 2D) = "white" {}
        _Back_Double_Paraboloid_Map("Back Double Paraboloid Map", 2D) = "white" {}
    }
        SubShader
    {

        HLSLINCLUDE

           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
           #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

            TEXTURE2D(_Front_Double_Paraboloid_Map);
            TEXTURE2D(_Back_Double_Paraboloid_Map);
            SAMPLER(sampler_Front_Double_Paraboloid_Map);
            UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
                UNITY_DEFINE_INSTANCED_PROP(float4, _Front_Double_Paraboloid_Map_TexelSize);
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

            float4 frag(Varyings i) : SV_TARGET{

                float3 normal = normalize(i.normal);
                float3 normalParabola = normal + float3(0.0f, 0.0f, 1.0f);
                float2 uv = normalParabola.xy / (1.0f + abs(normal.z));
                uv = uv * 0.5f + 0.5f;
                uv += 0.5f * _Front_Double_Paraboloid_Map_TexelSize.xy;

                # if UNITY_UV_STARTS_AT_TOP
                   // uv.y = 1 - uv.y;
                # endif
                    float4 Color;
                if (normal.z > 0.0f) {
                    Color = SAMPLE_TEXTURE2D(_Front_Double_Paraboloid_Map, sampler_Front_Double_Paraboloid_Map, uv);
                }
                else {
                    Color = SAMPLE_TEXTURE2D(_Back_Double_Paraboloid_Map, sampler_Front_Double_Paraboloid_Map, uv);
                }

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
