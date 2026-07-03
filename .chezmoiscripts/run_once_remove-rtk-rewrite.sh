#!/usr/bin/env bash
set -euo pipefail

CLAUDE_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/claude"
rm -f "$CLAUDE_CONFIG/hooks/rtk-rewrite.sh"
