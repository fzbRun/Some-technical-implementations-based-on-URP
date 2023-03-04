#ifndef LEAN_SPECULAR_AA_INCLUDED
#define LEAN_SPECULAR_AA_INCLUDED

//这里的B,M都是在切线空间算的，所以H也要变到切线空间
float LEAN_Backmann_NDF(float2 uv, float3 H, float roughness, out float3 normal) {

	float2 B = SAMPLE_TEXTURE2D(_LEANB, sampler_LEANB, uv).rg;
	float3 M = SAMPLE_TEXTURE2D(_LEANM, sampler_LEANM, uv).rgb;

	normal = normalize(float3(B.x, B.y, 1.0f));

	float s = max(0.01, (64.0f * (1.0f - roughness)));
	M += float3(1.0f / s, 1.0f / s, 0.0f);

	float3 Var = { M.x - B.x * B.x,
				   M.y - B.y * B.y,
				   M.z - B.x * B.y };
	
	float2 H_B = H.xy / H.z - B;
	float x2 = H_B.x * H_B.x;
	float y2 = H_B.y * H_B.y;
	float xy = H_B.x * H_B.y;
	float HVH = Var.y * x2 + Var.x * y2 - 2.0f * Var.z * xy;

	float NH = saturate(dot(normal, H));
	float NH4 = max(NH * NH * NH * NH, 0.000001f);

	float VarVal = sqrt(max(0.0001f, Var.x * Var.y - Var.z * Var.z));
	float e = exp(-0.5f * HVH / VarVal);

	return e / (2 * PI * sqrt(VarVal) * NH4);

	/*
	float2 H_B = H.xy / H.z - B;
	float x2 = H_B.x * H_B.x;
	float y2 = H_B.y * H_B.y;
	float xy = H_B.x * H_B.y;
	float e = Var.y * x2 + Var.x * y2 - 2.0f * Var.z * xy;
	float Det = Var.x * Var.y - Var.z * Var.z;
	return (Det <= 0.0f) ? 0.0f : exp(-0.5f * e / Det) / sqrt(Det) / 2 / PI;
	*/

}

#endif