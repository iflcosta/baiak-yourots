# AGENTS.md — Baiak-Yourots TFS 1.8 (Protocol 8.6)

## Project Overview
This is an **Open Tibia Server** built on **TFS 1.8**, downgraded to serve clients on the **8.6 protocol**.
The gameplay style is **Baiak-Yourots**: fast-paced PvP, custom teleports, VIP system, accelerated progression.

## Agent Profiles
Each agent in this project has a defined role documented in `docs/agents/`:
- `docs/agents/agent_leader.md` — Architect / Systems Engineer (planning, specs, task decomposition)
- `docs/agents/agent_developer.md` — Lua/C++ Developer (code implementation)
- `docs/agents/agent_qa.md` — QA Reviewer (bug hunting, security audits, legacy API detection)
- `docs/agents/agent_client.md` — OTClient / UI Specialist (AstraClient + Ultralight)


### Directory Layout
```
c:\baiak-yourots\
├── server/                  ← TFS 1.8 engine (C++ source + Lua scripts)
│   ├── src/                 ← C++ engine source
│   ├── data/
│   │   ├── scripts/         ← Lua scripts (actions, spells, movements, etc.)
│   │   │   ├── actions/
│   │   │   ├── spells/
│   │   │   ├── movements/
│   │   │   ├── talkactions/
│   │   │   ├── creaturescripts/
│   │   │   ├── globalevents/
│   │   │   └── eventcallbacks/
│   │   ├── events/          ← Global gameplay event overrides
│   │   ├── monsters/        ← Monster XML definitions
│   │   ├── npc/             ← NPC Lua and XML
│   │   └── world/           ← Map files (.otbm)
│   ├── config.lua           ← Server configuration (MySQL, ports, rates)
│   └── schema.sql           ← MySQL database schema
└── client/                  ← AstraClient (OTClient-based, protocol 8.6)
```

---

## CRITICAL: Mandatory Lua Syntax Rules (TFS 1.x OOP)

All Lua scripts in this project use the **TFS 1.x object-oriented API exclusively**.
**NEVER** use legacy TFS 0.4 / 0.3.6 procedural functions. They do not exist in this engine.

### ✅ CORRECT — TFS 1.x OOP API
```lua
local player = Player(cid)
if not player then return end

player:sendTextMessage(MESSAGE_STATUS, "Hello!")
player:addItem(2160, 10)
player:removeMoney(1000)
player:getStorageValue(12345)
player:setStorageValue(12345, 1)
creature:getPosition()
creature:teleportTo(Position(100, 100, 7))
creature:remove()
```

### ❌ FORBIDDEN — TFS 0.4 Legacy API (will cause engine errors)
```lua
-- These functions DO NOT EXIST in TFS 1.x. Never use them:
doPlayerSendTextMessage(cid, class, text)
doPlayerAddItem(cid, itemid, count)
doPlayerRemoveMoney(cid, amount)
getPlayerStorageValue(cid, key)
doPlayerSetStorageValue(cid, key, value)
getCreaturePosition(cid)
doTeleportThing(cid, position)
doRemoveCreature(cid)
doCreatureSetLookDir(cid, dir)
```

---

## Coding Standards

### Script Template
Every script must follow this structure:
```lua
local config = {
    -- All configurable values declared here at the top
    itemId = 2160,
    reward = 10,
    storageKey = 12345,
}

local handler = function(player, item, fromPosition, target, toPosition, isHotkey)
    if not player then return end
    -- logic here using config.* values
end

-- Registration at the bottom
local myAction = Action()
myAction.onUse = handler
myAction:register()
```

### Rules
- Always declare `local config = {}` at the top of each script.
- Always nil-check entity references: `if not player then return end`
- Use `db.asyncQuery` for database writes, `db.query` only for synchronous reads.
- Never concatenate raw user input into SQL strings.
- Use `data/events/scripts/` for global mechanic overrides (damage, healing, death).
- Avoid global variables; everything must be `local`.

---

## Project Status
Currently in **Phase 1A: Servidor Rodando Localmente**.

### ✓ Completed (Phase 1)
- [x] TFS 1.8 server repository cloned → `server/`
- [x] AstraClient repository cloned → `client/`
- [x] `config.lua` configured for local dev (MySQL: `baiak_tfs18`, user: `root`)
- [x] Agent profiles created → `docs/agents/`

### ✓ Completed (Phase 1A)
- [x] MariaDB 12.3 instalado e rodando (porta 3306)
- [x] Database `baiak_tfs18` criado com schema.sql importado
- [x] VS 2022 Build Tools + vcpkg instalados
- [x] Dependências vcpkg instaladas (abseil, asio, fmt, lua, libmariadb, openssl, pugixml, spdlog, etc.)
- [x] TFS 1.8 compilado → `theforgottenserver-x64.exe`
- [x] Servidor rodando localmente (portas 7171/7172)
- [x] `server_config.lua` validado para AstraClient (astraClientOnly=false, demais defaults)
- [x] Conta Account Manager padrão (id=1, password=1) disponível

### Pending
- [x] Validar acesso com AstraClient (teste manual de login) — conta `iflopes2`, char Iago Lopes lv 2000
- [x] Fazer primeiro commit no git (`de4742b` em `master`, 10186 arquivos, 207.6 MB no `.git`)
- [x] Repositório público criado em https://github.com/iflcosta/baiak-yourots
- [x] Branch `develop` criada e configurada como default no GitHub
- [x] `.gitignore` + `.gitattributes` cobrindo ~10 GB de build outputs e deps
- [x] Scripts de bootstrap em `scripts/` (setup / build-server / build-client / run-server / stop-server / minimap-export)
- [x] Minimap funcional com RME (cores exatas, void transparente) — ver `docs/minimap-procedure.md`

### Next Phases
- Phase 2: Map, Cities & Teleports
- Phase 3: Systems & Spells (VIP, PvP events, custom actions)
- Phase 4: Balance, QA & Deployment

---

## Git Workflow (gitflow light)

Two long-lived branches on `origin`:
- `master` — production / stable, updated only from `develop` via PR
- `develop` — default branch on GitHub, integration branch for the next release

Short-lived branches (off `develop`):
- `feature/<scope>-<short-desc>` — e.g. `feature/vip-system`, `feature/daily-reward`
- `fix/<short-desc>` — bug fixes against `develop`
- `release/<version>` — release stabilization (bump versions, changelog)
- `hotfix/<short-desc>` — urgent fixes branched off `master`, merged back to `master` and `develop`

### Typical feature cycle
```bash
git checkout develop
git pull
git checkout -b feature/vip-system
# ... code, commit often ...
git push -u origin feature/vip-system
# open PR -> develop on GitHub
# after review + merge: branch deleted automatically (configure in repo settings)
```

### Releases
```bash
git checkout develop
git checkout -b release/0.2.0
# bump version.lua / config.lua serverName / etc
git commit -m "chore(release): 0.2.0"
# open PR release/0.2.0 -> master
# after merge, tag master:
git checkout master && git pull
git tag -a v0.2.0 -m "Release 0.2.0"
git push origin v0.2.0
# back-merge release into develop:
git checkout develop && git merge --no-ff release/0.2.0
git push
```

### Commit message convention
Conventional Commits in English (so `git log --oneline` reads cleanly):
- `feat:` new feature
- `fix:` bug fix
- `chore:` tooling, deps, refactors without gameplay change
- `docs:` documentation only
- `refactor:` code change without functional change
- `test:` add or fix tests
- `perf:` performance improvement

Always include a scope when it makes sense: `feat(vip):`, `fix(login):`, `chore(deps):`.

---

## Build & Run Scripts (`scripts/`, PowerShell 5.1)

| Script | What it does |
|---|---|
| `setup.ps1` | Idempotent bootstrap: vcpkg deps, ultralight-sdk, 860.dat/.spr, MariaDB + schema import, .env |
| `build-server.ps1 [-Config Debug|Release] [-Clean]` | CMake configure + build of TFS 1.8, copies binary to `server/` |
| `build-client.ps1 [-Config Debug|Release] [-Clean]` | CMake configure + build of AstraClient, copies binary to `client/` |
| `run-server.ps1` | Stops any running TFS, starts `theforgottenserver-x64.exe` in foreground |
| `stop-server.ps1` | Stops any running TFS process |
| `minimap-export.ps1` | Guides through RME export + runs `rme_bmp_to_png.py` to regenerate 192 PNGs |

Run from repo root. Set `$env:VCPKG_ROOT` to override the default `C:\vcpkg`.

---

## Key Config Values (config.lua)
| Parameter | Value |
|---|---|
| `serverName` | `"Baiak-Yourots"` |
| `mysqlDatabase` | `"baiak_tfs18"` |
| `mysqlUser` | `"root"` |
| `loginProtocolPort` | `7171` |
| `gameProtocolPort` | `7172` |
| `worldType` | `"pvp"` |

---

## Progress Log

- **2026-06-06**: Projeto iniciado. Estrutura clonada (TFS 1.8 + AstraClient). Perfis de agente criados em `docs/agents/`. Iniciando Fase 1A (setup local).
- **2026-06-06**: MariaDB 12.3, VS 2022 Build Tools e vcpkg instalados. Dependências compiladas. TFS 1.8 compilado com sucesso. Servidor rodando em 7171/7172. DB `baiak_tfs18` com schema importado. Aguardando teste de login com AstraClient.
- **2026-06-07**: Login AstraClient validado (account `iflopes2`/pw `f2w4r8vu`, char Iago Lopes lv 2000). Bug save do player resolvido (criada tabela `player_rewarditems` faltando no schema). Iago Lopes reposicionado em (1000,1000,7).
- **2026-06-07**: Minimap pipeline completo: RME CLIENTID compilado + prebuilt instalado em `tools/rme-clientid/`. RME exporta 16 BMPs com paleta 6x6x6 (mesma do OTClient). Conversor `server/tools/rme_bmp_to_png.py` gera 192 PNGs `X_Y_Z.png` com void transparente. Procedimento documentado em `docs/minimap-procedure.md`.
- **2026-06-07**: Primeiro commit `de4742b` em `master` (10186 arquivos, 207.6 MB no `.git`). Removidos `.git/` aninhados de `client/`, `server/`, `tools/rme-clientid/` que estavam atrapalhando o `git add`. `.gitignore` cobre 10.5 GB de build outputs, DLLs, vcpkg, MariaDB data, ultralight-sdk, OTClient `.minimap` raws. `.gitattributes` com LF padrão, CRLF só em `.ps1/.bat/.cmd`.
- **2026-06-07**: Repositório público criado em https://github.com/iflcosta/baiak-yourots (Phase 1B). `develop` branch é o default no GitHub. Scripts `scripts/{setup,build-server,build-client,run-server,stop-server,minimap-export}.ps1` cobrem o ciclo build→run→stop→minimap. Fluxo gitflow (master/develop + feature/fix/release/hotfix) documentado nesta seção.

## References
- TFS 1.x Lua API: https://github.com/otland/forgottenserver/wiki
- AstraClient repo: https://github.com/Mateuzkl/AstraClient
- Ultralight integration: https://mateuzkl.github.io/Ultralight_-_OTClient/
