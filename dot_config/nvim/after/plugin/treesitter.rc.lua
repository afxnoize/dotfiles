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
-- The directory does not exist on a fresh machine, and the probe would fail without it. mkdir is
-- allowed to fail for the same read-only reason, and then the probe below skips the install.
pcall(vim.fn.mkdir, install_dir, 'p')
local probe = install_dir .. '/.write-probe'
local f = io.open(probe, 'w')
if f then
	f:close()
	os.remove(probe)
	ts.install({ 'html', 'tsx', 'javascript', 'typescript' })
end
