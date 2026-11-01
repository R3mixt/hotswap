# Original Hot Swap vector artwork. Rebuild both assets without external packages.
# Requires Windows PowerShell or PowerShell on Windows with System.Drawing.
# From the repository root:
# powershell -NoProfile -ExecutionPolicy Bypass -File work/publishing/build-logo.ps1
# The process-only execution policy permits this local script without changing
# the machine or user's persisted policy.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

# One shape list drives the SVG source and the supersampled PNG. Letters are
# original paths, not font glyphs. Supported path commands: M, L, C, Z.
$shapes = @(
    @{ Fill = '#101416'; D = 'M 0 0 L 400 0 L 400 400 L 0 400 Z' },
    @{ Fill = '#080B0C'; D = 'M 82 62 L 318 62 C 334 62 346 74 346 90 L 346 324 C 346 340 334 352 318 352 L 82 352 C 66 352 54 340 54 324 L 54 90 C 54 74 66 62 82 62 Z' },
    @{ Fill = '#887247'; D = 'M 82 48 L 318 48 C 334 48 346 60 346 76 L 346 310 C 346 326 334 338 318 338 L 82 338 C 66 338 54 326 54 310 L 54 76 C 54 60 66 48 82 48 Z' },
    @{ Fill = '#242A2B'; D = 'M 83 51 L 317 51 C 332 51 343 62 343 77 L 343 309 C 343 324 332 335 317 335 L 83 335 C 68 335 57 324 57 309 L 57 77 C 57 62 68 51 83 51 Z' },
    @{ Fill = '#3B3C33'; D = 'M 84 53 L 316 53 C 329 53 340 64 341 77 L 321 89 L 79 89 L 59 77 C 60 64 71 53 84 53 Z' },
    @{ Fill = '#151A1C'; D = 'M 79 295 L 321 295 L 340 311 C 338 323 329 332 316 332 L 84 332 C 71 332 62 323 60 311 Z' },
    @{ Fill = '#B99A5B'; D = 'M 91 70 L 309 70 C 319 70 327 78 327 88 L 327 293 C 327 303 319 311 309 311 L 91 311 C 81 311 73 303 73 293 L 73 88 C 73 78 81 70 91 70 Z' },
    @{ Fill = '#1B2122'; D = 'M 92 73 L 308 73 C 317 73 324 80 324 89 L 324 292 C 324 301 317 308 308 308 L 92 308 C 83 308 76 301 76 292 L 76 89 C 76 80 83 73 92 73 Z' },
    @{ Fill = '#B99A5B'; D = 'M 119 110 L 261 110 L 250 99 L 257 92 L 284 119 L 257 146 L 250 139 L 261 128 L 119 128 Z' },
    @{ Fill = '#E3C47F'; D = 'M 105 155 L 128 155 L 128 188 L 159 188 L 159 155 L 182 155 L 182 246 L 159 246 L 159 210 L 128 210 L 128 246 L 105 246 Z' },
    @{ Fill = '#E3C47F'; D = 'M 221 155 L 285 155 L 285 176 L 235 176 L 235 189 L 275 189 L 286 200 L 286 235 L 275 246 L 211 246 L 211 225 L 263 225 L 263 211 L 223 211 L 212 200 L 212 166 Z' },
    @{ Fill = '#B99A5B'; D = 'M 281 273 L 139 273 L 150 262 L 143 255 L 116 282 L 143 309 L 150 302 L 139 291 L 281 291 Z' }
)

$svgLines = @(
    '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="400" viewBox="0 0 400 400" role="img" aria-labelledby="title desc">',
    '  <title id="title">Hot Swap</title>',
    '  <desc id="desc">Original gold HS keycap with opposing swap arrows on a charcoal background.</desc>'
)
foreach ($shape in $shapes) {
    $svgLines += '  <path fill="{0}" d="{1}"/>' -f $shape.Fill, $shape.D
}
$svgLines += '</svg>'
$svgPath = Join-Path $PSScriptRoot 'logo.svg'
[IO.File]::WriteAllText($svgPath, ($svgLines -join "`n") + "`n", [Text.UTF8Encoding]::new($false))

function ConvertTo-DrawingPath([string]$Data) {
    $path = [Drawing.Drawing2D.GraphicsPath]::new()
    $tokens = [regex]::Matches($Data, '[MLCZ]|-?\d+(?:\.\d+)?')
    $position = 0
    [single]$currentX = 0
    [single]$currentY = 0
    while ($position -lt $tokens.Count) {
        $command = $tokens[$position++].Value
        switch ($command) {
            'M' {
                $path.StartFigure()
                $currentX = [single]::Parse($tokens[$position++].Value, [Globalization.CultureInfo]::InvariantCulture)
                $currentY = [single]::Parse($tokens[$position++].Value, [Globalization.CultureInfo]::InvariantCulture)
            }
            'L' {
                $x = [single]::Parse($tokens[$position++].Value, [Globalization.CultureInfo]::InvariantCulture)
                $y = [single]::Parse($tokens[$position++].Value, [Globalization.CultureInfo]::InvariantCulture)
                $path.AddLine($currentX, $currentY, $x, $y)
                $currentX = $x; $currentY = $y
            }
            'C' {
                $values = @()
                for ($index = 0; $index -lt 6; $index++) {
                    $values += [single]::Parse($tokens[$position++].Value, [Globalization.CultureInfo]::InvariantCulture)
                }
                $path.AddBezier($currentX, $currentY, $values[0], $values[1], $values[2], $values[3], $values[4], $values[5])
                $currentX = $values[4]; $currentY = $values[5]
            }
            'Z' { $path.CloseFigure() }
            default { throw "Unsupported path command: $command" }
        }
    }
    return ,$path
}

$large = [Drawing.Bitmap]::new(1600, 1600, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [Drawing.Graphics]::FromImage($large)
$output = $null
$downsample = $null
try {
    $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.ScaleTransform(4, 4)
    foreach ($shape in $shapes) {
        $path = ConvertTo-DrawingPath $shape.D
        $brush = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml($shape.Fill))
        try { $graphics.FillPath($brush, $path) }
        finally { $brush.Dispose(); $path.Dispose() }
    }
    $output = [Drawing.Bitmap]::new(400, 400, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $downsample = [Drawing.Graphics]::FromImage($output)
    $downsample.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $downsample.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $downsample.DrawImage($large, 0, 0, 400, 400)
    $pngPath = Join-Path $PSScriptRoot 'logo.png'
    $output.Save($pngPath, [Drawing.Imaging.ImageFormat]::Png)
    Write-Output "Built logo.svg and logo.png (400 x 400)."
}
finally {
    if ($downsample) { $downsample.Dispose() }
    if ($output) { $output.Dispose() }
    $graphics.Dispose()
    $large.Dispose()
}
