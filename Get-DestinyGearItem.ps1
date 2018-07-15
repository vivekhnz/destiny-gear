Param (
    [Parameter(Mandatory = $true)] [Uint32] $ItemHash
)

$WorldDBPath = Join-Path $PSScriptRoot "data/world.content"
$AssetDBPath = Join-Path $PSScriptRoot "data/assets.content"
$ItemsDirPath = Join-Path $PSScriptRoot "items"

$BungieNetPlatform = "https://www.bungie.net"
$GearDefinitionUrl = "$BungieNetPlatform/common/destiny2_content/geometry/gear"
$TexturesUrl = "$BungieNetPlatform/common/destiny2_content/geometry/platform/mobile/textures"
$GeometryUrl = "$BungieNetPlatform/common/destiny2_content/geometry/platform/mobile/geometry"

Function Get-ItemDefinition {
    Param (
        [Parameter(Mandatory = $true)] [Uint32] $ItemHash
    )

    # query world DB
    $hashFilter = "`"hash`":$ItemHash,"
    $query = "SELECT * FROM DestinyInventoryItemDefinition WHERE json like '%$hashFilter%'"
    $results = Invoke-SqliteQuery -DataSource $WorldDBPath -Query $query

    # verify exactly one item was found
    if ($results.id.Count -lt 1) {
        throw "No items found with hash '$ItemHash'"
    }
    if ($results.id.Count -gt 1) {
        throw "Multiple items found with hash '$ItemHash'"
    }

    # read json
    $json = [System.Text.Encoding]::ASCII.GetString($results.json)
    return @{
        Id   = $results.id
        Json = $json
    }
}

Function Get-AssetDefinition {
    Param (
        [Parameter(Mandatory = $true)] [string] $Id
    )

    # query assets DB
    $query = "SELECT json FROM DestinyGearAssetsDefinition WHERE id = '$Id'"
    $results = Invoke-SqliteQuery -DataSource $AssetDBPath -Query $query

    # verify exactly one item was found
    if (-not $results.json) {
        throw "No assets found with id '$Id'"
    }

    # read json
    $json = [System.Text.Encoding]::ASCII.GetString($results.json)
    return $json
}

Function Get-GearDefinition {
    Param (
        [Parameter(Mandatory = $true)] [string] $Filename
    )

    $url = "$GearDefinitionUrl/$Filename"
    $response = Invoke-WebRequest -Uri $url
    if ($response.StatusCode -ne 200) {
        throw "Failed to download gear definition from '$url'"
    }

    return $response.Content
}

Function Expand-TGXM {
    Param (
        [Parameter(Mandatory = $true)] [byte[]] $Data
    )

    # verify this is a TGXM file
    $format = [System.Text.Encoding]::ASCII.GetString($Data[0..3])
    if ($format -ne 'TGXM') {
        throw "File is not a valid TGXM file"
    }

    # identify file version and file count
    $version = [BitConverter]::ToInt32($Data[4..7], 0)
    $fileCount = [BitConverter]::ToInt32($Data[12..15], 0)

    # determine version-specific properties
    $stringLength = 128
    $tgxmHeaderLength = 16
    $identifier = ""
    if ($version -eq 2) {
        $stringLength = 256
        $tgxmHeaderLength = 16 + $stringLength

        $identifier = [System.Text.Encoding]::ASCII.GetString($Data[16..(15 + $stringLength)])
    }

    # read files
    $files = New-Object System.Collections.Generic.List[System.Object]
    $fileHeaderLength = $stringLength + 16
    for ($i = 0; $i -lt $fileCount; $i++) {
        $filenamePos = $tgxmHeaderLength + ($i * $fileHeaderLength)
        $offsetPos = $filenamePos + $stringLength
        $lengthPos = $offsetPos + 8

        $filename = [System.Text.Encoding]::ASCII.GetString($Data[$filenamePos..($offsetPos - 1)])
        $offset = [BitConverter]::ToInt32($Data[$offsetPos..($offsetPos + 3)], 0)
        $length = [BitConverter]::ToInt32($Data[$lengthPos..($lengthPos + 3)], 0)

        $files.Add(@{
                Filename = $filename.Trim([char] $null)
                Data     = $Data[$offset..($offset + $length - 1)]
            })
    }

    return @{
        Identifier = $identifier.Trim([char] $null)
        Files      = $files
    }
}

Function Get-Textures {
    Param (
        [Parameter(Mandatory = $true)] [string] $Filename
    )

    # download TGXM
    $url = "$TexturesUrl/$Filename"
    $response = Invoke-WebRequest -Uri $url
    if ($response.StatusCode -ne 200) {
        throw "Failed to download TGXM from '$url'"
    }

    # extract textures
    $tgxm = Expand-TGXM $response.Content
    return $tgxm.Files
}

Function Get-Geometry {
    Param (
        [Parameter(Mandatory = $true)] [string] $Filename
    )

    # download TGXM
    $url = "$GeometryUrl/$Filename"
    $response = Invoke-WebRequest -Uri $url
    if ($response.StatusCode -ne 200) {
        throw "Failed to download TGXM from '$url'"
    }

    # extract geometry
    return (Expand-TGXM $response.Content)
}

# verify DBs are accessible
if (!(Test-Path $WorldDBPath)) {
    throw "World DB not found at $WorldDBPath"
}
if (!(Test-Path $AssetDBPath)) {
    throw "Asset DB not found at $AssetDBPath"
}

# import SQLite module
Import-Module PSSQLite

# get item definition
Write-Host "Retrieving item definition..."
$item = Get-ItemDefinition $ItemHash

# build folder structure
$itemDir = Join-Path $ItemsDirPath $ItemHash
$texturesDir = Join-Path $itemDir "textures"
$geometryDir = Join-Path $itemDir "geometry"
New-Item -ItemType Directory -Path $itemDir -Force | Out-Null
New-Item -ItemType Directory -Path $texturesDir -Force | Out-Null
New-Item -ItemType Directory -Path $geometryDir -Force | Out-Null

$itemPath = Join-Path $itemDir "item.json"
$item.Json | Out-File -FilePath $itemPath -Force

# get asset definition
Write-Host "Retrieving asset definition..."
$asset = Get-AssetDefinition $item.Id
$assetPath = Join-Path $itemDir "asset.json"
$asset | Out-File -FilePath $assetPath -Force

# get gear definitions
Write-Host "Retrieving gear definition..."
$assetObj = $asset | ConvertFrom-Json
$gear = Get-GearDefinition $assetObj.gear[0]
$gearDefPath = Join-Path $itemDir "gear.json"
$gear | Out-File -FilePath $gearDefPath -Force

# get textures
if ($assetObj.content[0].textures) {
    Write-Host "Downloading texture sets..."
    $textureSets = @($assetObj.content[0].textures)
    for ($i = 0; $i -lt $textureSets.Count; $i++) {
        $textureSetName = $textureSets[$i]
        foreach ($file in (Get-Textures $textureSetName)) {
            $texturePath = Join-Path $texturesDir "$($file.Filename).png"
            $file.Data | Set-Content $texturePath -Encoding Byte
        }
        Write-Host "Downloaded $($i + 1)/$($textureSets.Count) texture sets."
    }
}

# get geometry
if ($assetObj.content[0].geometry) {
    Write-Host "Downloading geometry sets..."
    $geometrySets = @($assetObj.content[0].geometry)
    for ($i = 0; $i -lt $geometrySets.Count; $i++) {
        $geometrySetName = $geometrySets[$i]
        $tgxm = Get-Geometry $geometrySetName
        $geomSetDir = Join-Path $geometryDir $tgxm.Identifier
        New-Item -ItemType Directory -Path $geomSetDir -Force | Out-Null
        foreach ($file in $tgxm.Files) {
            $filePath = Join-Path $geomSetDir $file.Filename
            $file.Data | Set-Content $filePath -Encoding Byte
        }
        Write-Host "Downloaded $($i + 1)/$($geometrySets.Count) geometry sets."
    }
}