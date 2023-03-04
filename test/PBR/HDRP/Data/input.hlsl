#ifndef INPUT_DATA_INCLUDED
#define INPUT_DATA_INCLUDED

TEXTURE2D(_AlbedoMap);
SAMPLER(sampler_AlbedoMap);
TEXTURE2D(_DetailMap);
SAMPLER(sampler_DetailMap);
TEXTURE2D(_MaskMap);
SAMPLER(sampler_MaskMap);
TEXTURE2D(_NormalMap);
SAMPLER(sampler_NormalMap);
TEXTURE2D(_TangetMap);
SAMPLER(sampler_TangetMap);
TEXTURE2D(_SpecularColorMap);
SAMPLER(sampler_SpecularColorMap);

UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
	UNITY_DEFINE_INSTANCED_PROP(float4, _Albedo)
	UNITY_DEFINE_INSTANCED_PROP(float, _Smoothness)
	UNITY_DEFINE_INSTANCED_PROP(float, _Metallic)
	UNITY_DEFINE_INSTANCED_PROP(float4, _SpecularColor)
	UNITY_DEFINE_INSTANCED_PROP(float, _DetailAlbedoSacle)
	UNITY_DEFINE_INSTANCED_PROP(float, _DetailNormalScale)
	UNITY_DEFINE_INSTANCED_PROP(float, _NormalScale)
	UNITY_DEFINE_INSTANCED_PROP(float, _SmoothnessRemapMin)
	UNITY_DEFINE_INSTANCED_PROP(float, _SmoothnessRemapMax)
	UNITY_DEFINE_INSTANCED_PROP(float, _DetailSmoothnessScale)
	UNITY_DEFINE_INSTANCED_PROP(float, _MetallicRemapMin)
	UNITY_DEFINE_INSTANCED_PROP(float, _MetallicRemapMax)
	UNITY_DEFINE_INSTANCED_PROP(float, _AORemapMin)
	UNITY_DEFINE_INSTANCED_PROP(float, _AORemapMax)
	UNITY_DEFINE_INSTANCED_PROP(float3, _EmissiveColor)
	UNITY_DEFINE_INSTANCED_PROP(float, _AlbedoAffectEmissive)
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)


#endif