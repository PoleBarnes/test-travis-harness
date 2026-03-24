# Subagent Invocation Reference

How the `/pr` skill's review team uses Claude Code's Agent tool to run parallel, specialized reviews.

## What Are Subagents?

Claude Code's **Agent tool** spawns autonomous subprocesses that receive a prompt, execute independently with their own tool access, and return structured results to the orchestrator. The `/pr` skill uses subagents to run a multi-reviewer team in a single pass.

## Subagent Types Used in /pr

| Type | Tool Access | Speed | Used For |
|------|-------------|-------|----------|
| `general-purpose` | Full (read, write, execute, MCP) | Standard | Code review, V&V traceability, applying fixes |
| `Explore` | Read-only (file reads, searches) | Fast | Test coverage auditing, PR metadata fetching |

**Choose Explore** when the subagent only needs to read code and report findings.
**Choose general-purpose** when the subagent needs to modify files or call MCP servers.

## How to Invoke

Each subagent call requires a detailed prompt containing:

1. **Role** — what the subagent is checking (e.g., "You are a security reviewer")
2. **Context** — the diff, list of changed files, and linked work item (if any)
3. **Checklist** — specific items to evaluate
4. **Output format** — the expected feedback structure (see Feedback Format below)

Example invocation pattern:

```
Agent tool call:
  type: general-purpose (or Explore)
  prompt: |
    You are the Code Reviewer for PR #42.

    Changed files: [list]
    Diff: [full diff]
    Work item: PROJ-42 — Add login validation

    Check: security (OWASP Top 10), test coverage, standards, code quality.

    Return findings using [BLOCKING], [SUGGESTION], [QUESTION], [PRAISE] tags.
```

## Parallel Execution

All review subagents are spawned **simultaneously** for maximum throughput:

| Subagent | Type | Runs When |
|----------|------|-----------|
| Code Reviewer | `general-purpose` | Always |
| Test Auditor | `Explore` | Always |
| V&V Engineer | `general-purpose` | Only when a work item is linked |

The orchestrator waits for all subagents to complete, then synthesizes their results into a unified review.

## Feedback Format

All subagents must tag every finding with exactly one of:

| Tag | Meaning | Effect |
|-----|---------|--------|
| `[BLOCKING] file:LINE — description + proposed fix` | Must fix before merge | Triggers fix loop |
| `[SUGGESTION] file:LINE — description + rationale` | Optional improvement | Listed in PR description |
| `[QUESTION] file:LINE — description` | Needs author clarification | Surfaced to user |
| `[PRAISE] file:LINE — description` | Highlights good patterns | Included in review summary |

## Fix Loop

When the review team returns `[BLOCKING]` findings during **create mode**:

1. Each blocking issue is presented to the user with file reference and proposed fix
2. User chooses: **apply** (y), **skip** (n), or **skip all remaining**
3. Accepted fixes are delegated to a `general-purpose` subagent that modifies the code
4. After fixes are applied, affected review checks re-run to verify resolution
5. Unresolved blockers are noted in the PR description as known items
