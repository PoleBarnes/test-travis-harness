# Autopilot Session -- {date}

| Field | Value |
|-------|-------|
| Session ID | {sessionId} |
| Mode | {mode} |
| Budget | {budgetMinutes}m |
| Token Budget | {tokenBudget or "unlimited"} |
| Experiment | {experiment or "off"} |
| Max retries | {maxRetries} |
| Started | {startedAt} |
| Ended | {endedAt} |
| Duration | {elapsedMinutes}m |
| Cycles | {cycleCount} |
| Completed | {ticketsCompleted} |
| In progress | {ticketsInProgress} |
| Blocked | {ticketsBlocked} |
| Pause reason | {pauseReason or "N/A"} |
| Resumed from | {previousSessionId or "N/A"} |
| Projects | {scopedProjects or "single"} |

---

## Cycle Log

{cycles will be appended here by autopilot during execution}

---

## Session Summary

{summary will be written at session end}
