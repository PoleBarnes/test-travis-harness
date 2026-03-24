# Session Persistence Design

Requirement: CTX-004 — Cross-session context persistence via Claude Code auto-memory.

## Overview

Skills persist structured state between sessions using `session-state.json` in the project's `.harness/` directory. This enables skills to remember context from previous invocations (e.g., last active project, last timecard date, last sprint ID).

## session-state.json Schema

```json
{
  "version": "1.0",
  "lastActiveProject": "<project-key>",
  "recentWorkItemIds": [],
  "lastTimecardDate": "<ISO-date>",
  "lastSprintId": "<sprint-id>"
}
```

Each skill that reads/writes session state includes a `## Session State` section documenting which fields it uses and its merge strategy.

## MEMORY.md Conventions

- Skills may also write diagnostic notes to `MEMORY.md` via Claude Code's auto-memory
- The `/harness` skill writes to a `diagnostics.md` file linked from `MEMORY.md`
- Session state (structured JSON) and memory (freeform markdown) serve complementary purposes

## Merge Strategy

Skills use a "merge" strategy when writing session state — they read the existing file, update only their fields, and write back the full document. This prevents skills from overwriting each other's state.
