# Budget System Reference

Defines how autopilot tracks, enforces, and reports on time budgets. The budget prevents runaway sessions and gives users predictable control over how long autopilot runs.

---

## Time Budget

### Configuration

| Source | Syntax | Example | Precedence |
|--------|--------|---------|------------|
| CLI argument | `--budget <duration>` | `--budget 2h` | Highest |
| Config file | `autopilot.default_budget_minutes` | `240` | Middle |
| Built-in default | -- | 240 minutes (4 hours) | Lowest |

Resolution order: CLI argument > config file > built-in default.

### Parsing Duration Strings

Parse the `--budget` argument using these rules:

| Format | Interpretation | Example |
|--------|---------------|---------|
| `Nh` | N x 60 minutes | `2h` = 120 minutes |
| `N.Dh` | N.D x 60 minutes | `1.5h` = 90 minutes |
| `Nm` | N minutes | `30m` = 30 minutes |
| `NhMm` | N hours + M minutes | `1h30m` = 90 minutes |
| Bare number | Minutes | `120` = 120 minutes |
| Invalid | Warn and use default | `abc` = 240 minutes (with warning) |
| Zero | `0` = 0 minutes (dry-run) | See Edge Cases |
| Negative | Warn and use default | `-30` = 240 minutes (with warning) |

Parsing pseudocode:

```
function parse_budget(input):
    input = input.strip().lowercase()

    if input matches /^(\d+)h(\d+)m$/: return $1 * 60 + $2
    if input matches /^(\d+\.?\d*)h$/: return float($1) * 60
    if input matches /^(\d+)m$/: return $1
    if input matches /^\d+$/: return int(input)
    if int(input) < 0:
        warn "Negative budget '{input}'. Using default (240 minutes)."
        return 240
    warn "Invalid budget format '{input}'. Using default (240 minutes)."
    return 240
```

### Validation

After parsing, validate the budget against limits:

- Minimum: 0 minutes (0 enables dry-run mode)
- Below 15 minutes: warn "Budget below 15 minutes -- may not complete a full cycle"
- Maximum: `autopilot.max_budget_minutes` from config (default: 480 / 8 hours)
- Above maximum: warn and clamp to max

---

## Tracking

### Session State Fields

Budget tracking uses these fields in the autopilot session state:

| Field | Type | Description |
|-------|------|-------------|
| `autopilot.budget.timeMinutes` | number | Total budget in minutes |
| `autopilot.budget.elapsedMinutes` | number | Elapsed time in minutes (updated each cycle) |
| `autopilot.startedAt` | string (ISO 8601) | Session start timestamp |

### Elapsed Calculation

At the start of each cycle:

```
function calculate_elapsed(session):
    started = parse_iso8601(session.autopilot.startedAt)
    now = current_utc_time()
    elapsed_minutes = floor((now - started).total_minutes())

    session.autopilot.budget.elapsedMinutes = elapsed_minutes
    return elapsed_minutes
```

The floor ensures elapsed is always a whole number of minutes for clean display.

### Budget Percentage

```
function budget_percentage(session):
    if session.autopilot.budget.timeMinutes == 0:
        return 100  # Dry-run: always "exhausted"
    return (session.autopilot.budget.elapsedMinutes
            / session.autopilot.budget.timeMinutes) * 100
```

---

## Thresholds

### Budget Zones

| Zone | Condition | Behavior |
|------|-----------|----------|
| Normal | elapsed < 80% of budget | Normal operation. No warnings. |
| Warning | elapsed >= 80% and < 90% of budget | Emit warning before starting the cycle. Continue execution. |
| Critical | elapsed >= 90% and < 100% of budget | Emit warning. Skip Priority 4 actions (starting new items). Prefer completing in-flight work. |
| Expired | elapsed >= 100% of budget | Graceful stop. Complete current cycle if running, but do not start a new one. |

### Warning Message

When entering the warning zone (80% threshold), emit:

```
WARNING: Budget 80% consumed ([elapsed]m / [budget]m). [remaining]m remaining.
```

When entering the critical zone (90% threshold), emit:

```
WARNING: Budget nearly exhausted ([elapsed]m / [budget]m). Only executing completion actions.
```

These warnings appear in the cycle log and in the user-facing output.

### Critical Budget Behavior

When budget is in the critical zone (90-99%):

1. Skip Priority 4 actions (starting new items) -- starting new work with insufficient budget leads to incomplete items
2. Prefer Priority 1b/5 (completing in-review items, PR review) -- these close out in-flight work
3. Avoid Priority 2/3/4 (starting new work) -- these open new WIP
4. Priority 1 (continue WIP) is allowed only if the item appears close to completion
5. Priority 3 (triage/plan) is always allowed -- planning is quick

### Graceful Stop

When the budget expires:

1. If mid-cycle: let the current cycle's EXECUTE phase complete (do not interrupt a running skill)
2. Run the EVALUATE phase for the current cycle
3. Do NOT start a new SCAN phase
4. Write the session summary
5. Report to user: "Budget exhausted. Session complete."

---

## Budget Check Timing

Check the budget at the START of each cycle, before SCAN begins. This placement ensures:

- The current cycle always completes fully (no mid-cycle interruption)
- The budget warning appears before the last cycle begins
- Graceful stop happens between cycles, not during skill execution
- Skills are never killed mid-execution due to budget

### Check Pseudocode

```
function should_continue(session):
    elapsed = calculate_elapsed(session)
    budget = session.autopilot.budget.timeMinutes

    # Update tracking
    session.autopilot.budget.elapsedMinutes = elapsed

    if elapsed >= budget:
        return STOP

    pct = budget_percentage(session)

    if pct >= 90:
        remaining = budget - elapsed
        warn("Budget nearly exhausted ({elapsed}m / {budget}m). Only executing completion actions.")
        return CONTINUE_CRITICAL

    if pct >= 80:
        remaining = budget - elapsed
        warn("Budget 80% consumed ({elapsed}m / {budget}m). {remaining}m remaining.")
        return CONTINUE_WARNING

    return CONTINUE
```

---

## Budget Display

### In-Progress Display

During execution, include budget status in cycle log entries:

```
### Cycle [N] -- [timestamp] ([elapsed]m / [budget]m)
```

### Pause/Stop Output

When the session pauses or stops, include:

```
**Session**: [elapsed]m / [budget]m ([percentage]%) | [cycles] cycles
```

Example:
```
**Session**: 185m / 240m (77%) | 12 cycles
```

### Final Summary

The session document (see `autopilot-session-template.md` in `core/doc/`) records:

| Field | Value |
|-------|-------|
| Budget | {budgetMinutes}m |
| Duration | {elapsedMinutes}m |
| Cycles | {cycleCount} |

---

## Edge Cases

### Budget = 0 (Dry Run)

When the budget is 0 minutes:

1. Initialize the session (write session state, create session document)
2. Run exactly one SCAN phase (to report current state)
3. Run the DECIDE phase (to show what would be picked)
4. Do NOT run EXECUTE
5. Stop with: "Dry run complete. Would execute: [decision]"

This is useful for testing autopilot's decision logic without executing any work.

### Elapsed > Budget (Clock Skew)

If elapsed time already exceeds the budget when checked (e.g., due to clock adjustment or a very long skill execution):

- Stop at the next cycle boundary
- Do not panic or error
- Report: "Budget exhausted ({elapsed}m / {budget}m). Session over budget by {overage}m."

### Very Long Cycle (>1 hour)

If a single cycle takes more than 60 minutes:

- Log a warning: "Cycle {N} took {duration}m. Consider breaking work into smaller items."
- Do NOT interrupt the cycle
- The budget check at the next cycle start will handle stop/continue

### System Clock Changes

Autopilot uses wall-clock time, not CPU time. If the system clock is adjusted during a session:

- Forward jump: may cause early budget expiration (acceptable -- safer to stop early)
- Backward jump: may extend the session beyond intended budget (log a warning if elapsed decreases between cycles)

### Budget With No Actionable Work

If the DECIDE phase produces PAUSE ("no actionable work") but budget remains:

- Do NOT busy-loop waiting for work to appear
- PAUSE immediately, even though budget is available
- Report remaining budget: "Paused with {remaining}m budget remaining. No actionable work."

---

## Configuration Reference

### Config.yaml Fields

```yaml
autopilot:
  default_mode: observe              # "observe" or "implement"
  default_budget_minutes: 240        # Default budget when --budget not specified
  max_budget_minutes: 480            # Hard ceiling (8 hours). CLI cannot exceed this.
  max_retries: 3                     # Consecutive failures before pause
  cycle_timeout_minutes: 60          # Max duration for a single cycle
```

### Hard Ceiling

The `max_budget_minutes` setting (default: 480) prevents accidentally running autopilot for excessive durations. If the CLI `--budget` exceeds this value:

```
WARNING: Requested budget ({requested}m) exceeds maximum ({max}m). Using maximum.
```

Clamp to the max value and continue.

### All Fields Optional

All `autopilot` config fields are optional. If the `autopilot` section is absent entirely, use the defaults shown above. This maintains backward compatibility with existing customer configs.

---

## Token Budget

### Configuration
- CLI flag: `--token-budget <N>` (e.g., `500k`, `1m`, `1.5m`, `100000`)
- Config: `autopilot.default_token_budget` (default: null — unlimited)
- When null/unset: token budget is not enforced

### Parsing Token Counts
- `Nk` → N × 1000 (e.g., `500k` = 500000)
- `Nm` → N × 1000000 (e.g., `1m` = 1000000, `1.5m` = 1500000)
- Bare number → literal (e.g., `100000` = 100000)
- Invalid → warn, set to null (unlimited)

### Tracking
Session state fields:
- `autopilot.budget.tokens` — total budget (null = unlimited)
- `autopilot.budget.tokensUsed` — approximate tokens consumed

Estimation: After each cycle, estimate tokens consumed as approximately 4000 tokens per skill invocation (covers input + output). Adjust the multiplier based on observed conversation length. This is a rough estimate — actual usage may vary by 2-3x.

### Thresholds
Same zones as time budget: Normal (<80%), Warning (80-90%), Critical (90-100%), Expired (>=100%).

### Dual-Budget Check
Both budgets run simultaneously. At the start of each cycle:
1. Check time budget status
2. Check token budget status (if configured)
3. Use the MORE restrictive of the two (e.g., if time is at 50% but tokens are at 90%, apply critical zone behavior)
