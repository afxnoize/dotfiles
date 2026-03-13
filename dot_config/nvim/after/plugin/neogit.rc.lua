local function open(opt)
	return function()
		return require('neogit').open(opt or {})
	end
end

local silent = { silent = true }
vim.keymap.set('n', '[git]s', open({ kind = 'replace' }), silent)
vim.keymap.set('n', '[git]b', open({ 'branch', kind = 'split' }), silent)
vim.keymap.set('n', '[git]l', open({ 'log' }), silent)
