-- kakehashi: inherit nvim lsp configs as bridged servers {{{
-- It has no mason package, so it is enabled explicitly (see lsp/kakehashi.lua). This block sits
-- above the mason checks below, which return early, so kakehashi does not depend on mason loading.
vim.api.nvim_create_autocmd('LspAttach', {
	callback = function(ev)
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		if client and client.name == 'kakehashi' then
			require('kakehashi').inherit_nvim_lsp_config(
				client,
				vim.tbl_keys(vim.lsp._enabled_configs),
				'keep'
			)
		end
	end,
})
vim.lsp.enable('kakehashi')
-- }}}

local ok, _ = pcall(require, 'mason')
if not ok then
	print('mason is not installed')
	return
end

-- https://scrapbox.io/vim-jp/better_K_for_neovim_lua
local function lua_help()
	if vim.bo.filetype ~= 'lua' then
		return false
	end
	local current_line = vim.api.nvim_get_current_line()
	local cursor_col = vim.api.nvim_win_get_cursor(0)[2] + 1
	-- vim.fn.foo
	local s, e, m = current_line:find([[fn%.([%w_]+)%(?]])
	if s and s <= cursor_col and cursor_col <= e then
		vim.cmd('h ' .. m)
		return true
	end
	-- vim.fn['foo']
	s, e, m = current_line:find([[fn%[['"]([%w_#]+)['"]%]%(?]])
	if s and s <= cursor_col and cursor_col <= e then
		vim.cmd('h ' .. m)
		return true
	end
	-- vim.api.foo
	s, e, m = current_line:find([[api%.([%w_]+)%(?]])
	if s and s <= cursor_col and cursor_col <= e then
		vim.cmd('h ' .. m)
		return true
	end
	-- other vim.foo (e.g. vim.tbl_map, vim.lsp.foo, ...)
	s, e, m = current_line:find([[(vim%.[%w_%.]+)%(?]])
	if s and s <= cursor_col and cursor_col <= e then
		vim.cmd('h ' .. m)
		return true
	end
	return false
end

-- Servers that must not format, because null-ls already formats the same filetypes.
-- With several formatting clients attached, `]F` runs every one of them in turn.
local formatting_disabled = { vtsls = true, lua_ls = true }

-- AuthCmd: LspAttach {{{
vim.api.nvim_create_autocmd('LspAttach', {
	group = vim.api.nvim_create_augroup('mylspconfig', {}),
	callback = function(args)
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		if client and formatting_disabled[client.name] then
			client.server_capabilities.documentFormattingProvider = false
			client.server_capabilities.documentRangeFormattingProvider = false
		end

		-- Mappings.
		-- See `:help vim.lsp.*` for documentation on any of the below functions
		local bufnr = args.buf
		local bufopts = { noremap = true, silent = true, buffer = bufnr }
		vim.keymap.set('n', '][', function() vim.diagnostic.jump({ count = -1 }) end, bufopts)
		vim.keymap.set('n', ']]', function() vim.diagnostic.jump({ count = 1 }) end, bufopts)
		vim.keymap.set('n', ']e', vim.diagnostic.open_float, bufopts)

		-- Definitions
		vim.keymap.set('n', ']d', vim.lsp.buf.definition, bufopts)

		-- Implementations
		vim.keymap.set('n', ']i', vim.lsp.buf.implementation, bufopts)

		-- References
		vim.keymap.set('n', ']f', vim.lsp.buf.references, bufopts)

		vim.keymap.set('n', 'K', function() -- https://scrapbox.io/vim-jp/better_K_for_neovim_lua
			if not lua_help() then
				vim.lsp.buf.hover()
			end
		end, bufopts)
		vim.keymap.set('n', ']r', vim.lsp.buf.rename, bufopts)
		vim.keymap.set('n', ']a', vim.lsp.buf.code_action, bufopts)
		vim.keymap.set('n', ']F', function()
			vim.lsp.buf.format { async = true }
		end, bufopts)
	end,
})
-- }}}

-- Capacibilites {{{
-- The nvim-cmp almost supports LSP's capabilities so You should advertise it to LSP servers...
local ok, cmp_nvim_lsp = pcall(require, 'cmp_nvim_lsp')
if ok then
	local capabilities = vim.lsp.protocol.make_client_capabilities()
	vim.lsp.config('*', { capabilities = cmp_nvim_lsp.default_capabilities(capabilities) })
else
	print('cmp-nvim-lsp is not installed')
end
-- }}}

-- mason lspconfig {{{
local ok, mason_lspconfig = pcall(require, 'mason-lspconfig')
if not ok then
	print('mason-lspconfig is not installed')
	return
end

mason_lspconfig.setup {
	ensure_installed = {
		'lua_ls',
		'vtsls',
	},
	-- Every installed server is enabled by default. Skip the ones that duplicate another client:
	-- ts_ls (vtsls is the TypeScript server), stylua (null-ls runs stylua via mason-null-ls) and
	-- biome (prettier is the formatter; see the biome handler in plugins.lua).
	automatic_enable = {
		exclude = { 'ts_ls', 'stylua', 'biome' },
	},
}
-- }}}
