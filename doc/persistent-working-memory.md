# Persistent Working Memory Across Sessions

## Problem

Every new Claude Code session starts cold — no knowledge of what was being worked on, what decisions were made, or what threads are open. The session-state.json infrastructure exists (used by /pm and /timecard) and skills like /catch-me-up query external systems, but nothing connects local session context across sessions. 10 of 12 skills read and write zero local state.

This is the single biggest gap in the harness. Every other feature gets better once persistent memory exists — /pm recommendations improve, /catch-me-up gets smarter, stale work detection works, and context-switch recovery becomes possible.

## Proposed Solution

### Storage Layer

Two complementary files, each playing to its format's strengths:

| File | Format | Location | Purpose |
|------|--------|----------|---------|
| `session-state.json` | JSON | `~/.claude/projects/*/memory/` | Structured state — extend with `activeWorkItemId`, `lastSessionBranch` |
| `working-context.md` | Markdown | `.harness/` (gitignored, project root) | Narrative context for AI and humans |

#### working-context.md Format

```markdown
# Working Context
Last updated: 2026-03-18T14:30:00Z

## Active Work
- TRA-52: Implementing flash write journal — branch: feature/TRA-52-flash-journal

## Recent Decisions
- Chose append-only log over circular buffer for flash wear leveling (2026-03-17)

## Parked Work
- Email migration research — parked pending API access from Sarah

## Session Log
- 2026-03-18 14:30: branch=feature/TRA-52, 3 commits, 5 files modified
- 2026-03-17 16:45: branch=feature/TRA-52, 1 commit, 2 files modified
```

### Hook Changes

| Hook | Change | Script |
|------|--------|--------|
| SessionStart | Add stage: read `.harness/working-context.md`, print 2-3 line summary to terminal | `hooks/session-context.sh` (new) |
| Stop | Create: capture git state, append to Session Log in working-context.md | `hooks/session-stop.sh` (new) |

**Important constraint**: SessionStart hooks print to the terminal (user sees it) but do NOT inject into Claude's conversation context. The AI gets context when skills explicitly read the file — the hook provides a quick flash for the human.

### Skill Changes (Phased)

| Phase | Skill | Change |
|-------|-------|--------|
| 2 | `/catch-me-up` | Read working-context.md before external sources; add "Where You Left Off" section |
| 2 | `/pm` | Read working-context.md; factor into "Action Items" prioritization |
| 3 | `/implement` | Write "Active Work" on start; clear/update on completion |
| 3 | `/capture` | Append captured item to "Parked Work" or "Active Work" |

### Shared Reference (New)

`core/skills/_shared/references/working-context.md` — documents file location, format, which sections each skill owns, read/write patterns, and graceful degradation (file missing = proceed normally).

## Implementation Phases

### Phase 1 — Infrastructure (no skill changes)

1. Create `.harness/` directory convention + .gitignore entry
2. Create `hooks/session-stop.sh` — Stop hook that writes git breadcrumbs to working-context.md
3. Create `hooks/session-context.sh` — SessionStart hook that prints brief summary to terminal
4. Update `hooks.json` with both new hooks
5. Create shared reference doc for skills
6. Tests for all new infrastructure

### Phase 2 — Read Integration (2 skill changes)

1. `/catch-me-up` reads working-context.md, adds "Where You Left Off" section before external sources
2. `/pm` reads working-context.md, factors into action item prioritization
3. Tests for both

### Phase 3 — Write Integration (2 skill changes)

1. `/implement` writes active work on start, clears/updates on completion
2. `/capture` appends captured items to working context
3. Tests for both

## Design Decisions & Constraints Discovered

### Always-on, no config flag

Originally proposed a `memory` config section with `working_context`, `auto_capture`, and `session_greeting` flags. Dropped because:

- hooks.json is not rendered through Jinja2 (only .md and .sh files are), so hooks can't be conditionally included per customer
- Every customer benefits from this — making it opt-in adds complexity without value
- Hooks gracefully no-op when the file doesn't exist

### .harness/ directory (gitignored) instead of doc/ or vault/

Putting working-context.md in the repo (`doc/working-context.md`) would make `git status` permanently dirty, breaking /pm's "Current Context" section and polluting the commit workflow. The `.harness/` directory is gitignored, accessible by hooks via `$CLAUDE_PLUGIN_ROOT/.harness/`, and still human-readable/editable.

### Stop hook captures git breadcrumbs only — not conversation context

The Stop hook runs a shell command. It can read git state (branch, commits, modified files) but has zero access to what Claude was "thinking about" or which skills were invoked. For rich context like "was deep in TRA-52, parked email migration research," skills must write to working-context.md during execution (Phase 3). The Stop hook provides the baseline.

### Dropped /triage from skill changes

Originally planned to modify /triage to update working context. Dropped because /triage already creates git branches (`triage/*`) which ARE its breadcrumbs — /pm reads these branches in its "Check for Triage Branches" step. No additional state needed.

### Two files instead of one

session-state.json (structured JSON, merge pattern) for quick programmatic lookups. working-context.md (narrative markdown) for AI comprehension and human readability. Each format does what it's best at.

## Risks

1. **Stop hook may not fire on force-quit** — if the user hits Ctrl+C during a long operation, the hook may not run. Mitigated by Phase 3 skill writes (not relying solely on Stop hook).
2. **Session Log growth** — Stop hook keeps only last 10 entries; older entries trimmed on write.
3. **Multi-project users** — `.harness/` is per-repo, so context is per-repo. No unified cross-project view in v1. Acceptable.

## Payoff

Instead of every session starting cold, the user sees a terminal flash on startup:

```
Last session (2h ago): feature/TRA-52 — 3 commits, 5 files modified
Active: TRA-52 (flash write journal) | Parked: email migration research
```

And when they run `/catch-me-up` or `/pm`, Claude has full narrative context:

> "Yesterday you were deep in TRA-52, parked the email migration research pending API access from Sarah, and decided on append-only logging over circular buffer for flash wear leveling."

That's the difference between a tool and an actual assistant.
