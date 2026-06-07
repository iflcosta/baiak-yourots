---
name: Bug report
about: Server / client / script misbehavior
title: "[bug] "
labels: bug
assignees: iflcosta
---

## What happened

<!-- One-line description of the bug. -->

## Reproduction steps

1.
2.
3.

## Expected behavior

<!-- What you expected to happen. -->

## Actual behavior

<!-- What actually happened. Paste server logs / client logs / screenshots. -->

## Environment

- Server commit: `git rev-parse HEAD` (run in repo root)
- Client commit: same
- OS: Windows 10 / 11
- Server: Release / Debug, config.lua customizations
- MariaDB version: `SELECT VERSION();`

## Logs

```
<!-- Paste the relevant lines from server/data/logs/*.log or
     client/otclientv8.log here. -->
```

## Severity

- [ ] Critical (server crash, data corruption, exploit)
- [ ] High (feature broken, no workaround)
- [ ] Medium (feature broken, workaround exists)
- [ ] Low (cosmetic, typo, polish)
