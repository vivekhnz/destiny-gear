Param (
    [Parameter(Mandatory = $true)] [string] $VertexBufferPath,
    [Parameter(Mandatory = $true)] [string] $IndexBufferPath,
    [Parameter(Mandatory = $true)] [string] $OutputPath
)

# verify input files are accessible
if (!(Test-Path $VertexBufferPath)) {
    throw "Vertex buffer not found at $VertexBufferPath"
}
if (!(Test-Path $IndexBufferPath)) {
    throw "Index buffer not found at $IndexBufferPath"
}

# read buffers
$buffers = Get-Content -Path @($VertexBufferPath, $IndexBufferPath) -Encoding Byte -ReadCount 512

# save meshes file
$buffers | Set-Content $OutputPath -Encoding Byte -Force