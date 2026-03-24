# Autopilot Modes Reference

Defines the five autonomy modes that control which skills autopilot may dispatch. Each mode filters the priority table from `autopilot-loop.md` to restrict what actions the loop can take.

---

## Mode Definitions

| Mode | Allowed Skills | Description |
|------|---------------|-------------|
| `observe` | None (scan + report only) | Analyzes project state, recommends actions. Never executes. |
| `triage-only` | `/triage`, `/plan` | Processes incoming work. Creates tickets. Never writes code. |
| `review-only` | `/pr` | Reviews open PRs. Leaves feedback. Never writes code. |
| `implement` | `/triage`, `/plan`, `/orchestrate`, `/implement`, `/pr`, `/vv` | Full pipeline. Creates branches, writes code, creates PRs. Pauses for human review before merge. |
| `full` | All implement skills + auto-assign + auto-state + auto-merge | Everything implement does PLUS auto-assigns items, auto-updates tracker, auto-merges approved PRs. |

---

## Mode Filter for DECIDE Phase

The priority table in `autopilot-loop.md` applies to all modes. Before evaluating conditions, filter by the current mode's allowed actions:

| Priority | Action | observe | triage-only | review-only | implement | full |
|----------|--------|---------|-------------|-------------|-----------|------|
| 1 | Continue WIP | -- | -- | -- | Y | Y |
| 1b | Complete in-review item | -- | -- | -- | Y | Y |
| 2 | Unblock others | -- | -- | -- | Y | Y |
| 3 | Process triage | -- | Y | -- | Y | Y |
| 4 | Implement backlog | -- | -- | -- | Y | Y |
| 5 | Review PR | -- | -- | Y | Y | Y |
| 6 | Pause (no work) | Y | Y | Y | Y | Y |

`--` = skipped in this mode. `Y` = eligible.

In observe mode, every action row is skipped except Pause. The loop runs SCAN + DECIDE to produce recommendations, then stops. In constrained modes (triage-only, review-only), only the matching rows are eligible -- all others are skipped as if their conditions were false.

---

## observe Mode

Default mode. Runs SCAN + DECIDE only. Does not execute any skills.

1. **SCAN**: Analyze project state per `autopilot-loop.md`
2. **DECIDE**: Determine what actions *would* be taken
3. **Report**: Present findings and recommended actions
4. Set `autopilot.active = false` and finalize session state

All priority rows are skipped. The DECIDE phase produces recommendations without dispatching.

---

## triage-only Mode

Dispatches ONLY `/triage` and `/plan`. The loop:

1. **SCAN**: Check for triage branches and unplanned items
2. **DECIDE**: If triage branches exist, select `/plan`. If an enforcement rejection requires `/triage` (e.g., `G2_NO_TRIAGE_DOC`), dispatch `/triage` for that topic. Otherwise PAUSE with "No triage work remaining."
3. **EXECUTE**: Run `/plan` (or `/triage` if needed)
4. **EVALUATE**: Check results per standard evaluation. Loop or pause.

### Does NOT

- Create feature branches
- Write code or tests
- Create or review PRs
- Modify work item states (beyond what `/plan` does internally)
- Start or complete items via `/orchestrate`

---

## review-only Mode

Dispatches ONLY `/pr` for reviews. The loop:

1. **SCAN**: Check for PRs awaiting review (Priority 5 row from the priority table)
2. **DECIDE**: If PRs exist, select `/pr <oldest>` (oldest first per tiebreaking rules). Otherwise PAUSE with "No PRs to review."
3. **EXECUTE**: Run `/pr <number>`
4. **EVALUATE**: Check review results per standard evaluation. Loop or pause.

### Does NOT

- Create feature branches
- Write code or tests
- Create new PRs
- Modify work item states
- Start or complete items via `/orchestrate`

---

## implement Mode

Full pipeline mode. Dispatches `/triage`, `/plan`, `/orchestrate`, `/implement`, `/pr`, and `/vv`. All six priority rows (1 through 5) plus Pause (6) are eligible.

This is the mode described in detail in `SKILL.md` under "Mode: Implement" and in `autopilot-loop.md`. The loop runs SCAN-DECIDE-EXECUTE-EVALUATE with all actions available.

### Key constraint

Implement mode pauses for human review before merge. When an item reaches `in-review` state, autopilot waits for human PR approval. It does NOT auto-merge and does NOT auto-assign unassigned items.

All tracker state transitions go through pipeline skills (`/orchestrate`, `/implement`, `/pr`, `/vv`), never directly via MCP tools.

---

## full Mode

Everything implement does PLUS three auto-actions that reduce human friction for trusted, fully-supervised environments.

### Auto-assign

Before `/orchestrate start <ID>`, if the item has no assignee, assign it to the current user via the tracker's `update_item` operation:

1. Query item details via tracker MCP
2. If `assignee` is null or empty, set assignee to the current user
3. Log: `AUTO-ASSIGN: <ID> assigned to <user>`
4. Proceed with `/orchestrate start <ID>`

### Auto-state

After each successful EVALUATE, directly update tracker state via the tracker's `update_status` operation to ensure the tracker reflects reality:

1. After `/orchestrate start <ID>` succeeds: confirm item is `in-progress` in tracker
2. After `/pr` creates a PR: confirm item is `in-review` in tracker
3. After `/orchestrate complete <ID>` succeeds: confirm item is `done` in tracker
4. Log each update: `AUTO-STATE: <ID> -> <new-state>`

This supplements (does not replace) the state transitions that pipeline skills perform internally. It catches cases where a skill succeeds but the tracker update fails.

### Auto-merge

When an item reaches `in-review` state and the PR meets all merge criteria, auto-merge the PR:

1. PR has at least one approval
2. All CI/CD checks are passing (green)
3. No unresolved review comments
4. No merge conflicts
5. All enforcement gates pass (G4 gate check via `/orchestrate complete <ID>`)

If all criteria are met:
1. Run `/orchestrate complete <ID>` (which checks G4 gates). In `full` mode, autopilot passes `--auto-confirm` context to `/orchestrate complete` to skip the interactive confirmation prompt. This is safe because all enforcement gates (G4) are still evaluated — the confirmation is bypassed, not the gate checks.
2. If G4 passes, merge the PR via git platform MCP merge operation
3. Log: `AUTO-MERGE: PR #<number> merged for <ID>`

If any criterion is NOT met, behave like implement mode -- pause and wait for human action.

### Enforcement gates still apply

Full mode does NOT bypass any enforcement gate. All G1-G4 gates are checked normally. The auto-actions only reduce manual steps for operations that don't require human judgment:
- Assigning items to yourself
- Confirming tracker state matches reality
- Merging PRs that humans have already approved

---

## Mode Validation

If an unrecognized mode is passed:

1. Warn: `"Unknown mode '{mode}'. Valid: observe, triage-only, review-only, implement, full. Defaulting to observe."`
2. Set mode to `observe`
3. Log the warning in the session run log

Valid mode values are case-insensitive. Normalize to lowercase before comparison.

---

## Mode Selection Guidelines

| Scenario | Recommended Mode |
|----------|-----------------|
| First time running autopilot | `observe` |
| Morning triage processing | `triage-only` |
| Clearing PR review backlog | `review-only` |
| Active sprint work with oversight | `implement` |
| Trusted overnight batch processing | `full` |
| Debugging autopilot behavior | `observe` with `--dry-run` |

---

## Session State

The current mode is stored in `autopilot.mode` in session-state.json. Valid values: `"observe"`, `"triage-only"`, `"review-only"`, `"implement"`, `"full"`.

The mode cannot be changed mid-session. To switch modes, end the current session and start a new one.
