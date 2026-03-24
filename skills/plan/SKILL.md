---
name: plan
description: Discover triage branches and synthesize findings into requirements and work items. Trigger on "plan work", "what's in triage", "synthesize backlog", or "process triage branches".
argument-hint: [list | synthesize | triage/branch-name]
---

# Plan -- Backlog Synthesis

Discover `triage/` branches, read their triage documents, and synthesize findings into requirements and work items.

## Input

**$ARGUMENTS**

## Current Context

- Branch: !`git branch --show-current`
- Triage branches (local): !`git branch --list 'triage/*' 2>/dev/null || echo "none"`
- Triage branches (remote): !`git branch -r --list '*/triage/*' 2>/dev/null || echo "none"`

## Working Context

After synthesizing triage branches, update `.harness/working-context.md` if it exists.

For full format details, see `references/working-context.md` in the `_shared` skill directory.

### After Synthesis

If `.harness/working-context.md` exists:
- Add newly created work items to "## Active Work" (format: `- [ID]: [title]`)
- Record synthesis decisions in "## Recent Decisions" (e.g., "Grouped 3 triage items into single feature work item")
- Keep only the 5 most recent decision entries

If the file does not exist, do not create it — work items in the DevOps platform are the primary record.

This skill writes: Active Work, Recent Decisions

## Instructions

### Mode Detection

Determine the mode from **$ARGUMENTS**:

- **No arguments** or **"list"**: Run the List workflow below.
- **"synthesize"**: Run the full Synthesize workflow below.
- **A branch name** matching `triage/*` (e.g., `triage/fix-login-timeout`): Run the Single Branch workflow below.
- **Anything else**: Tell the user the argument was not recognized. Show usage: `/plan [list | synthesize | triage/<name>]`.

---

### Mode: List (Default)

Display all open triage branches and a one-line summary of each.

1. Collect triage branches from both local and remote listings using the context commands above.
2. Deduplicate -- if a branch exists both locally and as a remote tracking branch, show it once.
3. For each triage branch:
   a. Check out the branch contents without switching: `git show <branch>:<path>` for markdown files at the repo root or in a `triage/` directory on that branch.
   b. Extract from the triage document: **title**, **severity** (if present), **scope/component** (if present), and the **first sentence or summary line**.
4. Present results as a table:

```
| # | Branch                        | Title                  | Severity | Scope       |
|---|-------------------------------|------------------------|----------|-------------|
| 1 | triage/fix-login-timeout      | Login timeout on SSO   | High     | auth        |
| 2 | triage/add-export-csv         | CSV export for reports  | Medium   | reporting   |
```

5. If no triage branches exist, say: "No triage branches found. Create one with `git checkout -b triage/<name>` and commit a markdown document describing the issue or opportunity."

---

### Mode: Synthesize

Full workflow -- read all triage branches, synthesize into requirements and work items, and present for approval.

#### Triage Verification (G1 Gate)

If process enforcement is enabled (see `references/process-gates.md`):
1. Check that at least one triage branch exists: `git branch --list 'triage/*'`
2. If no triage branches found:
   - **mode: block** (standard/comprehensive tier): "BLOCKED: No triage branches found. Run `/triage` first to capture and analyze the issue before planning."
   - **mode: warn** (minimal tier): "WARNING: No triage branches found. Planning without triage may result in incomplete requirements."
3. If triage branches exist, proceed normally.

#### Step 1: Discover and Read

1. Collect all triage branches (local + remote, deduplicated).
2. If none exist, report that and stop.
3. For each branch, read all markdown files committed on that branch that are not present on the current branch. Use `git diff --name-only <current-branch>...<triage-branch>` to find new/changed files, then `git show <triage-branch>:<file>` to read each one.
4. Parse each triage document for: title, description, severity, affected components, proposed solution (if any), acceptance criteria (if any).

#### Step 2: Group and Prioritize

1. Group triage items by component or scope. If no component is specified, use "general".
2. Sort within each group by severity: Critical > High > Medium > Low > unspecified.
3. Check for conflicts -- triage items that contradict each other or propose incompatible changes to the same component. Flag these for the user.

#### Step 3: Synthesize Requirements

For each triage item (or group of related items), draft a requirement following ISO 29148 structure:

- **ID**: `REQ-<component>-<seq>` (e.g., `REQ-AUTH-001`)
- **Title**: Clear, imperative statement
- **Description**: What the system shall do (use "shall" for mandatory, "should" for recommended)
- **Rationale**: Why this requirement exists (traced back to triage document)
- **Source**: The triage branch name(s)
- **Priority**: Derived from severity
- **Acceptance Criteria**: Testable conditions (carried from triage doc or synthesized)

#### Step 4: Propose Requirements Update

1. Check if `doc/requirements.md` exists in the current branch.
   - If yes: read it, find the next available requirement ID sequence, and draft additions.
   - If no: bootstrap the file using the template in `references/requirements-bootstrap.md`. Create `doc/` directory if needed, write the initial structure, then append the synthesized requirements after the `## Requirements` heading.
2. Show the user the proposed additions or new file content in full.

#### Step 5: Propose Work Items

1. For each requirement, propose a work item with: title, description, acceptance criteria, and priority.
2. Format work items for the user's devops platform:
   - **Azure DevOps**: Use `azure-devops` MCP tools to create work items (User Story or Bug based on triage type). Include requirement ID in the description.
   - **GitHub**: Use `github` MCP tools to create issues with labels for priority and component. Include requirement ID in the body.
   - **Jira**: Use `atlassian` MCP tools to create issues. Map priority and link to requirement ID.
   - **Linear**: Use `linear` MCP tools to create issues. Map priority and link to requirement ID.
   - **No MCP available**: Present work items as a markdown checklist the user can copy into their tracker manually.
3. Show the proposed work items to the user. Do NOT create them yet.

#### Step 6: User Approval

Present a summary:

```
Triage branches processed: N
Requirements drafted: N
Work items proposed: N
Conflicts found: N (if any)
```

Ask the user to approve, modify, or reject. Wait for explicit confirmation before proceeding.

#### Step 7: Execute (On Approval Only)

1. **Requirements**: Write the approved changes to `doc/requirements.md`. Stage and commit with message: `docs: add requirements from triage synthesis`.
2. **Work items**: Create approved work items via the appropriate devops MCP tools. Report each created item with its ID/URL.
3. **Branch cleanup**: Suggest deleting processed triage branches. List the git commands but do NOT execute them without user confirmation:
   ```
   git branch -d triage/fix-login-timeout
   git push origin --delete triage/fix-login-timeout
   ```

---

### Mode: Single Branch

Process one triage branch -- same as Synthesize but scoped to a single branch.

1. Validate the branch exists (check local, then remote). If not found, report and stop.
2. If remote-only, fetch it first: `git fetch origin <branch>`.
3. Follow Synthesize Steps 1-7, but only for the specified branch.
4. When proposing requirements, still read existing `doc/requirements.md` to avoid ID collisions and duplicate requirements.

---

### Work Item Creation

**Input traceability**: When creating each work item:
- Include the requirement ID (REQ-*) in the work item description as the first line: `Requirement: REQ-[ID]`
- Include a link back to the triage document that generated this requirement (e.g., `Source: triage/<branch-name>`)
- This establishes the traceability chain: triage → requirement → work item

When creating work items, detect the available devops platform from MCP tool availability:

- **Azure DevOps**: Look for `azure-devops` MCP tools. Create Work Items (User Story for features, Bug for defects). Set fields: Title, Description, Acceptance Criteria, Priority, Area Path (from component).
- **GitHub**: Look for `github` MCP tools. Create Issues with labels. Map severity to priority labels (`priority:critical`, `priority:high`, etc.). Add component labels.
- **Jira**: Look for `atlassian` MCP tools. Create issues with appropriate issue type (Story/Bug). Set Priority and Component fields.
- **Linear**: Look for `linear` MCP tools. Create issues with priority mapping (Urgent/High/Medium/Low). Set team and label from component.
- **No platform detected**: Output work items as structured markdown. Inform the user that no devops MCP integration was detected and they can create items manually or configure an integration.

---

### Session State Update

After creating work items (Step 7), update session-state.json (see `references/session-state.md`):
- Add each new work item ID to `orchestrator.itemStates` with `abstractState: "planned"`, `trackerState` set to the "To Do" equivalent for the platform (see `references/tracker-operations.md` Status Mapping)
- Update `recentWorkItemIds` with the new IDs (prepend to array, keep last 10, LIFO order)
- Set `lastUpdated` to the current ISO 8601 timestamp and `version` to `"1.0"`

---

### Error Handling

- **No triage branches found**: Report clearly. Suggest how to create one: `git checkout -b triage/<name>`, commit a markdown file describing the issue, and push.
- **Triage branch has no markdown files**: Skip it with a warning. Report which branch was skipped and why.
- **`doc/requirements.md` does not exist**: Bootstrap it using `references/requirements-bootstrap.md` template. Offer to create and commit, then proceed with synthesis.
- **MCP tools unavailable**: Fall back to markdown output for work items. Do not fail -- the requirements synthesis is still valuable without work item creation.
- **Git errors** (detached HEAD, merge conflicts, dirty working tree): Report the git error clearly and suggest resolution. Do not attempt destructive git operations.
- **Conflicting triage items**: Flag them prominently in the synthesis output. Do not silently merge conflicting requirements. Ask the user to resolve before proceeding.
