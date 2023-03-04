using System.Collections;
using System.Collections.Generic;
using Unity.Collections;
using UnityEditor;
using UnityEngine;

public class Double_Paraboloid_Mapping : MonoBehaviour
{

    public Texture2D Front_Paraboloid_Map;
    public Texture2D Back_Paraboloid_Map;
    public Cubemap Environment_Map;
    public int sacleSize;
    private NativeArray<Color> Front_Paraboloid_Map_Color;
    private NativeArray<Color> Back_Paraboloid_Map_Color;
    private int mapSize;

    public void makeDouble_Paraboloid_Map()
    {
        float scale = 1.0f / sacleSize;
        float sacle2 = scale * scale;
        mapSize = Environment_Map.GetPixels((CubemapFace)0, 0).Length;
        Front_Paraboloid_Map_Color = new NativeArray<Color>((int)(mapSize * sacle2), Allocator.Persistent);
        Back_Paraboloid_Map_Color = new NativeArray<Color>((int)(mapSize * sacle2), Allocator.Persistent);
        mapSize = (int)(Mathf.Sqrt(mapSize) * scale);

        for (int face = 0; face < 6; face++)
        {

            Vector3 axis = new Vector3(0.0f, 0.0f, 0.0f);
            switch (face)
            {
                case 0:
                    axis = new Vector3(1.0f, 0.0f, 0.0f);
                    break;
                case 1:
                    axis = new Vector3(-1.0f, 0.0f, 0.0f);
                    break;
                case 2:
                    axis = new Vector3(0.0f, 1.0f, 0.0f);
                    break;
                case 3:
                    axis = new Vector3(0.0f, -1.0f, 0.0f);
                    break;
                case 4:
                    axis = new Vector3(0.0f, 0.0f, 1.0f);
                    break;
                case 5:
                    axis = new Vector3(0.0f, 0.0f, -1.0f);
                    break;
            }

            for (int v = 0; v < mapSize / scale; v++)
            {
                for (int u = 0; u < mapSize / scale; u++)
                {
                    float x = ((float)u / ((float)mapSize / scale)) * 2.0f - 1.0f;
                    float z = ((float)v / ((float)mapSize / scale)) * 2.0f - 1.0f;

                    Vector3 faceDir = Vector3.zero;
                    switch (face)
                    {
                        case 0:
                            faceDir = new Vector3(0.0f, z, -x);
                            break;
                        case 1:
                            faceDir = new Vector3(0.0f, z, x);
                            break;
                        case 2:
                            faceDir = new Vector3(x, 0.0f, -z);
                            break;
                        case 3:
                            faceDir = new Vector3(x, 0.0f, z);
                            break;
                        case 4:
                            faceDir = new Vector3(x, z, 0.0f);
                            break;
                        case 5:
                            faceDir = new Vector3(-x, z, 0.0f);
                            break;
                    }
                    Vector3 dir = faceDir + axis;
                    dir = dir.normalized;

                    Vector4 color = Environment_Map.GetPixel((CubemapFace)face, u, mapSize - v);
                    int s = (int)((dir.x / (1.0f + Mathf.Abs(dir.z)) * 0.5f + 0.5f) * mapSize);
                    int t = (int)((dir.y / (1.0f + Mathf.Abs(dir.z)) * 0.5f + 0.5f) * mapSize);
                    int index = (int)(s + t * mapSize);
                    if (dir.z > 0.0f)
                    {
                        if(index >= mapSize * mapSize)
                        {
                            index = mapSize * mapSize - 1;
                        }
                        Front_Paraboloid_Map_Color[index] = color;
                    }
                    else
                    {
                        if (index >= mapSize * mapSize)
                        {
                            index = mapSize * mapSize - 1;
                        }
                        Back_Paraboloid_Map_Color[index] = color;
                    }

                }
            }
        }

        Front_Paraboloid_Map = new Texture2D(mapSize, mapSize);
        Front_Paraboloid_Map.filterMode = FilterMode.Bilinear;
        Front_Paraboloid_Map.wrapMode = TextureWrapMode.Clamp;
        Front_Paraboloid_Map.SetPixels(Front_Paraboloid_Map_Color.ToArray());
        Front_Paraboloid_Map.Apply();
        AssetDatabase.CreateAsset(Front_Paraboloid_Map, "Assets/test/Environment mapping/Double_Paraboloid_Mapping/texture/Front_Paraboloid_Map.asset");

        Back_Paraboloid_Map = new Texture2D(mapSize, mapSize);
        Back_Paraboloid_Map.filterMode = FilterMode.Bilinear;
        Back_Paraboloid_Map.wrapMode = TextureWrapMode.Clamp;
        Back_Paraboloid_Map.SetPixels(Back_Paraboloid_Map_Color.ToArray());
        Back_Paraboloid_Map.Apply();
        AssetDatabase.CreateAsset(Back_Paraboloid_Map, "Assets/test/Environment mapping/Double_Paraboloid_Mapping/texture/Back_Paraboloid_Map.asset");

        AssetDatabase.Refresh();

    }

    public void Clear()
    {
        if (Front_Paraboloid_Map_Color.IsCreated)
        {
            Front_Paraboloid_Map_Color.Dispose();
        }
        if (Back_Paraboloid_Map_Color.IsCreated)
        {
            Back_Paraboloid_Map_Color.Dispose();
        }
    }

}
