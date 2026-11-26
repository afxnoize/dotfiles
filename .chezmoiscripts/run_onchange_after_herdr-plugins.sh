#!/usr/bin/env bash
set -euo pipefail

if ! command -v herdr &>/dev/null; then
  exit 0
fi

# plugin id and GitHub source
plugins=(
  "herdr-bar jeffarese/herdr-bar"
  "ez-corp.space-usage ezcorp-org/herdr-pc-ram-and-cpu-usage-overlay"
)

installed=$(herdr plugin list --json | jq -r '.result.plugins[].id')

for entry in "${plugins[@]}"; do
  read -r id source <<<"$entry"
  if grep -qxF "$id" <<<"$installed"; then
    continue
  fi
  herdr plugin install --yes "$source"
done
