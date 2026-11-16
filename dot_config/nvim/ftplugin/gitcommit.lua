-- BB abbreviate {{{
vim.keymap.set('ia', 'BB', 'BREAKING CHANGE:', { buffer = true, desc = 'Expand BB to BREAKING CHANGE:' })
-- }}}

-- Complete types {{{
-- https://github.com/conventional-changelog/commitlint/tree/master/%40commitlint/config-conventional
local types = {
	'chore: ',
	'ci: ',
	'docs: ',
	'feat: ',
	'fix: ',
	'perf: ',
	'refactor: ',
	'revert: ',
	'style: ',
	'test: ',
}

vim.keymap.set('n', 'i', function()
	vim.keymap.del('n', 'i', { buffer = true })
	vim.cmd.startinsert()
	vim.schedule(function()
		vim.fn.complete(1, types)
	end)
end, { buffer = true, desc = 'Insert with commit type completion' })
-- }}}
