local ok, ts = pcall(require, 'nvim-treesitter')
if not ok then
	return
end

ts.setup({
	install_dir = vim.fn.stdpath('data') .. '/site'
})
