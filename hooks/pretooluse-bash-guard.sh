#!/usr/bin/env bash
# =============================================================================
# pretooluse-bash-guard.sh — PreToolUse Bash hook for destructive command blocking
# Requirement: REQ-travis-NFR-001 (Security)
#
# Reads JSON from stdin, extracts .tool_input.command, and blocks dangerous
# commands. Uses a blocklist approach that checks for the presence of dangerous
# flag combinations anywhere in the command, regardless of flag order, prefixes,
# or quoting tricks.
#
# Exit: Always 0. Outputs JSON {"decision":"block","reason":"..."} to block.
# =============================================================================

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

if [ -z "$CMD" ]; then
  exit 0
fi

# ---------------------------------------------------------------------------
# 1. rm with recursive+force (both flags present in any order)
#    Catches: rm -rf, rm -r -f, rm -fr, rm --recursive --force,
#             \rm -rf, command rm -rf, /bin/rm -rf, env rm -rf
#    ALLOWS:  rm -f single-file.txt (no -r, not recursive)
# ---------------------------------------------------------------------------
# Strip common command prefixes and resolve to bare command
# Match "rm" preceded by nothing, backslash, command, env, or absolute path
if echo "$CMD" | grep -qE '(^|[;&|]\s*)(\\?rm|command\s+rm|env\s+rm|/\S*/rm)\s'; then
  # Extract the rm invocation (everything after rm up to ; or | or end)
  RM_PART=$(echo "$CMD" | grep -oE '(\\?rm|command\s+rm|env\s+rm|/\S*/rm)\s[^;&|]*' | head -1)
  if [ -n "$RM_PART" ]; then
    HAS_RECURSIVE=false
    HAS_FORCE=false
    # Check for --recursive or -r (within combined short flags)
    if echo "$RM_PART" | grep -qE '\s--recursive(\s|$)'; then
      HAS_RECURSIVE=true
    elif echo "$RM_PART" | grep -qE '\s-[a-zA-Z]*r'; then
      HAS_RECURSIVE=true
    fi
    # Check for --force or -f (within combined short flags)
    if echo "$RM_PART" | grep -qE '\s--force(\s|$)'; then
      HAS_FORCE=true
    elif echo "$RM_PART" | grep -qE '\s-[a-zA-Z]*f'; then
      HAS_FORCE=true
    fi
    if $HAS_RECURSIVE && $HAS_FORCE; then
      echo '{"decision": "block", "reason": "Blocked: rm with recursive+force is destructive. Use targeted rm instead."}'
      exit 0
    fi
  fi
fi

# Also catch eval-based invocations: eval "rm -rf ..."
if echo "$CMD" | grep -qE 'eval\s+["\x27].*rm\s.*-[a-zA-Z]*r.*-[a-zA-Z]*f|eval\s+["\x27].*rm\s.*-[a-zA-Z]*f.*-[a-zA-Z]*r|eval\s+["\x27].*rm\s+-rf|eval\s+["\x27].*rm\s+--recursive\s+--force|eval\s+["\x27].*rm\s+--force\s+--recursive'; then
  echo '{"decision": "block", "reason": "Blocked: rm with recursive+force via eval is destructive. Use targeted rm instead."}'
  exit 0
fi

# ---------------------------------------------------------------------------
# 2. git push --force (but NOT --force-with-lease, which is safe)
#    Catches: git push --force, git push -f, git push origin main --force,
#             git push -uf, command git push --force
# ---------------------------------------------------------------------------
if echo "$CMD" | grep -qE '(^|[;&|]\s*)(\\?git|command\s+git|env\s+git|/\S*/git)\s+push\s'; then
  PUSH_PART=$(echo "$CMD" | grep -oE '(\\?git|command\s+git|env\s+git|/\S*/git)\s+push\s[^;&|]*' | head -1)
  if [ -n "$PUSH_PART" ]; then
    # Check for --force but NOT --force-with-lease
    HAS_FORCE_PUSH=false
    if echo "$PUSH_PART" | grep -qE '\s--force(\s|$)'; then
      HAS_FORCE_PUSH=true
    fi
    # Check for -f or combined flags containing f (e.g., -uf)
    # But only short flags that contain 'f', not --force-with-lease
    if echo "$PUSH_PART" | grep -qE '\s-[a-zA-Z]*f[a-zA-Z]*(\s|$)'; then
      HAS_FORCE_PUSH=true
    fi
    # Exclude --force-with-lease (safe variant)
    if echo "$PUSH_PART" | grep -qE '\s--force-with-lease'; then
      HAS_FORCE_PUSH=false
    fi
    if $HAS_FORCE_PUSH; then
      echo '{"decision": "block", "reason": "Blocked: git push --force can destroy remote history. Use --force-with-lease instead."}'
      exit 0
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 3. git reset --hard (flag can appear before or after ref)
#    Catches: git reset --hard, git reset HEAD~1 --hard,
#             command git reset --hard
# ---------------------------------------------------------------------------
if echo "$CMD" | grep -qE '(^|[;&|]\s*)(\\?git|command\s+git|env\s+git|/\S*/git)\s+reset\s'; then
  RESET_PART=$(echo "$CMD" | grep -oE '(\\?git|command\s+git|env\s+git|/\S*/git)\s+reset\s[^;&|]*' | head -1)
  if [ -n "$RESET_PART" ]; then
    if echo "$RESET_PART" | grep -qE '\s--hard(\s|$)'; then
      echo '{"decision": "block", "reason": "Blocked: git reset --hard discards uncommitted changes permanently."}'
      exit 0
    fi
  fi
fi

exit 0
