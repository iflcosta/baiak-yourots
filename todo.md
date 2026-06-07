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

## Phase 2 — Map, Cities & Teleports (⏳ current)
- [x] Catalog aethrium systems for import decision
  ([docs/phase-2-analysis.md](docs/phase-2-analysis.md))
- [ ] Resolve §7 of [docs/phase-2-analysis.md](docs/phase-2-analysis.md)
  (5 pending decisions: map source, outfits scope, BP UI count,
  freePremium, AETHERITE_MASTERY.md)
- [ ] Decide final custom map (RME file path, source/author)
- [ ] Import custom map into `server/data/world/world.otbm`
- [ ] Re-run minimap pipeline for the new map
  ([docs/minimap-procedure.md](docs/minimap-procedure.md))
- [ ] Add towns to `server/data/world/world-spawn.xml`
- [ ] City teleport NPC (Lua action/talkaction)
- [ ] Verify teleport interaction ingame

## Phase 3 — Systems & Spells
- [ ] VIP account flag (account DB column + storage key)
- [ ] VIP perks (cosmetic, QoL, zone access)
- [ ] Daily reward / login streak
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
