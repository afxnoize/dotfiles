local M = {}

function M.config()
	local dialmap = require('dial.map')

	vim.keymap.set('n', '<C-a>', function()
		dialmap.manipulate('increment', 'normal')
	end, { desc = 'Dial: increment' })
	vim.keymap.set('n', '<C-x>', function()
		dialmap.manipulate('decrement', 'normal')
	end, { desc = 'Dial: decrement' })
	vim.keymap.set('v', '<C-a>', function()
		dialmap.manipulate('increment', 'visual')
	end, { desc = 'Dial: increment selection' })
	vim.keymap.set('v', '<C-x>', function()
		dialmap.manipulate('decrement', 'visual')
	end, { desc = 'Dial: decrement selection' })
	vim.keymap.set('n', 'g<C-a>', function()
		dialmap.manipulate('increment', 'gnormal')
	end, { desc = 'Dial: increment (cumulative)' })
	vim.keymap.set('n', 'g<C-x>', function()
		dialmap.manipulate('decrement', 'gnormal')
	end, { desc = 'Dial: decrement (cumulative)' })
	vim.keymap.set('v', 'g<C-a>', function()
		dialmap.manipulate('increment', 'gvisual')
	end, { desc = 'Dial: increment selection (cumulative)' })
	vim.keymap.set('v', 'g<C-x>', function()
		dialmap.manipulate('decrement', 'gvisual')
	end, { desc = 'Dial: decrement selection (cumulative)' })

	local augend = require('dial.augend')
	require('dial.config').augends:register_group({
		-- default augends used when no group name is specified
		default = {
			augend.integer.alias.decimal, -- nonnegative decimal number (0, 1, 2, 3, ...)
			augend.integer.alias.hex, -- nonnegative hex number  (0x01, 0x1a1f, etc.)
			augend.constant.alias.bool, -- boolean value (true <-> false)
			augend.date.alias["%Y/%m/%d"],
			augend.date.alias["%Y-%m-%d"],
			augend.date.alias["%m/%d"],
			augend.date.alias["%-m/%-d"],
			augend.date.alias["%Y年%-m月%-d日"],
			augend.date.alias["%Y年%-m月%-d日(%ja)"],
			augend.date.alias["%H:%M"],
			augend.constant.alias.ja_weekday_full,
		}
	})
end

return M
