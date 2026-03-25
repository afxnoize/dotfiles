#!/bin/bash
# Validate AWS CLI commands via PreToolUse hook
# Reads patterns from aws-patterns.txt, supports deny/ask decisions

set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

[[ "$TOOL" == "Bash" && -n "$CMD" ]] || exit 0

# Prefer rg (ripgrep) over grep -P for PCRE matching
if command -v rg &>/dev/null; then
  pcre_match() { echo "$1" | rg -q "$2"; }
else
  pcre_match() { echo "$1" | grep -qP "$2"; }
fi

# Quick bail: skip if no aws command present
pcre_match "$CMD" '(^|[;&|] *)aws\s' || exit 0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATTERNS_FILE="$SCRIPT_DIR/aws-patterns.txt"

[[ -f "$PATTERNS_FILE" ]] || exit 0

respond() {
  local decision="$1" reason="$2"
  jq -n --arg d "$decision" --arg r "$reason" '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": $d,
      "permissionDecisionReason": $r
    }
  }'
  exit 0
}

while IFS='|' read -r pattern decision reason; do
  # Strip comments and blank lines
  pattern=$(echo "$pattern" | sed 's/#.*//;s/^[[:space:]]*//;s/[[:space:]]*$//')
  [[ -z "$pattern" ]] && continue

  decision=$(echo "$decision" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  reason=$(echo "$reason" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  if pcre_match "$CMD" "(^|[;&|] *)$pattern"; then
    respond "$decision" "$reason"
  fi
done < "$PATTERNS_FILE"

exit 0
