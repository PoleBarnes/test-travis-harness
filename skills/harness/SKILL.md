---
name: harness
description: Diagnose harness health by auditing skills, hooks, and MCP servers. Trigger on "harness health", "diagnose issues", "plugin audit".
argument-hint: [audit | diagnose | check-mcp | dashboard | area-to-focus]
---

# Harness Diagnostics

Diagnose harness health and identify improvements.

## Request

Mode or focus area: **$ARGUMENTS**

## Current Harness State

- Plugin root: !`echo "$CLAUDE_PLUGIN_ROOT"`
- Plugin files: (use Glob tool on the plugin root path above for `skills/`, `hooks/`, `commands/`)
- CLAUDE.md size: (use Read tool on `CLAUDE.md` in project root)
- MCP config: (use Read tool on `.mcp.json` in project root)
- Plugin version: !`python3 -c "
import json, os
plugins_file = os.path.expanduser('~/.claude/plugins/installed_plugins.json')
installed = 'unknown'
try:
    with open(plugins_file) as f:
        d = json.load(f)
    for k, v in d.get('plugins', {}).items():
        if k.startswith('travis@'):
            installed = v[0].get('version', 'unknown')
            break
except: pass
market = os.path.join(os.environ.get('CLAUDE_PLUGIN_ROOT', ''), '.claude-plugin', 'marketplace.json')
available = 'unknown'
try:
    with open(market) as f:
        d = json.load(f)
    for p in d.get('plugins', []):
        if p.get('name') == 'travis':
            available = p.get('version', 'unknown')
            break
except: pass
if installed == available:
    print(f'v{installed} (up to date)')
elif installed != 'unknown' and available != 'unknown':
    print(f'v{installed} installed, v{available} available — run /travis:update')
else:
    print(f'v{installed} installed')
" 2>/dev/null || echo "unknown"`

## Instructions

### Determine Mode

Parse `$ARGUMENTS` to determine the diagnostic mode:

- **audit**: Full diagnostic scan — report findings without filing any tickets
- **diagnose**: Identify issues, present to user, file approved tickets via `/triage`
- **check-mcp**: Focus on MCP server health, versions, and configuration
- **dashboard**: Quick health summary of the entire harness (read-only)
- **Specific area** (e.g., "skills", "hooks", "context", "performance"): Focus diagnostics on that area
- **No arguments**: Default to **audit** mode

### Mode: Audit (Read-Only Scan)

Perform a full diagnostic scan:

1. **Skills audit**: Count skills, check frontmatter validity, verify argument handling, check for missing error handling
2. **Hooks audit**: Check hook coverage, identify repetitive manual actions that could be automated
3. **Context audit**: Measure CLAUDE.md line count (flag if >500 lines — large context files increase token usage and slow down responses), check for stale or redundant context
4. **MCP audit**: Verify all configured MCP servers, check for connection issues

Present a structured report:

```
## Harness Audit Report

### Overview
- Skills: [count] defined
- Hooks: [count] configured
- CLAUDE.md: [line count] lines
- MCP Servers: [count] configured

### Findings (ranked by impact)
1. [HIGH] [finding description]
2. [MEDIUM] [finding description]
3. [LOW] [finding description]

### Recommendations
- [actionable recommendation]
```

**No tickets are filed in audit mode.**

### Mode: Diagnose (Find Issues + File Tickets)

1. Perform the full audit (as above)
2. For each finding, formulate a specific improvement ticket:
   - Problem description with evidence
   - Proposed fix
   - Affected files
   - Acceptance criteria
   - Appropriate `harness:*` label (skill, hook, context, mcp, perf, test, docs)
3. **Present all proposed tickets to the user for approval** — tickets should only be filed after explicit confirmation because they create work items visible to the whole team
4. For each approved ticket, use `/triage` to create the work item
5. Report filed ticket keys

### Mode: Check-MCP

Focus specifically on MCP server diagnostics:

1. Read `.mcp.json` to identify all configured MCP servers
2. For each server, check:
   - Connection type (stdio, http, sse)
   - Whether the server starts successfully
   - Package version (for npm-based servers)
   - Whether newer versions are available
   - Configuration completeness (required env vars set)
3. Present an MCP health report:


```
## MCP Server Health

| Server           | Type  | Status | Version | Latest | Notes          |
|-----------------|-------|--------|---------|--------|----------------|
{% for server in mcp_servers %}
| {{server.name}} | {{server.type}} | OK | {{server.version}} | {{server.version}} | Up to date |
{% endfor %}
```


### Mode: Dashboard

See `references/dashboard-template.md` for full dashboard instructions and output format.

This is a fast, local-only status check.

### Mode: Focused Area

When a specific area is provided (e.g., `/harness skills`), run the full audit but only report on and prioritize findings for that area. Available focus areas:

- **skills**: Skill definition quality, argument handling, error handling
- **hooks**: Hook coverage, automation opportunities
- **context**: CLAUDE.md optimization, reference file organization
- **mcp**: MCP server health and configuration
- **performance**: Token usage, response times, unnecessary MCP calls

### Session State & Diagnostics Memory

For session state persistence, see `skills/_shared/references/session-state.md`.

After completing any diagnostic mode (audit, diagnose, check-mcp, or focused area):

1. **Write diagnostic findings to auto-memory**: Write a structured summary to `~/.claude/projects/*/memory/diagnostics.md`. Include date, mode run, finding count by severity, and key recommendations. Overwrite previous content to prevent unbounded growth.

2. **Update MEMORY.md**: Find or create a `## Diagnostic Notes` section and replace its content with a single line: `- Last /harness [mode]: [date] — [brief finding summary]`. Keep MEMORY.md under 200 lines.

3. **Update session-state.json**: Merge `lastUpdated` and `version` fields per the shared session state pattern.

### Critical Rules

1. **Read-only**: Diagnostics do NOT modify any files directly. All changes go through the triage-to-implementation pipeline, which ensures proper review and traceability.
2. **User approval**: No tickets are filed without explicit user approval.
3. **Triage pipeline**: All tickets are filed via `/triage`, which performs scope checking and requirement traceability.
4. **Evidence-based**: Every finding includes specific evidence (file paths, line counts, error messages) so that the resulting tickets are actionable.
