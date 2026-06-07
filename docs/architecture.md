# System Architecture

> How the pieces of Baiak-Yourots fit together. Read this once before
> touching anything cross-cutting.

## High-level diagram

```
                      ┌─────────────────────┐
                      │     AstraClient     │  (OTClientV8, C++ + Lua)
                      │  protocol 8.6       │  + Ultralight (HTML/JS UI)
                      └──────────┬──────────┘
                                 │ TCP
                                 │ 7171 (login) / 7172 (game)
                                 ▼
                      ┌─────────────────────┐
                      │   TFS 1.8 Server    │  (C++ engine, Lua scripts)
                      │  protocol 8.6       │  (downgraded from 1.x default)
                      └──────────┬──────────┘
                                 │ libmariadb
                                 ▼
                      ┌─────────────────────┐
                      │   MariaDB 12.3      │
                      │   baiak_tfs18       │  (utf8mb4)
                      └─────────────────────┘

   ┌─────────────────────┐
   │    RME (8.6)        │  offline; one-shot
   │   world.otbm  ────────▶  server/data/world/
   │   minimap_*.bmp  ────▶  server/tools/rme_bmp_to_png.py
   └─────────────────────┘           │
                                     ▼
                            ┌─────────────────────┐
                            │  client/data/       │
                            │  minimap/X_Y_Z.png  │  192 sectors
                            └─────────────────────┘
```

## Components

### Server — `server/`

- **Engine:** TFS 1.8 C++17, ~140 .cpp + 100 .h files in `server/src/`.
- **Scripts:** 4000+ Lua files in `server/data/scripts/`. TFS 1.x
  OOP API only (no TFS 0.4 procedural). See
  [conventions.md](conventions.md) for the script template.
- **Map:** `server/data/world/world.otbm` (4.3 MB, OTBM v1 format).
- **Schema:** `server/schema.sql` + `server/data/migrations/`.
- **Config:** `server/config.lua` (engine config) +
  `server/data/server_config.lua` (game-time config loaded by Lua).
- **Docs:** `server/README.md`, `server/AUTHORS`, `server/LICENSE`
  (GPL-2.0).

### Client — `client/`

- **Engine:** AstraClient (OTClientV8 fork, C++ + Lua).
- **UI:** OTUI files in `client/data/styles/` + Ultralight (HTML/JS
  rendered in-process).
- **Data:** `client/data/{images, sounds, styles, things, minimap}/`.
  - `things/860/` = Tibia 8.6 client data (Tibia.dat, Tibia.spr,
    Tibia.otfi) — gitignored, regenerable.
  - `minimap/*.png` = 192 sector PNGs from RME export, the actual
    tiles the client renders. Committed (output of the build).
  - `minimap/*.minimap` = raw RME exports, regenerable. Gitignored.
- **Minimap persistence:** `client/data/minimap/minimap.otmm`
  (binary, user's exploration). See
  [minimap-procedure.md](minimap-procedure.md).

### Tools — `tools/`

- **`tools/rme-clientid/`** — Remere's Map Editor, source with
  MSVC + vcpkg + boost 1.91 patches. The prebuilt
  `Editor_x64.exe` is NOT tracked (download separately, EULA).
- **`scripts/`** — PowerShell 5.1 helpers: `setup`,
  `build-server`, `build-client`, `run-server`, `stop-server`,
  `minimap-export`.
- **`server/tools/rme_bmp_to_png.py`** — RME BMP -> OTClient PNG
  sector converter. Pure stdlib Python 3.12.

### Database — MariaDB 12.3

- Schema in `server/schema.sql`, data dir in `mariadb_data/`
  (gitignored).
- See [database.md](database.md) for table groups and migrations.

## Data flow

### Login (port 7171)

```
AstraClient
    → connect 7171
    ← recvHello (OS, version, dat/spr signature, RSA pubkey)
    → sendLogin (account, password)
    ← recvCharacterList (or error code)
```

The login server (`server/src/protocollogin.cpp`) checks the
account, validates the password (using the RSA pubkey in
`server/key.pem`), and returns the character list. The client
then opens port 7172 and enters the game protocol.

### Game (port 7172)

```
AstraClient
    → connect 7172, send session token from login
    ← recvMapDescription, recvTileSet, recvCreatureLight, etc.
    ... gameplay loop ...
    → chat / move / use / attack / look / etc.
    ← tile updates, creature moves, chat, fx
```

The game server (`server/src/protocolgame.cpp`) is the main
event loop. All gameplay is driven by Lua scripts in
`server/data/scripts/`.

### Map load

The server loads `world.otbm` at startup
(`server/src/iomap_otbm.cpp`). Map mutations (doors, signs,
containers) are loaded from the `tiles` + `tile_items` tables.

### Minimap (client-side, offline)

```
world.otbm
  → RME File > Open
  → RME File > Export > Minimap (writes minimap_0.bmp ... minimap_15.bmp)
  → server/tools/rme_bmp_to_png.py (slices BMPs into 192 X_Y_Z.png)
  → client/data/minimap/*.png
  → AstraClient loads on launch (cached in RAM)
  → User explores → AstraClient writes minimap.otmm on shutdown
```

## Protocol downgrade: 8.6 in a 1.x engine

TFS 1.8 normally speaks a 1.x protocol (10+). We force it to
8.6 because AstraClient is 8.6-only. The downgrade lives in
two places:

- `server/src/protocolgame.cpp` — the message IDs, packet
  structure, and feature flags are all 8.6.
- `client/init.lua` — the client config asserts the protocol
  version at startup.

AstraClient is compatible with the 8.6 packet set, and the
server's protocol 8.6 implementation is upstream-clean
(otland/forgottenserver ships a 8.6 protocol variant).

## Build pipeline

```
vsvarsall.bat x64
  → cmake -G Ninja -DCMAKE_TOOLCHAIN_FILE=vcpkg.cmake
  → cmake --build . --config Release --parallel
  → binary at server/build-Release/theforgottenserver-x64.exe
  → scripts/build-server.ps1 copies it to server/ for convenience
```

`scripts/build-server.ps1` and `scripts/build-client.ps1` wrap
this. Both use the vcpkg manifest at
`<dir>/vcpkg.json` — the dependency set is locked to the repo,
not the global vcpkg state.

## File layout summary

```
baiak-yourots/
├── AGENTS.md              # project overview, status, conventions, log
├── README.md              # entry point (rendered on GitHub)
├── spec.md                # current product spec + phases
├── todo.md                # current task list
├── CREDITS.md             # third-party attributions
├── LICENSE                # GPL-2.0 (from TFS)
├── .gitignore
├── .gitattributes
├── .github/               # GitHub metadata
│   ├── CODEOWNERS
│   ├── PULL_REQUEST_TEMPLATE.md
│   ├── ISSUE_TEMPLATE/
│   └── copilot-instructions.md
├── docs/                  # deep-dive documentation
│   ├── README.md          # index
│   ├── local-dev.md
│   ├── architecture.md
│   ├── database.md
│   ├── build-troubleshoot.md
│   ├── conventions.md
│   ├── minimap-procedure.md
│   ├── spec-driven-development.md
│   └── agents/
├── scripts/               # PowerShell 5.1 helpers
├── server/                # TFS 1.8 (C++ + Lua + world.otbm + schema)
│   ├── src/
│   ├── data/
│   │   ├── scripts/
│   │   ├── monsters/
│   │   ├── npc/
│   │   ├── world/
│   │   └── ...
│   ├── schema.sql
│   ├── config.lua
│   ├── vcpkg.json
│   ├── vc18/              # Visual Studio project (alternative to cmake)
│   └── ...
├── client/                # AstraClient (C++ + Lua + assets)
│   ├── src/
│   ├── modules/
│   ├── mods/
│   ├── data/
│   │   ├── styles/
│   │   ├── images/
│   │   ├── minimap/
│   │   └── things/860/    # gitignored
│   ├── vcpkg.json
│   └── ...
├── tools/
│   └── rme-clientid/      # RME source with MSVC patches
│       ├── source/
│       ├── data/          # Tibia client version references
│       └── ...
└── ultralight-sdk/        # gitignored, extracted by setup.ps1
```
