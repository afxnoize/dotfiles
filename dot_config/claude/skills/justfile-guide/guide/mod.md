# Module (mod) 使用ガイド

いつ読む: justfile を分割するとき、mod を追加・入れ子にするとき、mod 内から他の recipe を呼ぶとき。mod と group の役割分担は [`SKILL.md`](../SKILL.md) を先に読む。前提は just 1.43.0 以上。

monorepo やパッケージ分割、ドメイン分離で `mod` を使う際のパターン。

## `mod` と `import` の使い分け

ファイルを分けたい動機は 2 通りで、選ぶ構文が違う。

- **`mod x "file.just"`** — 名前空間を切る
  - `just x <recipe>` / `(x::recipe)` で呼ぶ
  - `just --list` では `x` がまとまり、`just x` または `just --list x` でドリルダウンできる
  - 呼び出し側が「どのドメインの操作か」明示されるので、衝突しにくい（`db::drop` と `dms::drop` が共存できる）
- **`import "file.just"`** — テキスト連結に近い
  - 親の名前空間にすべての recipe がフラットに吸収される
  - 呼び出しは普通に `just recipe-name`

### 採用基準

- ドリルダウン UX を提供したい、ドメイン名を CLI で明示したい → `mod`
- 単にファイルが長くなったので分けたいだけ、呼び出し側は今まで通り → `import`
- 「見栄えのため」だけなら `import` で十分。`mod` の存在意義は CLI UX と名前空間にある
- 全 justfile に共通の設定を配りたい → `import "_common.just"`（[`settings.md`](settings.md)）

## 基本構文

```just
mod <name> "<path>"              # 必須モジュール
mod? <name> "<path>"             # 任意モジュール（存在しなくてもエラーにならない）
mod <name>                       # ./<name>/justfile または ./<name>.just を自動解決
```

## 分割の 2 形態

- **ディレクトリ分割 (`packages/api/justfile`)** — パッケージが独立したコード・依存・build 成果物を持つとき。monorepo の真のサブパッケージ向け。recipe は mod のディレクトリを cwd として走る
- **ファイル単位 (`db.just`)** — 同一 working dir で動く recipe 群をドメインで名前空間分けしたいとき。IaC / 運用スクリプトで多い。recipe は**ルートと同じ cwd** で走る

```
repo/
├── justfile       # mod db / mod dms / mod bastion を読み込む
├── db.just
├── dms.just
└── bastion.just
```

```just
# justfile
mod db                           # ./db.just を自動解決
mod dms "dms.just"               # 明示パスも OK
mod bastion
```

呼び出し感は `just db connect` / `just dms run-task` と同じで、UX は形態によらず変わらない。形態で変わるのは cwd と、次節以降の落とし穴。

## monorepo router 構成

```
repo/
├── justfile              # ルーター。mod を宣言し、umbrella recipe を持つ
├── _common.just          # 全 justfile 共通の set と _default
└── packages/
    ├── api/
    │   └── justfile
    ├── web/
    │   └── justfile
    └── ops/
        └── justfile
```

**ルート justfile**:

```just
set dotenv-load := true

import "_common.just"

# Go API (GraphQL)
mod api "packages/api"
# Next.js frontend
mod web "packages/web"
# DevOps / infra
mod ops

# api::check + web::check
check: api::check web::check
    @echo "All checks passed"

# api::setup + web::setup
setup: api::setup web::setup
    @echo "Toolchains ready"
```

**各 mod の justfile** も `_common.just` を import する。パスは import するファイルからの相対で、`packages/api/justfile` からは 2 階層上になる。

```just
# packages/api/justfile
import "../../_common.just"

# fmt + lint + test
check: fmt lint test
    @echo "All checks passed"

# go fmt ./...
fmt:
    go fmt ./...

# ... 以下 recipe
```

`_common.just` の `[default]` が効くので、`just api` で api モジュールの recipe 一覧が出る。

呼び出し:

```bash
just api check
just web build
just ops deploy
```

### 引数伝播つき umbrella recipe

umbrella recipe のパラメータをモジュール recipe に伝播できる。複数モジュールにわたる一発デプロイで多用する。

```just
# tag と sfn_env を各モジュールに渡す
deploy tag=GIT_HASH sfn_env="itg": (docker::build tag) docker::login (docker::push tag) ecs::register config::push (sfn::update sfn_env)
```

- 引数なし呼び出しは `module::recipe`（カッコ不要）
- 引数あり呼び出しは `(module::recipe arg1 arg2)`（必ずカッコで囲む）
- 行が長くなるなら、意味単位で改行する書き方でよい

## 入れ子の mod

mod の中に `mod` を宣言できる（`just db migrate up`）。深さは 2 階層までにする（判断は [`SKILL.md`](../SKILL.md)）。

入れ子にする mod は**ディレクトリ型**にする。ファイル型 mod（`db.just`）の中の `mod migrate` は、`db/migrate.just` ではなく `db.just` と同じディレクトリの `migrate.just` を探す。別の mod が同名のサブ mod を持つと衝突するため。

```
repo/
├── justfile              # mod db
├── _common.just
└── db/
    ├── justfile          # mod migrate
    └── migrate.just
```

```just
# db/justfile
import "../_common.just"

# psql "$DATABASE_URL"
connect:
    psql "$DATABASE_URL"

# Schema migrations
mod migrate
```

サブ mod にも `_common.just` を import する。`just db migrate` でサブ mod の一覧が出る。

## mod 内から同じ mod の recipe を呼ぶ

recipe の依存として書く。依存名は常に自分の mod の recipe を指す。

```just
# migrate + seed
setup: migrate seed
    @echo "Database ready"
```

本文からサブプロセスの `just x` で呼ぶと、**ファイル型 mod では**ルートの `x` が走る。サブプロセスの `just` は cwd から justfile を探し、ファイル型 mod の cwd はルートと同じだから。サブプロセスで呼ぶ必要があるとき（並列実行など）は、mod 自身のファイルを指定する。

```just
# in db.just
reset:
    "{{ just_executable() }}" --justfile "{{ module_file() }}" migrate
```

ディレクトリ型 mod は cwd が mod のディレクトリなので `just x` でも動くが、型を変えたときに壊れるので、統一して上記の書き方にしておく。

## 一覧表示

```bash
just --list               # ルート recipe + モジュール名
just --list api           # api モジュール内の recipe
just --list-submodules    # 全モジュール込みで再帰表示
```

flag はモジュール名の前。`just --list api`（正）／ `just api --list`（誤）。

## 並列実行

`just` は依存の並列実行を直接サポートしない。shebang + shell backgrounding で書く。ルートの recipe から `just api check` と呼ぶ分には、ルートの cwd から mod 名で解決されるので問題ない。

```just
# Run all package checks in parallel
check:
    #!/usr/bin/env bash
    set -uo pipefail
    just api check &  PID1=$!
    just web check &  PID2=$!
    just ops check &  PID3=$!
    FAIL=0
    wait $PID1 || FAIL=1
    wait $PID2 || FAIL=1
    wait $PID3 || FAIL=1
    [ $FAIL -eq 0 ] || { echo "Checks failed"; exit 1; }
    echo "All checks passed"
```

`-euo` ではなく `-uo`。`-e` を付けると最初の `wait` 失敗で残りの wait をスキップしてしまう。

## オプショナル module

```just
mod? optional "packages/optional"
```

環境によって存在しないパッケージがあるときに使う。

## module の doc comment

`mod` の直前のコメントが `just --list` に表示される。書き方は [`doc-comment.md`](doc-comment.md)。
