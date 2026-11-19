## Nix Module Conventions

`nix/` を編集するときの規約。個別の仕組みの説明と運用手順は、次の文書に分けている。

- [`docs/overlays.md`](docs/overlays.md): `overlays/` を編集・削除するとき、bun か happy-coder の挙動を調べるとき
- [`docs/flake-latest-update.md`](docs/flake-latest-update.md): 毎日の自動更新で追う入力を変えるとき、timer やスクリプトを編集するとき、自動更新の結果を調べるとき
- [`docs/nixos-release-bump.md`](docs/nixos-release-bump.md): `nixpkgs` / `home-manager` の URL を変えるとき、`chore/nixos-release-bump` の PR を確認するとき
- [`../docs/ghtkn.md`](../docs/ghtkn.md): `modules/git/` の credential helper など、GitHub の認証（ghtkn）に触れるとき

### モジュール構成
- 各モジュールは `modules/<name>/default.nix` にディレクトリ単位で配置
- `modules/default.nix` が全サブモジュールをimportする集約ファイル
- 新規モジュール追加時は `modules/default.nix` のimportリストに追加すること

### Tools / Runtime Wrapper パターン
- `tools/mk-runtime-wrappers.nix` は、registry の「コマンド名 = パッケージ名」から wrapper を生成する汎用関数。実行行は呼び出し側が `mkExec = cmd: pkg: "..."` で渡す
- npm の CLI は `tools/bunx/registry.nix` に登録する。`tools/bunx/default.nix` の `mkExec` が `bunx --bun --package <パッケージ> <コマンド>` を組み立てる
- `--package` でパッケージとコマンドを分けて渡す。`bunx <コマンド>` だけだと、bunx が PATH 上の同名の wrapper 自身を呼んでしまう

```nix
# registry.nix の例
{
  takt = "takt";
  leaf = "@rivolink/leaf";
}
```

### Home-Manager Activation
- `home.activation.*` で DAG 順序制御を使用
- 必ず `lib.hm.dag.entryAfter [ "writeBoundary" ]` で実行順を指定すること

### パッケージソース
- **nixpkgs (stable)**: 通常のパッケージ
- **nixpkgs-unstable**: 最新版が必要なパッケージ（mise, uv, deno, git-wt 等）
- **外部 flake**: llm-agents, cage 等（`inputs` で定義）
- **mise**: moonbit だけ（nixpkgs にも llm-agents にも無いため）。グローバルのランタイムは Nix で持ち、プロジェクトのランタイムは flake の devShell と nix-direnv に任せる
- 最新版が要るパッケージの取り方: nixpkgs-unstable で足りるならそれ、毎日追うなら llm-agents、どちらにもなければ mise
- **overlay で包むもの**: happy-coder（`HAPPY_CLAUDE_PATH` の既定値）と bun（upstream の latest release に固定）。理由と更新方法は [`docs/overlays.md`](docs/overlays.md)
- **Go のソースビルド**: nixpkgs に無い Go のツールは `tools/gh-infra/` のように `pkgs-unstable.buildGoModule` で build する。版を上げたら `hash` と `vendorHash` を更新する。gh の拡張は `xdg.dataFile."gh/extensions/<名前>"` に `bin` をつないで `gh <名前>` で呼べるようにする（`programs.gh` は `config.yml` を読み取り専用にするので使わない）
- **カスタムバイナリ**: `tools/kakehashi/` のようにプラットフォーム別に分岐

### パッケージを nix に移すときの確認
- 名前の一致を同一性の根拠にしない。`nix eval --raw --inputs-from ./nix nixpkgs#<attr>.meta.homepage` が元の owner/repo と一致するか見る。nixpkgs には同名の別ソフトがある（例: `qq` は Tencent QQ）。逆に別名で入っていることもある（例: `hl` は `hl-log-viewer`）
- nixpkgs の attribute と名前が衝突するときは、overlay で上書きせず、接頭辞付きの attribute 名で足す。上書きすると、その attribute に依存する他のパッケージにも中身の違うものが渡る
- 移行元が入れていたコマンドが全部あるか、`nix build --no-link --print-out-paths` の `bin/` を見て比べる。`meta.mainProgram` は代表の 1 つしか示さない
- `nix flake check` は評価しか見ない。bin の衝突は profile の構築で初めて出るため、activationPackage の build まで通す

### Claude Code の skills / plugins
- 外部リポジトリの skill と plugin は `modules/claude-code/` の `programs.claude-code` で入れる。取得元は `flake = false` の入力にし、版は `flake.lock` で固定する。更新は `hmu <入力名>`
- skill は `skills.<名前>` に入力のパスを渡す。リポジトリの一部だけを使うときは `"${inputs.<入力>}/skills/<パス>"` のようにディレクトリを指す。`configDir/skills/<名前>/` にファイルごとのリンクが張られる
- plugin は `plugins` にリポジトリのパスを渡す。module が `claude` を `--plugin-dir <パス>` 付きの wrapper で包むので、`claude-code` は `packages.nix` に入れない（`bin/claude` が衝突する）
- `settings` と `marketplaces` は使わない。どちらかを設定すると module が `settings.json` を生成し、chezmoi が管理する `dot_config/claude/settings.json` と衝突する
- 自分の skill は今までどおり `dot_config/claude/skills/` に置く。リポジトリ固有の skill と plugin は、そのリポジトリの `.claude/` で管理する

### Gotchas
- `--impure` が必須な理由はリポジトリ直下の `AGENTS.md` の Gotchas を見る
- `flake.lock` の更新は `nix flake update` で行う（手動編集しない）
- プラットフォーム固有の処理は `builtins.currentSystem` で分岐する
