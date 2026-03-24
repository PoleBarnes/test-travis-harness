#!/usr/bin/env bash
# validate-frontmatter.sh — Extract and validate YAML frontmatter from a .md file
# Usage: bash test/validate-frontmatter.sh <file> <required_field1> [required_field2] ...
# Exit code 0 = valid, non-zero = invalid
# Outputs field values as KEY=VALUE lines on stdout; errors on stderr

set -euo pipefail

FILE="${1:?Usage: validate-frontmatter.sh <file> <required_field>...}"
shift
REQUIRED_FIELDS=("$@")

if [[ ! -f "$FILE" ]]; then
    echo "ERROR: File not found: $FILE" >&2
    exit 1
fi

# Check that file starts with --- delimiter
FIRST_LINE=$(head -1 "$FILE")
if [[ "$FIRST_LINE" != "---" ]]; then
    echo "ERROR: $FILE does not start with frontmatter delimiter (---)" >&2
    exit 1
fi

# Extract frontmatter between first and second --- delimiters
FRONTMATTER=$(sed -n '2,/^---$/{ /^---$/d; p; }' "$FILE")

if [[ -z "$FRONTMATTER" ]]; then
    echo "ERROR: $FILE has empty frontmatter" >&2
    exit 1
fi

# Check closing delimiter exists (second ---)
DELIMITER_COUNT=$(grep -c '^---$' "$FILE" || true)
if [[ "$DELIMITER_COUNT" -lt 2 ]]; then
    echo "ERROR: $FILE missing closing frontmatter delimiter (---)" >&2
    exit 1
fi

# Validate each required field is present and non-empty
EXIT_CODE=0
for FIELD in "${REQUIRED_FIELDS[@]}"; do
    # Match "field:" at beginning of line, possibly with value
    VALUE=$(echo "$FRONTMATTER" | grep -E "^${FIELD}:" | head -1 | sed "s/^${FIELD}:[[:space:]]*//" || true)
    if [[ -z "$VALUE" ]]; then
        echo "MISSING:${FIELD}" >&2
        EXIT_CODE=1
    else
        echo "${FIELD}=${VALUE}"
    fi
done

exit "$EXIT_CODE"
