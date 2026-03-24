#!/usr/bin/env bash
# =============================================================================
# validate.sh — Harness structural validation test suite (generic)
#
# Validates plugin structure, frontmatter, MCP config, secrets, and links.
# Runnable as pre-commit hook or in CI.
#
# Usage:  bash test/validate.sh
# Exit:   0 = all pass, 1 = one or more failures
# =============================================================================

set -uo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FRONTMATTER_VALIDATOR="$SCRIPT_DIR/validate-frontmatter.sh"

PASS_COUNT=0
FAIL_COUNT=0

# CI mode: detect non-interactive environment
CI_MODE=0
if [[ ! -t 1 ]] || [[ "${CI:-}" == "true" ]] || [[ "${CI:-}" == "1" ]]; then
    CI_MODE=1
fi

# Color output (disable if not a terminal / in CI)
if [[ -t 1 ]] && [[ "$CI_MODE" -eq 0 ]]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    GREEN=''
    RED=''
    BOLD=''
    RESET=''
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    printf "${GREEN}[PASS]${RESET} %s\n" "$1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf "${RED}[FAIL]${RESET} %s\n" "$1"
}

check_file_exists() {
    local file="$1"
    local label="${2:-$file}"
    if [[ -f "$PROJECT_ROOT/$file" ]]; then
        pass "$label exists"
    else
        fail "$label missing"
    fi
}

check_dir_exists() {
    local dir="$1"
    local label="${2:-$dir}"
    if [[ -d "$PROJECT_ROOT/$dir" ]]; then
        pass "$label/ directory exists"
    else
        fail "$label/ directory missing"
    fi
}

# ---------------------------------------------------------------------------
# 1. Plugin Structure Validation
# ---------------------------------------------------------------------------
echo ""
echo "${BOLD}=== 1. Plugin Structure ===${RESET}"

check_file_exists ".claude-plugin/plugin.json" "plugin.json"

# Validate JSON
if [[ -f "$PROJECT_ROOT/.claude-plugin/plugin.json" ]]; then
    if jq empty "$PROJECT_ROOT/.claude-plugin/plugin.json" 2>/dev/null; then
        pass "plugin.json is valid JSON"
    else
        fail "plugin.json is NOT valid JSON"
    fi

    # Required fields
    for field in name description version author license; do
        val=$(jq -r ".$field // empty" "$PROJECT_ROOT/.claude-plugin/plugin.json" 2>/dev/null)
        if [[ -n "$val" ]]; then
            pass "plugin.json has field '$field'"
        else
            fail "plugin.json missing field '$field'"
        fi
    done
fi

# Required directories
for dir in skills hooks doc test; do
    check_dir_exists "$dir"
done

# ---------------------------------------------------------------------------
# 2. MCP Configuration Validation
# ---------------------------------------------------------------------------
echo ""
echo "${BOLD}=== 2. MCP Configuration ===${RESET}"

check_file_exists ".mcp.json" ".mcp.json"

if [[ -f "$PROJECT_ROOT/.mcp.json" ]]; then
    if jq empty "$PROJECT_ROOT/.mcp.json" 2>/dev/null; then
        pass ".mcp.json is valid JSON"
    else
        fail ".mcp.json is NOT valid JSON"
    fi

    # Check each server entry
    SERVERS=$(jq -r '.mcpServers | keys[]' "$PROJECT_ROOT/.mcp.json" 2>/dev/null || true)
    for server in $SERVERS; do
        for field in type command args env; do
            val=$(jq -r ".mcpServers.\"$server\".${field} // empty" "$PROJECT_ROOT/.mcp.json" 2>/dev/null)
            if [[ -n "$val" ]]; then
                pass ".mcp.json server '$server' has '$field'"
            else
                fail ".mcp.json server '$server' missing '$field'"
            fi
        done

        # Security: check no credential values are non-empty
        # Exclude known config-only env vars (URLs, hosts, orgs) that are not secrets
        NON_EMPTY_CREDS=$(jq -r ".mcpServers.\"$server\".env // {} | to_entries[] | select(.value != \"\") | select(.key | test(\"_URL$|_HOST$|_ORG$|_BASE_URL$|_SITE$|_DOMAIN$\") | not) | .key" "$PROJECT_ROOT/.mcp.json" 2>/dev/null || true)
        if [[ -z "$NON_EMPTY_CREDS" ]]; then
            pass ".mcp.json server '$server' has no populated credentials"
        else
            for cred in $NON_EMPTY_CREDS; do
                fail ".mcp.json server '$server' has non-empty credential: $cred"
            done
        fi
    done
fi

# ---------------------------------------------------------------------------
# 3. Skill Frontmatter Validation
# ---------------------------------------------------------------------------
echo ""
echo "${BOLD}=== 3. Skill Frontmatter ===${RESET}"

# Auto-discover all skill directories
for skill_dir in "$PROJECT_ROOT"/skills/*/; do
    [[ -d "$skill_dir" ]] || continue
    skill="$(basename "$skill_dir")"
    # Skip shared references directory (not a skill)
    [[ "$skill" == "_shared" ]] && continue
    SKILL_FILE="$skill_dir/SKILL.md"
    if [[ ! -f "$SKILL_FILE" ]]; then
        fail "skills/$skill/SKILL.md does not exist"
        continue
    fi
    pass "skills/$skill/SKILL.md exists"

    # Validate frontmatter
    if OUTPUT=$(bash "$FRONTMATTER_VALIDATOR" "$SKILL_FILE" name description 2>&1); then
        pass "skills/$skill/SKILL.md has valid frontmatter (name, description)"
    else
        MISSING=$(echo "$OUTPUT" | grep "^MISSING:" | sed 's/^MISSING://')
        if [[ -n "$MISSING" ]]; then
            for m in $MISSING; do
                fail "skills/$skill/SKILL.md missing '$m' in frontmatter"
            done
        else
            fail "skills/$skill/SKILL.md frontmatter error: $OUTPUT"
        fi
    fi
done

# ---------------------------------------------------------------------------
# 4. Secret Scanning
# ---------------------------------------------------------------------------
echo ""
echo "${BOLD}=== 4. Secret Scanning ===${RESET}"

SECRET_PATTERNS=(
    'api_key\s*[:=]\s*["\x27][^"\x27]+["\x27]'
    'api_token\s*[:=]\s*["\x27][^"\x27]+["\x27]'
    'password\s*[:=]\s*["\x27][^"\x27]+["\x27]'
    'secret_key\s*[:=]\s*["\x27][^"\x27]+["\x27]'
    'Bearer\s+[A-Za-z0-9\-._~+/]+=*'
    '\bsk-[a-zA-Z0-9]{20,}'
    '\bAKIA[0-9A-Z]{16}\b'
    '[0-9a-zA-Z_-]{24}\.apps\.googleusercontent\.com'
    'AZURE_DEVOPS_PAT\s*[:=]\s*["\x27]?[A-Za-z0-9]{24,}'
    'AZURE_DEVOPS_TOKEN\s*[:=]\s*["\x27]?[A-Za-z0-9]{24,}'
    '-----BEGIN (RSA |EC |DSA )?PRIVATE KEY-----'
)

SECRET_FOUND=0
for pattern in "${SECRET_PATTERNS[@]}"; do
    MATCHES=$(grep -rEn "$pattern" "$PROJECT_ROOT" \
        --include="*.md" --include="*.json" --include="*.yml" --include="*.yaml" --include="*.sh" --include="*.env" \
        --exclude-dir=".git" \
        --exclude="validate.sh" \
        --exclude="validate-frontmatter.sh" \
        --exclude="test-helpers.sh" \
        2>/dev/null || true)
    if [[ -n "$MATCHES" ]]; then
        while IFS= read -r match; do
            fail "Potential secret found: $match"
            SECRET_FOUND=1
        done <<< "$MATCHES"
    fi
done

# High-entropy value scanning in .env files
ENV_FILES=$(find "$PROJECT_ROOT" -name "*.env" -not -path "*/.git/*" -not -path "*/node_modules/*" 2>/dev/null || true)
for env_file in $ENV_FILES; do
    HE_MATCHES=$(grep -En '^[A-Z_]+=[^\s]{16,}' "$env_file" 2>/dev/null \
        | grep -vE '=\s*(your_|TODO|CHANGEME|REPLACE|example|placeholder|xxx|<)' || true)
    if [[ -n "$HE_MATCHES" ]]; then
        while IFS= read -r match; do
            fail "High-entropy .env value: $(basename "$env_file"):$match"
            SECRET_FOUND=1
        done <<< "$HE_MATCHES"
    fi
done

if [[ "$SECRET_FOUND" -eq 0 ]]; then
    pass "No secrets detected in tracked files"
fi

# ---------------------------------------------------------------------------
# 7. CLAUDE.md Validation
# ---------------------------------------------------------------------------
echo ""
echo "${BOLD}=== 5. CLAUDE.md ===${RESET}"

check_file_exists "CLAUDE.md"

if [[ -f "$PROJECT_ROOT/CLAUDE.md" ]]; then
    LINE_COUNT=$(wc -l < "$PROJECT_ROOT/CLAUDE.md" | tr -d ' ')
    if [[ "$LINE_COUNT" -lt 500 ]]; then
        pass "CLAUDE.md is under 500 lines ($LINE_COUNT lines)"
    else
        fail "CLAUDE.md exceeds 500 lines ($LINE_COUNT lines)"
    fi
fi

# ---------------------------------------------------------------------------
# 8. File Structure Completeness
# ---------------------------------------------------------------------------
echo ""
echo "${BOLD}=== 6. File Structure Completeness ===${RESET}"

# Count skills dynamically
SKILL_COUNT=0
for skill_dir in "$PROJECT_ROOT"/skills/*/; do
    [[ -d "$skill_dir" ]] || continue
    if [[ -f "$skill_dir/SKILL.md" ]]; then
        SKILL_COUNT=$((SKILL_COUNT + 1))
    fi
done
if [[ "$SKILL_COUNT" -gt 0 ]]; then
    pass "Found $SKILL_COUNT skill(s) with SKILL.md"
else
    fail "No skills found with SKILL.md"
fi

# CHANGELOG.md
check_file_exists "CHANGELOG.md"

# ---------------------------------------------------------------------------
# 9. Link Validation
# ---------------------------------------------------------------------------
echo ""
echo "${BOLD}=== 7. Link Validation ===${RESET}"

LINK_ERRORS=0
while IFS= read -r mdfile; do
    STRIPPED=$(awk '/^```/{skip=!skip; next} !skip{print}' "$mdfile")
    LINKS=$(echo "$STRIPPED" | grep -oE '\]\([^)]+\)' | sed 's/^\](//' | sed 's/)$//' | grep -v '^http' | grep -v '^#' || true)
    if [[ -z "$LINKS" ]]; then
        continue
    fi
    MDDIR=$(dirname "$mdfile")
    while IFS= read -r link; do
        LINK_PATH="${link%%#*}"
        if [[ -z "$LINK_PATH" ]]; then
            continue
        fi
        TARGET="$MDDIR/$LINK_PATH"
        if [[ ! -f "$TARGET" && ! -d "$TARGET" ]]; then
            fail "Broken link in $(echo "$mdfile" | sed "s|$PROJECT_ROOT/||"): $link"
            LINK_ERRORS=$((LINK_ERRORS + 1))
        fi
    done <<< "$LINKS"
done < <(find "$PROJECT_ROOT" -name "*.md" -not -path "*/.git/*" -not -path "*/node_modules/*" -not -path "*/core/*" -not -path "*/templates/*")

if [[ "$LINK_ERRORS" -eq 0 ]]; then
    pass "All markdown file references resolve to existing files"
fi

# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------
echo ""
TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo "${BOLD}RESULTS: ${PASS_COUNT}/${TOTAL} passed, ${FAIL_COUNT} failed${RESET}"
echo ""

if [[ "$FAIL_COUNT" -gt 0 ]]; then
    exit 1
else
    exit 0
fi
