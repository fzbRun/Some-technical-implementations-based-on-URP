Shader "Water/wave"
{
    Properties
    {
        _Color("Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _MainTex("Main Texture", 2D) = "white" {}
        _WaveA ("Wave A (dir, steepness, waveLength)", Vector) = (1.0, 0.0, 0.5, 10.0)
        _WaveB ("Wave B", Vector) = (0.0, 1.0, 0.25, 20.0)
        _WaveC ("Wave C", Vector) = (1.0, 1.0, 0.15, 10.0)
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
                    UNITY_DEFINE_INSTANCED_PROP(float4, _WaveA)
                    UNITY_DEFINE_INSTANCED_PROP(float4, _WaveB)
                    UNITY_DEFINE_INSTANCED_PROP(float4, _WaveC)
                    UNITY_DEFINE_INSTANCED_PROP(float, _Smoothness)
                    UNITY_DEFINE_INSTANCED_PROP(float, _Metallic)
                UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        struct Attributes {
            float4 vertex : POSITION;
            float3 normal : NORMAL;
            float2 texcoord : TEXCOORD0;
        };

        struct Varyings {
            float4 position : SV_POSITION;
            float3 worldPos : VAR_WORLDPOS;
            float3 normal : VAR_NORMAL;
            float2 uv : VAR_UV;
        };

        float3 GerstnerWave(float4 wave, float3 p, inout float3 tangent, inout float3 bitangent) {

            float2 _Direction = wave.xy;
            float _Steepness = wave.z;
            float _WaveLength = wave.w;
            float k = 2.0f * PI / _WaveLength;
            float c = sqrt(9.8f / k);
            float2 d = normalize(_Direction);
            float f = (dot(d, p.xz) - c * _Time.y) * k;
            float a = _Steepness / k;

            tangent += float3(
                -d.x * d.x * (_Steepness * sin(f)),
                d.x * (_Steepness * cos(f)),
                -d.x * d.y * (_Steepness * sin(f))
                );
            bitangent += float3(
                -d.x * d.y * (_Steepness * sin(f)),
                d.y * (_Steepness * cos(f)),
                -d.y * d.y * (_Steepness * sin(f))
                );
            return float3(
                d.x * (a * cos(f)),
                a * sin(f),
                d.y * (a * cos(f))
                );

        }

        Varyings vert(Attributes i) {

            Varyings o;

            float3 gridPoint = i.vertex.xyz;
            float3 tangent = float3(1.0f, 0.0f, 0.0f);
            float3 bitangent = float3(0.0f, 0.0f, 1.0f);

            float3 p = gridPoint;
            p += GerstnerWave(_WaveA, gridPoint, tangent, bitangent);
            p += GerstnerWave(_WaveB, gridPoint, tangent, bitangent);
            p += GerstnerWave(_WaveC, gridPoint, tangent, bitangent);

            float3 normal = normalize(cross(bitangent, tangent));

            o.worldPos = TransformObjectToWorld(p);
            o.position = TransformWorldToHClip(o.worldPos);
            o.normal = TransformObjectToWorldNormal(normal);
            o.uv = i.texcoord * _MainTex_ST.xy + _MainTex_ST.zw;

            return o;
        }

        float4 frag(Varyings i) : SV_TARGET{

            float2 uv = i.uv;

            float4 Color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv) * _Color;

            //float3 N = normalize(normalA + normalB);
            float3 N = normalize(i.normal);
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

        Cull Off

         HLSLPROGRAM
             #pragma vertex vert;
             #pragma fragment frag;
         ENDHLSL

     }
        }
}
