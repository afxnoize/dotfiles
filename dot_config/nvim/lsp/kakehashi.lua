return {
	cmd = { 'kakehashi' },
	init_options = {
		autoInstall = true,
		-- Unset, the server reports languageServers as null and inherit_nvim_lsp_config throws on it
		languageServers = vim.empty_dict(),
		-- autoInstall stays disabled unless searchPaths includes kakehashi's default data dir
		searchPaths = {
			vim.fs.joinpath(vim.env.XDG_DATA_HOME or vim.fn.expand('~/.local/share'), 'kakehashi'),
			vim.fn.stdpath('data') .. '/lazy/kakehashi.nvim',
			-- autoInstall fetches typescript/highlights.scm ("; inherits: ecma") without ecma,
			-- so semantic tokens come back empty. nvim-treesitter ships the missing base queries
			vim.fn.stdpath('data') .. '/lazy/nvim-treesitter/runtime',
		},
	},
}
