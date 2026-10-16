# doc comment 規約

いつ読む: recipe / mod を追加・変更するとき。`just --list` に出る文字列の書き分けを決める。

## 仕組み

- recipe の直前にある `#` コメント 1 行が `--list` の説明になる。コメントが複数行並んでいるときは最後の 1 行だけが使われる
- `[doc('...')]` は直前の `#` を上書きする。`[doc]`（引数なし）は説明を消すだけで、recipe は隠れない。`--list` から隠すのは `_` 接頭辞か `[private]`
- 属性（`[group]`, `[doc]` など）はコメントの後ろに置く。コメントを属性の間や属性と recipe の間に挟むと構文エラーになる

## 書き分け

本文が 1 コマンド行（`@` 接頭辞や `\` 継続で 1 論理行になるものを含む）なら、説明文ではなくコマンドそのものを書く。この規模ではコマンドのほうが説明文より情報量が多く、`--list` で実行内容がそのまま見えるため。

```just
# npm install
[group('setup')]
install:
    npm install
```

引数は展開前の形（`{{args}}`）のまま書く。コメントは展開されない。

```just
# uv run pytest {{args}}
test *args:
    uv run pytest {{args}}
```

それ以外は次のとおり。

- **依存だけの recipe** — 依存名を `+` でつなぐ。本文が `@echo` 1 行だけでも同じ。依存の並びが recipe の中身そのものなので

  ```just
  # format-check + lint + typecheck
  check: format-check lint typecheck
      @echo "All checks passed"
  ```

- **2 行以上 / shebang / 120 字超** — 説明文を書く。コマンドを並べても読みにくく、意図が伝わらないため

  ```just
  # Set up development environment
  [group('setup')]
  dev-setup:
      npm install
      cp .env.example .env
  ```

- **mod 宣言** — ドメインを一言で書く。`--list` のトップに並ぶ

  ```just
  # PostgreSQL migration & seeding
  mod db
  ```

## 理由を残したい 1 行 recipe

フラグの選択が意思決定を含む場合（`--legacy-peer-deps` など）は、理由を `#`、`--list` に出すコマンドを `[doc]` に書く。理由はソース内に残り、`--list` にはコマンドが出る。

```just
# peer-dep conflict workaround

[doc('npm install --legacy-peer-deps')]
[group('setup')]
install:
    npm install --legacy-peer-deps
```

`#` と `[doc]` の間の空行は必須。空行がないと `just --fmt` が理由のコメントを削除する（just 1.43.1 で確認）。
