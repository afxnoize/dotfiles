---------------------------------------------------------------------------------------------------+
-- Commands \ Modes | Normal | Insert | Command | Visual | Select | Operator | Terminal | Lang-Arg |
-- ================================================================================================+
-- map  / noremap   |    @   |   -    |    -    |   @    |   @    |    @     |    -     |    -     |
-- nmap / nnoremap  |    @   |   -    |    -    |   -    |   -    |    -     |    -     |    -     |
-- map! / noremap!  |    -   |   @    |    @    |   -    |   -    |    -     |    -     |    -     |
-- imap / inoremap  |    -   |   @    |    -    |   -    |   -    |    -     |    -     |    -     |
-- cmap / cnoremap  |    -   |   -    |    @    |   -    |   -    |    -     |    -     |    -     |
-- vmap / vnoremap  |    -   |   -    |    -    |   @    |   @    |    -     |    -     |    -     |
-- xmap / xnoremap  |    -   |   -    |    -    |   @    |   -    |    -     |    -     |    -     |
-- smap / snoremap  |    -   |   -    |    -    |   -    |   @    |    -     |    -     |    -     |
-- omap / onoremap  |    -   |   -    |    -    |   -    |   -    |    @     |    -     |    -     |
-- tmap / tnoremap  |    -   |   -    |    -    |   -    |   -    |    -     |    @     |    -     |
-- lmap / lnoremap  |    -   |   @    |    @    |   -    |   -    |    -     |    -     |    @     |
---------------------------------------------------------------------------------------------------+

local keymap = vim.keymap

-- １文字貼り付け防止
keymap.set({ 'n', 'x' }, 'x', '"_x', { desc = 'Delete character without yanking' })

-- 水平移動
keymap.set({ 'n', 'x', 'o' }, 'H', '^', { desc = 'Start of line (first non-blank)' })
keymap.set({ 'n', 'x', 'o' }, 'L', 'g_', { desc = 'End of line (last non-blank)' })

-- インデントしても選択領域を保持
keymap.set('v', '<', '<gv', { desc = 'Outdent and keep selection' })
keymap.set('v', '>', '>gv', { desc = 'Indent and keep selection' })
keymap.set('v', '=', '=gv', { desc = 'Reindent and keep selection' })

-- `*`検索の初回移動無効{{{
keymap.set('n', '*', function()
	return vim.v.count >= 1 and '*'
		or [[<Cmd>sil exe "keepj norm! *" <Bar> call winrestview(]]
		.. vim.fn.string(vim.fn.winsaveview())
		.. ')<CR>'
end, { silent = true, expr = true, desc = 'Search word under cursor without moving' })
-- }}}

-- save
keymap.set('n', '<Leader>w', '<Cmd>w<CR>', { silent = true, desc = 'Save' })

-- clear hylight
keymap.set('n', '<Esc><Esc>', '<Cmd>nohlsearch<CR>', { noremap = false, desc = 'Clear search highlight' })

-- Make inputting a character by code easily.{{{
keymap.set(
	'i',
	'<Plug>(vimrc-input-char-by-code)',
	[[<C-r>=nr2char(eval(input('char? ', '0x')))<CR>]],
	{ noremap = true, desc = 'Insert character by code' }
)
keymap.set('i', '<C-v>x', '<Plug>(vimrc-input-char-by-code)', { noremap = false, desc = 'Insert character by code' })
keymap.set('i', '<C-v>u', '<Plug>(vimrc-input-char-by-code)', { noremap = false, desc = 'Insert character by code' })
keymap.set('i', '<C-v>U', '<Plug>(vimrc-input-char-by-code)', { noremap = false, desc = 'Insert character by code' })
-- }}}

-- Toggle quickfix window {{{
keymap.set('n', '<Leader>q', function()
	local nr = vim.fn.winnr('$')
	vim.cmd.cwindow()
	local nr2 = vim.fn.winnr('$')
	if nr == nr2 then
		vim.cmd.cclose()
	end
end, { silent = true, desc = 'Toggle quickfix window' })
-- }}}

-- prefixes {{{
keymap.set('n', '<Leader><Tab>', '<Nop>', { desc = 'Tab prefix' })
keymap.set('n', '<Leader>t', '<Nop>', { desc = 'Terminal prefix' })
keymap.set('n', '<Leader>f', '<Nop>', { desc = 'Telescope prefix' })
keymap.set('n', '<Leader>g', '<Nop>', { desc = 'Git prefix' })
keymap.set('n', 'm', '<Nop>', { desc = 'Motion prefix' })
-- }}}

-- tab {{{
keymap.set('n', '<Leader><Tab>n', '<Cmd>tabnext<CR>', { silent = true, desc = 'Next tab' })
keymap.set('n', '<Leader><Tab>p', '<Cmd>tabprevious<CR>', { silent = true, desc = 'Previous tab' })
keymap.set('n', '<Leader><Tab>e', '<Cmd>tabedit<CR>', { silent = true, desc = 'New tab' })
keymap.set('n', '<Leader><Tab>x', '<Cmd>tabclose<CR>', { silent = true, desc = 'Close tab' })
keymap.set('n', '<Leader><Tab>o', '<Cmd>tabonly<CR>', { silent = true, desc = 'Close other tabs' })
-- }}}

-- term {{{
-- https://zenn.dev/fuzmare/articles/vim-term-escape
keymap.set('t', '<ESC>', '<C-\\><C-n><Plug>(esc)', { noremap = true, desc = 'Leave terminal mode' })
keymap.set('n', '<Plug>(esc)<ESC>', 'i<ESC>', { noremap = true, desc = 'Send <Esc> to the terminal' })
-- floaterm
local function floaterm(key, cmd, desc)
	keymap.set('n', '<Leader>t' .. key, '<Cmd>' .. cmd .. '<CR>', { silent = true, desc = desc })
	keymap.set('t', '<Leader>t' .. key, '<Cmd>' .. cmd .. '<CR>', { silent = true, desc = desc })
end
floaterm('c', 'FloatermNew', 'Floaterm: new')
floaterm('p', 'FloatermPrev', 'Floaterm: previous')
floaterm('n', 'FloatermNext', 'Floaterm: next')
floaterm('t', 'FloatermToggle', 'Floaterm: toggle')
local function floaterm_kill_and_next()
	local bufs = vim.fn['floaterm#buflist#gather']()
	if #bufs > 1 then
		local cur = vim.api.nvim_get_current_buf()
		vim.cmd.FloatermPrev()
		vim.cmd.FloatermKill(cur)
	else
		vim.cmd.FloatermToggle()
	end
end
keymap.set('n', '<Leader>tx', floaterm_kill_and_next, { silent = true, desc = 'Floaterm: kill' })
keymap.set('t', '<Leader>tx', function()
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<C-\\><C-n>', true, false, true), 'n', false)
	floaterm_kill_and_next()
end, { silent = true, desc = 'Floaterm: kill' })
-- }}}

-- disabled {{{
keymap.set('n', '<C-]>', '<Nop>', { desc = 'Disabled' })
-- }}}
