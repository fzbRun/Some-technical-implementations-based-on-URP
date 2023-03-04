using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using System;

namespace UnityEngine.Rendering.Universal
{
    [Serializable]
    internal class HBAOSettings
    {

        [SerializeField] internal bool Downsample = false;
        //[SerializeField] internal bool AfterOpaque = false;
        [SerializeField] internal DepthSource Source = DepthSource.Depth;
        [SerializeField] internal NormalQuality NormalSamples = NormalQuality.Medium;
        [SerializeField] internal float Intensity = 3.0f;
        [SerializeField] internal float DirectLightingStrength = 0.25f;
        [SerializeField] internal float Radius = 1.0f;
        [SerializeField] internal int SampleCount = 4;

        internal enum DepthSource
        {
            Depth = 0,
            DepthNormals = 1
        }

        internal enum NormalQuality
        {
            Low,
            Medium,
            High
        }

    }

    [System.Serializable]
    internal class HBAO : ScriptableRendererFeature
    {

        [SerializeField] public HBAOSettings hbaoSettings;
        [SerializeField, HideInInspector] Shader hbaoShader;
        [SerializeField] Material hbaoMaterial;
        [SerializeField] HBAOPass hbaoPass = null;

        private const string hbaoShaderPath = "test/HBAO";
        private const string isOrthoCameraKeyword = "_ORTHOGRAPHIC";
        private const string NormalReconstructionLowKeyword = "_RECONSTRUCT_NORMAL_LOW";
        private const string NormalReconstructionMediumKeyword = "_RECONSTRUCT_NORMAL_MEDIUM";
        private const string NormalReconstructionHighKeyword = "_RECONSTRUCT_NORMAL_HIGH";
        private const string SourceDepthKeyword = "_SOURCE_DEPTH";
        private const string SourceDepthNormalsKeyword = "_SOURCE_DEPTH_NORMALS";

        //internal bool afterOpaque => hbaoSettings.AfterOpaque;

        private bool GetMaterial()
        {
            if (hbaoMaterial != null)
            {
                return true;
            }

            if (hbaoShader == null)
            {
                hbaoShader = Shader.Find(hbaoShaderPath);
                if (hbaoShader == null)
                {
                    return false;
                }
            }

            hbaoMaterial = CoreUtils.CreateEngineMaterial(hbaoShader);

            return hbaoMaterial != null;
        }

        protected override void Dispose(bool disposing)
        {
            CoreUtils.Destroy(hbaoMaterial);
        }

        class HBAOPass : ScriptableRenderPass
        {
            private const string HBAOTextureName = "_ScreenSpaceOcclusionTexture";
            private const string HBAOAmbientOcclusionParamName = "_AmbientOcclusionParam";

            static int baseTextureID = Shader.PropertyToID("_BaseMap");
            static int HBAOTextureID = Shader.PropertyToID("_HBAOTexture");
            static int HBAOHTextureID = Shader.PropertyToID("_HBAOHTexture");
            static int HBAOVTextureID = Shader.PropertyToID("_HBAOVTexture");
            static int HBAOFinalTextureID = Shader.PropertyToID("_HBAOFinalTexture");

            static int hbaoParams = Shader.PropertyToID("_SSAOParams");
            static int dirsID = Shader.PropertyToID("_Dirs");
            static int CameraViewXExtentID = Shader.PropertyToID("_CameraViewXExtent");
            static int CameraViewYExtentID = Shader.PropertyToID("_CameraViewYExtent");
            static int CameraViewZExtentID = Shader.PropertyToID("_CameraViewZExtent");
            static int ProjectionParams2ID = Shader.PropertyToID("_ProjectionParams2");
            static int CameraProjectionsID = Shader.PropertyToID("_CameraProjections");
            static int CameraViewTopLeftCornerID = Shader.PropertyToID("_CameraViewTopLeftCorner");

            public HBAOSettings hbaoSettings;
            public ScriptableRenderer renderer;
            public Material hbaoMaterial;

            private bool SupportsR8RenderTextureFormat = SystemInfo.SupportsRenderTextureFormat(RenderTextureFormat.R8);
            private Vector4[] dirs = new Vector4[4]
            {
                new Vector4(0.0f, 1.0f), new Vector4(1.0f, 0.0f), new Vector4(0.0f, -1.0f), new Vector4(-1.0f, 0.0f)
            };
            private Vector4[] CameraTopLeftCorner = new Vector4[2];
            private Vector4[] CameraXExtent = new Vector4[2];
            private Vector4[] CameraYExtent = new Vector4[2];
            private Vector4[] CameraZExtent = new Vector4[2];
            private Matrix4x4[] CameraProjections = new Matrix4x4[2];
            private RenderTargetIdentifier HBAOTextureTarget = new RenderTargetIdentifier(HBAOTextureID, 0, CubemapFace.Unknown, -1);
            private RenderTargetIdentifier HBAOHTextureTarget = new RenderTargetIdentifier(HBAOHTextureID, 0, CubemapFace.Unknown, -1);
            private RenderTargetIdentifier HBAOVTextureTarget = new RenderTargetIdentifier(HBAOVTextureID, 0, CubemapFace.Unknown, -1);
            private RenderTargetIdentifier HBAOFinalTextureTarget = new RenderTargetIdentifier(HBAOFinalTextureID, 0, CubemapFace.Unknown, -1);
            private RenderTextureDescriptor AOPassDescriptor;
            private RenderTextureDescriptor BlurPassesDescriptor;
            private RenderTextureDescriptor FinalDescriptor;

            private enum ShaderPasses
            {
                AO = 0,
                BlurHorizontal = 1,
                BlurVertical = 2,
                BlurFinal = 3,
                AfterOpaque = 4
            }

            public bool Setup(HBAOSettings hbaoSettings, ScriptableRenderer renderer, Material hbaoMaterial)
            {

                this.hbaoSettings = hbaoSettings;
                this.renderer = renderer;
                this.hbaoMaterial = hbaoMaterial;

                HBAOSettings.DepthSource source = hbaoSettings.Source;
                renderPassEvent = RenderPassEvent.AfterRenderingOpaques;

                switch (source) {

                    case HBAOSettings.DepthSource.Depth:
                        ConfigureInput(ScriptableRenderPassInput.Depth);    //就是告诉Unity需要先执行哪些Pass
                        break;
                    case HBAOSettings.DepthSource.DepthNormals:
                        ConfigureInput(ScriptableRenderPassInput.Normal);   //这个是深度法线
                        break;
                    default:
                        throw new ArgumentOutOfRangeException();
                }

                return hbaoMaterial != null && hbaoSettings.Intensity > 0.0f && hbaoSettings.Radius > 0.0f && hbaoSettings.SampleCount > 0.0f;

            }

            public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
            {

                RenderTextureDescriptor cameraTargetDescriptor = renderingData.cameraData.cameraTargetDescriptor;
                int downsampleDivider = hbaoSettings.Downsample ? 2 : 1;

                Vector4 ssaoParams = new Vector4(
                    hbaoSettings.Intensity,   // Intensity
                    hbaoSettings.Radius,      // Radius
                    1.0f / downsampleDivider,      // Downsampling
                    hbaoSettings.SampleCount  // Sample count
                );
                hbaoMaterial.SetVector(hbaoParams, ssaoParams);

                hbaoMaterial.SetVectorArray(dirsID, dirs);

#if ENABLE_VR && ENABLE_XR_MODULE
                int eyeCount = renderingData.cameraData.xr.enabled && renderingData.cameraData.xr.singlePassEnabled ? 2 : 1;
#else
                int eyeCount = 1;
#endif

                for(int eyeIndex = 0; eyeIndex < eyeCount; eyeIndex++)
                {
                    Matrix4x4 view = renderingData.cameraData.GetViewMatrix(eyeIndex);
                    Matrix4x4 proj = renderingData.cameraData.GetProjectionMatrix(eyeIndex);
                    CameraProjections[eyeIndex] = proj.inverse;

                    // camera view space without translation, used by SSAO.hlsl ReconstructViewPos() to calculate view vector.
                    Matrix4x4 cview = view;
                    cview.SetColumn(3, new Vector4(0.0f, 0.0f, 0.0f, 1.0f));
                    Matrix4x4 cviewProj = proj * cview;
                    Matrix4x4 cviewProjInv = cviewProj.inverse;

                    Vector4 topLeftCorner = cviewProjInv.MultiplyPoint(new Vector4(-1, 1, -1, 1));
                    Vector4 topRightCorner = cviewProjInv.MultiplyPoint(new Vector4(1, 1, -1, 1));
                    Vector4 bottomLeftCorner = cviewProjInv.MultiplyPoint(new Vector4(-1, -1, -1, 1));
                    Vector4 farCentre = cviewProjInv.MultiplyPoint(new Vector4(0, 0, 1, 1));
                    CameraTopLeftCorner[eyeIndex] = topLeftCorner;  //世界空间
                    CameraXExtent[eyeIndex] = topRightCorner - topLeftCorner;
                    CameraYExtent[eyeIndex] = bottomLeftCorner - topLeftCorner;
                    CameraZExtent[eyeIndex] = farCentre;
                }

                hbaoMaterial.SetVector(ProjectionParams2ID, new Vector4(1.0f / renderingData.cameraData.camera.nearClipPlane, 0.0f, 0.0f, 0.0f));
                hbaoMaterial.SetMatrixArray(CameraProjectionsID, CameraProjections);
                hbaoMaterial.SetVectorArray(CameraViewTopLeftCornerID, CameraTopLeftCorner);
                hbaoMaterial.SetVectorArray(CameraViewXExtentID, CameraXExtent);
                hbaoMaterial.SetVectorArray(CameraViewYExtentID, CameraYExtent);
                hbaoMaterial.SetVectorArray(CameraViewZExtentID, CameraZExtent);

                CoreUtils.SetKeyword(hbaoMaterial, isOrthoCameraKeyword, renderingData.cameraData.camera.orthographic);

                HBAOSettings.DepthSource source = hbaoSettings.Source;
                if (source == HBAOSettings.DepthSource.Depth)
                {
                    switch (hbaoSettings.NormalSamples)
                    {
                        case HBAOSettings.NormalQuality.Low:
                            CoreUtils.SetKeyword(hbaoMaterial, NormalReconstructionLowKeyword, true);
                            CoreUtils.SetKeyword(hbaoMaterial, NormalReconstructionMediumKeyword, false);
                            CoreUtils.SetKeyword(hbaoMaterial, NormalReconstructionHighKeyword, false);
                            break;
                        case HBAOSettings.NormalQuality.Medium:
                            CoreUtils.SetKeyword(hbaoMaterial, NormalReconstructionLowKeyword, false);
                            CoreUtils.SetKeyword(hbaoMaterial, NormalReconstructionMediumKeyword, true);
                            CoreUtils.SetKeyword(hbaoMaterial, NormalReconstructionHighKeyword, false);
                            break;
                        case HBAOSettings.NormalQuality.High:
                            CoreUtils.SetKeyword(hbaoMaterial, NormalReconstructionLowKeyword, false);
                            CoreUtils.SetKeyword(hbaoMaterial, NormalReconstructionMediumKeyword, false);
                            CoreUtils.SetKeyword(hbaoMaterial, NormalReconstructionHighKeyword, true);
                            break;
                        default:
                            throw new ArgumentOutOfRangeException();
                    }
                }

                switch (source)
                {
                    case HBAOSettings.DepthSource.DepthNormals:
                        CoreUtils.SetKeyword(hbaoMaterial, SourceDepthKeyword, false);
                        CoreUtils.SetKeyword(hbaoMaterial, SourceDepthNormalsKeyword, true);
                        break;
                    default:
                        CoreUtils.SetKeyword(hbaoMaterial, SourceDepthKeyword, true);
                        CoreUtils.SetKeyword(hbaoMaterial, SourceDepthNormalsKeyword, false);
                        break;
                }

                RenderTextureDescriptor descriptor = cameraTargetDescriptor;
                descriptor.msaaSamples = 1;
                descriptor.depthBufferBits = 0;

                AOPassDescriptor = descriptor;
                AOPassDescriptor.width /= downsampleDivider;
                AOPassDescriptor.height /= downsampleDivider;
                AOPassDescriptor.colorFormat = RenderTextureFormat.ARGB32;

                BlurPassesDescriptor = descriptor;
                BlurPassesDescriptor.colorFormat = RenderTextureFormat.ARGB32;

                FinalDescriptor = descriptor;
                FinalDescriptor.colorFormat = SupportsR8RenderTextureFormat ? RenderTextureFormat.R8 : RenderTextureFormat.ARGB32;

                // Get temporary render textures
                cmd.GetTemporaryRT(HBAOTextureID, AOPassDescriptor, FilterMode.Bilinear);
                cmd.GetTemporaryRT(HBAOHTextureID, BlurPassesDescriptor, FilterMode.Bilinear);
                cmd.GetTemporaryRT(HBAOVTextureID, BlurPassesDescriptor, FilterMode.Bilinear);
                cmd.GetTemporaryRT(HBAOFinalTextureID, FinalDescriptor, FilterMode.Bilinear);

                // Configure targets and clear color
                ConfigureTarget(renderer.cameraColorTarget);
                ConfigureClear(ClearFlag.None, Color.white);

            }

            private void Render(CommandBuffer cmd, RenderTargetIdentifier target, ShaderPasses pass)
            {
                cmd.SetRenderTarget(
                    target,
                    RenderBufferLoadAction.DontCare,
                    RenderBufferStoreAction.Store,
                    target,
                    RenderBufferLoadAction.DontCare,
                    RenderBufferStoreAction.DontCare
                );
                cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, hbaoMaterial, 0, (int)pass);
            }

            private void RenderAndSetBaseMap(CommandBuffer cmd, RenderTargetIdentifier baseMap, RenderTargetIdentifier target, ShaderPasses pass)
            {
                cmd.SetGlobalTexture(baseTextureID, baseMap);
                Render(cmd, target, pass);
            }

            public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
            {
                if (hbaoMaterial == null)
                {
                    Debug.LogErrorFormat("{0}.Execute(): Missing material. ScreenSpaceAmbientOcclusion pass will not execute. Check for missing reference in the renderer resources.", GetType().Name);
                    return;
                }
                CommandBuffer cmd = CommandBufferPool.Get();
                cmd.name = "HBAO";

                Vector4 scaleBiasRt = new Vector4(-1, 1.0f, -1.0f, 1.0f);
                cmd.SetGlobalVector(Shader.PropertyToID("_ScaleBiasRt"), scaleBiasRt);
                
                hbaoMaterial.SetVector(Shader.PropertyToID("_SourceSize"), new Vector4(AOPassDescriptor.width, AOPassDescriptor.height,
                    1.0f / AOPassDescriptor.width, 1.0f / AOPassDescriptor.height));

                Render(cmd, HBAOTextureTarget, ShaderPasses.AO);

                RenderAndSetBaseMap(cmd, HBAOTextureTarget, HBAOHTextureTarget, ShaderPasses.BlurHorizontal);
                hbaoMaterial.SetVector(Shader.PropertyToID("_SourceSize"), new Vector4(BlurPassesDescriptor.width, BlurPassesDescriptor.height,
1.0f / BlurPassesDescriptor.width, 1.0f / BlurPassesDescriptor.height));
                RenderAndSetBaseMap(cmd, HBAOHTextureTarget, HBAOVTextureTarget, ShaderPasses.BlurVertical);
                RenderAndSetBaseMap(cmd, HBAOVTextureTarget, HBAOFinalTextureTarget, ShaderPasses.BlurFinal);

                cmd.SetGlobalTexture(HBAOTextureName, HBAOFinalTextureTarget);
                cmd.SetGlobalVector(HBAOAmbientOcclusionParamName, new Vector4(0f, 0f, 0f, hbaoSettings.DirectLightingStrength));

                CameraData cameraData = renderingData.cameraData;
                bool isCameraColorFinalTarget = (cameraData.cameraType == CameraType.Game && 
                    renderer.cameraColorTarget == BuiltinRenderTextureType.CameraTarget && 
                    cameraData.camera.targetTexture == null);

                bool yflip = !isCameraColorFinalTarget;
                float flipSign = yflip ? -1.0f : 1.0f;
                scaleBiasRt = (flipSign < 0.0f)
                    ? new Vector4(flipSign, 1.0f, -1.0f, 1.0f)
                    : new Vector4(flipSign, 0.0f, 1.0f, 1.0f);
                cmd.SetGlobalVector(Shader.PropertyToID("_ScaleBiasRt"), scaleBiasRt);

                // This implicitly also bind depth attachment. Explicitly binding m_Renderer.cameraDepthTarget does not work.
                cmd.SetRenderTarget(
                    renderer.cameraColorTarget,
                    RenderBufferLoadAction.Load,
                    RenderBufferStoreAction.Store
                );
                cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, hbaoMaterial, 0, (int)ShaderPasses.AfterOpaque);

                context.ExecuteCommandBuffer(cmd);
                CommandBufferPool.Release(cmd);

            }

            public override void OnCameraCleanup(CommandBuffer cmd)
            {
                if (cmd == null)
                {
                    throw new ArgumentNullException("cmd");
                }

                cmd.ReleaseTemporaryRT(HBAOTextureID);
                cmd.ReleaseTemporaryRT(HBAOHTextureID);
                cmd.ReleaseTemporaryRT(HBAOVTextureID);
                cmd.ReleaseTemporaryRT(HBAOFinalTextureID);
            }
        }

        public override void Create()
        {
            // Create the pass...
            if (hbaoPass == null)
            {
                hbaoPass = new HBAOPass();
            }

            GetMaterial();
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            if (!GetMaterial())
            {
                Debug.LogErrorFormat(
                    "{0}.AddRenderPasses(): Missing material. {1} render pass will not be added. Check for missing reference in the renderer resources.",
                    GetType().Name, name);
                return;
            }

            bool shouldAdd = hbaoPass.Setup(hbaoSettings, renderer, hbaoMaterial);
            if (shouldAdd)
            {
                renderer.EnqueuePass(hbaoPass);
            }
        }
    }
}


