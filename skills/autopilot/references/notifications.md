# Notification System Reference

## Configuration

`autopilot.notify_via` accepts: `terminal` (default), `slack`, `linear`, or an array `[slack, linear]`.
Terminal output always fires regardless of other channels.

## Terminal Notification

Already implemented in the Pause Protocol (SKILL.md). The structured pause/stop output is the terminal notification.

## Slack Notification



## Tracker Notification (Linear/Jira)

When an item is added to `ticketsBlocked`, post a comment on that item:


Use Linear MCP `save_comment` on the blocked issue:
"[Autopilot] Blocked: [reason]. Session [sessionId], cycle [N]."


## Pause Notification



If the pause is item-specific (e.g., "Human gate pending: G3_REVIEW for PROJ-42"), also post a tracker comment on the specific item using the tracker notification format above.

## Graceful Stop Notification



## Error Handling

Notification failure MUST NEVER block the session or count as a cycle failure:
- If Slack MCP is unavailable: warn "Slack notification skipped — MCP unavailable"
- If tracker comment fails: warn "Tracker notification skipped — [error]"
- If `autopilot.slack_channel` is not configured: warn "Slack notification skipped — no channel configured"
- Continue the session normally in all cases

Log the warning to the run log, then proceed. Notifications are best-effort; session continuity takes priority.

## When to Notify

| Event | Terminal | Slack | Tracker |
|-------|----------|-------|---------|
| Session start | yes | — | — |
| Cycle complete | — | — | — |
| Budget 80% warning | yes | — | — |
| Item blocked | yes | — | yes (comment on item) |
| Pause (any reason) | yes | yes | yes (if item-specific) |
| Graceful stop | yes | yes | — |

## Notification Sequence

When multiple channels are configured, fire them in this order:

1. **Terminal** — always first (immediate user feedback)
2. **Tracker** — comment on blocked/paused items (if applicable)
3. **Slack** — post session status to channel

If any channel fails, proceed to the next. Do not retry failed notifications within the same event.

## Channel Configuration Examples

Single channel (default):
```yaml
autopilot:
  notify_via: terminal
```

Multiple channels:
```yaml
autopilot:
  notify_via: [slack, linear]
  slack_channel: "#autopilot-status"
```

Array form always includes terminal implicitly. Specifying `terminal` in the array is valid but redundant.
