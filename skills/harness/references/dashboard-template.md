# Harness Diagnostics — Dashboard Template

Template and instructions for the dashboard mode (quick health summary).

## Dashboard Mode (Quick Health Summary)

Display a structured health overview of the entire harness. This mode reads local files and configuration only — no MCP calls, no ticket filing.

### Data Collection

1. **MCP Server Status**: Read `.mcp.json` and list each configured server with:
   - Server name and command type (uvx/npx/python3)
   - Whether the version is pinned (look for version in args like `==X.Y.Z` or `@X.Y.Z`)
   - Environment variable count and names

2. **Skill Inventory**: Glob `skills/*/SKILL.md` and list:
   - Total count of skills
   - Each skill name (from frontmatter)

3. **Test Health**: Check for test infrastructure:
   - Count test files in `test/skills/*.test.sh`
   - Report if `test/validate-frontmatter.sh` exists
   - Note any skills without corresponding test files

4. **Configuration Warnings**: Flag potential issues:
   - CLAUDE.md line count (warn if >500 lines)
   - Any skills missing `argument-hint` in frontmatter
   - MCP servers without version pinning

### Output Format

```
## travis Harness — Health Dashboard

### Plugin
- Version: [from Plugin version above — show update notice if one is available]

### MCP Servers ([count] configured)
| Server           | Command | Version Pinned | Env Vars |
|-----------------|---------|----------------|----------|

### Skills ([count] registered)
[list of skill names]

### Test Coverage
- Skill tests: [count] / [total skills]
- Frontmatter validator: [present/missing]
- Untested skills: [list any without test files]

### Warnings
- [any configuration issues found]
- [or "No warnings — harness is healthy"]
```

This is a fast, local-only status check.
