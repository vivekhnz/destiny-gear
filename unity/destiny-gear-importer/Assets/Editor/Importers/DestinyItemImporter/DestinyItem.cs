using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

public class DestinyItem
{
    public List<DestinyItemArrangement> Arrangements { get; private set; }

    private DestinyItem()
    {
    }

    public static DestinyItem Load(BinaryReader reader)
    {
        int arrangementCount = reader.ReadInt32();
        return new DestinyItem
        {
            Arrangements = Enumerable.Range(0, arrangementCount)
                .Select(i => DestinyItemArrangement.Load(reader)).ToList()
        };
    }
}