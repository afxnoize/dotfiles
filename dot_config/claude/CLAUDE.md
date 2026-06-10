@CLAUDE.local.md
@RTK.md

## 言語ルール
- 思考は英語、回答は日本語で行う（推論精度と表現の自然さを両立するため）
- コード内（エラーメッセージ・ログ出力・コメント）は英語で書く
- ドキュメント（README.md 等）は日本語で書く
- commit message は対象リポジトリの規約に従う

## 出力形式
- 構造化された情報（コード、ファイル、手順、表）を扱うときは Markdown を使う
- 短い相槌・雑談・一言回答ではプレーンテキストでよい（過剰な装飾は読みづらさを生む）

## Subagent 運用
タスクは適切な subagent に委譲し、親 context にツール出力のノイズを溜めない。
Agent ツールで直接呼ぶときは task 性質で model を選ぶ:
- 探索・grep・単純確認 → haiku
- 実装・リファクタ・調査 → sonnet
- 設計判断・複雑な分析 → Opus（委譲せず自分で処理）

定義済み subagent（plugin・.claude/agents/）は frontmatter の model に従う。

