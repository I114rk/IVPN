param(
  [string[]]$Targets = @(
    "$PSScriptRoot\..\windows\runner\resources\app_icon.ico"
  ),
  [string]$Preview = "$PSScriptRoot\..\build\icon_preview.png",
  [string]$AndroidRes = "$PSScriptRoot\..\android\app\src\main\res"
)

Add-Type -AssemblyName System.Drawing

$size = 256
$bitmap = New-Object System.Drawing.Bitmap($size, $size)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$graphics.Clear([System.Drawing.Color]::Transparent)

$rect = New-Object System.Drawing.Rectangle(8, 8, 240, 240)
$radius = 58
$diameter = $radius * 2
$background = New-Object System.Drawing.Drawing2D.GraphicsPath
$background.AddArc($rect.X, $rect.Y, $diameter, $diameter, 180, 90)
$background.AddArc($rect.Right - $diameter, $rect.Y, $diameter, $diameter, 270, 90)
$background.AddArc($rect.Right - $diameter, $rect.Bottom - $diameter, $diameter, $diameter, 0, 90)
$background.AddArc($rect.X, $rect.Bottom - $diameter, $diameter, $diameter, 90, 90)
$background.CloseFigure()

$startColor = [System.Drawing.Color]::FromArgb(255, 103, 80, 164)
$endColor = [System.Drawing.Color]::FromArgb(255, 0, 106, 106)
$gradient = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $startColor, $endColor, 45)
$graphics.FillPath($gradient, $background)

$shield = New-Object System.Drawing.Drawing2D.GraphicsPath
$shield.AddLine(128, 48, 192, 76)
$shield.AddLine(192, 76, 192, 130)
$shield.AddBezier(192, 130, 192, 172, 161, 200, 128, 214)
$shield.AddBezier(128, 214, 95, 200, 64, 172, 64, 130)
$shield.AddLine(64, 130, 64, 76)
$shield.CloseFigure()

$shieldBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(246, 255, 255, 255))
$graphics.FillPath($shieldBrush, $shield)

$checkPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 74, 61, 143), 17)
$checkPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$checkPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$checkPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$checkPoints = [System.Drawing.Point[]]@(
  [System.Drawing.Point]::new(98, 132),
  [System.Drawing.Point]::new(121, 155),
  [System.Drawing.Point]::new(162, 108)
)
$graphics.DrawLines($checkPen, [System.Drawing.Point[]]$checkPoints)

$graphics.Dispose()

$previewDirectory = Split-Path -Parent $Preview
if (-not (Test-Path -LiteralPath $previewDirectory)) {
  New-Item -ItemType Directory -Force -Path $previewDirectory | Out-Null
}
$bitmap.Save($Preview, [System.Drawing.Imaging.ImageFormat]::Png)

function Convert-ToPngBytes([System.Drawing.Bitmap]$source, [int]$targetSize) {
  $scaled = New-Object System.Drawing.Bitmap($targetSize, $targetSize)
  $g = [System.Drawing.Graphics]::FromImage($scaled)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.Clear([System.Drawing.Color]::Transparent)
  $g.DrawImage($source, 0, 0, $targetSize, $targetSize)
  $g.Dispose()
  $stream = New-Object System.IO.MemoryStream
  $scaled.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
  $bytes = $stream.ToArray()
  $stream.Dispose()
  $scaled.Dispose()
  return $bytes
}

$sizes = @(16, 24, 32, 48, 64, 128, 256)
$entries = @()
foreach ($targetSize in $sizes) {
  $entries += [PSCustomObject]@{
    Size  = $targetSize
    Bytes = (Convert-ToPngBytes $bitmap $targetSize)
  }
}

$androidIcons = [ordered]@{
  'mipmap-mdpi'    = 48
  'mipmap-hdpi'    = 72
  'mipmap-xhdpi'   = 96
  'mipmap-xxhdpi'  = 144
  'mipmap-xxxhdpi' = 192
}
foreach ($directoryName in $androidIcons.Keys) {
  $directory = Join-Path $AndroidRes $directoryName
  if (-not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }
  $iconPath = Join-Path $directory 'ic_launcher.png'
  $pngBytes = Convert-ToPngBytes $bitmap $androidIcons[$directoryName]
  [System.IO.File]::WriteAllBytes($iconPath, $pngBytes)
  Write-Host "Android icon written: $iconPath"
}

$bitmap.Dispose()

function Write-Ico([string]$path, $pngEntries) {
  $directory = Split-Path -Parent $path
  if (-not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }
  $stream = New-Object System.IO.MemoryStream
  $writer = New-Object System.IO.BinaryWriter($stream)
  $writer.Write([UInt16]0)
  $writer.Write([UInt16]1)
  $writer.Write([UInt16]$pngEntries.Count)
  $offset = 6 + 16 * $pngEntries.Count
  foreach ($entry in $pngEntries) {
    $dimension = if ($entry.Size -ge 256) { 0 } else { $entry.Size }
    $writer.Write([byte]$dimension)
    $writer.Write([byte]$dimension)
    $writer.Write([byte]0)
    $writer.Write([byte]0)
    $writer.Write([UInt16]1)
    $writer.Write([UInt16]32)
    $writer.Write([UInt32]$entry.Bytes.Length)
    $writer.Write([UInt32]$offset)
    $offset += $entry.Bytes.Length
  }
  foreach ($entry in $pngEntries) {
    [byte[]]$imageBytes = $entry.Bytes
    $writer.Write($imageBytes)
  }
  $writer.Flush()
  [System.IO.File]::WriteAllBytes($path, $stream.ToArray())
  $writer.Dispose()
  $stream.Dispose()
}

foreach ($target in $Targets) {
  Write-Ico $target $entries
  Write-Host "Icon written: $target"
}
Write-Host "Preview written: $Preview"
