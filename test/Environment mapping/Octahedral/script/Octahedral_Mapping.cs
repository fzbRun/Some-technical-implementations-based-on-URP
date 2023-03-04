using System.Collections;
using System.Collections.Generic;
using Unity.Collections;
using UnityEditor;
using UnityEngine;

public class Octahedral_Mapping : MonoBehaviour
{

    public Texture2D Octahedral_Map;
    public int scale = 1;
    public Cubemap Environment_CubeMap;
    private NativeArray<Color> Octahedral_Map_Color;

    float PI = Mathf.PI;

    float sign(float x)
    {
        return x >= 0.0f ? 1.0f : -1.0f;
    }

    public void makeOctahedral_Map()
    {
        int mapSize = Environment_CubeMap.GetPixels((CubemapFace)0, 0).Length;
        Octahedral_Map_Color = new NativeArray<Color>(mapSize * scale * scale, Allocator.Persistent);
        mapSize = (int)Mathf.Sqrt(mapSize);

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

            for(int v = 0; v < mapSize; v++)
            {
                for(int u = 0; u < mapSize; u++)
                {
                    float x = ((float)u / (float)mapSize) * 2.0f - 1.0f;
                    float z = ((float)v / (float)mapSize) * 2.0f - 1.0f;

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

                    x = Mathf.Abs(dir.x);
                    z = Mathf.Abs(dir.z);
                    float y = Mathf.Abs(dir.y);

                    float s = x * (1.0f / (x + y + z));
                    float t = z * (1.0f / (x + y + z));

                    if (dir.y < 0.0f)
                    {
                        float tempS2 = 1.0f - t;
                        float tempT2 = 1.0f - s;
                        t = tempT2;
                        s = tempS2;
                    }

                    s *= sign(dir.x);
                    t *= sign(dir.z);

                    s = s * 0.5f + 0.5f;
                    t = t * 0.5f + 0.5f;

                    s *= mapSize * scale;
                    t *= mapSize * scale;

                    int index = (int)(s) + (int)(t) * mapSize * scale;

                    if (index >= mapSize * mapSize * scale * scale)
                    {
                        index = mapSize * mapSize * scale * scale - 1;
                    }

                    if(index < 0)
                    {
                        continue;
                    }

                    Octahedral_Map_Color[index] = Environment_CubeMap.GetPixel((CubemapFace)face, u, mapSize - v);

                }
            }

        }

        Octahedral_Map = new Texture2D(mapSize * scale, mapSize * scale);
        Octahedral_Map.filterMode = FilterMode.Bilinear;
        Octahedral_Map.wrapMode = TextureWrapMode.Clamp;
        Octahedral_Map.SetPixels(Octahedral_Map_Color.ToArray());
        Octahedral_Map.Apply();
        AssetDatabase.CreateAsset(Octahedral_Map, "Assets/test/Environment mapping/Octahedral/texture/Octahedral_Map.asset");
        AssetDatabase.Refresh();

    }

    public void Clear()
    {
        if (Octahedral_Map_Color.IsCreated)
        {
            Octahedral_Map_Color.Dispose();
        }
    }

}
