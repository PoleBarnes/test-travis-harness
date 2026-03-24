---
name: pr
description: Create PRs, review existing PRs, or triage your PR queue with security and test checks. Trigger on "create PR", "review PR", "check my PRs".
argument-hint: [PR-number | target-branch | PROJ-123]
---

# travis Harness — Pull Request Workflow

You are the orchestrator. Follow this workflow to handle PR-related work by delegating to review subagents.

## Input

**$ARGUMENTS**

## Current Context

- Branch: !`git branch --show-current`
- Status: !`git status --short`
- Recent commits: !`git log --oneline -5`
- Merge base with main: !`git merge-base HEAD main 2>/dev/null || echo "unknown"`

## Working Context

Read `.harness/working-context.md` if it exists. Use the "Active Work" section to correlate this PR with the current task and enrich the PR description with context (e.g., which work item is being implemented, recent decisions that informed the approach).

For full format details, see `references/working-context.md` in the `_shared` skill directory.

This skill reads: Active Work, Recent Decisions

## Instructions

### Step 1: Determine Mode

Parse `$ARGUMENTS` to determine the operating mode:

**Mode A: No arguments (smart triage)**
If `$ARGUMENTS` is empty, enter **triage mode** (see Step 2).

**Mode B: PR number** (e.g., `42`, `#42`)
1. Strip any leading `#` character
2. Enter **review mode** — review the existing PR (see Step 4)


**Mode C: GitHub PR URL** (e.g., `https://github.com/org/repo/pull/42`)
1. Extract owner, repository, and PR number from the URL
2. Enter **review mode** — review the existing PR (see Step 4)


**Mode D: Branch name** (e.g., `main`, `develop`)
1. Validate the branch exists: `git rev-parse --verify <branch>`
2. If not found, show available branches and stop
3. Enter **create mode** with explicit target branch (see Step 5)

**Mode E: Work item ID** (matches `[A-Z]+-\d+`, e.g., `TH-123`)
1. Use the **fetch_item** operation (see `_shared/references/tracker-operations.md`) to fetch the work item for V&V traceability and PR description enrichment
2. Enter **create mode** — prepare and create a PR, linking the work item (see Step 5)

**Mode F: Branch name + work item ID** (e.g., `main TH-123`)
1. Use the branch as the explicit target and the work item for V&V/description
2. Enter **create mode** (see Step 5)

**If the current branch is `main` and no PR number was given**:
1. Display: "Error: /pr must be run from a feature branch when creating a PR. Use `/pr 42` to review an existing PR."
2. **Stop here**

---

### Step 2: Triage Mode (no arguments)

When no arguments are provided, analyze context to determine the most useful action and propose it as the default. The goal is to keep the user in productive flow — one Enter press to proceed.


**Context gathering** (delegate an Explore subagent to check via the github MCP server):

1. Detect current branch name and whether it's a feature branch (`feature/*`, `fix/*`) or major branch (`main`, `develop`, `release/*`)
2. If on a feature branch: check for commits ahead of parent, check if an open PR already exists for this branch
3. Query open PRs where the current user is assigned as a reviewer
4. Query open PRs authored by the current user

**Decision logic** (first match wins):

#### Case 1: On a feature branch, no open PR, commits ahead of parent

The user has been coding and wants to ship. **Default action: create a new PR.**

```
## Create PR for this branch?

Branch `feature/TH-42-login-validation` has 5 commits ahead of `main`.
No open PR exists for this branch.

[Enter] Create PR targeting `main` (review team + fix loop + create)
[w]     Create PR and link work item TH-42 (detected from branch name)
[n]     Don't create — show other PR work instead
```

If the user confirms (Enter), proceed to **create mode** (Step 5). If work item ID is detected from the branch name (`feature/TH-42-*`), automatically link it.

#### Case 2: On a feature branch, open PR already exists

```
## Your PR for this branch

PR #45 — Refactor auth module
Status: Changes requested (2 comments to address)
Branch: feature/TH-45 -> main | Created: 2d ago

[Enter] Review PR #45 (address feedback, re-review with team)
[n]     Don't review — show other PR work instead
```

If the user confirms, proceed to **review mode** (Step 4).

#### Case 3: On a major branch (main, develop, release/*)

Creating a PR doesn't make sense here. Show PR work to review. Closing PRs is higher priority than starting new work because it unblocks teammates. **Default action: review the highest-priority assigned PR.**

If assigned PRs exist:

```
## PRs Awaiting Your Review

| # | PR | Author | Age | Files |
|---|-----|--------|-----|-------|
| 1 | #42 — Add login validation | @teammate | 3d | 8 files |
| 2 | #39 — Fix calendar sync | @teammate | 1d | 3 files |

[Enter] Review PR #42 (oldest, highest priority)
[2]     Review PR #39 instead
[n]     Skip — show my open PRs
```

If no assigned PRs but own open PRs exist, show those instead with an option to review/address feedback.

#### Case 4: Nothing actionable

```
## No PR Work Pending

Suggestions:
> `/pm` to find your next task
> `/implement TH-123` to start working on a task
```

---

### Step 3: Pre-flight Checks (create mode only)

Before spawning the review team, verify:

| Check | Action if Failed |
|-------|-----------------|
| Uncommitted changes exist | Warn the user; offer to commit, stash, or abort |
| Branch not pushed to remote | Push the branch: `git push -u origin <branch>` (with user confirmation) |
| Current branch is `main` | Error: "/pr must be run from a feature branch" — stop |
| No commits ahead of target | Error: "No changes to create a PR for" — stop |
| Target branch doesn't exist | Show available branches, ask user to specify |

---

### Step 4: Review Mode (existing PR)


1. Delegate an **Explore subagent** to fetch via the github MCP server:

   - PR metadata: title, description, author, source/target branch, status
   - PR diff: full change set
   - PR comments: existing review comments
   - Linked work item (from PR title/description pattern `TH-\d+`)

2. Spawn the **review team** in parallel (see Step 6)

3. Display the review:

```
## Review: PR #42 — Add login validation

**Author**: @teammate | **Branch**: feature/TH-42 -> main
**Verdict**: APPROVE / REQUEST CHANGES

### Security: [PASS / ISSUES FOUND]
### Test Coverage: [ADEQUATE / GAPS FOUND]
### Standards: [COMPLIANT / ISSUES FOUND]
### V&V Traceability: [VERIFIED / SKIPPED]

### Blocking Issues (N)
1. [Issue with file reference and proposed fix]

### Suggestions (N)
1. [Suggestion with rationale]

### Positive Notes
- [What was done well]
```

**Merge detection**: If the PR is found to be merged:
- Check if the linked work item is still in "In Review" state
- If yes, prompt: "PR #[N] is merged. Move [ID] to Done? [Enter to confirm / n to skip]"
- If confirmed: update tracker to "Done" via **update_status** (see `_shared/references/tracker-operations.md`), update session-state.json `orchestrator.itemStates.[ID].abstractState` = "done"

---

### Output Verification Gate

If process enforcement is enabled and a work item is linked to this PR:

1. **Role check**: If `process_enforcement.roles` is configured, resolve the current user's role per `enforcement.md` (RBAC → Role Resolution). Check the permission matrix for the `in-progress → in-review` transition. If the role is not permitted, include `G3_ROLE_FORBIDDEN` in the rejection. If `process_enforcement.roles` is absent, skip this check (all roles permitted).

2. **Determine proportionality tier** for the linked work item (auto-detect from scope, or read from session-state.json `orchestrator.itemStates`)

3. **Check required deliverables** per tier:
   - **Minimal**: Linter report exists, unit test results exist, regression test results exist
   - **Standard**: Minimal + SDD in `doc/design/`, code coverage report, V&V audit report
   - **Comprehensive**: Standard + diagrams in `doc/diagrams/`, engineering journal in `doc/journal/`

4. **Report results**:
   | Deliverable | Required | Status |
   |-------------|----------|--------|
   [List each with PRESENT/MISSING]

5. **Structured rejection**: When any condition in steps 1–4 fails (role forbidden, or required deliverables missing), produce a rejection object per `enforcement.md` (Structured Rejection Schema). Each missing deliverable generates a `G3_MISSING_DELIVERABLES` condition with specific file paths in the `remediation` field (e.g., "Missing: SDD in doc/design/, V&V audit report. Produce required deliverables before review."). A forbidden role generates `G3_ROLE_FORBIDDEN`. Store the complete rejection object in `session-state.json` at `orchestrator.itemStates[id].lastGateResult`. Act on the result per `enforcement.md` (Enforcement Evaluation Algorithm, Step 10):
   - **mode: block**: "BLOCKED: [N] conditions failed. Resolve before creating PR." — halt the workflow.
   - **mode: warn**: "WARNING: [N] conditions failed. Continue anyway? [Enter/n]" — proceed only if user confirms.

---

### Step 5: Create Mode (new PR from current branch)

1. **Detect target branch** (if not explicitly provided):
   - Try `git config branch.<current>.merge` for upstream tracking
   - Fall back to `git merge-base --fork-point main HEAD`
   - Default to `main` if it exists

2. Run **pre-flight checks** (Step 3)

3. Spawn the **review team** in parallel (see Step 6)

4. For each **blocking** issue:
   - Present the issue with file reference and proposed fix
   - Ask user: "Apply this fix? [y/n/skip all]"
   - If confirmed, spawn a general-purpose subagent to apply the fix
   - If declined, note in PR description as known item

5. If fixes were applied, re-run affected review checks

6. Generate PR description:

```
## Summary
[1-3 sentences synthesized from commits and review findings]

## Work Item
[TH-NNN: Work item title](link) (if linked)

## Changes
- [File/module 1]: [What changed and why]
- [File/module 2]: [What changed and why]

## Review Summary
- Security: [PASS]
- Test Coverage: [ADEQUATE]
- Standards: [COMPLIANT]
- V&V Traceability: [VERIFIED / SKIPPED]

## Suggestions (non-blocking)
- [Suggestion from review team]
```

7. Create PR via the **github** MCP server
8. Link the PR to the work item using the **link_artifact** operation (see `_shared/references/tracker-operations.md`) — attach the PR URL to the work item for traceability

**State transition**: If process enforcement is enabled with auto_state_transitions:
- Update work item to "In Review" state using **update_status** operation (see `_shared/references/tracker-operations.md`)
- Link the PR to the work item using **link_artifact** operation (URL: the PR URL, type: "pull-request")
- Update session-state.json: `orchestrator.itemStates.[ID].abstractState` = "in-review", `prNumber` = PR number
- Confirm: "Moved [ID] to In Review and linked PR #[N]."

---

### Step 6: Review Team

Spawn these subagents **in parallel** for maximum throughput. Each subagent receives the full diff (or PR diff), the list of changed files, and the work item context (if available).

#### Code Reviewer (general-purpose subagent)

Run all of the following checks against every changed file:

**Security — OWASP Top 10**:
- Injection (SQL, command, LDAP, XPath) — parameterized queries, no string concatenation
- Authentication/authorization — proper checks on every endpoint, no hardcoded creds
- Sensitive data exposure — no secrets in code, proper encryption at rest/in transit
- Input validation — whitelist validation, length limits, type checks on all inputs
- Known-vulnerable dependencies — check lockfiles for flagged packages
- Security misconfiguration — no debug flags in production, proper CORS/CSP headers

**Test Coverage**:
- Every new/changed function or method has corresponding test(s)
- Acceptance criteria from the work item are covered by tests
- Edge cases addressed: nulls, empty inputs, boundary values, error paths

**Standards Compliance**:
- Naming conventions match existing codebase patterns
- Error handling is consistent (no swallowed exceptions, proper logging)
- Git hygiene: no merge commits, no large binaries, commit messages follow conventions
- No commented-out code or TODO items without tracking IDs

**Code Quality**:
- Logic errors, off-by-one mistakes, incorrect boolean logic
- Race conditions or concurrency issues
- Resource leaks (unclosed handles, missing cleanup)
- Unnecessary complexity (functions > 50 lines, deep nesting > 3 levels)
- Dead code or unreachable branches

**Feedback format**: Each finding must use one of these tags:
- `[BLOCKING] file:LINE — description + proposed fix` — must be fixed before merge
- `[SUGGESTION] file:LINE — description + rationale` — optional improvement
- `[QUESTION] file:LINE — description` — needs clarification from author
- `[PRAISE] file:LINE — description` — highlight good patterns

#### Test Auditor (Explore subagent)

- Map every changed file to its corresponding test file(s)
- Flag changed files with no test coverage
- Flag untested public methods/functions in changed files
- Verify the test suite passes

#### V&V Engineer (general-purpose subagent) — only if work item linked

- Extract the requirement ID from the linked work item
- Trace: requirement ID -> implementation file(s) -> test file(s)
- Verify each acceptance criterion has at least one test that exercises it
- Report coverage matrix and gaps:
  ```
  | AC # | Acceptance Criterion | Impl File(s) | Test File(s) | Status |
  |------|---------------------|--------------|-------------|--------|
  | 1    | ...                 | ...          | ...         | COVERED / GAP |
  ```

---

### Error Handling

**github MCP unavailable**:
- Triage mode: skip PR queries, fall back to branch analysis only
- Review mode: cannot fetch PR details — ask user to provide branch name instead
- Create mode: PR created via git commands; work item linking skipped

**Not on a feature branch (create mode)**: Display error and suggest creating a feature branch first.

**No commits on branch (create mode)**: Display: "No changes to create a PR for."

**PR not found (review mode)**: Display: "PR #[number] not found. Check the PR number and try again."

**Review finds unfixable blocking issues**: Present issues with file references and suggested manual fixes. Ask if user wants to create PR anyway (noting issues in description) or abort.
