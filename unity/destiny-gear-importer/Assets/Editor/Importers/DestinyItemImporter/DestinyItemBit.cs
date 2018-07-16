using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

public class DestinyItemBit
{
    public int StartIndex { get; private set; }
    public int EndIndex { get; private set; }

    private DestinyItemBit()
    {
    }

    public static DestinyItemBit Load(BinaryReader reader)
    {
        return new DestinyItemBit
        {
            StartIndex = reader.ReadInt32(),
            EndIndex = reader.ReadInt32()
        };
    }
}