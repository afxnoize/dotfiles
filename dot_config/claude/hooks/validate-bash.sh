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
# Match: git push [flags...] [remote] <protected-branch>
# Also match refspec format: feature:main
if echo "$CMD" | grep -qE "${PRE}git[[:space:]]+push[[:space:]]"; then
  # Check for protected branch as argument or refspec target (:main)
  echo "$CMD" | grep -qE "[[:space:]]${PROTECTED_BRANCH}([[:space:]]|$)" \
    && deny "Push to protected branch is blocked. Ask the user to push manually."
  echo "$CMD" | grep -qE ":${PROTECTED_BRANCH}([[:space:]]|$)" \
    && deny "Push to protected branch is blocked. Ask the user to push manually."
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
