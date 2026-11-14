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

> メモ: trusted user でないと、flake の `nixConfig` で指定した substituter は無視される。rtk・ccusage・neovim がソースビルドになり、初回は 30 分以上かかる。
> 回避は、root で `/etc/nix/nix.custom.conf` に次を追記して `nix-daemon` を再起動する。`trusted-users` に自分を足すのは root 相当になるので避ける。
>
> ```
> extra-substituters = https://cache.numtide.com https://nix-community.cachix.org
> extra-trusted-public-keys = niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=
> ```

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

## Windows

Windows は `windows/` を別の chezmoi ソースとして管理する。手順は [`windows/README.md`](windows/README.md) を読む。

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

## Telegram チャンネルの差し替え（supercharged）

公式 plugin の `server.ts` を [claude-telegram-supercharged](https://github.com/k1p1l0/claude-telegram-supercharged) v0.5.0 に差し替える。`telegram-supercharged` コマンド（`~/.local/bin`、Linux のみ）で入れて、いつでも戻せる。

```sh
telegram-supercharged status    # 今どちらが有効か
telegram-supercharged install   # 固定した版に差し替える（冪等）
telegram-supercharged restore   # 公式に戻す
```

- 入れるのは `server.ts` だけ。upstream の `install.sh` は使わない
  - `server.ts` 以外（skills、Mini App、launchd 用の supervisor、進捗フック）は、チャンネルを動かすのに要らない。upstream の `access` / `configure` skill は `~/.claude` 決め打ちで、`CLAUDE_CONFIG_DIR` を解決する公式のものより古いので、上書きしない
  - 進捗のライブ表示（Agentic Mode）は、supervisor が進捗フックを `--settings` で渡す前提のため、この差し替えだけでは動かない。使うなら、フックの導入を別に決める
  - 版は commit SHA で固定してある。HEAD は `server.ts` が `decisionTap` / `needsList` / `routerHook` を import するが、upstream の `install.sh` がこれらをコピーしないため、起動時に落ちる
  - 版を上げるときは、新しい版で `grep 'from "\./' server.ts` を確認し、`server.ts` の差分を読んでから、スクリプト内の `rev` を更新する
- 差し替え先は `installed_plugins.json` の user scope の `installPath`。最新バージョンのディレクトリを機械的に選ぶと、読み込まれない版を直して無反応になる
- 公式 plugin が更新されると新しいバージョンのディレクトリができ、差し替えが外れる。`install` を再実行すれば直る
- `install` は反映までに、Telegram を使う claude セッションの再起動が要る
- 作業用の clone は `$XDG_RUNTIME_DIR`（未設定なら `/run/user/<uid>`）に作る。cage から書ける `/tmp` では、検証とコピーの間に書き換えられうるため
- 公式と supercharged の `server.ts` は排他用のファイルが別（公式は `bot.pid`、supercharged は `data/telegram.lock`）で、互いを見ない。混ぜて動かすと 2 本が polling して 409 になり、DM はどちらかに落ちる
  - supercharged どうしなら、先に起動した 1 本だけが DM を受け取り、残りは送信のみの MCP モードになる
  - すでに動いている公式の `bun server.ts` は、再起動するまで古いコードのまま
  - project scope で入れた 0.0.4 は対象外。そのプロジェクトでは公式のまま動く
- `installed_plugins.json` の `installPath` やキャッシュ内の `server.ts*` は cage から書ける。スクリプトは、cache の外を指す・symlink になっている場合は書かずに止まる
- 受信メッセージは `~/.claude/channels/telegram/data/messages.db` に全件残る。`TELEGRAPH_ENABLED=true` にしない限り、長文を telegra.ph（公開）に投げることはない

導入後の確認:

- `telegram-supercharged status` が `supercharged 6dc3593` を示す
- 他の Telegram セッション（公式のままの `bun server.ts`）を止めてから、1 セッションだけ `claude --channels plugin:telegram@claude-plugins-official` で起動し直し、DM を送る。読んだ時点で 👀、返信後に 👍 が付く（長い作業では間に 🔥）。これは `server.ts` の instructions でモデルに頼んでいる動きで、保証ではない
- `telegram-supercharged restore` で戻したあとも、同じように動く

## ディレクトリ構成

| パス | 説明 |
|------|------|
| `nix/` | Flake & Home-Manager 設定 |
| `dot_config/nvim/` | Neovim 設定 |
| `dot_config/tmux/` | tmux 設定（tpm, continuum, resurrect） |
| `dot_config/zsh/` | Zsh 設定（zinit, completions） |
| `dot_config/wezterm/` | WezTerm ターミナル設定 |
| `dot_config/zabrze/` | スニペット展開（git, chezmoi, AI 用） |
| `dot_config/claude/` | Claude Code 設定・スキル・subagent・hooks |
| `.chezmoiscripts/` | chezmoi ライフサイクルスクリプト |

## 注意事項

- Nix ビルドには常に `--impure` が必須
- `dot_` プレフィクスは chezmoi が `.` に変換する（`dot_config/` → `~/.config/`）
- `.chezmoiignore` で OS 別に管理対象を分岐している。ファイル追加時は対象 OS を確認すること
- secrets は SOPS + age で暗号化。`chezmoi apply` 時にテンプレート内で復号される
- flake.lock は GitHub Actions で毎週自動更新される
