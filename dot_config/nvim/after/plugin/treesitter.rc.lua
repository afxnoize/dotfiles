local ok, ts = pcall(require, 'nvim-treesitter.configs')
if not ok then
	return
end

vim.api.nvim_create_autocmd("User", {
	pattern = "TSUpdate",
	callback = function()
		require("nvim-treesitter.parsers").moonbit = {
			install_info = {
				url = "https://github.com/moonbitlang/tree-sitter-moonbit",
				branch = "main",
				queries = 'queries',
			}
		}
	end
})

ts.setup({
	highlight = {
		enable = true,
		disable = {},
	},
	indent = {
		enable = true,
		disable = {},
	},
	ensure_installed = {},
	-- autotag = {
	--   enable = true,
	-- },
})

local parser_config = require('nvim-treesitter.parsers').get_parser_configs()
parser_config.tsx.filetype_to_parsername = { 'javascript', 'typescript.tsx' }
