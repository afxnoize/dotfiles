# secrets の扱い

`.env` は `set dotenv-load` で自動読み込みだが、sops 暗号化 yaml は明示復号が要る。nix ベース（agenix / sops-nix）への移行余地があるため、ここは薄めに留める。

## 変数バインド (backtick + sops extract)

単項を justfile 変数として使いたいとき。recipe 実行のたびに sops 復号が走る点に注意。

```just
db_host := `sops -d --extract '["db"]["host"]' secrets.yaml`
```

## shebang 内で shell 変数に束縛

recipe 1 回の実行中だけ使うとき。他 recipe から見えない。

```just
connect:
    #!/usr/bin/env bash
    pass=$(sops -d --extract '["db"]["password"]' secrets.yaml)
    psql "postgres://admin:$pass@localhost/app"
```

## sops exec-env で env 注入

外部コマンドに複数の secret を env として渡すとき。

```just
run:
    sops exec-env secrets.yaml 'my-tool --db-url "$DATABASE_URL"'
```

## nix 化の検討メモ

- agenix / sops-nix を導入すれば、justfile 内での復号呼び出しはほぼ不要になる（環境に secret が展開された状態で起動する）
- justfile に sops 呼び出しが増えてきたら、管理を nix 側へ寄せる方が healthy
