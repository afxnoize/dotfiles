# 標準 group 名

`[group('...')]` 属性で使う group 名は下記のコアセットに揃える。派生を増やさない。

## コア group

- **`setup`** — 依存と環境の構築・破棄
  - `install`, `update`, `bootstrap`, `clean`, `clean-all`
- **`dev`** — 対話的な開発サイクル
  - dev server, live reload, watch 系の対話ツール起動
- **`build`** — 配布・実行物の生成
  - `build`, `bundle`, artifact 生成
- **`quality`** — 静的コード品質
  - `lint`, `lint-fix`, `format`, `format-check`, `typecheck`
- **`test`** — テスト実行と被覆
  - `test`, `test-unit`, `test-integration`, `test-e2e`, `test-watch`, `coverage`, `coverage-check`
- **`observe`** — ランタイムの観察
  - `logs`, `tail-*`, `status`, `health`, `metrics`, `ps`
  - `logs` は `count="50"` を既定値とするパラメータを持たせる（`just logs` / `just logs 200` のどちらでも動く）
- **`security`** — 依存・ランタイムの脆弱性
  - `audit`, `audit-fix`, `scan`
- **`lifecycle`** — 稼働中サービスのオン・オフ
  - `start`, `stop`, `restart`, `deploy`（サービス単位のデプロイ）
  - `restart` は `stop` + `start` の合成で書く。`stop` は依存の逆順で止める
- **`deploy`** — 本番への反映
  - `deploy`, `release`, `publish`, `rollback`
  - サービス運用系（systemd / compose）の起動停止は `lifecycle` に分け、本番反映と混ぜない
- **`docs`** — プロジェクト文書
  - `docs`, `docs-serve`, `docs-build`

## group を付けない recipe

- **metadata** — `_default`, `help`
- **composite workflow** — `check`, `pre-commit`, `ci`
  - 合成そのものが骨格なので `--list` 上位に素で並べたい

## 境界ルール

- `test-watch` は `test`（対話性より対象で決める）
- `coverage` / `coverage-check` は `test`（独立 group は作らない）
- `clean` は `setup`（環境の構築と破棄は対称）
- `audit` は `quality` ではなく `security`（静的解析とランタイム / 依存脆弱性は別問題）
- `deploy` は存在する時点で mod 昇格候補（state と副作用が重い）。group 運用は軽量プロジェクト用と割り切る

## 拡張方針

- 新しい group を足すのは最終手段。まず既存コアに収まらないか検討する
- どうしても足りないとき: ドメインが他と交わらない・recipe が 3 個以上見込める・既存 group の意味と被らない、の 3 条件を満たすなら追加可
- 足したら本ファイルを更新する
