#!/bin/bash
# validate-bash.sh のユニットテスト
# Usage: bash test-validate-bash.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# In the chezmoi source tree the wrapper is named executable_validate-bash.sh.
VB="${VB:-$SCRIPT_DIR/validate-bash.sh}"
[ -f "$VB" ] || VB="$SCRIPT_DIR/executable_validate-bash.sh"
PASS=0 FAIL=0

# Throwaway repos so that `git push origin HEAD` can be resolved from cwd.
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
git init -q -b main "$WORK/on-main"
git init -q -b feat/x "$WORK/on-feature"

# _run <command> [cwd]
# The JSON is built with jq so that quotes, backslashes and newlines in the
# command survive; a malformed payload would otherwise look like "pass".
_run() {
  local payload result
  payload=$(jq -n --arg cmd "$1" --arg cwd "${2:-$WORK}" \
    '{tool_name: "Bash", cwd: $cwd, tool_input: {command: $cmd}}')
  result=$(printf '%s' "$payload" | bash "$VB" 2>/dev/null) || true
  if [ -z "$result" ]; then echo "pass"
  else echo "$result" | jq -r '.hookSpecificOutput.permissionDecision // "pass"'; fi
}

_assert() {
  local expected="$1" name="$2" cmd="$3" cwd="${4:-}"
  local actual
  actual=$(_run "$cmd" "$cwd")
  if [ "$actual" = "$expected" ]; then
    echo "  ✅ $name"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $name → $actual (expected: $expected)"
    FAIL=$((FAIL + 1))
  fi
}

assert_deny() { _assert deny "$@"; }
assert_pass() { _assert pass "$@"; }
assert_ask()  { _assert ask "$@"; }

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

echo ""
echo "# グローバルオプション・ラッパー・サブシェル越しでも検査する"
assert_deny "git -C . push を拒否する"                 "git -C . push origin main"
assert_deny "git -c k=v push を拒否する"               "git -c k=v push origin main"
assert_deny "git --no-pager push を拒否する"           "git --no-pager push origin main"
assert_deny "git --git-dir=.git push を拒否する"       "git --git-dir=.git push origin main"
assert_deny "-c alias での push を拒否する"            "git -c alias.p=push p origin main"
assert_deny "サブシェル内の push を拒否する"           "(git push origin main)"
assert_deny "コマンド置換内の push を拒否する"         'echo $(git push origin main)'
assert_deny "二重引用符内のコマンド置換を拒否する"     'echo "$(git push origin main)"'
assert_deny "バッククォート内の push を拒否する"       'echo `git push origin main`'
assert_deny "env 経由の push を拒否する"               "env git push origin main"
assert_deny "sudo 経由の push を拒否する"              "sudo git push origin main"
assert_deny "環境変数代入付きの push を拒否する"       "FOO=1 git push origin main"
assert_deny "rtk 経由の push を拒否する"               "rtk proxy git push origin main"
assert_deny "bash -c 内の push を拒否する"             "bash -c 'git push origin main'"
assert_deny "bash -lc 内の push を拒否する"            "bash -lc \"git push origin main\""
assert_deny "eval 内の push を拒否する"                'eval "git push origin main"'
assert_deny "絶対パスの git push を拒否する"           "/usr/bin/git push origin main"
assert_deny "if 内の push を拒否する"                  "if true; then git push origin main; fi"
assert_deny "波括弧グループ内の push を拒否する"       "{ git push origin main; }"
assert_deny "2 行目の push を拒否する"                 $'cd /tmp\ngit push origin main'
assert_deny "行継続をまたぐ push を拒否する"           $'git push \\\n origin main'
assert_deny "git -C 経由の reset --hard を拒否する"    "git -C . reset --hard HEAD~5"
assert_deny "git -C 経由の branch -D を拒否する"       "git -C /tmp branch -D feature"
assert_deny "git -C 経由の add -A を拒否する"          "git -C . add -A"
assert_deny "clean -df を拒否する"                     "git clean -df"
assert_deny "branch -d --force を拒否する"             "git branch -d --force feature"
assert_deny "checkout HEAD -- file を拒否する"         "git checkout HEAD -- src/main.rs"
assert_deny "gh -R 付きの pr merge を拒否する"         "gh -R owner/repo pr merge 1"
assert_deny "gh pr -R 付きの merge を拒否する"         "gh pr -R owner/repo merge 1"
assert_deny "env 経由の gh repo delete を拒否する"     "env GH_TOKEN=x gh repo delete owner/repo"

echo ""
echo "# 保護ブランチ判定の抜け道を塞ぐ"
assert_deny "+main (強制 refspec) を拒否する"          "git push origin +main"
assert_deny "引用符付きの main を拒否する"             "git push origin \"main\""
assert_deny "単引用符付きの main を拒否する"           "git push origin 'main'"
assert_deny "HEAD:main を拒否する"                     "git push origin HEAD:main"
assert_deny "refs/heads/main を拒否する"               "git push origin refs/heads/main"
assert_deny "feature:refs/heads/main を拒否する"       "git push origin feature:refs/heads/main"
assert_deny "main の削除 (:main) を拒否する"           "git push origin :main"
assert_deny "--delete main を拒否する"                 "git push origin --delete main"
assert_deny "--all を拒否する"                         "git push --all origin"
assert_deny "--mirror を拒否する"                      "git push --mirror origin"
assert_deny "main 上での push origin HEAD を拒否する"  "git push origin HEAD" "$WORK/on-main"
assert_deny "-C で main を指す push origin HEAD を拒否する" "git -C $WORK/on-main push origin HEAD" "$WORK/on-feature"
assert_pass "feature 上での push origin HEAD を許可する" "git push origin HEAD" "$WORK/on-feature"
assert_pass "+feature は許可する"                      "git push origin +feature-x"
assert_deny "ANSI-C 引用で隠した main を拒否する"      "git push origin \$'\\x6dain'"
assert_deny "ANSI-C 引用で隠した push を拒否する"      "git \$'\\160ush' origin main"
assert_ask  "波括弧展開で main になりうる push は確認する" "git push origin {main,x}"
assert_ask  "glob refspec は確認する"                  "git push origin 'refs/heads/*:refs/heads/*'"
assert_ask  "サブコマンドが変数のときは確認する"       'git ${SUB} origin main'
assert_ask  "ブランチ名が変数のときは確認する"         'git push origin "$BRANCH"'
assert_ask  "ブランチ名がコマンド置換のときは確認する" 'git push origin $(git branch --show-current)'

echo ""
echo "# 複数の push は全部検査する"
assert_deny "先行する main push を拒否する"            "git push origin main && git push origin feature/x"
assert_deny "echo で隠した main push を拒否する"       "git push origin main; echo git push a b"
assert_deny "後続の main push を拒否する"              "git push origin feature/x && git push origin main"

echo ""
echo "# コマンドではない文字列には反応しない"
assert_pass "echo 内の push 文字列は許可する"          'echo "git push origin main"'
assert_pass "コメント内の push は許可する"             "git status # git push origin main"
assert_pass "grep の引数にある push は許可する"        "git log --grep='git push origin main'"
assert_pass "引用符内の git reset --hard は許可する"   "git commit -m 'docs: git reset --hard is blocked'"
assert_pass "ヒアドキュメント本文の push は許可する"   $'git commit -m "$(cat <<\'EOF\'\nfix: tidy (wip\n\ngit push origin main\nEOF\n)"'
assert_pass "gh pr view は許可する"                    "gh pr view 1"
assert_pass "gh pr create は許可する"                  "gh pr create --title x --body y"
assert_pass "git status は許可する"                    "git status"
assert_pass "git checkout -b は許可する"               "git checkout -b feature/x"
assert_pass "git add 個別ファイルは許可する"           "git add README.md src/main.rs"
assert_pass "git branch -d は許可する"                 "git branch -d merged-branch"
assert_pass "git clean -n は許可する"                  "git clean -n"

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
