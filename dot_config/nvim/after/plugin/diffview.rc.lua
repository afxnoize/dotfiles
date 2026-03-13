local silent = { silent = true }
vim.keymap.set('n', '[git]d', '<Cmd>DiffviewOpen<CR>', silent)
vim.keymap.set('n', '[git]h', '<Cmd>DiffviewFileHistory %<CR>', silent)
vim.keymap.set('n', '[git]H', '<Cmd>DiffviewFileHistory<CR>', silent)

require('diffview').setup({
	view = {
		merge_tool = {
			layout = 'diff3_horizontal',
			disable_diagnostics = true,
		},
	},
})
