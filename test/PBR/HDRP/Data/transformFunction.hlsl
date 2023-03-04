#ifndef TRANSFORM_FUNCTION_INCLUDED
#define TRANSFORM_FUNCTION_INCLUDED

Varyings transformFromAToV(Attributes i) {

    Varyings o;

    //VertMesh����,
    UNITY_SETUP_INSTANCE_ID(i);
    UNITY_TRANSFER_INSTANCE_ID(i, o);
    o.positionWS = TransformObjectToWorld(i.positionOS); //+ worldSpaceOffset
    o.positionCS = TransformWorldToHClip(o.positionWS);
    o.normalWS = TransformObjectToWorldNormal(i.normalOS);
    o.tangentWS = float4(TransformObjectToWorldDir(i.tangentOS.xyz), i.tangentOS.w);
    o.uv = i.uv;
    //PackVaryingsMeshToPS����
    UNITY_TRANSFER_INSTANCE_ID(i, o);

    return o;

}

FragInput transformFromVToF(Varyings i) {

    UNITY_SETUP_INSTANCE_ID(i);

    FragInput o;

    o.TBN = k_identity3x3;  //��λ����

    o.positionSS = i.positionCS;    //CS����������ɫ��ʱ�Ѿ���Ϊ��Ļ�ռ�����
    o.positionWS = i.positionWS;
    float4 tangentWS = float4(i.tangentWS.xyz, i.tangentWS.w > 0.0f ? 1.0f : -1.0f);
    o.TBN = BuildTangentToWorld(tangentWS, i.normalWS);
    o.uv = i.uv;

    return o;

}

BSDFDataHDRP ConvertSurfaceDataToBSDFData(uint positionSS, SurfaceDataHDRP surfaceData) {
    BSDFDataHDRP bsdfData;
    bsdfData.ambientOcclusion = surfaceData.ambientOcclusion;
    bsdfData.specularOcclusion = surfaceData.specularOcclusion;
    bsdfData.normalWS = surfaceData.normalWS;
    bsdfData.perceptualRoughness = 1.0f - surfaceData.perceptualSmoothness;
    bsdfData.tangentWS = surfaceData.tangentWS;
    bsdfData.bitangentWS = normalize(cross(bsdfData.normalWS, bsdfData.tangentWS));
    bsdfData.roughness = bsdfData.perceptualRoughness;

    bsdfData.diffuseColor = surfaceData.baseColor * (1.0f - surfaceData.metallic); //ComputeDiffuseColor();
    bsdfData.specularColor = surfaceData.specularColor;
    bsdfData.fresnel0 = lerp(DEFAULT_SPECULAR_VALUE, surfaceData.baseColor, surfaceData.metallic);

    //���������������Ĵֲڶȣ���֪����ʲô�ã������ٿ�
    //ConvertAnisotropyToRoughness

    return bsdfData;

}

#endif