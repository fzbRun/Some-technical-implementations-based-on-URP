Shader "Environment_Mapping/Octahedral"
{
    Properties
    {
        _Octahedral_Map("Octahedral Map", 2D) = "white" {}
    }
        SubShader
    {

        HLSLINCLUDE

           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
           #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

            TEXTURE2D(_Octahedral_Map);
            SAMPLER(sampler_Octahedral_Map);
            UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
                UNITY_DEFINE_INSTANCED_PROP(float4, _Octahedral_Map_TexelSize);
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
                normal = abs(normal);
                float2 uv = float2(normal.x, normal.z) * (1.0f / (normal.x + normal.y + normal.z));
                if (i.normal.y < 0.0f) {
                    uv = 1.0f - float2(uv.y, uv.x);
                }
                uv *= float2(i.normal.x >= 0.0f ? 1.0f : -1.0f, i.normal.z >= 0.0f ? 1.0f : -1.0f);
                uv = uv * 0.5f + 0.5f;
                uv += 0.5f * _Octahedral_Map_TexelSize.xy;

                # if UNITY_UV_STARTS_AT_TOP
                // uv.y = 1 - uv.y;
             # endif
                float4 Color;
                Color = SAMPLE_TEXTURE2D(_Octahedral_Map, sampler_Octahedral_Map, uv);


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
