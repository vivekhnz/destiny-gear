using UnityEngine;
using UnityEditor.Experimental.AssetImporters;
using System.IO;
using System.Collections.Generic;
using System.Linq;
using System;

[ScriptedImporter(1, "meshes")]
public class DestinyItemImporter : ScriptedImporter
{
    public override void OnImportAsset(AssetImportContext ctx)
    {
        var item = LoadItemFromFile(ctx.assetPath);

        var root = new GameObject(Path.GetFileNameWithoutExtension(ctx.assetPath));
        ctx.AddObjectToAsset("root", root);
        ctx.SetMainObject(root);

        for (int a = 0; a < item.Arrangements.Count; a++)
        {
            var arrangement = item.Arrangements[a];

            var diffuseTexture = LoadTexture(
                string.Format("{0}_Diffuse", arrangement.Id), arrangement.DiffuseTexture);
            var normalTexture = LoadTexture(
                string.Format("{0}_Normal", arrangement.Id), arrangement.NormalTexture);
            var gearstackTexture = LoadTexture(
                string.Format("{0}_Gearstack", arrangement.Id), arrangement.GearstackTexture);

            ctx.AddObjectToAsset(diffuseTexture.name, diffuseTexture);
            ctx.AddObjectToAsset(normalTexture.name, normalTexture);
            ctx.AddObjectToAsset(gearstackTexture.name, gearstackTexture);

            var material = new Material(Shader.Find("Standard 2-Sided"));
            material.name = string.Format("{0}_Material", arrangement.Id);
            material.SetTexture("_MainTex", diffuseTexture);
            material.SetTexture("_BumpMap", normalTexture);
            ctx.AddObjectToAsset(material.name, material);

            for (int b = 0; b < arrangement.Bobs.Count; b++)
            {
                var bob = arrangement.Bobs[b];
                for (int p = 0; p < bob.Bits.Count; p++)
                {
                    var bit = bob.Bits[p];
                    string name = string.Format("{0}_{1}", arrangement.Id, p);

                    var indices = bob.Indices.Skip(bit.StartIndex)
                        .Take(bit.EndIndex - bit.StartIndex).ToArray();
                    if (!bob.IsTriangleList)
                    {
                        indices = ConvertTriangleStripToTriangleList(indices);
                    }

                    // remove loose vertices
                    int minIndex = indices.Min();
                    int maxIndex = indices.Max();
                    var vertices = bob.Vertices.Skip(minIndex)
                        .Take(maxIndex - minIndex + 1).ToArray();
                    indices = indices.Select(i => i - minIndex).ToArray();

                    var obj = CreateMesh(name, vertices, indices);
                    obj.transform.SetParent(root.transform);

                    var mesh = obj.GetComponent<MeshFilter>().sharedMesh;
                    ctx.AddObjectToAsset(mesh.name, mesh);

                    obj.GetComponent<MeshRenderer>().sharedMaterial = material;
                }
            }
        }
    }

    private Texture2D LoadTexture(string name, byte[] data)
    {
        var texture = new Texture2D(1, 1);
        texture.LoadImage(data);
        texture.name = name;
        return texture;
    }

    private DestinyItem LoadItemFromFile(string path)
    {
        using (var stream = new FileStream(path, FileMode.Open))
        {
            using (var reader = new BinaryReader(stream))
            {
                return DestinyItem.Load(reader);
            }
        }
    }

    private int[] ConvertTriangleStripToTriangleList(int[] indices)
    {
        var triList = new List<int>();
        for (int i = 0; i < indices.Count() - 2; i++)
        {
            var a = indices[i];
            var b = indices[i + 1];
            var c = indices[i + 2];
            if (a == b || a == c || b == c) continue;
            if (i % 2 == 0)
            {
                triList.Add(a);
                triList.Add(b);
                triList.Add(c);
            }
            else
            {
                triList.Add(a);
                triList.Add(c);
                triList.Add(b);
            }
        }
        return triList.ToArray();
    }

    private GameObject CreateMesh(string name, DestinyItemVertex[] vertices, int[] indices)
    {
        var obj = new GameObject(name);

        var mesh = new Mesh();
        mesh.name = string.Format("Mesh ({0})", name);

        mesh.SetVertices(vertices.Select(v => v.Position).ToList());
        mesh.SetUVs(0, vertices.Select(v => v.UV).ToList());
        mesh.SetNormals(vertices.Select(v => v.Normal).ToList());
        mesh.SetTriangles(indices, 0);

        obj.AddComponent<MeshFilter>().sharedMesh = mesh;
        obj.AddComponent<MeshRenderer>();

        return obj;
    }
}