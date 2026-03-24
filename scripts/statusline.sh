#!/usr/bin/env bash
# statusline.sh — Claude Code status line renderer
#
# Displays: user@host:~/cwd  branch*  ctx:XX%  Model  [session]  VIM_MODE
#
# Installed by /travis:setup — referenced from ~/.claude/settings.json:
#   "statusLine": { "type": "command", "command": "bash $CLAUDE_PLUGIN_ROOT/scripts/statusline.sh" }

input=$(cat)

# Core fields
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
vim_mode=$(echo "$input" | jq -r '.vim.mode // ""')
session_name=$(echo "$input" | jq -r '.session_name // ""')

# Shorten home directory to ~
home_dir="$HOME"
short_cwd="${cwd/#$home_dir/\~}"

# ANSI color codes using $'...' so the escape byte is embedded literally
RESET=$'\033[00m'
BOLD_GREEN=$'\033[01;32m'
BOLD_YELLOW=$'\033[01;33m'
BOLD_RED=$'\033[01;31m'
BOLD_BLUE=$'\033[01;34m'
BOLD_MAGENTA=$'\033[01;35m'
BOLD_CYAN=$'\033[01;36m'
DIM_WHITE=$'\033[02;37m'

# Git info (branch + dirty marker)
git_info=""
if [ -n "$cwd" ] && [ -d "$cwd" ]; then
  git_branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
  if [ -n "$git_branch" ]; then
    git_dirty=$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null | head -1)
    if [ -n "$git_dirty" ]; then
      git_info=" ${BOLD_YELLOW}${git_branch}*${RESET}"
    else
      git_info=" ${BOLD_GREEN}${git_branch}${RESET}"
    fi
  fi
fi

# Context window usage indicator
ctx_info=""
if [ -n "$used_pct" ]; then
  used_int=${used_pct%.*}
  if [ "$used_int" -ge 80 ]; then
    ctx_color="$BOLD_RED"
  elif [ "$used_int" -ge 50 ]; then
    ctx_color="$BOLD_YELLOW"
  else
    ctx_color="$BOLD_GREEN"
  fi
  ctx_info=" ${ctx_color}ctx:${used_int}%${RESET}"
fi

# Vim mode indicator
vim_info=""
if [ "$vim_mode" = "NORMAL" ]; then
  vim_info=" ${BOLD_MAGENTA}NORMAL${RESET}"
elif [ "$vim_mode" = "INSERT" ]; then
  vim_info=" ${BOLD_CYAN}INSERT${RESET}"
fi

# Session name (if set via /rename)
session_info=""
if [ -n "$session_name" ]; then
  session_info=" ${DIM_WHITE}[${session_name}]${RESET}"
fi

# Model badge
model_info=""
if [ -n "$model" ]; then
  model_info=" ${DIM_WHITE}${model}${RESET}"
fi

printf "%s%s@%s%s:%s%s%s%s%s%s%s%s%s" \
  "$BOLD_GREEN" "$(whoami)" "$(hostname -s)" "$RESET" \
  "$BOLD_BLUE" "$short_cwd" "$RESET" \
  "$git_info" "$ctx_info" "$model_info" "$session_info" "$vim_info"
