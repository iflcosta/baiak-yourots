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

# ---- Ensure MSVC env ------------------------------------------------------
# Ninja + cl.exe require the Visual Studio developer environment. If the
# caller hasn't already loaded it (e.g. ran from "Developer PowerShell for
# VS 2022"), bootstrap it from vcvars64.bat so the build is reproducible
# from any plain PowerShell.
if (-not (Get-Command cl.exe -ErrorAction SilentlyContinue)) {
    $VcvarsCandidates = @(
        "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat",
        "C:\Program Files\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat",
        "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat",
        "C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat",
        "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat"
    )
    $Vcvars = $VcvarsCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $Vcvars) {
        throw "MSVC compiler (cl.exe) not on PATH and vcvars64.bat not found in standard locations. Install Visual Studio 2022 Build Tools with the 'Desktop development with C++' workload."
    }
    Write-Host "==> Loading MSVC env from $Vcvars" -ForegroundColor Cyan
    # `cmd /c "vcvars64.bat && set"` dumps the resulting env as KEY=VALUE lines.
    # We parse and inject them into the current process so subsequent cmake
    # invocations can find cl.exe, link.exe, the Windows SDK, etc.
    $vcEnv = & cmd.exe /c "`"$Vcvars`" >NUL && set" |
        ForEach-Object {
            if ($_ -match '^([^=]+)=(.*)$') {
                [PSCustomObject]@{ Name = $Matches[1]; Value = $Matches[2] }
            }
        }
    foreach ($kv in $vcEnv) {
        # Skip names that PowerShell considers read-only or that would shadow
        # variables we just set (PATH, PATHEXT, etc. get merged, not replaced).
        if ($kv.Name -in @('PSExecutionPolicyPreference', 'PSModulePath')) { continue }
        Set-Item -LiteralPath "Env:\$($kv.Name)" -Value $kv.Value
    }
    if (-not (Get-Command cl.exe -ErrorAction SilentlyContinue)) {
        throw "vcvars64.bat loaded but cl.exe still not on PATH. Check the VS install."
    }
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
    "-DCMAKE_BUILD_TYPE=$Config" `
    "-DCMAKE_INSTALL_PREFIX=$BuildDir\install" `
    $Toolchain `
    $ServerDir
if ($LASTEXITCODE -ne 0) { throw "CMake configure failed (exit $LASTEXITCODE)" }

# ---- Build ----------------------------------------------------------------
Write-Host "==> CMake build ($Config)" -ForegroundColor Cyan
& $CMakeExe --build . --config "$Config" --parallel
if ($LASTEXITCODE -ne 0) { throw "CMake build failed (exit $LASTEXITCODE)" }

# ---- Locate output --------------------------------------------------------
# The CMake target is `tfs` (see server/CMakeLists.txt: `add_executable(tfs ...)`),
# which always produces `tfs.exe` regardless of Debug/Release config.
$ExeName = 'tfs.exe'
$ExePath  = Get-ChildItem -Path $BuildDir -Filter $ExeName -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName
if ($ExePath) {
    # Copy binary to server/ for convenience (matches the layout used by run-server.ps1).
    $Dest = Join-Path $ServerDir $ExeName
    Copy-Item -LiteralPath $ExePath -Destination $Dest -Force
    Write-Host "==> Built and copied: $Dest" -ForegroundColor Green
} else {
    Write-Warning "Build succeeded but $ExeName not found under $BuildDir."
}
