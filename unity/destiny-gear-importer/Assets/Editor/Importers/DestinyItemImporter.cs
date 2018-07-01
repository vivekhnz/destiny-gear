using UnityEngine;
using UnityEditor.Experimental.AssetImporters;
using System.IO;

[ScriptedImporter(1, "meshes")]
public class DestinyItemImporter : ScriptedImporter
{
    public override void OnImportAsset(AssetImportContext ctx)
    {
        using (var stream = new FileStream(ctx.assetPath, FileMode.OpenOrCreate))
        {
            using (var reader = new BinaryReader(stream))
            {
                int arrangementCount = reader.ReadInt32();
                Debug.Log(arrangementCount);
            }
        }

        var material = new Material(Shader.Find("Standard"));
        material.color = Color.red;
        ctx.AddObjectToAsset("material", material);

        var cube = GameObject.CreatePrimitive(PrimitiveType.Cube);
        cube.transform.position = new Vector3(0, 0, 0);
        cube.GetComponent<MeshRenderer>().material = material;

        ctx.AddObjectToAsset("root", cube);
        ctx.SetMainObject(cube);
    }
}