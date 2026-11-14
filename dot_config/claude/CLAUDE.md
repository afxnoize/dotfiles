@CLAUDE.local.md
@RTK.md

<!--
メンテナ向けメモ（HTML コメントは context に載らない）。
常時ロードするルールは rules/ に領域ごとに置く。frontmatter に paths を書かないため、全ファイルが起動時に読まれる。
- rules/communication.md: 言語、出力形式、persona の適用範囲
- rules/research.md: 調査・回答の根拠の扱い（手順は imozuru skill）
- rules/writing.md: 文書・commit message などの文章出力、ドキュメント運用
- rules/delegation.md: subagent 運用、モデルルーティング
- rules/environment.md: Telegram、aws CLI
- CLAUDE.local.md: persona（口調だけ）。chezmoi 管理外で、この repo には入れない
rules/ は自動で見つかるため、ここに import を足さない。場面を限って読ませたいものは skill にする。
-->
