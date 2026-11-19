#!/usr/bin/env bash
# Unit tests for windows-release-bump.sh (no network: the GitHub API calls are stubbed).
# Usage: bash windows-release-bump.test.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=windows-release-bump.sh
source "$SCRIPT_DIR/windows-release-bump.sh"
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

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

OLD_A=$(printf 'a%.0s' {1..64})
OLD_B=$(printf 'b%.0s' {1..64})
OLD_C=$(printf 'c%.0s' {1..64})
NEW_A=$(printf '1%.0s' {1..64})

write_fixture() {
  cat >"$WORK/config.dsc.yaml" <<EOF
        TestScript: |
          (Test-Release -Name Font -Sha256 '$OLD_A') -and
            (Test-Release -Name Tool -Sha256 '$OLD_B')
        SetScript: |
          Install-Release -Name Font -Sha256 '$OLD_A' -Dir \$fontDir -Extract 'Font-*.ttf' -RegisterFont \`
            -Url 'https://github.com/owner/font/releases/download/v5.0.3/Font_v5.0.3.zip'
          Install-Release -Name Tool -Sha256 '$OLD_B' -Dir \$dir -Extract '*' \`
            -Url 'https://github.com/owner/tool/releases/download/v1.0.0/Tool-1.0.0-portable.zip'
          Install-Release -Name Same -Sha256 '$OLD_C' -Dir \$dir -FileName same.exe \`
            -Url 'https://github.com/owner/same/releases/download/v2.0.0/same-v2.0.0.exe'
          \$installer = Save-Download -Url 'https://github.com/owner/nightly/releases/download/nightly/setup.exe'
          Install-Release -Name NirCmd -Sha256 '$OLD_C' -Dir \$dir -Extract '*' \`
            -Url 'https://www.nirsoft.net/utils/nircmd-x64.zip'
EOF
}

echo "pins"
write_fixture
_assert "reads each GitHub release URL with the hash on the line before it" \
  "owner/font	v5.0.3	Font_v5.0.3.zip	$OLD_A
owner/tool	v1.0.0	Tool-1.0.0-portable.zip	$OLD_B
owner/same	v2.0.0	same-v2.0.0.exe	$OLD_C" \
  "$(pins "$WORK/config.dsc.yaml")"

echo "next_asset"
_assert "keeps the v prefix in the name" "Cica_v5.1.0.zip" "$(next_asset Cica_v5.0.3.zip v5.0.3 v5.1.0)"
_assert "names without v" "BatteryHub-1.2.0-portable.zip" "$(next_asset BatteryHub-1.1.0-portable.zip v1.1.0 v1.2.0)"
_assert "tags without v" "tool_2.0_win.zip" "$(next_asset tool_1.9_win.zip 1.9 2.0)"

echo "newer"
_assert "newer minor" ok "$(newer v0.31.0 v0.30.0 && echo ok || echo no)"
_assert "same version" no "$(newer v1.1.0 v1.1.0 && echo ok || echo no)"
_assert "older version" no "$(newer v1.0.9 v1.1.0 && echo ok || echo no)"
_assert "compares numerically" ok "$(newer v1.10.0 v1.9.0 && echo ok || echo no)"

echo "main"
# Stubs: font has a new release, tool renamed its asset, same is up to date.
latest_release() {
  case $1 in
    owner/font) printf 'v5.1.0\nFont_v5.1.0.zip\tsha256:%s\n' "$NEW_A" ;;
    owner/tool) printf 'v1.1.0\nRenamed-1.1.0-portable.zip\tsha256:%s\n' "$NEW_A" ;;
    owner/same) printf 'v2.0.0\nsame-v2.0.0.exe\tsha256:%s\n' "$OLD_C" ;;
    *) echo "unexpected repo $1" >&2; return 1 ;;
  esac
}
asset_sha256() { echo "${2#sha256:}"; }

write_fixture
cp "$WORK/config.dsc.yaml" "$WORK/before.yaml"
export GITHUB_OUTPUT="$WORK/output"
: >"$GITHUB_OUTPUT"
DSC_FILES="$WORK/config.dsc.yaml" main --check >/dev/null 2>&1
_assert "--check changes nothing" "" "$(diff "$WORK/before.yaml" "$WORK/config.dsc.yaml")"

: >"$GITHUB_OUTPUT"
DSC_FILES="$WORK/config.dsc.yaml" main >/dev/null 2>&1
CONFIG=$(<"$WORK/config.dsc.yaml")
_assert "rewrites the URL" 1 "$(grep -c 'download/v5.1.0/Font_v5.1.0.zip' <<<"$CONFIG")"
_assert "rewrites the hash in TestScript and SetScript" 2 "$(grep -c "Font -Sha256 '$NEW_A'" <<<"$CONFIG")"
_assert "leaves no old hash of the bumped pin" 0 "$(grep -c "$OLD_A" <<<"$CONFIG" || true)"
_assert "leaves a renamed asset as is" 2 "$(grep -c "$OLD_B" <<<"$CONFIG")"
_assert "leaves the up-to-date pin as is" 1 "$(grep -c 'download/v2.0.0/same-v2.0.0.exe' <<<"$CONFIG")"
_assert "leaves URLs that are not pins as is" 2 "$(grep -c -e 'download/nightly/setup.exe' -e 'nircmd-x64.zip' <<<"$CONFIG")"
OUTPUT=$(<"$GITHUB_OUTPUT")
_assert "reports bumped" 1 "$(grep -c -x true <<<"$OUTPUT")"
_assert "reports the update" 1 "$(grep -c 'owner/font: v5.0.3 → v5.1.0' <<<"$OUTPUT")"
_assert "reports the renamed asset" 1 "$(grep -c 'owner/tool: v1.1.0 に Tool-1.1.0-portable.zip がない' <<<"$OUTPUT")"

echo
echo "passed: $PASS, failed: $FAIL"
[ "$FAIL" = 0 ]
