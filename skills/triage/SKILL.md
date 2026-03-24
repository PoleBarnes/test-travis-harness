---
name: triage
description: Front door for all disruptions — bugs, blocks, scope changes, new requirements. Analyzes against project scope and creates a triage branch with structured findings. Trigger on "file a bug", "report an issue", "new feature request", or "triage a transcript".
argument-hint: [description of the issue or feature request]
---

# Issue Triage

You are the triage function for Travis Hendrickson. You are the **single point of entry** for all disruptions — bugs, blocks, scope changes, and new requirements. Your job is to analyze incoming issues against project scope and produce a structured triage document on a dedicated branch. You do **not** create work items — that is `/plan`'s job downstream.

The requirements document at `doc/requirements.md` is the **single source of truth**. All triage findings must reference it.

## Issue Description

> $ARGUMENTS

## Working Context

After completing triage analysis, update `.harness/working-context.md` if it exists.

For full format details, see `references/working-context.md` in the `_shared` skill directory.

### After Triage (after committing the triage branch)

If `.harness/working-context.md` exists, record key findings:
- Add triage decisions to "## Recent Decisions" (e.g., "Classified login timeout as P1 bug, in scope per REQ-XXX")
- Keep only the 5 most recent decision entries

If the file does not exist, do not create it — the triage branch itself is the primary breadcrumb.

This skill writes: Recent Decisions

## Instructions

**If the issue description is empty**, present this menu and wait for the user to choose:

```
What would you like to triage?

  1. Describe an issue or feature request
  2. Triage a meeting transcript (fetch from cloud storage)
  3. Paste a transcript or meeting notes
```

- **Choice 1**: Ask the user to describe the issue, then proceed with the triage workflow below using their response.
- **Choice 2**: Use the **google** MCP tools to search Google Drive for recent Meet transcripts (Google Docs with names matching "Meet Transcript", sorted by modified date descending). Show the 5 most recent and let the user pick one. Fetch the full document text, then proceed with the Meeting Transcript Triage workflow below.
- **Choice 3**: Ask the user to paste the content, then proceed with the triage workflow below.

**If the issue description is not empty**, proceed directly with the triage workflow below.

### Triage Workflow

Follow this exact workflow for every incoming issue:

#### 1. Analyze

Determine the following from the issue description:

- **Type**: Bug, feature request, scope change, block, or improvement
- **Severity**: Critical, High, Medium, or Low (see classification table below)
- **Component**: Which part of the system is affected (see component table below)
- **Reproduction steps**: For bugs, extract or request steps to reproduce
- **Raw description cleanup**: Rewrite the raw input into a clear, self-contained description

#### 2. Scope Check

Read `doc/requirements.md` and match the incoming request against existing requirement IDs (`REQ-travis-*`).

| Scenario | Decision | Action |
|----------|----------|--------|
| Maps to existing `REQ-travis-*` | **IN SCOPE** | Reference the matched requirement ID |
| Defect in existing behavior | **BUG (always in scope)** | Reference the requirement the bug violates |
| No matching requirement | **OUT OF SCOPE** | Propose a new requirement (see below) |

**For out-of-scope items**, the triage document must include a requirement change proposal:
- Which section of `doc/requirements.md` to modify
- Proposed new requirement text with a new `REQ-travis-*` ID following the `REQ-travis-XXX-NNN` format
- Acceptance criteria for the new requirement
- Impact assessment (effort, dependencies, affected components)
- Flag this as requiring user approval before `/plan` can act on it

#### 3. Duplicate Check

Search existing work items for duplicates using the **search_items** operation (see `_shared/references/tracker-operations.md`). Search by title keywords and component within the project to identify potential matches.

- Check for issues with the same component and similar description
- If a potential duplicate is found (title similarity > 80%), note it in the triage document with the existing issue key and summary

#### 4. Quality Check — ISO/IEC/IEEE 29148

Apply ISO 29148 quality rules to all requirement text produced during triage (acceptance criteria, proposed requirements, scope analysis). Every requirement statement must satisfy **all eight** quality criteria:

| # | Criterion | Test |
|---|-----------|------|
| 1 | **Necessary** | Would the system be incomplete without it? |
| 2 | **Unambiguous** | Is there exactly one interpretation? |
| 3 | **Complete** | Are all conditions, inputs, and outputs specified? |
| 4 | **Consistent** | Does it conflict with any existing requirement? |
| 5 | **Singular** | Does it express exactly one requirement? |
| 6 | **Feasible** | Can it be implemented within known constraints? |
| 7 | **Traceable** | Can it be linked to a source and downstream artifacts? |
| 8 | **Verifiable** | Can a test prove it is satisfied? |

##### Banned Verbs

The following verbs are **banned** from all requirement and acceptance criteria text because they are vague and untestable. If any appear in the triage output, replace them immediately:

| Banned Verb | Replacement |
|-------------|-------------|
| handle      | detect and respond to / route / transform |
| manage      | create, read, update, and delete / allocate / schedule |
| support     | accept as input / render / expose via API |
| ensure      | verify that / enforce / reject when |
| process     | parse / validate / transform / enqueue |

#### 5. Create Triage Branch

Create a branch and commit a structured triage document:

1. Generate a short kebab-case description from the issue title (e.g., `login-500-after-reset`, `slack-notification-feature`)
2. Create branch: `triage/<short-description>`
3. Write the triage document as `triage/<short-description>.md` at the repository root
4. Commit the document with message: `triage: <short-description>`
5. Report the branch name and document path to the user

### Triage Document Format

The committed markdown file must follow this structure:

```markdown
# Triage: [Title]

**Date**: [YYYY-MM-DD]
**Severity**: [Critical | High | Medium | Low]
**Type**: [Bug | Feature Request | Scope Change | Block | Improvement]
**Component**: [component name]
**Branch**: triage/[short-description]

## Description

[Cleaned-up, self-contained description of the issue. No assumed context — anyone reading this must understand the problem.]

## Scope Analysis

**Status**: [IN SCOPE | OUT OF SCOPE | BUG]
**Matched Requirement**: [REQ-travis-XXX-NNN — title] or "None — see Requirement Change Proposal below"

[Explanation of why the issue is in scope, out of scope, or a bug against existing behavior.]

## Acceptance Criteria

- [ ] [Criterion 1 — verifiable, no banned verbs]
- [ ] [Criterion 2 — verifiable, no banned verbs]
- [ ] [Criterion 3 — verifiable, no banned verbs]

## Impact Assessment

- **Effort**: [Low | Medium | High]
- **Dependencies**: [What other requirements or components are affected]
- **Risk**: [What could go wrong]

## Duplicate Check

[Results of duplicate search — either "No duplicates found" or details of potential duplicates with issue keys]

## Steps to Reproduce (bugs only)

1. [Step from clean state]
2. [Step]
3. [Observed behavior]
4. [Expected behavior]

## Requirement Change Proposal (out-of-scope only)

**Status**: AWAITING APPROVAL

**Proposed Requirement ID**: REQ-travis-XXX-NNN
**Section**: [Which section of doc/requirements.md]
**Type**: [New requirement | Modification to existing REQ-travis-XXX-NNN]

### Proposed Text
[Requirement statement using ISO 29148 "shall" language, no banned verbs]

### Acceptance Criteria
- [ ] [Criterion — verifiable]

### Impact
- **Effort**: [Low | Medium | High]
- **Dependencies**: [affected components]
- **Phase**: [which rollout phase this fits into]

## Quality Check

[Confirm all acceptance criteria and proposed requirements pass the 8 ISO 29148 quality criteria. Flag any issues.]
```

### Severity Classification

| Severity | Criteria |
|----------|----------|
| **Critical** | System down, data loss, security vulnerability, revenue-impacting |
| **High** | Major feature broken, blocks other work, customer-reported |
| **Medium** | Feature gap, non-blocking improvement, tech debt |
| **Low** | Nice-to-have, cosmetic, minor UX improvement |

### Component Identification

Map the issue to the correct component based on what is affected:

| Component | Scope |
|-----------|-------|
| **Core Platform** | Plugin scaffold, plugin.json, directory structure |
| **MCP Integration** | .mcp.json, MCP server connections, external APIs |
| **Skills** | Skill definitions (SKILL.md files), slash commands |
| **Shared References** | Shared documentation, reference docs, templates |
| **Context** | CLAUDE.md, documentation, setup guides |
| **Harness** | Hooks, automation, CI/CD, testing infrastructure |
| **Backend** | Backend services, firmware, hardware integration |

### Meeting Transcript Triage


When the issue description references a meeting transcript or the user provides transcript content:

1. **Parse** the transcript for action items, issues, and feature requests

2. **Extract** each distinct issue or request from the transcript
3. **Run each extracted item** through the full triage workflow above (analyze, scope check, duplicate check, quality check)
4. **Present** all triage findings as a batch summary for user review
5. **Create a single triage branch** with one triage document per extracted item, or a combined document if the items are closely related
6. **Commit all triage documents** in a single commit on the triage branch

**Important**: Present all findings for user review. The triage branch captures analysis only — work item creation happens downstream via `/plan`.

### Session State Update

After committing the triage document:
1. Update session-state.json (see `references/session-state.md`): add the triage topic to a new field `orchestrator.recentTriages` (array of objects: `{topic, branch, date}`, keep last 10, LIFO). Set `lastUpdated` to the current ISO 8601 timestamp and `version` to `"1.0"`.
2. Update `.harness/working-context.md` (if it exists): add a line under "Recent Decisions" noting the triage was completed (e.g., "Triage completed for [topic] on branch triage/[short-description]").
3. Suggest next step: "Triage complete. Run `/plan` to synthesize requirements and create work items."

### Guidelines

1. **Never create work items directly.** Triage produces analysis documents on branches. Work item creation is `/plan`'s responsibility.
2. **Always include requirement traceability.** Every triage document references a `REQ-travis-XXX-NNN` or proposes one.
3. **Write self-contained triage documents.** No assumed context. Anyone reading the document must understand the issue completely.
4. **Enforce ISO 29148 quality.** All requirement text and acceptance criteria must pass quality checks with no banned verbs.
5. **Bugs are always in scope.** Defects in existing behavior do not require a requirement change proposal.
6. **One branch per triage.** Each triage session produces a `triage/<short-description>` branch with committed findings.
