# GitHub の認証（ghtkn）

git と gh の GitHub 認証を、GitHub App の User Access Token（ghtkn）で行う仕組み。nix、chezmoi のテンプレート、zsh、systemd にまたがる。

いつ読むか: ghtkn の設定テンプレート、git の credential helper、`gh` の略語、`GHTKN_APP` の切り替え、`ghtkn-agent` を編集するとき。Windows 側の差分は `windows/README.md` にある。

## 認証の流れ
- git の `github.com` と `gist.github.com` の credential helper は `ghtkn git-credential`（`nix/modules/git/default.nix`）。GitHub App の User Access Token を使い、8 時間で失効する
- どのアカウントのトークンを使うかは、`~/.config/ghtkn/ghtkn.yaml` の `git_owner` でリポジトリの owner ごとに決める

## 設定ファイル
- 設定ファイルは chezmoi のテンプレート `dot_config/ghtkn/ghtkn.yaml.tmpl` で配る。Windows も同じテンプレートを展開する（`windows/README.md`）
  - リポジトリには個人アカウント（`afxnoize`）の App だけを書く。Client ID は秘密ではない（Device Flow は Client Secret を使わない）が、仕事のアカウント名は公開リポジトリに出さない
  - 仕事のアカウントなど、マシンごとの App は `~/.config/ghtkn/apps.local.yaml` に書く。中身は ghtkn の設定ファイルと同じ形の YAML。apply のときにテンプレートが YAML として読み、`apps` は共通の App の後ろに足し、ほかのキーは共通の値を上書きする。Windows でも同じパス（`%USERPROFILE%\.config\ghtkn\apps.local.yaml`）
  - `apps.local.yaml` は、ないときだけ chezmoi が雛形（`create_apps.local.yaml`、`apps: []`）を作る。既にあれば触らない
  - `apps.local.yaml` を書き換えたら `chezmoi apply` し直す。生成された `ghtkn.yaml` を直接書き換えても、次の apply で上書きされる

## gh コマンドと GHTKN_APP
- zabrze の略語 `gh` は `ghtkn exec -e GH_TOKEN -- gh` に展開する（`dot_config/zabrze/gh.toml`）。`ghtkn exec` は環境変数 `GHTKN_APP` の App を使い、無ければ `ghtkn.yaml` の先頭の App を使う。`git_owner` で App を選ぶのは git の credential helper として動くときだけ
  - そのため `.zshrc` が、ディレクトリを移るたびにカレントディレクトリの `.../github.com/<owner>/` から owner を取り、連想配列 `ghtkn_app_by_owner`（owner → ghtkn の App 名）を引いて `GHTKN_APP` を設定する。一致しなければ `GHTKN_APP` を消す。Windows の PowerShell と同じ仕組み（`windows/README.md`）
  - `ghtkn_app_by_owner` は `$ZDOTDIR/local.rc.zsh` で定義する。定義が無ければ `GHTKN_APP` に触らない。`local.rc.zsh` は、ないときだけ chezmoi が雛形（`dot_config/zsh/create_local.rc.zsh`）を作る
  - owner と App の対応は `git_owner` と重複する。ディレクトリを移るたびに YAML を読むプロセスを起動しないため、`ghtkn.yaml` からは引かない

## Linux の agent
- Linux のトークンの保存先は agent backend にする（テンプレートが Linux のときだけ `backend: type: agent` を出す）。refresh token による自動更新は agent backend でしか使えない。keyring backend は Secret Service を要するが、導入時の Manjaro（KDE）では Secret Service が動いていなかった
- agent は systemd user unit `ghtkn-agent`（`dot_config/systemd/user/`）で cage の外に常駐させる。有効化は初回だけ手動で `systemctl --user daemon-reload && systemctl --user enable --now ghtkn-agent`
- agent は起動するたびにロックされた状態で始まる。ログイン後と ghtkn の更新後は、自分の端末で `ghtkn agent unlock --enable-refresh` を実行する。トークンが 7 日使われず消えたときは `ghtkn auth <App 名>` で取り直す
- socket は `$XDG_RUNTIME_DIR/ghtkn/agent.sock` に置く。`XDG_RUNTIME_DIR` がない端末では ghtkn が `~/.cache` に socket を探しに行くため、`dot_zshenv` で `/run/user/$UID` を補う。cage は `~/.cache` に書き込めるので、socket をそこに置くと偽の socket に差し替えられて unlock のパスフレーズを盗まれうる
