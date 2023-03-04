using System;
using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(Octahedral_Mapping))]
[CanEditMultipleObjects]
public class Octachedral_Mapping_Inspector : Editor
{
    private Octahedral_Mapping holder;

    private void OnEnable()
    {
        holder = (Octahedral_Mapping)serializedObject.targetObject;
    }

    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();
        if (GUILayout.Button("Create Octahedral Map"))
        {
            holder.makeOctahedral_Map();
        }
        if (GUILayout.Button("Clear"))
        {
            holder.Clear();
        }
    }
}
