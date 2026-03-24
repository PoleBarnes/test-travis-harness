# Dependency Resolution Reference

Algorithm and procedures for building, validating, and querying the work item dependency graph. Used by `/orchestrate` for status, next, plan, start, and complete modes.

---

## Graph Construction

Build a directed acyclic graph (DAG) where edges represent "depends on" relationships.

### Pseudocode

```
function build_dependency_graph(project_key):
    # 1. Fetch all open work items
    items = search_items(project=project_key, state NOT IN [done, removed])

    # 2. Also fetch recently completed items (needed as dependency targets)
    done_items = search_items(project=project_key, state=done, limit=50)

    # 3. Build node map
    graph = {}
    for item in (items + done_items):
        graph[item.id] = {
            id: item.id,
            title: item.title,
            state: item.state,
            priority: item.priority,
            created: item.created_date,
            depends_on: [],      # items this node depends on (predecessors)
            depended_by: [],     # items that depend on this node (successors)
        }

    # 4. Query dependencies for each open item
    for item in items:
        deps = check_dependencies(item.id)

        for dep in deps.blocked_by:
            graph[item.id].depends_on.append(dep.id)
            if dep.id in graph:
                graph[dep.id].depended_by.append(item.id)

        for dep in deps.blocking:
            graph[item.id].depended_by.append(dep.id)
            if dep.id in graph:
                graph[dep.id].depends_on.append(item.id)

    return graph
```

### Platform-Specific Extraction

Use the **check_dependencies** operation from `tracker-operations.md` to extract dependencies. Each platform has its own dependency model:


- Linear: issue relations with `type == "blocks"` / `"blocked-by"` / `"depends-on"`


---

## Cycle Detection

Use depth-first search (DFS) with three-color marking to detect cycles.

### Algorithm (DFS with Coloring)

```
WHITE = 0  # Not yet visited
GRAY  = 1  # Currently being explored (on the recursion stack)
BLACK = 2  # Fully explored, no cycle through this node

function detect_cycles(graph):
    color = { id: WHITE for id in graph }
    parent = { id: null for id in graph }
    cycles = []

    for node_id in graph:
        if color[node_id] == WHITE:
            dfs_visit(graph, node_id, color, parent, cycles)

    return cycles

function dfs_visit(graph, node_id, color, parent, cycles):
    color[node_id] = GRAY

    for dep_id in graph[node_id].depends_on:
        if dep_id not in graph:
            continue  # External or deleted item — skip

        if color[dep_id] == GRAY:
            # Found a cycle — trace back through parent chain
            cycle = trace_cycle(parent, node_id, dep_id)
            cycles.append(cycle)

        elif color[dep_id] == WHITE:
            parent[dep_id] = node_id
            dfs_visit(graph, dep_id, color, parent, cycles)

    color[node_id] = BLACK

function trace_cycle(parent, start, end):
    # Walk from start back to end via parent pointers
    cycle = [end]
    current = start
    while current != end:
        cycle.append(current)
        current = parent[current]
    cycle.append(end)  # Close the cycle
    cycle.reverse()
    return cycle
```

### Reporting Cycles

When cycles are detected:

1. Report each cycle as a chain: `A → B → C → A`
2. For each link in the cycle, show the item IDs and titles
3. Ask the user which link to break — do not auto-resolve
4. After the user breaks a link, re-run cycle detection to verify

---

## Topological Sort with Priority Weighting

Produce an execution order that respects dependencies and prioritizes high-value work.

### Algorithm (Modified Kahn's Algorithm)

```
function topological_sort_weighted(graph):
    # 1. Compute in-degree (number of unresolved dependencies)
    in_degree = {}
    for node_id in graph:
        in_degree[node_id] = count(
            dep for dep in graph[node_id].depends_on
            if dep in graph and graph[dep].state != "done"
        )

    # 2. Initialize priority queue with zero in-degree nodes
    #    Priority key: (priority_rank, -unblocking_power, created_date)
    ready_queue = PriorityQueue()
    for node_id in graph:
        if in_degree[node_id] == 0 and graph[node_id].state != "done":
            score = compute_priority_score(graph, node_id)
            ready_queue.push(node_id, score)

    # 3. Process queue
    sorted_order = []
    while not ready_queue.empty():
        node_id = ready_queue.pop_highest()
        sorted_order.append(node_id)

        # Decrement in-degree for successors
        for succ_id in graph[node_id].depended_by:
            if succ_id in in_degree:
                in_degree[succ_id] -= 1
                if in_degree[succ_id] == 0 and graph[succ_id].state != "done":
                    score = compute_priority_score(graph, succ_id)
                    ready_queue.push(succ_id, score)

    # 4. Check for remaining nodes (indicates cycle if any)
    remaining = [id for id in graph if id not in sorted_order and graph[id].state != "done"]
    if remaining:
        # These nodes are in a cycle — report separately
        pass

    return sorted_order

function compute_priority_score(graph, node_id):
    node = graph[node_id]

    # Priority rank: Critical=4, High=3, Medium=2, Low=1, None=0
    priority_rank = map_priority_to_rank(node.priority)

    # Unblocking power: how many downstream items does this unblock?
    unblocking_power = count_downstream(graph, node_id)

    # Age: days since creation (older = higher priority)
    age_days = days_since(node.created)

    # Composite score (higher is better)
    # Weights: priority dominates, then unblocking power, then age
    return (priority_rank * 1000) + (unblocking_power * 100) + age_days

function count_downstream(graph, node_id):
    # Count all transitive successors (items that directly or indirectly depend on this)
    visited = set()
    stack = [node_id]
    while stack:
        current = stack.pop()
        for succ in graph[current].depended_by:
            if succ not in visited and succ in graph:
                visited.add(succ)
                stack.append(succ)
    return len(visited)
```

### Priority Mapping

| Platform Priority | Rank |
|-------------------|------|
| Critical / Urgent / P1 | 4 |
| High / P2 | 3 |
| Medium / P3 | 2 |
| Low / P4 | 1 |
| None / Unset | 0 |

---

## Ready State Computation

An item is "ready" (can be started) when:

1. Its `abstractState` is `planned` or `todo`
2. **All** items in its `depends_on` list are in `done` state
3. It is not involved in a cycle (or the cycle has been broken)

```
function compute_ready_items(graph):
    ready = []
    for node_id in graph:
        node = graph[node_id]
        if node.state not in ["planned", "todo", "backlog"]:
            continue

        all_deps_done = all(
            graph[dep].state == "done"
            for dep in node.depends_on
            if dep in graph
        )

        if all_deps_done:
            ready.append(node_id)

    return ready
```

---

## Edge Cases

### Orphan Items

Items with no dependencies and no dependents. These are standalone work that can be started at any time.

- **Detection**: `depends_on` is empty AND `depended_by` is empty
- **Handling**: Include in the ready queue if their state allows. Show separately in the Plan mode tree under "## Standalone Items"

### Items with No Dependencies

Items that depend on nothing but are depended on by others. These are root nodes in the graph.

- **Detection**: `depends_on` is empty, `depended_by` is non-empty
- **Handling**: Always ready (unless in a non-startable state). These are high-value targets because starting them unblocks downstream work.

### Self-Referencing Items

An item that lists itself in its own dependencies.

- **Detection**: `node_id in graph[node_id].depends_on`
- **Handling**: Remove the self-reference and warn: "Item <ID> references itself as a dependency. Ignoring self-reference."

### External Dependencies

A dependency on an item not in the current project or query results.

- **Detection**: `dep_id not in graph`
- **Handling**: Attempt to fetch the item by ID using **fetch_item**. If found, add to the graph. If not found, warn: "Dependency <dep_id> not found — may be in another project or deleted. Treating as resolved." Mark as resolved to avoid permanent blocking.

### Deleted Items as Dependencies

A dependency target that has been removed from the tracker.

- **Detection**: **fetch_item** returns not found for the dependency ID
- **Handling**: Warn: "Dependency <dep_id> no longer exists in the tracker. Treating as resolved." Remove from the `blocked_by` list in session state.

---

## Caching

Dependency resolution is expensive (multiple MCP calls per item). Cache results in session state.

### Cache Strategy

1. Store results in `orchestrator.itemStates[id].blockedBy` (array of IDs)
2. Set `orchestrator.lastDependencyCheck` timestamp on each full resolution
3. Cache TTL: consider results stale after 10 minutes
4. On Status mode: always do a full live resolution and refresh cache
5. On Start/Complete mode: do a targeted resolution for the specific item (live, not cached)
6. On Next mode: use cache if < 10 minutes old, otherwise refresh
