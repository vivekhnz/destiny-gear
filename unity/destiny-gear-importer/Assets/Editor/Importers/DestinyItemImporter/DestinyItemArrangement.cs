using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

public class DestinyItemArrangement
{
    public string Id { get; private set; }
    public List<DestinyItemBob> Bobs { get; private set; }

    public byte[] DiffuseTexture { get; private set; }
    public byte[] NormalTexture { get; private set; }
    public byte[] GearstackTexture { get; private set; }

    private DestinyItemArrangement()
    {
    }

    public static DestinyItemArrangement Load(BinaryReader reader)
    {
        var arrangement = new DestinyItemArrangement();

        // read bobs
        int bobCount = reader.ReadInt32();
        arrangement.Bobs = Enumerable.Range(0, bobCount)
            .Select(i => DestinyItemBob.Load(reader)).ToList();

        // read arrangement ID
        arrangement.Id = reader.ReadString();

        // read textures
        arrangement.DiffuseTexture = reader.ReadBytes(reader.ReadInt32());
        arrangement.NormalTexture = reader.ReadBytes(reader.ReadInt32());
        arrangement.GearstackTexture = reader.ReadBytes(reader.ReadInt32());

        return arrangement;
    }
}