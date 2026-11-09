local wo = vim.wo
-- 行番号表示
wo.number = true

local opt = vim.opt
--
opt.title = true
opt.relativenumber = true

-- Indent {{{
-- tab to space if true
opt.expandtab = false
-- n spaces are tab
opt.tabstop = 4
-- replace tab to n spaces, or tabstop if this is 0
opt.softtabstop = 0
-- indent is n spaces
opt.shiftwidth = 4
opt.smartindent = true
-- Insert indent
opt.smarttab = true
-- indentを守る
opt.autoindent = true
--- }}}

opt.hlsearch = true

-- dont be afraid
opt.backup = false
opt.swapfile = false

opt.showcmd = true
opt.cmdheight = 1
opt.laststatus = 2
opt.scrolloff = 10
opt.backupskip = { '/tmp/*', '/private/tmp/*' }
opt.inccommand = 'split'
opt.breakindent = true
opt.wrap = false          -- No Wrap lines
opt.backspace = { 'start', 'eol', 'indent' }
opt.path:append({ '**' }) -- Finding files - Search down into subfolders
opt.wildignore:append({ '*/node_modules/*' })
opt.cursorline = true
opt.termguicolors = true
opt.winblend = 0
opt.wildoptions = 'pum'
opt.pumblend = 5

opt.belloff = 'all'

opt.foldmethod = 'marker'
-- opt.foldexpr = 'nvim_treesitter#foldexpr()'

-- Highlight {{{
-- 特殊文字をわかりやすくする
opt.list = true
opt.listchars = [[tab:▸-,trail:-,extends:»,precedes:«]]
-- }}}

-- Search {{{
-- 大文字小文字の区別をしない
opt.ignorecase = true
-- 検索が末尾に届いたら、先頭に戻る
opt.smartcase = true
-- 大文字で検索したときは大文字のみ検索
opt.wrapscan = true
-- 複数一致時、全一致を羅列し、共通最長文字列を補完
opt.wildmode = 'list:longest'
--- }}}

-- Suppress autoindent pasting clipboard (paste is turned off again by the InsertLeave autocmd in autocmds.lua)
vim.keymap.set('n', '<F10>', [[<C-u>exe "normal" (getline(".")==""?"I":"o")<CR>i<C-o>:set paste<CR>]], {})

-- Add asterisks in block comments
opt.formatoptions:append({ 'r' })

-- mapleader
local g = vim.g
g.mapleader = ','
