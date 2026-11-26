# Paseo

複数のコーディングエージェント（Claude Code など）を daemon から起動し、CLI やアプリから操作するツール。Linux では headless の CLI と daemon だけを入れる。

いつ読むか: Paseo の agent を操作するとき、Paseo のインストール方法や daemon の起動方法を変えるとき。

## インストール
- Linux では flake input の `llm-agents`（numtide/llm-agents.nix）の `paseo` を overlay で取り込み、`nix/modules/packages.nix` の `aiTools` で入れる。`paseo` コマンドは Nix の nodejs で CLI を起動するラッパーで、daemon も Node で動く。版は `flake.lock` の `llm-agents` に固定され、flake の更新で上がる
  - ほかの npm の CLI のように `nix/tools/bunx/registry.nix`（`bunx --bun`）へ登録しない。Bun で動かした daemon では `paseo plugin add` が `worker.child.channel?.ref is not a function` で失敗する（paseo 0.17.4、bun 1.4.4）。Bun の `fork()` が返す IPC チャネルに `ref()` と `unref()` がないため
- Windows では winget の `Paseo.Paseo`（デスクトップ版）を `windows/configuration.dev.dsc.yaml` で入れる。winget には CLI がない

## daemon
- agent は daemon の子プロセスとして動く。daemon の状態や設定は `~/.paseo` に置かれる（`--home` で変えられる）
- 初回は `paseo onboard` で設定と daemon の起動をまとめて行う。以降は `paseo daemon start`
- 状態の確認は `paseo daemon status`。`daemonNode` に daemon を動かしているランタイムが出る
- `paseo daemon restart` は daemon の worker を再起動する。動いている agent のプロセスは全部止まる。Paseo の agent の中から restart すると、その agent の会話も切れる
- `restart` は supervisor の起動のしかたを引き継ぐ。ランタイムを変えたあとは `paseo daemon stop` してから `paseo daemon start` で起動し直し、`daemonNode` を確かめる
- `config.json` を書き換えただけなら `paseo daemon reload` で読み直せる

## 設定ファイル
- `~/.paseo` のうち chezmoi で管理するのは `config.json` だけにする。ほかは agent の記録、ログ、鍵、pid などの状態なので管理しない
- 実体は `~/.config/paseo/config.json` に置き、`~/.paseo/config.json` から symlink を張る（`dot_paseo/symlink_config.json.tmpl`）
  - daemon は `config.json` を temp ファイルからの rename で書き戻すが、先に symlink を解決してから書く（paseo 0.17.4 の `private-files.js` の `resolveSymlinkedFile`）。そのため link は残り、実体が更新される
- 実体は modify script（`dot_config/paseo/modify_private_config.json.tmpl`）で作る。既存のファイルに、管理するキーだけを jq で上書きする
  - daemon はアプリからの設定変更や `paseo plugin add` で `config.json` を自分で書き換える。ファイル全体をテンプレートにすると、`chezmoi apply` のたびにその変更が消える
  - `plugins` は管理しない。`paseo plugin add` がインストールごとのパスを書き込むため
  - 管理するキーを変えるときは、アプリや `paseo` で変えたあと、modify script の jq 式にも同じ値を書く。書かないと次の `chezmoi apply` で戻る
- `daemon.listen` のアドレスとポートは公開したくないので、sops で暗号化した `dot_config/paseo/secrets.yaml` の `paseo_listen` に置く。中身の編集は `sops dot_config/paseo/secrets.yaml`
- 新しいマシンでは、`chezmoi apply` の前に `~/.paseo/config.json` があれば `~/.config/paseo/config.json` へ移す。移さずに apply すると、空の入力から管理するキーだけのファイルができる。そのファイルには `plugins` が入らない。また、chezmoi が `~/.paseo/config.json` を symlink で置き換えるときに、元のファイルの中身も失われる

## agent の操作
ID は前方一致で指定できる（例: `86b0cca`）。

```bash
paseo ls                       # agent の一覧。-a でアーカイブ済みも、-g で全ディレクトリ分も出す
paseo inspect <id>             # 詳細
paseo logs <id>                # これまでのやりとり。-f で追従、--tail <n> で末尾だけ
paseo attach <id>              # 実行中の出力ストリームにつなぐ
paseo send <id> "本文"         # メッセージを送り、返事が終わるまで待つ
paseo send <id> "本文" --no-wait
paseo wait <id>                # idle になるまで待つ
paseo stop <id>                # 実行中のターンを止める
paseo archive <id>             # アーカイブ（論理削除）
paseo delete <id>              # 削除
```

- 新しい agent は `paseo run "タスク"` で起動する。`--provider claude/<model>`、`--cwd`、`--title`、`--new-workspace worktree` などを指定できる
- 既存の Claude Code のセッションを Paseo に取り込むには `paseo import <セッション ID> --provider claude`
- `paseo send` の `--behavior` は、人が送るときの既定が `interrupt`。agent が作業中なら今のターンを止めて差し替える。待たせたいときは `queue`、今のターンに合流させたいときは `steer`

## Claude Code からの見え方
- Paseo が起動した claude は、stream-json の入出力で daemon とつながっている。Claude Code の `ListAgents` や `SendMessage` の宛先には出ない
- Claude Code のセッションから Paseo の agent に話しかけるときは、Bash で `paseo send` を使う

## plugin
- `paseo plugin add <source>` で入れる。source は registry、ディレクトリ、Git リポジトリ、npm パッケージのどれか（例: `paseo plugin add stevecastaneda/progress`）
- 一覧は `paseo plugin ls`、出力は `paseo plugin logs <id>`。ほかに `enable`、`disable`、`update`、`remove` がある
- plugin はサンドボックスなしで動く。信頼できるものだけを入れる
- plugin は Nix でも chezmoi でも入れず、paseo に管理させる。入れた plugin は `~/.paseo/plugins/` に置かれ、`config.json` の `plugins` に登録される
  - Nix で入れない理由: 依存の `node_modules` まで Nix でビルドする手間に見合わない。また、paseo は更新前に差分を見せ、git の commit や npm の成果物を照合する。この確認を残すため

### 入れている plugin
新しいマシンでは、次のコマンドで入れ直す。どれも Paseo の registry（`plugins.paseo.sh`）から入れている。

```bash
paseo plugin add stevecastaneda/progress   # progress: worktree ごとの進み具合のダッシュボード（npm）
paseo plugin add paseo-cafe/cafe           # paseo-cafe（npm）
paseo plugin add a31521424/host-monitor    # host-monitor（git: a31521424/paseo-kit）
paseo plugin add sojuhub/pele              # pele（git: sojuhub/paseo-plugin-pele）
```

plugin を足したり外したりしたら、この一覧も直す。

### 更新
自動では更新されない。paseo 0.17.4 には定期的に更新を確かめる仕組みがなく、CLI やアプリから頼んだときだけ確かめる。

```bash
paseo plugin update --all --check   # 更新があるかだけ見る
paseo plugin update --all           # 差分を見て、確認してから更新する
paseo plugin update <id>            # 1 つだけ更新する
```

`--yes`（確認を飛ばす）を timer などで定期的に回さない。plugin はサンドボックスなしで動くので、中身を見ないまま新しい版が入る。
