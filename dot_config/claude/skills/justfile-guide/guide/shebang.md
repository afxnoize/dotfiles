# shebang recipe の書き方

複数行 shell として評価される shebang recipe の定型。

## 冒頭 2 行は定型

```just
my-recipe:
    #!/usr/bin/env bash
    set -euo pipefail
    # ... 本体
```

- `#!/usr/bin/env bash` — system bash ではなく PATH 優先の bash を呼ぶ（macOS のシステム bash 3.x 回避にも有効）
- `set -euo pipefail` — エラー即終了、未定義変数検出、pipe 途中のエラー伝播

## shebang を使う判断基準

- 変数を行間で共有したい（shell 変数が行をまたぐ必要がある）
- 複雑な条件分岐・ループ
- `trap` で後片付けを確実にしたい
- エラーを細かくハンドリングしたい

## shebang を使わない方がよいケース

- 行単位の単発コマンドで足りる → 素直な複数行 recipe で OK（各行が独立した shell で走る）
- `@` prefix で echo 抑制したい個別行がある → 普通の recipe の方が柔軟

## 例外の `-e`

並列実行で `wait` を使うときは `-euo` ではなく `-uo`。`-e` を付けると最初の `wait` 失敗で残りの wait をスキップしてしまう（`guide/mod.md` 並列実行節を参照）。

## 外部ツール依存の fail-fast

`set shell` で toolchain を auto-activate しないプロジェクトでは、shebang recipe 冒頭でツール存在チェックを入れると親切。

```just
diff-config:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v dyff >/dev/null || { echo "dyff not installed. run 'nix develop' first" >&2; exit 1; }
    dyff between a.yaml b.yaml
```

複数ツール依存なら `doctor` recipe を立てて一括確認するのもよい。

```just
doctor:
    #!/usr/bin/env bash
    MISSING=0
    check() { command -v "$1" &>/dev/null || { echo "WARN: $1 is not installed"; MISSING=1; }; }
    check jq
    check yq
    check sops
    exit $MISSING
```

`set shell := ["mise", "exec", "--", "bash", "-c"]` 等で toolchain を自動 activate しているプロジェクトでは基本不要。

## 一時ファイルの後片付け

`mktemp` で一時ファイル / ディレクトリを作ったら、必ず `trap ... EXIT` で片付ける。

```just
diff-config:
    #!/usr/bin/env bash
    set -euo pipefail
    current=$(mktemp)
    new=$(mktemp)
    trap 'rm -f "$current" "$new"' EXIT
    generate-current > "$current"
    generate-new > "$new"
    diff -u "$current" "$new"
```

`mktemp -d` でディレクトリを作った場合は `rm -rf "$tmpdir"`。`trap` は `set -e` による途中終了でも発火するので安全。
