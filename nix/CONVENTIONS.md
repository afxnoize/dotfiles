## Nix Module Conventions

### モジュール構成
- 各モジュールは `modules/<name>/default.nix` にディレクトリ単位で配置
- `modules/default.nix` が全サブモジュールをimportする集約ファイル
- 新規モジュール追加時は `modules/default.nix` のimportリストに追加すること

### Tools / Runtime Wrapper パターン
- `tools/mk-runtime-wrappers.nix` は、registry の「コマンド名 = パッケージ名」から wrapper を生成する汎用関数。実行行は呼び出し側が `mkExec = cmd: pkg: "..."` で渡す
- npm の CLI は `tools/bunx/registry.nix` に登録する。`tools/bunx/default.nix` の `mkExec` が `bunx --bun --package <パッケージ> <コマンド>` を組み立てる
- `--package` でパッケージとコマンドを分けて渡す。`bunx <コマンド>` だけだと、bunx が PATH 上の同名の wrapper 自身を呼んでしまう

```nix
# registry.nix の例
{
  takt = "takt";
  leaf = "@rivolink/leaf";
}
```

### Home-Manager Activation
- `home.activation.*` で DAG 順序制御を使用
- 必ず `lib.hm.dag.entryAfter [ "writeBoundary" ]` で実行順を指定すること

### パッケージソース
- **nixpkgs (stable)**: 通常のパッケージ
- **nixpkgs-unstable**: 最新版が必要なパッケージ（mise, uv, deno, git-wt 等）
- **外部 flake**: llm-agents, cage 等（`inputs` で定義）
- **mise**: moonbit だけ（nixpkgs にも llm-agents にも無いため）。グローバルのランタイムは Nix で持ち、プロジェクトのランタイムは flake の devShell と nix-direnv に任せる
- 最新版が要るパッケージの取り方: nixpkgs-unstable で足りるならそれ、毎日追うなら llm-agents、どちらにもなければ mise
- **happy-coder**: llm-agents の版を `overlays/happy-coder.nix` で包み、`HAPPY_CLAUDE_PATH` の既定値を `~/.nix-profile/bin/claude` にする。上流の `bin/happy` は未設定なら `command -v claude` を使うため、PATH の順序（`~/.local/bin` が先）次第で別の claude を拾う。効くのは端末から起動する local モードだけで、デーモンが起動する remote モード（スマホから起こすセッション）は happy に同梱の claude-agent-sdk の claude を使う。そちらの版は happy-coder の更新でしか上がらない。store パスでなく profile を経由するのは、`flake-latest-update` で上がった claude を次の local セッションから使うため。`--set-default` なので環境変数で上書きできる。データ置き場は `HAPPY_HOME_DIR` で `$XDG_STATE_HOME/happy` に移している（実行時に解決し、デーモンは起動した happy から引き継ぐ）
- **Go のソースビルド**: nixpkgs に無い Go のツールは `tools/gh-infra/` のように `pkgs-unstable.buildGoModule` で build する。版を上げたら `hash` と `vendorHash` を更新する。gh の拡張は `xdg.dataFile."gh/extensions/<名前>"` に `bin` をつないで `gh <名前>` で呼べるようにする（`programs.gh` は `config.yml` を読み取り専用にするので使わない）
- **カスタムバイナリ**: `tools/kakehashi/` のようにプラットフォーム別に分岐
- **bun**: upstream の latest release に意図して固定し、nixpkgs の版には頼らない。理由は、nixpkgs の版が upstream より遅れ、同梱の brotli に脆弱性（bun 1.4.4 で修正）が残っていたため。`bun-linux-x64` / `bun-linux-aarch64` を `flake = false` のファイル入力（upstream の latest release の zip）として持ち、`overlays/bun.nix` の overlay で `pkgs.bun` の `src` だけを差し替える（`flake.nix` の `overlays` から import する）。`tools/bunx` と PATH 上の `bun` は同じ `pkgs.bun` なのでまとめて追従する。更新は `flake-latest-update` が毎日行う（手で上げるなら `nix flake update bun-linux-x64 bun-linux-aarch64`）。nixpkgs が追いついても、入力と overlay は削除しない。linux 以外の system は nixpkgs の bun のまま

### 最新版を追う入力の自動更新（flake-latest-update）
- systemd user timer `flake-latest-update`（毎日 03:00 JST）が、次の 4 入力だけ `flake.lock` を更新し、`nh home switch` まで実行する。実体は `dot_local/bin/executable_flake-latest-update`、unit は `dot_config/systemd/user/`
  - `claude-code`: sadjow/claude-code-nix
  - `llm-agents`: numtide/llm-agents.nix。rtk、ccusage、herdr、t3code、happy-coder などが一緒に上がる
  - `bun-linux-x64` / `bun-linux-aarch64`: upstream の latest release の zip（ファイル入力）
- 追う入力の一覧は、スクリプト冒頭の `latest_inputs` 配列に 1 箇所だけ持つ。足すときはここに名前を足す
- `claude-code` と `llm-agents` には `follows` を付けない。配布元が検証した nixpkgs から外れ、配布元の binary cache が使えなくなるため
- 無人で上がるので、壊れた版が入ったら Home-Manager の世代を戻す。switch の前に版を比べて止める仕組みは入れていない
- ビルド元はローカルの working copy ではなく、リモート（`https://github.com/afxnoize/dotfiles.git` の `main`）を毎回 shallow clone した一時ディレクトリ。cage 内の agent は working copy と `.git` を書き換えられるため、working copy を読む・git を実行すると、悪意ある nix module や `core.fsmonitor` を無人・サンドボックス外で実行させられてしまう。リモートの URL もスクリプトに固定している
- 一時ディレクトリは `/tmp` ではなく `$XDG_RUNTIME_DIR` 配下に作る（cage の `base` preset は `/tmp` を書込許可しており、同一 uid の agent が clone を改ざんできるため）。終了時に削除される
- push していない変更は反映されず、手動 `hms` で入れた未 push の変更は次回の timer で main の内容に戻る。working copy の `flake.lock` も更新されないので、lock の更新を残したいときはローカルで `hmu <入力名>` して commit・push する（放置すると手動 `hms` が古い rev に戻る）
- GitHub API の rate limit で更新できない日は exit 1 で終わる（nix は警告だけで cached lock に戻るため、スクリプト側で検出している）。結果は `journalctl --user -u flake-latest-update` で確認する
- 反映されるのは次回起動から。実行中の claude は旧バイナリのまま動き続ける
- timer の有効化は初回だけ手動: `systemctl --user daemon-reload && systemctl --user enable --now flake-latest-update.timer`（timer を有効にする chezmoi script は無いため、apply では有効化されない）
- `OnCalendar` を変えたときは、apply のあとに `systemctl --user daemon-reload && systemctl --user restart flake-latest-update.timer` で反映する

### GitHub の認証（ghtkn）
- git の `github.com` と `gist.github.com` の credential helper は `ghtkn git-credential`（`modules/git/default.nix`）。GitHub App の User Access Token を使い、8 時間で失効する
- どのアカウントのトークンを使うかは、`~/.config/ghtkn/ghtkn.yaml` の `git_owner` でリポジトリの owner ごとに決める
- 設定ファイルは chezmoi のテンプレート `dot_config/ghtkn/ghtkn.yaml.tmpl` で配る。Windows も同じテンプレートを展開する（`windows/README.md`）
  - リポジトリには個人アカウント（`afxnoize`）の App だけを書く。Client ID は秘密ではない（Device Flow は Client Secret を使わない）が、仕事のアカウント名は公開リポジトリに出さない
  - 仕事のアカウントなど、マシンごとの App は `~/.config/ghtkn/apps.local.yaml` に書く。中身は ghtkn の設定ファイルと同じ形の YAML。apply のときにテンプレートが YAML として読み、`apps` は共通の App の後ろに足し、ほかのキーは共通の値を上書きする。Windows でも同じパス（`%USERPROFILE%\.config\ghtkn\apps.local.yaml`）
  - `apps.local.yaml` は、ないときだけ chezmoi が雛形（`create_apps.local.yaml`、`apps: []`）を作る。既にあれば触らない
  - `apps.local.yaml` を書き換えたら `chezmoi apply` し直す。生成された `ghtkn.yaml` を直接書き換えても、次の apply で上書きされる
- zabrze の略語 `gh` は `ghtkn exec -e GH_TOKEN -- gh` に展開する（`dot_config/zabrze/gh.toml`）。`ghtkn exec` は環境変数 `GHTKN_APP` の App を使い、無ければ `ghtkn.yaml` の先頭の App を使う。`git_owner` で App を選ぶのは git の credential helper として動くときだけ
  - そのため `.zshrc` が、ディレクトリを移るたびにカレントディレクトリの `.../github.com/<owner>/` から owner を取り、連想配列 `ghtkn_app_by_owner`（owner → ghtkn の App 名）を引いて `GHTKN_APP` を設定する。一致しなければ `GHTKN_APP` を消す。Windows の PowerShell と同じ仕組み（`windows/README.md`）
  - `ghtkn_app_by_owner` は `$ZDOTDIR/local.rc.zsh` で定義する。定義が無ければ `GHTKN_APP` に触らない。`local.rc.zsh` は、ないときだけ chezmoi が雛形（`dot_config/zsh/create_local.rc.zsh`）を作る
  - owner と App の対応は `git_owner` と重複する。ディレクトリを移るたびに YAML を読むプロセスを起動しないため、`ghtkn.yaml` からは引かない
- Linux のトークンの保存先は agent backend にする（テンプレートが Linux のときだけ `backend: type: agent` を出す）。refresh token による自動更新は agent backend でしか使えない。keyring backend は Secret Service を要するが、導入時の Manjaro（KDE）では Secret Service が動いていなかった
- agent は systemd user unit `ghtkn-agent`（`dot_config/systemd/user/`）で cage の外に常駐させる。有効化は初回だけ手動で `systemctl --user daemon-reload && systemctl --user enable --now ghtkn-agent`
- agent は起動するたびにロックされた状態で始まる。ログイン後と ghtkn の更新後は、自分の端末で `ghtkn agent unlock --enable-refresh` を実行する。トークンが 7 日使われず消えたときは `ghtkn auth <App 名>` で取り直す
- socket は `$XDG_RUNTIME_DIR/ghtkn/agent.sock` に置く。`XDG_RUNTIME_DIR` がない端末では ghtkn が `~/.cache` に socket を探しに行くため、`dot_zshenv` で `/run/user/$UID` を補う。cage は `~/.cache` に書き込めるので、socket をそこに置くと偽の socket に差し替えられて unlock のパスフレーズを盗まれうる

### stable リリースの自動追従
- 週次の `flake-update`（`nix flake update`）は、URL に書いたブランチの中でしか追従しない。`nixos-25.11` のままでは 26.05 に上がらず、EOL したブランチには cacert などの修正が届かなくなる
- `.github/workflows/nixos-release-bump.yaml` が毎月 2 日 05:00 JST に最新の stable を検出し、`nixpkgs` と `home-manager` の URL を書き換えて PR を出す（ブランチ `chore/nixos-release-bump`）。実体は `.github/scripts/nixos-release-bump.sh`
- 採用するのは、nixpkgs の `nixos-YY.MM` と home-manager の `release-YY.MM` が両方あり、現在の pin より新しいリリース。home-manager は nixpkgs と同じリリースに揃える（ずれると警告や破損の原因になる）
- beta を拾わないよう、リリース名 `YY.MM` の翌月 1 日以降のものだけを採用する。ブランチがいつ作られるかに依存しないため
- CI は `nix eval` による評価だけを行う。ビルドは重いので、PR の確認者が手元で `nix build --impure` する。評価に失敗した場合は draft PR になる
- `home.stateVersion` は自動では上げない。互換性の記録であり、上げると既定値が静かに変わりうるため、リリースの追従とは別に判断する
- 動作確認は `bash .github/scripts/nixos-release-bump.sh --check`（変更せずに採用候補だけ表示）と `bash .github/scripts/nixos-release-bump.test.sh`（判定ロジックのテスト）
- merge すると、次回の `flake-latest-update` が main の内容でビルドして switch する。起きているうちに手元で `hms` を実行し、activation の問題を先に確認する

### Claude Code の skills / plugins
- 外部リポジトリの skill と plugin は `modules/claude-code/` の `programs.claude-code` で入れる。取得元は `flake = false` の入力にし、版は `flake.lock` で固定する。更新は `hmu <入力名>`
- skill は `skills.<名前>` に入力のパスを渡す。リポジトリの一部だけを使うときは `"${inputs.<入力>}/skills/<パス>"` のようにディレクトリを指す。`configDir/skills/<名前>/` にファイルごとのリンクが張られる
- plugin は `plugins` にリポジトリのパスを渡す。module が `claude` を `--plugin-dir <パス>` 付きの wrapper で包むので、`claude-code` は `packages.nix` に入れない（`bin/claude` が衝突する）
- `settings` と `marketplaces` は使わない。どちらかを設定すると module が `settings.json` を生成し、chezmoi が管理する `dot_config/claude/settings.json` と衝突する
- 自分の skill は今までどおり `dot_config/claude/skills/` に置く。リポジトリ固有の skill と plugin は、そのリポジトリの `.claude/` で管理する

### Gotchas
- `builtins.getEnv` を使っているため `--impure` 必須
- `flake.lock` の更新は `nix flake update` で行う（手動編集しない）
- プラットフォーム固有の処理は `builtins.currentSystem` で分岐する
