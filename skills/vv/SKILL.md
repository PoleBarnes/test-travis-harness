---
name: vv
description: Audit test coverage gaps, requirement traceability, documentation deliverables, and implementation completeness. Use when checking test coverage, auditing requirements, verifying documentation is complete, running a traceability check, or asking "what requirements are untested" or "are all doc deliverables present". This is the quality gate that validates work before it ships.
argument-hint: [scope or area]
---

# Verification & Validation Audit

Audit how well requirements are implemented and tested in the travis Harness. This traces each requirement to its implementation files and test files, identifying gaps where coverage is missing.

## Scope

**$ARGUMENTS**

## Current State

- Branch: !`git branch --show-current`
- Requirements file: !`wc -l doc/requirements.md 2>/dev/null | awk '{print $1 " lines"}' || echo "not found"`
- Skill count: !`ls -d skills/*/SKILL.md 2>/dev/null | wc -l | tr -d ' '`
- Test count: !`ls test/*.sh 2>/dev/null | wc -l | tr -d ' '`

## Working Context

Read `.harness/working-context.md` if it exists. Use "Recent Decisions" to cross-reference against implemented changes — flag if any implementation contradicts a recorded decision. This adds a design-intent validation layer on top of the standard requirement traceability check.

For full format details, see `references/working-context.md` in the `_shared` skill directory.

This skill reads: Recent Decisions

## Instructions

### Step 1: Determine Scope

Parse `$ARGUMENTS` to determine what to audit:

- **"full"** or **no arguments**: Audit all requirements in `doc/requirements.md` — build complete traceability matrix
- **"skills"**: Audit only `REQ-travis-SKL-*` requirements against `skills/*/SKILL.md` implementations
- **"mcp"**: Audit only `REQ-travis-MCP-*` requirements against `.mcp.json` configuration
- **"plugin"**: Audit only `REQ-travis-PLG-*` requirements against `.claude-plugin/plugin.json`
- **"tests"**: Audit only `REQ-travis-TST-*` requirements against `test/**` files
- **A specific REQ ID pattern** (e.g., `REQ-travis-SKL-001`): Audit that single requirement in depth
- **A work item ID** (e.g., `TH-123`): Use the **fetch_item** operation (see `_shared/references/tracker-operations.md`) to look up the work item, extract its requirement reference, and audit that requirement

### Step 2: Perform V&V Analysis

Execute the following verification and validation workflow:

#### 2a. Scope — Identify Requirements

- Read `doc/requirements.md` and extract all requirement IDs matching the determined scope
- Parse each requirement's description, acceptance criteria, and any linked implementation notes

#### 2b. Trace — Build Traceability Chain

For each requirement, build the traceability chain:

**Requirement ID → Implementation File(s) → Test File(s)**

- Search `skills/*/SKILL.md` files for references to the requirement ID
- Search source files for implementation of the requirement's specification
- Search `test/**` files for test cases referencing the requirement ID
- Record which links in the chain are present and which are missing

#### 2c. Verify — Check Implementation Completeness

For each requirement:

- Confirm at least one implementation file exists
- Verify the implementation matches the requirement specification (not just a reference to the ID)
- Check that the implementation covers all aspects described in the requirement

#### 2d. Audit — Documentation Deliverables

Verify all required documentation deliverables exist based on the proportionality tier:

| Deliverable | Required For | Check |
|-------------|-------------|-------|
| Software Design Document | Standard, Comprehensive | Exists in `doc/design/` and describes this change |
| Linter Report | All tiers | Clean run attached (zero violations or documented exceptions) |
| Code Coverage Analysis | Standard, Comprehensive | Percentage reported and meets project threshold |
| Unit Test Results | All tiers | Passing results for all new/modified code |
| Regression Test Results | All tiers | Passing results confirming no regressions |
| V&V Audit Report | Standard, Comprehensive | This report itself |
| Diagrams | Comprehensive | Visual diagrams in `doc/diagrams/` using Mermaid/PlantUML/ASCII |
| Engineering Journal | Comprehensive | Running record in `doc/journal/YYYY-MM-DD-<work-item-id>.md` |

**Tier determination** (same as `/implement`):
- Bug fixes, small refactors, config changes (<50 lines) → **Minimal**
- Features, medium tasks, integrations (50-300 lines) → **Standard**
- Architecture changes, security-sensitive work, new skills (>300 lines) → **Comprehensive**
- Component sensitivity (security, auth, data handling) → always **Comprehensive**
- Use the **highest** applicable tier

Flag any missing deliverables as:
- **CRITICAL** if required for the determined tier
- **RECOMMENDED** if in a higher tier but would add value

The documentation audit matters because these artifacts are the audit trail — when a compliance review or incident investigation happens months later, these deliverables are what proves the work was done correctly. Missing docs now means unverifiable claims later.

#### 2e. Validate — Acceptance Criteria Quality & Coverage

For each acceptance criterion, confirm it is:

1. **Testable** — Can be verified by an automated or manual test
2. **Specific** — Describes a concrete, unambiguous behavior
3. **Measurable** — Has a clear pass/fail condition
4. **Independent** — Can be tested without relying on other AC
5. **Binary** — Result is definitively PASS or FAIL, not subjective

Then check each AC against test files:

- Is there a test case that exercises this AC?
- Does the test pass?
- Does the test actually validate the AC (not just reference it)?

#### 2f. Report — Structured Audit Report

Compile findings into the structured report format (see Step 3).

### Step 3: Present Results

Display the audit report to the user, including:

```
## V&V Report
**Scope**: [scope description]

### Traceability Matrix
| Requirement | Implementation | Test | AC Coverage | Status |
|-------------|---------------|------|-------------|--------|
| REQ-travis-... | [file] | [test] | N/N AC | PASS/GAP |

### Acceptance Criteria Quality
| Requirement | AC # | Testable | Specific | Measurable | Independent | Binary | Quality |
|-------------|------|----------|----------|------------|-------------|--------|---------|
| REQ-... | AC-1 | ✓/✗ | ✓/✗ | ✓/✗ | ✓/✗ | ✓/✗ | PASS/WARN |

### Coverage Gap Analysis
[List each gap with severity and recommended action]

#### Severity Levels
- **CRITICAL**: No implementation exists for a requirement
- **HIGH**: Implementation exists but no test coverage
- **MEDIUM**: Partial acceptance criteria coverage (some AC tested, others not)
- **LOW**: Orphaned code with no traceability to any requirement

### Documentation Deliverables
| Deliverable | Status | Notes |
|-------------|--------|-------|
| Software Design Document | PRESENT/MISSING/N/A | [location or reason] |
| Linter Report | PRESENT/MISSING | [zero violations / N exceptions] |
| Code Coverage Analysis | PRESENT/MISSING/N/A | [N% — meets/below threshold] |
| Unit Test Results | PRESENT/MISSING | [N passed, N failed] |
| Regression Test Results | PRESENT/MISSING | [N passed, N regressions] |
| V&V Audit Report | PRESENT | [this report] |
| Diagrams | PRESENT/MISSING/N/A | [list each or reason] |
| Engineering Journal | PRESENT/MISSING/N/A | [file path or reason] |
| **Proportionality Tier** | [MINIMAL/STANDARD/COMPREHENSIVE] | [rationale] |

### Summary
- Total requirements: [N]
- Fully covered: [N] ([%])
- Gaps found: [N] ([%])
- AC quality warnings: [N]
- Documentation deliverables: [N/M] present

### Recommendations
1. [Highest priority action]
```

### Attach Report to Tracker

If process enforcement is enabled (see `references/process-gates.md`) and a work item ID was provided or detected from the working context:

1. Add a comment to the work item with the V&V summary using the **link_artifact** operation (see `references/tracker-operations.md`):
   - Include: total requirements, coverage %, gaps found, AC warnings
   - Include: the verdict (PASS / FAIL with gap count)
2. Update session-state.json (see `references/session-state.md`):
   - Set `orchestrator.itemStates.[ID].vvStatus` to `"pass"` or `"fail"`
   - Add `"vv"` to `orchestrator.itemStates.[ID].gatesPassed` array (create the array if it does not exist)
   - Set `lastUpdated` to the current ISO 8601 timestamp and `version` to `"1.0"`
3. Suggest next step based on result:
   - If V&V passes: "V&V audit attached to [ID]. Run `/orchestrate complete [ID]` to close the item."
   - If V&V fails: "V&V audit attached to [ID] with [N] gaps. Address gaps before closing."

### Machine-Readable Gate Marker

At the end of the V&V report output, append a hidden marker for gate consumption:

`<!-- GATE: vv_passed=[true|false] tier=[minimal|standard|comprehensive] gaps=[N] -->`

This marker allows downstream skills (e.g., `/orchestrate`) to programmatically detect V&V status without re-parsing the full report.

### Error Handling

**Requirements file not found**:
- Report that `doc/requirements.md` is missing
- This is a critical issue — the audit cannot proceed without the requirements document

**Tracker MCP unavailable** (when a work item ID is provided as scope):
- Report the connection issue — see `_shared/references/tracker-operations.md` Error Handling for degraded-mode behavior
- Suggest providing the requirement ID directly instead (e.g., `/vv REQ-travis-SKL-001`)

**Partial results**:
- If some files cannot be read, report partial results with a note about what was skipped
- Every gap should be reported explicitly — silent skips hide real coverage problems
