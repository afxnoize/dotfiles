# dotfiles

chezmoi + Nix Home-Manager による設定ファイル管理リポジトリ。

## ブートストラップ（WSL / Linux 新規セットアップ）

新しい環境を最小工数で構築する手順。

### 1. リポジトリのクローン

```sh
# Ubuntu の場合（git/curl が無ければ）
sudo apt update && sudo apt install -y git curl

# Arch/Manjaro の場合
# paru -S git curl

git clone https://github.com/afxnoize/dotfiles.git ~/repos/github.com/afxnoize/dotfiles
cd ~/repos/github.com/afxnoize/dotfiles
```

### 2. Nix のインストール

[Determinate Systems installer](https://github.com/DeterminateSystems/nix-installer) を使用する（標準の NixOS installer ではない）。

```sh
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

### 3. Home-Manager の初回適用

全ツール（git, neovim, fzf, ripgrep, sops, age, mise, claude-code 等）が一括でインストールされる。

```sh
cd ~/repos/github.com/afxnoize/dotfiles/nix
nix run github:nix-community/home-manager -- switch --flake .#$USER --impure
```

> `--impure` は必須。flake.nix が `builtins.getEnv` で `$USER` / `$HOME` を参照するため。

以降の更新:

```sh
home-manager switch --flake .#$USER --impure
```

### 4. age 秘密鍵の配置

chezmoi のテンプレートが SOPS + age で暗号化された secrets を復号する。秘密鍵がないと `chezmoi apply` が失敗する。

```sh
mkdir -p ~/.config/sops/age
# 秘密鍵を安全な場所からコピー（Bitwarden, USB 等）
cp /path/to/keys.txt ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt
```

対応する公開鍵: `age1juuhykhva94kwg6ajntxk366zlpvwr0rxfcnkwkgmwmzm2qhg4ls97yeaz`

### 5. chezmoi の初期化と適用

chezmoi と symlink（`~/.local/share/chezmoi` → リポジトリ）は Step 3 の Home-Manager で設定済み。
適用時に mise のグローバルツール（rust, node, go, python 等）も自動インストールされる。

```sh
chezmoi apply
```

### 6. デフォルトシェルを Zsh に変更

Zsh は Step 3 の Home-Manager で Nix 経由でインストール済み。
`chsh` は `/etc/shells` に登録されたシェルしか受け付けないため、Nix の zsh パスを追加する。

```sh
echo "$HOME/.nix-profile/bin/zsh" | sudo tee -a /etc/shells
sudo mkdir -p /etc/zsh
echo 'export ZDOTDIR="$HOME"/.config/zsh' | sudo tee /etc/zsh/zshenv
chsh -s "$HOME/.nix-profile/bin/zsh"
```

ログインし直すと Zsh が起動する。zinit プラグインは初回起動時に自動インストールされる。

## 日常の操作

```sh
# 設定ファイルの差分確認・適用
chezmoi diff
chezmoi apply

# 実環境のファイルをリポジトリ管理下に追加
chezmoi add ~/.config/X

# Nix パッケージの更新
cd ~/repos/github.com/afxnoize/dotfiles/nix
home-manager switch --flake .#$USER --impure
```

## ディレクトリ構成

| パス | 説明 |
|------|------|
| `nix/` | Flake & Home-Manager 設定 |
| `dot_config/nvim/` | Neovim 設定 |
| `dot_config/tmux/` | tmux 設定（tpm, continuum, resurrect） |
| `dot_config/zsh/` | Zsh 設定（zinit, completions） |
| `dot_config/wezterm/` | WezTerm ターミナル設定 |
| `dot_config/zabrze/` | スニペット展開（git, chezmoi, AI 用） |
| `dot_config/claude/` | Claude Code 設定・スキル・hooks |
| `.chezmoiscripts/` | chezmoi ライフサイクルスクリプト |

## 注意事項

- Nix ビルドには常に `--impure` が必須
- `dot_` プレフィクスは chezmoi が `.` に変換する（`dot_config/` → `~/.config/`）
- `.chezmoiignore` で OS 別に管理対象を分岐している。ファイル追加時は対象 OS を確認すること
- secrets は SOPS + age で暗号化。`chezmoi apply` 時にテンプレート内で復号される
- flake.lock は GitHub Actions で毎週自動更新される
