# Verification Sub-Agent Reference

## Overview

The verification sub-agent performs Tier 2 intelligent verification -- evaluating whether submitted artifacts actually satisfy acceptance criteria. It complements Tier 1 mechanical checks (file existence, state checks, traceability matrix) with comprehension-based evaluation.

Tier 1 (`/vv`) answers: "Are all required artifacts present and linked?"
Tier 2 (this sub-agent) answers: "Do the artifacts actually satisfy the acceptance criteria?"

## When Invoked

- During `/orchestrate complete` as part of G4 gate evaluation (step 8 of Enforcement Evaluation Algorithm in `_shared/references/enforcement.md`)
- Only when `process_enforcement.tier2_enabled: true` AND the item's proportionality tier is in `process_enforcement.tier2_tiers` (default: `["standard", "comprehensive"]`)
- After `/vv` has already passed (Tier 1 mechanical check must pass before Tier 2 runs)

## Sub-Agent System Prompt

```
You are a Verification Engineer. Your ONLY job is to evaluate whether submitted
artifacts satisfy the acceptance criteria for work item {item_id}: {item_title}.

CONSTRAINTS:
- You MUST NOT modify any files, create branches, or make commits
- You MUST NOT help, suggest improvements, or offer alternatives
- You MUST NOT run any write operations or MCP tool calls that alter state
- You MUST evaluate each acceptance criterion independently
- You MUST provide specific evidence (file paths, line numbers, test output) for each verdict
- You MUST return a structured JSON verdict as your final output

{rubric_section}
```

## Input Schema

The orchestrator passes this context to the sub-agent:

```json
{
  "item_id": "PROJ-123",
  "item_title": "Add login form validation",
  "acceptance_criteria": [
    {
      "id": "AC-1",
      "description": "Login form validates email format before submission"
    },
    {
      "id": "AC-2",
      "description": "Password field requires minimum 8 characters with mixed case"
    }
  ],
  "artifacts": {
    "changed_files": ["src/auth/login.ts", "src/auth/login.test.ts"],
    "diff_summary": "2 files changed, 45 insertions, 3 deletions",
    "test_output": "<test results summary>",
    "coverage": "<coverage percentage for changed files>",
    "documentation": ["doc/design/sdd-proj-123.md"]
  },
  "rubric": null,
  "previous_verdict": null,
  "resubmission_diff": null
}
```

### Input Field Definitions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `item_id` | string | yes | Work item identifier |
| `item_title` | string | yes | Work item title for context |
| `acceptance_criteria` | array | yes | List of AC objects with `id` and `description` |
| `acceptance_criteria[].id` | string | yes | Acceptance criterion identifier (e.g., `"AC-1"`) |
| `acceptance_criteria[].description` | string | yes | Full text of the acceptance criterion |
| `artifacts.changed_files` | array of strings | yes | File paths modified in this work item |
| `artifacts.diff_summary` | string | yes | Summary of changes (files, insertions, deletions) |
| `artifacts.test_output` | string | yes | Test execution results for changed files |
| `artifacts.coverage` | string | yes | Code coverage percentage for changed files |
| `artifacts.documentation` | array of strings | yes | Paths to design docs, journals, and other deliverables |
| `rubric` | object or null | no | Domain-specific rubric if applicable (see Domain-Specific Rubrics) |
| `previous_verdict` | object or null | no | Previous verdict JSON if this is a resubmission |
| `resubmission_diff` | string or null | no | Diff since the last verification if this is a resubmission |

## Output Schema (Verdict)

The sub-agent MUST return this JSON structure as a fenced code block:

```json
{
  "item_id": "PROJ-123",
  "verdict": "PASS",
  "timestamp": "2026-03-21T14:30:00Z",
  "criteria_results": [
    {
      "ac_id": "AC-1",
      "verdict": "PASS",
      "confidence": "high",
      "evidence": "src/auth/login.ts:23-31 implements email regex validation. src/auth/login.test.ts:45-67 tests valid/invalid email formats including edge cases.",
      "remediation": null,
      "notes": null
    },
    {
      "ac_id": "AC-2",
      "verdict": "FAIL",
      "confidence": "high",
      "evidence": "src/auth/login.ts:35-40 checks minimum length but does not enforce mixed case requirement.",
      "remediation": "Add uppercase/lowercase character check to password validation in src/auth/login.ts:35-40. Update test cases in src/auth/login.test.ts to cover mixed case scenarios.",
      "notes": null
    }
  ],
  "summary": {
    "total_ac": 2,
    "passed": 1,
    "failed": 1,
    "skipped": 0
  }
}
```

### Output Field Definitions

| Field | Type | Values | Description |
|-------|------|--------|-------------|
| `item_id` | string | -- | Echoed from input |
| `verdict` | string | `"PASS"`, `"FAIL"` | Overall verdict (see Verdict Rules) |
| `timestamp` | string (ISO 8601) | -- | When the evaluation completed |
| `criteria_results` | array | -- | One entry per acceptance criterion |
| `criteria_results[].ac_id` | string | -- | Acceptance criterion identifier, matches input `acceptance_criteria[].id` |
| `criteria_results[].verdict` | string | `"PASS"`, `"FAIL"`, `"SKIP"` | Individual criterion verdict |
| `criteria_results[].confidence` | string | `"high"`, `"medium"`, `"low"` | Certainty level (see below) |
| `criteria_results[].evidence` | string | -- | Specific file:line references and reasoning |
| `criteria_results[].remediation` | string or null | -- | Actionable fix instruction if `FAIL`; null if `PASS`/`SKIP` |
| `criteria_results[].notes` | string or null | -- | Optional context (e.g., assumptions, scope limitations) |
| `summary.total_ac` | number | -- | Total acceptance criteria evaluated |
| `summary.passed` | number | -- | Count of `PASS` verdicts |
| `summary.failed` | number | -- | Count of `FAIL` verdicts |
| `summary.skipped` | number | -- | Count of `SKIP` verdicts |

### Confidence Levels

| Level | Meaning | When Used |
|-------|---------|-----------|
| `high` | Clear, direct evidence in artifacts | File and line number directly implement the criterion |
| `medium` | Evidence inferred from context | Implementation appears correct but no direct test or the test is indirect |
| `low` | Insufficient information to be certain | Artifacts are ambiguous or the criterion requires runtime verification |

### Verdict Rules

- Overall `verdict` is `PASS` only if ALL criteria are `PASS` or `SKIP`
- Any single `FAIL` makes the overall verdict `FAIL`
- `SKIP` is valid only when a criterion is not applicable to the current scope (e.g., a UI criterion on a backend-only change). The sub-agent MUST explain why in `notes`.
- `criteria_results` MUST contain exactly one entry per `acceptance_criteria` input entry, plus any rubric criteria if a rubric is active

---

## Diff-Aware Re-Verification

When `previous_verdict` and `resubmission_diff` are both non-null, the sub-agent performs an optimized re-evaluation:

### Procedure

1. Parse `previous_verdict.criteria_results` to identify which AC were `FAIL`
2. Parse `resubmission_diff` to identify which files changed since the last evaluation
3. Build the re-evaluation set:
   - **Always re-check**: All previously `FAIL` criteria (regardless of which files changed)
   - **Re-check if touched**: Any previously `PASS` criteria whose relevant files appear in the resubmission diff
   - **Carry forward**: Previously `PASS` criteria whose relevant files are NOT in the resubmission diff
4. For carried-forward criteria: copy the previous result but set `confidence` to `"high (carried forward)"`
5. Return a **complete** verdict containing all AC (not just re-evaluated ones)

### Rationale

This optimization reduces token usage on large re-verifications. A work item with 10 AC where only 2 failed does not need to re-read and re-evaluate all 10 from scratch -- only the 2 failures plus any criteria whose implementation files were touched during the fix.

---

## Domain-Specific Rubrics

When `process_enforcement.verification.rubrics` defines domain rubrics in the customer config:

```yaml
process_enforcement:
  verification:
    rubrics:
      firmware:
        criteria:
          - "All register accesses use volatile pointers"
          - "ISR handlers have bounded execution time"
          - "No heap allocation in interrupt context"
      documentation:
        criteria:
          - "All public APIs have usage examples"
          - "Error codes are documented with recovery steps"
      security:
        criteria:
          - "No secrets or credentials in source files"
          - "All user input is validated before use"
          - "SQL queries use parameterized statements"
```

### Rubric Injection Procedure

1. Read the work item's labels/tags from the tracker
2. For each label, check if it matches a key in `process_enforcement.verification.rubrics` (case-insensitive)
3. If matched, inject the rubric criteria into the sub-agent system prompt:
   ```
   ## Domain Rubric: {rubric_name}
   In addition to the acceptance criteria, evaluate these domain-specific requirements:
   {formatted_criteria_list}
   Include each rubric criterion in your criteria_results with ac_id format "RUBRIC-{rubric_name}-{N}".
   ```
4. Pass the rubric object in the input schema's `rubric` field
5. The sub-agent evaluates rubric criteria alongside AC and includes them in `criteria_results`
6. Rubric criteria follow the same verdict rules -- a `FAIL` on any rubric criterion makes the overall verdict `FAIL`

---

## Invocation Pattern

The orchestrator invokes the sub-agent using Claude Code's Agent tool, following the same pattern as `/pr` review subagents (see `pr/references/subagent-invocation.md`).

### Subagent Configuration

| Property | Value | Rationale |
|----------|-------|-----------|
| Type | `Explore` | Verification is read-only; the sub-agent must not modify files |
| Parallelism | Sequential (single agent) | Verification must produce a single coherent verdict |
| Tool access | Read-only (file reads, searches) | Enforces the no-modification constraint |

### Invocation Template

```
Agent tool call:
  type: Explore
  prompt: |
    {system_prompt}

    ## Work Item
    {item_id}: {item_title}

    ## Acceptance Criteria
    {formatted_ac_list}

    ## Artifacts to Evaluate
    Changed files: {changed_files}
    Diff summary: {diff_summary}
    Test output: {test_output}
    Coverage: {coverage}
    Documentation: {documentation}

    ## Domain Rubric
    {rubric_section or "No domain rubric applies to this work item."}

    ## Previous Verdict (if resubmission)
    {previous_verdict_json or "N/A -- first evaluation"}

    ## Changes Since Last Evaluation
    {resubmission_diff or "N/A -- first evaluation"}

    ## Instructions
    1. Read each changed file listed above.
    2. For each acceptance criterion, locate the implementation and test evidence.
    3. Evaluate whether the artifacts satisfy the criterion.
    4. If a domain rubric is active, evaluate those criteria as well.
    5. If this is a resubmission, follow the diff-aware re-verification procedure.
    6. Return your verdict as a single JSON code block using the output schema.
```

### Error Handling

| Scenario | Behavior |
|----------|----------|
| Sub-agent returns malformed JSON | Treat as `FAIL` with `remediation`: "Verification sub-agent returned invalid output. Re-run `/orchestrate complete`." |
| Sub-agent times out | Treat as `FAIL` with `remediation`: "Verification timed out. Simplify the change scope or re-run." |
| Sub-agent cannot read a changed file | Include in verdict with `confidence: "low"` and `notes` explaining the read failure |
| No acceptance criteria on work item | Skip Tier 2 entirely; log a warning: "No acceptance criteria found for {item_id}. Tier 2 verification skipped." |

---

## Integration with Enforcement Engine

After the sub-agent returns its verdict, the orchestrator integrates the result into the enforcement evaluation (step 8 of the algorithm in `_shared/references/enforcement.md`).

### On FAIL

Add a `TIER2_VERIFICATION_FAILED` condition to the rejection object:

```json
{
  "code": "TIER2_VERIFICATION_FAILED",
  "condition": "tier2_verification",
  "severity": "block",
  "detail": "Tier 2 verification found {failed_count} issues: {failed_ac_ids}. Review the verdict and address each gap before proceeding.",
  "remediation": "Address the following gaps:\n{remediation_list}\nThen re-run `/orchestrate complete {item_id}`.",
  "retry_policy": "after-fix"
}
```

Where:
- `{failed_count}` = `summary.failed` from the verdict
- `{failed_ac_ids}` = comma-separated list of `ac_id` values with `FAIL` verdict
- `{remediation_list}` = numbered list of each failed criterion's `remediation` field

### On PASS

Add to `passed_conditions`:

```json
{
  "code": "TIER2_VERIFICATION_PASSED",
  "condition": "tier2_verification",
  "detail": "Tier 2 verification passed. All {total_ac} acceptance criteria satisfied."
}
```

Proceed with remaining G4 evaluation.

---

## Session State Integration

After the sub-agent returns, the orchestrator writes to `session-state.json` under the `orchestrator` namespace:

| Field | Type | Description |
|-------|------|-------------|
| `orchestrator.itemStates[id].lastVerificationVerdict` | object | The full verdict JSON returned by the sub-agent |
| `orchestrator.itemStates[id].lastVerifiedCommit` | string | Git HEAD SHA at the time of verification |
| `orchestrator.itemStates[id].tier2Status` | string | `"pass"` or `"fail"` |

### Staleness Detection

On subsequent `/orchestrate complete` calls, before invoking a new sub-agent:

1. Read `orchestrator.itemStates[id].lastVerifiedCommit`
2. Compare to current `git rev-parse HEAD`
3. If they match AND `tier2Status` is `"pass"`: skip Tier 2 (already verified at this commit)
4. If they differ: invoke the sub-agent with `previous_verdict` set to `lastVerificationVerdict` and `resubmission_diff` set to the diff between the two SHAs

This prevents redundant verification when no code has changed and enables diff-aware re-verification when code has changed.
