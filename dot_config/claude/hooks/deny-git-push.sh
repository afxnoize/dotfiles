#!/bin/bash
# Deny git push commands via PreToolUse hook
# Belt-and-suspenders with permissions.deny

set -euo pipefail

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$CMD" ]; then
  exit 0
fi

# Check if command contains git push (handles flags, pipes, &&, etc.)
if echo "$CMD" | grep -qE '(^|[;&|] *)git[[:space:]]+push([[:space:]]|$)'; then
  jq -n '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": "git push is blocked by policy. Ask the user to push manually."
    }
  }'
  exit 0
fi

exit 0
