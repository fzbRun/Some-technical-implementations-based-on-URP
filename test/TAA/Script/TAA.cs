using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using System;
using System.Collections.Generic;

[System.Serializable]
public class TAASettings
{
    //[SerializeField] float sampleCount = 1.0f;
    [Range(0.0f, 5.0f)] public float Jitter = 1.0f;
    [Range(0.0f, 1.0f)] public float Blend = 0.05f;

}

public class TAA : ScriptableRendererFeature
{

    [SerializeField] TAASettings taaSettings;

    class CustomRenderPass : ScriptableRenderPass
    {
        public RenderTargetIdentifier cameraTarget;
        private const string TAAshaderName = "antiAliasing/TAA";
        private const string MotionVectorshaderName = "Buffer/Motion Vector";
        private Material TAAmaterial;
        private Material MotionVectorMaterial;
        public ScriptableRenderer renderer;
        public TAASettings taaSettings;

        private Vector2[] HaltonSequence9 = new Vector2[] {
            new Vector2(0.5f, 1.0f / 3f),
            new Vector2(0.25f, 2.0f / 3f),
            new Vector2(0.75f, 1.0f / 9f),
            new Vector2(0.125f, 4.0f / 9f),
            new Vector2(0.625f, 7.0f / 9f),
            new Vector2(0.375f, 2.0f / 9f),
            new Vector2(0.875f, 5.0f / 9f),
            new Vector2(0.0625f, 8.0f / 9f),
            new Vector2(0.5625f, 1.0f / 27f),
        };
        private int index = 0;
        private RenderTexture lastFrame;
        private Camera camera;
        private Matrix4x4 unJitterMat;

        private static int lastFrameTexture = Shader.PropertyToID("_LastFrameTexture");
        //private static int unJitterVP = Shader.PropertyToID("UNITY_MATRIX_UNJITTERED_VP");
        //private static int lastUnJitterVP = Shader.PropertyToID("UNITY_MATRIX_PREV_VP");

        public void setUp(ScriptableRenderer renderer, TAASettings taaSettings, RenderTargetIdentifier cameraTarget)
        {
            this.renderer = renderer;
            this.taaSettings = taaSettings;
            this.cameraTarget = cameraTarget;
            ConfigureInput(ScriptableRenderPassInput.Motion); //添加运动矢量
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {

            if(TAAmaterial == null)
            {
                Shader shader = Shader.Find(TAAshaderName);
                if(shader == null)
                {
                    return;
                }
                TAAmaterial = CoreUtils.CreateEngineMaterial(shader);
            }
            
            if (MotionVectorMaterial == null)
            {
                Shader shader = Shader.Find(MotionVectorshaderName);
                if (shader == null)
                {
                    return;
                }
                MotionVectorMaterial = CoreUtils.CreateEngineMaterial(shader);
            }
            
            renderingData.cameraData.camera.depthTextureMode |= DepthTextureMode.MotionVectors;

            camera = renderingData.cameraData.camera;
            camera.ResetProjectionMatrix();
            Matrix4x4 pm = camera.projectionMatrix;
            unJitterMat = pm;
            Vector2 Jitter = new Vector2((HaltonSequence9[index].x * 2.0f - 1.0f) / camera.pixelWidth, (HaltonSequence9[index].y * 2.0f - 1.0f) / camera.pixelHeight);
            Jitter *= taaSettings.Jitter;
            pm.m02 -= Jitter.x;
            pm.m12 -= Jitter.y;
            camera.projectionMatrix = pm;
            index = (index + 1) % 9;

        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            /*
            if(MotionVectorMaterial == null || TAAmaterial == null)
            {
                return;
            }

            CommandBuffer cmdMV = CommandBufferPool.Get();
            cmdMV.name = "Motion Vector";

            int width = camera.pixelWidth;
            int height = camera.pixelHeight;

            int MVTexture = Shader.PropertyToID("_MotionVectorTexture");
            cmdMV.GetTemporaryRT(MVTexture, width, height, 0, FilterMode.Point, RenderTextureFormat.Default);
            cmdMV.SetRenderTarget(MVTexture, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
            cmdMV.ClearRenderTarget(true, true, Color.black);
            context.ExecuteCommandBuffer(cmdMV);

            SortingCriteria sortingCriteria = SortingCriteria.CommonOpaque;
            List<ShaderTagId> shaderTagIds = new List<ShaderTagId>()
            {
                new ShaderTagId("MotionVectors")
                //new ShaderTagId("UniversalForward"),
                //new ShaderTagId("UniversalForwardOnly")
            };
            DrawingSettings drawingSettings = CreateDrawingSettings(shaderTagIds, ref renderingData, sortingCriteria);
            //drawingSettings.overrideMaterial = MotionVectorMaterial;
            //drawingSettings.overrideMaterialPassIndex = 0;
            drawingSettings.fallbackMaterial = MotionVectorMaterial;
            drawingSettings.perObjectData |= PerObjectData.MotionVectors;

            FilteringSettings filteringSettings = new FilteringSettings(RenderQueueRange.all);

            int lastIndex = index - 1;
            if(lastIndex == -1)
            {
                lastIndex = 8;
            }
            //Shader.SetGlobalVector(Shader.PropertyToID("JitterParams"), new Vector4(HaltonSequence9[index].x / camera.pixelWidth, HaltonSequence9[index].y / camera.pixelHeight,
                //HaltonSequence9[lastIndex].x / camera.pixelWidth, HaltonSequence9[lastIndex].y / camera.pixelHeight));
            Shader.SetGlobalMatrix(lastUnJitterVP, camera.previousViewProjectionMatrix);
            Matrix4x4 vp = unJitterMat * renderingData.cameraData.GetViewMatrix();
            Shader.SetGlobalMatrix(unJitterVP, vp);

            //context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref filteringSettings);
            context.ExecuteCommandBuffer(cmdMV);
            //context.Submit();
            CommandBufferPool.Release(cmdMV);
            */
            
            if (TAAmaterial == null)
            {
                return;
            }
            

            CommandBuffer cmd = CommandBufferPool.Get();
            cmd.name = "TAA";

            int width = camera.pixelWidth;
            int height = camera.pixelHeight;

            TAAmaterial.SetFloat("_Blend", taaSettings.Blend);
            //只在第一次时执行
            if (lastFrame == null)
            {
                lastFrame = RenderTexture.GetTemporary(width, height, 0, camera.allowHDR ? RenderTextureFormat.DefaultHDR : RenderTextureFormat.Default);
                cmd.Blit(cameraTarget, lastFrame);
                TAAmaterial.SetTexture(lastFrameTexture, lastFrame);
            }
            /*
            //如果只开游戏窗口就得这样
            else if (lastFrame.width != camera.pixelWidth || lastFrame.height != camera.pixelHeight)
            {
                Debug.Log(lastFrame.width);
                Debug.Log(camera.pixelWidth);
                //本来应该相机分辨率改变时重写修改纹理大小，但是每帧都在改，导致一直创建，内存爆炸了,需要先释放
                lastFrame.Release();
                lastFrame = RenderTexture.GetTemporary(width, height, 0, camera.allowHDR ? RenderTextureFormat.DefaultHDR : RenderTextureFormat.Default);
                cmd.Blit(cameraTarget, lastFrame);
                material.SetTexture(lastFrameTexture, lastFrame);
            }

            int TAATexture = Shader.PropertyToID("_TAATexture");
            cmd.GetTemporaryRT(TAATexture, width, height, 0, FilterMode.Bilinear,
                camera.allowHDR ? RenderTextureFormat.DefaultHDR : RenderTextureFormat.Default);
            cmd.Blit(cameraTarget, TAATexture);
            cmd.Blit(TAATexture, cameraTarget, material, 0);

            cmd.Blit(cameraTarget, lastFrame);
            material.SetTexture(lastFrameTexture, lastFrame);

            cmd.ReleaseTemporaryRT(TAATexture);
            */
            //如果要开场景窗口就得这样
            if(lastFrame.width == camera.pixelWidth || lastFrame.height == camera.pixelHeight)
            {
                int TAATexture = Shader.PropertyToID("_TAATexture");
                cmd.GetTemporaryRT(TAATexture, width, height, 0, FilterMode.Bilinear,
                    camera.allowHDR ? RenderTextureFormat.DefaultHDR : RenderTextureFormat.Default);
                cmd.Blit(cameraTarget, TAATexture);
                cmd.Blit(TAATexture, cameraTarget, TAAmaterial, 0);

                cmd.Blit(cameraTarget, lastFrame);
                TAAmaterial.SetTexture(lastFrameTexture, lastFrame);

                cmd.ReleaseTemporaryRT(TAATexture);
            }

            //cmd.ReleaseTemporaryRT(MVTexture);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);

        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            
        }
    }

    CustomRenderPass m_ScriptablePass;

    /// <inheritdoc/>
    public override void Create()
    {
        m_ScriptablePass = new CustomRenderPass();
        m_ScriptablePass.renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        m_ScriptablePass.setUp(renderer, taaSettings, renderer.cameraColorTarget);
        renderingData.cameraData.camera.ResetProjectionMatrix();
        renderer.EnqueuePass(m_ScriptablePass);
    }
}


