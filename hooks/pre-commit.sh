#!/usr/bin/env bash
# travis Harness pre-commit hook — runs validation before commits
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "=== travis Harness Pre-Commit Validation ==="
bash "$REPO_ROOT/test/validate.sh"
