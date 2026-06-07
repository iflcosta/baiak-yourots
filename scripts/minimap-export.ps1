<#
.SYNOPSIS
    Regenerate OTClient minimap sector PNGs from the latest RME export.

.DESCRIPTION
    Assumes:
      - tools/rme-clientid/Editor_x64.exe (RME prebuilt) is installed
      - server/data/world/world.otbm is open in RME
    Workflow:
      1. Launch RME headless to export 16 minimap_*.bmp into server/data/world/
      2. Run server/tools/rme_bmp_to_png.py to slice BMPs into X_Y_Z.png sectors
      3. Print the OTClient factory-reset commands the user must run
         (Stop-Process AstraClient; Remove-Item $env:APPDATA\AstraClient)

.EXAMPLE
    .\scripts\minimap-export.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$RepoRoot   = (Resolve-Path "$PSScriptRoot\..").Path
$RmeExe     = Join-Path $RepoRoot 'tools\rme-clientid\Editor_x64.exe'
$WorldDir   = Join-Path $RepoRoot 'server\data\world'
$Otbm       = Join-Path $WorldDir 'world.otbm'
$Script     = Join-Path $RepoRoot 'server\tools\rme_bmp_to_png.py'
$Python     = 'C:\Users\Iago\AppData\Local\Programs\Python\Python312\python.exe'

if (-not (Test-Path $RmeExe)) { throw "RME not found at $RmeExe" }
if (-not (Test-Path $Otbm)) { throw "world.otbm not found at $Otbm" }
if (-not (Test-Path $Script)) { throw "Converter not found at $Script" }

# 1) Export BMPs from RME ---------------------------------------------------
# RME has no headless mode; this is a manual step. Print instructions.
Write-Host "==> Step 1: Export BMPs from RME" -ForegroundColor Cyan
Write-Host "    1. Launch:  $RmeExe"
Write-Host "    2. File -> Open -> $Otbm"
Write-Host "    3. File -> Export -> Minimap (16 files minimap_0.bmp ... minimap_15.bmp)"
Write-Host "    4. Press Enter here when done."
Read-Host

# 2) Slice BMPs into PNG sectors -------------------------------------------
Write-Host "==> Step 2: Slicing BMPs into PNG sectors" -ForegroundColor Cyan
& $Python $Script
if ($LASTEXITCODE -ne 0) { throw "rme_bmp_to_png.py failed (exit $LASTEXITCODE)" }

# 3) Print factory-reset commands ------------------------------------------
Write-Host ""
Write-Host "==> Step 3: Factory-reset OTClient cache" -ForegroundColor Cyan
Write-Host "    Stop-Process -Name AstraClient -Force -ErrorAction SilentlyContinue"
Write-Host "    Remove-Item -Recurse -Force `"`$env:APPDATA\AstraClient`""
Write-Host "    (relaunch AstraClient after this so the new PNGs are picked up)"
