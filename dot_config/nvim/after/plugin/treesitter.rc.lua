local ok, ts = pcall(require, 'nvim-treesitter')
if not ok then
	return
end

local install_dir = vim.fn.stdpath('data') .. '/site'

ts.setup({
	install_dir = install_dir
})

-- The main branch installs nothing by itself. nvim-ts-autotag needs these parsers on the client side.
-- Async, and parsers that are already installed are skipped.
-- Probe with a real write, as in rc/catppuccin.lua: inside cage the data dir is read-only, and
-- installing there would print EACCES errors on every start (fs_access() ignores Landlock).
local probe = install_dir .. '/.write-probe'
local f = io.open(probe, 'w')
if f then
	f:close()
	os.remove(probe)
	ts.install({ 'html', 'tsx', 'javascript', 'typescript' })
end
