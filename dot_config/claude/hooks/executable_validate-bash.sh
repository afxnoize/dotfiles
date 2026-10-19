#!/bin/bash
# Validate Bash commands via PreToolUse hook.
# The rules live in validate-bash.ts (on top of the shared tokenizer in
# shell-parse.ts); this wrapper only keeps the hook path stable.

dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if ! command -v bun >/dev/null 2>&1; then
  # Without bun the guard cannot run: ask instead of silently allowing.
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"validate-bash: bun is not available, so the git/gh guard cannot run. Proceed?"}}'
  exit 0
fi

exec bun "$dir/validate-bash.ts"
