#!/bin/bash
# validate-bash.sh のユニットテスト
# Usage: bash test-validate-bash.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VB="$SCRIPT_DIR/validate-bash.sh"
PASS=0 FAIL=0

_run() {
  local result
  result=$(echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$1\"}}" | bash "$VB" 2>/dev/null) || true
  if [ -z "$result" ]; then echo "pass"
  else echo "$result" | jq -r '.hookSpecificOutput.permissionDecision // "pass"'; fi
}

assert() {
  local label="$1" cmd="$2" expect="$3"
  local actual
  actual=$(_run "$cmd")
  if [ "$actual" = "$expect" ]; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label → $actual (expected: $expect)"
    FAIL=$((FAIL + 1))
  fi
}

echo "━━━ validate-bash.sh ━━━"

echo ""
echo "# 保護ブランチへの push → deny"
assert "git push origin main"          "git push origin main"          deny
assert "git push origin master"         "git push origin master"        deny
assert "git push origin develop"        "git push origin develop"       deny
assert "git push origin development"    "git push origin development"   deny
assert "git push origin dev"            "git push origin dev"           deny
assert "git push origin release"        "git push origin release"       deny
assert "git push origin release/v1.0"   "git push origin release/v1.0"  deny
assert "git push origin release/hot/x"  "git push origin release/hot/x" deny

echo ""
echo "# フラグ付き push → deny"
assert "git push --force origin main"           "git push --force origin main"           deny
assert "git push -f origin main"                "git push -f origin main"                deny
assert "git push --force-with-lease origin main" "git push --force-with-lease origin main" deny
assert "git push -u origin main"                "git push -u origin main"                deny

echo ""
echo "# main/master パスセグメント → deny"
assert "git push origin hotfix/main"      "git push origin hotfix/main"      deny
assert "git push origin hotfix/master"     "git push origin hotfix/master"    deny
assert "git push origin bugfix/main"       "git push origin bugfix/main"      deny
assert "git push origin feature/sub/main"  "git push origin feature/sub/main" deny

echo ""
echo "# refspec ターゲット → deny"
assert "git push origin feature:main"       "git push origin feature:main"       deny
assert "git push origin feature:release/v1" "git push origin feature:release/v1" deny

echo ""
echo "# refspec ソースが保護名でもターゲットが非保護 → pass"
assert "git push origin main:feature" "git push origin main:feature" pass

echo ""
echo "# 境界値: 保護名を含むが別ブランチ → pass"
assert "git push origin dev-feature"   "git push origin dev-feature"   pass
assert "git push origin main-feature"  "git push origin main-feature"  pass
assert "git push origin developer"     "git push origin developer"     pass
assert "git push origin release-notes" "git push origin release-notes" pass
assert "git push origin my-dev-branch" "git push origin my-dev-branch" pass

echo ""
echo "# main/master 以外はセグメントでも pass"
assert "git push origin hotfix/develop" "git push origin hotfix/develop" pass
assert "git push origin hotfix/dev"     "git push origin hotfix/dev"     pass
assert "git push origin hotfix/release" "git push origin hotfix/release" pass

echo ""
echo "# 非保護ブランチ → pass"
assert "git push origin feature-branch"  "git push origin feature-branch" pass
assert "git push origin feat/rtk-hook"   "git push origin feat/rtk-hook"  pass
assert "git push origin fix/bug-123"     "git push origin fix/bug-123"    pass
assert "git push -u origin feature-x"    "git push -u origin feature-x"   pass

echo ""
echo "# 引数なし / remote のみ → pass"
assert "git push (引数なし)" "git push"        pass
assert "git push origin"     "git push origin" pass

echo ""
echo "# チェーンコマンド誤検知防止"
assert "commit msg に main → pass"  "git commit -m 'fix main bug' && git push origin feat/x"  pass
assert "commit msg に push → pass"  "git commit -m 'push to prod' && git push origin feat/x"  pass
assert "echo main → pass"           "echo main && git push origin feat/x"                      pass

echo ""
echo "# チェーン内の push が保護ブランチ → deny"
assert "chain + main"         "git status && git push origin main"         deny
assert "chain + hotfix/main"  "git diff && git push origin hotfix/main"    deny

echo ""
echo "# 他の危険コマンド → deny"
assert "git add -A"            "git add -A"                  deny
assert "git add --all"         "git add --all"               deny
assert "git add ."             "git add ."                   deny
assert "git reset --hard"      "git reset --hard HEAD~1"     deny
assert "git clean -f"          "git clean -f"                deny
assert "git checkout -- file"  "git checkout -- src/main.rs" deny
assert "git branch -D"         "git branch -D feature"       deny
assert "gh pr merge"           "gh pr merge 1"               deny
assert "gh pr close"           "gh pr close 1"               deny
assert "gh issue close"        "gh issue close 1"            deny
assert "gh issue delete"       "gh issue delete 1"           deny
assert "gh repo delete"        "gh repo delete owner/repo"   deny
assert "gh repo archive"       "gh repo archive owner/repo"  deny
assert "gh release delete"     "gh release delete v1.0"      deny

# --- summary ---
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
