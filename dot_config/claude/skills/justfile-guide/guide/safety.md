# 破壊的操作への安全装置

副作用が重い・取り戻せない recipe には `[confirm]` 属性で実行前確認を強制する。

## `[confirm("...")]` を必ず付ける対象

- 本番／共有環境への反映 — `deploy`, `release`, `publish`
- 永続ストレージの破壊 — `db-drop`, `clean-all`, 永続ボリューム削除
- 外部サービスの課金を伴う操作
- 稼働中サービスの停止・無効化 — `systemctl disable`, timer 解除
- IaC の `destroy` — `tofu destroy`, `terraform destroy`, `pulumi destroy`

## 確認メッセージの書き方

「何が起こるか」を具体的に書く。ユーザーに選択を促すには情報量がいる。

```just
# 良い例: 影響範囲が明示されている
[confirm("AWS にデプロイします (ECR push + ECS task def + S3 config + SFN update)。実行する? [y/N]")]
deploy tag=GIT_HASH:
    # ...

[confirm("This will disable and remove the backup timer. Continue?")]
disable-timer:
    systemctl --user disable --now my-backup.timer

# 悪い例: 何が起こるか伝わらない
[confirm("OK?")]
destroy:
    tofu destroy
```

## やってはいけない代替

`@echo` で警告して実行続行する流儀は採らない。ユーザーに止める機会を与えないので `[confirm]` の代替にならない。

```just
# anti-pattern
destroy:
    @echo "This will schedule destroy..."
    tofu destroy
```

## 補助的な属性

- `[no-exit-message]` — 確認拒否時のエラーメッセージを抑制したい場合
- `[private]` — 直接実行させたくない recipe に（`_` prefix の代替として）
