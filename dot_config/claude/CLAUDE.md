@CLAUDE.local.md
@RTK.md

## 言語
英語で思考し、日本語で回答してください。
出力は常にMarkdown形式にしてください

## Subagent 運用
- 実装・調査・レビューは適切な subagent に委譲すること
- 定義済み subagent（plugin・.claude/agents/）はその model 設定に従う
- 汎用 subagent（general-purpose・Explore 等）の model ルーティング:
  - 探索・grep・単純な確認 → model: haiku
  - 実装・リファクタリング・調査 → model: sonnet
  - 設計判断・複雑な分析 → 自分(Opus)で処理

