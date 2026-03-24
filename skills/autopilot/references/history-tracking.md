# History Tracking Reference

Records per-session metrics to `doc/autopilot/history.json` so autopilot can display trends on startup and users can audit session performance over time. Committed to git after every session (DP-4: breadcrumbs everywhere).

---

## File Location

| Item | Value |
|------|-------|
| Path | `doc/autopilot/history.json` |
| Session state field | `autopilot.historyPath` — always `"doc/autopilot/history.json"` |
| Created on | First session end (if file does not exist) |
| Updated on | Every session end (pause or graceful stop) |

The path is fixed, not configurable. All sessions for a given customer repo share one history file.

---

## Schema

```json
{
  "version": "1.0",
  "sessions": [
    {
      "sessionId": "autopilot-20260323-091500",
      "date": "2026-03-23",
      "mode": "implement",
      "budget": 240,
      "elapsed": 185,
      "cycles": 12,
      "ticketsCompleted": ["PROJ-101", "PROJ-102"],
      "ticketsBlocked": ["PROJ-103"],
      "pauseReason": "Budget exhausted",
      "tokenBudget": 500000,
      "tokensUsed": 423000,
      "selfImprovementLevel": "end-of-session"
    }
  ],
  "aggregates": {
    "totalSessions": 1,
    "totalCycles": 12,
    "totalMinutes": 185,
    "totalTicketsCompleted": 2,
    "averages": {
      "cyclesPerSession": 12.0,
      "minutesPerSession": 185.0,
      "ticketsPerSession": 2.0,
      "minutesPerCycle": 15.4,
      "tokensPerSession": 423000
    }
  }
}
```

### Session Object Fields

| Field | Type | Source |
|-------|------|--------|
| `sessionId` | string | `autopilot.sessionId` |
| `date` | string (YYYY-MM-DD) | Extracted from `autopilot.startedAt` |
| `mode` | string | `autopilot.mode` |
| `budget` | number | `autopilot.budget.timeMinutes` |
| `elapsed` | number | `autopilot.budget.elapsedMinutes` |
| `cycles` | number | `autopilot.cycleCount` |
| `ticketsCompleted` | array of strings | `autopilot.ticketsCompleted` |
| `ticketsBlocked` | array of strings | `autopilot.ticketsBlocked` |
| `pauseReason` | string or null | `autopilot.pauseReason` (null for graceful stop) |
| `tokenBudget` | number or null | `autopilot.budget.tokens` (null if unlimited) |
| `tokensUsed` | number | `autopilot.budget.tokensUsed` |
| `selfImprovementLevel` | string | `autopilot.selfImprovement.level` |

### Aggregates Object Fields

| Field | Type | Description |
|-------|------|-------------|
| `totalSessions` | number | Length of `sessions` array |
| `totalCycles` | number | Sum of all `sessions[].cycles` |
| `totalMinutes` | number | Sum of all `sessions[].elapsed` |
| `totalTicketsCompleted` | number | Sum of all `sessions[].ticketsCompleted.length` |
| `averages.cyclesPerSession` | number | `totalCycles / totalSessions` (1 decimal) |
| `averages.minutesPerSession` | number | `totalMinutes / totalSessions` (1 decimal) |
| `averages.ticketsPerSession` | number | `totalTicketsCompleted / totalSessions` (1 decimal) |
| `averages.minutesPerCycle` | number | `totalMinutes / totalCycles` (1 decimal) |
| `averages.tokensPerSession` | number | Sum of `tokensUsed` / `totalSessions` (integer) |

---

## Write: On Session End

Append the current session and recompute aggregates. Runs during the Pause Protocol or Graceful Stop, after the run log is finalized but before the git commit.

```
function write_history(session_state):
    path = "doc/autopilot/history.json"

    # Load or initialize
    if file_exists(path):
        history = read_json(path)
    else:
        history = { "version": "1.0", "sessions": [], "aggregates": {} }

    # Build session entry from current autopilot state
    entry = {
        sessionId:             session_state.autopilot.sessionId,
        date:                  session_state.autopilot.startedAt[0:10],
        mode:                  session_state.autopilot.mode,
        budget:                session_state.autopilot.budget.timeMinutes,
        elapsed:               session_state.autopilot.budget.elapsedMinutes,
        cycles:                session_state.autopilot.cycleCount,
        ticketsCompleted:      session_state.autopilot.ticketsCompleted,
        ticketsBlocked:        session_state.autopilot.ticketsBlocked,
        pauseReason:           session_state.autopilot.pauseReason or null,
        tokenBudget:           session_state.autopilot.budget.tokens or null,
        tokensUsed:            session_state.autopilot.budget.tokensUsed or 0,
        selfImprovementLevel:  session_state.autopilot.selfImprovement.level
    }

    # Deduplicate: if sessionId already exists, replace it (handles resume edge case)
    history.sessions = history.sessions.filter(s => s.sessionId != entry.sessionId)
    history.sessions.append(entry)

    # Recompute aggregates
    history.aggregates = compute_aggregates(history.sessions)

    write_json(path, history)
    session_state.autopilot.historyPath = path
```

### Aggregate Computation

```
function compute_aggregates(sessions):
    n            = len(sessions)
    totalCycles  = sum(s.cycles for s in sessions)
    totalMinutes = sum(s.elapsed for s in sessions)
    totalTickets = sum(len(s.ticketsCompleted) for s in sessions)
    totalTokens  = sum(s.tokensUsed for s in sessions)

    return {
        totalSessions:        n,
        totalCycles:          totalCycles,
        totalMinutes:         totalMinutes,
        totalTicketsCompleted: totalTickets,
        averages: {
            cyclesPerSession:   round(totalCycles / n, 1),
            minutesPerSession:  round(totalMinutes / n, 1),
            ticketsPerSession:  round(totalTickets / n, 1),
            minutesPerCycle:    round(totalMinutes / max(totalCycles, 1), 1),
            tokensPerSession:   floor(totalTokens / n)
        }
    }
```

---

## Read: On Session Start

During Session Initialization (after step 10 in SKILL.md), read the history file and display a trend line from the last 3 sessions.

```
function display_trend():
    path = "doc/autopilot/history.json"

    if not file_exists(path):
        return   # First session — no history to display

    history = read_json(path)
    recent  = history.sessions[-3:]   # Last 3 (or fewer)

    if len(recent) == 0:
        return

    avg_cycles  = round(sum(s.cycles for s in recent) / len(recent), 1)
    avg_tickets = round(sum(len(s.ticketsCompleted) for s in recent) / len(recent), 1)
    avg_minutes = round(sum(s.elapsed for s in recent) / len(recent), 0)

    print("Last {n} sessions: avg {avg_cycles} cycles, {avg_tickets} items/session, {avg_minutes}m duration"
          .format(n=len(recent), ...))
```

The trend line appears in the session start report, below the settings table:

```
## Autopilot Starting

| Setting | Value |
|---------|-------|
| Mode | implement |
| Budget | 240 minutes |
| ... | ... |

Last 3 sessions: avg 10.3 cycles, 2.7 items/session, 165m duration
```

---

## Git Commit

The history file is committed alongside the run log during the Pause Protocol (step 4) and Graceful Stop. Both files are staged in the same commit:

```
git add doc/autopilot/history.json doc/autopilot/<date>-session.md
git commit -m "autopilot: session <sessionId> complete"
```

This satisfies DP-4 (breadcrumbs everywhere) and ensures history is version-controlled and auditable.

---

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| File missing on write | Create with `version: "1.0"` and empty `sessions` array, then append |
| File missing on read | Skip trend display silently — first session has no history |
| Corrupt JSON on read | Warn "History file corrupt — skipping trend display." Do not block session start. |
| Corrupt JSON on write | Warn "History file corrupt — reinitializing." Overwrite with fresh structure containing only the current session. |
| Duplicate sessionId (resume) | Replace the existing entry rather than appending a duplicate |
| `doc/autopilot/` directory missing | Create the directory before writing |
| Zero sessions in file | Skip trend display, write aggregates with all zeros |
