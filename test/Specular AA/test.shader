Shader "Specular AA/test"
{
    Properties
    {
        _LEANB ("LEAN B Texture", 2D) = "white" {}
        _LEANM ("LEAN M Texture", 2D) = "white" {}
    }
    SubShader
    {
         HLSLINCLUDE

           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
           #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

            TEXTURE2D(_LEANB);
            SAMPLER(sampler_LEANB);
            TEXTURE2D(_LEANM);
            SAMPLER(sampler_LEANM);

            struct Attributes {
                float4 vertex : POSITION;
                float2 texcoord : TEXCOORD0;
            };

            struct Varyings {
                float4 position : SV_POSITION;
                float2 uv : VAR_UV;
            };

          Varyings vert(Attributes i) {

                Varyings o;

                o.position = TransformObjectToHClip(i.vertex);
                o.uv = i.texcoord;

                return o;

          }

          float4 frag(Varyings i) : SV_TARGET{

              float2 B = SAMPLE_TEXTURE2D(_LEANB, sampler_LEANB, i.uv).rg;
              float3 M = SAMPLE_TEXTURE2D(_LEANM, sampler_LEANM, i.uv).rgb;

              return M.x > 10.0f ? 1.0f : 0.0f;

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
