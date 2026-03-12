#!/usr/bin/env bash
# PostToolUse:Bash hook
# cage sandbox 起因の権限エラーを検知したら、Claude にプロンプトを注入する
set -euo pipefail

[[ "${IN_CAGE:-}" == "1" ]] || exit 0

INPUT=$(cat)

STDERR=$(echo "$INPUT" | jq -r '.tool_result.stderr // ""')
STDOUT=$(echo "$INPUT" | jq -r '.tool_result.stdout // ""')

# 権限エラーキーワードがなければ即終了
if ! printf '%s\n%s' "$STDOUT" "$STDERR" | grep -qiE 'permission denied|read-only file system|operation not permitted|landlock'; then
  exit 0
fi

jq -nc '{
  "user_message": "cage (Landlock) の権限エラーを検知しました。上記のエラー出力を分析して、`$XDG_CONFIG_HOME/cage/presets.yaml` への修正案を提示してください。パスは可能な限り環境変数（$CARGO_HOME, $XDG_CACHE_HOME, $DENO_DIR 等）で表現してください。"
}'
