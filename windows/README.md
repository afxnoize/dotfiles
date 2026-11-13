# Windows 用 dotfiles

Windows 環境は、このディレクトリを chezmoi のソースとして独立に管理する。Linux 側（リポジトリ直下）とはソースを共有しない。

- パッケージと OS 設定は、用途別の構成ファイルを `winget configure` で適用する
  - `configuration.dev.dsc.yaml`: 開発用
  - `configuration.personal.dsc.yaml`: 個人用（開発以外の普段使い）
- 設定ファイルは chezmoi で配布する

## セットアップ

1. 使う構成ファイルを検証してから適用する。両方使うマシンでは両方を適用する
   - 管理者でないターミナルで実行する。Script リソースは実行ユーザーの環境変数と `%LOCALAPPDATA%` に書き込むため、別アカウントの管理者シェルで実行すると、そのアカウント側に書き込まれる

   ```powershell
   winget configure validate -f configuration.dev.dsc.yaml
   winget configure -f configuration.dev.dsc.yaml
   ```

2. このディレクトリをソースにして chezmoi を初期化し、apply する。chezmoi と git は `configuration.dev.dsc.yaml` が入れる
   - 初期化のときに、個人用のマシンかを一度だけ聞かれる。答えは生成される設定ファイルの `[data] personal` に残る
   - `.chezmoi.toml.tmpl` が `sourceDir` を設定ファイルに書くため、2 回目以降は `--source` を付けなくてよい

   ```powershell
   chezmoi init --source <リポジトリのパス>\windows
   chezmoi apply
   ```

## configuration.dev.dsc.yaml が行うこと

- 開発者モードを有効にする。chezmoi が管理者権限なしで symlink を作るために必要
- ユーザー環境変数 `XDG_CONFIG_HOME` を `%USERPROFILE%\.config` に設定する。Neovim は既定では `%LOCALAPPDATA%\nvim` を読むため、この変数で `~/.config/nvim` を読ませる
- `nix/modules/packages.nix` のうち Windows 版があるツールを winget で入れる
- herdr のデスクトップアプリを公式のインストーラ（`https://releases.herdr.dev/app/install.ps1`）で入れる
  - winget の `Herdr.Herdr` は CLI のランタイムで、デスクトップアプリは winget に登録されていない
  - インストーラは、リリースのマニフェストにある SHA256 でダウンロードを検証し、`%LOCALAPPDATA%\Programs\herdr-app` に置いてユーザーの `Path` に追加する。herdr-core がなければ一緒に入れる
  - 入れた後はアプリが自分で更新する。構成ファイルはアプリの有無だけを見る

`packages.nix` から入れないもの:

- Nix 関連、cage、devbox、tmux: Windows 版がない
- git-wt: winget に登録されていない
- gti: 使わない
- rtk、ccusage: 未確認。必要なら mise か npm で入れる

## configuration.personal.dsc.yaml が行うこと

- AutoHotkey v2 と Argus（タスクマネージャ）を winget で入れる
- NirCmd は winget に登録されていないため、NirSoft の zip を取得して `%LOCALAPPDATA%\Programs\NirCmd` に展開し、ユーザーの `Path` に追加する
  - zip は SHA256 で検証する。NirSoft は版を上げると同じ URL の zip を差し替えるため、版が上がるとハッシュ不一致で失敗する。そのときは新しい版を確認して `$expected` を更新する

## 配布するファイル

- `AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Startup/app-volume.ahk`: ログオン時に起動する AutoHotkey v2 スクリプト。NirCmd で前面のアプリの音量とミュートを切り替える
  - 個人用のマシンにだけ配る。AutoHotkey がないマシンに置くと、ログオン時に `.ahk` を開くアプリの選択画面が出るため

## 未対応

- PowerShell profile は、まだリポジトリ直下の `readonly_Documents/` にある。scoop（posh-git、scoop-completion、mise のパス）と、マシン固有の oh-my-posh の init パスに依存している
- Neovim と WezTerm の設定は、まだリンクしていない
- WezTerm が指定するフォント（Cica、Symbols Nerd Font Mono、Iosevka Term、Fira Code）は入れていない
- nvim-treesitter のパーサのビルドに使う C コンパイラは入れていない
- Claude Code の設定は、どのファイルを持っていくか決めていない
