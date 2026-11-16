local function open(opt)
	return function()
		return require('neogit').open(opt or {})
	end
end

vim.keymap.set('n', '<Leader>gs', open({ kind = 'replace' }), { silent = true, desc = 'Neogit: status' })
vim.keymap.set('n', '<Leader>gb', open({ 'branch', kind = 'split' }), { silent = true, desc = 'Neogit: branch' })
vim.keymap.set('n', '<Leader>gl', open({ 'log' }), { silent = true, desc = 'Neogit: log' })
