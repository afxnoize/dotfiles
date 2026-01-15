#!/usr/bin/env bash
set -euo pipefail

if ! command -v codex &>/dev/null; then
	echo "Error: codex CLI is not installed or not in PATH" >&2
	echo "Install: npm install -g @openai/codex" >&2
	exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

MODE="${1:-review}"
shift || true
QUERY="${*:-}"

PROMPT_FILE="$SKILL_DIR/prompts/${MODE}.md"

if [[ ! -f "$PROMPT_FILE" ]]; then
	echo "Unknown mode or missing prompt: $MODE" >&2
	exit 1
fi

PROMPT="$(cat "$PROMPT_FILE")"

codex exec \
  --sandbox read-only \
  --ask-for-approval on-request \
  "$PROMPT"$'\n\n'"User request: $QUERY"
