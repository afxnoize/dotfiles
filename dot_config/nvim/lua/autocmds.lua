local create_augroup = vim.api.nvim_create_augroup
local create_autocmd = vim.api.nvim_create_autocmd

create_autocmd('filetype', { -- {{{
	group = create_augroup('DisableInsertNextlineComment', {}),
	pattern = '*',
	callback = function()
		vim.opt_local.formatoptions:remove({ 'r', 'o' })
	end,
}) -- }}}

-- 2-space indent filetypes {{{
-- Compound filetypes (typescript.tsx, html.handlebars, ...) are split and matched per part,
-- like ftplugin does. A bare pattern list would miss them.
-- jsonc, php etc. are listed because $VIMRUNTIME's ftplugin used to chain-load the json/html
-- ftplugin of this config, so they were 2-space before the ftplugin files were merged here.
local two_space_filetypes = {}
for _, ft in ipairs({
	'css', 'html', 'javascript', 'javascriptreact', 'json', 'nix',
	'sass', 'scss', 'typescript', 'typescriptreact', 'vue', 'xhtml',
	'jsonc', 'php', 'eruby', 'htmldjango', 'liquid', 'stylus', 'htmlangular',
	'aspvbs', 'jsp', 'tt2html', 'haml',
}) do
	two_space_filetypes[ft] = true
end

create_autocmd('FileType', {
	group = create_augroup('TwoSpaceIndent', {}),
	pattern = '*',
	callback = function(args)
		for _, ft in ipairs(vim.split(args.match, '.', { plain = true })) do
			if two_space_filetypes[ft] then
				vim.opt_local.expandtab = true
				vim.opt_local.tabstop = 2
				vim.opt_local.softtabstop = 0
				vim.opt_local.shiftwidth = 2
				return
			end
		end
	end,
}) -- }}}

-- QuickFixGrep{{{
create_autocmd('QuickFixCmdPost', {
	group = create_augroup('QuickFixGrep', {}),
	pattern = { 'make', '*grep*' },
	command = 'cwindow',
}) -- }}}

-- 背景透過{{{
if vim.env.TRANSPARENT_TERM == '1' then
	create_autocmd('Colorscheme', {
		group = vim.api.nvim_create_augroup('TransparentBackground', {}),
		pattern = '*',
		callback = function()
			for _, name in ipairs({ 'Normal', 'NonText', 'LineNr', 'Folded', 'EndOfBuffer' }) do
				-- nvim_set_hl replaces the group, so keep the other attributes
				local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
				hl.bg = 'NONE'
				hl.ctermbg = 'NONE'
				vim.api.nvim_set_hl(0, name, hl)
			end
		end,
	})
	vim.api.nvim_exec_autocmds('ColorScheme', { group = 'TransparentBackground' })
end -- }}}

-- disable autofold at writing{{{
local shut_up_auto_fold_at_writing = create_augroup('ShutUpAutoFoldAtWriting', {})
create_autocmd('BufWinLeave', {
	group = shut_up_auto_fold_at_writing,
	pattern = '*',
	-- silent!: inside cage the view dir is read-only (it is sourced as code by loadview)
	command = [[if expand('%') != '' && &buftype != 'nofile' | silent! mkview | endif]],
})
create_autocmd('BufWinEnter', {
	group = shut_up_auto_fold_at_writing,
	pattern = '*',
	command = [[if expand('%') != '' && &buftype != 'nofile' | silent! loadview | endif]],
}) -- }}}
