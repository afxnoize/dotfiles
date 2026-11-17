-- 行番号表示
vim.opt.number = true

--
vim.opt.title = true
vim.opt.relativenumber = true

-- Indent {{{
-- tab to space if true
vim.opt.expandtab = false
-- n spaces are tab
vim.opt.tabstop = 4
-- replace tab to n spaces, or tabstop if this is 0
vim.opt.softtabstop = 0
-- indent is n spaces
vim.opt.shiftwidth = 4
vim.opt.smartindent = true
-- Insert indent
vim.opt.smarttab = true
-- indentを守る
vim.opt.autoindent = true
--- }}}

vim.opt.hlsearch = true

-- dont be afraid
vim.opt.backup = false
vim.opt.swapfile = false

vim.opt.showcmd = true
vim.opt.cmdheight = 1
vim.opt.laststatus = 2
vim.opt.scrolloff = 10
vim.opt.backupskip = { '/tmp/*', '/private/tmp/*' }
vim.opt.inccommand = 'split'
vim.opt.breakindent = true
vim.opt.wrap = false          -- No Wrap lines
vim.opt.backspace = { 'start', 'eol', 'indent' }
vim.opt.path:append({ '**' }) -- Finding files - Search down into subfolders
vim.opt.wildignore:append({ '*/node_modules/*' })
vim.opt.cursorline = true
vim.opt.termguicolors = true
vim.opt.winblend = 0
vim.opt.wildoptions = 'pum'
vim.opt.pumblend = 5

vim.opt.belloff = 'all'

vim.opt.foldmethod = 'marker'
-- vim.opt.foldexpr = 'nvim_treesitter#foldexpr()'

-- Highlight {{{
-- 特殊文字をわかりやすくする
vim.opt.list = true
vim.opt.listchars = 'tab:▸-,trail:-,extends:»,precedes:«'
-- }}}

-- Search {{{
-- 大文字小文字の区別をしない
vim.opt.ignorecase = true
-- 検索が末尾に届いたら、先頭に戻る
vim.opt.smartcase = true
-- 大文字で検索したときは大文字のみ検索
vim.opt.wrapscan = true
-- 複数一致時、全一致を羅列し、共通最長文字列を補完
vim.opt.wildmode = 'list:longest'
--- }}}

-- Add asterisks in block comments
vim.opt.formatoptions:append({ 'r' })

-- mapleader
vim.g.mapleader = ','
