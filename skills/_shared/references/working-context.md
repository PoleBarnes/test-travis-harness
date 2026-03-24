# Working Context — Persistent Session Memory

## Overview

The working context file (`.harness/working-context.md`) provides persistent memory across Claude Code sessions. It lives in the project root under the `.harness/` directory, which is gitignored. This file is never committed — it is local working state only.

**Location**: `<project-root>/.harness/working-context.md`

---

## File Format / Template

```markdown
# Working Context

Last updated: 2026-03-18 14:30

## Active Work

- PROJ-123 (implement flash write journal)
- PROJ-124 (fix retry logic in sync handler)

## Recent Decisions

- Chose append-only log over WAL for simplicity (2026-03-17)
- Deferred pagination to Phase 2 per stakeholder call (2026-03-16)

## Parked Work

- Email migration research — blocked on API access
- Refactor auth middleware — low priority, revisit next sprint

## Session Log

- 2026-03-18 14:30: branch=feature/PROJ-123-flash-write, 3 commits, 5 files modified
- 2026-03-18 09:15: branch=feature/PROJ-123-flash-write, 1 commits, 2 files modified
- 2026-03-17 16:00: branch=main, 0 commits, 0 files modified
```

---

## Section Ownership

| Section | Written By | Read By |
|---------|-----------|---------|
| **Active Work** | `/plan`, `/implement`, `/capture` | `/pm`, `/implement`, `/catch-me-up`, `/pr`, `/timecard`, `/estimate` |
| **Recent Decisions** | `/plan`, `/triage`, `/implement` | `/pm`, `/implement`, `/vv`, `/catch-me-up`, `/pr` |
| **Parked Work** | `/capture` | `/pm`, `/catch-me-up`, `/implement` |
| **Session Log** | `session-stop.sh` hook (auto) | `session-context.sh` hook (auto), `/pm`, `/catch-me-up`, `/timecard` |
| **Last updated** | `session-stop.sh` hook (auto) | All skills (informational) |

Skills must only write to their owned sections. When updating, read the entire file, modify only the owned section(s), and write back the full file to preserve other sections.

---

## Read Pattern

Skills that consume working context should use this pattern:

1. **Check existence** — if `.harness/working-context.md` does not exist, proceed normally without context. Never error on a missing file.
2. **Parse sections** — read the file and extract the relevant `## Section` block(s). Each section runs from its `## Heading` to the next `## Heading` or end of file.
3. **Graceful degradation** — if a section is missing or empty, treat it as having no data. Do not prompt the user to create the file.

```bash
# Bash example: extract Active Work items
CONTEXT_FILE=".harness/working-context.md"
if [[ -f "$CONTEXT_FILE" ]]; then
    active=$(sed -n '/^## Active Work/,/^## /{/^- /p}' "$CONTEXT_FILE")
fi
```

---

## Write Pattern

Skills that update working context should use this pattern:

1. **Read existing** — read the full file content (or start from the template if file doesn't exist).
2. **Update owned sections only** — replace content within the owned `## Section` boundaries. Preserve all other sections verbatim.
3. **Preserve structure** — keep the heading order, comment lines, and overall markdown structure intact.
4. **Update timestamp** — update the `Last updated:` line at the top when making changes.
5. **Create directory** — `mkdir -p .harness` before writing if the directory doesn't exist.

```bash
# Bash example: ensure directory and file exist
mkdir -p .harness 2>/dev/null || true
if [[ ! -f ".harness/working-context.md" ]]; then
    # Create from template (see session-stop.sh create_template function)
fi
```

---

## Graceful Degradation Rules

- **File missing**: Proceed without context. Do not create the file unless performing a write operation.
- **Section missing**: Treat as empty. Do not add missing sections during a read-only operation.
- **Malformed content**: Best-effort parsing. Skip lines that don't match expected patterns.
- **Permissions error**: Log a warning if possible, but never fail the skill or hook.
- **Never error**: All working context operations are advisory. A skill must complete its primary function regardless of working context availability.
