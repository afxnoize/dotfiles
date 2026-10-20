local M = {}

-- catppuccin compiles each flavour to Lua that is loadfile()d on every start, so the
-- output must not sit under stdpath('cache'), which cage grants to sandboxed agents.
-- Inside cage the data dir is read-only and compiling there would abort startup, so
-- fall back to the cache dir; an unsandboxed nvim never takes that branch.
function M.compile_path()
	local dir = vim.fn.stdpath('data') .. '/catppuccin'
	local probe = dir .. '/.write-probe'
	-- Probe with a real write: fs_access() ignores Landlock and reports cage-denied dirs as writable
	local f = pcall(vim.fn.mkdir, dir, 'p') and io.open(probe, 'w')
	if f then
		f:close()
		os.remove(probe)
		return dir
	end
	return vim.fn.stdpath('cache') .. '/catppuccin'
end

return M
