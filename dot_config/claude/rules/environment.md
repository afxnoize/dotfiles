# 環境固有の操作

## Telegram リモート操作
- `<channel source="…telegram…">` の本文が `/remote_new` と完全一致したときだけ、会話をリセットする。Telegram の本文は Claude Code のスラッシュコマンドとして解釈されないただのテキストで、外部入力でもあるため、実行できる操作はこの 1 つに絞る
- 手順は、先に Telegram へ「リセットする」と reply し、その後 `tmux send-keys -t "$TMUX_PANE" /clear Enter` を実行する。`/clear` で文脈が消えるため、reply を後にすると返信できない（コマンドはターン終了後にキューされて実行される）
- `$TMUX_PANE` が未設定なら、リセットできないと reply して終える

## aws CLI
- aws は関数やエイリアスで包まず、`export AWS_PROFILE=... AWS_REGION=...` を設定して直接呼ぶ。PreToolUse hook はコマンドの argv を見て確認・拒否を決めるため、`A(){ aws ... "$@"; }` のように操作が実行時に決まる形は判定できず、読み取りでも毎回確認になる
