---
name: git-wt-guide
description: >
  git-wt (git worktree wrapper by k1LoW) のコマンドリファレンスとワークフローガイド。
  git worktree、ワークツリー、並行ブランチ作業、worktree の作成・切替・削除、
  git wt コマンドの使い方について質問されたときに使用する。
  ユーザーが worktree 関連の操作を行おうとしている場合も積極的にトリガーすること。
user-invocable: true
---

# git-wt Reference

git-wt は `git worktree` をラップし、直感的なインターフェースと自動化機能を提供するGitサブコマンド。
このドキュメントは **v0.17.0** 時点の情報に基づく。

## Quick Reference

```bash
git wt                    # worktree 一覧表示
git wt <branch>           # 作成 or 切替（なければブランチも新規作成）
git wt <branch> <start>   # 特定のコミット/ブランチから作成
git wt -d <branch>        # 安全な削除（マージ済みのみ）
git wt -D <branch>        # 強制削除
git wt --init <shell>     # シェル統合の初期化
```

## Core Concepts

- **1コマンドで作成 or 切替**: `git wt feature-x` だけでブランチ＋worktreeの作成、既存なら切替
- **シェル統合**: `eval "$(git wt --init zsh)"` で自動cd＋補完が有効に
- **ファイル同期**: untracked/ignored/modified ファイルを新worktreeにコピー可能
- **ライフサイクルhook**: 作成後・削除前にコマンド自動実行（`npm install` 等）

## Configuration

git config の `wt.*` 名前空間で設定。CLI フラグ → git config → デフォルト の優先順。

主要設定:
- `wt.basedir` — worktree配置先（デフォルト: `.wt`）
- `wt.copyuntracked` / `wt.copyignored` / `wt.copymodified` — ファイルコピー制御
- `wt.copy` / `wt.nocopy` — gitignore構文のパターンマッチ
- `wt.hook` — 作成後フック

詳細なコマンドリファレンス・設定・ワークフロー例は [reference.md](reference.md) を参照。
トラブルシューティングは [troubleshooting.md](troubleshooting.md) を参照。
