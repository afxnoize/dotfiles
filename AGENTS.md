## Commands

```bash
# Nix Home-Manager — パッケージビルド
nix build --impure .#homeConfigurations.$USER.activationPackage
# リポジトリルートからの場合:
nix build --impure 'path:./nix#homeConfigurations.'$USER'.activationPackage'
```

## Project Overview
chezmoi + Nix Home-Manager の二段構成 dotfiles リポジトリ。役割分担は以下のとおり。

- chezmoi: 設定ファイルの配布・テンプレート展開・OS 別の差分管理
- Nix Home-Manager: 宣言的なパッケージ管理と再現可能な環境構築

## Directory Guide
- `nix/` を編集するとき → [`nix/CONVENTIONS.md`](nix/CONVENTIONS.md)（Flake & Home-Manager 設定の規約）
- `dot_config/nvim/` を編集するとき → [`dot_config/nvim/CONVENTIONS.md`](dot_config/nvim/CONVENTIONS.md)（Neovim 設定の規約）

## 設定ファイル編集ルール
- 編集対象はリポジトリ内の `dot_*` ソースファイル。`~/.config/` 配下は chezmoi apply で生成される派生物なので、直接編集しても次の apply で上書きされる
- 未管理ファイルの新規作成時は、リポジトリに追加するかユーザーに確認する
- 反映は `chezmoi apply` でユーザーが行う（Claude 自身は実行しない）

## Document Rules
- **テーブル**: 2列まで許容。3列以上になるならリストに変換する
- **図**: Mermaid を使う

## Commit Rules
- Conventional Commits 形式を使う
- type/scope は英語（feat, fix, docs など）
- subject / body は日本語で書く
- subject は短く、句点を付けない
- body は `git diff --staged` の内容にもとづき、変更点（何を）と動機（なぜ）を網羅的に書く

## Gotchas
- Nix ビルドには `--impure` が必須（`builtins.getEnv` で環境変数を参照するため）
- `chezmoi apply` 後、zshrc は自動で `zcompile` される（`.chezmoiscripts/` 参照）
- `.chezmoiignore` でOS別に管理対象を分岐しているため、ファイル追加時は対象OSを確認すること
