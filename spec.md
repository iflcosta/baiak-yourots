# Baiak-Yourots Product Spec

> Living spec. Update FIRST, code SECOND. See
> [docs/spec-driven-development.md](docs/spec-driven-development.md) for the
> methodology.

## 1. Vision

A fast-paced PvP Open Tibia server, playable from the AstraClient 8.6
client, that captures the Baiak-Yourots "feel":

- High XP / loot / skill rates
- Custom city teleports + event zones
- VIP system (cosmetic + QoL perks)
- 8.6 protocol (so the modern AstraClient / OTClientV8 stack works)

## 2. Non-goals (out of scope)

- New client protocol versions (we stay on 8.6)
- Mobile client
- Web client
- Cross-server federation

## 3. Players & Use Cases

| Persona       | Need                                            |
| ------------- | ----------------------------------------------- |
| Casual player | Quick login, fast progression, stable PvP       |
| Hardcore PvP  | Reliable death mechanics, gear scaling          |
| Dev / agent   | Clean code, scripts, docs to extend the server  |

## 4. Functional Requirements

### 4.1 Phase 1 — Foundation (✅ done)
- TFS 1.8 running locally on ports 7171/7172.
- AstraClient connects, login + character select + ingame work.
- Account 3 (`iflopes2`) + character Iago Lopes (lv 2000) verified.
- Minimap loaded from 192 sector PNGs, exploration persists across
  restarts (`minimap.otmm`).

### 4.2 Phase 2 — Map, Cities & Teleports (⏳ current)
- Import aethrium `real01` map (`world.otbm`, 2262×2131, 8 towns,
  301 houses) — ✅ done (`0717aad`).
- Minimap regenerated (1152 PNGs from 16 RME BMP exports) — ✅ done.
- City teleport system (NPC + tile-based) covering the map.
- Town definitions already aligned (aethrium spawn/house XMLs).

### 4.3 Phase 3 — Systems & Spells
- VIP system (account flag, perks, expiry).
- Daily reward / login streak.
- Custom PvP event (last-man-standing arena, configurable reward).
- Custom spells / runes for the Baiak-Yourots meta.

### 4.4 Phase 4 — Balance, QA & Deployment
- XP / loot / skill balancing pass.
- Full security audit (SQL injection, dupe exploits, NPEs).
- Play-test sessions, fix-and-tune loop.
- Production deployment: systemd unit, MariaDB backup, log rotation.

## 5. Non-Functional Requirements

| Requirement     | Target                                                   |
| --------------- | -------------------------------------------------------- |
| Uptime          | 99% during playtests                                     |
| Login latency   | < 200 ms local                                           |
| Map memory      | < 1 GB resident at 50 concurrent players                 |
| Code coverage   | Smoke tests for the 10 most-used spells / actions        |
| Docs            | Every public API / script template documented in `docs/` |

## 6. Tech Constraints

- **TFS 1.x OOP Lua API** only (no legacy TFS 0.4 procedural).
- **Protocol 8.6** (no higher).
- **MariaDB** (not MySQL) — better Windows support, more permissive
  defaults.
- **Windows-first dev** (this project was bootstrapped on Windows
  10/11 with VS 2022 Build Tools). Cross-platform is a stretch goal.

## 7. Open Questions

- Do we want a website (account mgmt, rankings)? → see todo.md
- Discord integration? → see todo.md
- Donation / store system? → see todo.md
