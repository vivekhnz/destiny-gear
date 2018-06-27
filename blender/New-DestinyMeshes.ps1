Param (
    [Parameter(Mandatory = $true)] [string] $FolderPath,
    [Parameter(Mandatory = $true)] [string] $OutputPath
)

$RenderMetadata = Join-Path $FolderPath "render_metadata.js"
$VertexStreamTypes = @{
    "_vertex_format_attribute_float2" = 0;
    "_vertex_format_attribute_float4" = 1;
    "_vertex_format_attribute_short2" = 2;
    "_vertex_format_attribute_short4" = 3;
    "_vertex_format_attribute_ubyte4" = 4
}
$VertexStreamSemantics = @{
    "_tfx_vb_semantic_position" = 0;
    "_tfx_vb_semantic_texcoord" = 1;
    "_tfx_vb_semantic_normal" = 2;
    "_tfx_vb_semantic_tangent" = 3;
    "_tfx_vb_semantic_color" = 4
}

# verify input files are accessible
if (!(Test-Path $RenderMetadata)) {
    throw "Folder not found at $FolderPath"
}

# read render metadata JSON file
$json = Get-Content -Path $RenderMetadata
$metadataObj = $json | ConvertFrom-Json

# add bobs to arrangement
$bobCount = $metadataObj.render_model.render_meshes.Count
$arrangement = [System.BitConverter]::GetBytes($bobCount)
foreach ($bob in $metadataObj.render_model.render_meshes) {

    # calculate bits to be used
    $start = If ($bob.stage_part_offsets.Count > 0) { $bob.stage_part_offsets[0] } Else { 0 }
    $end = If ($bob.stage_part_offsets.Count > 1) { $bob.stage_part_offsets[1] } Else { $bob.stage_part_list.Count - 1 }

    # add bits to arrangement
    $bitCount = $end - $start
    $arrangement += [System.BitConverter]::GetBytes($bitCount)
    for ($i = 0; $i -lt $bitCount; $i++) {
        $bit = $bob.stage_part_list[$i]
        $startIndex = $bit.start_index
        $indexCount = $bit.index_count

        $arrangement += [System.BitConverter]::GetBytes($startIndex)
        $arrangement += [System.BitConverter]::GetBytes($indexCount)
    }

    # add vertex stream definitions to arrangement
    $vertexDefinitions = $bob.stage_part_vertex_stream_layout_definitions[0]
    $vertexDefinitionFormats = $vertexDefinitions.formats
    $arrangement += [System.BitConverter]::GetBytes($vertexDefinitionFormats.Count)
    foreach ($format in $vertexDefinitionFormats) {
        $stride = $format.stride
        $arrangement += [System.BitConverter]::GetBytes($stride)
        $elements = $format.elements
        $arrangement += [System.BitConverter]::GetBytes($elements.Count)

        foreach ($element in $elements) {
            $type = $element.type
            $semantic = $element.semantic
            $size = $element.size
            $offset = $element.offset
            $semanticIndex = $element.semantic_index
            
            $arrangement += [System.BitConverter]::GetBytes($VertexStreamTypes[$type])
            $arrangement += [System.BitConverter]::GetBytes($VertexStreamSemantics[$semantic])
            $arrangement += [System.BitConverter]::GetBytes($size)
            $arrangement += [System.BitConverter]::GetBytes($offset)
            $arrangement += [System.BitConverter]::GetBytes($semanticIndex)
        }
    }

    # add index buffer to arrangement
    $indexBufferName = $bob.index_buffer.file_name
    $indexBufferSize = $bob.index_buffer.byte_size
    $arrangement += [System.BitConverter]::GetBytes($indexBufferSize)
    $arrangement += (Get-Content -Path (Join-Path $FolderPath $indexBufferName) -Encoding Byte -ReadCount 512)
    
    # add vertex buffers to arrangement
    $vertexBufferCount = $bob.vertex_buffers.Count
    $arrangement += [System.BitConverter]::GetBytes($vertexBufferCount)
    foreach ($buffer in $bob.vertex_buffers) {
        $vertexBufferName = $buffer.file_name
        $vertexBufferSize = $buffer.byte_size
    
        $arrangement += [System.BitConverter]::GetBytes($vertexBufferSize)
        $arrangement += (Get-Content -Path (Join-Path $FolderPath $vertexBufferName) -Encoding Byte -ReadCount 512)
    }
}

# save meshes file
$arrangement | Set-Content $OutputPath -Encoding Byte -Force