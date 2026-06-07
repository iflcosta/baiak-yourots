# Credits & Third-Party Attributions

Baiak-Yourots stands on the shoulders of giants. The custom code in this repo
is a thin layer on top of three major upstream projects and several smaller
ones. Each keeps its own license; this file lists them and the contribution.

## The Forgotten Server 1.8 (engine + server)

- **Upstream:** [otland/forgottenserver](https://github.com/otland/forgottenserver)
- **License:** [GPL-2.0](LICENSE) (inherited)
- **Used as:** `server/src/` (C++ engine), `server/data/` (Lua scripts,
  monsters, npc, map, schema). `server/LICENSE` is the original TFS license;
  we copy it to the repo root so the whole project carries the GPL stamp.
- **Modifications:** Many gameplay-specific changes (Baiak-Yourots style),
  integration with AstraClient (`server_config.lua`,
  `server/data/server_config.lua`), schema fix for `player_rewarditems`,
  repositioning of the default temple to (1000, 1000, 7), account-manager
  disable flag.
- **Thanks to:** Allan Ference, Andre Miles, and the rest of the
  [OTServ contributors](server/AUTHORS).

## AstraClient (client)

- **Upstream:** [Mateuzkl/AstraClient](https://github.com/Mateuzkl/AstraClient)
- **License:** Inherits from RubiniOT / OTClientV8 / OTClient open-source
  lineage. Original license headers and required open-source credits are
  retained in source files (see `client/CREDITS.md`).
- **Used as:** `client/` (C++ + Lua client). Bundled runtime DLLs
  (AppCore, Ultralight, WebCore, UltralightCore) are part of the Ultralight
  SDK and not tracked in this repo — see `ultralight-sdk/` after extracting
  the SDK archive.
- **Modifications:** Wired the minimap load/save cycle
  (`LoadTibiaMap`, `g_minimap.saveOtmm`/`loadOtmm` in
  `client/modules/game_minimap/minimap.lua`) so exploration persists across
  restarts.
- **Thanks to:** Mateuzkl, Equipe Skyyzyy.

## Remere's Map Editor (RME)

- **Upstream:** [remeresmapeditor.com](https://www.remeresmapeditor.com/)
- **License:** EULA — see `tools/rme-clientid/LICENSE.rtf`.
- **Used as:** `tools/rme-clientid/` (source). The prebuilt Windows binary
  (`Editor_x64.exe`) and bundled DLLs are NOT tracked in the repo
  (regenerable, large, under EULA).
- **Modifications:** Patches for MSVC + vcpkg + boost 1.91 in
  `tools/rme-clientid/source/` (asio io_context, boost::throw_exception
  stub, etc.). See commit history for the full set of patches.
- **Used for:** Exporting 16 `minimap_*.bmp` files with the 6x6x6 web-safe
  palette (matches the OTClient color quantization). Output is sliced by
  `server/tools/rme_bmp_to_png.py` into 192 sector PNGs consumed by the
  client.

## Ultralight (UI rendering)

- **Upstream:** [ultralight-ux/Ultralight](https://github.com/ultralight-ux/Ultralight)
- **License:** Free for non-commercial / indie use, see Ultralight SDK EULA.
- **Used as:** HTML/JS UI rendering inside AstraClient. SDK binaries
  (Ultralight.dll, AppCore.dll, WebCore.dll, UltralightCore.dll) are part
  of the SDK, not tracked in this repo.

## MariaDB 12.3 (database)

- **Upstream:** [MariaDB](https://mariadb.org/)
- **License:** GPL-2.0.
- **Used as:** Player/account/game data store on port 3306, database
  `baiak_tfs18`. The data directory lives in `mariadb_data/` (gitignored,
  regenerable from `server/schema.sql`).

## Tibia 8.6 client assets

- **Used as:** `client/data/things/860/{Tibia.dat, Tibia.spr, Tibia.otfi}`.
  These are extracted from the official Tibia 8.6 client archive. They are
  NOT tracked in this repo (CipSoft's IP, large) — obtain them yourself
  via the SDK extraction step in `scripts/setup.ps1`.
