vim.keymap.set('n', '<Leader>gd', '<Cmd>DiffviewOpen<CR>', { silent = true, desc = 'Diffview: open' })
vim.keymap.set('n', '<Leader>gh', '<Cmd>DiffviewFileHistory %<CR>', { silent = true, desc = 'Diffview: history of current file' })
vim.keymap.set('n', '<Leader>gH', '<Cmd>DiffviewFileHistory<CR>', { silent = true, desc = 'Diffview: history of repository' })

require('diffview').setup({
	view = {
		merge_tool = {
			layout = 'diff3_horizontal',
			disable_diagnostics = true,
		},
	},
})
