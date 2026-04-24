# Module (mod) 使用ガイド

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

## 基本構文

```just
mod <name> "<path>"              # 必須モジュール
mod? <name> "<path>"             # 任意モジュール（存在しなくてもエラーにならない）
mod <name>                       # ./<name>/justfile または ./<name>.just を自動解決
```

## 分割の 2 形態

- **ディレクトリ分割 (`packages/api/justfile`)** — パッケージが独立したコード・依存・build 成果物を持つとき。monorepo の真のサブパッケージ向け
- **ファイル単位 (`db.just`)** — 同一 working dir で動く recipe 群をドメインで名前空間分けしたいとき。IaC / 運用スクリプトで多い

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

呼び出し感は `just db connect` / `just dms run-task` と同じで、UX はディレクトリ分割と変わらない。

## monorepo router 構成

```
repo/
├── justfile              # ルーター。モジュールを import するだけ
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
_default:
    @just --list

# Go API (GraphQL)
mod api "packages/api"

# Next.js frontend
mod web "packages/web"

# DevOps / infra
mod ops "ops"

# umbrella recipes — モジュールに委譲
check: (api::check) (web::check)
    @echo "All checks passed"

setup: (api::setup) (web::setup)
    @echo "Toolchains ready"
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

**各モジュール justfile** も必ず先頭に `_default` を持つ:

```just
# packages/api/justfile
_default:
    @just --list

check: fmt lint test
    @echo "All checks passed"

fmt:
    go fmt ./...

# ... 以下 recipe
```

これで `just api` で api モジュールの recipe 一覧が出る（無いと missing recipe エラーになる）。

呼び出し:

```bash
just api check
just web build
just ops deploy
```

## Working Directory

モジュール内 recipe は、そのモジュール直下をカレントディレクトリとして実行される。package-local command を書くとき想定どおりに動く。

## 一覧表示

```bash
just --list               # ルート recipe + モジュール名
just --list api           # api モジュール内の recipe
just --list-submodules    # 全モジュール込みで再帰表示
```

flag はモジュール名の前。`just --list api`（正）／ `just api --list`（誤）。

## 呼び出し

```bash
just api check            # CLI から
(api::check)              # 他 recipe の依存として
```

## 並列実行

`just` は依存の並列実行を直接サポートしない。shebang + shell backgrounding で書く。

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

## module doc comment

`mod` の直前のコメントは `just --list` に表示される。必ず付ける。

```just
# Go API (GraphQL + Watermill)
mod api "packages/api"

# PostgreSQL migration & seeding
mod db "packages/db"
```

出力例:

```
api ...      # Go API (GraphQL + Watermill)
db  ...      # PostgreSQL migration & seeding
```

## オプショナル module

```just
mod? optional "packages/optional"
```

環境によって存在しないパッケージがあるときに使う。
