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

### Agent Skills モジュール
- `modules/agent-skills/default.nix` で Claude Code スキルの自動インストールを管理
- インストール先は `$CLAUDE_CONFIG_DIR/skills/`（デフォルト: `~/.config/claude/skills/`）
- 作業ディレクトリは `$XDG_STATE_HOME` 配下に分離

### パッケージソース
- **nixpkgs (stable)**: 通常のパッケージ
- **nixpkgs-unstable**: 最新版が必要なパッケージ（mise, git-wt 等）
- **外部 flake**: llm-agents, cage 等（`inputs` で定義）
- **カスタムバイナリ**: `tools/kakehashi/` のようにプラットフォーム別に分岐

### Gotchas
- `builtins.getEnv` を使っているため `--impure` 必須
- `flake.lock` の更新は `nix flake update` で行う（手動編集しない）
- プラットフォーム固有の処理は `builtins.currentSystem` で分岐する
