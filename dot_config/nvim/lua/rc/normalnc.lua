local M = {}

local function blend(bg, fg, ratio)
	local function channel(shift)
		local b = bit.band(bit.rshift(bg, shift), 0xff)
		local f = bit.band(bit.rshift(fg, shift), 0xff)
		return math.floor(b + (f - b) * ratio + 0.5)
	end
	return bit.lshift(channel(16), 16) + bit.lshift(channel(8), 8) + channel(0)
end

function M.setup()
	vim.api.nvim_create_autocmd('ColorScheme', {
		group = vim.api.nvim_create_augroup('normalnc', {}),
		callback = function()
			local normal = vim.api.nvim_get_hl(0, { name = 'Normal', link = false })
			if not (normal.bg and normal.fg) then
				return
			end
			vim.api.nvim_set_hl(0, 'NormalNC', { bg = blend(normal.bg, normal.fg, 0.06) })
		end,
	})
end

return M
