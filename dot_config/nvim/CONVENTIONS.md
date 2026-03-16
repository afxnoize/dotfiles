## Neovim Configuration Conventions

### エントリポイント
`init.lua` → `lua/base.lua`, `lua/plugins.lua`, `lua/extensions.lua`, `lua/keymaps.lua`, `lua/autocmds.lua` の順に読み込み

### プラグイン設定の配置ルール
| 種類 | 配置先 | 例 |
|------|--------|-----|
| プラグイン定義 | `lua/plugins.lua` | lazy.nvim spec |
| 複雑な設定 | `lua/rc/<name>.lua` | telescope, cmp |
| 単純な設定 | `after/plugin/<name>.rc.lua` | treesitter, lualine |
| LSPサーバー定義 | `lsp/<name>.lua` | ts_ls, lua_ls |
| filetype別設定 | `ftplugin/<ft>.lua` | typescript, markdown |
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
- `]` — LSP操作（]d, ]i, ]f, ]r, ]c, ]F）
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
- skkeleton（日本語入力）が有効なため、cmp のソース設定に skkeleton が含まれる
