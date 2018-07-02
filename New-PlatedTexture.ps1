Param (
    [Parameter(Mandatory = $true)] [string] $FolderPath,
    [Parameter(Mandatory = $true)] [string] $TextureFolderPath
)

$RenderMetadata = Join-Path $FolderPath "render_metadata.js"

function New-TexturePlate {
    Param (
        [Parameter(Mandatory = $true)] $Plate
    )

    $PlateWidth = $Plate.plate_size[0]
    $PlateHeight = $Plate.plate_size[1]

    $texturePlate = ([System.Drawing.Bitmap]::new($plateWidth, $plateHeight))
    $graphic = [System.Drawing.Graphics]::FromImage($texturePlate)

    foreach ($placement in $Plate.texture_placements) {
        $texturePath = Join-Path $TextureFolderPath ($placement.texture_tag_name + ".png")
        $texture = [System.Drawing.Bitmap]::FromFile($texturePath)
        $destination = [System.Drawing.Rectangle]::new($placement.position_x, $placement.position_y, $placement.texture_size_x, $placement.texture_size_y)
        $graphic.DrawImage($texture, $destination)

    }
    $graphic.Dispose()
    return $texturePlate
}

# verify input files are accessible
if (!(Test-Path $RenderMetadata)) {
    throw "Metadata file not found at $RenderMetadata"
}

$json = Get-Content -Path $RenderMetadata
$metadataObj = $json | ConvertFrom-Json
$texturePlateSet = $metadataObj.texture_plates[0].plate_set

$diffuseTexturePlate = New-TexturePlate $texturePlateSet.diffuse
$diffuseFilePath = Join-Path $FolderPath "diffuse.png"
$diffuseTexturePlate.Save($diffuseFilePath)

$normalTexturePlate = New-TexturePlate $texturePlateSet.normal
$normalFilePath = Join-Path $FolderPath "normal.png"
$normalTexturePlate.Save($normalFilePath)

$gearstackTexturePlate = New-TexturePlate $texturePlateSet.gearstack
$gearstackFilePath = Join-Path $FolderPath "gearstack.png"
$gearstackTexturePlate.Save($gearstackFilePath)