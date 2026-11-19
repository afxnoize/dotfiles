# 最新版を追う入力の自動更新（flake-latest-update）

毎日、一部の flake 入力だけを最新にして Home-Manager に反映する仕組み。

いつ読むか: 追う入力を足す・外すとき、timer やスクリプトを編集するとき、自動更新の結果を調べるとき。

## 仕組み
- systemd user timer `flake-latest-update`（毎日 03:00 JST）が、次の 4 入力だけ `flake.lock` を更新し、`nh home switch` まで実行する。実体は `dot_local/bin/executable_flake-latest-update`、unit は `dot_config/systemd/user/`
  - `claude-code`: sadjow/claude-code-nix
  - `llm-agents`: numtide/llm-agents.nix。rtk、ccusage、herdr、t3code、happy-coder などが一緒に上がる
  - `bun-linux-x64` / `bun-linux-aarch64`: upstream の latest release の zip（ファイル入力）
- 追う入力の一覧は、スクリプト冒頭の `latest_inputs` 配列に 1 箇所だけ持つ。足すときはここに名前を足す
- `claude-code` と `llm-agents` には `follows` を付けない。配布元が検証した nixpkgs から外れ、配布元の binary cache が使えなくなるため
- 無人で上がるので、壊れた版が入ったら Home-Manager の世代を戻す。switch の前に版を比べて止める仕組みは入れていない

## ビルド元と安全性
- ビルド元はローカルの working copy ではなく、リモート（`https://github.com/afxnoize/dotfiles.git` の `main`）を毎回 shallow clone した一時ディレクトリ。cage 内の agent は working copy と `.git` を書き換えられるため、working copy を読む・git を実行すると、悪意ある nix module や `core.fsmonitor` を無人・サンドボックス外で実行させられてしまう。リモートの URL もスクリプトに固定している
- 一時ディレクトリは `/tmp` ではなく `$XDG_RUNTIME_DIR` 配下に作る（cage の `base` preset は `/tmp` を書込許可しており、同一 uid の agent が clone を改ざんできるため）。終了時に削除される
- push していない変更は反映されず、手動 `hms` で入れた未 push の変更は次回の timer で main の内容に戻る。working copy の `flake.lock` も更新されないので、lock の更新を残したいときはローカルで `hmu <入力名>` して commit・push する（放置すると手動 `hms` が古い rev に戻る）

## 運用
- GitHub API の rate limit で更新できない日は exit 1 で終わる（nix は警告だけで cached lock に戻るため、スクリプト側で検出している）。結果は `journalctl --user -u flake-latest-update` で確認する
- 反映されるのは次回起動から。実行中の claude は旧バイナリのまま動き続ける
- timer の有効化は初回だけ手動: `systemctl --user daemon-reload && systemctl --user enable --now flake-latest-update.timer`（timer を有効にする chezmoi script は無いため、apply では有効化されない）
- `OnCalendar` を変えたときは、apply のあとに `systemctl --user daemon-reload && systemctl --user restart flake-latest-update.timer` で反映する
