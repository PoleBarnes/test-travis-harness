# travis Harness — Hooks

Hooks for the travis Harness project. This covers both **Claude Code hooks** (session-time configuration) and **git hooks** (commit-time validation).

---

## Claude Code Hooks

The travis Harness uses Claude Code lifecycle hooks defined in `.claude/hooks.json` for safety and automation. All hooks execute as shell commands and do not consume AI context tokens.

### Hook Summary

| Hook | Event | Purpose |
|------|-------|---------|
| **SessionStart** (1) | Plugin loads | Injects environment variables required for subagent features |
| **SessionStart** (2) | Plugin loads | Verifies MCP server health and warns on missing credentials |
| **PreToolUse** | Before Bash commands | Blocks destructive commands: `rm -rf`, `git push --force`, `git reset --hard` |
| **PostToolUse** | After Write/Edit | Runs `test/validate.sh` when skills are modified |
| **Stop** | Session ends | Logs session activity summary (branch, commits, modified files) for timecard integration |

### SessionStart: Environment Setup

When Claude Code loads the travis Harness plugin, the first SessionStart hook runs automatically and injects environment variables required for subagent features used by `/implement` and `/pr`.

No manual action is needed — the hook runs on every session start.

### SessionStart: MCP Health Check

The second SessionStart hook verifies that MCP servers are configured in `.mcp.json` and that key credential environment variables are set. Warnings are printed to stderr if any are missing — the session continues regardless, but skills relying on those servers will report errors.

### PreToolUse: Destructive Command Blocker

The PreToolUse hook intercepts Bash tool calls and blocks dangerous commands before they execute:

| Blocked Pattern | Reason |
|----------------|--------|
| `rm -rf` | Recursive forced deletion can destroy project files |
| `git push --force` | Force push can overwrite remote history; use `--force-with-lease` instead |
| `git reset --hard` | Hard reset permanently discards uncommitted changes |

When a blocked command is detected, the hook returns a `block` decision with an explanation. The AI will see the block reason and suggest a safer alternative.

### PostToolUse: Validation After Edits

The PostToolUse hook triggers after any Write or Edit tool call that modifies files matching:
- `skills/*/SKILL.md`

It runs `test/validate.sh` silently. If validation fails, a warning is printed to stderr. This catches structural issues (missing frontmatter fields, broken links) immediately after edits rather than at commit time.

### Stop: Session Activity Summary

The Stop hook runs when a Claude Code session ends and logs a summary to stderr:

```
Session summary (2026-03-04 17:30:00): branch=feature/my-feature, commits_last_hour=3, files_modified=5
```

This data supports timecard integration — the `/timecard` skill can reference session activity when generating time entries.

---

## Git Hooks

Git hooks automate validation and quality checks as part of the development workflow.

### Available Git Hooks

| Hook | File | Description |
|------|------|-------------|
| **pre-commit** | `pre-commit` | Git-hookable symlink target — runs `test/validate.sh` before each commit |
| **pre-commit** | `pre-commit.sh` | Standalone script — same validation, runnable outside of git |

---

### Installation

Install hooks by creating symlinks from your local `.git/hooks/` directory to the scripts in this folder:

```bash
# From the repository root (preferred — uses git rev-parse for repo root detection)
ln -sf ../../hooks/pre-commit .git/hooks/pre-commit
```

Alternatively, you can symlink the `.sh` variant:

```bash
ln -sf ../../hooks/pre-commit.sh .git/hooks/pre-commit
```

After installation, the hook runs automatically on every `git commit`. If validation fails, the commit is blocked until issues are resolved.

To install all hooks at once (as more are added):

```bash
# From the repository root
for hook in hooks/*.sh; do
  name="$(basename "$hook" .sh)"
  ln -sf "../../hooks/${name}.sh" ".git/hooks/${name}"
done
```

---

### Running Manually

You can run any hook directly without committing:

```bash
# Run the pre-commit validation
bash hooks/pre-commit.sh
```

This is useful for checking your changes before staging them, or for CI/CD pipelines.

---

### Uninstalling

Remove the symlink to disable a hook:

```bash
rm .git/hooks/pre-commit
```

---

### Adding New Hooks

To add a new hook:

1. Create a script in this directory named `<hook-name>.sh` (e.g., `commit-msg.sh`)
2. Add the shebang line: `#!/usr/bin/env bash`
3. Add `set -euo pipefail` for safe execution
4. Make it executable: `chmod +x hooks/<hook-name>.sh`
5. Document it in this README
6. Install via symlink as described above
