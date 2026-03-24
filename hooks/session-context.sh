#!/usr/bin/env bash
# =============================================================================
# session-context.sh — Working context summary (SessionStart hook)
#
# Reads .harness/working-context.md and prints a brief 2-3 line summary
# to the terminal so the user sees where they left off.
#
# Does NOT inject into Claude's conversation context.
#
# Exit: Always 0 (never blocks session start)
# =============================================================================

set -uo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARNESS_DIR="$PLUGIN_ROOT/.harness"
CONTEXT_FILE="$HARNESS_DIR/working-context.md"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Extract the most recent session log entry and compute relative time
get_last_session() {
    local line
    line=$(sed -n '/^## Session Log/,/^## /{ /^- /p; }' "$CONTEXT_FILE" | head -1)
    [[ -z "$line" ]] && return 1

    # Parse: - YYYY-MM-DD HH:MM: branch=<branch>, <N> commits, <M> files modified
    local timestamp branch commits files
    timestamp=$(echo "$line" | sed -n 's/^- \([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}\):.*/\1/p')
    branch=$(echo "$line" | sed -n 's/.*branch=\([^,]*\).*/\1/p')
    commits=$(echo "$line" | sed -n 's/.* \([0-9]*\) commits.*/\1/p')
    files=$(echo "$line" | sed -n 's/.* \([0-9]*\) files modified.*/\1/p')

    [[ -z "$timestamp" ]] && return 1

    # Compute relative time
    local then_epoch now_epoch diff_seconds
    then_epoch=$(date -d "$timestamp" +%s 2>/dev/null) || return 1
    now_epoch=$(date +%s)
    diff_seconds=$((now_epoch - then_epoch))

    local relative
    if [[ "$diff_seconds" -lt 60 ]]; then
        relative="just now"
    elif [[ "$diff_seconds" -lt 3600 ]]; then
        relative="$((diff_seconds / 60))m ago"
    elif [[ "$diff_seconds" -lt 86400 ]]; then
        relative="$((diff_seconds / 3600))h ago"
    else
        relative="$((diff_seconds / 86400))d ago"
    fi

    local detail=""
    [[ -n "$commits" ]] && detail="${commits} commits"
    [[ -n "$files" ]] && {
        [[ -n "$detail" ]] && detail="${detail}, "
        detail="${detail}${files} files modified"
    }

    echo "Last session (${relative}): ${branch:-unknown}${detail:+ — $detail}"
}

# Extract active work items (lines starting with "- " under ## Active Work)
get_active_work() {
    local items
    items=$(sed -n '/^## Active Work/,/^## /{/^- /p}' "$CONTEXT_FILE" | sed 's/^- //' | head -5)
    [[ -z "$items" ]] && return 1

    # Join multiple items with " | "
    echo "$items" | paste -sd '|' - | sed 's/|/ | /g'
}

# Extract parked items (lines starting with "- " under ## Parked Work)
get_parked_work() {
    local items
    items=$(sed -n '/^## Parked Work/,/^## /{/^- /p}' "$CONTEXT_FILE" | sed 's/^- //' | head -5)
    [[ -z "$items" ]] && return 1

    echo "$items" | paste -sd '|' - | sed 's/|/ | /g'
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    # Silently exit if no working context file
    [[ -f "$CONTEXT_FILE" ]] || exit 0

    local last_session active parked
    last_session=$(get_last_session 2>/dev/null) || last_session=""
    active=$(get_active_work 2>/dev/null) || active=""
    parked=$(get_parked_work 2>/dev/null) || parked=""

    # If nothing to show, exit silently
    [[ -z "$last_session" && -z "$active" && -z "$parked" ]] && exit 0

    echo ""
    [[ -n "$last_session" ]] && echo "  $last_session"

    # Build the Active/Parked line
    local status_line=""
    [[ -n "$active" ]] && status_line="Active: $active"
    [[ -n "$parked" ]] && {
        [[ -n "$status_line" ]] && status_line="$status_line | "
        status_line="${status_line}Parked: $parked"
    }
    [[ -n "$status_line" ]] && echo "  $status_line"
    echo ""

    exit 0
}

# Run main, but never fail (don't block session start)
main "$@" || exit 0
