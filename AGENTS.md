## 言語
英語で思考し、日本語で回答してください。
出力は常にMarkdown形式にしてください

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
chezmoi + Nix Home-Manager によるdotfiles管理リポジトリ。

## Directory Guide
- `nix/` - Flake & Home-Manager 設定 → 詳細は [`nix/CONVENTIONS.md`](nix/CONVENTIONS.md)
- `dot_config/nvim/` - Neovim設定 → 詳細は [`dot_config/nvim/CONVENTIONS.md`](dot_config/nvim/CONVENTIONS.md)
- `dot_config/tmux/` - tmux設定（tpm, continuum, resurrect）
- `dot_config/zsh/` - Zsh設定（zinit, completions）
- `dot_config/wezterm/` - Wezterm ターミナル設定
- `dot_config/zabrze/` - スニペット展開（git, chezmoi, AI用ショートカット）
- `dot_config/claude/` - Claude Code カスタムコマンド・スキル
- `.chezmoiscripts/` - chezmoi apply時のライフサイクルスクリプト
- `dosbin/` - Windows用バッチファイル

## 設定ファイル編集ルール
- **必ずこのリポジトリ内のソースファイル（`dot_*` 等）を編集すること。** `~/.config/` や `~/` 等の実体ファイルを直接編集してはならない
- 未管理ファイルの新規作成時は、リポジトリに追加するかユーザーに確認すること
- 反映は `chezmoi apply` でユーザーが行う

## Commit Rules
- Conventional Commits を使うこと
- type/scope は英語（feat, fix, docs など）
- subject / body は日本語で書く
- subject は短く（句点なし）
- Write a comprehensive body based on `git diff --staged`

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
