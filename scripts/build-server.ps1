<#
.SYNOPSIS
    Build the TFS 1.8 server (theforgottenserver) for Windows x64.

.DESCRIPTION
    Configures CMake (Ninja) and builds Release x64 using MSVC.
    Requires: Visual Studio 2022 Build Tools, vcpkg with manifest
    dependencies restored (see scripts/setup.ps1).

.PARAMETER Config
    Build configuration: Debug | Release (default: Release).

.PARAMETER Clean
    Wipe the build directory before configuring.

.EXAMPLE
    .\scripts\build-server.ps1
    .\scripts\build-server.ps1 -Config Debug -Clean

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
$ServerDir   = Join-Path $RepoRoot 'server'
$SrcDir      = Join-Path $ServerDir 'src'
$BuildDir    = Join-Path $ServerDir "build-$Config"
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

if (-not (Test-Path (Join-Path $ServerDir 'vcpkg.json'))) {
    throw "vcpkg.json not found in $ServerDir. Is the repo initialized?"
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
    $SrcDir
if ($LASTEXITCODE -ne 0) { throw "CMake configure failed (exit $LASTEXITCODE)" }

# ---- Build ----------------------------------------------------------------
Write-Host "==> CMake build ($Config)" -ForegroundColor Cyan
& $CMakeExe --build . --config $Config --parallel
if ($LASTEXITCODE -ne 0) { throw "CMake build failed (exit $LASTEXITCODE)" }

# ---- Locate output --------------------------------------------------------
$ExeName = if ($Config -eq 'Debug') { 'theforgottenserver.exe' } else { 'theforgottenserver-x64.exe' }
$ExePath  = Get-ChildItem -Path $BuildDir -Filter $ExeName -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName
if ($ExePath) {
    # Copy binary to repo root for convenience (matches the prebuilt layout).
    $Dest = Join-Path $ServerDir (Split-Path $ExePath -Leaf)
    Copy-Item -LiteralPath $ExePath -Destination $Dest -Force
    Write-Host "==> Built and copied: $Dest" -ForegroundColor Green
} else {
    Write-Warning "Build succeeded but $ExeName not found under $BuildDir."
}
