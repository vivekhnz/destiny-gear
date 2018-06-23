Param (
    [Parameter(Mandatory = $true)] [string] $ItemName
)

$WorldDBPath = Join-Path $PSScriptRoot "data/world.content"
$AssetDBPath = Join-Path $PSScriptRoot "data/assets.content"
$ItemsDirPath = Join-Path $PSScriptRoot "items"

$BungieNetPlatform = "https://www.bungie.net"
$GearDefinitionUrl = "$BungieNetPlatform/common/destiny2_content/geometry/gear"

Function Get-ItemDefinition {
    Param (
        [Parameter(Mandatory = $true)] [string] $ItemName
    )

    # query world DB
    $filter = "`"name`":`"$ItemName`""
    $query = "
        SELECT * FROM DestinyInventoryItemDefinition
            WHERE json like '%$filter%'
    "
    $results = Invoke-SqliteQuery -DataSource $WorldDBPath -Query $query

    # verify exactly one item was found
    if ($results.id.Count -lt 1) {
        throw "No items found with name '$ItemName'"
    }
    if ($results.id.Count -gt 1) {
        throw "Multiple items found with name '$ItemName'"
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
    $query = "
        SELECT json FROM DestinyGearAssetsDefinition
            WHERE id = '$Id'
    "
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
$item = Get-ItemDefinition $ItemName
$itemDir = Join-Path $ItemsDirPath $ItemName
$itemPath = Join-Path $itemDir "item.json"
New-Item -ItemType Directory -Path $itemDir -Force | Out-Null
$item.Json | Out-File -FilePath $itemPath -Force

# get asset definition
$asset = Get-AssetDefinition $item.Id
$assetPath = Join-Path $itemDir "asset.json"
$asset | Out-File -FilePath $assetPath -Force

# get gear definitions
$assetObj = $asset | ConvertFrom-Json
$gearDir = Join-Path $itemDir "gear"
New-Item -ItemType Directory -Path $gearDir -Force | Out-Null
foreach ($gear in @($assetObj.gear)) {
    $definition = Get-GearDefinition $gear
    $defPath = Join-Path $gearDir "$([System.IO.Path]::GetFileNameWithoutExtension($gear)).json"
    $definition | Out-File -FilePath $defPath -Force
}