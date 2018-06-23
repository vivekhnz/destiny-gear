Param (
    [Parameter(Mandatory = $true)] [string] $ItemName
)

$WorldDBPath = Join-Path $PSScriptRoot "data/world.content"
$ItemsDirPath = Join-Path $PSScriptRoot "items"

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

# verify DBs are accessible
if (!(Test-Path $WorldDBPath)) {
    throw "World DB not found at $WorldDBPath"
}

# import SQLite module
Import-Module PSSQLite

# get item definition
$item = Get-ItemDefinition $ItemName

# save item definition
$itemDir = Join-Path $ItemsDirPath $ItemName
$itemPath = Join-Path $itemDir "item.json"
New-Item -ItemType Directory -Path $itemDir -Force | Out-Null
$item.Json | Out-File -FilePath $itemPath -Force