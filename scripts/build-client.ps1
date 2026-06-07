<#
.SYNOPSIS
    Build the AstraClient (OTClientV8, protocol 8.6) for Windows x64.

.DESCRIPTION
    Configures CMake (Ninja) and builds Release x64 using MSVC.
    Requires: Visual Studio 2022 Build Tools, vcpkg with manifest
    dependencies restored (see scripts/setup.ps1), ultralight-sdk/
    extracted in the repo root.

.PARAMETER Config
    Build configuration: Debug | Release (default: Release).

.PARAMETER Clean
    Wipe the build directory before configuring.

.EXAMPLE
    .\scripts\build-client.ps1
    .\scripts\build-client.ps1 -Clean

.NOTES
    Author : Iago Lopes <iagopuma0@gmail.com>
    Repo   : https://github.com/iflcosta/baiak-yourots
#>
[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Config = 'Release',

    [switch]$Clean
)

$ErrorActionPreference = 'Stop'
$ProgressPreference   = 'SilentlyContinue'

# ---- Paths ----------------------------------------------------------------
$RepoRoot    = (Resolve-Path "$PSScriptRoot\..").Path
$ClientDir   = Join-Path $RepoRoot 'client'
$BuildDir    = Join-Path $ClientDir "build-$Config"
$Ultralight  = Join-Path $RepoRoot 'ultralight-sdk'
$VcpkgRoot   = if ($env:VCPKG_ROOT) { $env:VCPKG_ROOT } else { 'C:\vcpkg' }
$VcpkgExe    = Join-Path $VcpkgRoot 'vcpkg.exe'
$CMakeExe    = Join-Path $VcpkgRoot 'downloads\tools\cmake-4.3.2-windows\cmake-4.3.2-windows-x86_64\bin\cmake.exe'
$Toolchain   = "-DCMAKE_TOOLCHAIN_FILE=$VcpkgRoot\scripts\buildsystems\vcpkg.cmake"

# ---- Sanity checks --------------------------------------------------------
foreach ($p in @($VcpkgExe, $CMakeExe)) {
    if (-not (Test-Path $p)) {
        throw "Required tool not found: $p`nInstall Visual Studio Build Tools and vcpkg (see scripts/setup.ps1)."
    }
}
if (-not (Test-Path $Ultralight)) {
    throw "ultralight-sdk/ not found at $Ultralight. Extract it from the SDK archive (see scripts/setup.ps1)."
}
if (-not (Test-Path (Join-Path $ClientDir 'vcpkg.json'))) {
    throw "vcpkg.json not found in $ClientDir. Is the repo initialized?"
}

# ---- Clean (optional) -----------------------------------------------------
if ($Clean -and (Test-Path $BuildDir)) {
    Write-Host "==> Removing $BuildDir" -ForegroundColor Yellow
    Remove-Item -LiteralPath $BuildDir -Recurse -Force
}

# ---- Configure ------------------------------------------------------------
if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null
}
Set-Location $BuildDir

Write-Host "==> CMake configure ($Config, x64, vcpkg manifest)" -ForegroundColor Cyan
& $CMakeExe -G 'Ninja' `
    -DCMAKE_BUILD_TYPE=$Config `
    -DCMAKE_INSTALL_PREFIX="$BuildDir\install" `
    $Toolchain `
    $ClientDir
if ($LASTEXITCODE -ne 0) { throw "CMake configure failed (exit $LASTEXITCODE)" }

# ---- Build ----------------------------------------------------------------
Write-Host "==> CMake build ($Config)" -ForegroundColor Cyan
& $CMakeExe --build . --config $Config --parallel
if ($LASTEXITCODE -ne 0) { throw "CMake build failed (exit $LASTEXITCODE)" }

# ---- Locate output --------------------------------------------------------
$ExePath = Get-ChildItem -Path $BuildDir -Filter 'AstraClient.exe' -Recurse -ErrorAction SilentlyContinue |
           Select-Object -First 1 -ExpandProperty FullName
if ($ExePath) {
    $Dest = Join-Path $ClientDir 'AstraClient.exe'
    Copy-Item -LiteralPath $ExePath -Destination $Dest -Force
    Write-Host "==> Built and copied: $Dest" -ForegroundColor Green
} else {
    Write-Warning "Build succeeded but AstraClient.exe not found under $BuildDir."
}
