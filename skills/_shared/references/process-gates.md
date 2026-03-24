# Process Enforcement Gates

Process gates define the conditions that must be met before a work item can transition between workflow states. Skills check these gates at entry (Step 0). Gate behavior scales with the proportionality tier and the `process_enforcement.mode` config setting.

## State Model

```
triaged → planned → ready → in-progress → in-review → verifying → done

Any state ↔ blocked (when dependency detected/resolved)
```

### Tracker-Mapped States

Only these states exist in the external tracker and are synchronized via `tracker-operations.md` `update_status`:

- **planned** → maps to tracker "To Do" state (via `status_map.todo`)
- **in-progress** → maps to tracker "In Progress" state (via `status_map.in_progress`)
- **in-review** → maps to tracker "In Review" state (via `status_map.in_review`)
- **done** → maps to tracker "Done" state (via `status_map.done`)

### Internal-Only States

These exist only in `session-state.json` under `orchestrator.itemStates` and are not pushed to the tracker:

- **triaged** — triage branch exists with committed document for this topic
- **ready** — planned + all dependencies resolved (auto-computed, not manually set)
- **verifying** — V&V audit in progress (`/vv` is running)
- **blocked** — one or more dependencies unresolved (auto-computed from `check_dependencies`)

---

## Gates

### G1: Plan Gate (triaged → planned)

**Condition**: A triage branch exists with a committed triage document for this topic.

**Check**:
1. Run `git branch --list 'triage/*'` and match against the work item topic/slug
2. Verify the matched branch contains a committed markdown file (use `git show <branch>:triage/<slug>.md`)
3. If no matching triage branch, check `session-state.json` `orchestrator.itemStates[itemId].abstractState == "triaged"`

**Enforcement**:
- Minimal tier: **warn** — "No triage document found. Consider running `/triage` first for traceability."
- Standard/Comprehensive tier: **block** — "BLOCKED: No triage document for this item. Run `/triage <description>` to create one."

**On failure**: Direct the user to run `/triage` with the relevant issue description.

---

### G2: Implement Gate (planned → in-progress)

**Conditions**:

1. **Work item exists in tracker** with state == todo/To Do equivalent
   - Use `tracker-operations.md` `fetch_item` to retrieve the work item
   - Verify its status maps to the `todo` normalized state (see Status Mapping in `tracker-operations.md`)

2. **All dependencies resolved** — every dependency work item is in `done` state
   - Use `tracker-operations.md` `check_dependencies` to query blocking relationships
   - Each item in the `blocked_by` list must have status == done
   - **This condition is non-negotiable** — dependencies are enforced at all tiers

3. **Input documents linked** — requirement ID reference exists in work item description
   - Check the work item description for a `REQ-*` pattern (e.g., `REQ-travis-XXX-NNN`)
   - For minimal tier: warn if missing
   - For standard+ tiers: block if missing

4. **Triage document exists** (standard+ tiers only)
   - Verify the G1 triage condition is satisfied
   - Minimal tier: skip this check

**Enforcement**:
- Dependencies (condition 2): **block** for all tiers — dependencies are non-negotiable
- Other conditions: **block** for standard/comprehensive, **warn** for minimal

**On failure**: Report which specific condition failed:
- Condition 1: "Work item [ID] is in state [state], expected To Do. Update the tracker state before implementing."
- Condition 2: "Blocked by [ID1] (state: [state]), [ID2] (state: [state]). These must reach Done before work can begin."
- Condition 3: "No requirement ID (REQ-*) found in work item description. Link the relevant requirement."
- Condition 4: "No triage document found. Run `/triage` first (required for standard+ tier)."

---

### G3: Review Gate (in-progress → in-review)

**Conditions**:

1. **All code committed and pushed**
   - Run `git status --short` — must show no uncommitted changes
   - Run `git log origin/<branch>..<branch>` — must show no unpushed commits (or remote branch must exist)

2. **Documentation deliverables produced** — proportionality-appropriate artifacts exist
   - Minimal tier: linter report, unit test results, regression test results
   - Standard tier: minimal + SDD + code coverage + V&V audit
   - Comprehensive tier: all 8 artifacts (see `/implement` proportionality rules)
   - Check for deliverables in `doc/design/`, `doc/journal/`, and test output locations

3. **V&V has been run** (standard+ tiers only)
   - Check `session-state.json` for `orchestrator.itemStates[itemId].vvStatus == "passed"` or `"completed"`
   - If not found: "V&V audit not recorded. Run `/vv` to validate requirement traceability."

**Enforcement**:
- Standard/Comprehensive: **block** on all conditions
- Minimal: **warn** on conditions 2 and 3, **block** on condition 1 (uncommitted code is always blocked)

**On failure**: Report the specific missing deliverable or uncommitted state with remediation.

---

### G4: Merge Gate (in-review → done)

**Conditions**:

1. **PR review approved** — no outstanding "changes requested"

   - Check the PR via the **github** MCP tools for approval status
   - All required approvals must be granted


2. **V&V report attached to work item** (standard+ tiers)
   - Verify a V&V audit report is linked to the work item (use `tracker-operations.md` `fetch_item` and check linked artifacts)
   - For minimal tier: skip this check

3. **All output artifacts linked to work item**
   - PR is linked to the work item
   - Documentation deliverables are referenced in the work item or PR description

4. **All acceptance criteria tests pass**
   - Check test results from the most recent CI run or local test execution
   - Each acceptance criterion from the work item should map to at least one passing test

**Enforcement**: **block** for all tiers — merge gates are always enforced.

**On failure**:
- Condition 1: "PR has outstanding change requests. Address reviewer feedback before merging."
- Condition 2: "V&V report not attached to work item [ID]. Run `/vv` and link the output."
- Condition 3: "Artifacts not linked to work item. Use `link_artifact` to attach PR and documentation."
- Condition 4: "Acceptance criteria tests failing: [list]. Fix before merge."

---

## Gate Evaluation Logic

Skills evaluate gates at Step 0 before executing their primary workflow:

```
1. Read process_enforcement config:
   - If enabled == false OR mode == "off": SKIP all gates, proceed immediately
   - If mode == "warn": evaluate gates, show warnings, allow override
   - If mode == "block": evaluate gates, hard-stop on failure

2. Determine proportionality tier:
   a. Check the work item type (bug → minimal, feature → standard, architecture → comprehensive)
   b. Check lines changed (<50 = minimal, 50-300 = standard, >300 = comprehensive)
   c. Check component sensitivity (security, auth, data → always comprehensive)
   d. Use the HIGHEST applicable tier

3. Look up the relevant gate for the current transition:
   - /plan entering → G1 (Plan Gate)
   - /implement entering → G2 (Implement Gate)
   - /pr creating → G3 (Review Gate)
   - /pr merging or work item → Done → G4 (Merge Gate)

4. Evaluate each condition in the gate:
   a. Query tracker via MCP (use tracker-operations.md operations)
   b. Check session-state.json orchestrator.itemStates as fallback
   c. Check filesystem for deliverables (git branches, doc/ files)

5. Determine result:
   - All conditions pass → proceed silently (no output about gates)
   - Any condition fails:
     - mode == "warn":
       "⚠ WARNING: [gate name] — [condition] not met. [remediation]. Proceeding anyway."
     - mode == "block":
       "BLOCKED: [gate name] — [condition] not met. [remediation]. Resolve before proceeding."
       Stop the skill workflow.
```

---

## Role Check (all gates)

Before evaluating gate conditions:
1. Resolve current user's role per the procedure in `enforcement.md` (RBAC → Role Resolution)
2. Check the permission matrix for this transition
3. If role is not permitted: include `G{N}_ROLE_FORBIDDEN` in failed_conditions
4. If `process_enforcement.roles` is absent: skip role check (backward compatible)

---

## Structured Rejection Output

When gate evaluation is complete, produce a structured rejection object per the schema in `enforcement.md`:

1. For each failed condition, create a `failed_conditions` entry with:
   - `code`: The rejection code from the Rejection Code Taxonomy (e.g., `G2_DEPS_UNRESOLVED`)
   - `condition`: The condition name
   - `severity`: `block` or `warn` based on mode and tier
   - `detail`: Human-readable explanation with specific values
   - `remediation`: Actionable fix instruction
   - `retry_policy`: `immediate`, `after-fix`, or `after-approval`

2. For each passed condition, create a `passed_conditions` entry

3. Include `role_check` results (see Role Check section above)

4. Include `human_gates_pending` (see `enforcement.md` Human Gate Protocol)

5. Store the rejection object in session-state.json: `orchestrator.itemStates[id].lastGateResult`

---

## Human Gate Check (all gates)

After evaluating mechanical conditions:
1. Check if any `process_enforcement.human_gates` apply to this gate + current tier
2. If yes: check `orchestrator.itemStates[id].humanGates.{gate_name}.status`
   - If `"approved"`: condition passes
   - If `"pending"` or absent: include `G4_HUMAN_GATE_PENDING` in failed_conditions
3. If `process_enforcement.human_gates` is absent: skip (backward compatible)

---

## Graceful Degradation

When the tracker MCP server is unavailable, gates must still function using local data sources. The principle: **never crash, never silently skip gates, always inform the user about degraded state.**

### Fallback Chain

| Data Needed | Primary Source | Fallback 1 | Fallback 2 |
|------------|---------------|-----------|-----------|
| Work item state | Tracker MCP (`fetch_item`) | `session-state.json` `orchestrator.itemStates[id].abstractState` | Skip with warning |
| Dependencies | Tracker MCP (`check_dependencies`) | `session-state.json` `orchestrator.itemStates[id].dependencies` | Skip with warning |
| Triage document | Git branch inspection (`git branch --list 'triage/*'`) | `session-state.json` `orchestrator.itemStates[id].abstractState == "triaged"` | Skip with warning |
| Code committed | `git status` (always local) | — | — |
| Deliverables exist | Filesystem check (`doc/`, test outputs) | — | — |
| PR approval | Git provider MCP | `session-state.json` `orchestrator.itemStates[id].prStatus` | Skip with warning |
| V&V status | `session-state.json` `orchestrator.itemStates[id].vvStatus` | Check for V&V report file in `doc/` | Skip with warning |

### Degradation Behavior

When falling back to local data:

1. Warn the user: "Tracker unavailable — using local state (last sync: [timestamp from session-state.json lastUpdated]). State may be stale."
2. **In `warn` mode**: proceed with local verification, show warnings for conditions that cannot be verified
3. **In `block` mode**:
   - **Block** on conditions that can be verified locally (git state, filesystem checks, session-state cache)
   - **Warn-only** on conditions that require live tracker data and cannot be verified from cache
   - Never hard-block on a condition that is impossible to verify — that would halt all work when the tracker is down
4. Log the degraded evaluation in `session-state.json` under `orchestrator.lastGateCheck`:
   ```json
   {
     "gate": "G2",
     "itemId": "PROJ-123",
     "timestamp": "2026-03-20T10:00:00Z",
     "degraded": true,
     "results": {
       "tracker_state": "skipped — MCP unavailable",
       "dependencies": "skipped — MCP unavailable",
       "requirement_link": "passed",
       "triage_document": "passed"
     }
   }
   ```

### Local-Only Checks (Always Available)

These checks never require the tracker and are always fully enforceable:

- `git status --short` — uncommitted changes
- `git branch --list 'triage/*'` — triage branch existence
- `git log origin/<branch>..<branch>` — unpushed commits
- Filesystem checks — `doc/design/`, `doc/journal/`, test output files
- `session-state.json` — cached states, V&V status, last gate results
