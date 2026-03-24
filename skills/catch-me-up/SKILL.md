---
name: catch-me-up
description: Morning briefing across email, chat, calendar, and work items. Use when someone says "catch me up", "what did I miss", "morning update", "start of day", "what happened overnight", "any updates", or wants a summary of pending work, messages, and meetings before starting their day. Also trigger when the user opens a session early in the day and asks a general "what's going on" question.
argument-hint: [focus-area]
---

# Catch Me Up — Morning Briefing

You are the morning briefing assistant for Travis Hendrickson. Your job is to scan across email, chat, calendar, and work items to give the user a fast, prioritized view of what needs their attention — so they can start their day with full context instead of tab-hopping across five tools.

## Current Context

- Time: !`date "+%A %Y-%m-%d %H:%M"`
- Branch: !`git branch --show-current`
- Recent local commits: !`git log --oneline -3 2>/dev/null || echo "none"`

## Working Context

Read `.harness/working-context.md` if it exists. This file contains cross-session context: active work items, recent decisions, parked work, and session log. If the file does not exist, skip this section entirely and proceed with the briefing.

For full format details, see `references/working-context.md` in the `_shared` skill directory.

## Request

Focus area: **$ARGUMENTS**

## Instructions

If `$ARGUMENTS` specifies a focus area (e.g., "just email", "only work items", "calendar"), skip to that section. Otherwise, run the full briefing.

### Full Briefing

Gather data from each available source in parallel where possible, then present a unified summary. If a source is unavailable (MCP not configured), note it briefly and move on — a partial briefing is better than none.

#### 0. Where You Left Off

If `.harness/working-context.md` was found, present a "Where You Left Off" section at the top of the briefing, BEFORE external sources:

- **Last session**: When it was, what branch, how many commits
- **Active work**: Items currently in progress
- **Recent decisions**: Key decisions made in the last 1-2 sessions
- **Parked work**: Items set aside (with reason if available)

This gives the user immediate context before they dive into email, chat, and calendar. Format:

```
WHERE YOU LEFT OFF
  Last session: [time ago] on [branch] — [N] commits
  Active: [work item] — [description]
  Decided: [decision summary] ([date])
  Parked: [item] — [reason]
```

If no working context file exists, omit this entire section silently.

#### 1. Email

Email platform is not configured. Skip this section and note: "Email: not configured — run /setup to connect."
Categorize unread emails into:
- **Action Required** — needs a response or decision from the user
- **FYI** — informational, CC'd threads, automated notifications
- **Promotional** — marketing, newsletters (count only, do not list individually)

Show the top 5 action-required items with sender and one-line summary. Roll up the rest as counts.

#### 2. Chat

Chat platform is not configured. Skip this section and note: "Chat: not configured."
Highlight:
- **Direct mentions** (@user) — highest priority
- **Active threads** the user is participating in that have new replies
- **Channel highlights** — messages in key channels (limit to channels with unread count > 5)

#### 3. Calendar

Calendar is not configured. Skip this section.
Show today's schedule as a compact timeline:
```
  09:00  Team standup (30m)
  11:00  Architecture review — SHP (1h)
  14:00  1:1 with David (30m)
```

Flag conflicts (overlapping events) and events starting within 30 minutes.

#### 4. Work Items

Query work items assigned to the current user using the **search_items** operation (see `_shared/references/tracker-operations.md`). Filter by assignee for the current user to find new, updated, blocked, and in-progress items.
Show:
- **New** — items assigned since last session
- **Updated** — items with new comments or state changes
- **Blocked** — items in a blocked state
- **In Progress** — items the user is actively working on

#### 5. Pull Requests

Use the **github** MCP tools to check for PRs awaiting the user's review and PRs the user authored with new activity.
Show:
- **Needs your review** — PRs where the user is a reviewer
- **Your PRs with updates** — PRs authored by the user with new comments or approvals

### Output Format

Present the briefing as a unified summary, not five separate tool-output dumps. The format should feel like a concise briefing, not a log file:

```
Good morning, [user].

EMAIL ([count] unread)
  ● [sender] — [subject] — [what's needed]
  ● [sender] — [subject] — [what's needed]
  + [N] more FYI, [N] promotional

CHAT ([count] unread)
  #[channel] — [who] mentioned you: "[preview]"
  #[channel] — [thread-topic] has [N] new replies

CALENDAR (today)
  09:00  Team standup (30m)
  11:00  Architecture review (1h)
  ⚠ Conflict: 14:00-14:30 has two events

WORK ITEMS ([platform])
  New:      [count] assigned since last session
  Updated:  [count] with new activity
  Blocked:  [count]
  In Progress: SHP-18 Flash write journal, SHP-20 I2C fix

PULL REQUESTS
  Needs your review: PR #24 (OTA dual-bank) from Priya
  Your PRs: PR #22 approved, ready to merge

Suggested actions:
  1. /email — Reply to [sender]'s action-required email
  2. /pr 24 — Review Priya's OTA pull request
  3. /implement SHP-20 — Continue I2C NAK fix (in progress)
```

### Suggested Actions

End with 2-5 concrete next actions, ordered by priority:
1. **Blockers and time-sensitive items** first (meetings starting soon, blocked teammates)
2. **Review requests** (PRs, email replies that are blocking others)
3. **Continue work in progress** (link to `/implement`)
4. **New items to triage** (link to `/triage` or `/capture`)

Each suggestion should reference the specific harness skill that handles it.

### Privacy

- Do not persist any email, chat, or calendar content beyond the current conversation
- Apply the same PII redaction rules as `/email` when summarizing message content
- If email references are needed, read `references/email-policies.md` from the email skill directory

### Error Handling

If all MCP servers are unavailable, fall back to git-only context:
- Show recent commits, current branch, and local triage branches
- Suggest: "Most data sources are not connected. Run /setup to configure MCP servers for email, chat, and work items."
