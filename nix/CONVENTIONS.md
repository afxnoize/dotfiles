## Nix Module Conventions

### モジュール構成
- 各モジュールは `modules/<name>/default.nix` にディレクトリ単位で配置
- `modules/default.nix` が全サブモジュールをimportする集約ファイル
- 新規モジュール追加時は `modules/default.nix` のimportリストに追加すること

### Tools / Runtime Wrapper パターン
- `tools/mk-runtime-wrappers.nix` はランタイム（npx, bunx等）のラッパーを生成する汎用関数
- 各ツールは `registry.nix` にコマンド→パッケージのマッピングを定義
- 新しいコマンドを追加する場合は対応する `registry.nix` にエントリを追加する

```nix
# registry.nix の例
{
  takt = "@anthropic-ai/takt";   # コマンド名 = パッケージ名
}
```

### Home-Manager Activation
- `home.activation.*` で DAG 順序制御を使用
- 必ず `lib.hm.dag.entryAfter [ "writeBoundary" ]` で実行順を指定すること

### パッケージソース
- **nixpkgs (stable)**: 通常のパッケージ
- **nixpkgs-unstable**: 最新版が必要なパッケージ（mise, git-wt 等）
- **外部 flake**: llm-agents, cage 等（`inputs` で定義）
- **カスタムバイナリ**: `tools/kakehashi/` のようにプラットフォーム別に分岐

### claude-code の自動更新
- systemd user timer `claude-update`（月・木 03:00 JST）が `claude-code` 入力だけ `flake.lock` を更新し、`nh home switch` まで実行する。実体は `dot_local/bin/executable_claude-update.tmpl`、unit は `dot_config/systemd/user/`
- `nix/` に `flake.lock` 以外の未コミット変更があるとスキップする（switch は working tree 全体を適用するため、編集途中の状態を無人で反映しない）。`nix/` を編集したら commit するか手動で `hms` する
- GitHub API の rate limit で更新できない日は exit 1 で終わる（nix は警告だけで cached lock に戻るため、スクリプト側で検出している）。結果は `journalctl --user -u claude-update` で確認する
- 反映されるのは次回起動から。実行中の claude は旧バイナリのまま動き続ける
- timer の有効化は初回だけ手動: `systemctl --user daemon-reload && systemctl --user enable --now claude-update.timer`（`.chezmoiignore` の `.chezmoiscripts/*` で chezmoi scripts が無効なため、apply では有効化されない）

### Gotchas
- `builtins.getEnv` を使っているため `--impure` 必須
- `flake.lock` の更新は `nix flake update` で行う（手動編集しない）
- プラットフォーム固有の処理は `builtins.currentSystem` で分岐する
