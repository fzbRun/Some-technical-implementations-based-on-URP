using System;
using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(LightProbeGroupHealper))]
[CanEditMultipleObjects]
public class LightProbeGroupInspector : Editor
{
    private LightProbeGroupHealper holder;

    private void OnEnable()
    {
        holder = (LightProbeGroupHealper)serializedObject.targetObject;
    }

    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();
        if (GUILayout.Button("Prepare"))
        {
            holder.Prepare();
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
