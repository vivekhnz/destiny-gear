using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEngine;

public class DestinyItemBob
{
    public bool IsTriangleList { get; private set; }

    public int[] Indices { get; private set; }
    public DestinyItemVertex[] Vertices { get; private set; }
    public List<DestinyItemBit> Bits { get; private set; }

    private DestinyItemBob()
    {
    }

    public static DestinyItemBob Load(BinaryReader reader)
    {
        var bob = new DestinyItemBob();

        // read texture coordinate scale and offset
        var textureScale = new Vector2(reader.ReadSingle(), reader.ReadSingle());
        var textureOffset = new Vector2(reader.ReadSingle(), reader.ReadSingle());

        // read bob header
        int bitCount = reader.ReadInt32();
        if (bitCount == 0)
        {
            return bob;
        }

        bob.IsTriangleList = reader.ReadInt32() == 3;
        int vertexCount = reader.ReadInt32();

        // read index buffer
        int indexCount = reader.ReadInt32();
        bob.Indices = Enumerable.Range(0, indexCount)
            .Select(i => (int)reader.ReadInt16()).ToArray();

        // read vertices
        int vertexBufferCount = reader.ReadInt32();
        bob.Vertices = Enumerable.Range(0, vertexCount)
            .Select(i => new DestinyItemVertex()).ToArray();
        for (int i = 0; i < vertexBufferCount; i++)
        {
            int elementCount = reader.ReadInt32();
            var elements = Enumerable.Range(0, elementCount).Select(
                e => DestinyItemStreamElement.Load(reader)).ToList();
            foreach (var vertex in bob.Vertices)
            {
                foreach (var element in elements)
                {
                    element.ModifyVertex(vertex, element.ReadValue(reader));
                }
            }
        }

        // post-process vertices
        foreach (var vertex in bob.Vertices)
        {
            var normalizedUV = (vertex.UV * 2f) - Vector2.one;
            var transformedUV = (normalizedUV * textureScale) + textureOffset;
            vertex.SetUV(new Vector2(transformedUV.x, 1f - transformedUV.y));
        }

        // read bits
        bob.Bits = Enumerable.Range(0, bitCount)
            .Select(i => DestinyItemBit.Load(reader)).ToList();

        return bob;
    }
}