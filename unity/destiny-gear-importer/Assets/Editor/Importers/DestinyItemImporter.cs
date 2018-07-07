using UnityEngine;
using UnityEditor.Experimental.AssetImporters;
using System.IO;
using System.Collections.Generic;
using System.Linq;
using System;

[ScriptedImporter(1, "meshes")]
public class DestinyItemImporter : ScriptedImporter
{
    private struct Vertex
    {
        public Vector3 Position;
        public Vector2 UV;
    }

    private class StreamElement
    {
        public enum StreamElementType
        {
            Float2 = 0,
            Float4 = 1,
            Short2 = 2,
            Short4 = 3,
            Ubyte4 = 4
        }

        delegate object StreamTypeReader(BinaryReader reader);

        private static Dictionary<StreamElementType, StreamTypeReader> StreamTypeReaders =
            new Dictionary<StreamElementType, StreamTypeReader>
            {
                { StreamElementType.Float2, r => r.ReadVector2() },
                { StreamElementType.Float4, r => r.ReadVector4() },
                { StreamElementType.Short2, r => r.ReadShort2() },
                { StreamElementType.Short4, r => r.ReadShort4() },
                { StreamElementType.Ubyte4, r => r.ReadBytes(4) }
            };

        private StreamTypeReader valueReader;
        private bool isNormalized;

        public StreamElement(StreamElementType type, int semantic, int index, bool isNormalized)
        {
            if (!StreamTypeReaders.TryGetValue(type, out valueReader))
            {
                throw new NotImplementedException(
                    string.Format("No reader defined for element type '{0}'", type));
            }
            this.isNormalized = isNormalized;
        }

        public void ModifyVertex(BinaryReader reader, Vertex vertex)
        {
            var value = valueReader(reader);
            // if (vertexModifier != null)
            // {
            //     vertexModifier(vertex, value);
            // }
        }
    }

    public override void OnImportAsset(AssetImportContext ctx)
    {
        using (var stream = new FileStream(ctx.assetPath, FileMode.OpenOrCreate))
        {
            using (var reader = new BinaryReader(stream))
            {
                var root = new GameObject(Path.GetFileNameWithoutExtension(ctx.assetPath));
                ctx.AddObjectToAsset("root", root);
                ctx.SetMainObject(root);

                int arrangementCount = reader.ReadInt32();
                var objects = Enumerable.Range(0, arrangementCount)
                    .SelectMany(i => ImportArrangement(reader, i.ToString()))
                    .ToList();

                foreach (var obj in objects)
                {
                    obj.transform.SetParent(root.transform);
                }
            }
        }
    }

    private List<GameObject> ImportArrangement(BinaryReader reader, string prefix)
    {
        int bobCount = reader.ReadInt32();
        return Enumerable.Range(0, bobCount)
            .SelectMany(i => ImportBob(reader, string.Format("{0}-{1}", prefix, i)))
            .ToList();
    }

    private List<GameObject> ImportBob(BinaryReader reader, string prefix)
    {
        // read bob header
        bool isTriList = reader.ReadInt32() == 3;
        int vertexCount = reader.ReadInt32();

        // read index buffer
        int indexCount = reader.ReadInt32();
        var allIndices = Enumerable.Range(0, indexCount)
            .Select(i => reader.ReadInt16())
            .ToArray();

        // read vertices
        var vertices = new Vertex[vertexCount];
        int vertexBufferCount = reader.ReadInt32();
        for (int i = 0; i < vertexBufferCount; i++)
        {
            FillVertices(reader, vertices);
        }

        // read bits
        int bitCount = reader.ReadInt32();
        return (from i in Enumerable.Range(0, bitCount)
                let bitPrefix = string.Format("{0}-{1}", prefix, i)
                select ImportBit(reader, bitPrefix, allIndices, isTriList, vertices)).ToList();
    }

    private void FillVertices(BinaryReader reader, Vertex[] vertices)
    {
        int elementCount = reader.ReadInt32();
        var elements = Enumerable.Range(0, elementCount)
            .Select(i => ReadElement(reader))
            .ToArray();

        foreach (var vertex in vertices)
        {
            foreach (var element in elements)
            {
                element.ModifyVertex(reader, vertex);
            }
        }
    }

    private StreamElement ReadElement(BinaryReader reader)
    {
        var type = (StreamElement.StreamElementType)reader.ReadInt32();
        return new StreamElement(type, reader.ReadInt32(), reader.ReadInt32(),
            reader.ReadBoolean());
    }

    private GameObject ImportBit(BinaryReader reader, string name, short[] allIndices,
        bool isTriList, Vertex[] vertices)
    {
        int start = reader.ReadInt32();
        int end = reader.ReadInt32();

        return new GameObject(name);
    }
}

public static class DII_ExtensionMethods
{
    // BinaryReader
    public static Vector2 ReadVector2(this BinaryReader reader)
    {
        return new Vector2(reader.ReadSingle(), reader.ReadSingle());
    }

    public static Vector4 ReadVector4(this BinaryReader reader)
    {
        return new Vector4(reader.ReadSingle(), reader.ReadSingle(), reader.ReadSingle(),
            reader.ReadSingle());
    }

    public static short[] ReadShort2(this BinaryReader reader)
    {
        return new[]
        {
            reader.ReadInt16(),
            reader.ReadInt16()
        };
    }

    public static short[] ReadShort4(this BinaryReader reader)
    {
        return new[]
        {
            reader.ReadInt16(),
            reader.ReadInt16(),
            reader.ReadInt16(),
            reader.ReadInt16()
        };
    }
}