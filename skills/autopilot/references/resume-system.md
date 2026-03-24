# Resume System Reference

## Command

`/autopilot --resume`

## Procedure

### 1. Load Previous Session

Read `session-state.json`, locate the `autopilot` namespace.

**Validation checks** (in order):

1. If `autopilot.active == true`: warn "A session appears to be actively running. Start a new session instead."
2. If `autopilot.pauseReason` is null: warn "No paused session found. Start a new session."
3. If `autopilot.pauseReason` is `"Budget exhausted"` or `"No actionable work remaining"`: report "Previous session ended normally and cannot be resumed. Start a new session."

If any check fails, stop and do not proceed with resume.

### 2. Assess Current State

Gather context before presenting the resume summary:

- **Uncommitted changes**: `git status --porcelain` — count modified/added/deleted files
- **In-progress items**: read `autopilot.ticketsInProgress`
- **Blocked items**: read `autopilot.ticketsBlocked`
- **Incomplete PRs**: check `orchestrator.itemStates` for items in `in-review` state
- **Elapsed budget**: read `autopilot.budget.elapsedMinutes` and `autopilot.budget.timeMinutes`
- **Cycle count**: read `autopilot.cycleCount`
- **Consecutive failures**: read `autopilot.consecutiveFailures`

### 3. Present Resume Summary

Display the following to the user and wait for confirmation:

```
## Resume Summary

| Field | Value |
|-------|-------|
| Previous session | [sessionId] ([date from startedAt]) |
| Pause reason | [pauseReason] |
| Cycles completed | [cycleCount] |
| Uncommitted changes | [yes/no — file count if yes] |
| In-progress items | [list or "none"] |
| Blocked items | [list or "none"] |
| Budget consumed | [elapsedMinutes] / [timeMinutes] minutes |

Resume this session? [Enter/n]
```

If the user declines, report "Resume cancelled." and stop.

### 4. Resume

If user confirms:

1. **Generate a new sessionId**: `autopilot-<YYYYMMDD>-<HHMMSS>` (new session boundary)
2. **Restore from previous session**: `ticketsCompleted`, `ticketsInProgress`, `ticketsBlocked`, `cycleCount`
3. **Set `autopilot.previousSessionId`** to the old sessionId
4. **Set `autopilot.startedAt`** to the current UTC time
5. Apply CLI overrides if provided. Otherwise restore from previous session:
   - `--mode` -> previous `autopilot.mode`
   - `--budget` -> remaining budget from previous session
   - `--token-budget` -> remaining token budget
   - `--experiment` -> previous `autopilot.experiment.enabled`
   - `--projects` -> previous `autopilot.scopedProjects`
   - `--self-improve` -> previous `autopilot.selfImprovement.level`
6. **Reset counters**: `consecutiveFailures = 0`, `budget.elapsedMinutes = 0`
7. **Create new run log** at `doc/autopilot/<new-date>-session.md` with "Resumed from [previousSessionId]" header
8. **Set `autopilot.active = true`** and `autopilot.pauseReason = null`
9. **Enter the normal SCAN -> DECIDE -> EXECUTE -> EVALUATE loop**

### 5. Run Log Continuity

The resumed session gets its own run log at `doc/autopilot/<new-date>-session.md`.

First line: `Resumed from session [previousSessionId] — [original pause reason]`

Cycle numbering continues from previous `cycleCount`. If the previous session completed 5 cycles, the first cycle in the resumed session is cycle 6.

### 6. Budget Handling on Resume

| Scenario | Behavior |
|----------|----------|
| `--budget` flag provided | Use the new budget value as `timeMinutes`; reset `elapsedMinutes` to 0 |
| No `--budget` flag | Carry forward remaining budget: `timeMinutes = previous timeMinutes - previous elapsedMinutes` |
| Remaining budget < 10 minutes | Warn "Only [N] minutes remaining from previous budget. Consider using --budget to extend." |

### 7. Blocked Item Handling

On resume, re-evaluate blocked items before entering the loop:

1. For each item in `ticketsBlocked`, check if the blocking condition has been resolved:
   - Human gate pending: check if the gate has been approved (via tracker state)
   - Dependency unresolved: re-run dependency check
   - Tracker unavailable: verify MCP connectivity
2. If a blocked item is now unblocked, move it from `ticketsBlocked` to `ticketsInProgress`
3. Log any state changes to the run log

### 8. Error Handling

| Error | Response |
|-------|----------|
| `session-state.json` missing | "No session state found. Start a new session with /autopilot." |
| `autopilot` namespace missing | "No autopilot session data found. Start a new session." |
| Previous run log missing | Warn "Previous run log not found — starting fresh log." Proceed normally. |
| Uncommitted changes from previous session | Warn "Uncommitted changes detected from previous session. Review before continuing." Include file list in the resume summary. |
