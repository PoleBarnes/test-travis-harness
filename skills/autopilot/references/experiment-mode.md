# Experiment Mode Reference

The `--experiment` flag enables dual-implementation comparison on implementation cycles. Not a separate mode -- a configurable option that layers onto `implement` and `full` modes. Implements each task twice using different approaches, tests both, presents a comparison for user selection.

---

## Activation

```
/autopilot implement --experiment --budget 2h
/autopilot full --experiment --budget 4h
```

Ignored in `observe`, `triage-only`, and `review-only` modes (no implementation actions). Log: `EXPERIMENT: Flag ignored in {mode} mode.`

---

## Dual-Implementation Protocol

When `--experiment` is active and DECIDE selects an implementation action (Priority 1, 2, or 4), EXECUTE runs this protocol instead of a single `/implement`.

**Step 1 -- Approach A**: Run `/implement <ID>` with the default approach. Record test results (pass/fail, coverage, duration). Stash changes: `git stash push --include-untracked -m "experiment/<ID>/approach-a"`. The `--include-untracked` flag ensures newly created files are captured in the stash.

**Step 2 -- Approach B**: Reset branch to pre-implementation state. Run `/implement <ID>` with a structural alternative (composition vs inheritance, extend vs new module, iterative vs recursive -- the skill selects the most meaningful contrast). Record test results. Stash: `git stash push --include-untracked -m "experiment/<ID>/approach-b"`.

**Step 3 -- Compare**: Build comparison table (see below) and present to user.

**Step 4 -- User Selects**: Apply the chosen stash via `git stash pop`, drop both experiment stashes. If user selects `skip`, discard both -- item returns to backlog for a future non-experiment cycle.

---

## Comparison Table

```
EXPERIMENT: Dual implementation complete for <ID>

| Metric              | Approach A          | Approach B          |
|---------------------|---------------------|---------------------|
| Strategy            | <brief description> | <brief description> |
| Tests passing       | 42/42               | 42/42               |
| Coverage            | 87%                 | 91%                 |
| Implementation time | 12m 30s             | 18m 45s             |
| Lines changed       | +145 / -12          | +98 / -8            |
| New files           | 3                   | 1                   |
| Complexity note     | <any concern>       | <any concern>       |

Select approach: [A / B / skip]
```

---

## Stash Management

Naming convention: `experiment/<ITEM-ID>/approach-a` and `experiment/<ITEM-ID>/approach-b`.

- Selected approach applied via `git stash pop`; rejected approach dropped via `git stash drop`
- On session end/PAUSE, orphaned experiment stashes are logged as warnings but NOT auto-dropped
- Before starting an experiment cycle, check for existing stashes with the same item ID -- if found, skip experiment for that item and run a normal single implementation

---

## Budget Impact

Adds ~2x overhead per implementation cycle. Only implementation actions (Priority 1, 2, 4) trigger the protocol -- triage, review, and completion actions are unaffected. A 2-hour budget fitting 4-5 normal implementation cycles may only fit 2-3 with `--experiment`.

### Critical Budget Zone (90%+) Disables Experiment

When budget enters the critical zone, experiment mode auto-disables for the session remainder. Starting two implementations with insufficient budget risks leaving both incomplete.

```
EXPERIMENT: Disabled -- budget in critical zone (92%). Reverting to single implementation.
```

The flag stays in session state but is not acted upon. On resume with additional budget, experiment reactivates when budget drops below critical threshold.

---

## Session State

| Field | Type | Description |
|-------|------|-------------|
| `autopilot.experiment` | boolean | Whether `--experiment` was passed |
| `autopilot.experiment.disabledByBudget` | boolean | True when critical zone suppressed experiments |
| `autopilot.experiment.cyclesRun` | number | Dual-implementation cycles completed |
| `autopilot.experiment.selectionsA` | number | Times user chose approach A |
| `autopilot.experiment.selectionsB` | number | Times user chose approach B |
| `autopilot.experiment.skipped` | number | Times user chose skip |
