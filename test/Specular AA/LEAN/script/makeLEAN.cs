using System.Collections;
using System.Collections.Generic;
using Unity.Collections;
using UnityEditor;
using UnityEngine;

public class makeLEAN : MonoBehaviour
{

    public Texture2D NormalTexture;
    public Texture2D LEANBTexture;
    public Texture2D LEANMTexture;
    private NativeArray<Color> LEANB;
    private NativeArray<Color> LEANM;
    private int size;

    public void makeLEANTexture()
    {

        if (!NormalTexture)
        {
            Debug.Log("需要法线贴图");
            return;
        }

        Color[] normals = NormalTexture.GetPixels();
        size = (int)Mathf.Sqrt(normals.Length);

        LEANB = new NativeArray<Color>(size * size, Allocator.Persistent);
        LEANM = new NativeArray<Color>(size * size, Allocator.Persistent);

        for(int u = 0; u < size; u++)
        {
            int uOffset = u * size;
            for (int v = 0; v < size; v++)
            {

                int index = uOffset + v;

                //法线需要解码
                float r = normals[index].r;
                float g = normals[index].g;
                float b = normals[index].b;
                float a = normals[index].a;

                a *= r;
                float x = a * 2.0f - 1.0f;
                float y = g * 2.0f - 1.0f;
                float z = Mathf.Max(0.01f, Mathf.Sqrt(1.0f - Mathf.Clamp01(x * x + y * y)));
                Vector3 normal = new Vector3(x, y, z).normalized;

                float Nx = normal.x / normal.z;   //x * (1 / z)
                float Ny = normal.y / normal.z;
                LEANM[index] = new Vector4(Nx * Nx, Ny * Ny, Nx * Ny, 1.0f);
                LEANB[index] = new Vector4(Nx, Ny, 0.0f, 1.0f);

            }
        }
    }

    public Texture2D Create2DTexture(Vector2Int sizes)
    {
        TextureFormat format = TextureFormat.RGBAFloat;
        Texture2D tex2D = new Texture2D(sizes.x, sizes.y, format, true);
        tex2D.filterMode = FilterMode.Bilinear;
        tex2D.wrapMode = TextureWrapMode.Clamp;
        //Debug.Log(tex2D.mipmapCount);
        return tex2D;
    }

    public void Bake()
    {

        LEANBTexture = Create2DTexture(new Vector2Int(size, size));
        LEANMTexture = Create2DTexture(new Vector2Int(size, size));

        LEANBTexture.SetPixels(LEANB.ToArray());
        LEANMTexture.SetPixels(LEANM.ToArray());

        LEANBTexture.Apply();
        LEANMTexture.Apply();

        AssetDatabase.CreateAsset(LEANBTexture, "Assets/test/Specular AA/LEAN/texture/LEANBTexture.asset");
        AssetDatabase.CreateAsset(LEANMTexture, "Assets/test/Specular AA/LEAN/texture/LEANMTexture.asset");
        AssetDatabase.Refresh();

    }

    public void Clear()
    {

        if (LEANB.IsCreated)
        {
            LEANB.Dispose();
        }
        if (LEANM.IsCreated)
        {
            LEANM.Dispose();
        }

    }

}

[CustomEditor(typeof(makeLEAN))]
[CanEditMultipleObjects]
class makeLEANInspector : Editor
{
    private makeLEAN holder;

    private void OnEnable()
    {
        holder = (makeLEAN)serializedObject.targetObject;
    }

    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();
        if (GUILayout.Button("Make LEAN Texture"))
        {
            holder.makeLEANTexture();
        }
        if (GUILayout.Button("Bake"))
        {
            holder.Bake();
        }
        if (GUILayout.Button("Clear"))
        {
            holder.Clear();
        }
    }
}
