---
name: justfile-guide
description: |
  Personal justfile / just command runner conventions. Use when reading,
  writing, or editing any justfile, when the user mentions just, recipe,
  mod, group, or task automation, or when setting up build / command
  entry points for a project.
---

# Justfile ガイド

自分用の justfile 記述規約。新規作成・編集時は以下に従う。

## mod vs group の判断

**mod 化する**:
- 独立した関心事で、他から呼ばれる / 状態を持つ / 単体で意味がある
- 関連 recipe が 3 つ以上、もしくは共通 private recipe がある、もしくはパラメータが複雑
- 上記のうち **2 つ以上**を満たすとき

**group にとどめる**:
- どこかのドメインに従属していて単独では存在意義が薄い（log, observe 系はほぼここ）
- 表示の整理だけが目的
- `[group('name')]` 属性で記述する

**昇格ルール**: observe 系が複数ドメインを横断しはじめたら mod に昇格。それまでは親 mod の group 止め。

## セクション区切り

`####################` コメントは使わない。`[group('...')]` 属性で `just --list` の表示を整理する。

```just
[group('dev')]
build:
    # bun run build

[group('quality')]
lint:
    # bun run lint
```

group 名は自由に増やさず、標準セットに揃える。詳細は [`guide/group.md`](guide/group.md)。


## 命名規約

| ルール | 例 |
|---|---|
| kebab-case 必須（snake_case / camelCase は禁止） | `test-unit`, `format-check`（not `test_unit`） |
| verb-first (動作) | `lint`, `build`, `clean` |
| noun-first (カテゴリ) | `db-migrate`, `docs-serve` |
| private 接頭辞 | `_setup`, `_generate-secrets` |
| `-check` 接尾辞 | 読み取り専用検証（`format-check`） |
| `-fix` 接尾辞 | 自動修正（`lint-fix`） |
| `-watch` 接尾辞 | watch mode |
| modifier は後置 | `build-release` (not `release-build`) |

## doc comment 規約

`just --list` に出る文字列は、`#` コメントまたは `[doc('...')]` 属性で決まる。`[doc(...)]` があれば直前の `#` は抑制され、`#` は実装メモとして残せる。

**1 行 recipe（自己説明的）** → `#` に実コマンドを書く。説明文は書かない。

```just
# npm install
[group('setup')]
install:
    npm install
```

**1 行 recipe（説明が要る）** → `[doc('...')]` を使う。`#` は実装メモに回せる。

以下のいずれかを満たすとき説明を付ける:

1. フラグの選択が意思決定を含む（`--legacy-peer-deps`, `-race -short`, `--unsafe-fixes` 等、なぜそのフラグかを名前で表現しきれない）
2. コマンドが cryptic（awk / sed / jq one-liner、短い composite pipe）
3. recipe 名が抽象的で、どこへ・何を・が曖昧（`deploy`, `sync` など）
4. 副作用・前提が自明でない（外部サービスを叩く、ネット必要、destructive）

```just
# Install deps (workaround for peer-dep conflict)
[doc('npm install --legacy-peer-deps')]
[group('setup')]
install:
    npm install --legacy-peer-deps
```

**shebang / multi-line / 120 字超** → `#` に descriptive コメントを書く。

```just
# Set up development environment
[group('setup')]
dev-setup:
    npm install
    cp .env.example .env
    just db-migrate
```

**module 宣言** → `#` でドメインの一言を書く。`just --list` に並ぶ。

```just
# PostgreSQL migration & seeding
mod db "modules/db"
```

**`--list` から隠す** → `[doc]`（引数なし）。`[private]` は使わないが `--list` のノイズになる補助 recipe 向け。prefix:`_`で十分.

```just
[doc]
_helper:
    @echo internal
```

## 標準 recipe セット

| recipe | 合成 | 用途 |
|---|---|---|
| `_default` | `@just --list` | 既定アクション（詳細は下記） |
| `check` | `format-check` + `lint` + `typecheck` | 非破壊の品質ゲート |
| `pre-commit` | `check` + `test-unit` | 高速事前チェック |
| `ci` | `check` + `test-coverage` + `build` | CI 想定のフル検証 |
| `clean` | 生成物削除 | 部分クリーン |
| `clean-all` | `clean` + 依存・キャッシュ削除 | フルクリーン |

### `_default` を徹底する

ルートにもすべての mod にも `_default` recipe を置き、中身は `@just --list` に固定する。

```just
_default:
    @just --list
```

- **private prefix `_`** にすることで `just --list` 自身に `_default` が出現しない
- `just` 単独実行 → ルートの recipe 一覧
- `just modA` → `modA` の recipe 一覧（`_default` がないと missing recipe エラー）
- justfile / モジュール justfile の**先頭**に置く（just は最初の recipe を既定として呼ぶ）

## settings 既定

```just
set dotenv-load
```

`set positional-arguments` は既定に入れない。shebang recipe 内で `$1` / `$2` を recipe 引数にマップしたいとき**だけ**明示的に付ける。普段は recipe 引数の interpolation（`{{args}}`）で足りる。

`set shell` はオプトイン。裸の `bash` を既定とし、プロジェクトの要件で選ぶ。

### toolchain auto-activate（主眼）

dev shell に入らなくても `just <recipe>` 一発で所定の toolchain 下で実行できるようにする。CI とのふるまい統一にも使える。

```just
# mise 前提
set shell := ["mise", "exec", "--", "bash", "-c"]

# nix devShell 前提
set shell := ["nix", "develop", "-c", "bash", "-c"]
```

開発者が `mise activate` / `nix develop` を事前に実行したかに依存せず recipe が動く、という体験が得られる。

### strict bash（副次）

安全性を上げたいなら strict モードで上書きできる。

```just
set shell := ["bash", "-euo", "pipefail", "-c"]
```

各行が `bash -euo pipefail -c` で実行されるため、失敗時に即終了できる。ただし行をまたいだ変数・状態共有は効かない（shebang recipe が必要）。

### どれも足さない場合

裸の `bash`（厳格化なし、toolchain 非依存）。mise も nix も使わないオープンソースや、エコシステム非依存にしたいときはこの既定のままでよい。

## Parameters

| 形 | 意味 |
|---|---|
| `recipe param:` | 必須 |
| `recipe param="default":` | 任意、既定値あり |
| `recipe +FILES:` | 1 個以上 variadic |
| `recipe *FLAGS:` | 0 個以上 variadic |
| `recipe $VAR:` | env var として export |

passthrough が必要な recipe は `*args` を既定に。

```just
test *args:
    uv run pytest {{args}}
```

## 参照

- [`guide/group.md`](guide/group.md) — 標準 group 名と境界ルール
- [`guide/mod.md`](guide/mod.md) — monorepo で `mod` を使った構成
- [`guide/secrets.md`](guide/secrets.md) — sops 連携（nix 化検討中のため薄め）
- [`guide/safety.md`](guide/safety.md) — 破壊的操作への `[confirm]` 運用
- [`guide/shebang.md`](guide/shebang.md) — shebang recipe の書き方と判断基準
