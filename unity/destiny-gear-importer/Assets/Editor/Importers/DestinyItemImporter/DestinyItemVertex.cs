using UnityEngine;

public class DestinyItemVertex
{
    public Vector3 Position { get; private set; }
    public Vector2 UV { get; private set; }
    public Vector3 Normal { get; private set; }

    public void SetPosition(Vector4 position)
    {
        Position = new Vector3(position.x, position.y, position.z);
    }

    public void SetUV(Vector2 uv)
    {
        UV = uv;
    }

    public void SetNormal(Vector4 normal)
    {
        Normal = new Vector3(
            (normal.x * 2f) - 1f,
            (normal.y * 2f) - 1f,
            (normal.z * 2f) - 1f);
    }
}