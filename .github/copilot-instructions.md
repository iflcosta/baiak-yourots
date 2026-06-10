# GitHub Copilot Instructions (Baiak-Yourots)

> Context for AI coding assistants (GitHub Copilot, Cursor, etc.). Read
> this before suggesting code in this repo. The full project context lives
> in [AGENTS.md](../../AGENTS.md) and [docs/](../).

## Project at a glance

- **Open Tibia server** built on **TFS 1.8** (C++17, Lua 5.1, MariaDB),
  talking protocol **8.6** to the **AstraClient** front-end.
- Custom code is a thin layer on top of three upstreams. The
  modifications live in the existing TFS/AstraClient tree — we are
  NOT building a new engine, we are extending an existing one.
- **Spec-Driven Development**: docs/spec.md and docs/todo.md come
  FIRST, code comes SECOND. Update them with the change.

## Hard rules (read before suggesting code)

1. **TFS 1.x OOP Lua API only.** Legacy TFS 0.4 procedural functions
   (`doPlayerSendTextMessage`, `doPlayerAddItem`, `getCreaturePosition`,
   `doRemoveCreature`, etc.) DO NOT EXIST in TFS 1.x and will cause
   engine errors. Always use the OOP equivalents:
   `Player(cid)`, `player:sendTextMessage(...)`, `player:addItem(...)`,
   `creature:getPosition()`, `creature:teleportTo(Position(...))`,
   `creature:remove()`.
2. **C++ scripts in `server/data/scripts/` follow the Lua template**
   in [AGENTS.md §Script Template](../../AGENTS.md). `local config = {}`
   at the top, nil-check entities, `db.asyncQuery` for writes.
3. **No global variables** in Lua scripts.
4. **Never concatenate raw user input** into SQL strings. Use
   parameterized queries / escaped values.
5. **Commit message = Conventional Commits in English**, scoped
   (`feat(vip):`, `fix(login):`, `chore(deps):`).
6. **No secrets / API keys** in code. No hardcoded passwords.
7. **Gitflow**: branch from `develop` as
   `feature/<scope>-<short-desc>` or `fix/<short-desc>`. Never PR
   directly to `master`.

## Style

- **Lua**: 4-space indent, snake_case for variables/functions,
  PascalCase for classes, `local` everywhere unless required.
- **C++**: Follow the file's existing style. Most files in `server/src/`
  use Allman braces, 4-space indent, `m_` prefix for private members.
- **.ps1**: Verb-Noun naming, `param()` block at the top,
  `.SYNOPSIS` / `.DESCRIPTION` / `.EXAMPLE` comment-based help.
  Validate syntax with `[System.Management.Automation.Language.Parser]`.

## Build / test

- Local dev: Windows 10/11, VS 2022 Build Tools, vcpkg at
  `C:\vcpkg`, MariaDB 12.3, 7-Zip, Python 3.12.
- Build/run scripts: `scripts/build-server.ps1`,
  `scripts/build-client.ps1`, `scripts/run-server.ps1`.
- Server binary lives at `server/tfs.exe`.
- Client binary lives at `client/AstraClient.exe`.
- Schema: `server/schema.sql`, database `baiak_tfs18` on MariaDB
  port 3306.

## Common gotchas (see [docs/build-troubleshoot.md](../../docs/build-troubleshoot.md))

- The repo has nested `.git` folders from upstream clones. They must
  be removed before `git add` or git treats the directory as a
  submodule.
- `client/data/things/860/{Tibia.dat, Tibia.spr}` (431 MB) is
  gitignored. Don't suggest committing it.
- `tools/rme-clientid/data/` (112 MB of Tibia client version
  references) is committed on purpose — don't suggest `.gitignore`-ing
  it.
- Schema: `player_rewarditems` table is created at runtime; if
  missing, players can't save. The fix is in `docs/database.md`.

## Pointers

- [AGENTS.md](../../AGENTS.md) — project overview, status, log
- [spec.md](../../spec.md) — current product spec
- [todo.md](../../todo.md) — current task list
- [docs/conventions.md](../../docs/conventions.md) — code conventions
- [docs/architecture.md](../../docs/architecture.md) — system architecture
- [docs/local-dev.md](../../docs/local-dev.md) — clone + run
- [docs/build-troubleshoot.md](../../docs/build-troubleshoot.md) — gotchas
- [docs/database.md](../../docs/database.md) — schema + migrations
- [docs/spec-driven-development.md](../../docs/spec-driven-development.md) — SDD methodology
- [docs/agents/](../../docs/agents/) — multi-agent role profiles
