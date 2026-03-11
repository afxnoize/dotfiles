--- copy from https://github.com/yutkat/dotfiles/blob/master/.config/wezterm/utils.lua

local M = {}

function M.merge_config(base, extra)
	for k, v in pairs(extra) do
		base[k] = v
	end
end

function M.merge_tables(t1, t2)
	for k, v in pairs(t2) do
		if (type(v) == "table") and (type(t1[k] or false) == "table") then
			M.merge_tables(t1[k], t2[k])
		else
			t1[k] = v
		end
	end
	return t1
end

function M.merge_lists(a, b)
	local result = {}
	for _, v in ipairs(a) do
		table.insert(result, v)
	end
	for _, v in ipairs(b) do
		table.insert(result, v)
	end
	return result
end

return M
