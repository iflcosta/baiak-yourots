<#
.SYNOPSIS
    Stop any running TFS 1.8 server process.

.EXAMPLE
    .\scripts\stop-server.ps1
#>
[CmdletBinding()]
param()

$procs = Get-Process -Name 'tfs' -ErrorAction SilentlyContinue
if (-not $procs) {
    Write-Host "No TFS server process running." -ForegroundColor DarkGray
    return
}
Write-Host "==> Stopping $($procs.Count) process(es): $($procs.Id -join ', ')" -ForegroundColor Yellow
$procs | Stop-Process -Force
Start-Sleep -Seconds 1
$remaining = Get-Process -Name 'tfs' -ErrorAction SilentlyContinue
if ($remaining) {
    throw "Failed to stop PID $($remaining.Id -join ', ')"
}
Write-Host "==> Stopped." -ForegroundColor Green
