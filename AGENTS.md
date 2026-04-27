## Commands

```bash
# chezmoi — 設定ファイルの反映・差分確認
chezmoi apply                # リポジトリの変更を実環境に反映
chezmoi diff                 # 適用前の差分を確認
chezmoi add ~/.config/X      # 既存ファイルをリポジトリ管理下に追加

# Nix Home-Manager — パッケージビルド（--impure 必須）
nix build --impure .#homeConfigurations.$USER.activationPackage
# リポジトリルートからの場合:
nix build --impure 'path:./nix#homeConfigurations.'$USER'.activationPackage'
```

## Project Overview
chezmoi + Nix Home-Manager の二段構成 dotfiles リポジトリ。役割分担は以下のとおり。

- chezmoi: 設定ファイルの配布・テンプレート展開・OS 別の差分管理
- Nix Home-Manager: 宣言的なパッケージ管理と再現可能な環境構築

## Directory Guide
- `nix/` - Flake & Home-Manager 設定 → 詳細は [`nix/CONVENTIONS.md`](nix/CONVENTIONS.md)
- `dot_config/nvim/` - Neovim設定 → 詳細は [`dot_config/nvim/CONVENTIONS.md`](dot_config/nvim/CONVENTIONS.md)
- `dot_config/tmux/` - tmux設定（tpm, continuum, resurrect）
- `dot_config/zsh/` - Zsh設定（zinit, completions）
- `dot_config/wezterm/` - Wezterm ターミナル設定
- `dot_config/zabrze/` - スニペット展開（git, chezmoi, AI用ショートカット）
- `dot_config/claude/` - Claude Code カスタムコマンド・スキル・hooks
- `.chezmoiscripts/` - chezmoi apply時のライフサイクルスクリプト
- `dosbin/` - Windows用バッチファイル

## 設定ファイル編集ルール
- 編集対象はリポジトリ内の `dot_*` ソースファイル。`~/.config/` 配下は chezmoi apply で生成される派生物なので、直接編集しても次の apply で上書きされる
- 未管理ファイルの新規作成時は、リポジトリに追加するかユーザーに確認する
- 反映は `chezmoi apply` でユーザーが行う（Claude 自身は実行しない）

## Commit Rules
- Conventional Commits 形式を使う
- type/scope は英語（feat, fix, docs など）
- subject / body は日本語で書く
- subject は短く、句点を付けない
- body は `git diff --staged` の内容にもとづき、変更点（何を）と動機（なぜ）を網羅的に書く

## Key Patterns
- **Nix modules**: `nix/modules/` 配下にgit・zsh等をモジュール分割
- **Chezmoi templates**: OS別の条件分岐は `.chezmoiignore` で管理
- **Zabrze snippets**: TOML形式、カテゴリ別に分割（`ai.toml`, `git.toml` 等）
- **Neovim**: `lua/` 配下にモジュール分割、`plugin/`・`after/plugin/` でlazy設定

## Gotchas
- Nix ビルドには `--impure` が必須（`builtins.getEnv` で環境変数を参照するため）
- `chezmoi apply` 後、zshrc は自動で `zcompile` される（`.chezmoiscripts/` 参照）
- `.chezmoiignore` でOS別に管理対象を分岐しているため、ファイル追加時は対象OSを確認すること
- `dot_` プレフィクスは chezmoi が `.` に変換する（例: `dot_config/` → `~/.config/`）
