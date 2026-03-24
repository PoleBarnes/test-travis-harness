# Autopilot Loop Algorithm

Defines the four-phase loop that drives autonomous work selection and execution. Each cycle runs SCAN-DECIDE-EXECUTE-EVALUATE, then loops until budget expires, a pause condition is hit, or no actionable work remains.

---

## SCAN Phase

Analyze current project state by performing an internal `/pm`-style analysis. Gather five categories of information.

### 1. Triage Branches

Count branches matching `triage/*` pattern:

```
git branch --list 'triage/*'
```

Each branch represents unprocessed incoming work that needs `/plan` before it becomes actionable backlog.

### 2. Backlog Items (Ready)

Query the tracker for items in "To Do" / "Planned" state:

- Use `search_items` operation (see `_shared/references/tracker-operations.md`)
- Filter by project key: use `autopilot.scopedProject` if set (from CLI arg), otherwise fall back to `lastActiveProject` from session state
- Cross-reference with `orchestrator.itemStates` to identify items where all dependencies are resolved
- These are "ready" items -- they can be started immediately

### 3. In-Progress Items (WIP)

Query the tracker for items in "In Progress" state:

- Cross-reference with `orchestrator.itemStates` for branch and PR info
- Categorize each:
  - **Needs continued work**: branch exists, no PR yet, implementation incomplete
  - **Waiting for review**: PR exists but not yet approved
  - **Stale**: no commits in >5 days on the item's branch

### 4. PRs Awaiting Review

Check for open PRs assigned to the user or team:

- Use the git platform MCP to query open PRs
- Identify PRs with no review activity (no approvals, no comments)
- Note PRs with requested changes that need attention

### 5. Blocked Items

Check `orchestrator.itemStates` for items with unresolved dependencies:

- Items where `blockedBy` array is non-empty and those blockers are not in `done` state
- Items where `humanGates` have `status: "pending"` or `status: "escalated"`

#### Cross-Project Scanning

When `autopilot.scopedProjects` contains multiple keys, run scans 1-5 for each project and combine results into a merged state summary. See `references/cross-project.md` for the combined scan protocol.

### SCAN Output

Produce a state summary object for use by the DECIDE phase:

```json
{
  "triageBranches": 3,
  "readyBacklog": 5,
  "inProgress": 1,
  "prsAwaitingReview": 2,
  "blockedItems": 1,
  "wipDetails": [
    {
      "id": "PROJ-42",
      "state": "in-progress",
      "branch": "feature/PROJ-42-auth-module",
      "hasPR": false,
      "lastCommitAge": "2h"
    }
  ],
  "readyDetails": [
    {
      "id": "PROJ-55",
      "priority": "High",
      "unblockingPower": 2,
      "age": "3d"
    }
  ]
}
```

---

## DECIDE Phase

Select the next action using strict priority order. Evaluate conditions top to bottom and take the FIRST applicable action.

### Mode Filter

Before evaluating the priority table, filter by the current mode's allowed actions (see `references/modes.md`):

| Priority | Action | triage-only | review-only | implement | full |
|----------|--------|-------------|-------------|-----------|------|
| 1 | Continue WIP | — | — | ✓ | ✓ |
| 1b | Complete in-review | — | — | ✓ | ✓ |
| 2 | Unblock others | — | — | ✓ | ✓ |
| 3 | Process triage | ✓ | — | ✓ | ✓ |
| 4 | Implement backlog | — | — | ✓ | ✓ |
| 5 | Review PR | — | ✓ | ✓ | ✓ |
| 6 | Pause | ✓ | ✓ | ✓ | ✓ |

`observe` mode skips DECIDE entirely (handled in SKILL.md).
Rows marked `—` are skipped for that mode.

### Priority Table

| Priority | Condition | Action | Reasoning |
|----------|-----------|--------|-----------|
| 1 | WIP item exists with remaining work (no PR yet) | Continue `/implement <ID>` | Finish what you started; context switching is expensive |
| 1b | Item in `in-review` with approved PR and V&V passed | `/orchestrate complete <ID>` | Close completed work; free up WIP slot |
| 2 | Item exists that blocks >=2 downstream items | `/orchestrate start <ID>` + `/implement <ID>` | Unblocking others has multiplicative impact |
| 3 | Triage branches exist | `/plan` | Process incoming work before starting new implementation |
| 4 | Ready backlog items exist | `/orchestrate start <ID>` (highest priority) + `/implement <ID>` | Highest-priority unblocked item |
| 5 | PRs awaiting review | `/pr <number>` (oldest first) | Review is faster than implementation; unblocks others |
| 6 | None of the above | PAUSE -- "No actionable work remaining" | Nothing to do |

### Tiebreaking Rules

When multiple items qualify within the same priority level, break ties in this order:

1. **Tracker priority**: Critical > High > Medium > Low
2. **Age**: Oldest first (FIFO) -- prevents starvation
3. **Unblocking power**: Items that unblock the most downstream work win

### Skip List

Maintain a per-session skip list of item IDs that have been skipped due to enforcement rejections. Do not re-select a skipped item in the same session unless the blocking condition changes (e.g., a dependency completes).

### Decision Output

Log the decision in a structured format:

```
DECIDE: [action] -- [item ID] -- [reasoning]
```

Examples:
- `DECIDE: /implement PROJ-42 -- WIP item with remaining work (in-progress, no PR)`
- `DECIDE: /orchestrate start PROJ-55 + /implement PROJ-55 -- highest-priority ready backlog item (High priority, unblocks 2 items)`
- `DECIDE: /plan -- 3 triage branches pending`
- `DECIDE: /pr #87 -- oldest PR awaiting review (3 days, no activity)`
- `DECIDE: PAUSE -- no actionable work remaining`

---

## EXECUTE Phase

Dispatch the chosen skill. The mapping from decision to skill invocation:

| Decision | Skill Invocation | Notes |
|----------|-----------------|-------|
| Process triage | `/plan` | Synthesizes all triage branches at once |
| Start new item | `/orchestrate start <ID>` then `/implement <ID>` | Orchestrate handles gate checks and state transition |
| Continue WIP | `/implement <ID>` | Resumes implementation on existing branch |
| Review PR | `/pr <number>` | Runs review workflow |
| Complete item | `/orchestrate complete <ID>` | After `/implement` + `/pr` succeed |

#### Experiment Mode

When `autopilot.experiment == true` and the current mode is `implement` or `full`, use the dual-implementation protocol for `/implement` dispatches. See `references/experiment-mode.md`.

### Full Mode Auto-Actions

In `full` mode, three additional actions occur (see `references/modes.md` for details):
1. **Auto-assign**: Before `/orchestrate start`, assign unassigned items to current user
2. **Auto-state**: After EVALUATE success, update tracker state directly
3. **Auto-merge**: When item has approved PR + passed V&V, merge PR via git platform MCP

### Execution Boundaries

- Each skill invocation is fully visible to the user -- autopilot does not suppress output
- Autopilot does not pass `--force` or override flags to any skill
- If a skill prompts for user confirmation (e.g., "Update to In Progress? [y/n]"), the user responds directly
- Autopilot waits for the skill to complete before proceeding to EVALUATE

### Enforcement Gate Handling

When `/orchestrate start <ID>` returns a structured rejection (see `_shared/references/enforcement.md`), autopilot must handle it based on the rejection code and retry policy.

#### G1 -- Plan Gate Rejections

| Code | retry_policy | Autopilot Action |
|------|--------------|-----------------|
| `G1_NO_TRIAGE_DOC` | `after-fix` | Run `/triage` for this topic first, then retry `/orchestrate start`. If triage also fails, skip item and pick next. |
| `G1_ROLE_FORBIDDEN` | `after-fix` | PAUSE -- autopilot cannot change its role. Report to user: "Role {current_role} cannot plan items. Required: {required_roles}." |

#### G2 -- Implement Gate Rejections

| Code | retry_policy | Autopilot Action |
|------|--------------|-----------------|
| `G2_DEPS_UNRESOLVED` | `after-fix` | Skip this item. Dependencies are someone else's work or need to be completed first. Add to skip list and pick next item from the priority table. |
| `G2_ITEM_STATE_INVALID` | `after-fix` | Item may already be started or in wrong state. Check `orchestrator.itemStates` for actual state and adjust. If truly invalid, skip item. |
| `G2_NO_REQ_LINK` | `after-fix` | Attempt to add requirement reference (REQ-*) to the work item description via tracker MCP, then retry once. If still failing, skip item. |
| `G2_NO_TRIAGE_DOC` | `after-fix` | Run `/triage` for this topic first, then retry `/orchestrate start`. If triage also fails, skip item. |
| `G2_ROLE_FORBIDDEN` | `after-fix` | PAUSE -- autopilot cannot change its role. Report to user: "Role {current_role} cannot start implementation. Required: {required_roles}." |

#### G3 -- Review Gate Rejections

| Code | retry_policy | Autopilot Action |
|------|--------------|-----------------|
| `G3_UNCOMMITTED_CHANGES` | `after-fix` | Commit and push all changes, then retry. |
| `G3_MISSING_DELIVERABLES` | `after-fix` | Attempt to produce missing deliverables during `/implement`, then retry. |
| `G3_VV_NOT_RUN` | `after-fix` | Run `/vv <ID>` before creating PR, then retry. |
| `G3_ROLE_FORBIDDEN` | `after-fix` | PAUSE -- report to user. |

#### G4 -- Merge Gate Rejections

| Code | retry_policy | Autopilot Action |
|------|--------------|-----------------|
| `G4_PR_NOT_APPROVED` | `after-fix`* | PAUSE -- autopilot cannot self-approve PRs. Although enforcement lists this as `after-fix`, autopilot treats it as a pause trigger because addressing review feedback requires human judgment. |
| `G4_VV_NOT_ATTACHED` | `after-fix` | Run `/vv <ID>` and attach report, then retry once. |
| `G4_ARTIFACTS_NOT_LINKED` | `after-fix` | Attempt to link artifacts via tracker MCP, then retry once. |
| `G4_AC_TESTS_FAILING` | `after-fix` | Log the failure. This should have been caught during `/implement`. Skip completion, mark for next cycle. |
| `G4_HUMAN_GATE_PENDING` | `after-approval` | PAUSE -- human approval required. Report: "Awaiting {gate_name} approval from {required_role}." |
| `G4_ROLE_FORBIDDEN` | `after-fix` | PAUSE -- report to user. |

#### Cross-Gate Rejections

| Code | retry_policy | Autopilot Action |
|------|--------------|-----------------|
| `TIER2_VERIFICATION_FAILED` | `after-fix` | Log the gap count. Attempt remediation during next `/implement` cycle. If gaps persist after one retry, PAUSE. |

#### General Retry Policy Rules

| retry_policy | Autopilot Behavior |
|--------------|-------------------|
| `immediate` | Re-evaluate the gate immediately (stale cache, MCP timeout). Max 1 immediate retry per gate per cycle. |
| `after-fix` | Attempt the remediation described in the `remediation` field once. If still failing after one fix attempt, skip the item and pick the next one from the priority table. |
| `after-approval` | PAUSE -- human action required. Do not retry automatically. Report the pending approval to the user. |

---

## EVALUATE Phase

After execution completes, assess the result and determine the next action.

### 1. Success

The dispatched skill completed without errors.

- Reset `consecutiveFailures` to 0
- Increment `cycleCount`
- Update counters:
  - If an item moved to `done`: increment `ticketsCompleted`
  - If an item moved to `in-progress`: update `ticketsInProgress`
  - If an item is blocked: update `ticketsBlocked`
- Append cycle summary to the run log
- Continue to next SCAN

### 2. Failure

The dispatched skill failed or produced errors.

- Increment `consecutiveFailures`
- If `consecutiveFailures >= maxRetries`: PAUSE with reason "Max retries exceeded: [last error]"
- Otherwise: log the failure with error details, continue to next SCAN (the next DECIDE may pick a different item or retry)

### 3. Enforcement Rejection

A gate returned a structured rejection. See the Enforcement Gate Handling table above for per-code behavior. Summary:

- `after-fix` rejections: attempt remediation once, then skip if still failing
- `after-approval` rejections: PAUSE immediately
- `immediate` rejections: retry the gate once without user action

### 4. Human Decision Needed

The skill encountered ambiguous requirements, architectural choices, or situations requiring human judgment.

- PAUSE with reason: "Human decision required: [description]"
- Do not attempt to resolve ambiguity autonomously

### 5. Budget Check

After each cycle, check the time budget (see `budget-system.md`):

- Calculate: `elapsed = now - startedAt`
- If `elapsed >= budget`: graceful STOP -- do not start a new cycle
- If `elapsed >= 80% of budget`: emit warning, continue current cycle
- If `elapsed < 80%`: normal operation

### 6. Self-Improvement Analysis

If self-improvement is enabled (`autopilot.selfImprovement.level != 'off'`):

- **`training` level**: Run analysis engine after every skill return in EXECUTE phase (before reaching EVALUATE). This provides maximum insight but adds overhead.
- **`per-cycle` level**: Run analysis engine here in EVALUATE after budget check. Quick pattern analysis of the just-completed cycle.
- **`end-of-session` level**: Skip analysis here. Runs only once on session stop/pause.
- **`off` level**: Skip entirely.

See `references/self-improvement.md` for the analysis engine algorithm, timing constraints, and safety rules.

---

## Cycle Logging

After each EVALUATE, append a cycle entry to the session run log. This log is written into the session document (see `autopilot-session-template.md` in `core/doc/`).

### Format

```markdown
### Cycle [N] -- [timestamp]
**SCAN**: [summary]
**DECIDE**: [action and reasoning]
**EXECUTE**: [skill invoked, duration, outcome]
**EVALUATE**: [result, next step]
```

### Examples

```markdown
### Cycle 1 -- 2026-03-22T09:00:00Z
**SCAN**: 3 triage branches, 5 ready items, 0 WIP, 2 PRs awaiting review
**DECIDE**: /plan -- 3 triage branches pending (Priority 3)
**EXECUTE**: /plan (4m 12s) -- synthesized 3 triage branches into 3 work items
**EVALUATE**: Success. 3 items added to backlog. Continue to next cycle.

### Cycle 2 -- 2026-03-22T09:05:00Z
**SCAN**: 0 triage branches, 8 ready items, 0 WIP, 2 PRs awaiting review
**DECIDE**: /orchestrate start PROJ-55 + /implement PROJ-55 -- highest-priority ready item (High, unblocks 2)
**EXECUTE**: /orchestrate start PROJ-55 (0m 8s) -- gate passed. /implement PROJ-55 (22m 45s) -- implementation complete, tests passing
**EVALUATE**: Success. PROJ-55 in-progress. Continue to next cycle.

### Cycle 3 -- 2026-03-22T09:28:00Z
**SCAN**: 0 triage branches, 7 ready items, 1 WIP (PROJ-55), 2 PRs awaiting review
**DECIDE**: /implement PROJ-55 -- WIP item with remaining work (Priority 1)
**EXECUTE**: /implement PROJ-55 (15m 30s) -- PR created, pushed
**EVALUATE**: Success. PROJ-55 moved to in-review. Continue to next cycle.
```

---

## Pause and Stop Conditions

The loop terminates (PAUSE or STOP) under these conditions:

| Condition | Type | Message Template |
|-----------|------|-----------------|
| Budget expired | STOP | "Budget exhausted ({elapsed}m / {budget}m). {cycles} cycles completed." |
| No actionable work | PAUSE | "No actionable work remaining. {summary of current state}." |
| Max retries exceeded | PAUSE | "Max retries exceeded ({consecutiveFailures}/{maxRetries}). Last error: {error}." |
| Human approval needed | PAUSE | "Awaiting human approval: {gate_name} for {item_id}." |
| Human decision needed | PAUSE | "Human decision required: {description}." |
| Role forbidden | PAUSE | "Role {role} cannot perform required action. {detail}." |

On PAUSE or STOP:
1. Write the session summary to the session document
2. Update session state with final counters
3. Present the summary to the user with the pause/stop reason

---

## State Transitions During Autopilot

The autopilot loop drives items through the state machine (see `orchestrate/references/state-machine.md`). The typical flow for one item across multiple cycles:

```
Cycle N:   /orchestrate start <ID>     -- planned -> in_progress (G2)
Cycle N:   /implement <ID>             -- write code, tests, docs
Cycle N+1: /implement <ID> (continue)  -- finish implementation
Cycle N+1: /pr <ID>                    -- in_progress -> in_review (G3)
Cycle N+2: /orchestrate complete <ID>  -- in_review -> done (G4)
```

Each state transition is guarded by the enforcement engine. Autopilot respects all gates and never bypasses them.
