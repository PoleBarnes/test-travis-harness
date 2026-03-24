# Session State Reference

Shared pattern for reading and writing session state across skills. Session state provides cross-skill continuity so that skills can remember context from previous invocations (e.g., last active project, recent work items, last timecard date).

## File Location

```
~/.claude/projects/*/memory/session-state.json
```

Use the auto-memory directory for the current project. The `*` segment corresponds to the project-specific directory that Claude Code creates automatically.

## Read Pattern

Before starting skill work, load session context:

1. Read `~/.claude/projects/*/memory/session-state.json`
2. If the file exists and is valid JSON, extract relevant fields (see Common Fields below)
3. If the file does not exist or is malformed, proceed with no defaults — prompt the user as normal

```
# Pseudocode
session = {}
if file exists and is valid JSON:
    session = parse(file)
    # Use fields as defaults — skip prompting user for values already known
else:
    # Proceed without defaults — ask user for required context
```

Skills should never fail or error due to missing or malformed session state. Treat it as optional context that improves the experience when available.

## Write Pattern

After completing skill work, update session state:

1. Read the existing `session-state.json` (or start with `{}` if missing/malformed)
2. Merge updated fields into the existing object — do NOT overwrite unrelated fields
3. Always set `lastUpdated` to the current ISO 8601 timestamp
4. Always set `version` to `"1.0"`
5. Write the merged object back to `session-state.json`

```
# Pseudocode
session = read existing file or {}
session["fieldA"] = new_value       # merge skill-specific fields
session["lastUpdated"] = now_iso()  # always update timestamp
session["version"] = "1.0"         # always set version
write(session)
```

Key rule: **merge, do not overwrite**. Each skill owns specific fields and must leave other skills' fields untouched.

## Common Fields

| Field | Type | Used By | Description |
|-------|------|---------|-------------|
| `version` | string | all | Schema version, always `"1.0"` |
| `lastUpdated` | string (ISO 8601) | all | Timestamp of last session state write |
| `lastActiveProject` | string | pm, timecard | Project key used in the most recent session (e.g., `"PROJ"`) |
| `recentWorkItemIds` | array of strings | pm | Last 10 work item IDs interacted with (LIFO order) |
| `lastTimecardDate` | string (date) | timecard | Most recent date for which time was logged |

### Orchestrator Fields (owned by `/orchestrate`)

| Field | Type | Description |
|-------|------|-------------|
| `orchestrator.currentWorkItem` | string | ID of item currently being worked |
| `orchestrator.wipLimit` | number | WIP limit, default 1 |
| `orchestrator.itemStates` | object | Map of item ID to state tracking object |
| `orchestrator.lastDependencyCheck` | string (ISO 8601) | Timestamp of last dependency resolution |
| `orchestrator.lastStatusRun` | string (ISO 8601) | Timestamp of last status query |
| `orchestrator.recentTriages` | array | Recent triage entries as {topic, branch, date} objects, last 10 LIFO (written by `/triage`) |

#### Item State Object

```json
{
  "abstractState": "in-progress",
  "trackerState": "In Progress",
  "branch": "feature/PROJ-145-add-auth",
  "prNumber": null,
  "vvStatus": null,
  "lastTransition": "2026-03-20T09:00:00Z",
  "blockedBy": [],
  "proportionalityTier": "standard"
}
```

### Enforcement Fields (owned by `/orchestrate` and gate-checking skills)

| Field | Type | Description |
|-------|------|-------------|
| `orchestrator.itemStates[id].lastGateResult` | object | Full structured rejection object from last gate evaluation (see enforcement.md). Also stored at `orchestrator.lastGateResult` (top-level) for quick access to the most recent gate result across all items. |
| `orchestrator.itemStates[id].humanGates` | object | Map of gate_name → {status, requestedAt, approvedBy, approvedAt} |
| `orchestrator.itemStates[id].lastVerificationVerdict` | object | Tier 2 sub-agent verdict JSON (see verification-subagent.md) |
| `orchestrator.itemStates[id].lastVerifiedCommit` | string | Git SHA of last verified commit (for diff-aware re-verification) |
| `orchestrator.itemStates[id].gatesPassed` | array | List of gate codes that have passed (e.g., ["G1", "G2", "G3"]) |
| `orchestrator.itemStates[id].outputArtifacts` | array | Deliverable file paths produced for this item (written by `/implement`) |

### User Context Fields

| Field | Type | Description |
|-------|------|-------------|
| `orchestrator.currentUserRole` | string | Resolved canonical role (lead, engineer, pm, reviewer, stakeholder) |
| `orchestrator.currentUserUsername` | string | Matched username from git config |

**Merge rule**: `/orchestrate` owns the `orchestrator` namespace. Other skills must not write to it. When reading, treat as optional — if missing, the orchestrator has not been used yet.

### Autopilot Fields (owned by `/autopilot`)

| Field | Type | Description |
|-------|------|-------------|
| `autopilot.active` | boolean | Whether autopilot is currently running |
| `autopilot.sessionId` | string | UUID or timestamp-based session identifier |
| `autopilot.startedAt` | string (ISO 8601) | Session start timestamp |
| `autopilot.lastCycleAt` | string (ISO 8601) | Timestamp of last completed cycle |
| `autopilot.mode` | string | Current mode: `observe`, `triage-only`, `review-only`, `implement`, or `full` |
| `autopilot.budget.timeMinutes` | number | Total time budget in minutes |
| `autopilot.budget.elapsedMinutes` | number | Elapsed time in minutes |
| `autopilot.cycleCount` | number | Number of completed cycles |
| `autopilot.consecutiveFailures` | number | Consecutive failure counter |
| `autopilot.maxRetries` | number | Maximum consecutive failures before pause |
| `autopilot.ticketsCompleted` | array | List of completed work item IDs |
| `autopilot.ticketsInProgress` | array | List of in-progress work item IDs |
| `autopilot.ticketsBlocked` | array | List of blocked work item IDs |
| `autopilot.endedAt` | string (ISO 8601) or null | Session end timestamp (set on graceful stop or pause) |
| `autopilot.pauseReason` | string or null | Reason for pause (null if not paused) |
| `autopilot.runLogPath` | string | Path to the run log file |
| `autopilot.budget.tokens` | number or null | Total token budget (null if unlimited) |
| `autopilot.budget.tokensUsed` | number | Approximate tokens consumed |
| `autopilot.notifyVia` | array of strings | Notification channels ["terminal", "slack", "linear"] |
| `autopilot.previousSessionId` | string or null | Session ID of resumed-from session |
| `autopilot.selfImprovement.level` | string | Active self-improvement level (off/end-of-session/per-cycle/training) |
| `autopilot.selfImprovement.observations` | array of strings | Analysis observations |
| `autopilot.selfImprovement.improvementsApplied` | array of objects | Improvements applied this session |
| `autopilot.selfImprovement.improvementsProposed` | array of objects | Improvements proposed (pending review) |
| `autopilot.experiment` | object or null | Experiment mode state (null if disabled). Contains: `enabled` (boolean), `disabledByBudget` (boolean), `cyclesRun` (number), `selectionsA` (number), `selectionsB` (number), `skipped` (number) |
| `autopilot.scopedProject` | string or null | Single project key from positional arg |
| `autopilot.scopedProjects` | array of strings | Project keys for cross-project mode |
| `autopilot.historyPath` | string | Path to history.json file |

**Merge rule**: `/autopilot` owns the `autopilot` namespace exclusively. Other skills must not write to it. `/autopilot` reads from `orchestrator.itemStates` (read-only) for work item state information.

## Requirement Traceability

This pattern implements **REQ-CTX-004** (Session State Continuity). All skills that read or write session state reference this requirement in their `## Session State` section.

## Example

```json
{
  "version": "1.0",
  "lastUpdated": "2026-03-07T16:30:00Z",
  "lastActiveProject": "PROJ",
  "recentWorkItemIds": ["PROJ-145", "PROJ-132", "PROJ-128"],
  "lastTimecardDate": "2026-03-07"
}
```
