---
name: implement
description: Implement a coding task end-to-end — decompose, delegate to subagents, produce documentation deliverables scaled by proportionality tier, and create a PR. Use when the user says "build this feature", "code this task", "work on PROJ-123", "implement this", or needs to go from a work item to a shipped PR with full documentation.
argument-hint: [PROJ-123 or task description]
---

# travis Harness — Implementation Workflow

You are the orchestrator. Follow this workflow to implement a coding task end-to-end by delegating to subagents.

## Task Input

**$ARGUMENTS**

## Current Context

- Branch: !`git branch --show-current`
- Status: !`git status --short`
- Recent commits: !`git log --oneline -5`

## Working Context

Update `.harness/working-context.md` during implementation to maintain cross-session continuity.

For full format details, see `references/working-context.md` in the `_shared` skill directory.

### On Start (after Step 1)

If `.harness/working-context.md` exists, add the current task to the "## Active Work" section:
```
- [WORK-ITEM-ID]: [title] — branch: [branch-name]
```

If the file does not exist, create it with the standard template (see shared reference) and add the active work entry.

### On Completion (after Step 6)

Update `.harness/working-context.md`:
1. Remove the completed item from "## Active Work"
2. Add key design decisions to "## Recent Decisions" (keep last 5 entries)

This skill writes: Active Work, Recent Decisions

## Instructions

### Step 0: Process Gate Check

Before proceeding, verify this task is ready for implementation.

1. **Read enforcement config**: Check if process enforcement is configured.
   - If process enforcement is not enabled or mode is "off", skip this step entirely and proceed to Step 1.

2. **Role check**: If `process_enforcement.roles` is configured, resolve the current user's role per `enforcement.md` (RBAC → Role Resolution). Check the permission matrix for the `planned → in-progress` transition. If the role is not permitted, include `G2_ROLE_FORBIDDEN` in the rejection. If `process_enforcement.roles` is absent, skip this check (all roles permitted).

3. **Validate work item state**: If $ARGUMENTS contains a work item ID (matches pattern `^[A-Z][A-Z0-9]+-\d+$`):
   a. Fetch the work item using the **fetch_item** operation (see `_shared/references/tracker-operations.md`)
   b. Verify the work item state is the "To Do" equivalent (per `status_map.todo` in config)
   c. If the item is already "In Progress" or beyond, note this and proceed (may be resuming work)
   d. If the item is "Done", warn: "This item is already completed."

4. **Check dependencies**: Use the **check_dependencies** operation to query blocking items.
   - For each blocker not in "Done" state: record as unresolved
   - If ANY unresolved blockers exist:
     - **mode: block**: "BLOCKED: Cannot implement [ID]. Blocked by: [BLOCKER-ID] ([title]) — state: [state]. Resolve blockers first."
     - **mode: warn**: "WARNING: [ID] has unresolved blockers: [BLOCKER-ID] ([title]). Proceeding may cause dependency issues. Continue? [Enter/n]"

5. **Verify input traceability**: Search the work item description for requirement references (pattern: `REQ-` followed by identifier).
   - If no requirement reference found:
     - **mode: block** (standard/comprehensive tier): "BLOCKED: No requirement reference (REQ-*) found in work item description. Link a requirement before implementing."
     - **mode: warn**: "WARNING: No requirement traceability. Consider linking a REQ-* reference."

6. **Structured rejection**: When any condition in steps 2–5 fails, produce a rejection object per `enforcement.md` (Structured Rejection Schema). Each failed condition includes a rejection code (e.g., `G2_ROLE_FORBIDDEN`, `G2_DEPS_UNRESOLVED`, `G2_NO_REQ_LINK`), a remediation instruction, and a retry policy. Store the complete rejection object in `session-state.json` at `orchestrator.itemStates[id].lastGateResult`. Act on the result per `enforcement.md` (Enforcement Evaluation Algorithm, Step 10): in `block` mode halt the workflow; in `warn` mode prompt the user to continue or abort.

7. If all checks pass (or the user confirms past warnings), proceed to Step 1.

### Step 1: Parse and Validate Task Input

Examine `$ARGUMENTS` to determine the task source:

**If no arguments provided** (empty `$ARGUMENTS`):
1. Display: "Error: /implement requires a work item ID (e.g., TH-123) or task description."
2. Show usage examples: `/implement TH-123` or `/implement add input validation to the login form`
3. **Stop here**

**If it looks like a work item ID** (matches pattern `[A-Z]+-\d+`, e.g., `TH-123`):
1. Validate format: `^[A-Z][A-Z0-9]+-\d+$`
2. If invalid, display: "Error: Invalid work item ID format. Expected format: TH-123"
3. If valid:
   Fetch the full work item using the **fetch_item** operation (see `_shared/references/tracker-operations.md`)
4. Extract: title, description, acceptance criteria, priority, linked work items
5. If not found, report and suggest checking the ID
6. Update `.harness/working-context.md` — add this task to "Active Work" (see Working Context section above)

**If natural language** (e.g., "add input validation to the login form"):
1. Use the text directly as the task description

**State transition**: If process enforcement is enabled with auto_state_transitions:
- Update the work item to "In Progress" state using the **update_status** operation (see `_shared/references/tracker-operations.md`)
- Confirm with user: "Moving [ID] to In Progress. [Enter to confirm / n to skip]"
- Update session-state.json: set `orchestrator.itemStates.[ID].abstractState` to "in-progress", `trackerState` to the platform's in-progress state, `branch` to current branch, `lastTransition` to now

### Step 2: Decompose and Plan

Before delegating any work:

1. Use **TodoWrite** to create the task breakdown
2. If the task scope is unclear, delegate an **Explore subagent** to research:
   - Which files are involved
   - What patterns exist in the codebase
   - What test framework is used
3. Read the Explore subagent's summary and refine your plan

### Step 3: Delegate Implementation

Based on the task complexity (see Effort Scaling in CLAUDE.md), spawn subagents:

**For each implementation subagent, include in the Task Brief:**
- The specific files to modify and what changes to make
- Existing patterns to follow (from research step)
- Git conventions: branch from `main`, commit format `TH-NNN: <type>: description`
- Do NOT create a PR — just implement and commit

**For each test subagent, include in the Task Brief:**
- Which files were changed (from implementer results)
- Acceptance criteria from the work item
- Requirement: 100% test coverage of new/changed code
- Run the full test suite and report results

### Step 4: Verify

After all subagents complete:
1. Update **TodoWrite** with results
2. Confirm all acceptance criteria are met
3. Confirm all tests pass
4. If issues found, spawn a fix subagent with specific instructions

### Step 5: Produce Documentation Deliverables

Before review, generate all required documentation artifacts based on the proportionality tier (see below):

1. **Software Design Document** — Create or update the SDD describing design decisions, component interactions, and architecture changes. Place in `doc/design/` or update the existing SDD. Use the template in `doc/templates/sdd-template.md`.
2. **Linter Report** — Run the project linter and capture the report. Must show zero violations or document each exception with rationale.
3. **Code Coverage Analysis** — Run the test suite with coverage enabled. Report the coverage percentage for new/modified code. Must meet or exceed the project threshold (default: 80%).
4. **Unit Test Results** — Capture and attach the unit test results for all new/modified code.
5. **Regression Test Results** — Run the full test suite and capture results. Confirm zero regressions introduced by this change.
6. **V&V Audit Report** — Run `/vv` after implementation to produce this. Ensure it is attached before marking Done.
7. **Diagrams** — Create or update visual diagrams that reduce cognitive load: state machine diagrams, sequence charts, system/component diagrams, data flow diagrams. Place in `doc/diagrams/` using Mermaid (preferred), PlantUML, or ASCII art.
8. **Engineering Journal** — Maintain a running engineering journal throughout the task in `doc/journal/`. Use the template in `doc/templates/engineering-journal-template.md`. Record:
   - **Work performed** — what was done at each step and why
   - **Decisions made** — each design or implementation decision with reasoning and alternatives considered
   - **Surprises and unexpected findings** — anything that deviated from expectations
   - **Open questions** — unresolved items that may need future attention
   - Format: `YYYY-MM-DD-<work-item-id>.md`

The work item is not Done until every required deliverable for the determined tier is produced and attached. This gate exists because documentation debt compounds — missing an SDD now means the next engineer has no design context, and missing test results means nobody can verify quality after the fact.

### Proportionality Rules

Not all work items require all 8 artifacts. Scale requirements to scope:

| Tier | Required Artifacts | When |
|------|-------------------|------|
| **Minimal** | Linter report, unit test results, regression test results | Bug fixes, small refactors, config changes (<50 lines changed) |
| **Standard** | Minimal + SDD + code coverage + V&V audit | Features, medium tasks, integrations (50-300 lines changed) |
| **Comprehensive** | All 8 artifacts | Architecture changes, security-sensitive work, new skills (>300 lines changed) |

**Scope determination:**
- Work item type: bug → minimal, feature → standard, architecture → comprehensive
- Lines changed: <50 = minimal, 50-300 = standard, >300 = comprehensive
- Component sensitivity: security, auth, data handling → always comprehensive
- Use the **highest** applicable tier when multiple criteria apply

The reason for tiered requirements: a one-line config fix doesn't need an SDD and architecture diagrams, but a new authentication flow absolutely does. Proportionality keeps the documentation gate from becoming a tax on small changes while ensuring critical work gets thorough documentation.

**Output tracking**: Update session-state.json `orchestrator.itemStates.[ID].outputArtifacts` with the list of produced deliverable file paths. This enables the /orchestrate complete gate to verify completeness.

### Step 6: Review and PR

Invoke `/pr` to handle the review and PR creation:

1. Ensure all changes are committed
2. Run `/pr` which will:
   - Execute the full review (security, tests, V&V)
   - Fix blocking issues with user approval
   - Create the PR with generated description
3. The `/pr` skill handles all review logic — do not duplicate it here

**State transition**: If process enforcement is enabled with auto_state_transitions:
- The /pr skill will handle the transition to "In Review" (see /pr modifications)
- Update session-state.json: set `orchestrator.itemStates.[ID].abstractState` to "in-review", `prNumber` to the PR number

### Step 7: Report

```
## Task Complete

- **Branch**: [feature-branch-name]
- **PR**: [PR link or number from /pr output]
- **Tests**: [pass/fail count]
- **Work Item**: [work item ID] updated with implementation notes

### Changes Made
- [file1]: [what changed]
- [file2]: [what changed]

### Review & PR
- See `/pr` output above for full review summary and PR link

### Documentation Deliverables
| Deliverable | Status | Notes |
|-------------|--------|-------|
| Software Design Document | PRODUCED/SKIPPED | [location or "N/A — minimal tier"] |
| Linter Report | PRODUCED/SKIPPED | [zero violations / N exceptions documented] |
| Code Coverage | PRODUCED/SKIPPED | [N% — meets/below threshold] |
| Unit Test Results | PRODUCED | [N passed, N failed] |
| Regression Test Results | PRODUCED | [N passed, N regressions] |
| V&V Audit Report | PRODUCED/SKIPPED | [attached / "N/A — minimal tier"] |
| Diagrams | PRODUCED/SKIPPED | [list each or "N/A — minimal/standard tier"] |
| Engineering Journal | PRODUCED/SKIPPED | [doc/journal/YYYY-MM-DD-PROJ-NNN.md or "N/A"] |
| **Proportionality Tier** | [MINIMAL/STANDARD/COMPREHENSIVE] | [rationale] |

### Working Context
- Active Work: [updated — item removed from active, decisions recorded]
```

## Task Decomposition Patterns

### Standard Feature
```
1. [Explore] Analyze codebase for existing patterns and affected files
2. [Plan] Define implementation approach and file changes
3. [Implement] Write the feature code (subagent)
4. [Test] Write unit tests with 100% coverage (subagent)
5. [Document] Produce documentation deliverables per proportionality tier
6. [/pr] Review, fix blocking issues, create PR
```

### Bug Fix
```
1. [Explore] Reproduce the bug and identify root cause
2. [Test] Write a failing test that demonstrates the bug (subagent)
3. [Implement] Fix the bug — test should now pass (subagent)
4. [Verify] Run full test suite for regressions (subagent)
5. [Document] Produce documentation deliverables (minimal tier unless security-sensitive)
6. [/pr] Review and create PR
```

### Refactoring
```
1. [Explore] Map all usages of the code being refactored
2. [Test] Ensure existing tests cover current behavior (subagent)
3. [Implement] Refactor with tests continuously passing (subagent)
4. [Verify] All existing tests still pass (subagent)
5. [Document] Produce documentation deliverables per proportionality tier
6. [/pr] Review and create PR
```

## Error Handling

**Tracker MCP unavailable**: If a work item ID was provided but the tracker MCP server is not configured or unavailable, inform the user and suggest providing the task as natural language instead. See `_shared/references/tracker-operations.md` Error Handling for degraded-mode behavior.

**Subagent failure**: If a subagent fails or gets stuck, spawn a replacement with more specific instructions or report the blocker to the user.

**No test framework detected**: The implementer subagent should identify the appropriate test framework from the project. If none exists, it sets one up as part of the implementation.
