---
name: capture
description: Quick-capture items into triage without full analysis. Use when someone says "jot this down", "quick note", "capture this", "log this for later", "add this to the backlog", or wants to record a bug, idea, or task without going through full triage. Also use when multiple items need to be captured in batch. This is the fast-path alternative to /triage — speed over rigor.
argument-hint: [item to capture, or multiple items separated by blank lines]
---

# Quick Capture

You are the fast-path intake for Travis Hendrickson. Where `/triage` performs full quality analysis (ISO 29148 checks, scope review, duplicate detection), you prioritize **speed** — get the item recorded on a triage branch so it is not lost, and move on. The user can always run `/triage` later for full analysis.

## Input

> $ARGUMENTS

## Working Context

After capturing items, update `.harness/working-context.md` to record what was captured.

For full format details, see `references/working-context.md` in the `_shared` skill directory.

### After Capture

If `.harness/working-context.md` exists, append captured items to the appropriate section:
- **bug/task/feature** → "## Active Work" (if the user intends to work on it soon) or "## Parked Work" (default for captures)
- **risk/question** → "## Parked Work"

Format: `- [type]: [title] — captured [date], branch: triage/[branch-name]`

If the file does not exist, do not create it — captures are already recorded on triage branches.

This skill writes: Active Work (optional), Parked Work

## Instructions

**If the input is empty**, ask the user what they want to capture and wait for their response.

**If the input contains multiple items** (separated by blank lines, numbered lists, or bullet points), process each as a separate capture in batch mode.

**Otherwise**, process the single item.

### Capture Workflow

For each item:

#### 1. Auto-Classify

Determine the type from the content. Do not ask the user — just make your best call:

| Type | Signals |
|------|---------|
| **bug** | Error, crash, failure, broken, wrong behavior, regression |
| **feature** | Add, new, want, need, should, wish, would be nice |
| **task** | Do, update, change, migrate, refactor, clean up |
| **risk** | Concern, worry, might fail, what if, could break |
| **question** | How, why, can we, is it possible, what happens if |

#### 2. Generate Title

Write a short, specific title (under 80 characters) from the raw input. Use the same voice and terminology the user used — do not corporate-speak it.

#### 3. Create Triage Document

Create a minimal triage document with this exact structure:

```markdown
# [Title]

| Field | Value |
|-------|-------|
| Type | [bug/feature/task/risk/question] |
| Captured | [ISO 8601 timestamp] |
| Source | quick-capture |
| Status | raw — needs full triage |

## Raw Description

[The user's original text, unmodified]
```

That is the entire document. No quality analysis, no scope check, no severity classification, no duplicate search. Those happen later when someone runs `/triage` or `/plan` on this branch.

#### 4. Commit to Triage Branch

- Branch name: `triage/capture-[slugified-title]`
  - For batch mode: `triage/capture-batch-[date]` (one branch, multiple files)
- File path: `triage/[slugified-title].md`
- Commit message: `TH: capture: [title]`

### Batch Mode

When processing multiple items, create all documents on a single `triage/capture-batch-[date]` branch. Show a summary table when done:

```
Captured 4 items on triage/capture-batch-2026-03-12:

  # | Type    | Title
  1 | bug     | Login timeout on slow connections
  2 | feature | Export dashboard to PDF
  3 | task    | Update Node.js to v22
  4 | risk    | Redis cache eviction under load
```

### After Capture

End with:

```
✓ [N] item(s) captured on triage/[branch-name]

  These are raw captures — no quality analysis or scope check performed.
  Next: /triage to analyze and refine, or /plan to synthesize into work items.
```

### What Capture Does NOT Do

- No ISO 29148 quality analysis (that is `/triage`)
- No scope check against `doc/requirements.md` (that is `/triage`)
- No duplicate detection in the DevOps platform (that is `/triage`)
- No severity classification (that is `/triage`)
- No work item creation (that is `/plan`)

The point is speed. Get it written down before it is forgotten.
