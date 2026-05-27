# サクラエディタ用設定

Windows のサクラエディタ向けカスタマイズ一式。Linux 上では使われないため
chezmoi の管理対象外として、必要なときに手動で Windows へ持っていく。

対象バージョン: Sakura Editor **v2.4.2** (`vStructureVersion=177`)

## ファイル

| ファイル | 用途 |
| --- | --- |
| `markdown_catppuccin_latte.ini` | Markdown 用タイプ別設定 (Catppuccin Latte 配色) |
| `open_in_shiba.mac` | 現在のファイルを [Shiba](https://github.com/rhysd/Shiba) でプレビューする外部マクロ |

## 1. カラーテーマのインポート

1. サクラエディタを開く
2. **設定 → タイプ別設定一覧**
3. 「種別追加」あるいは既存の Markdown 設定を選んで「設定変更」
4. 「インポート」→ `markdown_catppuccin_latte.ini` を指定
5. 適用後、`*.md` ファイルを開いて配色を確認

ファイルは UTF-8 BOM + CRLF で保存済み。色は BGR 順 (`COLORREF` 形式) のため、
RGB の hex とは並びが異なる点に注意 (例: Latte Base `#eff1f5` → ini 中では `f5f1ef`)。

### 配色マッピング

| 用途 | RxKey | Catppuccin Latte |
| --- | --- | --- |
| Bold (`**` `__` `***` `___`) | RK1 | Maroon |
| Italic (`*` `_`) | RK2 | Pink |
| Heading (`#` 記号のみ) | RK3 | Blue |
| Inline code (`` ` ``) | RK4 | Peach (Surface0 bg) |
| Link / image text | RK5 | Mauve |
| URL / autolink | RK6 | Sky (underline) |
| Blockquote (`>` 記号 + 行 bg) | RK7 | Subtext0 + Mantle |
| List marker / task / table | RK8 | Yellow |
| HR / strikethrough | RK9 | Overlay1 |
| Code fence / ref-def label | RKA | Teal |

行全体の色変えは避け、ブロック要素は記号のみ着色する方針。
`C[EBK]` (偶数行背景) は **必ず off** のまま (Excel ゼブラ縞防止)。

## 2. Shiba プレビュー連携 (`open_in_shiba.mac`)

[Shiba](https://github.com/rhysd/Shiba) をインストールしたうえで、
キーバインドから現在編集中の Markdown を Shiba で開けるようにする。

### マクロの内容

```
ExecCommand("\"C:\\Program Files\\Shiba\\shiba.exe\" \"$F\"", 0);
```

- `$F` は `CSakuraEnvironment::ExpandParameter` により現在ファイルの絶対パスに展開される
- exe パスは外側ダブルクォートで囲んでいる (`Program Files` のスペース対策)
- 第二引数 `0` = stdin/stdout のリダイレクトなし (GUI アプリ起動)
- インストール先が違う場合は `.mac` の中身を書き換える

### 登録手順

1. **マクロ登録**
   - 設定 → 共通設定 → **マクロ**
   - 空きスロット (0 〜 49 のどれか) を選び、`open_in_shiba.mac` のパスを指定
   - 名前: `Open in Shiba` 等わかりやすい名前
2. **キー割り当て**
   - 設定 → 共通設定 → **キー割り当て**
   - 機能の種類: **外部マクロ**
   - 上で登録したマクロを選ぶ
   - キー: `Ctrl+Shift+P` などお好みで
   - 「割り付け」→「OK」

### 注意

- `.mac` の文法は **`関数名(引数, ...);`** (カッコ必須、セミコロン終端)。
  スペース区切り (`ExecCommand "..." 0;`) では「存在しない関数」エラーになる。
- パス区切りはエスケープが必要 (`\\`)。ダブルクォート自身も `\"` でエスケープ。
- マクロ追加後、サクラエディタの再起動は不要 (キー割り当てを保存すれば即反映)。

## 参考

- 元配色のベース: [KeitetsuWorks/Sakura_Monokai](https://github.com/KeitetsuWorks/Sakura_Monokai)
- パレット: [catppuccin/catppuccin](https://github.com/catppuccin/catppuccin)
- C[XXX] と内部 enum の対応は `sakura_core/view/colors/EColorIndexType.h` および
  `sakura_core/view/colors/CColorStrategy.cpp` の `g_ColorAttributeArr` を参照
