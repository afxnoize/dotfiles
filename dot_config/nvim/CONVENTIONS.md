## Neovim Configuration Conventions

### エントリポイント
`init.lua` → `lua/base.lua`, `lua/plugins.lua`, `lua/extensions.lua`, `lua/keymaps.lua`, `lua/autocmds.lua` の順に読み込み

### プラグイン設定の配置ルール
| 種類 | 配置先 | 例 |
|------|--------|-----|
| プラグイン定義 | `lua/plugins.lua` | lazy.nvim spec |
| 複雑な設定 | `lua/rc/<name>.lua` | telescope, cmp |
| 単純な設定 | `after/plugin/<name>.rc.lua` | treesitter, lualine |
| LSPサーバー定義 | `lsp/<name>.lua` | vtsls, lua_ls |
| filetype別設定 | `ftplugin/<ft>.lua` | markdown, gitcommit |
| filetype検出 | `ftdetect/<name>.lua` | moonbit, tmux |

### 命名規約
- `after/plugin/` のファイルは `.rc.lua` サフィックスを使用
- 無効化するプラグインは `empty_<name>.rc.lua`（ファイルを消さずに空にする）

### キーマッププレフィクス
- Leader: `,`
- `<Leader><Tab>` — タブ操作
- `<Leader>t` — floaterm ターミナル
- `<Leader>g` — git操作
- `<Leader>f` — telescope
- `]` — LSP操作（]d, ]i, ]f, ]r, ]a, ]F）。`]c` は gitsigns の hunk 移動と diff 標準に空けてある
- `m` — motion系

### プラグイン設定のパターン
```lua
-- after/plugin/ での安全なrequireパターン
local ok, plugin = pcall(require, 'name')
if not ok then return end
plugin.setup({ ... })
```

### ファイラー
- **oil.nvim**: デフォルトファイルエクスプローラ（`default_file_explorer = true`）
- **telescope file_browser**: `sf` でカレントバッファのディレクトリを開く（隠しファイル表示、gitignore無視）
- **fern.vim**: `:Fern` コマンドで利用可能（サイドバー型ファイラー）

### Gotchas
- `lua/plugins.lua` は lazy.nvim の spec 定義のみ。setup() は `after/plugin/` か `lua/rc/` で行う
- LSP設定は `lsp/` に最小限のオプションのみ。keymapは `after/plugin/lsp.rc.lua` の LspAttach で一元管理
- mason に入れたサーバーは `automatic_enable` で全部 enable される。別のクライアントと役割が重なるもの（ts_ls は vtsls と、stylua は null-ls と重複）は `lsp.rc.lua` の `exclude` で外す。重複すると診断が二重に出て、`]F` が整形を全員分実行するため。mason 管理外の kakehashi は `lsp.rc.lua` で `vim.lsp.enable` する
- 2スペース indent の filetype（css, html, javascript 系, json, jsonc, nix, sass, scss, typescript 系, vue, xhtml ほか php, eruby など html を連鎖読み込みするもの）は `lua/autocmds.lua` の `TwoSpaceIndent` に集約している。個別の `ftplugin/` は作らず、ここに足す。`typescript.tsx` のような複合 filetype は `.` で分割して各要素を判定するため、要素側（typescript）が載っていれば足りる
- kakehashi の `searchPaths` に nvim-treesitter の `runtime` を入れている。autoInstall が落とす `typescript/highlights.scm` は `; inherits: ecma` なのに `ecma` を落とさず、足さないと TS の semantic token が空になるため
- lazy.nvim は `defaults.lazy = true`。`event` / `cmd` / `ft` / `keys` のどれも無いプラグインは、他から `require` されない限り一度も load されない（setup() が走らず、設定が黙って無効になる）。常時 load したいものは `lazy = false` を付ける
- skkeleton（日本語入力）が有効なため、cmp のソース設定に skkeleton が含まれる
