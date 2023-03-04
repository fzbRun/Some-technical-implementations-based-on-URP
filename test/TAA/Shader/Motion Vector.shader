Shader "Buffer/Motion Vector"
{
    Properties
    {

    }
    SubShader
    {

        HLSLINCLUDE

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

            float4x4 UNITY_MATRIX_PREV_VP;
            float4x4 UNITY_MATRIX_UNJITTERED_VP;
            float4 JitterParams;

            struct Attributes {
                float4 vertex : POSITION;
                float2 texcoord : TEXCOORD0;
                float3 vertexLast : TEXCOORD4;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings{
                float4 position : SV_POSITION;
                //float3 positionWorld : VAR_POSITION;
                float2 uv : TEXCOORD0;
                float4 transferPos : TEXCOORD1;
                float4 transferPosOld : TEXCOORD2;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            Varyings MotionVectorVertex(Attributes i) {

                Varyings o;

                o.position = TransformObjectToHClip(i.vertex);
                //o.positionWorld = TransformObjectToWorld(i.vertex);
                o.uv = i.texcoord;

            #if UNITY_REVERSED_Z
                o.position.z -= unity_MotionVectorsParams.z * o.position.w;
            #else
                o.position.z += unity_MotionVectorsParams.z * o.position.w;
            #endif

                //o.transferPos = mul(UNITY_MATRIX_UNJITTERED_VP, mul(GetObjectToWorldMatrix(), float4(i.vertex.xyz, 1.0f)));
                o.transferPos = mul(UNITY_MATRIX_PREV_VP, mul(GetObjectToWorldMatrix(), float4(i.vertex.xyz, 1.0f)));
                if (unity_MotionVectorsParams.x > 0.0f) {
                    o.transferPosOld = mul(UNITY_MATRIX_PREV_VP, mul(unity_MatrixPreviousM, float4(i.vertexLast.xyz, 1.0f)));
                }
                else {
                    o.transferPosOld = mul(UNITY_MATRIX_PREV_VP, mul(unity_MatrixPreviousM, float4(i.vertex.xyz, 1.0f)));
                }

                return o;

            }

            float2 MotionVectorFragment(Varyings i) : SV_TARGET{
                /*
                float3 screenPos = (i.transferPos.xyz / i.transferPos.w) * 0.5f + 0.5f - float3(JitterParams.x, JitterParams.y, 0.0f);
                float3 screenPosOld = (i.transferPosOld.xyz / i.transferPosOld.w) * 0.5f + 0.5f - float3(JitterParams.z, JitterParams.w, 0.0f);
                float2 motionVector = screenPos - screenPosOld;
                */

                float3 ndcPos = i.transferPos.xyz / i.transferPos.w;
                float3 ndcPosOld = i.transferPosOld.xyz / i.transferPosOld.w;
                float2 motionVector = ndcPos - ndcPosOld;
                
                #if UNITY_UV_STARTS_AT_TOP
                motionVector.y -= motionVector.y;
                #endif
                if (unity_MotionVectorsParams.y == 0.0f) {
                    return float2(1.0f, 0.0f);
                }
                return motionVector * 0.25f + 0.5f; //这里direct和opengl可以共用
                //return motionVector * 0.5f;
                //return unity_MotionVectorsParams.x == 0.0f ? 1.0f : 0.0f;

            }

        ENDHLSL

        Pass{
            

            Tags{
                "RenderPipeline" = "UniversalPipeline"
                "LightMode" = "MotionVectors"
            }

            HLSLPROGRAM
                #pragma exclude_renderers d3d11_9x gles
                #pragma target 3.5
                #pragma vertex MotionVectorVertex;
                #pragma fragment MotionVectorFragment;
            ENDHLSL

            }

    }
}
