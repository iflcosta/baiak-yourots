# Build & Runtime Troubleshooting

> Known issues and their fixes, gathered from the bootstrap session
> (2026-06-06 / 2026-06-07). Add new ones as you hit them.

## Git / repo

### `git add` treats `server/` as a submodule

**Symptom:** `git status` shows `server` with a leading `S` or `?? server`
warning, and the commit adds `server/` as a gitlink (mode 160000)
referencing an old upstream commit, NOT its real contents.

**Cause:** The original `git clone` of TFS left a nested
`server/.git` directory. `git add` sees it and treats `server/`
as an embedded repository.

**Fix:**

```powershell
Remove-Item -LiteralPath server\.git -Recurse -Force
git rm --cached -r server      # if it's already in the index as a gitlink
git add server
```

Same goes for `client/.git` and `tools/rme-clientid/.git` — they
were upstream clones too.

### `git push` rejected: `denyNonFastForwards`

You branched from `master` directly and `master` moved. `git pull
--rebase origin master` then push again, or rebase off `develop`
instead.

### `git commit` fails on Windows with `fatal: CRLF would be replaced by LF`

The file is in the working tree as CRLF and `.gitattributes` says
LF. Run `git add --renormalize <file>` to normalize, or save the
file as LF in your editor.

## Build

### `theforgottenserver-x64.pch` is 388 MB

Precompiled header from a Release build. The `.gitignore` should
catch it (`server/vc18/theforgo.A10F9657/x64/Release/`), but if
you see it in `git status`, your `.gitignore` isn't being read.
Check the path patterns in the top-level `.gitignore` and in
`server/.gitignore`.

### `vcpkg install` fails with `error: while detecting compiler information`

VS 2022 Build Tools not installed (or not the "Desktop development
with C++" workload). Re-run the VS installer, add the workload,
restart PowerShell.

### `cmake` not found when running `build-server.ps1`

`build-server.ps1` looks for cmake in
`$env:VCPKG_ROOT\downloads\tools\cmake-*\bin\cmake.exe`. If that
path doesn't exist (e.g. vcpkg hasn't downloaded cmake yet),
trigger vcpkg once manually:

```powershell
& $env:VCPKG_ROOT\vcpkg.exe install vcpkg-cmake --triplet=x64-windows
```

### `boost::throw_exception` link error when compiling RME

vcpkg no longer ships a `boost_exception` library. RME source
expects one. We added a stub:
`tools/rme-clientid/source/boost_exception_stub.cpp` that defines
`boost::throw_exception`. Re-add it to the source CMakeLists if
you wipe the RME build.

### RME `Editor_x64.exe` (prebuilt) works, but our build crashes 0xC0000005

We couldn't find the cause. Use the prebuilt. The patches to the
RME source are still useful as documentation of what we tried.

## Server runtime

### `mysqld` not running / `connection refused`

```powershell
& "C:\Program Files\MariaDB 12.3\bin\mysqld.exe" `
    --datadir="$PWD\mariadb_data" `
    --port=3306
```

Run in a separate terminal (it's foreground). For a background
service, register it: `mysqld --install` then `net start mysql`.

### `account: 1` (Account Manager) keeps logging in

`server/config.lua` must have `accountManager = false`. We set
this. If you reset the repo, re-apply.

### Player save fails: `Table 'baiak_tfs18.player_rewarditems' doesn't exist`

**Cause:** `server/schema.sql` shipped without the
`player_rewarditems` table, but the C++ engine (`iologindata.cpp`)
references it on save.

**Fix:** Create the table (idempotent):

```sql
CREATE TABLE IF NOT EXISTS `player_rewarditems` (
  `player_id` INT(11) NOT NULL,
  `pid`       INT(11) NOT NULL,
  `sid`       INT(11) NOT NULL,
  `itemtype`  INT(11) NOT NULL,
  `count`     INT(11) NOT NULL DEFAULT 0,
  `attributes` BLOB,
  PRIMARY KEY (`player_id`, `pid`, `sid`),
  FOREIGN KEY (`player_id`) REFERENCES `players`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

Documented in [database.md §Migrations](database.md#migrations).

### Server boots then crashes on first player login

Check `server/data/logs/*.log`. The most common cause is the
`player_rewarditems` fix above. The second is a corrupted
`world.otbm` (rebuild from the RME export, see
[minimap-procedure.md](minimap-procedure.md)).

## Client runtime

### Minimap is all black

You explored nothing. Walk around for a few minutes. If you
walked and it's still all black, the exploration save
(`minimap.otmm`) is broken. Delete it and start over:

```powershell
Stop-Process -Name AstraClient -Force -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$env:APPDATA\AstraClient"
```

The next launch regenerates the cache from
`client/data/minimap/*.png`.

### Minimap is fully colored but with wrong colors

The PNGs are not aligned to the 6x6x6 web-safe palette. Re-export
from RME and re-run `rme_bmp_to_png.py`. See
[minimap-procedure.md](minimap-procedure.md).

### AstraClient log says `failed to load minimap: X_Y_Z.png`

The PNG file is missing for the sector the player is in. Either
the export is incomplete, or the player is outside the map. Verify
the PNGs exist:

```powershell
Get-ChildItem "$PWD\client\data\minimap\*.png" | Measure-Object
```

Should return 192 PNGs (16 floors × 12 sectors). If less, re-run
`scripts/minimap-export.ps1`.

### AstraClient starts but the login window is blank

The Ultralight SDK is missing or the wrong version. Verify:

```powershell
Test-Path "$PWD\client\Ultralight.dll"   # should be True
Test-Path "$PWD\client\AppCore.dll"      # should be True
Test-Path "$PWD\client\WebCore.dll"      # should be True
```

Re-run `scripts/setup.ps1` if any are missing. The DLLs are
gitignored (extracted from the SDK archive) so a fresh clone
needs `setup.ps1` step 2 to populate them.

## MariaDB

### Forgot the root password

```powershell
Stop-Service mysql   # or kill mysqld
& "C:\Program Files\MariaDB 12.3\bin\mysqld.exe" `
    --skip-grant-tables --port=3306
# In another terminal:
& "C:\Program Files\MariaDB 12.3\bin\mysql.exe" -u root
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '';
exit;
# Stop the --skip-grant-tables instance, restart normally
```

### Restoring a backup

```powershell
& "C:\Program Files\MariaDB 12.3\bin\mysqldump.exe" `
    -u root baiak_tfs18 > backup-$(Get-Date -Format yyyyMMdd).sql
# Restore:
& "C:\Program Files\MariaDB 12.3\bin\mysql.exe" `
    -u root baiak_tfs18 < backup-YYYYMMDD.sql
```
