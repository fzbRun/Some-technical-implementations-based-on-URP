Shader "PBR/HDRP_PBR"
{
    Properties
    {
        _AlbedoMap("Albedo Map", 2D) = "white"{}
        _Albedo("Albedo", Color) = (1.0, 1.0, 1.0, 1.0)

        [Toggle(_DETAIL_MAP)] _DETAIL_MAP("Detail", Float) = 0.0
        _DetailMap("Detail Map", 2D) = "white"{}
        [Toggle(_MASK_MAP)] _MASK_MAP("Mask", Float) = 0.0
        _MaskMap("Mask Map", 2D) = "white"{}

        _Metallic("Metallic", Range(0.0, 1.0)) = 0.5
        _MetallcRemapMin("Metallic Remap Min", Range(0.0, 0.5)) = 0.0
        _MetallcRemapMax("Metallic Remap Max", Range(0.5, 1.0)) = 0.0

        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5
        _SmoothnessRemapMin("Smootness Remap Min", Range(0.0, 0.5)) = 0.0
        _SmoothnessRemapMax("Smootness Remap Max", Range(0.5, 1.0)) = 1.0
        _DetailSmoothnessScale("Detail Smoothness Scale", Range(0.0, 1.0)) = 1.0

        [Toggle(_SPECULAR_MAP)]_SPECULAR_MAP("Specular", Float) = 0.0
        _SpecularMap("Specular Map", 2D) = "white"{}
        _SpecularColor("Specular Color", Color) = (1.0, 1.0, 1.0, 1.0)

        [Toggle(_NORMAL_MAP)]_NORMAL_MAP("Normal", Float) = 0.0
        _NormalMap("Normal Map", 2D) = "bump"{}
        _NormalScale("Normal Scale", Range(0.0, 1.0)) = 1.0

        [Toggle(_TANGENT_MAP)] _TANGENT_MAP("Tangent", Float) = 0.0
        _TangentMap("Tangent Map", 2D) = "bump"{}

        _AORemapMin("AO Remap Min", Range(0.0, 0.5)) = 0.0
        _AORemapMax("AO Remap Max", Range(0.5, 1.0)) = 0.5
        _EmissiveColor("Emissive Color", Color) = (0.0, 0.0, 0.0, 0.0)
        _AlbedoAffectEmissive("Albedo Affect Emissive", Range(0.0, 1.0)) = 0.5

    }
    SubShader
    {
         HLSLINCLUDE

           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
           #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
           //#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Sampling/SampleUVMapping.hlsl"
           #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"

            #include "Data/input.hlsl"
            #include "Data/StructData.hlsl"
            #include "Data/getData.hlsl"
            #include "Data/transformFunction.hlsl"

            Varyings vert(Attributes i) {

                Varyings o = transformFromAToV(i);

                return o;

            }

            float4 frag(Varyings i) : SV_TARGET{

                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                
                FragInput fragInput = transformFromVToF(i);
                
                //FPTL的内容，后面实现再添加

                float3 V = normalize(GetCameraPositionWS() - i.positionWS);

                SurfaceDataHDRP surfaceData;
                BuiltinData builtinData;
                GetSurfaceAndBuiltinData(fragInput, V, surfaceData);//, builtinData);

                BSDFDataHDRP bsdfData = ConvertSurfaceDataToBSDFData(fragInput.positionSS.xy, surfaceData);
                PreLightData preLightData = GetPreLightData(V, bsdfData);

                Light light = GetMainLight();
                float3 color = preLightData.diffuseFGD * bsdfData.diffuseColor * light.color + preLightData.specularFGD * bsdfData.specularColor;
                color *= saturate(dot(light.direction, surfaceData.normalWS));

                return float4(color, 1.0f);

            }

        ENDHLSL


        Pass{

            Tags{
                "RenderPipeline" = "UniversalPipeline"
            }

            HLSLPROGRAM
                #pragma shader_feature_local _NORMAL_MAP
                #pragma shader_feature_local _DETAIL_MAP
                #pragma shader_feature_local _MASK_MAP
                #pragma shader_feature_local _TANGENT_MAP
                #pragma shader_feature_local _SPECULAR_MAP
                #pragma vertex vert;
                #pragma fragment frag;
            ENDHLSL

        }
    }
}
