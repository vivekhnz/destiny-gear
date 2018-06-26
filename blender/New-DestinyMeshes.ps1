Param (
    [Parameter(Mandatory = $true)] [string] $FolderPath,
    [Parameter(Mandatory = $true)] [string] $OutputPath
)

$RenderMetadata = Join-Path $FolderPath "render_metadata.js"

# verify input files are accessible
if (!(Test-Path $RenderMetadata)) {
    throw "Folder not found at $FolderPath"
}

# read render metadata JSON file
$json = Get-Content -Path $RenderMetadata
$metadataObj = $json | ConvertFrom-Json

# add bob count to arrangement
$bobCount = $metadataObj.render_model.render_meshes.Count
$arrangement = [System.BitConverter]::GetBytes($bobCount)

# iterate through bobs
foreach ($bob in $metadataObj.render_model.render_meshes) {

    # add bit count to arrangement
    $bitCount = $bob.stage_part_list.Count
    $arrangement += [System.BitConverter]::GetBytes($bitCount)

    # iterate through bits
    foreach ($bit in $bob.stage_part_list) {
        # add bit index data to arrangement
        $startIndex = $bit.start_index
        $indexCount = $bit.index_count

        $arrangement += [System.BitConverter]::GetBytes($startIndex)
        $arrangement += [System.BitConverter]::GetBytes($indexCount)
    }

    # add index buffer to arrangement
    $indexBufferName = $bob.index_buffer.file_name
    $indexBufferSize = $bob.index_buffer.byte_size

    $arrangement += [System.BitConverter]::GetBytes($indexBufferSize)
    $arrangement += (Get-Content -Path (Join-Path $FolderPath $indexBufferName) -Encoding Byte -ReadCount 512)
    
    # add vertex buffer to arrangement
    $vertexBufferName = $bob.vertex_buffers[0].file_name
    $vertexBufferSize = $bob.vertex_buffers[0].byte_size
    
    $arrangement += [System.BitConverter]::GetBytes($vertexBufferSize)
    $arrangement += (Get-Content -Path (Join-Path $FolderPath $vertexBufferName) -Encoding Byte -ReadCount 512)
}

# save meshes file
$arrangement | Set-Content $OutputPath -Encoding Byte -Force