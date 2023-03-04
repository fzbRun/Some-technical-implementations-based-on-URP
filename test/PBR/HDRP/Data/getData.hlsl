#ifndef GET_DATA_INCLUDED
#define GET_DATA_INCLUDED

float3x3 BuildTangentToWorld(float4 tangentWS, float3 normalWS)
{

    float3 unnormalizedNormalWS = normalWS;
    float renormFactor = 1.0 / max(FLT_MIN, length(unnormalizedNormalWS));

    real3 bitangent = cross(normalWS, tangentWS.xyz) * tangentWS.w;
    real3x3 tangentToWorld = real3x3(tangentWS.xyz, bitangent, normalWS);

    tangentToWorld[0] = tangentToWorld[0] * renormFactor;
    tangentToWorld[1] = tangentToWorld[1] * renormFactor;
    tangentToWorld[2] = tangentToWorld[2] * renormFactor;
    /*
    tangentToWorld[0] = normalize(tangentToWorld[0]);
    tangentToWorld[1] = normalize(tangentToWorld[1]);
    tangentToWorld[2] = normalize(tangentToWorld[2]);
    */
    return tangentToWorld;
}

float3 DecodeNormal(float4 sample, float scale) {
#if defined(UNITY_NO_DXT5nm)
    return UnpackNormalRGB(sample, scale);
#else
    return UnpackNormalmapRGorAG(sample, scale);
#endif
}

float3 BlendNormalRNW(float3 n1, float3 n2) {
    float3 t = n1 + float3(0.0f, 0.0f, 1.0f);
    float3 u = n2 + float3(-1.0f, -1.0f, 1.0f);
    float3 r = (t / t.z) * dot(t, u) - u;
    return r;
}
//��ñ�����Ϣ
float3 GetNormalTS(FragInput input, float3 detailNormalTS, float detailMask) {

    float3 normalTS = 0.0f;

#ifdef _NORMAL_MAP
    float4 normalMap = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv);
    normalTS = DecodeNormal(normalMap, _NormalScale);

    #ifdef _DETAIL_MAP
    normalTS = lerp(normalTS, BlendNormalRNW(normalTS, normalize(detailNormalTS)), detailMask); //��Ԫ����ת���
    #endif
#else
    #ifdef _DETAIL_MAP
    normalTS = lerp(normalTS, BlendNormalRNM(normalTS, detailNormalTS), detailMask);    //û�з���ֱ�Ӿ���0���ϸ�ڷ���
    #endif
#endif
    return normalTS;
}

//ϸ��������r�Ƿ�����ǿ�ȣ�ga�Ƿ��ߵ�xy����ͨ��xy�Ƴ�z��b�ǹ⻬ǿ��
//Mask������r�ǽ���ֵǿ�ȣ�g�ǻ������ڱΣ�b��ϸ��ǿ�ȣ�a�ǹ⻬��
float GetSurfaceData(FragInput input, out SurfaceDataHDRP surfaceData, out float3 normalTS) {

    float3 detailNormalTS = 0.0f;
    float detailMask = 0.0f;
#ifdef _DETAIL_MAP
    detailMask = 1.0f;
    #ifdef _MASKMAP
    detailMask = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv).b;
    #endif
    float2 detailAlbedoAndSmoothness = SAMPLE_TEXTURE2D(_DetailMap, sampler_DetailMap, input.uv).rb;
    float detailAlbedo = detailAlbedoAndSmoothness.r * 2.0f - 1.0f; //������ǿ��
    float detailSmoothness = detailAlbedoAndSmoothness.g * 2.0f - 1.0f;
    float4 detailNormalMap = SAMPLE_TEXTURE2D(_DetailMap, sampler_DetailMap, input.uv);
    detailNormalTS = DecodeNormal(detailNormalMap, _DetailNormalScale);
#endif

    float4 color = SAMPLE_TEXTURE2D(_AlbedoMap, sampler_AlbedoMap, input.uv) * _Albedo;
    surfaceData.baseColor = color.rgb;
    float alpha = color.a;

#ifdef _DETAIL_MAP
    //��ϸ������Է����ʽ��в�ֵ
    float albeDetailSpeed = saturate(abs(detailAlbedo) * _DetailAlbedoSacle);
    float3 baseColorOverlay = lerp(sqrt(surfaceData.baseColor), detailAlbedo < 0.0f ? float3(0.0f, 0.0f, 0.0f) : float3(1.0f, 1.0f, 1.0f), albeDetailSpeed * albeDetailSpeed);
    baseColorOverlay *= baseColorOverlay;
    surfaceData.baseColor = lerp(surfaceData.baseColor, saturate(baseColorOverlay), detailMask);
#endif

    surfaceData.specularOcclusion = 1.0f;

    surfaceData.normalWS = 0.0f;
    normalTS = GetNormalTS(input, detailNormalTS, detailMask);

#ifdef _MASK_MAP
    surfaceData.perceptualSmoothness = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv).a;
    surfaceData.perceptualSmoothness = lerp(_SmoothnessRemapMin, _SmoothnessRemapMax, surfaceData.perceptualSmoothness);
#else
    surfaceData.perceptualSmoothness = _Smoothness;
#endif

#ifdef _DETAIL_MAP
    //�ͷ�����һ����������gamma�ռ���
    float smoothnessDetailSpeed = saturate(abs(detailSmoothness) * _DetailSmoothnessScale);
    float smoothnessOverlay = lerp(surfaceData.perceptualSmoothness, detailSmoothness < 0.0f ? 0.0f : 1.0f, smoothnessDetailSpeed);
    surfaceData.perceptualSmoothness = lerp(surfaceData.perceptualSmoothness, saturate(smoothnessOverlay), detailMask);
#endif

#ifdef _MASK_MAP
    surfaceData.metallic = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv).r;
    surfaceData.metallic = lerp(_MetallicRemapMin, _MetallicRemapMax, surfaceData.metallic);
    surfaceData.ambientOcclusion = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv).g;
    surfaceData.ambientOcclusion = lerp(_AORemapMin, _AORemapMax, surfaceData.ambientOcclusion);
#else
    surfaceData.metallic = _Metallic;
    surfaceData.ambientOcclusion = 1.0f;
#endif

#ifdef _TANGENTM_MAP    //�������߲�û�й�һ�����������ٹ�һ��
    float3 tangentTS = SAMPLE_TEXTURE2D(_TangentMap, sampler_TangentMap, input.uv);
    surfaceData.tangentWS = TransformTangentToWorld(tangentTS, input.TBN);
#else
    surfaceData.tangentWS = input.TBN[0];
#endif

    surfaceData.specularColor = _SpecularColor.rgb;
#ifdef _SPECULARCOLOR_MAP
    surfaceData.specularColor *= SAMPLE_TEXTURE2D(_SpecularColorMap, sampler_SpecularColorMap, input.uv).rgb;
#endif
    //surfaceData.baseColor *= 1.0f - Max3(surfaceData.specularColor.r, surfaceData.specularColor.g, surfaceData.specularColor.b);

    return alpha;

}

/*
void InitBuiltinData(float alpha, float3 normalWS, float3 backNormalWS, float3 positionWS, float2 uv, BuiltinData builtinData) {
    
    builtinData.opacity = alpha;

    //builtinData.backDiffuseLighting = SampleBakedGI(positionWS, normalWS,)

}

void GetBuiltinData(FragInput input, float3 V, SurfaceDataHDRP surfaceData, float alpha, float3 normalWS, out BuiltinData builtinData) {

    float3 emissiveColor = _EmissiveColor * lerp(float3(1.0f, 1.0f, 1.0f), surfaceData.baseColor, _AlbedoAffectEmissive);
#ifdef _EMISSIVE_COLOR_MAP
    emissiveColor *= SAMPLE_TEXTURE2D(_EmissiveColorMap, sampler_EmissiveColorMap, input.uv).rgb;
#endif

    //ȫ�ֹ��ȷ�һ��
    //InitBuiltinData(alpha. normalWS, -input.TBN[2], )

}
*/

void GetSurfaceAndBuiltinData(FragInput input, float3 V, out SurfaceDataHDRP surfaceData){//, out BuiltinData builtinData) {

    //������ָ�����UV
    //LayerTexCoord layerTexCoord;
    //GetLayerTexCoord(input, layerTexCoord);

    float3 normalTS;
    //float3 bentNormalTS;
    float3 bentNormalWS;
    float alpha = GetSurfaceData(input, surfaceData, normalTS);

#ifdef _NORMAL_MAP
    surfaceData.normalWS = TransformTangentToWorld(normalTS, input.TBN);    //TBN���аڷţ�����Ҫ�ҳ�
#else
    surfaceData.normalWS = input.TBN[2];
#endif

    surfaceData.specularOcclusion = GetSpecularOcclusionFromAmbientOcclusion(saturate(dot(surfaceData.normalWS, V)), surfaceData.ambientOcclusion, PerceptualSmoothnessToRoughness(surfaceData.perceptualSmoothness));

    //���ｫ����תΪ�����ߣ����ڸ������ԵĲ���
    surfaceData.tangentWS = Orthonormalize(surfaceData.tangentWS, surfaceData.normalWS);

    //specualr AA���޸Ĺ⻬��
    

    //ȫ�ֹ���
    //GetBuiltinData(input, V, surfaceData, alpha, surfaceData.normalWS, builtinData);

}

void GetPreIntegratedFGDGGXAndDisneyDiffuse(float3 N, float3 V, float perceptualRoughness, float3 fresnel0, out float3 specualrFGD, out float diffuseFGD, out float reflectivity) {

    //������Ԥ����LUT��������ֱ�Ӳ���������learnOpengl�е�����
    //�ȷ�һ�ߣ�֮��ʵ��,��ʵ��һ���򵥵�
    Light light = GetMainLight();
    float3 L = normalize(light.direction);
    float3 H = normalize(normalize(L) + normalize(V));
    float NdotH = saturate(dot(N, H));
    float LdotH = saturate(dot(L, H));
    float roughness4 = perceptualRoughness * perceptualRoughness * perceptualRoughness * perceptualRoughness;
    specualrFGD = roughness4 / (4.0f * PI * (NdotH * NdotH * (roughness4 - 1.0f) + 1.0f) * (NdotH * NdotH * (roughness4 - 1.0f) + 1.0f) * LdotH * LdotH * (perceptualRoughness + 0.5f));
    diffuseFGD = (1.0f - fresnel0);
    reflectivity = fresnel0;

}

PreLightData GetPreLightData(float3 V, BSDFDataHDRP bsdfData) {

    PreLightData preLightData;

    float3 N = bsdfData.normalWS;
    preLightData.NdotV = dot(N, V);
    float clampedNdotV = saturate(preLightData.NdotV);

    preLightData.iblPerceptualRoughness = bsdfData.perceptualRoughness;

    float specualrReflectivity;
    //GetPreIntegratedFGDGGXAndDisneyDiffuse(clampedNdotV, preLightData.iblPerceptualRoughness, bsdfData.fresnel0, preLightData.specularFGD, preLightData.diffuseFGD, specularReflectivity);
    GetPreIntegratedFGDGGXAndDisneyDiffuse(N, V, preLightData.iblPerceptualRoughness, bsdfData.fresnel0, preLightData.specularFGD, preLightData.diffuseFGD, specualrReflectivity);

    preLightData.iblR = reflect(-V, N);
    return preLightData;
}

#endif