# Enforcement Engine Reference

The enforcement engine wraps process gates (defined in `process-gates.md`) with structured rejections, role-based permissions, and human gates. Skills reference this file when evaluating gates at Step 0. The engine produces machine-readable rejection objects so that callers can programmatically inspect failures, retry after fixes, or escalate to human approvers.

All enforcement features are backward compatible: if the corresponding `process_enforcement` config section is absent, the feature is silently skipped.

---

## Structured Rejection Schema

### Rejection Object

Every gate evaluation produces a rejection object, whether the gate passes or fails. Skills consume this object to decide how to proceed.

```json
{
  "gate": "G2",
  "item_id": "PROJ-123",
  "result": "REJECTED",
  "timestamp": "2026-03-21T14:30:00Z",
  "tier": "standard",
  "mode": "block",
  "failed_conditions": [
    {
      "code": "G2_DEPS_UNRESOLVED",
      "condition": "dependencies_resolved",
      "severity": "block",
      "detail": "Blocked by PROJ-100 (state: In Progress), PROJ-101 (state: To Do)",
      "remediation": "Complete PROJ-100, PROJ-101 before starting. Run `/orchestrate status` to check progress.",
      "retry_policy": "after-fix"
    }
  ],
  "passed_conditions": [
    {
      "code": "G2_ITEM_STATE_INVALID",
      "condition": "work_item_state",
      "detail": "Current state: To Do (expected)"
    }
  ],
  "role_check": {
    "current_user": "thendrickson",
    "current_role": "lead",
    "transition": "planned -> in-progress",
    "allowed": true
  },
  "human_gates_pending": [],
  "degraded": false,
  "degraded_checks": []
}
```

### Field Definitions

| Field | Type | Description |
|-------|------|-------------|
| `gate` | string | Gate identifier: `"G1"`, `"G2"`, `"G3"`, `"G4"` |
| `item_id` | string | Work item ID being evaluated |
| `result` | string | `"PASSED"` or `"REJECTED"` |
| `timestamp` | string (ISO 8601) | When the evaluation occurred |
| `tier` | string | Proportionality tier: `"minimal"`, `"standard"`, `"comprehensive"` |
| `mode` | string | Enforcement mode: `"block"`, `"warn"`, `"off"` |
| `failed_conditions` | array | Conditions that did not pass (see below) |
| `passed_conditions` | array | Conditions that passed (see below) |
| `role_check` | object | Role resolution and permission result |
| `human_gates_pending` | array | Human gate names awaiting approval |
| `degraded` | boolean | `true` if any check used fallback data |
| `degraded_checks` | array of strings | Which checks fell back to local data |

### Condition Object (failed)

| Field | Type | Description |
|-------|------|-------------|
| `code` | string | Unique rejection code (see Rejection Code Taxonomy) |
| `condition` | string | The condition name from `process-gates.md` |
| `severity` | string | `"block"` or `"warn"` (tier-dependent) |
| `detail` | string | Human-readable explanation of the failure |
| `remediation` | string | Actionable instruction to resolve the failure |
| `retry_policy` | string | When the gate can be re-evaluated (see Retry Policies) |

### Condition Object (passed)

| Field | Type | Description |
|-------|------|-------------|
| `code` | string | Condition code |
| `condition` | string | The condition name |
| `detail` | string | Human-readable confirmation |

---

## Rejection Code Taxonomy

Every rejection code follows the pattern `G{N}_{CONDITION_NAME}` where `N` is the gate number. The special prefix `TIER2_` is used for intelligent verification results that span gates.

### G1 -- Plan Gate (triaged -> planned)

| Code | Condition | Severity | Remediation Template |
|------|-----------|----------|---------------------|
| `G1_NO_TRIAGE_DOC` | No triage document found for this topic | block (std+), warn (min) | "Run `/triage` to capture and analyze the issue before planning." |
| `G1_ROLE_FORBIDDEN` | User role cannot execute this transition | block | "Transition triaged -> planned requires role: {required_roles}. Your role: {current_role}." |

### G2 -- Implement Gate (planned -> in-progress)

| Code | Condition | Severity | Remediation Template |
|------|-----------|----------|---------------------|
| `G2_ITEM_STATE_INVALID` | Work item not in expected state (To Do) | block | "Work item must be in To Do state. Current: {state}. Update the tracker before implementing." |
| `G2_DEPS_UNRESOLVED` | One or more dependency items not in Done state | block | "Complete {blocker_ids} before starting. Run `/orchestrate status` to check progress." |
| `G2_NO_REQ_LINK` | No requirement reference (REQ-*) in work item description | block (std+), warn (min) | "Add REQ-* reference to work item description for traceability." |
| `G2_NO_TRIAGE_DOC` | No triage document exists (standard+ tiers only) | block (std+) | "Run `/triage` first. Triage documentation is required for standard and comprehensive tiers." |
| `G2_ROLE_FORBIDDEN` | User role cannot start implementation | block | "Transition planned -> in-progress requires role: {required_roles}. Your role: {current_role}." |

### G3 -- Review Gate (in-progress -> in-review)

| Code | Condition | Severity | Remediation Template |
|------|-----------|----------|---------------------|
| `G3_UNCOMMITTED_CHANGES` | Uncommitted or unpushed code detected | block | "Commit and push all changes before creating PR. Run `git status` to see pending changes." |
| `G3_MISSING_DELIVERABLES` | Required documentation artifacts missing for this tier | block (std+), warn (min) | "Missing: {deliverable_list}. Produce required deliverables before review." |
| `G3_VV_NOT_RUN` | V&V audit not executed (standard+ tiers only) | block (std+) | "Run `/vv {item_id}` before creating PR." |
| `G3_ROLE_FORBIDDEN` | User role cannot create PR / move to review | block | "Transition in-progress -> in-review requires role: {required_roles}. Your role: {current_role}." |

### G4 -- Merge Gate (in-review -> done)

| Code | Condition | Severity | Remediation Template |
|------|-----------|----------|---------------------|
| `G4_PR_NOT_APPROVED` | PR has outstanding change requests or lacks required approvals | block | "Address PR review comments and get approval before merging." |
| `G4_VV_NOT_ATTACHED` | V&V report not linked to work item (standard+ tiers) | block (std+) | "Run `/vv {item_id}` and attach the report to the work item." |
| `G4_ARTIFACTS_NOT_LINKED` | Output artifacts (PR, docs) not linked to work item | block | "Link deliverables to work item via tracker. Use `link_artifact` to attach PR and documentation." |
| `G4_AC_TESTS_FAILING` | One or more acceptance criteria tests failing | block | "Fix failing tests: {test_list}. All acceptance criteria must pass before merge." |
| `G4_HUMAN_GATE_PENDING` | Awaiting human approval for a configured human gate | block | "Awaiting {gate_name} approval from {required_role}. See Human Gate Protocol below." |
| `G4_ROLE_FORBIDDEN` | User role cannot close the work item | block | "Transition in-review -> done requires role: {required_roles}. Your role: {current_role}." |

### Cross-Gate

| Code | Condition | Severity | Remediation Template |
|------|-----------|----------|---------------------|
| `TIER2_VERIFICATION_FAILED` | Intelligent verification (Tier 2) found gaps | block | "Tier 2 verification found {gap_count} issues. Review the verdict and address each gap before proceeding." |

---

## Retry Policies

Each failed condition specifies when the gate can be re-evaluated.

| Policy | Meaning | Agent Behavior |
|--------|---------|----------------|
| `immediate` | Condition may be stale (e.g., cached dependency check, MCP timeout) | Re-evaluate the gate immediately without user action |
| `after-fix` | Agent or user must perform specific work to resolve | Follow the `remediation` instruction, then retry the gate |
| `after-approval` | Requires a human to grant approval | Park the item, notify approvers, wait for approval signal before retrying |

### Policy Assignment Rules

- `G*_ROLE_FORBIDDEN` -> `after-fix` (user must switch context or have a permitted user act)
- `G*_DEPS_UNRESOLVED` -> `after-fix` (complete blocking items first)
- `G4_HUMAN_GATE_PENDING` -> `after-approval`
- `G4_PR_NOT_APPROVED` -> `after-fix` (address review feedback)
- All other codes -> `after-fix` (default)

---

## Role-Based Access Control (RBAC)

### Canonical Roles

The enforcement engine maps free-text roles from `team.members[].role` in config.yaml to one of five canonical roles.

| Canonical Role | Description |
|----------------|-------------|
| `lead` | Technical lead or owner. Full permissions including gate overrides. |
| `engineer` | Developer or implementer. Can start and submit work. Cannot close items or override gates. |
| `pm` | Project manager. Can plan, reassign, adjust priorities. Cannot implement. |
| `reviewer` | Reviewer or QA. Can approve gates and PRs. Cannot implement. |
| `stakeholder` | Business stakeholder. Can approve sign-off gates. Read-only for all other operations. |

### Role Resolution Procedure

To determine the current user's canonical role:

1. Read `git config user.name` (fall back to `git config user.email` if name is empty)
2. Match against `team.members[].username` or `team.members[].name` in config.yaml (case-insensitive)
3. Read the matched member's `.role` field (free-text string)
4. Map the free-text role to a canonical role:
   a. Check `process_enforcement.roles.role_map` in config for an explicit mapping
   b. If no explicit mapping, apply keyword matching:

   | Keywords in role string (case-insensitive) | Canonical Role |
   |---------------------------------------------|---------------|
   | `owner`, `lead`, `architect`, `principal`, `cto`, `vp` | `lead` |
   | `engineer`, `developer`, `dev`, `programmer`, `consultant` | `engineer` |
   | `pm`, `project manager`, `program manager`, `scrum master`, `manager` | `pm` |
   | `reviewer`, `qa`, `quality`, `test lead`, `auditor` | `reviewer` |
   | `stakeholder`, `director`, `executive`, `sponsor`, `customer`, `leadership` | `stakeholder` |

   c. If multiple keywords match, use the first match in the table order above
5. If no match: use `process_enforcement.roles.defaults.unknown_role` from config (default: `engineer`)
6. Solo developer override: if `process_enforcement.roles.solo_developer_override` is `true` (default: `true`) and `team.members` has exactly 1 entry, the resolved role is always `lead`
7. Store the resolved role in `session-state.json`: `orchestrator.currentUserRole`

### Config Schema for Roles

```yaml
process_enforcement:
  roles:
    role_map:                          # Optional explicit mappings
      "Owner / AI Architect": "lead"
      "AI/Engineering Consultant": "engineer"
      "F3 Leadership": "stakeholder"
      "Project Manager": "pm"
    defaults:
      unknown_role: "engineer"         # Default: "engineer"
    solo_developer_override: true      # Default: true
```

If `process_enforcement.roles` is absent in config, skip all role checks. All transitions are permitted (backward compatible).

### Permission Matrix

| Transition | lead | engineer | pm | reviewer | stakeholder |
|-----------|------|----------|-----|----------|-------------|
| triaged -> planned (G1) | Y | Y | Y | -- | -- |
| planned -> in-progress (G2) | Y | Y | -- | -- | -- |
| in-progress -> in-review (G3) | Y | Y | -- | -- | -- |
| in-review -> done (G4) | Y | --* | -- | -- | -- |
| Override blocked gate | Y | -- | -- | -- | -- |
| Reassign work item | Y | -- | Y | -- | -- |
| Approve human gate | Y | -- | Y+ | Y | Y+ |

**Legend**:
- `Y` = permitted
- `--` = denied (returns `G{N}_ROLE_FORBIDDEN`)
- `--*` = engineer can trigger G4 evaluation but `G4_PR_NOT_APPROVED` ensures a non-author reviewer has approved the PR; the engineer cannot self-approve
- `Y+` = PM and stakeholder can approve sign-off human gates only (not technical review gates)

### Permission Check Procedure

Before any gate transition:

1. Resolve the current user's canonical role (see Role Resolution Procedure above)
2. Look up the transition in the permission matrix
3. Check `process_enforcement.permissions.overrides` for customer-specific overrides:
   ```yaml
   process_enforcement:
     permissions:
       overrides:
         "planned -> in-progress":
           allow: ["lead", "engineer", "pm"]   # Add pm to G2
         "in-review -> done":
           allow: ["lead", "engineer"]          # Let engineers close items
   ```
4. If the role is not permitted:
   - Build a rejection condition with code `G{N}_ROLE_FORBIDDEN`
   - Set `severity: "block"`
   - Set `detail`: "Transition {from} -> {to} requires role: {allowed_roles}. Your role: {current_role} ({raw_role})."
   - Set `retry_policy: "after-fix"`
5. If `process_enforcement.roles` is absent: skip this check entirely (all roles permitted)

---

## Human Gate Protocol

Human gates require explicit approval from a person with the right role before a process gate can pass. They are used for sign-offs, compliance checkpoints, and approval workflows.

### Configuration

```yaml
process_enforcement:
  human_gates:
    design_review:
      description: "Design document sign-off before implementation"
      required_for: ["G2"]
      required_tiers: ["standard", "comprehensive"]
      required_approvers: ["lead", "stakeholder"]
      timeout_hours: 24
      escalation: "lead"
    sign_off:
      description: "Final merge approval from lead"
      required_for: ["G4"]
      required_tiers: ["comprehensive"]
      required_approvers: ["lead"]
      timeout_hours: 48
      escalation: "lead"
```

### Config Field Definitions

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `description` | string | no | `""` | Human-readable description of the gate purpose |
| `required_for` | array of strings | yes | -- | Which process gates trigger this human gate (`"G1"`, `"G2"`, `"G3"`, `"G4"`) |
| `required_tiers` | array of strings | yes | -- | Which proportionality tiers require this gate (`"minimal"`, `"standard"`, `"comprehensive"`) |
| `required_approvers` | array of strings | yes | -- | Canonical roles that can approve (`"lead"`, `"pm"`, `"reviewer"`, `"stakeholder"`) |
| `timeout_hours` | number | no | `24` | Hours before escalation |
| `escalation` | string | no | `"lead"` | Canonical role to escalate to on timeout |

### Request Flow

**Step 1: Gate encounters human gate condition.**

During gate evaluation, check if any configured human gate applies to the current gate and tier:

```
for each gate_name, gate_config in process_enforcement.human_gates:
    if current_gate in gate_config.required_for
       AND current_tier in gate_config.required_tiers:
        check if already approved
```

If the human gate has not been approved:

1. Post a comment on the work item via `tracker-operations.md` `link_artifact`:
   ```
   Awaiting [<gate_name>] approval from [<required_roles>].
   Gate: <gate> for <item_id>.
   Description: <description>
   ```
2. Write to session state:
   ```json
   {
     "orchestrator": {
       "itemStates": {
         "<item_id>": {
           "humanGates": {
             "<gate_name>": {
               "status": "pending",
               "requestedAt": "2026-03-21T14:30:00Z",
               "timeoutAt": "2026-03-22T14:30:00Z",
               "requiredApprovers": ["lead", "stakeholder"],
               "approvedBy": null,
               "approvedAt": null
             }
           }
         }
       }
     }
   }
   ```
3. Add `G4_HUMAN_GATE_PENDING` to `failed_conditions` with `retry_policy: "after-approval"`

**Step 2: Display to user.**

```
## Human Gate Pending: <gate_name>

<item_id> requires <gate_name> approval before proceeding.
Description: <description>
Required approver role: <required_roles>
Requested: <timestamp>
Timeout: <timeout_timestamp>

Grant approval:
- Comment "APPROVED: <gate_name>" on the work item in the tracker
- Or run: /orchestrate approve <item_id> <gate_name>
```

**Step 3: Approval detection.**

On the next gate evaluation or `/orchestrate status`, check for approval:

IMPORTANT: The approver identity MUST be determined from the tracker API's comment author field (e.g., Jira `author.accountId`, Linear `user.id`), NOT from any text within the comment body. Reject comments where the API-reported author does not match a team member with an approved role.

1. Check tracker comments (via `tracker-operations.md` `fetch_item`) for text matching `APPROVED: <gate_name>` from a user whose role is in `required_approvers`
2. Check session state for a grant written by `/orchestrate approve`
3. If approved:
   - Update session state: `humanGates.<gate_name>.status = "approved"`
   - Set `humanGates.<gate_name>.approvedBy = "<username>"`
   - Set `humanGates.<gate_name>.approvedAt = "<timestamp>"`
   - Remove from `human_gates_pending` in the rejection object

**Step 4: Timeout and escalation.**

If `timeout_hours` elapses without approval:

1. Post escalation comment on the work item:
   ```
   Escalating [<gate_name>] to [<escalation_role>] -- approval timeout after <timeout_hours> hours.
   ```
2. Update session state: `humanGates.<gate_name>.status = "escalated"`
3. Do NOT auto-approve -- escalation only increases visibility; a human must still grant approval

### `/orchestrate approve` Command

Syntax: `/orchestrate approve <item_id> <gate_name>`

Procedure:

1. Resolve the current user's canonical role (Role Resolution Procedure)
2. Look up `<gate_name>` in `process_enforcement.human_gates`
3. Verify the resolved role is in `required_approvers` for that gate
4. If authorized:
   - Update session state: `humanGates.<gate_name>.status = "approved"`
   - Set `approvedBy` and `approvedAt`
   - Post tracker comment: `APPROVED: <gate_name> by <username> (<role>)`
   - Report: "<gate_name> approved for <item_id>."
5. If not authorized:
   - Report: "Your role (<role>) cannot approve <gate_name>. Required: <required_approvers>."
   - Do not modify session state

If `process_enforcement.human_gates` is absent in config, no human gates are enforced (backward compatible).

---

## Enforcement Evaluation Algorithm

When a skill evaluates a gate (e.g., `/orchestrate start` evaluates G2), execute the following steps in order:

```
Step 1: Check enforcement enabled
   - Read process_enforcement.enabled from config
   - If false or absent: SKIP all enforcement, return result = "PASSED", proceed

Step 2: Determine enforcement mode
   a. Check process_enforcement.gate_overrides.{gate}.mode for a gate-specific override
   b. If not set: use process_enforcement.mode
   c. If not set: default to "warn"
   d. If mode == "off": SKIP all enforcement, return result = "PASSED", proceed

Step 3: Determine proportionality tier
   - Use the work item's tier if already stored in session state
   - Otherwise auto-detect per process-gates.md Gate Evaluation Logic step 2:
     a. Work item type (bug -> minimal, feature -> standard, architecture -> comprehensive)
     b. Lines changed (<50 = minimal, 50-300 = standard, >300 = comprehensive)
     c. Component sensitivity (security, auth, data -> always comprehensive)
     d. Use the HIGHEST applicable tier

Step 4: Resolve current user's role
   - Execute the Role Resolution Procedure (see RBAC section above)
   - If process_enforcement.roles is absent: skip role checks entirely

Step 5: Check role permission for this transition
   - Look up the transition in the Permission Matrix
   - Apply any customer overrides from process_enforcement.permissions.overrides
   - If role is not permitted: add G{N}_ROLE_FORBIDDEN to failed_conditions

Step 6: Evaluate each gate condition
   - For each condition defined in process-gates.md for this gate:
     a. Determine if the condition applies at the current tier
     b. Query the data source (tracker MCP, git, filesystem, session state)
     c. If the primary data source is unavailable, use the fallback chain
        from process-gates.md Graceful Degradation
     d. Determine pass/fail
     e. Build the condition object and add to passed_conditions or failed_conditions
     f. Set severity based on tier: conditions that are "warn" at minimal but "block"
        at standard+ use the tier-appropriate severity

Step 7: Check human gates
   - For each human gate in process_enforcement.human_gates:
     a. If current gate is in required_for AND current tier is in required_tiers:
        - Check session state for existing approval
        - If not approved: add G4_HUMAN_GATE_PENDING to failed_conditions
          with retry_policy = "after-approval"
        - Add gate name to human_gates_pending array

Step 8: Check Tier 2 verification (G4 only)
   - If gate == G4 AND process_enforcement.tier2_enabled == true
     AND current tier is in process_enforcement.tier2_tiers (default: ["standard", "comprehensive"]):
     a. Invoke the verification sub-agent (see /vv skill)
     b. If verdict is FAIL: add TIER2_VERIFICATION_FAILED to failed_conditions
        with detail containing the gap count and summary
     c. If verdict is PASS: add to passed_conditions

Step 9: Build rejection object
   - Set result:
     - If failed_conditions is empty: result = "PASSED"
     - If failed_conditions is not empty: result = "REJECTED"
   - Populate all fields per the Rejection Object schema

Step 10: Act on result
   - If result == "PASSED": proceed with the skill workflow silently
   - If result == "REJECTED":
     - mode == "block":
       Display each failed condition:
         "BLOCKED: [{gate}] {code} -- {detail}. {remediation}"
       Halt the skill workflow. Do not proceed.
     - mode == "warn":
       Display each failed condition:
         "WARNING: [{gate}] {code} -- {detail}. {remediation}"
       Prompt: "Continue despite warnings? [Enter/n]"
       If user confirms: proceed
       If user declines: halt
     - mode == "off":
       Proceed silently (should not reach here due to Step 2 short-circuit)

Step 11: Write result to session state
   - Write the rejection object to session-state.json:
     orchestrator.lastGateResult = <rejection object>
   - Update orchestrator.itemStates[item_id].lastGateCheck = <timestamp>
```

---

## Gate Override Configuration

Customers can override enforcement mode per gate.

```yaml
process_enforcement:
  enabled: true
  mode: block                         # Default mode for all gates
  gate_overrides:
    G1:
      mode: warn                      # Softer enforcement on plan gate
    G2:
      mode: block                     # Strict on implement gate
    G3:
      mode: block
    G4:
      mode: block
  tier2_enabled: false                # Default: false
  tier2_tiers:                        # Default: ["standard", "comprehensive"]
    - standard
    - comprehensive
```

### Full Config Schema Reference

All `process_enforcement` fields with types and defaults:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | boolean | `false` | Master switch for all enforcement |
| `mode` | string | `"warn"` | Default enforcement mode: `"block"`, `"warn"`, `"off"` |
| `dependency_check` | boolean | `true` | Enable dependency resolution checks |
| `auto_state_transitions` | boolean | `true` | Auto-update tracker state on gate pass |
| `input_verification` | boolean | `true` | Verify input documents at gate entry |
| `output_verification` | boolean | `true` | Verify output artifacts at gate exit |
| `gate_overrides` | object | `{}` | Per-gate mode overrides (see above) |
| `gate_overrides.{gate}.mode` | string | (inherits `mode`) | Gate-specific mode |
| `tier2_enabled` | boolean | `false` | Enable Tier 2 intelligent verification at G4 |
| `tier2_tiers` | array of strings | `["standard", "comprehensive"]` | Tiers that trigger Tier 2 verification |
| `roles` | object | (absent) | Role configuration; absent = skip role checks |
| `roles.role_map` | object | `{}` | Explicit free-text-to-canonical role mappings |
| `roles.defaults.unknown_role` | string | `"engineer"` | Canonical role when user cannot be matched |
| `roles.solo_developer_override` | boolean | `true` | Single team member gets `lead` role |
| `permissions` | object | (absent) | Permission configuration |
| `permissions.overrides` | object | `{}` | Per-transition permission overrides |
| `human_gates` | object | (absent) | Human gate definitions; absent = no human gates |
| `human_gates.{name}.description` | string | `""` | Human-readable gate description |
| `human_gates.{name}.required_for` | array of strings | (required) | Process gates that trigger this human gate |
| `human_gates.{name}.required_tiers` | array of strings | (required) | Tiers that require this human gate |
| `human_gates.{name}.required_approvers` | array of strings | (required) | Canonical roles that can approve |
| `human_gates.{name}.timeout_hours` | number | `24` | Hours before escalation |
| `human_gates.{name}.escalation` | string | `"lead"` | Role to escalate to on timeout |

---

## Session State Fields

The enforcement engine reads and writes the following fields in `session-state.json` under the `orchestrator` namespace (owned by `/orchestrate` per `session-state.md`):

| Field | Type | Description |
|-------|------|-------------|
| `orchestrator.currentUserRole` | string | Resolved canonical role for the current user |
| `orchestrator.lastGateResult` | object | Most recent rejection object (full schema above) |
| `orchestrator.itemStates[id].lastGateCheck` | string (ISO 8601) | Timestamp of last gate evaluation for this item |
| `orchestrator.itemStates[id].humanGates` | object | Map of human gate name to gate state object |
| `orchestrator.itemStates[id].humanGates.{name}.status` | string | `"pending"`, `"approved"`, `"escalated"` |
| `orchestrator.itemStates[id].humanGates.{name}.requestedAt` | string (ISO 8601) | When approval was requested |
| `orchestrator.itemStates[id].humanGates.{name}.timeoutAt` | string (ISO 8601) | When escalation triggers |
| `orchestrator.itemStates[id].humanGates.{name}.requiredApprovers` | array of strings | Canonical roles that can approve |
| `orchestrator.itemStates[id].humanGates.{name}.approvedBy` | string or null | Username of approver |
| `orchestrator.itemStates[id].humanGates.{name}.approvedAt` | string or null (ISO 8601) | When approval was granted |

---

## Backward Compatibility

The enforcement engine is fully additive. Existing customer configs that lack enforcement fields continue to work without changes.

| Missing Config Section | Behavior |
|----------------------|----------|
| `process_enforcement` absent entirely | No enforcement. All gates pass. Skills proceed as before. |
| `process_enforcement.enabled: false` | Same as absent. No enforcement. |
| `process_enforcement.roles` absent | Skip all role checks. All transitions permitted for all users. |
| `process_enforcement.permissions` absent | Use default permission matrix. No customer overrides. |
| `process_enforcement.human_gates` absent | No human gates enforced. `human_gates_pending` is always empty. |
| `process_enforcement.gate_overrides` absent | All gates use the top-level `mode` setting. |
| `process_enforcement.tier2_enabled` absent | No Tier 2 verification. Treated as `false`. |
