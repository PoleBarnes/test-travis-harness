---
name: update
description: Update or upgrade the Harness plugin to the latest version. Trigger on "update plugin", "upgrade harness", "check for updates", or "get the latest version".
allowed-tools: Bash
---

# Harness Update

Update the travis Harness plugin to the latest available version.

## Current State

- Installed version: !`cat "$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('version','unknown'))" 2>/dev/null || echo "unknown"`
- Plugin root: !`echo "${CLAUDE_PLUGIN_ROOT:-not set}"`

## Instructions

### Step 1: Verify Environment

Before updating, confirm `CLAUDE_PLUGIN_ROOT` is set. If it is not set, the plugin is not properly installed — tell the user to install it first and stop.

### Step 2: Capture Current Version

Read the current version from `$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json` so you can compare it after the update completes. This comparison tells the user whether anything actually changed.

### Step 3: Run the Update

Execute the install script, which handles marketplace refresh and plugin update:

```bash
bash "$CLAUDE_PLUGIN_ROOT/install.sh"
```

The install script is idempotent — running it when already up-to-date is safe and produces no harmful side effects.

### Step 4: Compare Versions

After the install script completes, read the version from `plugin.json` again and compare:

- **Version changed**: Report the old and new versions. Instruct the user to restart Claude Code for changes to take effect.
- **Version unchanged**: Report that the plugin is already at the latest version. No restart needed.

### Step 5: Post-Update Guidance

If the version changed, tell the user:

1. Restart Claude Code to load the updated plugin
2. Run `/travis:setup --check` after restart to verify everything is configured correctly

## Error Handling

- **Install script not found**: If `$CLAUDE_PLUGIN_ROOT/install.sh` does not exist, report the missing file. The plugin installation may be corrupt — suggest reinstalling.
- **Install script fails**: If the script exits with a non-zero code, show the error output. Common causes: network issues, GitHub auth problems, or disk space.
- **Permission errors**: If the script cannot write to the plugin directory, suggest checking file permissions on `$CLAUDE_PLUGIN_ROOT`.
- **Version file unreadable**: If `plugin.json` cannot be parsed before or after the update, report this as a possible corruption issue.
