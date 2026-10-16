# settings と `_common.just`

いつ読む: justfile を新規作成するとき、`set` を足すとき、mod を追加して設定を揃えるとき。

## mod は設定を継承しない

ルートの `set` は mod に効かない。ルートで `set shell := ["bash", ...]` を指定しても、mod の recipe は素の `sh` で走る。

- `set shell` / `set export` / `set positional-arguments` — mod ごとに有効。mod 自身が書くか、`import` した先に書く
- `set dotenv-load` — ルートでのみ有効。mod に書いても無視され、mod ディレクトリの `.env` も読まれない。ルートが読んだ `.env` の値は、環境変数として mod の recipe にも渡る

## `_common.just` に集約する

mod ごとに `set` を複製すると設定がずれていくため、共通設定は `_common.just` に 1 つ置いて、ルートと全 mod から `import` する。`import` 先の `set` は import した側に効く。

```just
# _common.just
set shell := ["bash", "-c"]

[default]
_default:
    @"{{ just_executable() }}" --justfile "{{ module_file() }}" --list
```

`_default` は `just <mod>`（recipe 名なし）で呼ばれる。`--justfile "{{ module_file() }}"` で自分自身のファイルを指定すると、ファイル型 mod でもディレクトリ型 mod でも、その mod の recipe 一覧が出る。素の `@just --list` はファイル型 mod（`db.just`）でルートの一覧を出してしまう。サブプロセスの `just` は recipe の cwd から justfile を探し、ファイル型 mod の cwd はルートと同じだから。

`[default]` を使うのは、`import` した recipe がファイルの先頭 recipe より後ろに並ぶため。`[default]` がないと、mod の先頭 recipe（`deploy` かもしれない）が `just <mod>` で実行される。`_default` を置かなくてもエラーにならない。

制約:

- `[default]` は 1 つの justfile に 1 つだけ。`_common.just` を import した justfile には別の `[default]` を書かない（重複はエラー）
- `import` のパスは、import するファイルからの相対。`packages/api/justfile` からルートの `_common.just` は `../../_common.just`
- ルートは `set dotenv-load` を自分で書く

雛形は [`templates/`](../templates/) にある。

## `set` の既定

ルートに置くもの:

```just
set dotenv-load := true
```

`set positional-arguments` は既定に入れない。shebang recipe 内で `$1` / `$2` を recipe 引数にマップしたいとき**だけ**明示的に付ける。普段は recipe 引数の interpolation（`{{args}}`）で足りる。

## `set shell` の選択肢

just の既定 shell は `sh`。bash の機能を使うなら明示する。`_common.just` に 1 つだけ書く。

- 裸の bash — `["bash", "-c"]`。mise も nix も使わないオープンソースや、エコシステム非依存にしたいとき
- mise の toolchain — `["mise", "exec", "--", "bash", "-c"]`
- nix の devShell — `["nix", "develop", "-c", "bash", "-c"]`
- strict bash — `["bash", "-euo", "pipefail", "-c"]`

mise と nix は、dev shell に入らなくても `just <recipe>` 一発で所定の toolchain 下で実行できるようにする。`mise activate` / `nix develop` を事前に実行したかに依存せず recipe が動き、CI とのふるまいも揃う。

strict bash は各行が `bash -euo pipefail -c` で実行されるので、失敗時に即終了できる。ただし行をまたいだ変数・状態共有は効かない（その場合は shebang recipe が必要。[`shebang.md`](shebang.md)）。
