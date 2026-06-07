# Code & Contribution Conventions

> The hard rules. Read this before opening a PR.

## Lua (server scripts)

### API: TFS 1.x OOP ONLY

TFS 1.x exposes an object-oriented Lua API. TFS 0.4 procedural
functions (`doPlayerSendTextMessage`, `doPlayerAddItem`,
`getCreaturePosition`, `doRemoveCreature`, `doTeleportThing`,
`doCreatureSetLookDir`, `getPlayerStorageValue`,
`doPlayerSetStorageValue`, `getCreaturePosition`, etc.) **DO
NOT EXIST in TFS 1.x**. Using them will cause engine errors at
runtime, not at parse time. Always use the OOP equivalents:

```lua
-- CORRECT
local player = Player(cid)
if not player then return end
player:sendTextMessage(MESSAGE_STATUS, "Hello!")
player:addItem(2160, 10)
player:removeMoney(1000)
player:getStorageValue(12345)
player:setStorageValue(12345, 1)
local pos = player:getPosition()
player:teleportTo(Position(100, 100, 7))
player:remove()
```

```lua
-- WRONG — WILL BREAK
doPlayerSendTextMessage(cid, MESSAGE_STATUS, "Hello!")
doPlayerAddItem(cid, 2160, 10)
doPlayerRemoveMoney(cid, 1000)
getPlayerStorageValue(cid, 12345)
doPlayerSetStorageValue(cid, 12345, 1)
getCreaturePosition(cid)
doTeleportThing(cid, position)
doRemoveCreature(cid)
doCreatureSetLookDir(cid, dir)
```

This is enforced by the QA agent (see
[docs/agents/agent_qa.md](agents/agent_qa.md)).

### Script template

Every script must follow this structure. Place the file in
the correct TFS subdirectory (`data/scripts/actions/`,
`data/scripts/spells/`, etc.):

```lua
local config = {
    -- All configurable values declared here at the top
    itemId       = 2160,
    reward       = 10,
    storageKey   = 12345,
    requiredVocation = { "Knight", "Elite Knight" },
}

local handler = function(player, item, fromPosition, target, toPosition, isHotkey)
    if not player then return end
    -- logic here, using config.* values
end

-- Registration at the bottom
local myAction = Action()
myAction.onUse = handler
myAction:register()
```

### Rules

- `local config = {}` at the top of every script.
- `if not player then return end` (or equivalent nil-check) at
  the top of every handler.
- `local` for everything unless the engine requires a global
  (event registration, etc.).
- `db.asyncQuery` for writes, `db.query` only for synchronous
  reads.
- Never concatenate raw user input into SQL. Use parameterized
  queries or escape the input.
- Use `server/data/events/scripts/` for global mechanic
  overrides (damage, healing, death).

### Style

- 4-space indent (not tabs).
- snake_case for variables and functions.
- PascalCase for classes.
- String literals: prefer double-quotes for static text,
  single-quotes for keys/identifiers.
- Max line length 120.

## Lua (client scripts)

OTClient framework classes. `g_game`, `g_resources`, `UIWidget`,
`g_minimap`, etc. The minimap subsystem is in
`client/modules/game_minimap/minimap.lua`. See
[minimap-procedure.md](minimap-procedure.md) for the load/save
cycle.

## C++

- C++17.
- Follow the file's existing style. Most files in `server/src/`
  use Allman braces, 4-space indent, `m_` prefix for private
  members, `s_` prefix for static members.
- No C-style casts (`(int)x`). Use `static_cast<int>(x)`.
- No raw `new`/`delete` outside of `std::unique_ptr` ownership
  (use `std::make_unique`).
- `clang-format` config is in `server/.clang-format`. Run
  `clang-format -i <file>` on edited C++ files.
- Don't add new dependencies without updating `vcpkg.json` and
  documenting the reason in the PR body.

## PowerShell (.ps1)

- PowerShell 5.1+ compatible.
- `[CmdletBinding()]` at the top.
- `param()` block immediately after.
- `$ErrorActionPreference = 'Stop'` near the top.
- Use full cmdlet names (`Get-ChildItem`, `Set-Content`), not
  aliases.
- Comment-based help: `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`,
  `.EXAMPLE`, `.NOTES`.
- Validate syntax locally:
  ```powershell
  $tokens = $null; $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile(
      'C:\path\to\script.ps1', [ref]$tokens, [ref]$errors) | Out-Null
  if ($errors) { $errors | Format-List }
  ```

## SQL

- Schema in `server/schema.sql`, migrations in
  `server/data/migrations/NNNN_<name>.sql`.
- Always `CREATE TABLE IF NOT EXISTS` / `ALTER TABLE ... ADD IF
  NOT EXISTS` for idempotency.
- One change per migration file.
- Register the migration in the `migrations` table.
- Update [docs/database.md](database.md) with the new table /
  column / convention.

## Git

### Branching (gitflow light)

- `master` — stable, updated only via PR from `develop`.
- `develop` — default branch on GitHub. Branch from here.
- `feature/<scope>-<short-desc>` — new features.
- `fix/<short-desc>` — bug fixes.
- `release/<version>` — release stabilization, branched from
  `develop`, merged to `master` and back to `develop`.
- `hotfix/<short-desc>` — urgent fixes, branched from
  `master`, merged to `master` and back to `develop`.

Full flow in [AGENTS.md § Git Workflow](../AGENTS.md#git-workflow-gitflow-light).

### Commit messages

Conventional Commits in English:

```
<type>(<scope>): <short summary>

<body explaining WHY, not WHAT — the diff is the WHAT.

<footer with any breaking changes / issue references>
```

Types: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`,
`perf`. Always include a scope: `feat(vip):`, `fix(login):`,
`chore(deps):`. Subject ≤ 72 chars, body wrapped at 72.

### What NOT to commit

`.gitignore` is the source of truth, but call out:

- `*.dat`, `*.spr`, `*.otbm` (large game data) — except the
  canonical `server/data/world/world.otbm` and `server/data/items/items.otb`
  which are versioned.
- `*.pch`, `*.iobj`, `*.ilk`, `*.exp`, `*.lib`, `*.dll`,
  `*.exe` (build artifacts).
- `vcpkg_installed/`, `build/`, `mariadb_data/`,
  `ultralight-sdk/`.
- Secrets, API keys, passwords, RSA private keys (use env vars
  + `.env`, never commit).

## Pull requests

Use the template at `.github/PULL_REQUEST_TEMPLATE.md`. Link
the relevant `spec.md` section / `todo.md` item. AI-assisted
PRs are welcome — disclose the tool used in the template.
