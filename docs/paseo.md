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
