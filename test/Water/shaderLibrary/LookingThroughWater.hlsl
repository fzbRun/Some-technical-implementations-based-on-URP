#ifndef _LOOKING_THROUGH_WATER_INCLUDED
#define _LOOKING_THROUGH_WATER_INCLUDED

TEXTURE2D(_CameraDepthTexture);
SAMPLER(sampler_CameraDepthTexture);
float4 _CameraDepthTexture_TexelSize;

float3 ColorBelowWater(float4 clipPos) {

	float2 uv = clipPos.xy / clipPos.w;
	uv = uv * 0.5f + 0.5f;
	#if UNITY_UV_STARTS_AT_TOP
	uv.y = 1.0f - uv.y;
	#endif

	float backgroundDepth = LinearEyeDepth(SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uv), _ZBufferParams);
	float surfaceDepth = UNITY_Z_0_FAR_FROM_CLIPSPACE(clipPos.z);
	float depthDifference = backgroundDepth - surfaceDepth;

	return depthDifference/ 20.0f;

}

#endif