param([string[]]$Pages, [ValidateRange(1,3)][int]$Scale = 2)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$iconManifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'icons/manifest.json') -Raw | ConvertFrom-Json
$iconImages = @{}
function Draw-GameIcon($graphics,$rect,$node) {
    $name = [string]$node.icon
    if ($name -notmatch '^[a-z0-9_]+$') { throw "Unsafe icon name: $name" }
    if (-not $iconImages.ContainsKey($name)) {
        $asset = $iconManifest.assets.PSObject.Properties[$name].Value
        $path = Join-Path $PSScriptRoot ".cache/icons/$name.jpg"
        if (-not $asset -or -not (Test-Path -LiteralPath $path) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $asset.sha256) {
            throw "Missing or changed icon $name. Run python ui-qa/icon_assets.py --fetch before rendering."
        }
        $iconImages[$name] = [System.Drawing.Image]::FromFile($path)
    }
    $art = $iconImages[$name]
    $uv = if ($node.texCoord -and $node.texCoord.Count -eq 4) { $node.texCoord } else { @(0,1,0,1) }
    $tint = if ($node.vertexColor) { $node.vertexColor } else { @(1,1,1,1) }
    $matrix = [System.Drawing.Imaging.ColorMatrix]::new()
    $matrix.Matrix00 = [single]$tint[0]; $matrix.Matrix11 = [single]$tint[1]; $matrix.Matrix22 = [single]$tint[2]
    if ($node.desaturated) {
        $matrix.Matrix00 = 0.2126*$tint[0]; $matrix.Matrix01 = 0.2126*$tint[1]; $matrix.Matrix02 = 0.2126*$tint[2]
        $matrix.Matrix10 = 0.7152*$tint[0]; $matrix.Matrix11 = 0.7152*$tint[1]; $matrix.Matrix12 = 0.7152*$tint[2]
        $matrix.Matrix20 = 0.0722*$tint[0]; $matrix.Matrix21 = 0.0722*$tint[1]; $matrix.Matrix22 = 0.0722*$tint[2]
    }
    $matrix.Matrix33 = [single]$node.alpha * $(if ($tint.Count -gt 3) { [single]$tint[3] } else { 1 })
    $attributes = [System.Drawing.Imaging.ImageAttributes]::new()
    $attributes.SetColorMatrix($matrix)
    $graphics.DrawImage($art,[System.Drawing.Rectangle]::Round($rect),[single]($uv[0]*$art.Width),[single]($uv[2]*$art.Height),[single](($uv[1]-$uv[0])*$art.Width),[single](($uv[3]-$uv[2])*$art.Height),[System.Drawing.GraphicsUnit]::Pixel,$attributes)
    $attributes.Dispose()
}
function New-QAColor($values) {
    if ($null -eq $values) { return [System.Drawing.Color]::White }
    $alpha = if ($values.Count -gt 3) { [int]($values[3] * 255) } else { 255 }
    return [System.Drawing.Color]::FromArgb($alpha, [int]($values[0]*255), [int]($values[1]*255), [int]($values[2]*255))
}
# Window chrome is approximated; spell/item artwork is loaded from verified game icons.
function Draw-QABevel($graphics, $rect, $top, $bottom, $edge) {
    $brush = [System.Drawing.Drawing2D.LinearGradientBrush]::new($rect, $top, $bottom, [System.Drawing.Drawing2D.LinearGradientMode]::Vertical)
    $graphics.FillRectangle($brush, $rect)
    $brush.Dispose()
    $pen = [System.Drawing.Pen]::new($edge, 2)
    $graphics.DrawRectangle($pen,$rect.X+1,$rect.Y+1,$rect.Width-2,$rect.Height-2)
    $pen.Dispose()
    $pen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(140,145,130,102),1)
    $graphics.DrawLine($pen,$rect.X+2,$rect.Y+2,$rect.Right-3,$rect.Y+2)
    $pen.Dispose()
}
if (-not $Pages) {
    $Pages = @('setup','presets','bindings','bindings-shift','bindings-cat','bindings-test','items','safety','share','library-spells','library-ranks','library-items','library-macros','action-bars','settings','settings-controls','settings-bars','settings-window','settings-diagnostics','diagnostic-log','operation-error','talent-choices','talent-own','hover-bind','bindings-current','bindings-recommendation','save-preset','current-hover')
    foreach ($theme in @('classic','modern')) {
        foreach ($view in @('current','presets','settings','spellbook','movement','camera')) {
            if (Test-Path -LiteralPath (Join-Path $PSScriptRoot "$theme-$view.json")) { $Pages += "$theme-$view" }
        }
    }
}
foreach ($pageName in $Pages) {
    $nodes = Get-Content -LiteralPath (Join-Path $PSScriptRoot "$pageName.json") -Raw | ConvertFrom-Json
    $canvasWidth = [int][Math]::Ceiling(($nodes | ForEach-Object { $_.clip[0]+$_.clip[2] } | Measure-Object -Maximum).Maximum)
    $contentHeight = [int][Math]::Ceiling(($nodes | ForEach-Object { $_.clip[1]+$_.clip[3] } | Measure-Object -Maximum).Maximum)
    $bitmap = [System.Drawing.Bitmap]::new($canvasWidth*$Scale, ($contentHeight+32)*$Scale)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.ScaleTransform($Scale,$Scale)
    $graphics.Clear([System.Drawing.Color]::FromArgb(14,17,20))
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    foreach ($node in $nodes) {
        if ($node.w -le 0 -or $node.h -le 0 -or $node.clip[2] -le 0 -or $node.clip[3] -le 0) { continue }
        $clip = [System.Drawing.RectangleF]::new([single]$node.clip[0],[single]$node.clip[1],[single]$node.clip[2],[single]$node.clip[3])
        $rect = [System.Drawing.RectangleF]::new([single]$node.x,[single]$node.y,[single]$node.w,[single]$node.h)
        $graphics.SetClip($clip)
        $nativeArtwork = $node.theme -ne 'modern' -or -not $node.themeRole
        if ($node.fill -and -not $node.backdrop) {
            $brush = [System.Drawing.SolidBrush]::new((New-QAColor $node.fill))
            $graphics.FillRectangle($brush, $rect)
            $brush.Dispose()
        }
        if ($node.keycap -and -not $node.backdrop -and $nativeArtwork) {
            Draw-QABevel $graphics $rect ([System.Drawing.Color]::FromArgb(37,34,27)) ([System.Drawing.Color]::FromArgb(15,14,10)) ([System.Drawing.Color]::FromArgb(96,84,58))
        }
        if ($node.icon) { Draw-GameIcon $graphics $rect $node }
        if ($node.unresolvedTexture -or $node.texture -like 'QA:*') { throw 'Unresolved placeholder texture in capture. Regenerate with verified icon metadata.' }
        if ($node.theme -eq 'modern' -and $node.backdrop -and $node.fill) {
            $brush = [System.Drawing.SolidBrush]::new((New-QAColor $node.fill))
            $graphics.FillRectangle($brush, $rect)
            $brush.Dispose()
        }
        if ($nativeArtwork -and ($node.backdrop -or $node.template -match 'BasicFrameTemplate|InsetFrameTemplate')) {
            Draw-QABevel $graphics $rect ([System.Drawing.Color]::FromArgb(30,27,22)) ([System.Drawing.Color]::FromArgb(13,12,10)) ([System.Drawing.Color]::FromArgb(89,80,62))
            if ($node.template -eq 'BasicFrameTemplateWithInset') {
                $titleRect=[System.Drawing.RectangleF]::new($rect.X+4,$rect.Y+3,$rect.Width-8,22)
                Draw-QABevel $graphics $titleRect ([System.Drawing.Color]::FromArgb(57,50,40)) ([System.Drawing.Color]::FromArgb(23,21,17)) ([System.Drawing.Color]::FromArgb(100,88,65))
            }
        }
        if ($nativeArtwork -and $node.template -match 'UIPanelButtonTemplate|UIPanelCloseButton') {
            $light=if ($node.enabled) { [System.Drawing.Color]::FromArgb(115,24,17) } else { [System.Drawing.Color]::FromArgb(45,41,36) }
            Draw-QABevel $graphics $rect $light ([System.Drawing.Color]::FromArgb(42,10,7)) ([System.Drawing.Color]::FromArgb(123,104,70))
            if ($node.template -eq 'UIPanelCloseButton') {
                $pen=[System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(233,196,123),2)
                $graphics.DrawLine($pen,$rect.X+8,$rect.Y+7,$rect.Right-7,$rect.Bottom-7)
                $graphics.DrawLine($pen,$rect.Right-7,$rect.Y+7,$rect.X+8,$rect.Bottom-7)
                $pen.Dispose()
            }
        }
        if ($nativeArtwork -and $node.template -match 'CharacterFrameTab|PanelTabButtonTemplate') {
            $light=if ($node.selected) { [System.Drawing.Color]::FromArgb(79,67,46) } else { [System.Drawing.Color]::FromArgb(42,37,29) }
            Draw-QABevel $graphics $rect $light ([System.Drawing.Color]::FromArgb(23,20,16)) ([System.Drawing.Color]::FromArgb(100,85,58))
        }
        if ($nativeArtwork -and $node.template -eq 'OptionsSliderTemplate') {
            $track=[System.Drawing.RectangleF]::new($rect.X,$rect.Y+6,$rect.Width,6)
            Draw-QABevel $graphics $track ([System.Drawing.Color]::FromArgb(20,18,15)) ([System.Drawing.Color]::FromArgb(42,36,26)) ([System.Drawing.Color]::FromArgb(115,99,66))
        }
        if ($null -ne $node.sliderOwner) {
            if ($node.theme -eq 'modern') {
                $thumbColor = if ($node.fill) { $node.fill } else { $node.vertexColor }
                $brush = [System.Drawing.SolidBrush]::new((New-QAColor $thumbColor))
                $graphics.FillRectangle($brush,$rect)
                $brush.Dispose()
            } else {
                Draw-QABevel $graphics $rect ([System.Drawing.Color]::FromArgb(162,136,82)) ([System.Drawing.Color]::FromArgb(80,66,39)) ([System.Drawing.Color]::FromArgb(202,173,112))
            }
        }
        if ($nativeArtwork -and $node.template -eq 'InputBoxTemplate') {
            Draw-QABevel $graphics $rect ([System.Drawing.Color]::FromArgb(8,7,5)) ([System.Drawing.Color]::FromArgb(20,17,12)) ([System.Drawing.Color]::FromArgb(93,81,59))
        }
        if ($nativeArtwork -and $node.template -eq 'UICheckButtonTemplate') {
            $square=[System.Drawing.RectangleF]::new($rect.X+4,$rect.Y+4,$rect.Width-8,$rect.Height-8)
            Draw-QABevel $graphics $square ([System.Drawing.Color]::FromArgb(5,4,3)) ([System.Drawing.Color]::FromArgb(38,30,18)) ([System.Drawing.Color]::FromArgb(128,106,60))
            if ($node.checked) {
                $pen=[System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255,213,62),2)
                $graphics.DrawLine($pen,$square.X+3,$square.Y+8,$square.X+7,$square.Y+13)
                $graphics.DrawLine($pen,$square.X+7,$square.Y+13,$square.Right-1,$square.Y+3)
                $pen.Dispose()
            }
        }
        if ($node.border) {
            $pen = [System.Drawing.Pen]::new((New-QAColor $node.border), 1)
            $graphics.DrawRectangle($pen, $rect.X, $rect.Y, $rect.Width, $rect.Height)
            $pen.Dispose()
        }
        if (($node.kind -eq 'FontString' -or $node.kind -eq 'EditBox') -and $node.text) {
            $fontFamily = if ($node.fontpath -match 'ARIAL') { 'Segoe UI' } else { 'Georgia' }
            $font = [System.Drawing.Font]::new($fontFamily, [single]$node.font, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
            $brush = [System.Drawing.SolidBrush]::new((New-QAColor $node.color))
            $format = [System.Drawing.StringFormat]::new()
            $format.Trimming = [System.Drawing.StringTrimming]::EllipsisCharacter
            $format.Alignment = if ($node.justify -eq 'CENTER') { [System.Drawing.StringAlignment]::Center } elseif ($node.justify -eq 'RIGHT') { [System.Drawing.StringAlignment]::Far } else { [System.Drawing.StringAlignment]::Near }
            $format.LineAlignment = if ($node.justifyV -eq 'MIDDLE' -or $node.justifyV -eq 'CENTER') { [System.Drawing.StringAlignment]::Center } elseif ($node.justifyV -eq 'BOTTOM') { [System.Drawing.StringAlignment]::Far } else { [System.Drawing.StringAlignment]::Near }
            if (-not $node.wrap) { $format.FormatFlags = [System.Drawing.StringFormatFlags]::NoWrap }
            $plainText = [string]$node.text -replace '\|c[0-9a-fA-F]{8}|\|r',''
            $graphics.DrawString($plainText, $font, $brush, $rect, $format)
            $format.Dispose(); $brush.Dispose(); $font.Dispose()
        }
    }
    $graphics.ResetClip()
    $font = [System.Drawing.Font]::new('Segoe UI', 11, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $brush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(170,180,187))
    $graphics.DrawString('OFFLINE PREVIEW  /  Actual addon UI + real spell icons  /  Sample data; approximate window artwork and fonts', $font, $brush, 12, $contentHeight+11)
    $bitmap.Save((Join-Path $PSScriptRoot "$pageName.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    if ($pageName -match '^(classic|modern)-') {
        $deliverables = Join-Path (Split-Path $PSScriptRoot -Parent) 'review/themes'
        New-Item -ItemType Directory -Path $deliverables -Force | Out-Null
        $bitmap.Save((Join-Path $deliverables "$pageName.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    }
    $brush.Dispose(); $font.Dispose(); $graphics.Dispose(); $bitmap.Dispose()
    Write-Output "Rendered $pageName.png"
}
foreach ($art in $iconImages.Values) { $art.Dispose() }

# A review sheet uses the rendered widgets above, with a title outside the UI.
# It is deliberately labeled so this cannot be mistaken for a game capture.
if (($Pages -contains 'classic-current') -and ($Pages -contains 'modern-current')) {
    $classic = [System.Drawing.Image]::FromFile((Join-Path $PSScriptRoot 'classic-current.png'))
    $modern = [System.Drawing.Image]::FromFile((Join-Path $PSScriptRoot 'modern-current.png'))
    $sheet = [System.Drawing.Bitmap]::new(1260*$Scale,1520*$Scale)
    $g = [System.Drawing.Graphics]::FromImage($sheet)
    $g.ScaleTransform($Scale,$Scale)
    $g.Clear([System.Drawing.Color]::FromArgb(11,16,24))
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $heading = [System.Drawing.Font]::new('Segoe UI',29,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
    $body = [System.Drawing.Font]::new('Segoe UI',15,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
    $white = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(233,240,248))
    $muted = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(148,163,184))
    $g.DrawString('HOT SWAP  /  Choose your look', $heading,$white,40,25)
    $g.DrawString('Same bindings. Two themes. Rendered from the addon without opening World of Warcraft.', $body,$muted,40,69)
    $g.DrawString('CLASSIC  /  Familiar gold accents and game-style controls', $body,$white,40,111)
    $g.DrawImage($classic,[System.Drawing.Rectangle]::new(40,145,1180,652))
    $g.DrawString('MODERN  /  Slate panels, clear type and cool accents', $body,$white,40,822)
    $g.DrawImage($modern,[System.Drawing.Rectangle]::new(40,856,1180,652))
    $sheet.Save((Join-Path $PSScriptRoot 'theme-comparison.png'),[System.Drawing.Imaging.ImageFormat]::Png)
    $sheet.Save((Join-Path $deliverables 'theme-comparison.png'),[System.Drawing.Imaging.ImageFormat]::Png)
    $classic.Dispose();$modern.Dispose();$heading.Dispose();$body.Dispose();$white.Dispose();$muted.Dispose();$g.Dispose();$sheet.Dispose()
    Write-Output 'Rendered theme-comparison.png'
}
