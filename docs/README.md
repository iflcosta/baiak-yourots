# Documentation Index

> The full project context for humans and AI agents. Top-level files
> (`README.md`, `AGENTS.md`, `spec.md`, `todo.md`) cover the entry
> points; this folder is the deep-dive.

## For humans

| File                                       | What's in it                              |
| ------------------------------------------ | ----------------------------------------- |
| [local-dev.md](local-dev.md)               | Clone -> run quickstart                   |
| [architecture.md](architecture.md)         | System architecture + data flow           |
| [database.md](database.md)                 | Schema overview + migrations              |
| [build-troubleshoot.md](build-troubleshoot.md) | Gotchas + fixes                      |
| [conventions.md](conventions.md)           | Lua / C++ / Git / PR conventions          |
| [minimap-procedure.md](minimap-procedure.md) | RME -> PNG -> factory reset             |
| [spec-driven-development.md](spec-driven-development.md) | The methodology             |

## For AI agents

| File                                       | Purpose                                   |
| ------------------------------------------ | ----------------------------------------- |
| [agents/agent_leader.md](agents/agent_leader.md)     | Architect / planner / spec author |
| [agents/agent_developer.md](agents/agent_developer.md) | Lua/C++ implementer              |
| [agents/agent_qa.md](agents/agent_qa.md)             | Code reviewer / security auditor |
| [agents/agent_client.md](agents/agent_client.md)     | OTClient / Ultralight specialist  |

Each agent profile lists its persona, hard rules, workflow, and the
files it owns.

## Reading order for a new contributor

1. [README.md](../README.md) — orientation
2. [AGENTS.md](../AGENTS.md) — project overview, status, log
3. [spec.md](../spec.md) — what's being built
4. [todo.md](../todo.md) — what's being worked on
5. [docs/architecture.md](architecture.md) — how it all fits together
6. [docs/local-dev.md](local-dev.md) — how to run it
7. [docs/conventions.md](conventions.md) — how to write code that fits

## Reading order for an AI agent

1. [AGENTS.md](../AGENTS.md) — non-negotiable rules + status
2. [.github/copilot-instructions.md](../.github/copilot-instructions.md) — hard rules summary
3. [docs/spec-driven-development.md](spec-driven-development.md) — methodology
4. The agent's own profile in [agents/](agents/)
5. The relevant deep-dive doc (architecture / database / conventions)
6. [spec.md](../spec.md) and [todo.md](../todo.md) for current work
