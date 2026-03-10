## 言語
英語で思考し、日本語で回答してください。
出力は常にMarkdown形式にしてください

## Commit Rules
- Conventional Commits を使うこと
- type/scope は英語（feat, fix, docs など）
- subject / body は日本語で書く
- subject は短く（句点なし）
- Write a comprehensive body based on `git diff --staged`

## Project Overview
chezmoi + Nix Home-Manager によるdotfiles管理リポジトリ。

## Directory Guide
- `nix/` - Flake & Home-Manager 設定（`flake.nix`, `home.nix`, `modules/`, `tools/`）
- `dot_config/nvim/` - Neovim設定（lazy.nvim, LSP, Treesitter）
- `dot_config/tmux/` - tmux設定（tpm, continuum, resurrect）
- `dot_config/zsh/` - Zsh設定（zinit, completions）
- `dot_config/wezterm/` - Wezterm ターミナル設定
- `dot_config/zabrze/` - スニペット展開（git, chezmoi, AI用ショートカット）
- `dot_config/claude/` - Claude Code カスタムコマンド・スキル
- `.chezmoiscripts/` - chezmoi apply時のライフサイクルスクリプト
- `dosbin/` - Windows用バッチファイル

## Key Patterns
- **Nix modules**: `nix/modules/` 配下にgit・zsh等をモジュール分割
- **Chezmoi templates**: OS別の条件分岐は `.chezmoiignore` で管理
- **Zabrze snippets**: TOML形式、カテゴリ別に分割（`ai.toml`, `git.toml` 等）
- **Neovim**: `lua/` 配下にモジュール分割、`plugin/`・`after/plugin/` でlazy設定
