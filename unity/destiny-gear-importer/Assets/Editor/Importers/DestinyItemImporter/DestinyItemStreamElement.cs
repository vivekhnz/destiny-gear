using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEngine;

public class DestinyItemStreamElement
{
    private enum VertexStreamType
    {
        Float2 = 0,
        Float4 = 1,
        Short2 = 2,
        Short4 = 3,
        Ubyte4 = 4
    }
    private enum VertexStreamSemantic
    {
        POSITION = 0,
        TEXCOORD = 1,
        NORMAL = 2,
        TANGENT = 3,
        COLOR = 4,
        BLENDWEIGHT = 5,
        BLENDINDICES = 6
    }

    public delegate object VertexStreamReader(BinaryReader reader, bool isNormalized);
    public delegate void VertexModifier(DestinyItemVertex vertex, object value);

    private static Dictionary<VertexStreamType, VertexStreamReader> StreamReaders =
        new Dictionary<VertexStreamType, VertexStreamReader>
        {
            {
                VertexStreamType.Float2,
                (r, n) => new Vector2(
                    r.ReadSingle().NormalizeFloat(n),
                    r.ReadSingle().NormalizeFloat(n))
            },
            {
                VertexStreamType.Float4,
                (r, n) => new Vector4(
                    r.ReadSingle().NormalizeFloat(n),
                    r.ReadSingle().NormalizeFloat(n),
                    r.ReadSingle().NormalizeFloat(n),
                    r.ReadSingle().NormalizeFloat(n))
            },
            {
                VertexStreamType.Short2,
                (r, n) => new Vector2(
                    r.ReadInt16().NormalizeShort(n),
                    r.ReadInt16().NormalizeShort(n))
            },
            {
                VertexStreamType.Short4,
                (r, n) => new Vector4(
                    r.ReadInt16().NormalizeShort(n),
                    r.ReadInt16().NormalizeShort(n),
                    r.ReadInt16().NormalizeShort(n),
                    r.ReadInt16().NormalizeShort(n))
            },
            {
                VertexStreamType.Ubyte4,
                (r, n) => {
                    var bytes = r.ReadBytes(4).Select(b => b.NormalizeByte(n)).ToArray();
                    return new Vector4(bytes[0], bytes[1], bytes[2], bytes[3]);
                }
            }
        };
    private static Dictionary<string, VertexModifier> VertexModifiers =
        new Dictionary<string, VertexModifier>
        {
            { "POSITION0", (vertex, value) => vertex.SetPosition((Vector4)value) },
            { "TEXCOORD0", (vertex, value) => vertex.SetUV((Vector2)value) },
            { "NORMAL0", (vertex, value) => vertex.SetNormal((Vector4)value) }
        };

    VertexStreamReader valueReader;
    VertexModifier vertexModifier;
    bool isNormalized;

    private DestinyItemStreamElement(VertexStreamType type, VertexStreamSemantic semantic,
        int semanticIndex, bool isNormalized)
    {
        if (!StreamReaders.TryGetValue(type, out valueReader))
            throw new InvalidDataException(
                string.Format("Unknown stream element type ({0}).", type));

        string semanticId = string.Format("{0}{1}", semantic.ToString(), semanticIndex);
        VertexModifiers.TryGetValue(semanticId, out vertexModifier);

        this.isNormalized = isNormalized;
    }

    public static DestinyItemStreamElement Load(BinaryReader reader)
    {
        return new DestinyItemStreamElement(
            (VertexStreamType)reader.ReadInt32(),
            (VertexStreamSemantic)reader.ReadInt32(),
            reader.ReadInt32(),
            reader.ReadBoolean());
    }

    public object ReadValue(BinaryReader reader)
    {
        return valueReader(reader, isNormalized);
    }

    public void ModifyVertex(DestinyItemVertex vertex, object value)
    {
        if (vertexModifier != null)
        {
            vertexModifier(vertex, value);
        }
    }
}