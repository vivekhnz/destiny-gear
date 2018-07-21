Param (
    [Parameter(Mandatory = $true)] [string] $FolderPath,
    [Parameter(Mandatory = $true)] [string] $TextureFolderPath,
    [Parameter(Mandatory = $true)] [string] $OutputPath
)

Import-Module .\DestinyGear.psm1

$RenderMetadata = Join-Path $FolderPath "render_metadata.js"
$VertexStreamTypes = @{
    "_vertex_format_attribute_float2" = 0
    "_vertex_format_attribute_float4" = 1
    "_vertex_format_attribute_short2" = 2
    "_vertex_format_attribute_short4" = 3
    "_vertex_format_attribute_ubyte4" = 4
}
$VertexStreamSemantics = @{
    "_tfx_vb_semantic_position"     = 0
    "_tfx_vb_semantic_texcoord"     = 1
    "_tfx_vb_semantic_normal"       = 2
    "_tfx_vb_semantic_tangent"      = 3
    "_tfx_vb_semantic_color"        = 4
    "_tfx_vb_semantic_blendweight"  = 5
    "_tfx_vb_semantic_blendindices" = 6
}
$KnownPrimitiveTypes = @(3, 5)

function Get-StageParts {
    Param (
        [Parameter(Mandatory = $true)] $Bob
    )

    $parts = @()
    if ($Bob.stage_part_offsets.Count -eq 0) {
        $parts = $Bob.stage_part_list
    }
    elseif ($Bob.stage_part_offsets.Count -eq 1) {
        $start = $Bob.stage_part_offsets[0]
        $parts = $Bob.stage_part_list[$start..-1]
    }
    else {
        $start = $Bob.stage_part_offsets[0]
        $end = $Bob.stage_part_offsets[1]
        $parts = $Bob.stage_part_list[$start..$end]
    }

    return $parts | Where-Object { $_.lod_category.value -lt 4 }
}

function Write-IndexBuffer {
    Param (
        [Parameter(Mandatory = $true)] [System.IO.BinaryWriter] $Writer,
        [Parameter(Mandatory = $true)] $IndexBuffer
    )
    
    $path = Join-Path $FolderPath $IndexBuffer.file_name
    $data = [System.IO.File]::ReadAllBytes($path)
    
    $Writer.Write($IndexBuffer.byte_size / $IndexBuffer.value_byte_size)
    $Writer.Write($data -as [Byte[]])
}

function Write-VertexBuffer {
    Param (
        [Parameter(Mandatory = $true)] [System.IO.BinaryWriter] $Writer,
        [Parameter(Mandatory = $true)] $VertexBuffer,
        [Parameter(Mandatory = $true)] $Elements
    )
    
    $path = Join-Path $FolderPath $VertexBuffer.file_name
    $data = [System.IO.File]::ReadAllBytes($path)
    
    $Writer.Write($Elements.Count)
    foreach ($element in $Elements) {
        $type = $VertexStreamTypes[$element.type]
        if ($type -eq $null) {
            throw "Unknown stream element type '$($element.type)'."
        }
        
        $semantic = $VertexStreamSemantics[$element.semantic]
        if ($semantic -eq $null) {
            throw "Unknown stream element semantic '$($element.semantic)'."
        }

        $Writer.Write($type)
        $Writer.Write($semantic)
        $Writer.Write($element.semantic_index)
        $Writer.Write($element.normalized)
    }
    $Writer.Write($data)
}

function Write-Bit {
    Param (
        [Parameter(Mandatory = $true)] [System.IO.BinaryWriter] $Writer,
        [Parameter(Mandatory = $true)] $Bit
    )

    $Writer.Write($Bit.start_index)
    $Writer.Write($Bit.start_index + $Bit.index_count)
}

function Write-Bob {
    Param (
        [Parameter(Mandatory = $true)] [System.IO.BinaryWriter] $Writer,
        [Parameter(Mandatory = $true)] $Bob
    )
    
    # write texture coordinate scale and offset
    $texcoordInformation = $Bob.texcoord0_scale_offset
    $Writer.Write($texcoordInformation[0] -as [float])
    $Writer.Write($texcoordInformation[1] -as [float])
    $Writer.Write($texcoordInformation[2] -as [float])
    $Writer.Write($texcoordInformation[3] -as [float])

    $parts = @(Get-StageParts $Bob)
    $Writer.Write($parts.Count)
    if (($parts.Count -eq 0)) {
        return
    }

    $vbCount = $Bob.vertex_buffers.Count
    $layoutCount = $Bob.stage_part_vertex_stream_layout_definitions.formats.Count
    if ($vbCount -eq 0) {
        throw "Bob contains $($parts.Count) bits for the specified LOD but no vertex buffers were included."
    }
    if ($vbCount -gt $layoutCount) {
        throw "Bob contains $vbCount vertex buffers but only $layoutCount stream layouts were defined."
    }

    # identify whether bob is a triangle strip or a triangle list
    $primitiveType = $parts[0].primitive_type
    for ($i = 1; $i -lt $parts.Count; $i++) {
        if ($parts[$i].primitive_type -ne $primitiveType) {
            throw "Bob contains inconsistent primitive types."
        }
    }
    if (-not ($KnownPrimitiveTypes.Contains($primitiveType))) {
        throw "Unknown primitive type '$primitiveType'."
    }

    # determine vertex count
    $firstVB = $Bob.vertex_buffers[0]
    $vertexCount = $firstVB.byte_size / $firstVB.stride_byte_size
    for ($i = 1; $i -lt $vbCount; $i++) {
        $vb = $Bob.vertex_buffers[$i]
        if (($vb.byte_size / $vb.stride_byte_size) -ne $vertexCount) {
            throw "Vertex buffers contain a different number of vertices."
        }
    }

    # write bob header
    $Writer.Write($primitiveType)
    $Writer.Write($vertexCount)

    # write index buffer
    Write-IndexBuffer $Writer $Bob.index_buffer
    
    # write vertex buffers
    $Writer.Write($vbCount)
    for ($i = 0; $i -lt $vbCount; $i++) {
        $vb = $Bob.vertex_buffers[$i]
        $layout = $Bob.stage_part_vertex_stream_layout_definitions.formats[$i].elements
        Write-VertexBuffer $Writer $vb $layout
    }

    # write bits
    foreach ($part in $parts) {
        Write-Bit $Writer $part
    }
}

function Read-Texture {
    Param (
        [Parameter(Mandatory = $true)] [string] $Path
    )

    # open texture
    $bitmap = [System.Drawing.Bitmap]::FromFile($Path)

    # save to buffer
    $stream = [System.IO.MemoryStream]::new()
    $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
    $buffer = $stream.ToArray()
    $stream.Close()

    return $buffer
}

function Write-TexturePlates {
    Param (
        [Parameter(Mandatory = $true)] [System.IO.BinaryWriter] $Writer,
        [Parameter(Mandatory = $true)] $PlateSet
    )
    
    $diffuse = (New-TexturePlate -TextureFolderPath $TextureFolderPath -Plate $PlateSet.diffuse) -as [byte[]]
    $normal = (New-TexturePlate -TextureFolderPath $TextureFolderPath -Plate $PlateSet.normal) -as [byte[]]
    $gearstack = (New-TexturePlate -TextureFolderPath $TextureFolderPath -Plate $PlateSet.gearstack) -as [byte[]]

    Write-Textures $Writer $diffuse $normal $gearstack
}

function Write-StaticTextures {
    Param (
        [Parameter(Mandatory = $true)] [System.IO.BinaryWriter] $Writer,
        [Parameter(Mandatory = $true)] $DiffuseTextureName,
        [Parameter(Mandatory = $true)] $NormalTextureName,
        [Parameter(Mandatory = $true)] $GearstackTextureName
    )

    $diffuse = (Read-Texture (Join-Path $TextureFolderPath "$($DiffuseTextureName).png")) -as [byte[]]
    $normal = (Read-Texture (Join-Path $TextureFolderPath "$($NormalTextureName).png")) -as [byte[]]    
    $gearstack = (Read-Texture (Join-Path $TextureFolderPath "$($GearstackTextureName).png")) -as [byte[]]

    Write-Textures $Writer $diffuse $normal $gearstack
}

function Write-Textures {
    Param (
        [Parameter(Mandatory = $true)] [System.IO.BinaryWriter] $Writer,
        [Parameter(Mandatory = $true)] [byte[]] $DiffuseTexture,
        [Parameter(Mandatory = $true)] [byte[]] $NormalTexture,
        [Parameter(Mandatory = $true)] [byte[]] $GearstackTexture
    )

    $Writer.Write($DiffuseTexture.Count)
    $Writer.Write($DiffuseTexture)
    
    $Writer.Write($NormalTexture.Count)
    $Writer.Write($NormalTexture)
    
    $Writer.Write($GearstackTexture.Count)
    $Writer.Write($GearstackTexture)
}

function Write-Arrangement {
    Param (
        [Parameter(Mandatory = $true)] [System.IO.BinaryWriter] $Writer,
        [Parameter(Mandatory = $true)] $Arrangement
    )

    # write bobs
    $Writer.Write($Arrangement.render_model.render_meshes.Count)
    foreach ($bob in $Arrangement.render_model.render_meshes) {
        Write-Bob $Writer $bob
    }

    # write arrangement ID
    $folderStructure = $FolderPath.Split([System.IO.Path]::DirectorySeparatorChar)
    $arrangementId = $folderStructure[$folderStructure.Count - 1]
    $Writer.Write($arrangementId.Trim())

    # write textures
    if ($Arrangement.texture_plates.Count -eq 1) {
        $Writer.Write(1)
        Write-TexturePlates $Writer $Arrangement.texture_plates[0].plate_set
    }
    else {
        $hasStaticTextures = $false
        if ($Arrangement.render_model.render_meshes.Count -gt 0) {
            $renderMesh = $Arrangement.render_model.render_meshes[0]
            $stagePartCount = $renderMesh.stage_part_list.Count
            for ($i = 0; $i -lt $stagePartCount; $i++) {
                $stagePart = $renderMesh.stage_part_list[$i]
                $shader = $stagePart.shader
                if (($shader -ne $null) -and ($shader.static_textures -ne $null)) {
                    $staticTextures = $shader.static_textures
                    if ($staticTextures.Count -ge 5) {
                        $staticTextureIdDiffuse = $staticTextures[1]
                        $staticTextureIdNormal = $staticTextures[3]
                        $staticTextureIdGearstack = $staticTextures[2]
                        
                        if (($staticTextureIdDiffuse -ne $null) -and ($staticTextureIdNormal -ne $null) -and ($staticTextureIdGearstack -ne $null)) {
                            $Writer.Write(1)
                            Write-StaticTextures $Writer $staticTextureIdDiffuse $staticTextureIdNormal $staticTextureIdGearstack
                            $hasStaticTextures = $true
                            break
                        }
                    }
                }
            }
            if (!($hasStaticTextures)) {
                $Writer.Write(0)
            }
        }
        else {
            $Writer.Write(0)
        }
    }
}

# verify input files are accessible
if (!(Test-Path $RenderMetadata)) {
    throw "Folder not found at $FolderPath"
}

# read render metadata JSON file
$json = Get-Content -Path $RenderMetadata
$metadataObj = $json | ConvertFrom-Json

$arrangements = @(
    $metadataObj
)

# save meshes file
$stream = New-Object System.IO.FileStream($OutputPath, [IO.FileMode]::OpenOrCreate)
$writer = New-Object System.IO.BinaryWriter($stream)

$Writer.Write($arrangements.Count)
foreach ($arrangement in $arrangements) {
    Write-Arrangement $writer $arrangement
}

$writer.Close()
$stream.Close()