# overlays

`nix/overlays/` の各 overlay がある理由と、版の決め方。

いつ読むか: `overlays/` のファイルを編集・削除するとき、または bun か happy-coder の挙動を調べるとき。

## happy-coder
- llm-agents の版を `overlays/happy-coder.nix` で包み、`HAPPY_CLAUDE_PATH` の既定値を `~/.nix-profile/bin/claude` にする
- 上流の `bin/happy` は未設定なら `command -v claude` を使うため、PATH の順序（`~/.local/bin` が先）次第で別の claude を拾う
- 効くのは端末から起動する local モードだけ。デーモンが起動する remote モード（スマホから起こすセッション）は happy に同梱の claude-agent-sdk の claude を使う。そちらの版は happy-coder の更新でしか上がらない
- store パスでなく profile を経由するのは、[`flake-latest-update`](flake-latest-update.md) で上がった claude を次の local セッションから使うため
- `--set-default` なので環境変数で上書きできる
- データ置き場は `HAPPY_HOME_DIR` で `$XDG_STATE_HOME/happy` に移している（実行時に解決し、デーモンは起動した happy から引き継ぐ）

## bun
- upstream の latest release に意図して固定し、nixpkgs の版には頼らない。理由は、nixpkgs の版が upstream より遅れ、同梱の brotli に脆弱性（bun 1.4.4 で修正）が残っていたため
- `bun-linux-x64` / `bun-linux-aarch64` を `flake = false` のファイル入力（upstream の latest release の zip）として持ち、`overlays/bun.nix` の overlay で `pkgs.bun` の `src` だけを差し替える（`flake.nix` の `overlays` から import する）
- `tools/bunx` と PATH 上の `bun` は同じ `pkgs.bun` なのでまとめて追従する
- 更新は [`flake-latest-update`](flake-latest-update.md) が毎日行う。手で上げるなら `nix flake update bun-linux-x64 bun-linux-aarch64`
- nixpkgs が追いついても、入力と overlay は削除しない
- linux 以外の system は nixpkgs の bun のまま
