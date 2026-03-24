#!/usr/bin/env bash
# SessionStart: check deps and plugin updates.

# ── Dependency check ──────────────────────────────────────────────────
for tool in node python3 uvx; do
    command -v "$tool" >/dev/null 2>&1 && continue
    echo "⚠ travis Harness: $tool is not installed. Run bash \$CLAUDE_PLUGIN_ROOT/install.sh to install dependencies."
    exit 0
done
# ── Update check ──────────────────────────────────────────────────────
_update_check_file="$HOME/.claude/plugins/.travis-update-check"
_now=$(date +%s 2>/dev/null || echo 0)
_last_check=0
[[ -f "$_update_check_file" ]] && _last_check=$(cat "$_update_check_file" 2>/dev/null || echo 0)

if (( _now - _last_check > 86400 )); then
    echo "$_now" > "$_update_check_file" 2>/dev/null || true
    _raw_url="https://raw.githubusercontent.com/PoleBarnes/travis-harness/main/.claude-plugin/plugin.json"
    _remote_json=$([ -n "$_raw_url" ] && curl -sf --max-time 5 "$_raw_url" 2>/dev/null || echo "")
    if [[ -n "$_remote_json" ]]; then
        _remote_ver=$(echo "$_remote_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('version',''))" 2>/dev/null || echo "")
        _local_ver=$(python3 -c "
import json, os
try:
    with open(os.path.expanduser('~/.claude/plugins/installed_plugins.json')) as f:
        d = json.load(f)
    for k, v in d.get('plugins', {}).items():
        if k.startswith('travis@'):
            print(v[0].get('version', ''))
            break
except: pass
" 2>/dev/null || echo "")
        if [[ -n "$_remote_ver" && -n "$_local_ver" && "$_remote_ver" != "$_local_ver" ]]; then
            echo "⟳ travis Harness v$_remote_ver available (installed: v$_local_ver) — run /travis:update"
        fi
    fi
fi
