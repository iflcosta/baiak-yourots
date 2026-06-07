# Spec-Driven Development (SDD)

> Why this project is built the way it is. Most of the development
> on Baiak-Yourots is AI-assisted; spec-first is the only way that
> scales without losing intent.

## TL;DR

1. **Update `spec.md` / `todo.md` FIRST.** Code is the
   implementation of a spec, not a substitute for one.
2. **Read `AGENTS.md` and the relevant doc in `docs/` BEFORE
   writing code.** The doc tells you what's already tried, what's
   forbidden, and what's planned.
3. **Code in small, reviewable units.** One feature or fix per
   commit, one commit per PR.
4. **Update the spec/docs with the change.** If you change the
   behavior, change the spec to match. If you discover a new
   constraint, add it to the right doc.

## Why SDD, especially with AI

AI coding assistants (opencode, GitHub Copilot, Cursor) are
powerful but context-free. They will:

- Suggest a TFS 0.4 procedural function if the doc doesn't
  remind them not to.
- Reinvent a system that's already in `server/data/scripts/`.
- Forget the minimap pipeline and propose parsing the OTBM by
  hand.
- Commit a 200 MB binary because the .gitignore wasn't quoted in
  their context.

A spec + context docs are the only way to keep an AI's output
aligned with the project's intent. The investment in writing
docs upfront pays for itself the first time the AI is asked to
extend the code.

## The four artifacts

### `AGENTS.md` (root)

The non-negotiable entry point. Reads as a project briefing:

- **Project overview** (what + why)
- **Directory layout** (where things live)
- **Hard rules** (Lua OOP API only, no procedural, etc.)
- **Coding standards** (script template, commit message)
- **Project status** (current Phase, what's done)
- **Git workflow** (branching, commit format, release flow)
- **Progress log** (chronological, dated)

Anyone (human or AI) who reads `AGENTS.md` can orient themselves
in 5 minutes.

### `spec.md` (root)

The product spec. Phased, with goals and non-goals for each
phase. The "what" of the project, separated from the "how" (which
lives in `docs/`).

### `todo.md` (root)

The active task list, ordered by current Phase priority. The
"what's next" of the project. The leader agent maintains this.

### `docs/` (deep-dive)

The "how" — detailed docs that the spec points to:

| Doc                                       | What it covers                            |
| ----------------------------------------- | ----------------------------------------- |
| `docs/architecture.md`                    | System overview, data flow, file layout   |
| `docs/local-dev.md`                       | Clone, build, run                         |
| `docs/database.md`                        | Schema, migrations, storage conventions   |
| `docs/build-troubleshoot.md`              | Known issues + fixes (the gotchas)        |
| `docs/conventions.md`                     | Code style, commit messages, PR rules     |
| `docs/minimap-procedure.md`               | RME -> PNG -> factory reset               |
| `docs/spec-driven-development.md`         | This file                                |
| `docs/agents/`                            | Multi-agent role profiles                 |

## Workflow

### Starting a feature

1. Read `spec.md` and `todo.md` to confirm the feature is on
   the roadmap.
2. If it's a NEW feature, add a section to `spec.md` first
   (problem, proposed solution, scope).
3. Move the task from `[ ]` to `[~]` in `todo.md`.
4. Read the relevant deep-dive doc in `docs/` (architecture,
   conventions, build-troubleshoot, etc.) before opening the
   editor.
5. Read `.github/copilot-instructions.md` if you're using an AI
   assistant.
6. Branch from `develop`: `git checkout -b feature/<scope>-<desc>`.

### Implementing

1. Small, scoped commits. Conventional Commits in English.
2. Self-review: run the relevant tests, check that the build
   still passes.
3. Update the relevant doc with any new gotcha you hit (build
   failure, schema fix, API quirk).
4. PR into `develop` using the PR template. Wait for review
   (even if it's you reviewing yourself the next morning).

### Finishing

1. Mark the task `[x]` in `todo.md`, link the commit hash.
2. Update `AGENTS.md` progress log with the date + one-liner.
3. After review, the branch is deleted (auto-delete on PR
   merge).

## Spec lifecycle

```
draft        spec.md section added, discussion in PR
  → agreed   merged to develop, todo.md task created
    → done    feature implemented, PR merged, todo.md checked, log updated
      → kept  spec.md remains as the historical record
```

The spec is NEVER deleted. It is amended (with a date stamp
and a one-line note about what changed and why).

## Anti-patterns (do not do)

- **Code first, doc later.** The doc gets written under deadline
  pressure and lies. Write the doc first, even if it's a stub.
- **Updating only `AGENTS.md`.** A 500-line `AGENTS.md` is a
  smell. Move deep-dive content to `docs/` and link to it.
- **Skipping the agent profiles.** If you have multiple AI
  agents (or a human + AI team), each role should know its own
  scope and rules. That's what `docs/agents/*.md` is for.
- **Out-of-scope commits.** Don't sneak a "small refactor" into
  a feature PR. Open a separate `refactor:` PR. Easier to
  review, easier to revert.
- **Editing the existing doc only.** A 6-month-old `AGENTS.md`
  with no progress log entry is a red flag. Update the log.

## What to do if you're an AI agent reading this

1. Open `AGENTS.md` first. Read it in full.
2. Open `spec.md` and `todo.md` next. Find the task you're
   supposed to work on (the user will usually name it).
3. Read the deep-dive doc named in the task's "context" field
   (or the obvious one: `docs/build-troubleshoot.md` for a
   build fix, `docs/database.md` for a schema change, etc.).
4. If your task is a `feat` and the spec doesn't mention it,
   **stop and ask**. The leader agent (or the user) will
   update `spec.md` first, then hand it back.
5. Commit with a Conventional Commits message. Reference the
   spec section in the commit body.
6. Update the doc that the task touches (e.g. add a gotcha to
   `build-troubleshoot.md` if you fixed a build issue).
7. Mark the todo item `[x]` with the commit hash.
