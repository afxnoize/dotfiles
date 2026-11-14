# herdr app Cheat Sheet

herdr app の既定のショートカット。LiRu の `~/.config/herdr-app/keys.json`（2026-11-14 時点）から写した。Windows の app の `keys.json`（`%APPDATA%` 側）とは突き合わせていない。

- 構成: space（repo ごと）> tab（作業ごと）> pane（shell や Claude Code を並べる）
- 一覧は app の中で `Ctrl-?` で開く

## Pane
- `Ctrl-Shift-o`: 右に分割
- `Ctrl-Shift-e`: 下に分割
- `Ctrl-Shift-x`: 閉じる
- `Ctrl-Shift-z`: ズーム
- `Alt-h/j/k/l`, `Alt-←/→`: 隣の pane へ移動
- `Alt-Shift-h/j/k/l`: 隣の pane と入れ替え
- `Alt-↑/↓`: agent（Claude Code など）が動く pane を順に移動

## Tab
- `Ctrl-1..9`: 番号の tab へ
- `Ctrl-Tab`, `Ctrl-PageDown`, `Alt-]`: 次の tab
- `Ctrl-Shift-Tab`, `Ctrl-PageUp`, `Alt-[`: 前の tab
- `Ctrl-Shift-t`: 新しい tab
- `Ctrl-Shift-w`: 閉じる
- `F2`: 名前を付ける

## Space
- `Alt-1..9`: 番号の space へ
- `Ctrl-Shift-PageDown` / `Ctrl-Shift-PageUp`: 次 / 前の space
- `Ctrl-Shift-n`: 新しい space
- `Shift-F2`: 名前を付ける

## Terminal
- `Ctrl-Shift-c` / `Ctrl-Shift-v`: コピー / 貼り付け
- `Ctrl-v`: 画像を貼り付け
- `Ctrl-Shift-f`: 検索

## その他
- `Ctrl-Shift-p`: コマンドパレット
- `Ctrl-Shift-k`: picker
- `Ctrl-Shift-b`: サイドバーの表示切り替え
- `Ctrl-Shift-l`: layout の切り替え
- `Ctrl-,`: 設定

## 注意
- app が割り当てたキーは、ターミナルの中のプログラムに届かない。返すには `keys.json` の `terminal` 節に `"<key>": "terminal"` と書く
- `keys.json` を一度でも編集すると、以後のアップデートで既定のショートカットが更新されなくなる。新しい既定値は手で足す
