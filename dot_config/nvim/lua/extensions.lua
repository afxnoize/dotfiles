local create_user_command = vim.api.nvim_create_user_command

-- json parser
-- vim.fn.executable() returns 0 or 1, and 0 is truthy in Lua, so compare explicitly
if vim.fn.executable('jq') == 1 then
	create_user_command('Jq', function(opts)
		local filter = opts.fargs[1] or '.'
		-- true: also escape !, % and # which :! would expand
		vim.cmd('%!jq ' .. vim.fn.shellescape(filter, true))
	end, { nargs = '?' })
end

-- QuickFixGrep {{{
-- require setting [[au QuickFixCmdPost make,*grep* cwindow]]
if vim.fn.executable('git') == 1 then
	create_user_command('Ggrep', function(opts)
		local current_grepprg = vim.o.grepprg
		vim.opt_local.grepprg = 'git grep -I --line-number'
		vim.cmd('silent grep! ' .. opts.args)
		vim.opt_local.grepprg = current_grepprg
		vim.cmd('redraw!')
	end, { nargs = 1 })
end

if vim.fn.executable('rg') == 1 then
	create_user_command('Rgrep', function(opts)
		local current_grepprg = vim.o.grepprg
		local current_grepformat = vim.o.grepformat
		vim.opt_local.grepprg = 'rg --vimgrep --hidden'
		vim.opt_local.grepformat = '%f:%l:%c:%m'
		vim.cmd('silent grep! ' .. opts.args)
		vim.opt_local.grepprg = current_grepprg
		vim.opt_local.grepformat = current_grepformat
		vim.cmd('redraw!')
	end, { nargs = 1 })
end

if vim.fn.executable('jvgrep') == 1 then
	create_user_command('Jvgrep', function(opts)
		local current_grepprg = vim.o.grepprg
		vim.opt_local.grepprg = 'jvgrep'
		vim.cmd('silent grep! ' .. opts.args .. ' ./*')
		vim.opt_local.grepprg = current_grepprg
		vim.cmd('redraw!')
	end, { nargs = 1 })
end
-- }}}
