using System;
using System.IO;
using System.Linq;
using UnityEngine;

public static class NormalizationExtensions
{
    public static float NormalizeFloat(this float value, bool isNormalized)
    {
        if (isNormalized)
        {
            return (value - float.MinValue) / (float.MaxValue - float.MinValue);
        }
        return value;
    }
    public static float NormalizeShort(this short value, bool isNormalized)
    {
        if (isNormalized)
        {
            return (value - (float)short.MinValue) / ((float)short.MaxValue - (float)short.MinValue);
        }
        return value;
    }
    public static float NormalizeByte(this byte value, bool isNormalized)
    {
        if (isNormalized)
        {
            return (value - (float)byte.MinValue) / ((float)byte.MaxValue - (float)byte.MinValue);
        }
        return value;
    }
}