<#
.SYNOPSIS
    Start the TFS 1.8 server in the foreground.

.DESCRIPTION
    Launches server/theforgottenserver-x64.exe from the repo root.
    Stops the running instance first if one is already attached to
    ports 7171/7172 (login + game protocol). Ctrl-C to abort.

.EXAMPLE
    .\scripts\run-server.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path "$PSScriptRoot\..").Path
$Exe      = Join-Path $RepoRoot 'server\theforgottenserver-x64.exe'

if (-not (Test-Path $Exe)) {
    throw "Server binary not found: $Exe`nBuild it first with .\scripts\build-server.ps1"
}

# Stop any running instance to free the ports.
$running = Get-Process -Name 'theforgottenserver-x64' -ErrorAction SilentlyContinue
if ($running) {
    Write-Host "==> Stopping existing server (PID $($running.Id))" -ForegroundColor Yellow
    $running | Stop-Process -Force
    Start-Sleep -Seconds 1
}

# Make sure runtime DLLs from vcpkg_installed are discoverable.
$VcpkgRoot  = if ($env:VCPKG_ROOT) { $env:VCPKG_ROOT } else { 'C:\vcpkg' }
$VcpkgBin   = Join-Path $VcpkgRoot 'installed\x64-windows\bin'
if (Test-Path $VcpkgBin) {
    $env:PATH = "$VcpkgBin;$env:PATH"
}

Set-Location (Join-Path $RepoRoot 'server')

Write-Host "==> Starting $Exe (Ctrl-C to stop)" -ForegroundColor Cyan
& $Exe
