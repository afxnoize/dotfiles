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

assert_deny() {
  local name="$1" cmd="$2"
  local actual
  actual=$(_run "$cmd")
  if [ "$actual" = "deny" ]; then
    echo "  ✅ $name"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $name → $actual (expected: deny)"
    FAIL=$((FAIL + 1))
  fi
}

assert_pass() {
  local name="$1" cmd="$2"
  local actual
  actual=$(_run "$cmd")
  if [ "$actual" = "pass" ]; then
    echo "  ✅ $name"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $name → $actual (expected: pass)"
    FAIL=$((FAIL + 1))
  fi
}

echo "━━━ validate-bash.sh ━━━"

echo ""
echo "# 保護ブランチへの push をブロックする"
assert_deny "main ブランチへの push を拒否する"        "git push origin main"
assert_deny "master ブランチへの push を拒否する"       "git push origin master"
assert_deny "develop ブランチへの push を拒否する"      "git push origin develop"
assert_deny "development ブランチへの push を拒否する"  "git push origin development"
assert_deny "dev ブランチへの push を拒否する"          "git push origin dev"
assert_deny "release ブランチへの push を拒否する"      "git push origin release"
assert_deny "release/* ブランチへの push を拒否する"    "git push origin release/v1.0"
assert_deny "release の深いパスへの push を拒否する"    "git push origin release/hot/x"

echo ""
echo "# フラグ付きでも保護ブランチへの push をブロックする"
assert_deny "--force 付きでもブロックする"              "git push --force origin main"
assert_deny "-f 短縮形でもブロックする"                 "git push -f origin main"
assert_deny "--force-with-lease 付きでもブロックする"   "git push --force-with-lease origin main"
assert_deny "-u 付きでもブロックする"                   "git push -u origin main"

echo ""
echo "# main/master をパスセグメントに含むブランチもブロックする"
assert_deny "hotfix/main への push を拒否する"          "git push origin hotfix/main"
assert_deny "hotfix/master への push を拒否する"         "git push origin hotfix/master"
assert_deny "bugfix/main への push を拒否する"           "git push origin bugfix/main"
assert_deny "深いパスの main への push を拒否する"       "git push origin feature/sub/main"

echo ""
echo "# refspec のターゲットが保護ブランチならブロックする"
assert_deny "feature:main の refspec を拒否する"         "git push origin feature:main"
assert_deny "feature:release/v1 の refspec を拒否する"   "git push origin feature:release/v1"

echo ""
echo "# refspec のソースが保護名でもターゲットが非保護なら許可する"
assert_pass "main:feature はターゲットが非保護なので許可する" "git push origin main:feature"

echo ""
echo "# 保護名を前方一致で含むだけの別ブランチは許可する"
assert_pass "dev-feature は dev とは別ブランチなので許可する"     "git push origin dev-feature"
assert_pass "main-feature は main とは別ブランチなので許可する"   "git push origin main-feature"
assert_pass "developer は develop とは別ブランチなので許可する"   "git push origin developer"
assert_pass "release-notes は release/ ではないので許可する"      "git push origin release-notes"
assert_pass "my-dev-branch は dev を途中に含むだけなので許可する" "git push origin my-dev-branch"

echo ""
echo "# main/master 以外の保護名はパスセグメント内なら許可する"
assert_pass "hotfix/develop はセグメント検出対象外なので許可する" "git push origin hotfix/develop"
assert_pass "hotfix/dev はセグメント検出対象外なので許可する"     "git push origin hotfix/dev"
assert_pass "hotfix/release はセグメント検出対象外なので許可する" "git push origin hotfix/release"

echo ""
echo "# 非保護ブランチへの push を許可する"
assert_pass "feature ブランチへの push を許可する"           "git push origin feature-branch"
assert_pass "スラッシュ付き feature ブランチを許可する"      "git push origin feat/rtk-hook"
assert_pass "数字付き fix ブランチを許可する"                "git push origin fix/bug-123"
assert_pass "-u 付きの非保護ブランチ push を許可する"        "git push -u origin feature-x"

echo ""
echo "# remote・ブランチが省略された push をブロックする"
assert_deny "引数なし push を拒否する"                      "git push"
assert_deny "remote のみ指定の push を拒否する"             "git push origin"
assert_deny "リダイレクト付き bare push を拒否する"         "git push 2>&1"
assert_deny "フラグのみの push を拒否する"                  "git push --force"
assert_deny "フラグ+remote のみの push を拒否する"          "git push -u origin"

echo ""
echo "# チェーンコマンド内の文字列に誤反応しない"
assert_pass "コミットメッセージ内の main に反応しない"   "git commit -m 'fix main bug' && git push origin feat/x"
assert_pass "コミットメッセージ内の push に反応しない"   "git commit -m 'push to prod' && git push origin feat/x"
assert_pass "echo コマンド内の main に反応しない"        "echo main && git push origin feat/x"

echo ""
echo "# チェーン内でも push 部分が保護ブランチならブロックする"
assert_deny "チェーン後の main push を拒否する"          "git status && git push origin main"
assert_deny "チェーン後の hotfix/main push を拒否する"   "git diff && git push origin hotfix/main"

echo ""
echo "# 広範囲ステージングをブロックする"
assert_deny "git add -A を拒否する"     "git add -A"
assert_deny "git add --all を拒否する"  "git add --all"
assert_deny "git add . を拒否する"      "git add ."

echo ""
echo "# 破壊的 git 操作をブロックする"
assert_deny "git reset --hard を拒否する"    "git reset --hard HEAD~1"
assert_deny "git clean -f を拒否する"        "git clean -f"
assert_deny "git checkout -- を拒否する"     "git checkout -- src/main.rs"
assert_deny "git branch -D を拒否する"       "git branch -D feature"

echo ""
echo "# 状態変更を伴う gh 操作をブロックする"
assert_deny "gh pr merge を拒否する"       "gh pr merge 1"
assert_deny "gh pr close を拒否する"       "gh pr close 1"
assert_deny "gh issue close を拒否する"    "gh issue close 1"
assert_deny "gh issue delete を拒否する"   "gh issue delete 1"
assert_deny "gh repo delete を拒否する"    "gh repo delete owner/repo"
assert_deny "gh repo archive を拒否する"   "gh repo archive owner/repo"
assert_deny "gh release delete を拒否する" "gh release delete v1.0"

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
