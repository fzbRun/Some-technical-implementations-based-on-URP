using System.Collections;
using System.Collections.Generic;
using Unity.Collections;
using UnityEditor;
using UnityEngine;

public class Concentric_Octahedral : MonoBehaviour
{

    public Texture2D Concentric_Octahedral_Map;
    public int scale;
    public Cubemap Environment_CubeMap;
    private Color[] Environment_CubeMap_Color;
    private NativeArray<Color> Concentric_Octahedral_Map_Color;

    float PI = Mathf.PI;

    float sign(float x)
    {
        return x >= 0.0f ? 1.0f : -1.0f;
    }

    public void makeConcentric_Octahedral_Map()
    {
        int mapSize = Environment_CubeMap.GetPixels((CubemapFace)0, 0).Length;
        Concentric_Octahedral_Map_Color = new NativeArray<Color>(mapSize * scale * scale, Allocator.Persistent);
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

            Environment_CubeMap_Color = Environment_CubeMap.GetPixels((CubemapFace)face, 0);
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
                    //Vector4 color = Environment_CubeMap.GetPixel((CubemapFace)face, u, v);
                    //Debug.DrawRay(this.transform.position, dir, color, 20);
                    //Debug.Log(dir);

                    x = Mathf.Abs(dir.x);
                    z = Mathf.Abs(dir.z);
                    float y = Mathf.Abs(dir.y);

                    float r = Mathf.Sqrt(1.0f - y);

                    float a = Mathf.Max(x, z);
                    float b = Mathf.Min(x, z);
                    float fai = a == 0.0f ? 0.0f : b / a;

                    float fai2PI = (float)(0.00000406531 + 0.636227 * fai +
                                       0.00615523 * fai * fai -
                                       0.247326 * fai * fai * fai +
                                       0.0881627 * fai * fai * fai * fai +
                                       0.0419157 * fai * fai * fai * fai * fai -
                                       0.0251427 * fai * fai * fai * fai * fai * fai);
                    if (x < z)
                    {
                        fai2PI = 1.0f - fai2PI;
                    }

                    float t = r * fai2PI;  //v'
                    float s = r - t;    //u'

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
                    t = 1.0f - t;
                    t *= mapSize * scale;

                    int index = (int)(s) + (int)(t) * mapSize * scale;

                    if (index >= mapSize * mapSize * scale * scale)
                    {
                        index = mapSize * mapSize * scale * scale - 1;
                    }

                    Concentric_Octahedral_Map_Color[index] = Environment_CubeMap.GetPixel((CubemapFace)face, u, mapSize - v);

                }
            }

        }

        Concentric_Octahedral_Map = new Texture2D(mapSize * scale, mapSize * scale);
        Concentric_Octahedral_Map.filterMode = FilterMode.Bilinear;
        Concentric_Octahedral_Map.wrapMode = TextureWrapMode.Clamp;
        Concentric_Octahedral_Map.SetPixels(Concentric_Octahedral_Map_Color.ToArray());
        Concentric_Octahedral_Map.Apply();
        AssetDatabase.CreateAsset(Concentric_Octahedral_Map, "Assets/test/Environment mapping/Concentric/texture/Concentric_Octahedral_Map.asset");
        AssetDatabase.Refresh();

    }

    public void Clear()
    {
        if (Concentric_Octahedral_Map_Color.IsCreated)
        {
            Concentric_Octahedral_Map_Color.Dispose();
        }
    }

}
