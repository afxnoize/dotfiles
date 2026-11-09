-- BB abbreviate {{{
-- Registering a FileType autocmd here misses the FileType event that is running this file.
vim.cmd('inoreabbrev <buffer> BB BREAKING CHANGE:')
-- }}}

-- Complete types {{{
local function commit_type()
	-- https://github.com/conventional-changelog/commitlint/tree/master/%40commitlint/config-conventional
	vim.fn.complete(1, {
		'chore: ',
		'ci: ',
		'docs: ',
		'feat: ',
		'fix: ',
		'perf: ',
		'refactor: ',
		'revert: ',
		'style: ',
		'test: '
	})
	vim.api.nvim_buf_del_keymap(0, 'n', 'i')
	return ''
end

vim.api.nvim_buf_set_keymap(0, 'n', 'i', 'i<C-r>=v:lua.commit_type()<CR>', { noremap = true })

_G.commit_type = commit_type
-- }}}
