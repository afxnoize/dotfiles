#!/usr/bin/env bash
# Unit tests for nixos-release-bump.sh (pure functions only; no network, no nix).
# Usage: bash nixos-release-bump.test.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=nixos-release-bump.sh
source "$SCRIPT_DIR/nixos-release-bump.sh"
PASS=0 FAIL=0

_assert() {
  local name="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  ✅ $name"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $name"
    echo "     expected: '$expected'"
    echo "     actual:   '$actual'"
    FAIL=$((FAIL + 1))
  fi
}

# _succeeds <name> <command...>: assert that the command exits 0 / non-zero.
_succeeds() {
  local name="$1"
  shift
  if "$@"; then _assert "$name" ok ok; else _assert "$name" ok fail; fi
}
_fails() {
  local name="$1"
  shift
  if "$@"; then _assert "$name" fail ok; else _assert "$name" fail fail; fi
}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

echo "releases"
_assert "keeps only nixos-YY.MM, oldest first" "25.05
25.11
26.05" "$(printf '%s\n' nixos-26.05 nixos-25.11 nixos-25.05 | releases nixos)"
_assert "drops -small, unstable and other branches" "26.05" \
  "$(printf '%s\n' nixos-26.05 nixos-26.05-small nixos-unstable nixos-unstable-small nixos-26.07 | releases nixos)"
_assert "honours the prefix" "26.05" "$(printf '%s\n' release-26.05 nixos-25.11 | releases release)"
_assert "empty input gives empty output" "" "$(printf '' | releases nixos)"
_assert "no match gives empty output" "" "$(printf '%s\n' nixos-unstable | releases nixos)"
_assert "drops names that are not two-digit years" "25.05" "$(printf '%s\n' nixos-25.05 nixos-9.05 | releases nixos)"

echo "current_release"
cat >"$WORK/flake.nix" <<'EOF'
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
    };
  };
EOF
_assert "reads the nixpkgs pin" "25.11" "$(FLAKE="$WORK/flake.nix" current_release)"
printf '%s\n' 'nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";' >"$WORK/unpinned.nix"
_assert "no pin gives empty output" "" "$(FLAKE="$WORK/unpinned.nix" current_release)"

echo "newer"
_succeeds "26.05 is newer than 25.11" newer 26.05 25.11
_succeeds "25.11 is newer than 25.05" newer 25.11 25.05
_fails "equal is not newer" newer 25.11 25.11
_fails "25.05 is not newer than 25.11" newer 25.05 25.11

echo "adoptable"
_fails "not in the release month (26.05 in 2026-05)" adoptable 26.05 202605
_fails "not before the release (26.11 in 2026-10, the beta window)" adoptable 26.11 202610
_succeeds "from the month after (26.05 in 2026-06)" adoptable 26.05 202606
_succeeds "long after (26.05 in 2026-10)" adoptable 26.05 202610
_fails "not in the release month (26.11 in 2026-11)" adoptable 26.11 202611
_succeeds "26.11 in 2026-12" adoptable 26.11 202612
_succeeds "26.11 in 2027-01" adoptable 26.11 202701

echo "pick_release"
NP="25.05
25.11
26.05"
HM="25.05
25.11
26.05"
_assert "adopts the newer release" "26.05" "$(pick_release 25.11 202606 "$NP" "$HM")"
_assert "waits for the month after the release" "" "$(pick_release 25.11 202605 "$NP" "$HM")"
_assert "already on the newest" "" "$(pick_release 26.05 202610 "$NP" "$HM")"
_assert "pinned ahead of the lists" "" "$(pick_release 26.11 202612 "$NP" "$HM")"
_assert "skips a release home-manager lacks" "" "$(pick_release 25.11 202606 "$NP" "25.05
25.11")"
_assert "skips a release nixpkgs lacks" "" "$(pick_release 25.11 202606 "25.05
25.11" "$HM")"

NP2="$NP
26.11"
HM2="$HM
26.11"
_assert "ignores a beta and adopts the previous release" "26.05" "$(pick_release 25.11 202610 "$NP2" "$HM2")"
_assert "ignores a beta when already on the previous release" "" "$(pick_release 26.05 202610 "$NP2" "$HM2")"
_assert "adopts 26.11 once the month after has begun" "26.11" "$(pick_release 26.05 202612 "$NP2" "$HM2")"
_assert "prefers the newest adoptable release" "26.11" "$(pick_release 25.11 202612 "$NP2" "$HM2")"
_assert "falls back when the newest lacks home-manager" "26.05" "$(pick_release 25.11 202612 "$NP2" "$HM")"
_assert "empty lists give nothing" "" "$(pick_release 25.11 202606 "" "")"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━"
TOTAL=$((PASS + FAIL))
echo "Result: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  echo "⚠️  $FAIL tests failed"
  exit 1
else
  echo "All tests passed"
fi
