# Local Development — Clone & Run

> Step-by-step for a fresh Windows 10/11 dev box. End state: TFS server
> running on ports 7171/7172, AstraClient connecting, character Iago
> Lopes (lv 2000) on account `iflopes2` reachable.

## 1. Prerequisites

| Tool             | Version      | Where to get it                                            |
| ---------------- | ------------ | ---------------------------------------------------------- |
| Windows          | 10 / 11      | -                                                          |
| Git              | 2.40+        | [git-scm.com](https://git-scm.com/)                        |
| Visual Studio    | 2022 Build Tools | [visualstudio.microsoft.com](https://visualstudio.microsoft.com/) ("Desktop development with C++", "Windows 10/11 SDK") |
| CMake            | 3.20+        | (vcpkg installs its own, do nothing)                      |
| Ninja            | 1.10+        | `choco install ninja` (or vcpkg installs its own)          |
| vcpkg            | latest       | [github.com/microsoft/vcpkg](https://github.com/microsoft/vcpkg) |
| MariaDB          | 12.3         | [mariadb.org](https://mariadb.org/)                        |
| 7-Zip           | 23+          | [7-zip.org](https://www.7-zip.org/) (used by `setup.ps1`)  |
| Python           | 3.12         | [python.org](https://www.python.org/) (used by minimap converter) |
| gh (GitHub CLI)  | 2.40+        | [cli.github.com](https://cli.github.com/) (optional, for repo ops) |

Set `$env:VCPKG_ROOT = 'C:\vcpkg'` if you installed vcpkg anywhere but
the default `C:\vcpkg`.

## 2. Clone

```powershell
git clone https://github.com/iflcosta/baiak-yourots.git
cd baiak-yourots
```

The first clone is ~210 MB (compressed) and 5+ GB after building
because of the bundled 192 MB of UI images, the 112 MB of RME
reference data, and the 8.6 `Tibia.spr` (431 MB, NOT in the repo, you
provide it).

## 3. Bootstrap

```powershell
.\scripts\setup.ps1
```

What it does (idempotent — safe to rerun):

1. Installs the vcpkg manifest deps for `server/` and `client/`
   (boost, lua, libmariadb, openssl, pugixml, spdlog, etc.).
2. Extracts `ultralight-sdk/` from `sdk/ultralight-sdk.zip` (you
   must drop the zip in `sdk/` first).
3. Extracts `client/data/things/860/{Tibia.dat, Tibia.spr}` from
   `sdk/860.rar` (you must drop the rar in `sdk/` first).
4. Initializes the MariaDB data directory and starts `mysqld` on
   port 3306.
5. Creates the `baiak_tfs18` database and imports
   `server/schema.sql`.
6. Writes a `.env` with the local paths and credentials.

Use `-Skip` to skip steps: `.\scripts\setup.ps1 -Skip db,env`.

## 4. Build the server

```powershell
.\scripts\build-server.ps1
```

Builds Release x64 with Ninja + MSVC. The binary is copied to
`server/theforgottenserver-x64.exe` for convenience.

For a clean rebuild: `.\scripts\build-server.ps1 -Clean`.
For Debug: `.\scripts\build-server.ps1 -Config Debug`.

## 5. Build the client

```powershell
.\scripts\build-client.ps1
```

Same as the server, but for AstraClient. Output:
`client/AstraClient.exe`. The runtime DLLs (Ultralight, AppCore,
WebCore) must be in the same directory as the binary; `setup.ps1`
step 2 places them under `ultralight-sdk/`, the build copies them
next to the .exe.

## 6. Run

In one terminal:

```powershell
.\scripts\run-server.ps1
```

In another terminal:

```powershell
.\client\AstraClient.exe
```

Default client address: `127.0.0.1:7171` (login) -> `127.0.0.1:7172`
(game). Edit `client/init.lua` if you want to point elsewhere.

## 7. Verify

Log in with:

- Account: `iflopes2`
- Password: `f2w4r8vu`
- Character: `Iago Lopes` (lv 2000, knight, group 6 / god)

Temple should be at (1000, 1000, 7). Open the minimap — you should
see the explored area as colored tiles and the unvisited area as
black (that's the widget's `color: black` background showing
through the void-tile alpha=0 PNGs).

## 8. Iterate

| Need                          | Command                                          |
| ----------------------------- | ------------------------------------------------ |
| Rebuild server                | `.\scripts\build-server.ps1`                     |
| Rebuild client                | `.\scripts\build-client.ps1`                     |
| Restart server (Ctrl-C + run) | `.\scripts\run-server.ps1`                       |
| Stop server                   | `.\scripts\stop-server.ps1`                      |
| Regenerate minimap            | `.\scripts\minimap-export.ps1`                   |
| Drop into MariaDB CLI         | `& "C:\Program Files\MariaDB 12.3\bin\mysql.exe" -u root baiak_tfs18` |

## 9. Common errors

See [docs/build-troubleshoot.md](build-troubleshoot.md) for the full
list. The top three:

- **`port 7171 already in use`** — another TFS is still running. Run
  `.\scripts\stop-server.ps1` first.
- **`AstraClient.exe cannot find Ultralight.dll`** — the
  `ultralight-sdk/` extraction in `setup.ps1` step 2 failed. Run
  the step manually.
- **`mariadb` connection refused** — mysqld isn't running. Start
  it via the Windows Services panel or the command in
  [build-troubleshoot.md](build-troubleshoot.md#mariadb).
