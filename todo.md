# Baiak-Yourots Todo

> Living task list. The leader agent keeps this in sync with `spec.md` and
> chat progress. Tasks are ordered by current Phase priority.

## Legend
- [ ] pending
- [~] in progress
- [x] done
- [!] blocked (see Notes)

## Phase 1 — Foundation (✅ done)
- [x] TFS 1.8 + AstraClient running locally
- [x] First commit pushed to GitHub (de4742b on master)
- [x] gitflow (develop) + build/run scripts (Phase 1B)

## Phase 1B — Documentation (✅ done)
- [x] README.md / LICENSE / CREDITS.md
- [x] docs/{local-dev, build-troubleshoot, database, architecture,
       spec-driven-development, conventions}.md
- [x] docs/agents/*.md updated to current state
- [x] .github/{CODEOWNERS, PR template, issue templates,
       copilot-instructions}

## Phase 2 — Map, Cities & Teleports (✅ done)
- [x] Catalog aethrium systems for import decision
  ([docs/phase-2-analysis.md](docs/phase-2-analysis.md))
- [x] **Decision**: Import aethrium map only (no systems)
- [x] Import aethrium `real01.otbm` → `world.otbm` (2262x2131, v2)
- [x] Add `real02-spawn.xml` / `real02-house.xml` (aethrium data)
- [x] Remove old `world-spawn.xml` / `world-house.xml`
- [x] Regenerate minimap (1152 PNGs from RME exports)
  (`0717aad`)
- [x] Verify map + minimap ingame with AstraClient
- [x] ~~City teleport NPC~~ (removed from scope — aethrium doesn't ship one)

## Phase 3 — Systems & Spells

### VIP System (spec: docs/specs/vip-system.md — agreed 2026-06-09)
- [x] **Implementation complete** (`73cea6f` merged to develop)
  - C++ engine: `player.h`/`player.cpp`/`luaplayer.cpp`/`iologindata.cpp`
    patches (5 public methods + 5 Lua bindings)
  - 2 DB migrations: `48.lua` + `49.lua` (idempotent, run on server boot)
  - 7 server Lua scripts: tier tables, login perks, gated tiles
    (AIDs 50010-12), activation scrolls (items 24774-6), `!vip` UI
    command, GM `!setvip`, extended opcode 181 protocol
  - Client: `client/mods/game_vip/` (AstraClient + Ultralight panel)
  - Integration gate: 20/20 checks passed
  - Item sprite IDs (24774-6) are provisional; will reuse existing
    ClientIDs once visual design lands (see follow-up in
    docs/specs/vip-system.md §11)
- [ ] Manual smoke tests (Section 10 of spec) — owner validation pending

### Other Phase 3 features
- [ ] Daily reward / login streak (spec TBD)
- [ ] Custom PvP event (last-man-standing)
- [ ] Custom spells / runes for the meta

## Phase 4 — Balance, QA & Deployment
- [ ] XP / loot / skill rate balance
- [ ] Security audit (SQL, dupe, NPE)
- [ ] Play-test + fix loop
- [ ] CI workflow (lint PowerShell + Python + Lua)
- [ ] Production deployment guide

## Open Questions (from spec.md §7)
- [ ] Website (account mgmt, rankings)?
- [ ] Discord integration?
- [ ] Donation / store system?

## Backlog (deferred, not currently scheduled)
- [ ] Cross-platform build (Linux TFS server)
- [ ] Reverse-proxy the login server (nginx + TLS)
- [ ] Backup rotation for MariaDB

---

## How to use this file

- When you start a task, mark it `[~]`.
- When you finish, mark it `[x]` and add a one-liner with the commit
  hash in parentheses.
- If a task is blocked, mark it `[!]` and add a "Notes" line at the
  bottom explaining the blocker.
- Reorder the "current Phase" section weekly so the most relevant work
  is at the top.
