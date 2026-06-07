# Baiak-Yourots

A custom Open Tibia server built on **TFS 1.8** (downgraded to protocol 8.6)
and **AstraClient** (OTClientV8-based). Fast-paced PvP, custom teleports,
VIP system, accelerated progression.

> Public repo: <https://github.com/iflcosta/baiak-yourots>
> Status: **Phase 1 complete** (server + client running locally, minimap pipeline working end-to-end). See [spec.md](spec.md) for the full roadmap.

## What is this?

A Baiak-Yourots-style OT server: high-rate PvP with custom content. The engine
is The Forgotten Server 1.8 (a modern TFS 1.x fork), forced to talk the
client protocol 8.6 so it can use the AstraClient fork as the visual front-end.

## Tech stack

| Component  | Tech                                                 |
| ---------- | ---------------------------------------------------- |
| Server     | TFS 1.8 (C++17, Lua 5.1, MariaDB 12.3)               |
| Client     | AstraClient / OTClientV8 (C++, Ultralight UI)        |
| Map editor | Remere's Map Editor (CLIENTID 8.6)                   |
| Build      | CMake + Ninja + vcpkg (manifest mode) + MSBuild      |
| Minimap    | RME BMP export -> `rme_bmp_to_png.py` -> 192 PNGs    |

## Quick start

```powershell
# 1. Clone
git clone https://github.com/iflcosta/baiak-yourots.git
cd baiak-yourots

# 2. Bootstrap dev environment
.\scripts\setup.ps1

# 3. Build the server
.\scripts\build-server.ps1

# 4. Build the client
.\scripts\build-client.ps1

# 5. Start the server (foreground)
.\scripts\run-server.ps1
```

Full walkthrough in [docs/local-dev.md](docs/local-dev.md).

## Documentation

This project is **Spec-Driven Development** — docs and specs are the source
of truth, code follows the spec. See [docs/spec-driven-development.md](docs/spec-driven-development.md).

| Doc                                       | What's in it                            |
| ----------------------------------------- | --------------------------------------- |
| [spec.md](spec.md)                        | Current product spec + phased roadmap   |
| [todo.md](todo.md)                        | Active task list                        |
| [AGENTS.md](AGENTS.md)                    | Project overview, conventions, log      |
| [docs/local-dev.md](docs/local-dev.md)    | Clone -> run quickstart                 |
| [docs/architecture.md](docs/architecture.md) | System architecture + data flow     |
| [docs/database.md](docs/database.md)      | Schema overview + migrations            |
| [docs/build-troubleshoot.md](docs/build-troubleshoot.md) | Gotchas + fixes               |
| [docs/conventions.md](docs/conventions.md) | Lua / C++ / Git / PR conventions        |
| [docs/minimap-procedure.md](docs/minimap-procedure.md) | RME -> PNG -> factory reset       |
| [docs/agents/](docs/agents/)              | Multi-agent role profiles               |

## Contributing

1. Read [AGENTS.md](AGENTS.md) and [docs/conventions.md](docs/conventions.md).
2. Pick a task from [todo.md](todo.md) or open a feature request via the
   issue template.
3. Branch from `develop`: `git checkout -b feature/<scope>-<short-desc>`.
4. Conventional Commits in English: `feat:`, `fix:`, `chore:`, `docs:`, etc.
5. Open a PR -> `develop`. Never PR directly to `master`.

Full workflow in [AGENTS.md](AGENTS.md#git-workflow-gitflow-light).

## License

**GPL-2.0** (inherited from The Forgotten Server). See [LICENSE](LICENSE).
Custom code added in this repo is also GPL-2.0 unless a subdirectory
declares otherwise (e.g. `tools/rme-clientid/` is under its own EULA).

Third-party attributions: [CREDITS.md](CREDITS.md).
