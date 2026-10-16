---
name: justfile-guide
description: |
  Personal justfile / just command runner conventions. Use when reading,
  writing, or editing any justfile, when the user mentions just, recipe,
  mod, import, group, or task automation, or when setting up build /
  command entry points for a project.
---

# Justfile ガイド

自分用の justfile 記述規約。新規作成・編集時は以下に従う。前提は just 1.43.0 以上（`[default]` 属性を使うため）。

## mod と group の役割

整理の軸を 2 つに分け、同じ軸を二重に使わない。同じ分類が mod 名と group 名の両方に現れると、どちらを更新すべきか迷うため。

- **mod** — ドメイン（名詞）で切る。CLI の名前空間になる（`just db migrate`）
- **group** — 工程（動詞）で切る。`--list` の見出しになる（`setup`, `build`, `quality`）。group 名は mod ごとに独立しているので、`quality` がルートと各 mod にあっても衝突しない

運用ルール:

- group 名にドメイン名を使わない
- mod 化したら recipe 名から mod 名の接頭辞を外す（`db-migrate` → `db migrate`）
- mod 宣言に `[group]` を付けない。`--list` では `db ...` と表示されて recipe と見分けがつき、名前空間は mod 名がすでに担っている。付けると recipe 用の見出しの下に紛れて探しにくい
- mod と recipe の同名は定義エラーになる

### mod にするか group にとどめるか

**mod 化する**:
- 独立した関心事で、他から呼ばれる / 状態を持つ / 単体で意味がある
- 関連 recipe が 3 つ以上、もしくは共通 private recipe がある、もしくはパラメータが複雑
- 上記のうち **2 つ以上**を満たすとき

**group にとどめる**:
- どこかのドメインに従属していて単独では存在意義が薄い（log, observe 系はほぼここ）
- 表示の整理だけが目的
- `[group('name')]` 属性で記述する

**昇格ルール**: observe 系が複数ドメインを横断しはじめたら mod に昇格。それまでは親 mod の group 止め。昇格したら元の group は消す。

### mod が複雑化したとき

mod の中身が増えたら、割れ方で対処を変える。mod 宣言への `[group]` は整理にならない（見出しが付くだけ）。

- recipe 名の接頭辞（名詞）が揃ってきた → サブ mod に切る（`migrate-up` / `migrate-down` → `db migrate up`）
- 工程（動詞）で分かれる → mod 内で group を使う
- 入れ子は 2 階層まで。3 階層になるなら mod の切り方がドメインに合っていない

入れ子の書き方は [`guide/mod.md`](guide/mod.md)。

## セクション区切り

`####################` コメントは使わない。`[group('...')]` 属性で `just --list` の表示を整理する。

```just
# bun run build
[group('build')]
build:
    bun run build

# bun run lint
[group('quality')]
lint:
    bun run lint
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

noun-first のカテゴリが mod になったら接頭辞を外す（上記「運用ルール」）。

## 標準 recipe セット

group を付けず、`--list` の上位に素で並べる。合成そのものが骨格だから。

- `check` — `format-check` + `lint` + `typecheck`。非破壊の品質ゲート
- `pre-commit` — `check` + `test-unit`。高速事前チェック
- `ci` — `check` + `test-coverage` + `build`。CI 想定のフル検証
- `clean` — 生成物削除（部分クリーン）
- `clean-all` — `clean` + 依存・キャッシュ削除（フルクリーン）

## settings

mod はルートの `set` を引き継がない。ルートと全 mod に同じ `set shell` と `[default] _default`（引数なしの `just <mod>` で一覧を出す recipe）を効かせるには、`_common.just` に集約して各 justfile から `import` する。`set dotenv-load` だけはルートでしか効かない。

雛形は [`templates/`](templates/)、設計の理由と `set shell` の選択肢は [`guide/settings.md`](guide/settings.md)。

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
# uv run pytest {{args}}
test *args:
    uv run pytest {{args}}
```

## 参照

読むタイミングの目安つき。必要になるまで開かない。

- [`guide/doc-comment.md`](guide/doc-comment.md) — recipe / mod を追加・変更するとき。`#` コメントの書き分け
- [`guide/settings.md`](guide/settings.md) — justfile を新規作成するとき、`set` や `_common.just` を触るとき
- [`guide/mod.md`](guide/mod.md) — justfile を分割するとき、mod を入れ子にするとき、mod 内で他の recipe を呼ぶとき
- [`guide/group.md`](guide/group.md) — `[group]` を付けるとき。標準 group 名と境界ルール
- [`guide/shebang.md`](guide/shebang.md) — 複数行 shell の recipe を書くとき
- [`guide/safety.md`](guide/safety.md) — deploy / destroy など破壊的な recipe を書くとき
- [`guide/secrets.md`](guide/secrets.md) — sops など secret を扱うとき
- [`templates/`](templates/) — root / mod の雛形（`root.just`, `mod-dir.just`, `mod-file.just`, `_common.just`）。コピーして使う
