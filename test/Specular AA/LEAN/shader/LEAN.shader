Shader "Specular AA/LEAN"
{
    Properties
    {
        _AlbedoMap("Albedo Map", 2D) = "white"{}
        _NormalMap("Normal Map", 2D) = "bump"{}
        [Toggle(_LEAN)]_LEAN("LEAN", float) = 0.0
        _LEANB("LEAN B Texture", 2D) = "white" {}
        _LEANM("LEAN M Texture", 2D) = "white" {}
        _Roughness("Roughness", Range(0.01, 0.99)) = 0.0
    }
        SubShader
    {
         HLSLINCLUDE

           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
           #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

            TEXTURE2D(_AlbedoMap);
            SAMPLER(sampler_AlbedoMap);
            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);
            TEXTURE2D(_LEANB);
            SAMPLER(sampler_LEANB);
            TEXTURE2D(_LEANM);
            SAMPLER(sampler_LEANM);

            UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
                UNITY_DEFINE_INSTANCED_PROP(float, _Roughness)
            UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

            struct Attributes {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 texcoord : TEXCOORD0;
            };

            struct Varyings {
                float4 position : SV_POSITION;
                float3 worldPos : VAR_WORLDPOS;
                float3 normal : VAR_NORMAL;
                float4 tangent : VAT_TANGENT;
                float2 uv : VAR_UV;
            };

          Varyings vert(Attributes i) {

                Varyings o;

                o.worldPos = TransformObjectToWorld(i.vertex);
                o.position = TransformWorldToHClip(o.worldPos);
                o.normal = TransformObjectToWorldNormal(i.normal);
                o.tangent = float4(TransformObjectToWorldDir(i.tangent.xyz), i.tangent.w);
                o.uv = i.texcoord;

                return o;

          }

          float3 DecodeNormal(float4 sample, float scale) {
            #if defined(UNITY_NO_DXT5nm)
              return UnpackNormalRGB(sample, scale);
            #else
              return UnpackNormalmapRGorAG(sample, scale);
            #endif
          }

          #include "LEAN.hlsl"

          float4 frag(Varyings i) : SV_TARGET{

              # if UNITY_UV_STARTS_AT_TOP
                i.uv.y = 1 - i.uv.y;
              # endif

              Light light = GetMainLight();
              float3 L = light.direction;
              float3 V = normalize(GetCameraPositionWS() - i.worldPos);
              float3 H = normalize(L + V);

              float3 normal = 0.0f;
              float4 tangent = normalize(i.tangent);
              float3 baseNormal = normalize(i.normal);
              float3 bitangent = normalize(cross(baseNormal, tangent) * sign(tangent.w));
              float3x3 TBN = float3x3(tangent.xyz, bitangent, baseNormal);

              #ifdef _LEAN
              H = mul(TBN, H);  //TBN按行放，所以要右乘，所以TBN的逆矩阵=转置=左乘
              float3 specular = LEAN_Backmann_NDF(i.uv, H, _Roughness, normal);
              normal = mul(normal, TBN);
              #else
              float4 N = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.uv);
              normal = DecodeNormal(N, 1.0f);
              normal = mul(normal, TBN);
              float3 specular = pow(saturate(dot(normal, H)), 64.0f * (1.0f - _Roughness));
              #endif

              float3 diffuse = SAMPLE_TEXTURE2D(_AlbedoMap, sampler_AlbedoMap, i.uv) * saturate(dot(normal, L));

              return specular.x;

          }

      ENDHLSL


      Pass {

          Tags{
              "RenderPipeline" = "UniversalPipeline"
          }

          HLSLPROGRAM
              #pragma shader_feature_local _LEAN
              #pragma vertex vert;
              #pragma fragment frag;
          ENDHLSL

        }
    }
}
