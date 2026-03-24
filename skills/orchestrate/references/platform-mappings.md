# Platform State Mappings

Maps abstract orchestrator states to each platform's native state representation. Used by `/orchestrate` when reading and writing work item state via `tracker-operations.md`.

---

## Abstract State Model

The orchestrator uses these abstract states internally:

| Abstract State | Description | Synced to Tracker |
|---------------|-------------|-------------------|
| `triaged` | Triage document exists | No |
| `planned` | Work item created, in backlog/todo | Yes |
| `ready` | All dependencies resolved (auto-computed) | No |
| `in-progress` | Active implementation | Yes |
| `in-review` | PR created, under review | Yes |
| `verifying` | V&V audit running | No |
| `blocked` | Dependencies unresolved (auto-computed) | No |
| `done` | Complete, merged, closed | Yes |

Only states marked "Yes" under "Synced to Tracker" are pushed to the external tracker via the **update_status** operation.

---

## Platform Mapping Tables

### Jira (Atlassian)



| Abstract State | Jira Status | Notes |
|---------------|-------------|-------|
| `planned` | To Do / Open | Depends on project workflow |
| `in-progress` | In Progress | |
| `in-review` | In Review | May not exist — fall back to "In Progress" with a label |
| `blocked` | (no status change) | Set the issue flag ("impediment" flag) or add `blocked` label |
| `done` | Done / Closed | Depends on project workflow |

**Jira specifics**:
- Jira requires transition IDs, not status names. Query available transitions first via the issue's `/transitions` endpoint.
- If the target status is not reachable in one step, report the valid transition path to the user.
- Some workflows have conditions (e.g., "all subtasks must be done before parent can move to Done").
- The "In Review" status may not exist in all workflows. If absent, keep as "In Progress" and add a comment noting review state.
- Use the impediment flag or a `blocked` label for blocked state — Jira has no native "blocked" status.
- Status categories (`To Do`, `In Progress`, `Done`) can be used for coarse-grained mapping when exact status names vary.

### Linear


**Active platform** — these mappings are in use.


| Abstract State | Linear State | Notes |
|---------------|-------------|-------|
| `planned` | Todo | |
| `in-progress` | In Progress | |
| `in-review` | In Review | |
| `blocked` | (no state change) | Add `blocked` label |
| `done` | Done | |

**Linear specifics**:
- Linear allows direct state transitions without path constraints.
- State IDs must be resolved via `list_issue_statuses` — do not hardcode state IDs.
- Linear state names are customizable per team — always resolve by name, not ID.
- The `blocked` label must be resolved via `list_issue_labels` before applying.
- Linear's priority is numeric: 0=No priority, 1=Urgent, 2=High, 3=Medium, 4=Low (inverted from typical priority scales).

---

## Custom Workflow Configuration

Projects can override default state mappings via the `devops.workflow.status_map` config.

### Config Structure

```yaml
devops:
  workflow:
    status_map:
      backlog: "Backlog"
      todo: "Ready for Dev"
      in_progress: "In Development"
      in_review: "Code Review"
      done: "Released"
```

### Resolution Order

When resolving a state name for tracker operations:

1. **Check `devops.workflow.status_map`** — if the normalized state has a custom mapping, use it
2. **Fall back to platform defaults** — use the mapping table for the active platform (above)
3. **Fall back to generic names** — use the normalized state name as-is (e.g., "In Progress")

### Using Custom Mappings


This project has custom status mappings configured:


- `todo` → `Todo`

- `in_progress` → `In Progress`

- `in_review` → `In Review`

- `done` → `Done`

- `blocked_tag` → `blocked`


Use these values instead of the platform defaults when calling the **update_status** operation.


---

## Fallback Behavior

When the target platform lacks a particular state:

| Missing State | Fallback Strategy |
|--------------|-------------------|
| `in-review` not in workflow | Keep as `in-progress`. Add a comment or label: "PR created — in review". Record `in-review` in session state only. |
| `blocked` not a valid state | Do not change tracker state. Add a `blocked` tag/label/flag. Record `blocked` in session state only. |
| `todo` not in workflow | Use the first non-terminal state (often "New", "Open", or "Backlog"). |
| Custom state in tracker not in abstract model | Map to the closest abstract state by status category. Log a warning about the unmapped state. |

### Status Category Mapping (coarse fallback)

When exact state names don't match, use status categories:

| Category | Abstract States |
|----------|----------------|
| To Do / Backlog | `planned`, `ready` |
| In Progress | `in-progress`, `in-review`, `verifying` |
| Done | `done` |

This mapping is lossy — use it only when exact mapping fails and log a warning.

---

## Reading State from Tracker

When reading a work item's state from the tracker, reverse-map it to the abstract model:

```
function resolve_abstract_state(tracker_state, platform):
    # 1. Check custom status_map (reversed)
    if devops.workflow.status_map is defined:
        for normalized, mapped in status_map.items():
            if mapped == tracker_state:
                return normalized

    # 2. Check platform default mapping (reversed)
    for abstract, platform_state in platform_defaults[platform].items():
        if platform_state == tracker_state:
            return abstract

    # 3. Fall back to status category
    category = get_status_category(tracker_state, platform)
    return category_to_abstract[category]  # e.g., "In Progress" category → "in-progress"
```

When the tracker state does not cleanly map to an abstract state, prefer the closest match and log: "Tracker state '<state>' mapped to abstract '<abstract>' — verify this is correct."
