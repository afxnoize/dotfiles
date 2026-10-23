#!/usr/bin/env bash
# Move the stable NixOS pin (nixpkgs + home-manager) in nix/flake.nix to the newest release
# that is safe to adopt, then refresh flake.lock for those two inputs.
#
# Usage (from the repository root): nixos-release-bump.sh [--check]
#   --check  only report the release that would be adopted; change nothing
#
# A release is adopted only when
#   - nixpkgs has nixos-YY.MM and home-manager has release-YY.MM,
#   - it is newer than the current pin, and
#   - the month after YY.MM has begun. NixOS ships within its own month, so this never
#     picks up a beta, whatever the branch names do before the release.
# Only the .05 and .11 releases exist; other branch names (-small, unstable) are ignored.
#
# Env: FLAKE (flake.nix path), TODAY_YM (YYYYMM override, for tests), GITHUB_OUTPUT (set by Actions).
set -euo pipefail

FLAKE=${FLAKE:-nix/flake.nix}

# releases <prefix>: read branch names on stdin, print the YY.MM of each <prefix>-YY.MM, oldest first.
releases() {
  { grep -E "^$1-[0-9]{2}\.(05|11)$" || true; } | sed "s/^$1-//" | sort -V
}

# current_release: the YY.MM that nixpkgs is pinned to in $FLAKE.
current_release() {
  sed -n 's#.*github:NixOS/nixpkgs/nixos-\([0-9][0-9]\.\(05\|11\)\)".*#\1#p' "$FLAKE"
}

# newer <a> <b>: succeed when release a is newer than release b.
newer() {
  [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ]
}

# adoptable <YY.MM> <YYYYMM>: succeed once the month after YY.MM has begun.
adoptable() {
  local year month
  year=$((2000 + 10#${1%.*}))
  month=$((10#${1#*.} + 1))
  if [ "$month" -gt 12 ]; then
    year=$((year + 1))
    month=1
  fi
  [ "$2" -ge "$(printf '%04d%02d' "$year" "$month")" ]
}

# pick_release <current> <YYYYMM> <nixpkgs releases> <home-manager releases>
# Print the newest release that satisfies the rules above; print nothing when there is none.
pick_release() {
  local current=$1 today=$2 rel
  while read -r rel; do
    newer "$rel" "$current" || break
    grep -qx "$rel" <<<"$4" || continue
    adoptable "$rel" "$today" || continue
    echo "$rel"
    return
  done < <(sort -rV <<<"$3")
}

# fetch_branches <owner/repo> <prefix>: print the names of the branches that start with <prefix>-.
fetch_branches() {
  gh api "repos/$1/git/matching-refs/heads/$2-" --paginate --jq '.[].ref | sub("^refs/heads/"; "")'
}

# emit <key> <value>: expose a step output when running under Actions.
emit() {
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "$1=$2" >>"$GITHUB_OUTPUT"
  fi
}

main() {
  local check=0 current today nixpkgs_rels hm_rels target
  if [ "${1:-}" = "--check" ]; then check=1; fi

  current=$(current_release)
  if [ -z "$current" ]; then
    echo "cannot find the nixos-YY.MM pin in $FLAKE" >&2
    exit 1
  fi
  today=${TODAY_YM:-$(date -u +%Y%m)}
  nixpkgs_rels=$(fetch_branches NixOS/nixpkgs nixos | releases nixos)
  hm_rels=$(fetch_branches nix-community/home-manager release | releases release)

  target=$(pick_release "$current" "$today" "$nixpkgs_rels" "$hm_rels")
  if [ -z "$target" ]; then
    echo "pinned at $current; no newer release is adoptable"
    emit bumped false
    return 0
  fi
  echo "pinned at $current; adopting $target"
  if [ "$check" = 1 ]; then return 0; fi

  sed -i \
    -e "s#github:NixOS/nixpkgs/nixos-$current\"#github:NixOS/nixpkgs/nixos-$target\"#" \
    -e "s#github:nix-community/home-manager/release-$current\"#github:nix-community/home-manager/release-$target\"#" \
    "$FLAKE"
  # A URL that was not rewritten would leave nixpkgs and home-manager on different releases.
  if ! grep -q "github:NixOS/nixpkgs/nixos-$target\"" "$FLAKE" ||
    ! grep -q "github:nix-community/home-manager/release-$target\"" "$FLAKE"; then
    echo "failed to rewrite the nixpkgs / home-manager URLs in $FLAKE" >&2
    exit 1
  fi
  (cd "$(dirname "$FLAKE")" && nix flake update nixpkgs home-manager)

  emit bumped true
  emit release "$target"
}

# Sourced by the tests, which call the functions directly.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
