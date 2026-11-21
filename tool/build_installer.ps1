$ErrorActionPreference = 'Stop'

$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$installerRoot = Join-Path $root 'installer'
$appRelease = Join-Path $root 'build\windows\x64\runner\Release'
$installerRelease = Join-Path $installerRoot 'build\windows\x64\runner\Release'
$assetsDirectory = Join-Path $installerRoot 'assets'
$payload = Join-Path $assetsDirectory 'payload.zip'
$distDirectory = Join-Path $root 'dist'
$packageDirectory = Join-Path $distDirectory 'IVPN-Setup'
$packageArchive = Join-Path $distDirectory 'IVPN-Setup-1.0.0.zip'

function Invoke-Flutter([string]$directory, [string[]]$arguments) {
  Push-Location $directory
  try {
    & flutter @arguments
    if ($LASTEXITCODE -ne 0) {
      throw "flutter $($arguments -join ' ') failed with code $LASTEXITCODE"
    }
  }
  finally {
    Pop-Location
  }
}

& (Join-Path $PSScriptRoot 'generate_icon.ps1') -Targets @(
  (Join-Path $root 'windows\runner\resources\app_icon.ico'),
  (Join-Path $installerRoot 'windows\runner\resources\app_icon.ico')
)

Invoke-Flutter $root @('pub', 'get')
Invoke-Flutter $root @('build', 'windows', '--release')

if (-not (Test-Path -LiteralPath (Join-Path $appRelease 'ivpn.exe'))) {
  throw "Application build not found: $appRelease"
}
if (-not (Test-Path -LiteralPath $assetsDirectory)) {
  New-Item -ItemType Directory -Path $assetsDirectory | Out-Null
}
if (Test-Path -LiteralPath $payload) {
  Remove-Item -LiteralPath $payload -Force
}
Compress-Archive -Path "$appRelease\*" -DestinationPath $payload -CompressionLevel Optimal

Invoke-Flutter $installerRoot @('pub', 'get')
Invoke-Flutter $installerRoot @('build', 'windows', '--release')

if (-not (Test-Path -LiteralPath (Join-Path $installerRelease 'ivpn_installer.exe'))) {
  throw "Installer build not found: $installerRelease"
}
if (-not (Test-Path -LiteralPath $distDirectory)) {
  New-Item -ItemType Directory -Path $distDirectory | Out-Null
}
if (Test-Path -LiteralPath $packageDirectory) {
  Remove-Item -LiteralPath $packageDirectory -Recurse -Force
}
New-Item -ItemType Directory -Path $packageDirectory | Out-Null
Copy-Item -Path "$installerRelease\*" -Destination $packageDirectory -Recurse -Force

if (Test-Path -LiteralPath $packageArchive) {
  try {
    Remove-Item -LiteralPath $packageArchive -Force -ErrorAction Stop
  }
  catch {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $packageArchive = Join-Path $distDirectory "IVPN-Setup-1.0.0-$stamp.zip"
    Write-Warning "The previous archive is in use; writing $packageArchive instead."
  }
}
Compress-Archive -Path "$packageDirectory\*" -DestinationPath $packageArchive -CompressionLevel Optimal

Write-Host "Installer folder: $packageDirectory"
Write-Host "Distribution archive: $packageArchive"
