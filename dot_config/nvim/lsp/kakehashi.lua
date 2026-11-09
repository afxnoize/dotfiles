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
		},
	},
}
