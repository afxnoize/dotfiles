# git-wt Complete Reference

## Table of Contents

1. [Installation](#installation)
2. [Commands](#commands)
3. [Flags & Options](#flags--options)
4. [Configuration](#configuration)
5. [Environment Variables](#environment-variables)
6. [Shell Integration](#shell-integration)
7. [File Copying](#file-copying)
8. [Lifecycle Hooks](#lifecycle-hooks)
9. [Bare Repository Support](#bare-repository-support)
10. [Workflows](#workflows)
11. [Directory Structure](#directory-structure)

---

## Installation

```bash
# Homebrew
brew install k1LoW/tap/git-wt

# Go install
go install github.com/k1LoW/git-wt@latest

# Binary download
# GitHub Releases から OS/arch に合ったバイナリを取得
```

Requirements: Git 2.0+

---

## Commands

### List Worktrees

```bash
git wt              # テーブル形式（現在のworktreeは * マーク）
git wt --json       # JSON形式
```

JSON output:
```json
[
  {
    "path": "/absolute/path/to/worktree",
    "branch": "feature-branch",
    "head": "abc123def456",
    "current": true,
    "bare": false
  }
]
```

### Create / Switch

```bash
git wt <branch>              # ブランチ＋worktree作成、既存なら切替
git wt <branch> <start-point> # 特定のコミットから作成
```

ターゲット引数の解決順序:
1. ブランチ名（既存 or 新規）
2. worktreeディレクトリ名（basedir相対）
3. ファイルシステムパス（絶対 or 相対）

### Delete

```bash
git wt -d <branch>   # 安全な削除（マージ済みチェック、未マージなら失敗）
git wt -D <branch>   # 強制削除（マージ状態無視）
```

- main/master ブランチはデフォルトで削除不可（`--allow-delete-default` で解除）

---

## Flags & Options

| Flag | Purpose |
|------|---------|
| `--basedir <path>` | worktree配置ディレクトリ（`{gitroot}` テンプレート対応） |
| `--copyignored` | `.gitignore` 対象ファイルをコピー |
| `--copyuntracked` | 未追跡ファイルをコピー |
| `--copymodified` | 変更済みファイルをコピー |
| `--copy <pattern>` | コピー対象パターン（gitignore構文） |
| `--nocopy <pattern>` | コピー除外パターン |
| `--hook <cmd>` | 作成後に実行するコマンド |
| `--deletehook <cmd>` | 削除前に実行するコマンド |
| `--nocd` | 自動ディレクトリ切替を無効化 |
| `--no-switch-directory` | `--nocd` の deprecated エイリアス |
| `--relative` | 現在のサブディレクトリパスを出力に付加（対象サブディレクトリが存在しない場合はworktreeルートにフォールバック） |
| `--allow-delete-default` | デフォルトブランチの削除を許可 |
| `--json` | JSON形式で出力 |
| `--version` | バージョン表示 |
| `--help` | ヘルプ表示 |

**注意**: `--hook`, `--deletehook`, `--remover` 等のフラグは git config の値を**完全に置き換える**（追加ではない）。

---

## Configuration

3段階の優先順位: CLI flags > git config (`wt.*`) > built-in defaults

### Configuration Keys

| Key | Default | Purpose |
|-----|---------|---------|
| `wt.basedir` | `../{gitroot}-wt` | worktree配置先テンプレート |
| `wt.copyignored` | `false` | gitignored ファイルのコピー |
| `wt.copyuntracked` | `false` | 未追跡ファイルのコピー |
| `wt.copymodified` | `false` | 変更済みファイルのコピー |
| `wt.copy` | (empty) | コピー対象パターン |
| `wt.nocopy` | (empty) | コピー除外パターン |
| `wt.hook` | (empty) | 作成後フック |
| `wt.deletehook` | (empty) | 削除前フック |
| `wt.remover` | (empty) | カスタム削除コマンド（実行後 `git worktree prune` が自動実行） |
| `wt.nocd` | `false` | 自動cd制御（`false`: 常にcd / `true` or `all`: 常に無効 / `create`: 新規作成時のみ無効） |
| `wt.relative` | `false` | サブディレクトリ付加 |

### Examples

```bash
# basedir をカスタマイズ
git config wt.basedir "../worktrees"

# ファイルコピー有効化
git config wt.copyignored true
git config wt.copyuntracked true

# パターン指定
git config --add wt.copy "*.env"
git config --add wt.copy ".vscode/"
git config --add wt.nocopy "node_modules/"

# フック設定
git config --add wt.hook "npm install"
git config --add wt.hook "npm run build"
```

---

## Environment Variables

| Variable | Description |
|----------|-------------|
| `GIT_WT_SHELL_INTEGRATION=1` | シェル統合ラッパーが自動設定。現在worktree削除時にメインリポジトリパスを出力する等の挙動に影響 |

---

## Shell Integration

### Setup

```bash
# Zsh — ~/.zshrc に追加
eval "$(git wt --init zsh)"

# Bash — ~/.bashrc に追加
eval "$(git wt --init bash)"

# Fish — ~/.config/fish/config.fish に追加
git wt --init fish | source

# PowerShell — $PROFILE に追加
Invoke-Expression (git wt --init powershell | Out-String)
```

### What It Provides

- `git wt <branch>` 後の自動 `cd`
- ブランチ名・worktree名のタブ補完
- 環境変数 `GIT_WT_SHELL_INTEGRATION=1` のセット

---

## File Copying

worktree作成時にコミットされていないファイルを自動転送。

### File Types

- **ignored**: `.gitignore` にマッチするファイル（`wt.copyignored`）
- **untracked**: 未追跡ファイル（`wt.copyuntracked`）
- **modified**: 変更済み追跡ファイル（`wt.copymodified`）

### Pattern Matching

- `wt.copy`: gitignore構文で対象パターン指定（gitignored ファイルも含めてマッチ）
- `wt.nocopy`: gitignore構文で除外パターン指定（**`wt.copy` より優先**）
- basedir がリポジトリ内にある場合は循環コピー防止
- 個別ファイルのコピー失敗は警告（stderr）のみ、worktree作成は中断しない

### Optimization

- ファイルのタイムスタンプを保持
- macOS では `clonefile` による copy-on-write

---

## Lifecycle Hooks

### Creation Hooks (`wt.hook`)

worktree**新規作成後**に、新しいworktreeディレクトリ内で実行。既存worktreeへの切替時は実行されない。

```bash
git config --add wt.hook "npm install"
git config --add wt.hook "go generate ./..."
git config --add wt.hook "code ."
```

- 定義順に順次実行、失敗時は後続処理を中断（worktree自体は作成済み）
- 出力は stderr に送られる

### Deletion Hooks (`wt.deletehook`)

worktree削除前に、削除対象のworktreeディレクトリ内で実行。

```bash
git config --add wt.deletehook "git push origin HEAD"
git config --add wt.deletehook "npm run cleanup"
```

- 定義順に順次実行、失敗時は削除を中止（`-d` / `-D` 共通）
- `-d` vs `-D` の違いはブランチ削除時のマージチェック有無のみ

---

## Bare Repository Support

bare リポジトリでも全機能が動作。

### 4つのリポジトリコンテキスト

| State | Description |
|-------|-------------|
| BareRoot | bare リポジトリのルート |
| BareWorktree | bare リポジトリのworktree内 |
| NormalRoot | 通常リポジトリのルート |
| NormalWorktree | 通常リポジトリのworktree内 |

コンテキストは `git rev-parse` で自動検出。

---

## Workflows

### Feature Branch

```bash
git wt feature-new-ui          # ブランチ＋worktree作成
# 作業...コミット...
git wt -d feature-new-ui       # マージ後に削除
```

### Hotfix from Specific Branch

```bash
git wt hotfix-123 origin/main  # origin/main から hotfix ブランチ作成
```

### PR Review

```bash
git fetch origin pull/123/head:pr-123
git wt pr-123                  # レビュー用worktree
# テスト・レビュー
git wt -D pr-123               # 完了後に強制削除
```

### Context Switch

```bash
git wt                         # 一覧確認
git wt other-feature           # 別のworktreeに切替
```

### With Auto Setup

```bash
git config --add wt.hook "npm install"
git config --add wt.hook "npm run build"
git wt feature-branch          # 作成後に自動で npm install && build
```

---

## Directory Structure

リポジトリ名 `myproject` の場合（デフォルト設定）:

```
parent/
├── myproject/              # メインworktree
│   └── .git/
└── myproject-wt/           # basedir (default: ../{gitroot}-wt)
    ├── feature-x/
    │   └── .git
    ├── bugfix-123/
    │   └── .git
    └── experimental/
        └── .git
```

