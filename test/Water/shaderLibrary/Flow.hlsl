#ifndef FLOW_INCLUDED
#define FLOW_INCLIDED

float3 FlowUVW(float2 uv, float time, float2 flowVector, bool flowB, float2 jump, float tiling, float flowOffset) {
	float3 uvw;
	float phaseOffset = flowB ? 0.5f : 0.0f;
	float2 progress = frac(time + phaseOffset);
	uvw.xy = uv - flowVector * (progress + flowOffset);
	uvw.xy *= tiling;
	uvw.xy += phaseOffset;
	uvw.xy += (time - progress) * jump;
	uvw.z = 1.0f - abs(1.0f - 2.0f * progress);
	return uvw;
}

float2 DirectionalFlowUV(float2 uv, float3 flowVectorAndSpeed, float tiling, float time, out float2x2 rotation) {

	float2 dir = normalize(flowVectorAndSpeed.xy);
	rotation = float2x2(dir.y, dir.x, -dir.x, dir.y);
	uv = mul(float2x2(dir.y, -dir.x, dir.x, dir.y), uv);
	uv.y -= time * flowVectorAndSpeed.z;
	return uv * tiling;

}

#endif