using System;
using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(Concentric_Octahedral))]
[CanEditMultipleObjects]
public class Concentric_Octahedral_Inspector : Editor
{
    private Concentric_Octahedral holder;

    private void OnEnable()
    {
        holder = (Concentric_Octahedral)serializedObject.targetObject;
    }

    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();
        if (GUILayout.Button("Create Concentric Octahedral Map"))
        {
            holder.makeConcentric_Octahedral_Map();
        }
        if (GUILayout.Button("Clear"))
        {
            holder.Clear();
        }
    }
}
