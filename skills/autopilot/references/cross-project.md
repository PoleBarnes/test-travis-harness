# Cross-Project Autopilot

Extends autopilot to operate across multiple project keys in a single session via the `--projects` flag.

---

## Invocation

```
/autopilot --projects PROJ1,PROJ2 --mode implement --budget 4h
/autopilot --projects ALPHA,BETA,GAMMA --mode full
```

Comma-separated list, no spaces. Each value must match `^[A-Z][A-Z0-9]+$`.

## Single-Platform Constraint

All listed projects **must** use the same work tracker platform (e.g., all Azure DevOps, all Jira, all Linear). Validated during session initialization against `devops.platform`. Mismatch fails immediately:

```
ERROR: Cross-project requires a single tracker platform.
  PROJ1 → azure-devops, PROJ2 → linear
Cannot mix platforms in one autopilot session.
```

## Session State

| Field | Type | Description |
|-------|------|-------------|
| `autopilot.scopedProjects` | string[] | Array of project keys (`--projects` flag) |
| `autopilot.scopedProject` | string | Single project key (positional arg, backward compat) |
| `autopilot.lastServedProjectIndex` | number | Round-robin pointer for tiebreaking (resets on start/resume) |

Resolution order: `scopedProjects` > `scopedProject` > `lastActiveProject`. When `--projects` is set, `scopedProject` is left null and vice versa.

## Multi-Project SCAN

Iterates over every project in `scopedProjects`, running the standard five-category scan for each (see `autopilot-loop.md` SCAN Phase). Scan order matches `--projects` order but does not affect priority. Results combine into a single state summary:

```json
{
  "projects": {
    "PROJ1": { "triageBranches": 1, "readyBacklog": 3, "inProgress": 1, "prsAwaitingReview": 0, "blockedItems": 0 },
    "PROJ2": { "triageBranches": 2, "readyBacklog": 4, "inProgress": 0, "prsAwaitingReview": 1, "blockedItems": 1 }
  },
  "totals": { "triageBranches": 3, "readyBacklog": 7, "inProgress": 1, "prsAwaitingReview": 1, "blockedItems": 1 }
}
```

Each project entry also includes `wipDetails` and `readyDetails` arrays (same schema as single-project SCAN output).

## Combined DECIDE with Round-Robin Tiebreak

The priority table from `autopilot-loop.md` applies unchanged across the merged candidate pool. When multiple items from different projects tie at the same priority level, break ties:

1. **Tracker priority**: Critical > High > Medium > Low (same as single-project)
2. **Round-robin by project**: Cycle through `scopedProjects` in order via `lastServedProjectIndex`. Prevents a large backlog in one project from starving others.
3. **Age**: Oldest first within the same project (FIFO)
4. **Unblocking power**: Items unblocking the most downstream work win

## Cycle Logging

Run log entries include a **Project** column in cross-project mode:

```markdown
### Cycle 4 -- 2026-03-23T10:15:00Z
**Project**: PROJ2
**SCAN**: PROJ1: 0 triage, 2 ready, 1 WIP | PROJ2: 1 triage, 3 ready, 0 WIP
**DECIDE**: /plan -- 1 triage branch in PROJ2 (Priority 3)
**EXECUTE**: /plan (3m 22s) -- synthesized 1 triage branch into 1 work item
**EVALUATE**: Success. 1 item added to PROJ2 backlog. Continue to next cycle.
```

The `**Project**` line is omitted in single-project mode.

## Backward Compatibility

| Invocation | State Field | Behavior |
|------------|-------------|----------|
| `/autopilot PROJ` | `scopedProject = "PROJ"` | Single-project. All existing logic unchanged. |
| `/autopilot --projects PROJ` | `scopedProjects = ["PROJ"]` | Array code path, one project. Functionally identical. |
| `/autopilot --projects P1,P2` | `scopedProjects = ["P1","P2"]` | Full cross-project with round-robin tiebreak. |
| `/autopilot` | Both null | Falls back to `lastActiveProject`. Single-project behavior. |
