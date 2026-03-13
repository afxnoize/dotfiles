#!/bin/bash

# Bitwarden から persona / bossMode を取得して ~/.config/claude/CLAUDE.md のマーカー区間を更新する
# chezmoi apply 時のみ実行される（status/diff では走らない）
# マーカー外の内容（@RTK.md 等）はそのまま保持される

CLAUDE_MD="$HOME/.config/claude/CLAUDE.md"
BEGIN_MARKER="<!-- bw:begin -->"
END_MARKER="<!-- bw:end -->"

mkdir -p "$(dirname "$CLAUDE_MD")"

# ファイルが存在しなければ雛形を作成
if [ ! -f "$CLAUDE_MD" ]; then
  cat > "$CLAUDE_MD" <<EOF
@RTK.md

$BEGIN_MARKER
$END_MARKER
EOF
fi

# マーカーがなければ末尾に追加
if ! grep -qF "$BEGIN_MARKER" "$CLAUDE_MD"; then
  printf '\n%s\n%s\n' "$BEGIN_MARKER" "$END_MARKER" >> "$CLAUDE_MD"
fi

# Bitwarden から取得
bw_json=$(bw get item agent-settings 2>/dev/null)
if [ -n "$bw_json" ]; then
  persona=$(echo "$bw_json" | jq -r '.fields[] | select(.name == "persona") | .value // empty' 2>/dev/null)
  boss_mode=$(echo "$bw_json" | jq -r '.fields[] | select(.name == "bossMode") | .value // empty' 2>/dev/null)
fi

# マーカー区間を置換
block="${BEGIN_MARKER}"
[ -n "$persona" ] && block="${block}"$'\n'"${persona}"
[ -n "$boss_mode" ] && block="${block}"$'\n'"${boss_mode}"
block="${block}"$'\n'"${END_MARKER}"

sed -i "/${BEGIN_MARKER}/,/${END_MARKER}/c\\
$(echo "$block" | sed 's/$/\\/' | sed '$ s/\\$//')" "$CLAUDE_MD"
