# Windows 用 dotfiles

Windows 環境は、このディレクトリを chezmoi のソースとして独立に管理する。Linux 側（リポジトリ直下）とはソースを共有しない。

- パッケージと OS 設定は、用途別の構成ファイルを `winget configure` で適用する
  - `configuration.dev.dsc.yaml`: 開発用
  - `configuration.personal.dsc.yaml`: 個人用（開発以外の普段使い）
- 設定ファイルは chezmoi で配布する

## セットアップ

管理者でないターミナルで実行する。Script リソースは実行ユーザーの環境変数と `%LOCALAPPDATA%` に書き込むため、別アカウントの管理者シェルで実行すると、そのアカウント側に書き込まれる。

1. git を入れてリポジトリを clone する。構成ファイルはリポジトリの中にあるため、git だけは先に単独で入れる

   ```powershell
   winget install --id Git.Git -e
   # 新しいターミナルを開いて git を PATH に通してから
   git clone https://github.com/afxnoize/dotfiles.git $HOME\repos\github.com\afxnoize\dotfiles
   ```

2. 使う構成ファイルを検証してから適用する。両方使うマシンでは両方を適用する

   ```powershell
   cd $HOME\repos\github.com\afxnoize\dotfiles\windows
   winget configure validate -f configuration.dev.dsc.yaml
   winget configure -f configuration.dev.dsc.yaml
   ```

3. 新しいターミナルを開く。winget が入れた chezmoi などは、開き直すまで PATH に入らない

4. このディレクトリをソースにして chezmoi を初期化し、apply する。chezmoi は `configuration.dev.dsc.yaml` が入れる
   - 初期化のときに、個人用のマシンかを一度だけ聞かれる。答えは生成される設定ファイルの `[data] personal` に残る
   - `.chezmoi.toml.tmpl` が `sourceDir` を設定ファイルに書くため、2 回目以降は `--source` を付けなくてよい
   - 既存の chezmoi の設定ファイルは、`.chezmoi.toml.tmpl` から作り直したものに置き換わる。以前の設定（リポジトリ直下のテンプレートから作った `[secret]` など）は残らない

   ```powershell
   chezmoi init --source $HOME\repos\github.com\afxnoize\dotfiles\windows
   chezmoi apply
   ```

## winget にないものの入れ方

winget にないツールとフォントは、構成ファイルの Script リソースから `scripts/release.ps1` の関数を呼んで、リリースから入れる。ダウンロードを SHA256 で検証し、入れたもののハッシュを `%LOCALAPPDATA%\dotfiles\releases` に記録する。構成ファイルのハッシュと記録が違うもの、または本体（`sops.exe`、`nircmd.exe`）がなくなったものだけを入れ直す。

## configuration.dev.dsc.yaml が行うこと

- 開発者モードを有効にする。chezmoi が管理者権限なしで symlink を作るために必要
- ユーザー環境変数 `XDG_CONFIG_HOME` を `%USERPROFILE%\.config` に設定する。Neovim は既定では `%LOCALAPPDATA%\nvim` を読むため、この変数で `~/.config/nvim` を読ませる
- `nix/modules/packages.nix` のうち Windows 版があるツールを winget で入れる
- WezTerm の nightly 版を、GitHub の `nightly` リリースにある `WezTerm-nightly-setup.exe` から入れる
  - winget の `wez.wezterm.nightly` は使わない。上書きされ続けるインストーラの URL に SHA256 を固定しているため、winget の bot がマニフェストを更新するまでハッシュ不一致で失敗する
  - ダウンロードはハッシュで検証しない
  - 安定版と同じ Inno Setup の AppId を使うため、安定版が入っていれば同じ場所に上書きする。構成ファイルは、最後の安定版（`20240203-110809-5046fc22`）以外の版が入っていれば導入済みとみなす
  - 入れた後は更新しない。新しい nightly にするときは、構成ファイルを流さず、インストーラを手で入れ直す
- フォント（Cica、UDEV Gothic、PleckJP）を GitHub のリリースから取得し、現在のユーザーに入れる
  - 版と SHA256 は構成ファイルに固定している。更新するときは、TestScript と SetScript の両方のハッシュと、SetScript の URL を書き換える
- `packages.nix` にない T3 Code（コーディングエージェントの GUI）を winget の `T3Tools.T3Code` で入れる
- sops は winget から削除された（`Mozilla.SOPS`）ため、GitHub のリリースから `sops.exe` を取得して `%LOCALAPPDATA%\Programs\sops` に置き、ユーザーの `Path` に追加する
  - 版と SHA256 は構成ファイルに固定している。更新するときは、SetScript の URL と、TestScript と SetScript の両方のハッシュを書き換える。ハッシュはリリースの `sops-v<版>.checksums.txt` にある amd64.exe の行を使う

`packages.nix` から入れないもの:

- Nix 関連、cage、tmux: Windows 版がない
- git-wt: winget に登録されていない
- gti: 使わない
- rtk、ccusage: 未確認。必要なら mise か npm で入れる

## configuration.personal.dsc.yaml が行うこと

- AutoHotkey v2、Argus（タスクマネージャ）、Kando（パイメニュー）を winget で入れる
- NirCmd は winget に登録されていないため、NirSoft の zip を取得して `%LOCALAPPDATA%\Programs\NirCmd` に展開し、ユーザーの `Path` に追加する
  - zip は SHA256 で検証する。NirSoft は版を上げると同じ URL の zip を差し替えるため、版が上がるとハッシュ不一致で失敗する。そのときは新しい版を確認して、TestScript と SetScript の両方のハッシュを更新する
- Wireless Battery（ワイヤレス機器のバッテリー残量をタスクバーに出す）も winget に登録されていないため、GitHub リリースの portable zip を `%LOCALAPPDATA%\Programs\WirelessBattery` に展開する
  - 版は URL で固定している。上げるときは URL と、TestScript と SetScript の両方のハッシュを更新する
  - サインイン時の自動起動は、アプリのメニューの *Start with Windows* で設定する

## 配布するファイル

- `AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Startup/app-volume.ahk`: ログオン時に起動する AutoHotkey v2 スクリプト。NirCmd で前面のアプリの音量とミュートを切り替える
  - 個人用のマシンにだけ配る。AutoHotkey がないマシンに置くと、ログオン時に `.ahk` を開くアプリの選択画面が出るため
- `AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Startup/kando-gesture.ahk`: ログオン時に起動する AutoHotkey v2 スクリプト。マウスカーソルを円を描くように回すと、Kando のメニューを開く
  - Kando にはマウスジェスチャーで開く機能がないため、カーソルの動きを監視して、メニューのショートカット `Ctrl+Alt+Shift+F18` を送る
  - Kando の設定は chezmoi で管理していない。Kando の設定画面で、メニューのショートカットを `Ctrl+Alt+Shift+F18` にする
  - app-volume.ahk と同じく、個人用のマシンにだけ配る

- `dot_config/git/config.tmpl`: git の設定。Linux と共通の設定 `nix/modules/git/common.gitconfig` を、apply のときにテンプレートで埋め込む
  - 実行時の `[include]` でリポジトリのファイルを読まないのは、working copy の書き換えが apply を経ずに反映されないようにするため。clone 先を動かしても、設定が黙って消えることもない
  - 共通の設定を変えたら、Windows でも `chezmoi apply` する
  - マシン固有の設定は、Linux と同じく `~/.config/git/local.config` に書く
  - GitHub（`github.com` と `gist.github.com`）の credential helper は `ghtkn git-credential` にする
  - Git for Windows のインストーラは、system の設定に Git Credential Manager を入れる。GitHub に限り、空の `helper =` でこれを外す。ほかのホストは Git Credential Manager のまま
  - ghtkn の設定ファイルは `%APPDATA%\ghtkn\ghtkn.yaml` に置く。Windows の ghtkn は `XDG_CONFIG_HOME` を見ない。App の Client ID と `git_owner` を書くファイルで、chezmoi では管理しない
  - 設定ファイルは `ghtkn init` で作り、Client ID と `git_owner` を書き換える。ないまま apply すると、GitHub への HTTPS の push と fetch が認証で失敗する
  - トークンは Windows Credential Manager（ghtkn の既定の keyring backend）に入る。Windows の ghtkn は refresh token に対応しないため、8 時間ごとに `ghtkn auth <App 名>` でブラウザ承認をやり直す
- `dot_config/git/ignore.tmpl`: グローバルの gitignore。Linux と共通の `nix/modules/git/ignore` を埋め込む
- `dot_config/symlink_wezterm.tmpl`: `~/.config/wezterm` を、リポジトリ直下の `dot_config/wezterm` への symlink にする

## 未対応

- PowerShell profile は、まだリポジトリ直下の `readonly_Documents/` にある。scoop（posh-git、scoop-completion、mise のパス）と、マシン固有の oh-my-posh の init パスに依存している
- Neovim の設定は、まだリンクしていない
- nvim-treesitter のパーサのビルドに使う C コンパイラは入れていない
- Claude Code の設定は、どのファイルを持っていくか決めていない
