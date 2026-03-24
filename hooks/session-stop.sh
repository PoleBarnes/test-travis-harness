#!/usr/bin/env bash
# =============================================================================
# session-stop.sh — Capture session context on exit (Stop hook)
#
# Records git state (branch, commits, modified files) into
# .harness/working-context.md so the next session can pick up where
# this one left off.
#
# Exit: Always 0 (never blocks session shutdown)
# =============================================================================

set -uo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARNESS_DIR="$PLUGIN_ROOT/.harness"
CONTEXT_FILE="$HARNESS_DIR/working-context.md"
SESSION_MARKER="$HARNESS_DIR/.session-start"
MAX_LOG_ENTRIES=10

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

ensure_harness_dir() {
    mkdir -p "$HARNESS_DIR" 2>/dev/null || true
}

# Get the current git branch name
get_branch() {
    git -C "$PLUGIN_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown"
}

# Count commits made since session start
get_session_commits() {
    if [[ -f "$SESSION_MARKER" ]]; then
        local start_sha
        start_sha=$(cat "$SESSION_MARKER" 2>/dev/null)
        # Validate SHA format (defense-in-depth)
        if [[ "$start_sha" =~ ^[0-9a-f]{4,40}$ ]]; then
            git -C "$PLUGIN_ROOT" rev-list --count "${start_sha}..HEAD" 2>/dev/null || echo "0"
            return
        fi
    fi
    echo "0"
}

# Count modified/untracked files in working tree
get_modified_files_count() {
    git -C "$PLUGIN_ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' '
}

# Create the initial working-context.md template
create_template() {
    local now
    now=$(date '+%Y-%m-%d %H:%M')
    cat > "$CONTEXT_FILE" << 'TEMPLATE'
# Working Context

Last updated: TIMESTAMP_PLACEHOLDER

## Active Work

<!-- Current work items, one per line: - PROJ-123 (short description) -->

## Recent Decisions

<!-- Key decisions made during sessions, one per line -->

## Parked Work

<!-- Items set aside for later, one per line -->

## Session Log

<!-- Auto-populated by session-stop hook — most recent first -->
TEMPLATE
    sed -i "s|TIMESTAMP_PLACEHOLDER|$now|" "$CONTEXT_FILE"
}

# Update the "Last updated" timestamp in the file
update_timestamp() {
    local now
    now=$(date '+%Y-%m-%d %H:%M')
    if grep -q '^Last updated:' "$CONTEXT_FILE" 2>/dev/null; then
        sed -i "s|^Last updated:.*|Last updated: $now|" "$CONTEXT_FILE"
    fi
}

# Append a session log entry and trim to MAX_LOG_ENTRIES
append_session_log() {
    local branch="$1"
    local commits="$2"
    local files="$3"
    local now
    now=$(date '+%Y-%m-%d %H:%M')

    # Sanitize branch name: strip sed metacharacters to prevent injection
    local safe_branch
    safe_branch=$(printf '%s' "$branch" | tr -cd 'a-zA-Z0-9/_.-')
    local entry="- ${now}: branch=${safe_branch}, ${commits} commits, ${files} files modified"

    # Check if Session Log section exists
    if ! grep -q '^## Session Log' "$CONTEXT_FILE" 2>/dev/null; then
        printf '\n## Session Log\n\n%s\n' "$entry" >> "$CONTEXT_FILE"
        return
    fi

    # Insert the new entry right after "## Session Log" heading (and any comment line)
    # Find the line number of "## Session Log"
    local section_line
    section_line=$(grep -n '^## Session Log' "$CONTEXT_FILE" | head -1 | cut -d: -f1)
    [[ -z "$section_line" ]] && return

    # Find the first non-blank, non-comment line after the heading to insert before
    local insert_after="$section_line"
    local total_lines
    total_lines=$(wc -l < "$CONTEXT_FILE")

    # Skip blank lines and comment lines immediately after the heading
    local i=$((section_line + 1))
    while [[ "$i" -le "$total_lines" ]]; do
        local line
        line=$(sed -n "${i}p" "$CONTEXT_FILE")
        if [[ "$line" =~ ^[[:space:]]*$ ]] || [[ "$line" =~ ^\<!-- ]]; then
            insert_after="$i"
            i=$((i + 1))
        else
            break
        fi
    done

    # Insert the new entry after comments/blanks
    sed -i "${insert_after}a\\${entry}" "$CONTEXT_FILE"

    # Trim to keep only the last MAX_LOG_ENTRIES entries
    # Collect all log entry line numbers
    local entry_lines
    entry_lines=$(sed -n '/^## Session Log/,/^## /{/^- /=}' "$CONTEXT_FILE")
    local count
    count=$(echo "$entry_lines" | grep -c '[0-9]')

    if [[ "$count" -gt "$MAX_LOG_ENTRIES" ]]; then
        # Remove the oldest entries (those beyond MAX_LOG_ENTRIES from the top)
        local lines_to_remove
        lines_to_remove=$(echo "$entry_lines" | tail -n +"$((MAX_LOG_ENTRIES + 1))")
        # Delete from bottom up to preserve line numbers
        for ln in $(echo "$lines_to_remove" | sort -rn); do
            sed -i "${ln}d" "$CONTEXT_FILE"
        done
    fi
}

# Record the session start marker (HEAD sha at session start)
record_session_start() {
    ensure_harness_dir
    git -C "$PLUGIN_ROOT" rev-parse HEAD > "$SESSION_MARKER" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    ensure_harness_dir

    local branch commits files
    branch=$(get_branch)
    commits=$(get_session_commits)
    files=$(get_modified_files_count)

    # Create template if file doesn't exist or is empty
    [[ -s "$CONTEXT_FILE" ]] || create_template

    # Update timestamp
    update_timestamp

    # Append session log entry
    append_session_log "$branch" "$commits" "$files"

    # Reset session marker for next session
    record_session_start

    exit 0
}

# Run main, but never fail (don't block session shutdown)
main "$@" || exit 0
