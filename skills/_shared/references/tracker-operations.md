# Tracker Operations Reference

Normalized tracker operations across platforms. Skills reference named operations here instead of embedding platform-specific conditionals. Each operation maps to a concrete MCP tool call for the active platform.

## Platform: linear

---

## Operations

### fetch_item

Retrieve a work item by ID. Extract: title, description, acceptance criteria, status, assignee, priority, linked items.


**Server**: `linear`

1. Use `get_issue` from the **Linear** MCP server with the issue identifier
2. Extract fields:
   - `title` → title
   - `description` → description (markdown)
   - Parse description for `## Acceptance Criteria` section → acceptance_criteria
   - `state.name` → status
   - `assignee.name` → assignee
   - `priority` → priority (0=No priority, 1=Urgent, 2=High, 3=Medium, 4=Low)
   - `labels` → type
   - `relations` → linked items (query relations for blocking/blocked-by)
3. Use `get_issue_status` for detailed state information if needed


---

### update_status

Transition a work item to a new state. Use the Status Mapping table below to convert normalized states to platform-specific values.


**Server**: `linear`

1. Use `save_issue` from the **Linear** MCP server to update the issue state
2. Use `list_issue_statuses` to find the state ID matching the target status name
3. Set `stateId` to the resolved state ID
4. Linear supports direct state transitions without path constraints


---

### check_dependencies

Query dependency and blocking relationships for a work item.


**Server**: `linear`

1. Use `get_issue` to fetch the issue with its relations
2. Parse relations for:
   - `type == "blocks"` → blocking
   - `type == "blocked-by"` or `type == "depends-on"` → blocked_by
   - `type == "related"` → related
3. For each related issue, use `get_issue` or `get_issue_status` to check if resolved
4. Return: `{ blocking: [...], blocked_by: [...], related: [...] }` with identifiers and states


---

### link_artifact

Attach or link an artifact (PR, document, test result, V&V report) to a work item.


**Server**: `linear`

1. **PR link**: Use `create_attachment` from the **Linear** MCP server to attach the PR URL to the issue
2. **Document/report**: Use `create_attachment` with the document URL and a descriptive title
3. **Comment**: Use `save_comment` to add a comment with artifact summary and link
4. Linear supports URL attachments natively — use `create_attachment` for structured linking and `save_comment` for narrative context


---

### search_items

Search for work items matching criteria (for duplicate detection, dependency resolution, backlog queries).


**Server**: `linear`

Use `list_issues` from the **Linear** MCP server with filter parameters:

- Filter by team: set `teamId`
- Filter by state: use `list_issue_statuses` to resolve state IDs, then filter
- Filter by assignee: set `assigneeId` (resolve via `list_users`)
- Filter by label: set `labelId` (resolve via `list_issue_labels`)
- For keyword search: use the `query` parameter or filter results by title/description content
- For duplicate detection: search by title keywords, compare similarity of returned issues


---

### create_item

Create a new work item with normalized field mappings.


**Server**: `linear`

Use `save_issue` from the **Linear** MCP server to create an issue:

| Normalized Field | Linear Field | Notes |
|-----------------|-------------|-------|
| title | `title` | Required |
| description | `description` | Markdown format |
| acceptance_criteria | (in description) | Add as `## Acceptance Criteria` section in description |
| priority | `priority` | 0=No priority, 1=Urgent, 2=High, 3=Medium, 4=Low |
| type | `labelIds` | Resolve label ID via `list_issue_labels`, then attach |
| assignee | `assigneeId` | Resolve user ID via `list_users` |
| tags | `labelIds` | Resolve via `list_issue_labels` |
| team | `teamId` | Required — resolve via `list_teams` |

Include the requirement ID in the description for traceability. Linear requires `teamId` for issue creation.


---

## Status Mapping

Map normalized states to platform-specific state names.


| Normalized State | Linear State |
|-----------------|-------------|
| backlog | Backlog |
| todo | Todo |
| in_progress | In Progress |
| in_review | In Review |
| blocked | In Progress (+ "blocked" label) |
| done | Done |




**Config override**: This customer has a `status_map` in config. Use these values instead of the defaults above:

- todo → Todo

- in_progress → In Progress

- in_review → In Review

- done → Done

- blocked_tag → blocked



---

## Field Mapping


| Normalized Field | Linear Field |
|-----------------|-------------|
| title | `title` |
| description | `description` |
| acceptance_criteria | `description` (parsed section) |
| status | `state.name` |
| assignee | `assignee.name` |
| priority | `priority` (0-4 integer) |
| links | `relations` |
| type | `labels` |



---

## Dependency Model


Linear uses **issue relations** for dependencies:

- **Blocks**: This issue blocks another
- **Is blocked by / Depends on**: This issue depends on another
- **Related**: Informational link
- **Duplicate**: Marks an issue as a duplicate of another

Query relations via the issue's `relations` field. A dependency is resolved when the related issue's state is in the "Done" or "Completed" category. Use `get_issue_status` to verify.


---

## Error Handling

### MCP Server Unavailable

If the tracker MCP server (linear) is not responding or not configured:

1. Report clearly: "Tracker MCP server (linear) is unavailable. Operating in degraded mode."
2. Fall back to `session-state.json` for cached work item data — read `recentWorkItemIds` and any cached state from `orchestrator.itemStates`
3. Warn about staleness: "Using cached data from session-state.json (last updated: [timestamp]). State may be out of date."
4. **Never block the skill entirely** — degrade gracefully and proceed with available local data

### Field Not Found

If an expected field is missing from the work item response:

1. **Acceptance criteria**: Check the description body for an "Acceptance Criteria" heading or checklist as fallback
2. **Priority**: Default to "Medium" and warn: "Priority field not set — defaulting to Medium"
3. **Assignee**: Proceed without assignee context and note it as unassigned
4. Log a warning about the missing field but do not fail the operation

### Status Transition Failure


- Linear generally allows direct state changes. If a state name is not found, use `list_issue_statuses` to show available states and their IDs
- Report: "State '[name]' not found. Available states: [list]"


In all cases: report the failure clearly with a suggested manual action. Never silently swallow a transition error.
