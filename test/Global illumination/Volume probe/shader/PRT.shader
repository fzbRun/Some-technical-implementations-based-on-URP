Shader "GI/PRT"
{
    Properties
    {
        
    }
    SubShader
    {
        HLSLINCLUDE

           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
           #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

            TEXTURE3D(_IrradianceVolume_SH0);
            TEXTURE3D(_IrradianceVolume_SH1);
            TEXTURE3D(_IrradianceVolume_SH2);
            TEXTURE3D(_IrradianceVolume_SH3);
            SAMPLER(sampler_IrradianceVolume_SH0);
            TEXTURE2D(_VisibilityVolume_SH0);
            TEXTURE2D(_VisibilityVolume_SH1);
            TEXTURE2D(_VisibilityVolume_SH2);
            TEXTURE2D(_VisibilityVolume_SH3);
            SAMPLER(sampler_VisibilityVolume_SH0);
            UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
                UNITY_DEFINE_INSTANCED_PROP(float4, _Volume_texelSize);
                UNITY_DEFINE_INSTANCED_PROP(float4, _VisibilityTexture_texelSize);
                UNITY_DEFINE_INSTANCED_PROP(float3, _Volume_size);
                UNITY_DEFINE_INSTANCED_PROP(float3, _Volume_start);
                UNITY_DEFINE_INSTANCED_PROP(float3, _Volume_interval);
                UNITY_DEFINE_INSTANCED_PROP(float, _judge_offset_size);
                UNITY_DEFINE_INSTANCED_PROP(float, _worldPos_offset_size);
            UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

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

            Varyings vert(Attributes i) {

                Varyings o;

                o.worldPos = TransformObjectToWorld(i.vertex);
                o.position = TransformWorldToHClip(o.worldPos);
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
                    u = _VisibilityTexture_texelSize.r;
                }

                float2 uv = float2(u, v);
                if (normal.y < 0.0f) {
                    uv = 1.0f - float2(v, u);
                }

                uv = uv * float2(sign1(normal.x), sign1(normal.z));
                uv = uv * 0.5f + 0.5f;

                return uv;

            }

            float3 getLo(float2 uv, float3 uv2) {
                float4 cos = SAMPLE_TEXTURE2D(_VisibilityVolume_SH0, sampler_VisibilityVolume_SH0, uv);
                cos = cos * 2.0f - 1.0f;
                float4 Li = SAMPLE_TEXTURE3D(_IrradianceVolume_SH0, sampler_IrradianceVolume_SH0, uv2);
                Li = Li * 2.0f - 1.0f;
                float4 Lo = Li.r * cos.r;
                Lo += Li.g * cos.g;
                Lo += Li.b * cos.b;
                Lo += Li.a * cos.a;

                cos = SAMPLE_TEXTURE2D(_VisibilityVolume_SH1, sampler_VisibilityVolume_SH0, uv);
                cos = cos * 2.0f - 1.0f;
                Li = SAMPLE_TEXTURE3D(_IrradianceVolume_SH1, sampler_IrradianceVolume_SH0, uv2);
                Li = Li * 2.0f - 1.0f;
                Lo += Li.r * cos.r;
                Lo += Li.g * cos.g;
                Lo += Li.b * cos.b;
                Lo += Li.a * cos.a;

                cos = SAMPLE_TEXTURE2D(_VisibilityVolume_SH2, sampler_VisibilityVolume_SH0, uv);
                cos = cos * 2.0f - 1.0f;
                Li = SAMPLE_TEXTURE3D(_IrradianceVolume_SH2, sampler_IrradianceVolume_SH0, uv2);
                Li = Li * 2.0f - 1.0f;
                Lo += Li.r * cos.r;
                Lo += Li.g * cos.g;
                Lo += Li.b * cos.b;
                Lo += Li.a * cos.a;

                cos = SAMPLE_TEXTURE2D(_VisibilityVolume_SH3, sampler_VisibilityVolume_SH0, uv);
                cos = cos * 2.0f - 1.0f;
                Li = SAMPLE_TEXTURE3D(_IrradianceVolume_SH3, sampler_IrradianceVolume_SH0, uv2);
                Li = Li * 2.0f - 1.0f;
                Lo += Li.r * cos.r;
                Lo += Li.g * cos.g;
                Lo += Li.b * cos.b;
                Lo += Li.a * cos.a;

                return Lo;
            }

            float3 getLoWithRotate(float2 uv, float3 uv2, float3 normal) {

                float4 Lo = 0.0f;

                float x = normal.x;
                float z = normal.y;
                float y = normal.z;
                float SHFunction_normal[16] =
                {
                    1.0f,

                    y,
                    z,
                    x,

                    x * y,
                    y * z,
                    -x * x - y * y + 2 * z * z,
                    z * x,
                    x * x - y * y,

                    y * (3 * x * x - y * y),
                    x * y * z,
                    y * (4 * z * z - x * x - y * y),
                    z * (2 * z * z - 3 * x * x - 3 * y * y),
                    x * (4 * z * z - x * x - y * y),
                    z * (x * x - y * y),
                    x * (x * x - 3 * y * y)

                };
                
                float SHFunction16[16] =
                {
                    0.2821,

                    0.4886,
                    0.4886,
                    0.4886,

                    1.09255,
                    1.09255,
                    0.3154,
                    1.09255,
                    0.546275,

                    0.59,
                    2.8906,
                    0.4570458,
                    0.3732,
                    0.4570458,
                    1.4453,
                    0.59
                };

                /*
                float4 cos = SAMPLE_TEXTURE2D(_VisibilityVolume_SH0, sampler_VisibilityVolume_SH0, uv);
                cos = cos * 2.0f - 1.0f;

                float4 Li = SAMPLE_TEXTURE3D(_IrradianceVolume_SH0, sampler_IrradianceVolume_SH0, uv2);
                Li = Li * 2.0f - 1.0f;

                float cofeBaseFun = sqrt(4.0f * PI) * SHFunction16[0] * SHFunction_normal[0];
                Lo += Li.r * cos.r * cofeBaseFun;

                float cofe = sqrt(4.0f * PI / 3.0f);
                cofeBaseFun = cofe * SHFunction16[1] * SHFunction_normal[1];
                Lo += Li.g * cos.g * cofeBaseFun;
                cofeBaseFun = cofe * SHFunction16[2] * SHFunction_normal[2];
                Lo += Li.b * cos.g * cofeBaseFun;
                cofeBaseFun = cofe * SHFunction16[3] * SHFunction_normal[3];
                Lo += Li.a * cos.g * cofeBaseFun;

                Li = SAMPLE_TEXTURE3D(_IrradianceVolume_SH1, sampler_IrradianceVolume_SH0, uv2);
                Li = Li * 2.0f - 1.0f;

                cofe = sqrt(4.0f * PI / 5.0f);
                cofeBaseFun = cofe * SHFunction16[4] * SHFunction_normal[4];
                Lo += Li.r * cos.b * cofeBaseFun;
                cofeBaseFun = cofe * SHFunction16[5] * SHFunction_normal[5];
                Lo += Li.g * cos.b * cofeBaseFun;
                cofeBaseFun = cofe * SHFunction16[6] * SHFunction_normal[6];
                Lo += Li.b * cos.b * cofeBaseFun;
                cofeBaseFun = cofe * SHFunction16[7] * SHFunction_normal[7];
                Lo += Li.a * cos.b * cofeBaseFun;

                Li = SAMPLE_TEXTURE3D(_IrradianceVolume_SH2, sampler_IrradianceVolume_SH0, uv2);
                Li = Li * 2.0f - 1.0f;

                cofeBaseFun = cofe * SHFunction16[8] * SHFunction_normal[8];
                Lo += Li.r * cos.b * cofeBaseFun;

                cofe = sqrt(4.0f * PI / 7.0f);
                cofeBaseFun = cofe * SHFunction16[9] * SHFunction_normal[9];
                Lo += Li.g * cos.a * cofeBaseFun;
                cofeBaseFun = cofe * SHFunction16[10] * SHFunction_normal[10];
                Lo += Li.b * cos.a * cofeBaseFun;
                cofeBaseFun = cofe * SHFunction16[11] * SHFunction_normal[11];
                Lo += Li.a * cos.a * cofeBaseFun;

                Li = SAMPLE_TEXTURE3D(_IrradianceVolume_SH3, sampler_IrradianceVolume_SH0, uv2);
                Li = Li * 2.0f - 1.0f;

                cofeBaseFun = cofe * SHFunction16[12] * SHFunction_normal[12];
                Lo += Li.r * cos.a * cofeBaseFun;
                cofeBaseFun = cofe * SHFunction16[13] * SHFunction_normal[13];
                Lo += Li.g * cos.a * cofeBaseFun;
                cofeBaseFun = cofe * SHFunction16[14] * SHFunction_normal[14];
                Lo += Li.b * cos.a * cofeBaseFun;
                cofeBaseFun = cofe * SHFunction16[15] * SHFunction_normal[15];
                Lo += Li.a * cos.a * cofeBaseFun;

                return Lo;
                */

                float4 Li = SAMPLE_TEXTURE3D(_IrradianceVolume_SH0, sampler_IrradianceVolume_SH0, uv2);
                Li = Li * 2.0f - 1.0f;

                Lo = PI * SHFunction16[0] * SHFunction_normal[0] * Li.r;
                Lo += 0.66667f * PI * SHFunction16[1] * SHFunction_normal[1] * Li.g;
                Lo += 0.66667f * PI * SHFunction16[2] * SHFunction_normal[2] * Li.b;
                Lo += 0.66667f * PI * SHFunction16[3] * SHFunction_normal[3] * Li.a;

                Li = SAMPLE_TEXTURE3D(_IrradianceVolume_SH1, sampler_IrradianceVolume_SH0, uv2);
                Li = Li * 2.0f - 1.0f;

                Lo += 0.25f * PI * SHFunction16[4] * SHFunction_normal[4] * Li.r;
                Lo += 0.25f * PI * SHFunction16[5] * SHFunction_normal[5] * Li.g;
                Lo += 0.25f * PI * SHFunction16[6] * SHFunction_normal[6] * Li.b;
                Lo += 0.25f * PI * SHFunction16[7] * SHFunction_normal[7] * Li.a;

                Li = SAMPLE_TEXTURE3D(_IrradianceVolume_SH2, sampler_IrradianceVolume_SH0, uv2);
                Li = Li * 2.0f - 1.0f;

                Lo += 0.25f * PI * SHFunction16[8] * SHFunction_normal[8] * Li.r;

                return Lo;

            }

            float4 frag(Varyings i) : SV_TARGET{

                float3 normal = normalize(i.normal);

                float3 probeIndex = floor((i.worldPos - _Volume_start) / _Volume_interval);	//获得左下角probe的索引
                float3 probeLBBWorldPos = probeIndex * _Volume_interval + _Volume_start;	//LBB = LeftBottomBehind

                float2 uv = sampleConcentric_Octahedral_Map(normal);
                uv += 0.5f * _VisibilityTexture_texelSize.xy;
                //float3 uv2 = probeIndex / (floor(_Volume_size / _Volume_interval) + 1);
                float3 uv2 = (i.worldPos - _Volume_start) / _Volume_interval;
                uv2 += 0.5f * _Volume_texelSize;

                //float3 Lo = getLo(uv, uv2);
                float3 Lo = getLoWithRotate(uv, uv2, normal);


                return float4(Lo, 1.0f);

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
