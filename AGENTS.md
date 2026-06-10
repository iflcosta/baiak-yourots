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
Currently in **Phase 2: Map ✅ done — advancing to Phase 3: Systems & Spells**.

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
- [x] TFS 1.8 compilado → `tfs.exe`
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
## CRITICAL: Mandatory OTClient/AstraClient API Rules (client mods)

These are the gotchas I hit while building `game_vip` (the VIP panel
mod). They are NOT obvious from reading existing mods and will cost
you a verifier rejection if you get them wrong.

### 1. Use `g_ui.loadUIFromString` for OTML-from-string, NOT `createWidgetFromOTMLString`

- `g_ui.createWidgetFromOTMLString` does **not exist**. The bound APIs are:
  - `g_ui.loadUI(file_path, parent)` — load a static `.otui` file
  - `g_ui.loadUIFromString(otml_string, parent)` — load an OTML literal
  - `g_ui.createWidgetFromOTML(otmlNode, parent)` — takes a pre-parsed
    `OTMLNodePtr`, NOT a string
- For an inline OTML wrapper, use `loadUIFromString`. See
  `client/src/framework/luafunctions.cpp:430-434`.

### 2. Global keybinds use `g_keyboard.bindKeyPress`, NOT `g_keyboard.onPress`

- `g_keyboard` is a plain Lua table — it has no signal mechanism. Doing
  `connect(g_keyboard, { onPress = fn })` is **dead code**: nothing ever
  fires `g_keyboard.onPress`.
- The canonical pattern is `g_keyboard.bindKeyPress('Ctrl+V', callback)`,
  which installs the combo on the widget's `boundKeyPressCombos` table
  — that table IS what the input system dispatches. See
  `client/modules/corelib/keyboard.lua:190` (and `unbindKeyPress` at
  line 254). Existing reference: `mods/game_helper/helper.lua:1270`
  binds `Tab` this way.

### 3. Sandboxed mods that expose JS-callable callbacks MUST write to `_G`

- The Ultralight C++ dispatcher does
  `g_lua.evaluateExpression("game_vip.onActivateSubscription('123')")`,
  and `evaluateExpression` runs the chunk in the real global env (`_G`).
- Sandboxed envs have `__index = _G` (reads fall through), but writes
  stay local. So if a sandboxed mod does `local game_vip = { onX = ... }`,
  the C++ dispatcher's lookup of `game_vip` will find **nil** in `_G`.
- The pattern that works: `_G.game_vip = _G.game_vip or {}` followed by
  `_G.game_vip.onX = function(...) ... end`. Same trick is used in
  `mods/game_helper/timer_panel.lua:878` for
  `_G.modules.game_helper.timerPanel`.

### 4. `ProtocolGame.unregisterExtendedOpcode` throws on empty slot

- Source: `client/modules/gamelib/protocolgame.lua:80-82` —
  `error('Opcode is not registered.')` if the slot is empty.
- This matters in `onGameStart`: if the mod was previously registered
  and terminate unregisterd it (or the slot was never filled), the next
  `onGameStart` will throw here and abort the rest of the handler
  (no re-register, no `request_update`).
- Fix: always `pcall(ProtocolGame.unregisterExtendedOpcode, opcode)`
  before `registerExtendedOpcode` in `onGameStart`. This makes
  `/reloadgame_vip` while in-game work correctly.

### 5. Ultralight HTML base dir

- `UltraLightManager::detectUltralightBaseDir()` (line 571) probes
  `<temp>/ultralight`, `.`, `../ultralight-sdk`, `../../ultralight-sdk`
  — returning the first one with `resources/cacert.pem`. The local
  install has it at `C:\baiak-yourots\ultralight-sdk` (candidate #3).
- `loadFile()` (line 453) builds `file:///<baseDir><htmlPath>`, so the
  actual served URL is `file:///C:/baiak-yourots/ultralight-sdk/vip/vip_panel.html`.
- Mods shipping HTML/CSS/JS/PNG assets must mirror them under
  `<ultralight-sdk>/vip/` at runtime. The standard pattern is to use
  `io.open` + `os.execute('mkdir ...')` in `init()`/`onGameStart()` to
  copy from the mod's `styles/` + `assets/` dirs (sandboxed mods CAN
  use `io` and `os` — only the global env is restricted, not stdlib).

### 6. The OTUI wrapper around the Ultralight view

- The HTML view is just a textured bitmap. To make it anchor + move
  with the rest of the UI, wrap it in a `Panel` (OTUI) via
  `g_ui.loadUIFromString(...)`, then `g_ultralight.setViewPosition(name, 0, 0)`
  on the panel's top-left.
- Make the wrapper `background: #00000000` (transparent) so only the
  HTML content is visible. The Ultralight view itself is also
  `is_transparent: true` (see `UltraLightManager::createView` line 369).

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
| `run-server.ps1` | Stops any running TFS, starts `tfs.exe` in foreground |
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
- **2026-06-07**: Documentação completa (Phase 1B+). Adicionados `README.md`, `LICENSE` (GPL-2.0 herdado do TFS), `CREDITS.md`, `spec.md` (Phases 2-4), `todo.md`, `docs/README.md` (índice), `docs/{local-dev, build-troubleshoot, database, architecture, spec-driven-development, conventions}.md`. Perfis de agente (`docs/agents/*.md`) atualizados com estado atual, áreas ownadas, workflow detalhado. GitHub: `.github/{CODEOWNERS, PULL_REQUEST_TEMPLATE.md, ISSUE_TEMPLATE/{bug_report,feature_request}.md, copilot-instructions.md}`. Metodologia: Spec-Driven Development — specs primeiro, código depois (justificado pelo desenvolvimento IA-based).
- **2026-06-09**: Phase 2 completo (`2768ada`). Mapa aethrium `real01.otbm` (2262x2131, 8 cidades, 301 casas) importado. Spawn/house XMLs do aethrium integrados. Minimap regenerado (1152 PNGs de 16 BMPs RME). Login AstraClient validado — mapa funcional, personagem Iago Lopes (lv 2000) logado com sucesso. City teleport removido do scope. Phase 3 (Systems & Spells) em aberto.
- **2026-06-09**: VIP system spec draft criada em `docs/specs/vip-system.md` (status: `draft`, awaiting approval). 3 tiers cumulativos (Bronze→Silver→Gold), pagamento mensal, **subscription stacking LIFO com escolha do player** (LIFO é o default, mas o player pode ativar qualquer subscription da pilha via UI; auto-fallback ao expirar usa o tier mais alto restante). C++ patches + 2 DB migrations + server Lua + client Ultralight panel. Inspirado pelo aethrium-baiak (referência de arquitetura) mas custom-built com player choice + auto-fallback. `todo.md` Phase 3 detalhado com sub-tarefas do VIP.
- **2026-06-09**: VIP system spec aprovada pelo user (`status: agreed`). Implementação iniciada via `mavis-team` (paralelo: `agent_developer` faz C++ + Lua, `agent_client` faz HTML/CSS/JS via Ultralight). 16 sub-tarefas no `todo.md` em status `[~]`.

## References
- TFS 1.x Lua API: https://github.com/otland/forgottenserver/wiki
- AstraClient repo: https://github.com/Mateuzkl/AstraClient
- Ultralight integration: https://mateuzkl.github.io/Ultralight_-_OTClient/
