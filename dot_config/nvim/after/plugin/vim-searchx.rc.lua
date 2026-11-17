-- Overwrite / and ?.
vim.keymap.set({ 'n', 'x' }, '?', [[<Cmd>call searchx#start({ 'dir': 0 })<CR>]], { desc = 'Search backward (searchx)' })
vim.keymap.set({ 'n', 'x' }, '/', [[<Cmd>call searchx#start({ 'dir': 1 })<CR>]], { desc = 'Search forward (searchx)' })

vim.keymap.set({ 'n', 'x' }, 'N', '<Cmd>call searchx#prev_dir()<CR>', { desc = 'Previous match in search direction (searchx)' })
vim.keymap.set({ 'n', 'x' }, 'n', '<Cmd>call searchx#next_dir()<CR>', { desc = 'Next match in search direction (searchx)' })
vim.keymap.set({ 'n', 'x' }, '<C-k>', '<Cmd>call searchx#prev()<CR>', { desc = 'Previous match (searchx)' })
vim.keymap.set({ 'n', 'x' }, '<C-j>', '<Cmd>call searchx#next()<CR>', { desc = 'Next match (searchx)' })

vim.keymap.set('n', '<C-l>', '<Cmd>call searchx#clear()<CR>', { desc = 'Clear search highlight (searchx)' })

vim.g.searchx = {
	-- Auto jump if the recent input matches to any marker.
	auto_accept = true,
	-- The scrolloff value for moving to next/prev.
	scrolloff = vim.opt.scrolloff:get(),
	-- To enable scrolling animation.
	scrolltime = 0,
	-- To enable auto nohlsearch after cursor is moved
	nohlsearch = { jump = true },
	-- Marker characters.
	markers = vim.fn.split('ABCDEFGHIJKLMNOPQRSTUVWXYZ', [[.\zs]]),
	-- Convert search pattern.
	convert = function(input)
		if vim.fn.match(input, [[\k]]) == -1 then
			return [[\V]] .. input
		end
		return input:sub(1, 1) .. vim.fn.substitute(input:sub(2), [[\\\@<! ]], [[.\\{-}]], 'g')
	end,
}

-- [TODO] vim.api.nvim_set_hl(0, 'SearchxMarker', { bg = 'cyan' })
