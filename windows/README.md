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

GitHub のリリースから入れるものは、週次の workflow（`.github/workflows/windows-release-bump.yaml`）が最新版を調べ、URL と SHA256 を書き換えた PR を作る。

- 対象は、`-Sha256 '<hash>'` の次の行に `-Url 'https://github.com/<owner>/<repo>/releases/download/<tag>/<asset>'` がある `Install-Release` の呼び出し。一覧ファイルはなく、構成ファイルから直接拾う
- 新しい asset 名は、古い asset 名の版の部分を置き換えて作る。新しいリリースにその名前の asset がないとき（改名など）は書き換えず、workflow を失敗させて知らせる
- NirCmd（GitHub 外）と WezTerm nightly（ハッシュなし）は対象外

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
- sops は winget から削除された（`Mozilla.SOPS`）ため、GitHub のリリースから `sops.exe` を取得して `%LOCALAPPDATA%\Programs\sops` に置き、ユーザーの `Path` に追加する
  - 版と SHA256 は構成ファイルに固定している。更新するときは、SetScript の URL と、TestScript と SetScript の両方のハッシュを書き換える。ハッシュはリリースの `sops-v<版>.checksums.txt` にある amd64.exe の行を使う
- git-wt は winget に登録されていないため、GitHub のリリースの `windows_amd64.tar.gz` から `git-wt.exe` を取り出して `%LOCALAPPDATA%\Programs\git-wt` に置き、ユーザーの `Path` に追加する
  - 版と SHA256 は構成ファイルに固定している。更新するときは、SetScript の URL と、TestScript と SetScript の両方のハッシュを書き換える。ハッシュはリリースの `checksums.txt` にある windows_amd64 の行を使う
- Pester 6（`windows/tests` のテストに使う）を、PowerShell Gallery から現在のユーザーに入れる
  - winget が動かす PowerShell ではなく `pwsh.exe` を起動して `Install-PSResource` を呼ぶ。winget の PowerShell はモジュールのパスが独自で、PSResourceGet が読めないことがあるため
  - `pwsh.exe` は、MSI 版なら `Program Files\PowerShell\7` に、MSIX 版（winget の `Microsoft.PowerShell` が入れるもの）なら `%LOCALAPPDATA%\Microsoft\WindowsApps` にある。両方を探す
  - 版は構成ファイルに固定している。更新するときは、TestScript と SetScript の両方の版を書き換える

`packages.nix` から入れないもの:

- Nix 関連、cage、tmux: Windows 版がない
- gti: 使わない
- rtk、ccusage: 未確認。必要なら mise か npm で入れる

## configuration.personal.dsc.yaml が行うこと

- AutoHotkey v2、Argus（タスクマネージャ）、Kando（パイメニュー）、OpenInzone（INZONE Hub なしで Sony INZONE ヘッドセットを操作する）を winget で入れる
- NirCmd は winget に登録されていないため、NirSoft の zip を取得して `%LOCALAPPDATA%\Programs\NirCmd` に展開し、ユーザーの `Path` に追加する
  - zip は SHA256 で検証する。NirSoft は版を上げると同じ URL の zip を差し替えるため、版が上がるとハッシュ不一致で失敗する。そのときは新しい版を確認して、TestScript と SetScript の両方のハッシュを更新する
- BatteryHub（ワイヤレス機器のバッテリー残量をタスクバーに出す。旧名 Wireless Battery）も winget に登録されていないため、GitHub リリースの portable zip を `%LOCALAPPDATA%\Programs\BatteryHub` に展開する
  - 版は URL で固定している。上げるときは URL と、TestScript と SetScript の両方のハッシュを更新する。ハッシュはリリースの `SHA256SUMS.txt` にある portable zip の行を使う
  - 設定と電池の履歴は旧名のまま `HKCU\Software\WirelessBattery` と `%LOCALAPPDATA%\WirelessBattery` に残り、改名後もそのまま使われる
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
  - ghtkn の設定ファイルは `AppData/Roaming/ghtkn/ghtkn.yaml.tmpl` で配る。Windows の ghtkn は `XDG_CONFIG_HOME` を見ず、`%APPDATA%\ghtkn\ghtkn.yaml` を読む
  - 中身は Linux と共通の `dot_config/ghtkn/ghtkn.yaml.tmpl` を apply のときに展開したもの。書き方は `docs/ghtkn.md` を見る
  - backend は書かず、既定の keyring にする
  - トークンは Windows Credential Manager（ghtkn の既定の keyring backend）に入る。Windows の ghtkn は refresh token に対応しないため、8 時間ごとに `ghtkn auth <App 名>` でブラウザ承認をやり直す
- `dot_config/git/ignore.tmpl`: グローバルの gitignore。Linux と共通の `nix/modules/git/ignore` を埋め込む
- `dot_config/symlink_wezterm.tmpl`: `~/.config/wezterm` を、リポジトリ直下の `dot_config/wezterm` への symlink にする
- `dot_config/powershell/profile.ps1`: PowerShell 7 の設定。zoxide を初期化し、プロンプトにカレントディレクトリと git の状態を出す
  - git の状態は、ブランチ名、upstream との差（`↑` `↓`）、競合（`!`）、ステージ済み（`+`）、未ステージ（`~`）、未追跡（`?`）の件数
  - 起動を軽くするため、oh-my-posh や posh-git は使わない。git リポジトリの外では git を呼ばない
  - PowerShell 7 が読む profile（`$PROFILE`）は Documents フォルダの下にあり、Documents は `$HOME` の外に移されていることがある。そのため chezmoi は `$PROFILE` をファイルとして持たない
  - 代わりに `.chezmoiscripts/run_onchange_after_powershell-profile.ps1` が、`$PROFILE` をこのファイルを読み込む一行だけに書き換える。元の中身が違えば `Microsoft.PowerShell_profile.ps1.bak` に退避する
  - 環境変数 `PROFILE` を設定しても、PowerShell が読む profile の場所は変わらない。`$PROFILE` は PowerShell が起動時に値を入れる自動変数で、環境変数とは別物
  - マシン・アカウント固有の設定は、同じディレクトリの `profile.local.ps1` に書く。あれば zoxide の初期化より前に dot-source する。git の `local.config`、ghtkn の `apps.local.yaml` と同じ位置づけ
    - chezmoi は `create_profile.local.ps1` から、ファイルが無いときだけ雛形を置く。既にあれば上書きしない
  - プロンプトを出すたびに、カレントディレクトリの `...\github.com\<owner>\` から owner を取り、`$GhtknAppByOwner`（owner → ghtkn の App 名）を引いて環境変数 `GHTKN_APP` を設定する。一致しなければ `GHTKN_APP` を消す
    - `$GhtknAppByOwner` は `profile.local.ps1` で定義する。定義が無ければ `GHTKN_APP` に触らない
    - `ghtkn exec` は `GHTKN_APP` の App を使い、無ければ `ghtkn.yaml` の先頭の App を使う。`git_owner` で App を選ぶのは git の credential helper として動くときだけ。そのため略語の `gh`（`ghtkn exec -e GH_TOKEN -- gh`）は、この切り替えが無いと owner に関係なく先頭の App で動く
    - owner と App の対応は `ghtkn.yaml` の `git_owner` と重複する。PowerShell 標準に YAML パーサが無いため、`ghtkn.yaml` からは引かない
- `dot_config/powershell/abbr.ps1`: zabrze と同じ要領の略語展開。PSReadLine の Space と Enter に割り当て、カーソルの直前の語を展開する
  - zabrze は zsh 専用で、既存の PowerShell 向けモジュール（PowerShell Gallery の `Abbr`）は正規表現のトリガーと `context` を持たない。そのため自作した
  - 外部プロセスを呼ばず、PowerShell の中で展開する。Space のたびにプロセスを起動しないため
  - 規則は `dot_config/powershell/abbr/*.ps1` に置く。各ファイルは規則を 1 つにつき 1 個のハッシュテーブルとして出力し、ファイル名順・記述順で最初に一致した規則を使う
  - 規則のキーは zabrze の項目に対応する: `Trigger`（完全一致）/ `TriggerPattern`（正規表現）、`Snippet` / `Evaluate`、`Global`、`Context`、`Cursor`、`If`
  - `Evaluate` と `If` はスクリプトブロックで書く。`Evaluate` は名前付きグループのハッシュテーブルを引数に受け取る。`.psd1` にしないのは、データファイルにスクリプトブロックを書けないため
  - `Global` でない規則は、コマンド位置でだけ展開する。コマンド位置は、行頭と、`|` `;` `&` 改行 `(` `{` の直後。ハッシュテーブル（`@{ }`）の直下はキーの位置なので展開しない
  - `Context` は、いま書いている文の先頭からカーソルまでの文字列（トリガー自身を含む）に対して評価する。文の先頭は、上のコマンド位置の区切りの直後で、先頭の空白は除く。zabrze は行頭から評価するため、`cd x; git st` のような 2 つ目以降の文では展開しない。こちらでは展開する
  - 文字列（here-string を含む）とコメントの中では展開しない
  - 規則の `If` と `Evaluate` は打鍵のたびに動く。例外は握りつぶして次の規則に進み、`$LASTEXITCODE` は展開の前の値に戻す
  - `Cursor` の印の位置にカーソルを置いたときは、Enter でも行を実行せず入力を待つ
  - 貼り付けた文字列は展開しない。端末への貼り付けは、PSReadLine には 1 文字ずつのキー入力として届く。そこで Space や Enter の時点で後ろにキーが控えていれば、貼り付けとみなす
    - PSReadLine はハンドラを呼ぶ前に入力を読み切り、非公開の `_queuedKeys` に溜める。そのため `[Console]::KeyAvailable` だけでは見分けられず、`_queuedKeys` をリフレクションで読む
    - PSReadLine の版が変わってこのフィールドがなくなったときは、`[Console]::KeyAvailable` だけで判定する。その場合、貼り付けでも展開されることがある
  - 規則ファイルに誤り（未知のキー、Trigger と TriggerPattern の両方など）があると、profile は警告を出して略語展開だけを無効にする
  - zsh の規則のうち、Windows に入っていないツール（nix、tmux、pueue、cage など）と、coreutils 固有のフラグを使うものは移していない
  - テストは Pester 6 で書いている。Pester は `configuration.dev.dsc.yaml` が入れる。Windows 付属の Pester 3.4 では動かない

    ```powershell
    pwsh -NoProfile -Command 'Invoke-Pester windows/tests -Output Detailed'
    ```

## 未対応

- 以前の PowerShell profile は、まだリポジトリ直下の `readonly_Documents/` にある。scoop（posh-git、scoop-completion、mise のパス）と、マシン固有の oh-my-posh の init パスに依存している
- Neovim の設定は、まだリンクしていない
- nvim-treesitter のパーサのビルドに使う C コンパイラは入れていない
- Claude Code の設定は、どのファイルを持っていくか決めていない
