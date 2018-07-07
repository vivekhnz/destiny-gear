Param (
    [Parameter(Mandatory = $true)] [string] $FolderPath,
    [Parameter(Mandatory = $true)] [string] $TextureFolderPath
)

Import-Module .\DestinyGear.psm1

$RenderMetadata = Join-Path $FolderPath "render_metadata.js"

# verify input files are accessible
if (!(Test-Path $RenderMetadata)) {
    throw "Metadata file not found at $RenderMetadata"
}

$json = Get-Content -Path $RenderMetadata
$metadataObj = $json | ConvertFrom-Json
$plateSet = $metadataObj.texture_plates[0].plate_set

New-TexturePlate -TextureFolderPath $TextureFolderPath -Plate $plateSet.diffuse |
    Set-Content -Path (Join-Path $FolderPath "diffuse.png") -Encoding Byte
New-TexturePlate -TextureFolderPath $TextureFolderPath -Plate $plateSet.normal |
    Set-Content -Path (Join-Path $FolderPath "normal.png") -Encoding Byte
New-TexturePlate -TextureFolderPath $TextureFolderPath -Plate $plateSet.gearstack |
    Set-Content -Path (Join-Path $FolderPath "gearstack.png") -Encoding Byte