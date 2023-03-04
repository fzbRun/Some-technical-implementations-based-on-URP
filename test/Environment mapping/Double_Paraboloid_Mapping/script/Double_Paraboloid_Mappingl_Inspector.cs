using System;
using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(Double_Paraboloid_Mapping))]
[CanEditMultipleObjects]
public class Double_ParaBoloid_Mapping_Inspector : Editor
{
    private Double_Paraboloid_Mapping holder;

    private void OnEnable()
    {
        holder = (Double_Paraboloid_Mapping)serializedObject.targetObject;
    }

    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();
        if (GUILayout.Button("Create Double ParaBoloid Map"))
        {
            holder.makeDouble_Paraboloid_Map();
        }
        if (GUILayout.Button("Clear"))
        {
            holder.Clear();
        }
    }
}