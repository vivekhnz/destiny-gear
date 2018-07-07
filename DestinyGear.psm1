Add-Type -Assembly System.Drawing

function New-TexturePlate {
    Param (
        [Parameter(Mandatory = $true)] $TextureFolderPath,
        [Parameter(Mandatory = $true)] $Plate
    )

    # composite texture plate
    $bitmap = ([System.Drawing.Bitmap]::new($Plate.plate_size[0], $Plate.plate_size[1]))
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

    foreach ($placement in $Plate.texture_placements) {
        $path = Join-Path $TextureFolderPath "$($placement.texture_tag_name).png"
        $texture = [System.Drawing.Bitmap]::FromFile($path)
        $destination = [System.Drawing.Rectangle]::new(
            $placement.position_x, $placement.position_y,
            $placement.texture_size_x, $placement.texture_size_y)
        $graphics.DrawImage($texture, $destination)
    }

    $graphics.Dispose()
    
    # save to buffer
    $stream = [System.IO.MemoryStream]::new()
    $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
    $buffer = $stream.ToArray()
    $stream.Close()
    
    return $buffer
}

Export-ModuleMember -Function 'New-TexturePlate'