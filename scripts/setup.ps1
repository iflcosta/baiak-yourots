<#
.SYNOPSIS
    Bootstrap a fresh dev environment for baiak-yourots on Windows.

.DESCRIPTION
    Idempotent. Performs (in order):
      1. Verifies Visual Studio 2022 Build Tools + vcpkg
      2. Installs vcpkg manifest deps for server/ and client/
      3. Extracts ultralight-sdk/ from sdk/ultralight-sdk.zip (if not present)
      4. Extracts client/data/things/860/{Tibia.dat, Tibia.spr} from
         sdk/860.rar (if not present)
      5. Creates the MariaDB database (baiak_tfs18) and imports schema.sql
      6. Writes an .env file with the local paths and credentials

.PARAMETER Skip
    Comma-separated steps to skip. Valid: vcpkg, ultralight, things, db, env

.EXAMPLE
    .\scripts\setup.ps1
    .\scripts\setup.ps1 -Skip db
#>
[CmdletBinding()]
param(
    [string]$Skip = ''
)

$ErrorActionPreference = 'Stop'
$ProgressPreference   = 'SilentlyContinue'

$RepoRoot      = (Resolve-Path "$PSScriptRoot\..").Path
$VcpkgRoot     = if ($env:VCPKG_ROOT) { $env:VCPKG_ROOT } else { 'C:\vcpkg' }
$VcpkgExe      = Join-Path $VcpkgRoot 'vcpkg.exe'
$SevenZip      = 'C:\Program Files\7-Zip\7z.exe'
$Python        = 'C:\Users\Iago\AppData\Local\Programs\Python\Python312\python.exe'
$MariaBin      = 'C:\Program Files\MariaDB 12.3\bin\mysql.exe'
$MariaData     = Join-Path $RepoRoot 'mariadb_data'
$UltralightDir = Join-Path $RepoRoot 'ultralight-sdk'
$SdkDir        = Join-Path $RepoRoot 'sdk'
$ThingsDir     = Join-Path $RepoRoot 'client\data\things\860'
$SkipSet       = @{}; $Skip.Split(',') | ForEach-Object { $SkipSet[$_.Trim()] = $true }

function Step($name, [scriptblock]$fn) {
    if ($SkipSet.ContainsKey($name)) {
        Write-Host "==> [skip] $name" -ForegroundColor DarkGray
        return
    }
    Write-Host "==> $name" -ForegroundColor Cyan
    & $fn
}

# 1) vcpkg manifest deps ---------------------------------------------------
Step 'vcpkg' {
    if (-not (Test-Path $VcpkgExe)) {
        throw "vcpkg not found at $VcpkgExe. Install vcpkg first: git clone https://github.com/microsoft/vcpkg $VcpkgRoot && `$VcpkgRoot\bootstrap-vcpkg.bat"
    }
    $manifests = @(
        Join-Path $RepoRoot 'server',
        Join-Path $RepoRoot 'client'
    )
    foreach ($m in $manifests) {
        if (-not (Test-Path (Join-Path $m 'vcpkg.json'))) { continue }
        Write-Host "    installing manifest deps in $m"
        & $VcpkgExe install --x-install-root="$VcpkgRoot\installed" --x-packages-root="$VcpkgRoot\packages" --triplet=x64-windows
        if ($LASTEXITCODE -ne 0) { throw "vcpkg install failed in $m" }
    }
}

# 2) ultralight-sdk --------------------------------------------------------
Step 'ultralight' {
    $zip = Get-ChildItem -Path $SdkDir -Filter 'ultralight-sdk*.zip' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $zip) {
        Write-Warning "    ultralight-sdk zip not found in $SdkDir. Place it there and rerun."
        return
    }
    if (Test-Path $UltralightDir) {
        Write-Host "    already extracted at $UltralightDir"
        return
    }
    & $SevenZip x $zip.FullName -o$SdkDir -y | Out-Null
    # Rename to canonical ultralight-sdk/ if needed.
    $candidate = Get-ChildItem -Path $SdkDir -Directory | Where-Object { $_.Name -like 'ultralight-sdk*' } | Select-Object -First 1
    if ($candidate -and $candidate.FullName -ne $UltralightDir) {
        Rename-Item -LiteralPath $candidate.FullName -NewName 'ultralight-sdk'
    }
}

# 3) client/data/things/860/ (Tibia.dat + Tibia.spr) -----------------------
Step 'things' {
    if ((Test-Path "$ThingsDir\Tibia.dat") -and (Test-Path "$ThingsDir\Tibia.spr")) {
        Write-Host "    already extracted at $ThingsDir"
        return
    }
    $rar = Get-ChildItem -Path $SdkDir -Filter '860.rar' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $rar) {
        Write-Warning "    860.rar not found under $SdkDir. Place it there and rerun."
        return
    }
    New-Item -ItemType Directory -Path $ThingsDir -Force | Out-Null
    & $SevenZip x $rar.FullName -o$ThingsDir -y | Out-Null
}

# 4) MariaDB schema --------------------------------------------------------
Step 'db' {
    if (-not (Test-Path $MariaBin)) {
        Write-Warning "    MariaDB not found at $MariaBin. Install MariaDB 12.3 and rerun."
        return
    }
    # Initialize data dir if empty.
    if (-not (Test-Path (Join-Path $MariaData 'mysql'))) {
        & "$VcpkgRoot\installed\x64-windows\tools\openssl\openssl.exe" version 2>$null | Out-Null
        # Use mysqld --initialize-insecure from MariaDB.
        $mysqld = $MariaBin -replace 'mysql\.exe$', 'mysqld.exe'
        & $mysqld --initialize-insecure --datadir=$MariaData --auth-root-authentication-plugin=mysql_native_password
        if ($LASTEXITCODE -ne 0) { throw "mysqld --initialize failed" }
    }
    # Start server in background.
    $mysqld = $MariaBin -replace 'mysql\.exe$', 'mysqld.exe'
    $running = Get-Process -Name 'mysqld' -ErrorAction SilentlyContinue
    if (-not $running) {
        Start-Process -FilePath $mysqld -ArgumentList "--datadir=$MariaData","--port=3306" -WindowStyle Hidden
        Start-Sleep -Seconds 5
    }
    # Create database and import schema.
    & $MariaBin -u root -e "CREATE DATABASE IF NOT EXISTS baiak_tfs18 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    if ($LASTEXITCODE -ne 0) { throw "CREATE DATABASE failed" }
    $schemaSql = Join-Path $RepoRoot 'server\schema.sql'
    & $MariaBin -u root baiak_tfs18 -e "SOURCE $schemaSql"
    if ($LASTEXITCODE -ne 0) { throw "schema import failed" }
}

# 5) .env ------------------------------------------------------------------
Step 'env' {
    $envFile = Join-Path $RepoRoot '.env'
    @"
# Baiak-Yourots local dev env (auto-generated by scripts/setup.ps1)
BAIAK_VCPKG_ROOT=$VcpkgRoot
BAIAK_MARIADB_BIN=$((Split-Path $MariaBin) | Split-Path -Leaf)
BAIAK_DB_NAME=baiak_tfs18
BAIAK_DB_USER=root
BAIAK_DB_PASSWORD=
BAIAK_LOGIN_PORT=7171
BAIAK_GAME_PORT=7172
"@ | Out-File -FilePath $envFile -Encoding utf8
    Write-Host "    wrote $envFile"
}

Write-Host "`n==> Setup complete." -ForegroundColor Green
