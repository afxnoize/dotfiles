---
name: cage-adviser
description: >
  Diagnoses cage (Landlock) sandbox permission errors and suggests presets.yaml fixes.
  Use when any tool fails with "permission denied", "read-only file system",
  "operation not permitted", "landlock", or "EACCES" while IN_CAGE=1.
user-invocable: true
allowed-tools: Read
---

# cage-adviser

cage は Landlock LSM によるサンドボックスで、**書き込みのみを制限**する。

## presets.yaml 仕様

場所: `$XDG_CONFIG_HOME/cage/presets.yaml`

```yaml
presets:
  name:
    allow:
      - "$ENV_VAR"                    # 環境変数展開可能
      - path: "/tmp"
        eval-symlinks: true           # symlink を実パスに解決
    allow-git: true                   # git common directory への書き込み許可
    allow-keychain: true              # macOS keychain への書き込み許可

auto-presets:
  - command: claude                   # 完全一致
    presets: [base, dev-tools]
  - command-pattern: "cargo.*"        # 正規表現マッチ
    presets: [base]
```

## 診断手順

1. エラー出力から**拒否されたパス**と**操作種別**を特定する
2. `$XDG_CONFIG_HOME/cage/presets.yaml` を読み、現在の許可パスを確認する
3. 修正案を提示する:
   - git 関連エラーには `allow` ではなく `allow-git: true` を検討する
   - パスは環境変数で表現する（`$CARGO_HOME`, `$XDG_CACHE_HOME`, `$DENO_DIR` 等）
   - symlink が関係する場合は `eval-symlinks: true` を使う
   - 既存プリセットへの追記を優先し、新規作成は用途が異なる場合のみ
   - 最小権限の原則に従う
