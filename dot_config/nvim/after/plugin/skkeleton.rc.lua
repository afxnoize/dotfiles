-- access https://skk-dev.github.io/dict/
-- $ curl -OL https://skk-dev.github.io/dict/SKK-JISYO.L.gz
-- put /usr/share/skk/SKK-JISYO.L

vim.keymap.set({ 'i', 'c' }, '<C-j>', '<Plug>(skkeleton-toggle)', { noremap = false })

-- Evaluating the variable autoloads skkeleton, which defines the default keys
local mapped_keys = vim.fn.eval('g:skkeleton#mapped_keys')
vim.list_extend(mapped_keys, { '<C-n>', '<C-p>' })
vim.g['skkeleton#mapped_keys'] = mapped_keys
vim.api.nvim_create_autocmd('User', {
	group = vim.api.nvim_create_augroup('skkeleton-initialize-pre', {}),
	pattern = 'skkeleton-initialize-pre',
	callback = function()
		vim.fn['skkeleton#config']({ eggLikeNewline = true, debug = true })
		vim.fn['skkeleton#register_keymap']('insert', '<C-n>', 'henkanFirst')
		vim.fn['skkeleton#register_keymap']('henkan', '<C-n>', 'henkanForward')
		vim.fn['skkeleton#register_keymap']('henkan', '<C-p>', 'henkanBackward')
	end
})
