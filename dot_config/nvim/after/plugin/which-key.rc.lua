local ok, wk = pcall(require, 'which-key')
if not ok then
	print('which-key is not installed')
end

-- [lsp]を押しても表示されない. :WhichKey [lsp]には登録されている
wk.add({
	mode = {"n"},
	{ "[lsp]<C-d>", desc = "Definition" },
	{ "[lsp][", desc = "Diagnostic prev" },
	{ "[lsp]]", desc = "Diagnostic next" },
	{ "[lsp]e", desc = "Diagnostic float" },
	{ "[lsp]d", desc = "Definition" },
	{ "[lsp]f", desc = "References" },
	{ "[lsp]D", desc = "Definition" },
	{ "[lsp]F", desc = "Format" },
	{ "[lsp]i", desc = "Implementation" },
	{ "[lsp]r", desc = "Rename" },
	{ "[lsp]c", desc = "Code action" },
})
