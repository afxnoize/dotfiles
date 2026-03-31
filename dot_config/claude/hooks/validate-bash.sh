#!/bin/bash
# Validate Bash commands via PreToolUse hook
# Blocks dangerous git/gh operations

set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

[[ "$TOOL" == "Bash" && -n "$CMD" ]] || exit 0

deny() {
  jq -n --arg reason "$1" '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": $reason
    }
  }'
  exit 0
}

# Match command at start of line or after ; & | operators
PRE='(^|[;&|] *)'

# --- git: push to protected branches ---
PROTECTED_BRANCH='(main|master|development|develop|dev|release(/[^[:space:]]*)?)'
DENY_MSG="Push to protected branch is blocked. Ask the user to push manually."
if echo "$CMD" | grep -qE "${PRE}git[[:space:]]+push([[:space:]]|$)"; then
  # Extract only the git push sub-command args (exclude other chained commands)
  PUSH_ARGS=$(echo "$CMD" | sed -nE 's/.*git[[:space:]]+push([[:space:]][^;&|]*).*/\1/p')
  # Exact branch: git push origin main, git push origin release/v1.0
  echo "$PUSH_ARGS" | grep -qE "[[:space:]]${PROTECTED_BRANCH}([[:space:]]|$)" \
    && deny "$DENY_MSG"
  # main/master as path segment: git push origin hotfix/main
  echo "$PUSH_ARGS" | grep -qE "[[:space:]][^[:space:]]*/+(main|master)([[:space:]]|/|$)" \
    && deny "$DENY_MSG"
  # Refspec target: git push origin feature:main
  echo "$PUSH_ARGS" | grep -qE ":${PROTECTED_BRANCH}([[:space:]]|$)" \
    && deny "$DENY_MSG"
  # Refspec target with main/master segment: feature:hotfix/main
  echo "$PUSH_ARGS" | grep -qE ":[^[:space:]]*/+(main|master)([[:space:]]|/|$)" \
    && deny "$DENY_MSG"
  # Bare git push (no branch arg) — block unconditionally
  [[ -z "$PUSH_ARGS" || "$PUSH_ARGS" =~ ^[[:space:]]*$ ]] \
    && deny "Bare git push is blocked. Specify remote and branch explicitly, or ask the user to push."
fi

echo "$CMD" | grep -qE "${PRE}git[[:space:]]+add[[:space:]]+(-A|--all|\.($|[[:space:];|&]))" \
  && deny "git add -A / git add . is blocked. Specify file names explicitly."

echo "$CMD" | grep -qE "${PRE}git[[:space:]]+reset[[:space:]]+--hard" \
  && deny "git reset --hard is blocked. Ask the user before discarding changes."

echo "$CMD" | grep -qE "${PRE}git[[:space:]]+clean[[:space:]]+-f" \
  && deny "git clean -f is blocked. Ask the user before removing untracked files."

echo "$CMD" | grep -qE "${PRE}git[[:space:]]+checkout[[:space:]]+--[[:space:]]" \
  && deny "git checkout -- is blocked. Ask the user before discarding changes."

echo "$CMD" | grep -qE "${PRE}git[[:space:]]+branch[[:space:]]+-D" \
  && deny "git branch -D is blocked. Ask the user before force-deleting branches."

# --- gh: state-changing operations ---
echo "$CMD" | grep -qE "${PRE}gh[[:space:]]+pr[[:space:]]+merge" \
  && deny "gh pr merge is blocked. Ask the user to merge manually."

echo "$CMD" | grep -qE "${PRE}gh[[:space:]]+pr[[:space:]]+close" \
  && deny "gh pr close is blocked. Ask the user to close PRs manually."

echo "$CMD" | grep -qE "${PRE}gh[[:space:]]+issue[[:space:]]+close" \
  && deny "gh issue close is blocked. Ask the user to close issues manually."

echo "$CMD" | grep -qE "${PRE}gh[[:space:]]+issue[[:space:]]+delete" \
  && deny "gh issue delete is blocked. Ask the user to delete issues manually."

echo "$CMD" | grep -qE "${PRE}gh[[:space:]]+repo[[:space:]]+delete" \
  && deny "gh repo delete is blocked. Ask the user to delete repos manually."

echo "$CMD" | grep -qE "${PRE}gh[[:space:]]+repo[[:space:]]+archive" \
  && deny "gh repo archive is blocked. Ask the user to archive repos manually."

echo "$CMD" | grep -qE "${PRE}gh[[:space:]]+release[[:space:]]+delete" \
  && deny "gh release delete is blocked. Ask the user to delete releases manually."

exit 0
